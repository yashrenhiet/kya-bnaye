import Foundation
import KyaCore
import SwiftData

// Pantry, shopping list and seed-state operations. Orders and semantics follow the
// `KyaCore` port documentation (`PantryRepository`, `ShoppingRepository`,
// `SeedStateRepository`).
extension DataStoreActor {
    // MARK: Pantry

    /// Every pantry record, sorted by ingredient id.
    func allPantryItems() throws -> [PantryItem] {
        try rows(PantryRecord.self).sorted { $0.ingredientId < $1.ingredientId }
    }

    /// Inserts or fully replaces pantry records, atomically; last occurrence wins.
    func setPantryLevels(_ items: [PantryItem]) throws {
        guard !items.isEmpty else { return }
        try write([.pantry]) {
            var existing = try recordsByKey(PantryRecord.self)
            try upsert(items, into: &existing)
        }
    }

    /// Deletes pantry records by ingredient id, atomically; unknown ids are ignored.
    func deletePantryItems(ingredientIds: Set<String>) throws {
        guard !ingredientIds.isEmpty else { return }
        try write([.pantry]) {
            for record in try records(PantryRecord.self)
            where ingredientIds.contains(record.ingredientId) {
                modelContext.delete(record)
            }
        }
    }

    // MARK: Shopping

    /// Every shopping item in list order (first-insertion order).
    func allShoppingItems() throws -> [ShoppingItem] {
        let ordered = try records(ShoppingItemRecord.self).sorted {
            ($0.position, $0.id) < ($1.position, $1.id)
        }
        var items: [ShoppingItem] = []
        for record in ordered {
            items.append(try record.toRow())
        }
        return items
    }

    /// Appends new items in order or replaces existing ones in place, atomically. A
    /// repeated id keeps the last value at the first occurrence's position.
    func upsertShoppingItems(_ items: [ShoppingItem]) throws {
        guard !items.isEmpty else { return }
        try write([.shopping]) {
            var existing = try recordsByKey(ShoppingItemRecord.self)
            var nextPosition = (existing.values.map(\.position).max() ?? -1) + 1
            try upsert(items, into: &existing) { record in
                record.position = nextPosition
                nextPosition += 1
            }
        }
    }

    /// Ticks one item off or back on, leaving everything else unchanged.
    ///
    /// - Throws: ``KyaCore/RepositoryError/notFound(_:)`` for an unknown id.
    func setShoppingItemChecked(_ isChecked: Bool, forItemWithId id: String) throws {
        try write([.shopping]) {
            var descriptor = FetchDescriptor<ShoppingItemRecord>(
                predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let record = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound(id)
            }
            record.isChecked = isChecked
        }
    }

    /// Deletes items by id, atomically; unknown ids are ignored.
    func deleteShoppingItems(ids: Set<String>) throws {
        guard !ids.isEmpty else { return }
        try write([.shopping]) {
            for record in try records(ShoppingItemRecord.self) where ids.contains(record.id) {
                modelContext.delete(record)
            }
        }
    }

    /// Makes the list hold exactly `items`, in their order (a repeated id keeps the last
    /// value at the first position). Must run inside ``write(_:_:)``.
    func replaceShoppingList(with items: [ShoppingItem]) throws {
        let byKey = try replaceTable(with: items, as: ShoppingItemRecord.self)
        var positioned = Set<String>()
        for item in items where positioned.insert(item.id).inserted {
            if let record = byKey[item.id] {
                record.position = positioned.count - 1
            }
        }
    }

    // MARK: Seed state

    /// The last fully applied seed version, or `nil` if none.
    func seedVersion() throws -> Int? {
        try seedStateRecord()?.version
    }

    /// Records `version` as fully applied, atomically.
    func setSeedVersion(_ version: Int) throws {
        try write([.seedState]) {
            try storeSeedVersion(version)
        }
    }

    /// Stores or clears the seed version. Must run inside ``write(_:_:)``.
    func storeSeedVersion(_ version: Int?) throws {
        let record = try seedStateRecord()
        switch (record, version) {
        case (let record?, let version?):
            record.version = version
        case (let record?, nil):
            modelContext.delete(record)
        case (nil, let version?):
            modelContext.insert(
                SeedStateRecord(key: SeedStateRecord.seedVersionKey, version: version))
        case (nil, nil):
            break
        }
    }

    private func seedStateRecord() throws -> SeedStateRecord? {
        let key = SeedStateRecord.seedVersionKey
        var descriptor = FetchDescriptor<SeedStateRecord>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
