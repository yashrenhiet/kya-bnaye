import Foundation

/// The "I made this" history. Append-only like the swipe log: a meal log is
/// never edited or deleted. Follows the shared repository contract documented
/// in `Repositories.swift`.
public protocol MealLogRepository: Sendable {
    /// Every meal log, sorted by ``MealLog/cookedAt`` ascending, ties broken by
    /// ``MealLog/id`` ascending.
    ///
    /// - Returns: A snapshot of the history.
    /// - Throws: A storage error if the read fails.
    func all() async throws -> [MealLog]

    /// Observes the history, in the order of ``all()``.
    ///
    /// - Returns: A new stream of full history snapshots.
    func watchAll() -> AsyncThrowingStream<[MealLog], any Error>

    /// Appends one meal log. Postcondition: every previously stored log is
    /// unchanged.
    ///
    /// - Parameter log: The log to append; its id must be new.
    /// - Throws: ``RepositoryError/duplicateId(_:)`` if `log.id` is already
    ///   stored (the stored log is left unchanged), or a storage error.
    func add(_ log: MealLog) async throws
}

/// The append-only swipe log (ADR 008). There is deliberately no update and
/// no per-event delete: an undo is a new ``SwipeEvent`` with
/// ``SwipeAction/undo``, never a mutation of history. Taste profiles are
/// derived from this log, never stored.
///
/// The one exception is ``deleteAll()``, which exists only for the user's
/// explicit "Reset my taste": it forgets the whole log at once, so no partial
/// history (an undo without the swipe it reverts) can ever be left behind.
/// Follows the shared repository contract documented in `Repositories.swift`.
public protocol SwipeEventRepository: Sendable {
    /// Every event, sorted by ``SwipeEvent/at`` ascending, ties broken by
    /// ``SwipeEvent/id`` ascending.
    ///
    /// - Returns: A snapshot of the log.
    /// - Throws: A storage error if the read fails.
    func all() async throws -> [SwipeEvent]

    /// Observes the log, in the order of ``all()``.
    ///
    /// - Returns: A new stream of full log snapshots.
    func watchAll() -> AsyncThrowingStream<[SwipeEvent], any Error>

    /// Appends one event. Postcondition: every previously stored event is
    /// unchanged.
    ///
    /// - Parameter event: The event to append; its id must be new.
    /// - Throws: ``RepositoryError/duplicateId(_:)`` if `event.id` is already
    ///   stored (the stored event is left unchanged), or a storage error.
    func add(_ event: SwipeEvent) async throws

    /// Forgets every event in one atomic write ("Reset my taste"): afterwards
    /// the log reads `[]`; on failure it is unchanged. Observers receive the
    /// empty log. The only removal the log supports; never use it to edit
    /// history.
    ///
    /// - Throws: A storage error; the log is then unchanged.
    func deleteAll() async throws
}
