import Foundation

/// Every piece of user data held by the repositories, as one immutable value:
/// what the JSON backup (F7) exports and restores. Mapping to and from the
/// backup file format is the backup codec's job; this type only carries the
/// rows.
///
/// Not `Equatable` on purpose: ``Ingredient`` and ``Recipe`` compare ids only,
/// so a synthesized `==` would hide field differences.
public struct RepositorySnapshot: Sendable {
    /// The whole catalog, sorted by ``Ingredient/id``.
    public let ingredients: [Ingredient]

    /// Every pantry record, sorted by ``PantryItem/ingredientId``.
    public let pantryItems: [PantryItem]

    /// The whole recipe book, sorted by ``Recipe/id``.
    public let recipes: [Recipe]

    /// The cooking history, sorted by ``MealLog/cookedAt`` then ``MealLog/id``.
    public let mealLogs: [MealLog]

    /// The swipe log, sorted by ``SwipeEvent/at`` then ``SwipeEvent/id``.
    public let swipeEvents: [SwipeEvent]

    /// The shopping list, in list order.
    public let shoppingItems: [ShoppingItem]

    /// The applied seed version, or `nil` if seeding never completed.
    public let seedVersion: Int?

    /// Creates a snapshot. Each list is taken as given; the documented orders
    /// are what ``BackupRepository/exportSnapshot()`` produces.
    ///
    /// - Parameters:
    ///   - ingredients: The catalog.
    ///   - pantryItems: The pantry records.
    ///   - recipes: The recipe book.
    ///   - mealLogs: The cooking history.
    ///   - swipeEvents: The swipe log.
    ///   - shoppingItems: The shopping list, in list order.
    ///   - seedVersion: The applied seed version, if any.
    public init(
        ingredients: [Ingredient] = [],
        pantryItems: [PantryItem] = [],
        recipes: [Recipe] = [],
        mealLogs: [MealLog] = [],
        swipeEvents: [SwipeEvent] = [],
        shoppingItems: [ShoppingItem] = [],
        seedVersion: Int? = nil
    ) {
        self.ingredients = ingredients
        self.pantryItems = pantryItems
        self.recipes = recipes
        self.mealLogs = mealLogs
        self.swipeEvents = swipeEvents
        self.shoppingItems = shoppingItems
        self.seedVersion = seedVersion
    }
}

/// Whole-store export and restore for the JSON backup (F7: "export → wipe →
/// import restores everything"). Spans every repository, so an adapter
/// implements it over the same store the other repositories use.
public protocol BackupRepository: Sendable {
    /// Reads every repository as one consistent point-in-time snapshot (no
    /// write is half-visible). Each list is in the order of the corresponding
    /// repository's `all()`.
    ///
    /// - Returns: The snapshot.
    /// - Throws: A storage error if the read fails.
    func exportSnapshot() async throws -> RepositorySnapshot

    /// Replaces **all** stored data with `snapshot`, atomically: afterwards
    /// every repository reads exactly the snapshot's rows (in its documented
    /// order; the shopping list in snapshot order) and the seed version equals
    /// ``RepositorySnapshot/seedVersion`` (`nil` clears it); if it throws,
    /// nothing changed. Every repository's observers then emit the new state.
    /// If an id repeats within one list, the last occurrence wins (as with
    /// `upsert`), including for the append-only logs.
    ///
    /// Precondition: `snapshot` has been decoded and validated by the caller;
    /// this method does not check referential integrity.
    ///
    /// - Parameter snapshot: The data to restore.
    /// - Throws: A storage error; the previous data is kept in that case.
    func replaceAll(with snapshot: RepositorySnapshot) async throws
}

/// Every repository an app needs, wired over one store: the input to the
/// composition root, and the unit the cross-repository contract checks run
/// against.
public struct RepositorySet: Sendable {
    /// The ingredient catalog.
    public let ingredients: any IngredientRepository
    /// The pantry.
    public let pantry: any PantryRepository
    /// The recipe book.
    public let recipes: any RecipeRepository
    /// The cooking history.
    public let mealLogs: any MealLogRepository
    /// The swipe log.
    public let swipeEvents: any SwipeEventRepository
    /// The shopping list.
    public let shopping: any ShoppingRepository
    /// The applied seed version.
    public let seedState: any SeedStateRepository
    /// Whole-store export and restore, over the same store as the others.
    public let backup: any BackupRepository

    /// Creates a set. Every member must share one underlying store, so that
    /// ``backup`` sees and replaces exactly what the others read.
    ///
    /// - Parameters:
    ///   - ingredients: The ingredient catalog.
    ///   - pantry: The pantry.
    ///   - recipes: The recipe book.
    ///   - mealLogs: The cooking history.
    ///   - swipeEvents: The swipe log.
    ///   - shopping: The shopping list.
    ///   - seedState: The applied seed version.
    ///   - backup: Whole-store export and restore.
    public init(
        ingredients: any IngredientRepository,
        pantry: any PantryRepository,
        recipes: any RecipeRepository,
        mealLogs: any MealLogRepository,
        swipeEvents: any SwipeEventRepository,
        shopping: any ShoppingRepository,
        seedState: any SeedStateRepository,
        backup: any BackupRepository
    ) {
        self.ingredients = ingredients
        self.pantry = pantry
        self.recipes = recipes
        self.mealLogs = mealLogs
        self.swipeEvents = swipeEvents
        self.shopping = shopping
        self.seedState = seedState
        self.backup = backup
    }
}
