import Foundation
import KyaCore

/// Decides which Low/Out pantry rows the Shopping list adds on its own, on top of
/// ``KyaCore/ShoppingListBuilder``.
///
/// **When it runs:** on the first load of the Shopping tab and again every time the pantry
/// changes (the pantry stream emits), so marking something Out in Pantry lists it without
/// a pull to refresh. It never runs because the list itself changed, so ticking or deleting
/// a row can't trigger it.
///
/// **No duplicates:** any row already on the list for the same ingredient blocks a new one,
/// ticked or not. (The builder alone lets ticked rows through, which would put a second
/// "Tomato" under a ticked one while the pantry still says Out.)
///
/// **No resurrection:** when the user deletes an auto-added row, the pantry record that
/// caused it is remembered for the rest of the session. The row only comes back if that
/// record changes (a new level, or the same level set again later), because then the
/// pantry is telling us something new. Dismissals live in memory only: after a relaunch
/// the list is rebuilt from the pantry.
struct ShoppingAutoFill: Sendable {
    /// Pantry records whose auto-added row the user deleted, keyed by ingredient id.
    private(set) var dismissed: [String: PantryItem] = [:]

    /// Remembers that the user deleted `item`, so the same pantry state doesn't re-add it.
    /// Rows the user typed or that came from a recipe are not tracked: auto-fill never
    /// creates those.
    ///
    /// - Parameters:
    ///   - item: The deleted shopping row.
    ///   - pantry: The current pantry, keyed by ingredient id.
    mutating func recordDeletion(of item: ShoppingItem, pantry: [String: PantryItem]) {
        guard item.reason == .out || item.reason == .low,
            let ingredientId = item.ingredientId,
            let record = pantry[ingredientId], record.level != .plenty
        else { return }
        dismissed[ingredientId] = record
    }

    /// The rows to add for the current pantry.
    ///
    /// Drops dismissals whose pantry record has changed since, then asks the builder for
    /// Low/Out rows, treating every existing row (ticked or not) and every still-valid
    /// dismissal as already listed.
    ///
    /// - Parameters:
    ///   - pantry: The current pantry records.
    ///   - ingredientsById: The catalog.
    ///   - existing: The whole current list.
    ///   - now: Stamped on new rows.
    ///   - nextId: Supplies ids for new rows.
    /// - Returns: The rows to add, possibly none.
    mutating func newItems(
        pantry: [PantryItem],
        ingredientsById: [String: Ingredient],
        existing: [ShoppingItem],
        now: Date,
        nextId: () -> String
    ) -> [ShoppingItem] {
        let current = Dictionary(pantry.map { ($0.ingredientId, $0) }) { _, last in last }
        dismissed = dismissed.filter { id, record in current[id] == record }
        let eligible = pantry.filter { dismissed[$0.ingredientId] == nil }
        return ShoppingListBuilder().build(
            pantry: eligible,
            ingredientsById: ingredientsById,
            existingItems: existing.map { $0.withIsChecked(false) },
            recipesToShopFor: [],
            now: now,
            nextId: nextId)
    }
}
