import Foundation

/// "Move bought items to pantry" (F6) against the repositories: applies
/// ``ShoppingListBuilder/restockPlan(items:ingredientsById:now:calendar:)``.
///
/// The pantry is written before the list is cleared, so if the app dies in
/// between, the bought items are still ticked on the list and running this
/// again is harmless (it sets the same records to Plenty again). Items ticked
/// while this runs are not cleared, because only the planned ids are deleted.
public struct MoveBoughtItemsToPantry: Sendable {
    private let shopping: any ShoppingRepository
    private let pantry: any PantryRepository
    private let ingredients: any IngredientRepository

    /// Creates the use case over the repositories it reads and writes.
    ///
    /// - Parameters:
    ///   - shopping: The list to read and clear.
    ///   - pantry: Receives the restocked records.
    ///   - ingredients: The catalog, for shelf lives.
    public init(
        shopping: any ShoppingRepository,
        pantry: any PantryRepository,
        ingredients: any IngredientRepository
    ) {
        self.shopping = shopping
        self.pantry = pantry
        self.ingredients = ingredients
    }

    /// Restocks every checked item's ingredient and clears the checked items.
    ///
    /// - Parameters:
    ///   - now: The restock time.
    ///   - calendar: Calendar (and time zone) defining "day" for the expiry
    ///     estimate; defaults to ``Foundation/Calendar/kyaDefault``.
    /// - Returns: The applied plan (empty when nothing was checked, in which
    ///   case nothing is written).
    /// - Throws: Any repository error. If the pantry write fails, nothing
    ///   changed; if the delete fails, the pantry is already restocked.
    @discardableResult
    public func callAsFunction(
        now: Date,
        calendar: Calendar = .kyaDefault
    ) async throws -> ShoppingRestockPlan {
        let items = try await shopping.all()
        let catalog = try await ingredients.all()
        let plan = ShoppingListBuilder().restockPlan(
            items: items,
            ingredientsById: Dictionary(catalog.map { ($0.id, $0) }) { _, last in last },
            now: now,
            calendar: calendar
        )
        if !plan.pantryUpdates.isEmpty {
            try await pantry.setLevels(plan.pantryUpdates)
        }
        if !plan.clearedItemIds.isEmpty {
            try await shopping.delete(ids: Set(plan.clearedItemIds))
        }
        return plan
    }
}
