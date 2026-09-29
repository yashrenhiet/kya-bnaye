/// Runs a store's write actions one at a time, in the order they were requested.
///
/// A quick double tap starts two actions before the first one's `await` returns. Without
/// this, both read the same stale state (e.g. both see "Plenty" and both write "Low", or
/// both see an empty shopping list and both add the item). Queued, the second action runs
/// only after the first has finished and updated the store, so it reads the new state.
///
/// Never call ``run(_:)`` from inside an action on the same queue: it would wait on itself.
@MainActor
final class SerialWriteQueue {
    private var tail: Task<Void, Never>?

    /// Runs `action` after every action queued before it has finished.
    ///
    /// The action keeps running if the caller is cancelled, so a write is never cut in half.
    ///
    /// - Parameter action: The write to perform.
    /// - Returns: The action's result.
    func run<Result: Sendable>(
        _ action: @escaping @MainActor () async -> Result
    ) async -> Result {
        let previous = tail
        let task = Task {
            await previous?.value
            return await action()
        }
        tail = Task { _ = await task.value }
        return await task.value
    }
}
