import Foundation
import SwiftData

/// A table of the store, used to route change notifications to observers.
enum StoreTable: Sendable, Hashable, CaseIterable {
    /// Ingredient catalog.
    case ingredients
    /// Pantry records.
    case pantry
    /// Recipe book.
    case recipes
    /// Meal logs.
    case mealLogs
    /// Swipe events.
    case swipeEvents
    /// Shopping list.
    case shopping
    /// Applied seed version.
    case seedState
}

/// The single owner of the store's `ModelContext`. Every repository adapter of one
/// ``SwiftDataStore`` forwards to the same actor, which gives three guarantees:
///
/// - **Isolation:** the non-`Sendable` context and `@Model` objects never leave this
///   actor; only `KyaCore` value types cross its boundary, so the adapters are `Sendable`
///   without `@unchecked`.
/// - **Atomic batches:** each write runs synchronously inside one actor turn and ends in
///   exactly one `save()`. Any error (mapping, validation or the save itself) rolls the
///   context back, so readers and observers see all of a batch or none of it.
/// - **Change notification:** observers register here, per table. After a successful
///   save, in the same actor turn, every observer of an affected table is signalled, so
///   no write can slip between a save and its notification, whichever adapter wrote it.
///   Signals are buffered newest-only, so a slow or cancelled observer never blocks a
///   write; the observer re-reads the full state on each signal (coalescing is allowed by
///   the `KyaCore` stream contract). This does not use `NotificationCenter` and makes no
///   main-thread assumptions.
@ModelActor
actor DataStoreActor {
    private var observers: [UUID: Observer] = [:]
    private var beforeSave: (@Sendable () throws -> Void)?

    /// One registered observer: the table it watches and how to wake it.
    private struct Observer {
        let table: StoreTable
        let signal: AsyncStream<Void>.Continuation
    }

    // MARK: Observation

    /// Returns a stream that emits `read`'s result immediately and again after every
    /// committed write to `table`, until the consumer stops iterating.
    ///
    /// - Parameters:
    ///   - table: The table whose writes trigger a new element.
    ///   - read: Reads the full current state; a thrown error ends the stream.
    /// - Returns: A new, independent stream.
    nonisolated func observe<Row: Sendable>(
        _ table: StoreTable,
        read: @escaping @Sendable (DataStoreActor) async throws -> [Row]
    ) -> AsyncThrowingStream<[Row], any Error> {
        let (stream, output) = AsyncThrowingStream.makeStream(
            of: [Row].self, throwing: (any Error).self, bufferingPolicy: .bufferingNewest(1))
        let pump = Task {
            let (id, signals) = await self.subscribe(to: table)
            do {
                for await _ in signals {
                    output.yield(try await read(self))
                }
                output.finish()
            } catch {
                output.finish(throwing: error)
            }
            await self.unsubscribe(id)
        }
        output.onTermination = { _ in pump.cancel() }
        return stream
    }

    /// Registers an observer and signals it once, so its first element is read after
    /// registration and no later write can be missed.
    private func subscribe(to table: StoreTable) -> (UUID, AsyncStream<Void>) {
        let (signals, continuation) = AsyncStream.makeStream(
            of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        observers[id] = Observer(table: table, signal: continuation)
        continuation.yield()
        return (id, signals)
    }

    private func unsubscribe(_ id: UUID) {
        observers.removeValue(forKey: id)?.signal.finish()
    }

    /// The number of live observers (for tests: cancelled streams must unregister).
    var observerCount: Int { observers.count }

    // MARK: Writes

    /// Runs `body` as one atomic batch: saves once if anything changed, then signals the
    /// observers of `tables`. On any error the context is rolled back and the error
    /// rethrown, so nothing of the batch is persisted or observed.
    ///
    /// - Parameters:
    ///   - tables: The tables `body` may change.
    ///   - body: The mutations; must not suspend.
    /// - Returns: `body`'s result.
    /// - Throws: `body`'s error, or the save error.
    func write<Result>(
        _ tables: Set<StoreTable>, _ body: () throws -> Result
    ) throws -> Result {
        do {
            let result = try body()
            if modelContext.hasChanges {
                try beforeSave?()
                try modelContext.save()
                for observer in observers.values where tables.contains(observer.table) {
                    observer.signal.yield()
                }
            }
            return result
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Installs a hook that runs just before every save; throwing from it simulates a
    /// storage failure (e.g. a full disk). Test seam only; `nil` removes it.
    ///
    /// - Parameter hook: The hook, or `nil`.
    func setBeforeSaveHook(_ hook: (@Sendable () throws -> Void)?) {
        beforeSave = hook
    }

    // MARK: Generic table helpers

    /// Every record of a table, in storage order (callers sort the mapped rows).
    func records<Record: PersistentModel>(_ type: Record.Type) throws -> [Record] {
        try modelContext.fetch(FetchDescriptor<Record>())
    }

    /// Every record of a table, mapped to `KyaCore` values (unsorted).
    func rows<Record: DomainRecord>(_ type: Record.Type) throws -> [Record.Row] {
        var rows: [Record.Row] = []
        for record in try records(type) {
            rows.append(try record.toRow())
        }
        return rows
    }

    /// Every record of a table, keyed by ``DomainRecord/rowKey``.
    func recordsByKey<Record: DomainRecord>(_ type: Record.Type) throws -> [String: Record] {
        Dictionary(try records(type).map { ($0.rowKey, $0) }) { first, _ in first }
    }

    /// Inserts or fully replaces `rows` (last occurrence of a key wins). Must run inside
    /// ``write(_:_:)``.
    ///
    /// - Parameters:
    ///   - rows: The rows to write.
    ///   - existing: The table's records by key; updated with inserted records.
    ///   - inserted: Called with each newly inserted record (e.g. to assign a position).
    /// - Throws: ``DataStoreError/recordMappingFailed(entity:id:field:)`` if a row cannot
    ///   be encoded.
    func upsert<Record: DomainRecord>(
        _ rows: [Record.Row], into existing: inout [String: Record],
        inserted: (Record) -> Void = { _ in }
    ) throws(DataStoreError) {
        for row in rows {
            let key = Record.rowKey(of: row)
            if let record = existing[key] {
                try record.update(from: row)
            } else {
                let record = Record(rowKey: key)
                try record.update(from: row)
                modelContext.insert(record)
                existing[key] = record
                inserted(record)
            }
        }
    }

    /// Inserts only rows whose key is not stored (first occurrence wins). Must run inside
    /// ``write(_:_:)``.
    ///
    /// - Parameters:
    ///   - rows: Candidate rows.
    ///   - type: The table.
    /// - Returns: The inserted keys, sorted ascending.
    /// - Throws: A fetch error, or a mapping error if a row cannot be encoded.
    func insertMissing<Record: DomainRecord>(
        _ rows: [Record.Row], as type: Record.Type
    ) throws -> [String] {
        var known = Set(try records(type).map(\.rowKey))
        var inserted: [String] = []
        for row in rows {
            let key = Record.rowKey(of: row)
            guard known.insert(key).inserted else { continue }
            let record = Record(rowKey: key)
            try record.update(from: row)
            modelContext.insert(record)
            inserted.append(key)
        }
        return inserted.sorted()
    }

    /// Makes a table hold exactly `rows` (last occurrence of a key wins): updates matching
    /// records in place, inserts new ones and deletes the rest. Must run inside
    /// ``write(_:_:)``.
    ///
    /// - Parameters:
    ///   - rows: The complete new contents.
    ///   - type: The table.
    ///   - inserted: Called with each newly inserted record.
    /// - Returns: Every record now in the table, by key.
    /// - Throws: A fetch error, or a mapping error from ``upsert(_:into:inserted:)``.
    @discardableResult
    func replaceTable<Record: DomainRecord>(
        with rows: [Record.Row], as type: Record.Type, inserted: (Record) -> Void = { _ in }
    ) throws -> [String: Record] {
        var existing = try recordsByKey(type)
        let keep = Set(rows.map(Record.rowKey(of:)))
        for (key, record) in existing where !keep.contains(key) {
            modelContext.delete(record)
            existing.removeValue(forKey: key)
        }
        try upsert(rows, into: &existing, inserted: inserted)
        return existing
    }
}
