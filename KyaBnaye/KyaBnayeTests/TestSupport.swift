import Foundation
import KyaCore
import SwiftData

@testable import KyaBnaye

/// Sample values and helpers shared by the Data-layer tests.
enum TestData {
    /// A fixed instant, so tests never depend on the clock.
    static let instant = Date(timeIntervalSince1970: 1_790_000_000)

    /// A catalog ingredient.
    static func ingredient(_ id: String, name: String? = nil) -> Ingredient {
        Ingredient(
            id: id, name: name ?? id, aliases: ["\(id) alias"], category: .sabzi, role: .core,
            buyFrom: .sabziwala, shelfLifeDays: 5)
    }

    /// A pantry record.
    static func pantry(_ id: String, _ level: StockLevel) -> PantryItem {
        PantryItem(ingredientId: id, level: level, updatedAt: instant)
    }

    /// A fresh, empty directory under the temporary directory.
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "KyaBnayeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The error a failing save hook throws.
    struct SimulatedDiskFull: Error, Equatable {}
}

extension DataStoreActor {
    /// Writes an ingredient row whose category is not a valid raw value, as a newer build
    /// (or on-disk corruption) could leave behind.
    func insertIngredientWithUnknownCategory(id: String) throws {
        let record = IngredientRecord(id: id)
        record.name = id
        record.categoryRaw = "spaceFood"
        record.roleRaw = IngredientRole.core.rawValue
        record.buyFromRaw = BuyFrom.kirana.rawValue
        modelContext.insert(record)
        try modelContext.save()
    }
}

/// Counts calls from concurrent closures.
actor CallCounter {
    private(set) var count = 0

    /// Records one call.
    func increment() {
        count += 1
    }
}
