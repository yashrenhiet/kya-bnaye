import Foundation
import KyaCore

/// "Add missing to shopping list", shared by Home's pick sheet and Today's picks tray.
/// Split out of `DeckStore.swift` to keep that file under the line-count limit.
extension DeckStore {
    /// Puts `recipe`'s missing ingredients on the shopping list (reason "recipe"), skipping
    /// any already listed and not ticked off. A recipe already being added is ignored, so a
    /// double tap from either caller can't write duplicates.
    ///
    /// - Returns: How many items were added.
    @discardableResult
    func addMissingToShoppingList(_ recipe: Recipe) async -> Int {
        guard !addingMissingFor.contains(recipe.id) else { return 0 }
        addingMissingFor.insert(recipe.id)
        defer { addingMissingFor.remove(recipe.id) }
        do {
            let items = RecipeShoppingPlan.missingItems(
                for: recipe, ingredientsById: ingredientsById, pantry: pantryById,
                existingItems: try await repositories.shopping.all(), now: now(), nextId: makeId)
            try await repositories.shopping.upsert(items)
            confirmation =
                items.isEmpty
                ? String(localized: "Everything missing is already on your list")
                : String(localized: "Added \(items.count) to your shopping list")
            return items.count
        } catch {
            actionError = String(localized: "Couldn't update the shopping list. Please try again.")
            return 0
        }
    }
}
