/// Everything a full backup/restore (F7 in `AGENTS.md` section 3) needs to
/// round-trip.
///
/// Deliberately a plain bundle, not a "whole app state" singleton —
/// repositories decide how these lists map to their own storage. Lists keep
/// their order through ``BackupCodec``.
///
/// A backup holds everything, seed rows included; trimming seed data (which
/// reloads from the bundle, `AGENTS.md` section 5.6) is a safe, additive
/// optimisation for later.
public struct BackupBundle: Sendable {
    /// The seed version the backed-up catalogue and recipe book were at, or
    /// `nil` when unknown (a schema-1 file, which did not record it). A restore
    /// stores it, so seed rows added since then arrive with the next seed sync.
    public let seedVersion: Int?
    /// Catalogue ingredients, seed and user-created.
    public let ingredients: [Ingredient]
    /// Pantry stock records.
    public let pantryItems: [PantryItem]
    /// Recipes, seed and user-created.
    public let recipes: [Recipe]
    /// Cooking history.
    public let mealLogs: [MealLog]
    /// The append-only swipe log (ADR 008).
    public let swipeEvents: [SwipeEvent]
    /// Shopping-list lines.
    public let shoppingItems: [ShoppingItem]

    /// Creates a bundle; every list defaults to empty.
    ///
    /// - Parameters:
    ///   - seedVersion: The applied seed version, if known.
    ///   - ingredients: Catalogue ingredients.
    ///   - pantryItems: Pantry stock records.
    ///   - recipes: Recipes.
    ///   - mealLogs: Cooking history.
    ///   - swipeEvents: The swipe log.
    ///   - shoppingItems: Shopping-list lines.
    public init(
        seedVersion: Int? = nil,
        ingredients: [Ingredient] = [],
        pantryItems: [PantryItem] = [],
        recipes: [Recipe] = [],
        mealLogs: [MealLog] = [],
        swipeEvents: [SwipeEvent] = [],
        shoppingItems: [ShoppingItem] = []
    ) {
        self.seedVersion = seedVersion
        self.ingredients = ingredients
        self.pantryItems = pantryItems
        self.recipes = recipes
        self.mealLogs = mealLogs
        self.swipeEvents = swipeEvents
        self.shoppingItems = shoppingItems
    }
}
