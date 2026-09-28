extension SwipeEvent {
    /// Filters an append-only event log down to the events that still count:
    /// undo events are dropped, and so is every event an undo references.
    ///
    /// This is the single implementation of "how undo interacts with the
    /// append-only log" (ADR 008), shared by ``TasteProfile`` and
    /// ``RankingContext`` so the rule cannot drift between them. An undo that
    /// targets another undo never resurrects anything, and the log may be in
    /// any order.
    ///
    /// - Parameter events: The full event log, in any order.
    /// - Returns: The surviving non-undo events, in their original order.
    public static func activeEvents(_ events: [SwipeEvent]) -> [SwipeEvent] {
        let undoneIds = Set(
            events.compactMap { $0.action == .undo ? $0.undoesEventId : nil })
        return events.filter { $0.action != .undo && !undoneIds.contains($0.id) }
    }
}
