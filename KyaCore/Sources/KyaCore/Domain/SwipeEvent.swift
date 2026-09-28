import Foundation

/// Which of the two ranking strategies a ``SwipeEvent`` happened under.
public enum SwipeMode: String, Sendable, CaseIterable, Codable {
    /// "What can I cook with what I have?"
    case kitchen
    /// "What do I feel like eating?"
    case craving
}

/// What the user did with a card.
public enum SwipeAction: String, Sendable, CaseIterable, Codable {
    /// Liked / picked.
    case right
    /// Skipped.
    case left
    /// Hide this recipe from every deck.
    case neverShow
    /// Reverts an earlier event (see ``SwipeEvent/undoesEventId``).
    case undo
}

/// One swipe, forever.
///
/// The event log is **append-only** (ADR 008): undo is a new
/// ``SwipeAction/undo`` event that references the event it reverses, never a
/// delete. Taste profiles are folded from the full list of these.
///
/// Equality and hashing are value-based over every field. Unlike Dart's
/// `DateTime`, `Date` carries no UTC/local flag, so the same instant always
/// compares equal regardless of how it was constructed.
public struct SwipeEvent: Sendable, Hashable, CustomStringConvertible {
    /// Unique id of this event.
    public let id: String

    /// The ``Recipe/id`` the card showed.
    public let recipeId: String

    /// What the user did.
    public let action: SwipeAction

    /// Which ranking mode the deck was built under.
    public let mode: SwipeMode

    /// When the swipe happened.
    public let at: Date

    /// The seed the deck was built with when this card was shown, so an undo
    /// (and golden tests) can reconstruct exactly what the user saw.
    public let deckSeed: Int

    /// Set only when ``action`` is ``SwipeAction/undo``: the id of the event
    /// being reverted. Not enforced by this type.
    public let undoesEventId: String?

    /// Creates a swipe event.
    ///
    /// - Parameters:
    ///   - id: Unique id of this event.
    ///   - recipeId: The recipe the card showed.
    ///   - action: What the user did.
    ///   - mode: Which ranking mode was active.
    ///   - at: When the swipe happened.
    ///   - deckSeed: The seed the deck was built with.
    ///   - undoesEventId: For undo events, the reverted event's id; defaults
    ///     to `nil`.
    public init(
        id: String,
        recipeId: String,
        action: SwipeAction,
        mode: SwipeMode,
        at: Date,
        deckSeed: Int,
        undoesEventId: String? = nil
    ) {
        self.id = id
        self.recipeId = recipeId
        self.action = action
        self.mode = mode
        self.at = at
        self.deckSeed = deckSeed
        self.undoesEventId = undoesEventId
    }

    /// Shows action, recipe and UTC time, e.g.
    /// `"SwipeEvent(SwipeAction.right poha @ 2025-06-01 12:00:00.000Z)"`.
    public var description: String {
        let time = at.formatted(
            Date.ISO8601FormatStyle(
                dateTimeSeparator: .space, includingFractionalSeconds: true, timeZone: .gmt))
        return "SwipeEvent(SwipeAction.\(action.rawValue) \(recipeId) @ \(time))"
    }
}
