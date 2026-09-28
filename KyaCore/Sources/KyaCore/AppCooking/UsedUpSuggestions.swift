import Foundation

/// One ingredient the "Used up anything?" sheet offers after cooking.
public struct UsedUpCandidate: Sendable, Hashable {
    /// The ingredient.
    public let ingredient: Ingredient
    /// Its stock level before cooking (never ``StockLevel/out``).
    public let currentLevel: StockLevel

    /// Creates a candidate.
    ///
    /// - Parameters:
    ///   - ingredient: The ingredient.
    ///   - currentLevel: Its level before cooking.
    public init(ingredient: Ingredient, currentLevel: StockLevel) {
        self.ingredient = ingredient
        self.currentLevel = currentLevel
    }
}

/// The "Used up anything?" step after "I made this" (F5). Principle 4,
/// "suggest, never assume": this only proposes candidates and turns the
/// user's explicit choices into pantry writes; nothing changes by default.
public enum UsedUpSuggestions {
    /// Whether cooking plausibly uses `ingredient` up: fresh categories
    /// (sabzi, fruit, dairy) always; ``IngredientCategory/other`` only when it
    /// has a shelf life (eggs, meat, tofu); dry goods never.
    ///
    /// - Parameter ingredient: The ingredient.
    /// - Returns: `true` if it is worth asking about.
    public static func isPerishable(_ ingredient: Ingredient) -> Bool {
        switch ingredient.category {
        case .sabzi, .fruit, .dairy: true
        case .other: ingredient.shelfLifeDays != nil
        case .grains, .dal, .masala, .oilGhee, .packaged: false
        }
    }

    /// The recipe's perishable ingredients that are in stock (a pantry record
    /// that is not out), in recipe order, each once. Optional lines count
    /// too: a garnish that was used is still used. Ids missing from the
    /// catalog are skipped.
    ///
    /// - Parameters:
    ///   - recipe: The recipe just cooked.
    ///   - ingredientsById: The catalog, keyed by id.
    ///   - pantry: Pantry records keyed by ingredient id.
    /// - Returns: The candidates to pre-list.
    public static func candidates(
        for recipe: Recipe,
        ingredientsById: [String: Ingredient],
        pantry: [String: PantryItem]
    ) -> [UsedUpCandidate] {
        var seen = Set<String>()
        return recipe.ingredients.compactMap { line in
            guard seen.insert(line.ingredientId).inserted,
                let ingredient = ingredientsById[line.ingredientId], isPerishable(ingredient),
                let item = pantry[line.ingredientId], item.level.isAvailable
            else { return nil }
            return UsedUpCandidate(ingredient: ingredient, currentLevel: item.level)
        }
    }

    /// The pantry records to write for the user's confirmed choices.
    ///
    /// Only choices that change a stored record's level produce a write; the
    /// written record keeps its expiry and is stamped `now`. Ids with no
    /// pantry record are ignored (nothing to use up).
    ///
    /// - Parameters:
    ///   - choices: New level per ingredient id, as confirmed by the user.
    ///   - pantry: Pantry records keyed by ingredient id.
    ///   - now: The write timestamp.
    /// - Returns: The records for `PantryRepository.setLevels`, sorted by
    ///   ingredient id; empty when nothing changes.
    public static func updates(
        choices: [String: StockLevel],
        pantry: [String: PantryItem],
        now: Date
    ) -> [PantryItem] {
        choices.compactMap { id, level in
            guard let item = pantry[id], item.level != level else { return nil }
            return item.copy(level: level, updatedAt: now)
        }
        .sorted { $0.ingredientId < $1.ingredientId }
    }
}
