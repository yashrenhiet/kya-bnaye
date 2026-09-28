import Foundation
import KyaCore

/// A keyed, observable table: the single storage engine behind every in-memory
/// repository, so their shared contract is implemented once.
///
/// Rows are kept in first-insertion order; `order` turns them into the
/// documented read order.
actor InMemoryTable<Row: Sendable> {
    typealias Stream = AsyncThrowingStream<[Row], any Error>

    private let key: @Sendable (Row) -> String
    private let order: @Sendable ([Row]) -> [Row]
    private var rows: [Row] = []
    private var observers: [UUID: Stream.Continuation] = [:]

    init(
        key: @escaping @Sendable (Row) -> String,
        order: @escaping @Sendable ([Row]) -> [Row] = { $0 }
    ) {
        self.key = key
        self.order = order
    }

    /// Rows in read order.
    func snapshot() -> [Row] { order(rows) }

    /// The row stored under `id`, if any.
    func row(withId id: String) -> Row? { rows.first { key($0) == id } }

    /// Inserts or replaces rows in place (a replaced row keeps its position).
    func upsert(_ newRows: [Row]) {
        guard !newRows.isEmpty else { return }
        merge(newRows)
        publish()
    }

    /// Inserts only rows whose key is new (first occurrence wins).
    ///
    /// - Returns: The inserted keys, sorted ascending.
    func insertMissing(_ newRows: [Row]) -> [String] {
        var inserted: [String] = []
        for newRow in newRows where row(withId: key(newRow)) == nil {
            rows.append(newRow)
            inserted.append(key(newRow))
        }
        if !inserted.isEmpty { publish() }
        return inserted.sorted()
    }

    /// Appends a row whose key must be new.
    func insertNew(_ newRow: Row) throws(RepositoryError) {
        let id = key(newRow)
        guard row(withId: id) == nil else { throw .duplicateId(id) }
        rows.append(newRow)
        publish()
    }

    /// Replaces the stored row `id` with `transform(row)`.
    func update(id: String, _ transform: (Row) -> Row) throws(RepositoryError) {
        guard let index = rows.firstIndex(where: { key($0) == id }) else { throw .notFound(id) }
        rows[index] = transform(rows[index])
        publish()
    }

    /// Removes every row whose key is in `ids`.
    func delete(ids: Set<String>) {
        let before = rows.count
        rows.removeAll { ids.contains(key($0)) }
        if rows.count != before { publish() }
    }

    /// Replaces every row (a repeated key keeps the last row, first position).
    func replaceAll(_ newRows: [Row]) {
        rows = []
        merge(newRows)
        publish()
    }

    /// A new stream: the current snapshot first, then one after every write.
    nonisolated func observe() -> Stream {
        let (stream, continuation) = Stream.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        Task { await self.addObserver(id, continuation) }
        return stream
    }

    private func merge(_ newRows: [Row]) {
        for newRow in newRows {
            if let index = rows.firstIndex(where: { key($0) == key(newRow) }) {
                rows[index] = newRow
            } else {
                rows.append(newRow)
            }
        }
    }

    private func addObserver(_ id: UUID, _ continuation: Stream.Continuation) {
        observers[id] = continuation
        continuation.yield(snapshot())
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func publish() {
        let current = snapshot()
        for continuation in observers.values {
            continuation.yield(current)
        }
    }
}
