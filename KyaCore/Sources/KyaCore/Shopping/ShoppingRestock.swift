import Foundation

/// The changes "Move bought items to pantry" (F6) makes: pantry records to
/// write and shopping items to clear.
public struct ShoppingRestockPlan: Sendable, Hashable {
    /// One ``StockLevel/plenty`` record per distinct bought catalog
    /// ingredient, sorted by ``PantryItem/ingredientId`` ascending.
    public let pantryUpdates: [PantryItem]

    /// Every checked item's id, in list order — including free-typed items
    /// and ids unknown to the catalog, which leave the list without a pantry
    /// change.
    public let clearedItemIds: [String]

    /// Creates a plan.
    ///
    /// - Parameters:
    ///   - pantryUpdates: Pantry records to write.
    ///   - clearedItemIds: Shopping item ids to delete.
    public init(pantryUpdates: [PantryItem], clearedItemIds: [String]) {
        self.pantryUpdates = pantryUpdates
        self.clearedItemIds = clearedItemIds
    }
}

extension ShoppingListBuilder {
    /// Plans "Move bought items to pantry": every checked item leaves the list
    /// and its catalog ingredient goes back to ``StockLevel/plenty``, with a
    /// fresh estimated expiry from ``Ingredient/shelfLifeDays``.
    ///
    /// Postconditions: unchecked items are untouched; a bought ingredient
    /// listed twice yields one pantry record; free-typed items and ids unknown
    /// to `ingredientsById` produce no pantry record; output order is
    /// independent of dictionary iteration order.
    ///
    /// - Parameters:
    ///   - items: The current shopping list, in list order.
    ///   - ingredientsById: The catalog, keyed by ``Ingredient/id``.
    ///   - now: Stamped as ``PantryItem/updatedAt``; the expiry estimate
    ///     counts from its calendar day.
    ///   - calendar: Calendar (and time zone) defining "day"; defaults to
    ///     ``Foundation/Calendar/kyaDefault``.
    /// - Returns: The pantry records to write and the item ids to clear.
    public func restockPlan(
        items: [ShoppingItem],
        ingredientsById: [String: Ingredient],
        now: Date,
        calendar: Calendar = .kyaDefault
    ) -> ShoppingRestockPlan {
        let bought = items.filter(\.isChecked)
        let restockedIds = Set(bought.compactMap(\.ingredientId)).sorted()
        let updates = restockedIds.compactMap { id -> PantryItem? in
            guard let ingredient = ingredientsById[id] else { return nil }
            return PantryItem(ingredientId: id, level: .plenty, updatedAt: now)
                .withEstimatedExpiry(shelfLifeDays: ingredient.shelfLifeDays, calendar: calendar)
        }
        return ShoppingRestockPlan(pantryUpdates: updates, clearedItemIds: bought.map(\.id))
    }
}
