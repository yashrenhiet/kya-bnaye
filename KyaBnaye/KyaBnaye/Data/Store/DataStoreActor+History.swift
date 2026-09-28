import Foundation
import KyaCore
import SwiftData

// Append-only history (meal logs, swipe events) and whole-store backup operations.
// Orders and semantics follow the `KyaCore` port documentation (`MealLogRepository`,
// `SwipeEventRepository`, `BackupRepository`).
extension DataStoreActor {
    // MARK: Meal logs

    /// Every meal log, sorted by `cookedAt`, ties by id.
    func allMealLogs() throws -> [MealLog] {
        try rows(MealLogRecord.self).sorted { ($0.cookedAt, $0.id) < ($1.cookedAt, $1.id) }
    }

    /// Appends one meal log.
    ///
    /// - Throws: ``KyaCore/RepositoryError/duplicateId(_:)`` if the id is stored.
    func addMealLog(_ log: MealLog) throws {
        try write([.mealLogs]) {
            let id = log.id
            let count = try modelContext.fetchCount(
                FetchDescriptor<MealLogRecord>(predicate: #Predicate { $0.id == id }))
            guard count == 0 else { throw RepositoryError.duplicateId(id) }
            let record = MealLogRecord(rowKey: id)
            record.update(from: log)
            modelContext.insert(record)
        }
    }

    // MARK: Swipe events

    /// Every swipe event, sorted by time, ties by id.
    func allSwipeEvents() throws -> [SwipeEvent] {
        try rows(SwipeEventRecord.self).sorted { ($0.at, $0.id) < ($1.at, $1.id) }
    }

    /// Appends one swipe event.
    ///
    /// - Throws: ``KyaCore/RepositoryError/duplicateId(_:)`` if the id is stored.
    func addSwipeEvent(_ event: SwipeEvent) throws {
        try write([.swipeEvents]) {
            let id = event.id
            let count = try modelContext.fetchCount(
                FetchDescriptor<SwipeEventRecord>(predicate: #Predicate { $0.id == id }))
            guard count == 0 else { throw RepositoryError.duplicateId(id) }
            let record = SwipeEventRecord(rowKey: id)
            record.update(from: event)
            modelContext.insert(record)
        }
    }

    /// Deletes every swipe event in one save ("Reset my taste"); on failure the log is
    /// unchanged.
    func deleteAllSwipeEvents() throws {
        try write([.swipeEvents]) {
            for record in try records(SwipeEventRecord.self) {
                modelContext.delete(record)
            }
        }
    }

    // MARK: Backup

    /// Reads every table in one actor turn, so no write is half-visible.
    func exportSnapshot() throws -> RepositorySnapshot {
        RepositorySnapshot(
            ingredients: try allIngredients(),
            pantryItems: try allPantryItems(),
            recipes: try allRecipes(),
            mealLogs: try allMealLogs(),
            swipeEvents: try allSwipeEvents(),
            shoppingItems: try allShoppingItems(),
            seedVersion: try seedVersion())
    }

    /// Replaces every table with `snapshot` in one save; on any failure the context is
    /// rolled back and the previous data is kept. Observers of every table are signalled
    /// on success.
    func replaceAll(with snapshot: RepositorySnapshot) throws {
        try write(Set(StoreTable.allCases)) {
            try replaceTable(with: snapshot.ingredients, as: IngredientRecord.self)
            try replaceTable(with: snapshot.pantryItems, as: PantryRecord.self)
            try replaceTable(with: snapshot.recipes, as: RecipeRecord.self)
            try replaceTable(with: snapshot.mealLogs, as: MealLogRecord.self)
            try replaceTable(with: snapshot.swipeEvents, as: SwipeEventRecord.self)
            try replaceShoppingList(with: snapshot.shoppingItems)
            try storeSeedVersion(snapshot.seedVersion)
        }
    }
}
