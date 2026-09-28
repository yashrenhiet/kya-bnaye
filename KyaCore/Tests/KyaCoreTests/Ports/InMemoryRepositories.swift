import Foundation
import KyaCore

/// Reference ``IngredientRepository``.
struct InMemoryIngredientRepository: IngredientRepository {
    let table = InMemoryTable<Ingredient>(key: \.id) { $0.sorted { $0.id < $1.id } }

    func all() async -> [Ingredient] { await table.snapshot() }
    func watchAll() -> AsyncThrowingStream<[Ingredient], any Error> { table.observe() }
    func upsert(_ ingredients: [Ingredient]) async { await table.upsert(ingredients) }
    func insertMissing(_ ingredients: [Ingredient]) async -> [String] {
        await table.insertMissing(ingredients)
    }
}

/// Reference ``PantryRepository``.
struct InMemoryPantryRepository: PantryRepository {
    let table = InMemoryTable<PantryItem>(key: \.ingredientId) {
        $0.sorted { $0.ingredientId < $1.ingredientId }
    }

    func all() async -> [PantryItem] { await table.snapshot() }
    func watchAll() -> AsyncThrowingStream<[PantryItem], any Error> { table.observe() }
    func setLevels(_ items: [PantryItem]) async { await table.upsert(items) }
    func delete(ingredientIds: Set<String>) async { await table.delete(ids: ingredientIds) }
}

/// Reference ``RecipeRepository``.
struct InMemoryRecipeRepository: RecipeRepository {
    let table = InMemoryTable<Recipe>(key: \.id) { $0.sorted { $0.id < $1.id } }

    func all() async -> [Recipe] { await table.snapshot() }
    func watchAll() -> AsyncThrowingStream<[Recipe], any Error> { table.observe() }
    func recipe(withId id: String) async -> Recipe? { await table.row(withId: id) }
    func upsert(_ recipes: [Recipe]) async { await table.upsert(recipes) }
    func insertMissing(_ recipes: [Recipe]) async -> [String] {
        await table.insertMissing(recipes)
    }
    func setFavorite(_ isFavorite: Bool, forRecipeWithId id: String) async throws {
        try await table.update(id: id) { $0.copy(isFavorite: isFavorite) }
    }
    func setHidden(_ isHidden: Bool, forRecipeWithId id: String) async throws {
        try await table.update(id: id) { $0.copy(isHidden: isHidden) }
    }
    func delete(id: String) async { await table.delete(ids: [id]) }
}

/// Reference ``MealLogRepository``.
struct InMemoryMealLogRepository: MealLogRepository {
    let table = InMemoryTable<MealLog>(key: \.id) {
        $0.sorted { ($0.cookedAt, $0.id) < ($1.cookedAt, $1.id) }
    }

    func all() async -> [MealLog] { await table.snapshot() }
    func watchAll() -> AsyncThrowingStream<[MealLog], any Error> { table.observe() }
    func add(_ log: MealLog) async throws { try await table.insertNew(log) }
}

/// Reference ``SwipeEventRepository``.
struct InMemorySwipeEventRepository: SwipeEventRepository {
    let table = InMemoryTable<SwipeEvent>(key: \.id) {
        $0.sorted { ($0.at, $0.id) < ($1.at, $1.id) }
    }

    func all() async -> [SwipeEvent] { await table.snapshot() }
    func watchAll() -> AsyncThrowingStream<[SwipeEvent], any Error> { table.observe() }
    func add(_ event: SwipeEvent) async throws { try await table.insertNew(event) }
    func deleteAll() async { await table.replaceAll([]) }
}

/// Reference ``ShoppingRepository`` (list order = first-insertion order).
struct InMemoryShoppingRepository: ShoppingRepository {
    let table = InMemoryTable<ShoppingItem>(key: \.id)

    func all() async -> [ShoppingItem] { await table.snapshot() }
    func watchAll() -> AsyncThrowingStream<[ShoppingItem], any Error> { table.observe() }
    func upsert(_ items: [ShoppingItem]) async { await table.upsert(items) }
    func setChecked(_ isChecked: Bool, forItemWithId id: String) async throws {
        try await table.update(id: id) { $0.withIsChecked(isChecked) }
    }
    func delete(ids: Set<String>) async { await table.delete(ids: ids) }
}

/// Reference ``SeedStateRepository``.
actor InMemorySeedStateRepository: SeedStateRepository {
    private var version: Int?

    func seedVersion() -> Int? { version }
    func setSeedVersion(_ version: Int) { self.version = version }
    func replace(with version: Int?) { self.version = version }
}

/// Reference ``BackupRepository`` over the other in-memory repositories.
/// Tables are written one after another; in memory nothing can fail midway.
struct InMemoryBackupRepository: BackupRepository {
    let ingredients: InMemoryIngredientRepository
    let pantry: InMemoryPantryRepository
    let recipes: InMemoryRecipeRepository
    let mealLogs: InMemoryMealLogRepository
    let swipeEvents: InMemorySwipeEventRepository
    let shopping: InMemoryShoppingRepository
    let seedState: InMemorySeedStateRepository

    func exportSnapshot() async -> RepositorySnapshot {
        RepositorySnapshot(
            ingredients: await ingredients.all(),
            pantryItems: await pantry.all(),
            recipes: await recipes.all(),
            mealLogs: await mealLogs.all(),
            swipeEvents: await swipeEvents.all(),
            shoppingItems: await shopping.all(),
            seedVersion: await seedState.seedVersion()
        )
    }

    func replaceAll(with snapshot: RepositorySnapshot) async {
        await ingredients.table.replaceAll(snapshot.ingredients)
        await pantry.table.replaceAll(snapshot.pantryItems)
        await recipes.table.replaceAll(snapshot.recipes)
        await mealLogs.table.replaceAll(snapshot.mealLogs)
        await swipeEvents.table.replaceAll(snapshot.swipeEvents)
        await shopping.table.replaceAll(snapshot.shoppingItems)
        await seedState.replace(with: snapshot.seedVersion)
    }
}

/// A fresh, empty in-memory ``RepositorySet``.
func makeInMemoryRepositorySet() -> RepositorySet {
    let backup = InMemoryBackupRepository(
        ingredients: InMemoryIngredientRepository(),
        pantry: InMemoryPantryRepository(),
        recipes: InMemoryRecipeRepository(),
        mealLogs: InMemoryMealLogRepository(),
        swipeEvents: InMemorySwipeEventRepository(),
        shopping: InMemoryShoppingRepository(),
        seedState: InMemorySeedStateRepository()
    )
    return RepositorySet(
        ingredients: backup.ingredients,
        pantry: backup.pantry,
        recipes: backup.recipes,
        mealLogs: backup.mealLogs,
        swipeEvents: backup.swipeEvents,
        shopping: backup.shopping,
        seedState: backup.seedState,
        backup: backup
    )
}
