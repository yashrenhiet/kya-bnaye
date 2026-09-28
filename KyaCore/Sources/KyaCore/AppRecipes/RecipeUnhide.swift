import Foundation

/// "Unhide" in the recipe book, expressed in the swipe log.
///
/// A dish can be hidden two ways: the ``Recipe/isHidden`` flag, and an active
/// ``SwipeAction/neverShow`` event, which ``RankingContext`` treats as a hard
/// exclusion. Unhiding must clear both, or the dish returns to the book but
/// never to the deck. The flag is cleared through ``RecipeRepository``; the
/// log, being append-only (ADR 008), is corrected by appending an
/// ``SwipeAction/undo`` for every never-show still in force. That keeps
/// ``SwipeEvent/activeEvents(_:)`` the single source of truth for which swipes
/// count, and also lifts the never-show's negative taste signal.
public enum RecipeUnhide {
    /// The undo events that revoke every active never-show of `recipeId`.
    ///
    /// Each undo copies the mode and deck seed of the event it reverts (as a
    /// deck undo does). An empty result means the log needs no change.
    ///
    /// - Parameters:
    ///   - recipeId: The recipe being unhidden.
    ///   - events: The full swipe log, in any order.
    ///   - now: Stamped on the undo events.
    ///   - nextId: Supplies a new, unique id per undo event.
    /// - Returns: The events to append, in the order of the events they undo.
    public static func undoEvents(
        for recipeId: String,
        in events: [SwipeEvent],
        now: Date,
        nextId: () -> String
    ) -> [SwipeEvent] {
        SwipeEvent.activeEvents(events)
            .filter { $0.recipeId == recipeId && $0.action == .neverShow }
            .map { event in
                SwipeEvent(
                    id: nextId(), recipeId: recipeId, action: .undo, mode: event.mode, at: now,
                    deckSeed: event.deckSeed, undoesEventId: event.id)
            }
    }
}
