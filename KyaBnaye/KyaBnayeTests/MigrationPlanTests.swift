import Foundation
import KyaCore
import SwiftData
import Testing

@testable import KyaBnaye

/// Smoke tests for the versioned schema and its migration plan, so the first real
/// migration starts from a known-good baseline.
@Suite("Schema and migration plan")
struct MigrationPlanTests {
    @Test("the plan lists v1 as its only schema and the current schema is the newest")
    func planShape() throws {
        let versions = KyaMigrationPlan.schemas.map { $0.versionIdentifier }
        #expect(versions == [Schema.Version(1, 0, 0)])
        #expect(KyaMigrationPlan.stages.isEmpty)
        let newest = try #require(KyaMigrationPlan.schemas.last)
        #expect(newest.versionIdentifier == CurrentSchema.versionIdentifier)
    }

    @Test("schema versions are strictly increasing")
    func versionsIncrease() {
        let versions = KyaMigrationPlan.schemas.map { $0.versionIdentifier }
        #expect(zip(versions, versions.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("v1 declares one entity per stored KyaCore type")
    func entities() {
        let names = Set(Schema(versionedSchema: KyaSchemaV1.self).entities.map(\.name))
        #expect(
            names == [
                "IngredientRecord", "PantryRecord", "RecipeRecord", "MealLogRecord",
                "SwipeEventRecord", "ShoppingItemRecord", "SeedStateRecord",
            ])
    }

    @Test("a store written through the migration plan reopens through it with every table")
    func reopenThroughPlan() async throws {
        let url = try TestData.temporaryDirectory().appending(path: SwiftDataStore.storeFileName)
        let snapshot = RepositorySnapshot(
            ingredients: [TestData.ingredient("onion")],
            pantryItems: [TestData.pantry("onion", .low)],
            mealLogs: [
                MealLog(
                    id: "m1", recipeId: "poha", mealType: .breakfast, cookedAt: TestData.instant)
            ],
            swipeEvents: [
                SwipeEvent(
                    id: "e1", recipeId: "poha", action: .right, mode: .kitchen,
                    at: TestData.instant, deckSeed: -7)
            ],
            shoppingItems: [
                try ShoppingItem(
                    id: "s1", customName: "Foil", reason: .manual, isChecked: false,
                    createdAt: TestData.instant)
            ],
            seedVersion: 1)
        do {
            try await SwiftDataStore.persistent(at: url).repositories.backup
                .replaceAll(with: snapshot)
        }

        let reopened = try await SwiftDataStore.persistent(at: url).repositories.backup
            .exportSnapshot()
        #expect(reopened.ingredients.map(\.id) == ["onion"])
        #expect(reopened.pantryItems == snapshot.pantryItems)
        #expect(reopened.mealLogs == snapshot.mealLogs)
        #expect(reopened.swipeEvents == snapshot.swipeEvents)
        #expect(reopened.shoppingItems == snapshot.shoppingItems)
        #expect(reopened.seedVersion == 1)
    }
}
