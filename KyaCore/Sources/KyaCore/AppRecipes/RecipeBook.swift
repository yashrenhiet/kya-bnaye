import Foundation

/// What the Recipes tab is narrowed by: free-text search plus the filter chips
/// (Cookable now / Quick / Favourite / Meal type). Every criterion combines
/// with AND.
public struct RecipeFilter: Sendable, Hashable {
    /// The longest cooking time, in minutes, that counts as "Quick".
    public static let quickMaxMinutes = 30

    /// Free text matched against recipe names (never ingredient aliases).
    public var searchText: String
    /// Keep only recipes with nothing missing.
    public var cookableNow: Bool
    /// Keep only recipes of at most ``quickMaxMinutes``.
    public var quick: Bool
    /// Keep only favourites.
    public var favouritesOnly: Bool
    /// Keep only recipes for this meal slot; `nil` means any.
    public var mealType: MealType?

    /// Creates a filter; the defaults narrow nothing.
    ///
    /// - Parameters:
    ///   - searchText: Free text; defaults to empty.
    ///   - cookableNow: Defaults to `false`.
    ///   - quick: Defaults to `false`.
    ///   - favouritesOnly: Defaults to `false`.
    ///   - mealType: Defaults to `nil` (any).
    public init(
        searchText: String = "",
        cookableNow: Bool = false,
        quick: Bool = false,
        favouritesOnly: Bool = false,
        mealType: MealType? = nil
    ) {
        self.searchText = searchText
        self.cookableNow = cookableNow
        self.quick = quick
        self.favouritesOnly = favouritesOnly
        self.mealType = mealType
    }

    /// Whether any criterion narrows the list (blank search text does not).
    public var isActive: Bool {
        !searchTokens.isEmpty || cookableNow || quick || favouritesOnly || mealType != nil
    }

    /// Whether `recipe` passes every criterion. Does not look at
    /// ``Recipe/isHidden``; ``RecipeBook/browse(_:filter:cookability:)`` does.
    ///
    /// - Parameters:
    ///   - recipe: The candidate.
    ///   - isReady: Whether nothing is missing for it (only read when
    ///     ``cookableNow`` is set).
    /// - Returns: `true` if the recipe should be listed.
    public func matches(_ recipe: Recipe, isReady: @autoclosure () -> Bool) -> Bool {
        if quick && recipe.minutes > Self.quickMaxMinutes { return false }
        if favouritesOnly && !recipe.isFavorite { return false }
        if let mealType, !recipe.mealTypes.contains(mealType) { return false }
        if !matchesSearch(recipe.name) { return false }
        return !cookableNow || isReady()
    }

    /// Every whitespace-separated word must appear in the name, in any order,
    /// ignoring case and diacritics.
    private func matchesSearch(_ name: String) -> Bool {
        searchTokens.allSatisfy {
            name.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var searchTokens: [String] {
        IngredientNormalizer.normalise(searchText).split(separator: " ").map(String.init)
    }
}

/// Listing rules for the recipe book screens.
public enum RecipeBook {
    /// The visible (not hidden) recipes that pass `filter`, sorted by name
    /// (case-insensitive), ties broken by id.
    ///
    /// - Parameters:
    ///   - recipes: The whole recipe book.
    ///   - filter: The active filter.
    ///   - cookability: Evaluates a recipe against the pantry; called only
    ///     when ``RecipeFilter/cookableNow`` is set.
    /// - Returns: The recipes to list.
    public static func browse(
        _ recipes: [Recipe],
        filter: RecipeFilter,
        cookability: (Recipe) -> RecipeCookability
    ) -> [Recipe] {
        sortedByName(
            recipes.filter {
                !$0.isHidden && filter.matches($0, isReady: cookability($0).isReady)
            })
    }

    /// The hidden ("Never show") recipes, sorted like
    /// ``browse(_:filter:cookability:)``, so the user can find and unhide them.
    ///
    /// - Parameter recipes: The whole recipe book.
    /// - Returns: The hidden recipes.
    public static func hidden(_ recipes: [Recipe]) -> [Recipe] {
        sortedByName(recipes.filter(\.isHidden))
    }

    private static func sortedByName(_ recipes: [Recipe]) -> [Recipe] {
        let keyed: [(key: String, recipe: Recipe)] = recipes.map {
            (IngredientNormalizer.normalise($0.name), $0)
        }
        let sorted = keyed.sorted { (lhs, rhs) -> Bool in
            if lhs.key != rhs.key { return lhs.key < rhs.key }
            return lhs.recipe.id < rhs.recipe.id
        }
        return sorted.map(\.recipe)
    }
}
