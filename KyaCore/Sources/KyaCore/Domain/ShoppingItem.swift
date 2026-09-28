import Foundation

/// Why an item landed on the shopping list — shown to the user so an
/// automatically built list still feels explainable.
public enum ShoppingReason: String, Sendable, CaseIterable, Codable {
    /// The ingredient is out of stock.
    case out
    /// The ingredient is running low.
    case low
    /// A recipe the user wants to cook needs it.
    case recipe
    /// The user added it by hand.
    case manual
}

/// A ``ShoppingItem`` invariant violation.
public enum ShoppingItemError: Error, Sendable, Equatable {
    /// Neither a catalog ingredient id nor a free-typed name was given.
    case missingIngredientAndCustomName
}

/// One line on the shopping list.
///
/// Invariant (enforced by the throwing initializer): at least one of
/// ``ingredientId`` and ``customName`` is non-`nil`. Both may be set, in which
/// case ``customName`` wins for display.
///
/// Equality and hashing are value-based over every field.
public struct ShoppingItem: Sendable, Hashable {
    /// Unique id of this item.
    public let id: String

    /// Set when this item maps to a catalog ``Ingredient``; `nil` for a
    /// free-typed item (e.g. "birthday candles").
    public let ingredientId: String?

    /// Free-typed name; expected only when ``ingredientId`` is `nil`.
    public let customName: String?

    /// Why the item is on the list.
    public let reason: ShoppingReason

    /// Set when ``reason`` is ``ShoppingReason/recipe``: which recipe asked for
    /// this ingredient, so the UI can show "for: Palak Paneer".
    public let recipeId: String?

    /// Whether the user ticked it off.
    public let isChecked: Bool

    /// When the item was added.
    public let createdAt: Date

    /// Creates a shopping item.
    ///
    /// - Parameters:
    ///   - id: Unique id of this item.
    ///   - ingredientId: Catalog ingredient id, if catalog-backed.
    ///   - customName: Free-typed name, if not catalog-backed.
    ///   - reason: Why the item is on the list.
    ///   - recipeId: The recipe that asked for it, if any.
    ///   - isChecked: Whether it is ticked off.
    ///   - createdAt: When it was added.
    /// - Throws: ``ShoppingItemError/missingIngredientAndCustomName`` when both
    ///   `ingredientId` and `customName` are `nil`.
    public init(
        id: String,
        ingredientId: String? = nil,
        customName: String? = nil,
        reason: ShoppingReason,
        recipeId: String? = nil,
        isChecked: Bool,
        createdAt: Date
    ) throws(ShoppingItemError) {
        guard ingredientId != nil || customName != nil else {
            throw .missingIngredientAndCustomName
        }
        self.init(
            validatedId: id,
            ingredientId: ingredientId,
            customName: customName,
            reason: reason,
            recipeId: recipeId,
            isChecked: isChecked,
            createdAt: createdAt
        )
    }

    /// Memberwise initializer for callers that already hold the invariant.
    private init(
        validatedId id: String,
        ingredientId: String?,
        customName: String?,
        reason: ShoppingReason,
        recipeId: String?,
        isChecked: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.ingredientId = ingredientId
        self.customName = customName
        self.reason = reason
        self.recipeId = recipeId
        self.isChecked = isChecked
        self.createdAt = createdAt
    }

    /// Returns a copy with ``isChecked`` replaced (e.g. the user ticks the item
    /// off). The invariant already holds, so this cannot fail.
    ///
    /// - Parameter checked: The new checked state.
    /// - Returns: The modified copy; `self` is unchanged.
    public func withIsChecked(_ checked: Bool) -> ShoppingItem {
        ShoppingItem(
            validatedId: id,
            ingredientId: ingredientId,
            customName: customName,
            reason: reason,
            recipeId: recipeId,
            isChecked: checked,
            createdAt: createdAt
        )
    }

    /// The name to display, whether or not the item is catalog-backed.
    ///
    /// Returns ``customName`` when set, without calling `resolveName`;
    /// otherwise resolves ``ingredientId`` through `resolveName` (this type has
    /// no repository dependency).
    ///
    /// - Parameter resolveName: Maps an ingredient id to its display name.
    /// - Returns: The display name.
    public func displayName(_ resolveName: (String) -> String) -> String {
        customName ?? ingredientId.map(resolveName) ?? ""
    }

    /// Creates an auto-generated, catalog-backed item: shared by
    /// ``ShoppingListBuilder`` and ``RecipeShoppingPlan``, the two places that
    /// build a ``ShoppingItem`` from a known ``Ingredient/id`` rather than
    /// free-typed text.
    ///
    /// A non-`nil` `ingredientId` always satisfies the "id or custom name"
    /// invariant, so — unlike ``init(id:ingredientId:customName:reason:recipeId:isChecked:createdAt:)``
    /// — this cannot fail.
    ///
    /// - Parameters:
    ///   - id: Unique id of this item.
    ///   - ingredientId: The catalog ingredient this item is for.
    ///   - reason: Why the item is on the list.
    ///   - recipeId: The recipe that asked for it, if any.
    ///   - createdAt: When it was added.
    /// - Returns: The new item, unchecked.
    static func catalogBacked(
        id: String, ingredientId: String, reason: ShoppingReason, recipeId: String?, createdAt: Date
    ) -> ShoppingItem {
        ShoppingItem(
            validatedId: id,
            ingredientId: ingredientId,
            customName: nil,
            reason: reason,
            recipeId: recipeId,
            isChecked: false,
            createdAt: createdAt
        )
    }
}
