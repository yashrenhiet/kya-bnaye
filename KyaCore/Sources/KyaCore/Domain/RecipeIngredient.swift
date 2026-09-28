/// One line of a recipe's ingredient list.
///
/// ``quantityText`` is free text ("2 katori", "1 medium") shown to the user —
/// deliberately not a structured amount + unit, because nothing in v1 does
/// arithmetic on quantities (ADR 005).
///
/// Equality and hashing are value-based over every field.
public struct RecipeIngredient: Sendable, Hashable {
    /// The ``Ingredient/id`` this line refers to.
    public let ingredientId: String

    /// Free-text quantity shown to the user.
    public let quantityText: String

    /// Optional lines (usually garnishes) never count as missing. This is the
    /// per-recipe complement to ``IngredientRole/optional``: an ingredient never
    /// counts as missing if **either** this flag is set **or** its catalog role
    /// is optional (see ``IngredientAvailability``).
    public let isOptional: Bool

    /// Creates a recipe line.
    ///
    /// - Parameters:
    ///   - ingredientId: The ingredient this line refers to.
    ///   - quantityText: Free-text quantity.
    ///   - isOptional: Whether the line is optional; defaults to `false`.
    public init(ingredientId: String, quantityText: String, isOptional: Bool = false) {
        self.ingredientId = ingredientId
        self.quantityText = quantityText
        self.isOptional = isOptional
    }
}
