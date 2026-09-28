import Foundation
import KyaCore

// Thin `KyaCore` port adapters over one shared ``DataStoreActor``. They hold no state of
// their own: all isolation, atomicity and change notification live in the actor, which is
// why a write through any adapter re-emits every observer of the affected table.

/// SwiftData-backed ``KyaCore/IngredientRepository``.
struct SwiftDataIngredientRepository: IngredientRepository {
    /// The shared store.
    let store: DataStoreActor

    func all() async throws -> [Ingredient] {
        try await store.allIngredients()
    }

    func watchAll() -> AsyncThrowingStream<[Ingredient], any Error> {
        store.observe(.ingredients) { try await $0.allIngredients() }
    }

    func upsert(_ ingredients: [Ingredient]) async throws {
        try await store.upsertIngredients(ingredients)
    }

    func insertMissing(_ ingredients: [Ingredient]) async throws -> [String] {
        try await store.insertMissingIngredients(ingredients)
    }
}

/// SwiftData-backed ``KyaCore/RecipeRepository``.
struct SwiftDataRecipeRepository: RecipeRepository {
    /// The shared store.
    let store: DataStoreActor

    func all() async throws -> [Recipe] {
        try await store.allRecipes()
    }

    func watchAll() -> AsyncThrowingStream<[Recipe], any Error> {
        store.observe(.recipes) { try await $0.allRecipes() }
    }

    func recipe(withId id: String) async throws -> Recipe? {
        try await store.recipe(withId: id)
    }

    func upsert(_ recipes: [Recipe]) async throws {
        try await store.upsertRecipes(recipes)
    }

    func insertMissing(_ recipes: [Recipe]) async throws -> [String] {
        try await store.insertMissingRecipes(recipes)
    }

    func setFavorite(_ isFavorite: Bool, forRecipeWithId id: String) async throws {
        try await store.setFavorite(isFavorite, forRecipeWithId: id)
    }

    func setHidden(_ isHidden: Bool, forRecipeWithId id: String) async throws {
        try await store.setHidden(isHidden, forRecipeWithId: id)
    }

    func delete(id: String) async throws {
        try await store.deleteRecipe(id: id)
    }
}

/// SwiftData-backed ``KyaCore/PantryRepository``.
struct SwiftDataPantryRepository: PantryRepository {
    /// The shared store.
    let store: DataStoreActor

    func all() async throws -> [PantryItem] {
        try await store.allPantryItems()
    }

    func watchAll() -> AsyncThrowingStream<[PantryItem], any Error> {
        store.observe(.pantry) { try await $0.allPantryItems() }
    }

    func setLevels(_ items: [PantryItem]) async throws {
        try await store.setPantryLevels(items)
    }

    func delete(ingredientIds: Set<String>) async throws {
        try await store.deletePantryItems(ingredientIds: ingredientIds)
    }
}

/// SwiftData-backed ``KyaCore/ShoppingRepository``.
struct SwiftDataShoppingRepository: ShoppingRepository {
    /// The shared store.
    let store: DataStoreActor

    func all() async throws -> [ShoppingItem] {
        try await store.allShoppingItems()
    }

    func watchAll() -> AsyncThrowingStream<[ShoppingItem], any Error> {
        store.observe(.shopping) { try await $0.allShoppingItems() }
    }

    func upsert(_ items: [ShoppingItem]) async throws {
        try await store.upsertShoppingItems(items)
    }

    func setChecked(_ isChecked: Bool, forItemWithId id: String) async throws {
        try await store.setShoppingItemChecked(isChecked, forItemWithId: id)
    }

    func delete(ids: Set<String>) async throws {
        try await store.deleteShoppingItems(ids: ids)
    }
}

/// SwiftData-backed ``KyaCore/MealLogRepository``.
struct SwiftDataMealLogRepository: MealLogRepository {
    /// The shared store.
    let store: DataStoreActor

    func all() async throws -> [MealLog] {
        try await store.allMealLogs()
    }

    func watchAll() -> AsyncThrowingStream<[MealLog], any Error> {
        store.observe(.mealLogs) { try await $0.allMealLogs() }
    }

    func add(_ log: MealLog) async throws {
        try await store.addMealLog(log)
    }
}

/// SwiftData-backed ``KyaCore/SwipeEventRepository``.
struct SwiftDataSwipeEventRepository: SwipeEventRepository {
    /// The shared store.
    let store: DataStoreActor

    func all() async throws -> [SwipeEvent] {
        try await store.allSwipeEvents()
    }

    func watchAll() -> AsyncThrowingStream<[SwipeEvent], any Error> {
        store.observe(.swipeEvents) { try await $0.allSwipeEvents() }
    }

    func add(_ event: SwipeEvent) async throws {
        try await store.addSwipeEvent(event)
    }

    func deleteAll() async throws {
        try await store.deleteAllSwipeEvents()
    }
}

/// SwiftData-backed ``KyaCore/SeedStateRepository``.
struct SwiftDataSeedStateRepository: SeedStateRepository {
    /// The shared store.
    let store: DataStoreActor

    func seedVersion() async throws -> Int? {
        try await store.seedVersion()
    }

    func setSeedVersion(_ version: Int) async throws {
        try await store.setSeedVersion(version)
    }
}

/// SwiftData-backed ``KyaCore/BackupRepository``, over the same store as the others.
struct SwiftDataBackupRepository: BackupRepository {
    /// The shared store.
    let store: DataStoreActor

    func exportSnapshot() async throws -> RepositorySnapshot {
        try await store.exportSnapshot()
    }

    func replaceAll(with snapshot: RepositorySnapshot) async throws {
        try await store.replaceAll(with: snapshot)
    }
}

extension RepositorySet {
    /// Every SwiftData adapter, wired over one shared store actor.
    ///
    /// - Parameter store: The actor owning the store's context.
    init(store: DataStoreActor) {
        self.init(
            ingredients: SwiftDataIngredientRepository(store: store),
            pantry: SwiftDataPantryRepository(store: store),
            recipes: SwiftDataRecipeRepository(store: store),
            mealLogs: SwiftDataMealLogRepository(store: store),
            swipeEvents: SwiftDataSwipeEventRepository(store: store),
            shopping: SwiftDataShoppingRepository(store: store),
            seedState: SwiftDataSeedStateRepository(store: store),
            backup: SwiftDataBackupRepository(store: store))
    }
}
