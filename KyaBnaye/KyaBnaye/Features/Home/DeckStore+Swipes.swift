import Foundation
import KyaCore

/// Swipe and undo actions for Home's deck (F4, F4b, F5). Split out of `DeckStore.swift` to
/// keep that file under the line-count limit.
extension DeckStore {
    /// Plays `action` on the current top card and appends it to the swipe log.
    ///
    /// A no-op while a write is already in flight, if there is no top card, or if
    /// `expectedTopId` no longer matches the top card — the deck can move under an in-flight
    /// gesture (e.g. a pantry change during `DeckArea`'s fling animation). On failure the
    /// card is left in place and ``actionError`` explains why.
    ///
    /// - Parameters:
    ///   - action: What the user did. Use ``undo()`` to revert, not this method.
    ///   - expectedTopId: The recipe id the caller last saw on top, or `nil` to skip that
    ///     check (as tests do).
    func swipe(_ action: SwipeAction, expectedTopId: String? = nil) async {
        guard !isWriting, let top = cards.first,
            expectedTopId == nil || expectedTopId == top.recipe.id
        else { return }
        isWriting = true
        defer { isWriting = false }
        let event = SwipeEvent(
            id: makeId(), recipeId: top.recipe.id, action: action, mode: mode, at: now(),
            deckSeed: deckSeed)
        do {
            try await repositories.swipeEvents.add(event)
            if action == .neverShow {
                try await repositories.recipes.setHidden(true, forRecipeWithId: top.recipe.id)
            }
        } catch {
            actionError = String(
                localized: "Couldn't save your choice for \(top.recipe.name). Please try again.")
            return
        }
        log.record(event)
        cards.removeFirst()
        sessionSwipedIds.insert(top.recipe.id)
        lastSwipe = LastSwipe(event: event, card: top)
        pickedCard = action == .right ? top : nil
        refreshPicks()
    }

    /// Reverts the last swipe of this session: appends an ``SwipeAction/undo`` event, puts
    /// the card back on top, and — for a reverted "Never show" — unhides the recipe.
    func undo() async {
        guard !isWriting, let last = lastSwipe else { return }
        isWriting = true
        defer { isWriting = false }
        let event = SwipeEvent(
            id: makeId(), recipeId: last.event.recipeId, action: .undo, mode: last.event.mode,
            at: now(), deckSeed: last.event.deckSeed, undoesEventId: last.event.id)
        do {
            try await repositories.swipeEvents.add(event)
            if last.event.action == .neverShow {
                try await repositories.recipes.setHidden(
                    false, forRecipeWithId: last.event.recipeId)
            }
        } catch {
            actionError = String(localized: "Couldn't undo that. Please try again.")
            return
        }
        log.record(event)
        cards.insert(last.card, at: 0)
        sessionSwipedIds.remove(last.event.recipeId)
        lastSwipe = nil
        pickedCard = nil
        refreshPicks()
        confirmation = String(localized: "\(last.card.recipe.name) is back")
    }
}
