/// The single definition of "is this ingredient available right now", shared
/// by the recommender and the shopping-list builder so the rule is only ever
/// defined once.
public enum IngredientAvailability {
    /// Whether an ingredient counts as available.
    ///
    /// - ``IngredientRole/optional`` (a garnish): always available — never
    ///   missing, never blocks a recipe, never auto-added to the shopping list.
    /// - ``IngredientRole/staple``: available unless its pantry record is
    ///   explicitly ``StockLevel/out`` (no record counts as available).
    /// - Every other role, including `nil` (an id missing from the catalog):
    ///   needs a pantry record whose level ``StockLevel/isAvailable`` (so `low`
    ///   counts) — no record means "never bought".
    ///
    /// Lookup is by exact ``PantryItem/ingredientId`` key, never substring.
    ///
    /// - Parameters:
    ///   - ingredientId: The ingredient to check.
    ///   - role: Its catalog role, or `nil` if it is not in the catalog.
    ///   - pantry: Pantry records keyed by ingredient id.
    /// - Returns: `true` if the ingredient is available.
    public static func isAvailable(
        ingredientId: String,
        role: IngredientRole?,
        pantry: [String: PantryItem]
    ) -> Bool {
        switch role {
        case .optional:
            return true
        case .staple:
            return pantry[ingredientId]?.level != .out
        case .core, .flavor, nil:
            return pantry[ingredientId]?.level.isAvailable ?? false
        }
    }

    /// Whether a recipe line counts as available: a line flagged
    /// ``RecipeIngredient/isOptional`` never counts as missing; otherwise the
    /// ingredient-level rule of ``isAvailable(ingredientId:role:pantry:)``
    /// applies.
    ///
    /// - Parameters:
    ///   - line: The recipe line to check.
    ///   - role: The line ingredient's catalog role, or `nil` if unknown.
    ///   - pantry: Pantry records keyed by ingredient id.
    /// - Returns: `true` if the line does not count as missing.
    public static func isAvailable(
        _ line: RecipeIngredient,
        role: IngredientRole?,
        pantry: [String: PantryItem]
    ) -> Bool {
        line.isOptional || isAvailable(ingredientId: line.ingredientId, role: role, pantry: pantry)
    }
}
