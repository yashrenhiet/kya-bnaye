import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Backup export/import against a real in-memory store.
@Suite("BackupStore")
@MainActor
struct BackupStoreTests {
    let repositories: RepositorySet
    let store: BackupStore

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        store = BackupStore(
            repositories: repositories, now: { TestData.instant },
            calendar: { ShoppingFixtures.calendar },
            temporaryDirectory: try TestData.temporaryDirectory())
        try await BackupFixtures.fill(repositories)
    }

    @Test("export, erase, import restores every row exactly")
    func roundTrip() async throws {
        let original = try await repositories.backup.exportSnapshot()

        await store.prepareExport()
        let prepared = try #require(store.preparedBackup)
        #expect(store.failure == nil)
        #expect(try Data(contentsOf: prepared.fileURL) == prepared.data)
        try await repositories.backup.replaceAll(with: RepositorySnapshot(seedVersion: 1))
        #expect(try await repositories.recipes.all().isEmpty)

        try store.stageRestore(of: prepared.data)
        await store.confirmRestore(try #require(store.pendingRestore))

        let restored = try await repositories.backup.exportSnapshot()
        BackupFixtures.expectIdentical(restored, original)
        #expect(store.restoredMessage != nil)
        #expect(store.failure == nil)
    }

    @Test("the file is named after the export day in the user's time zone")
    func fileName() async throws {
        await store.prepareExport()
        // 1_790_000_000 is 2026-09-21 in India.
        #expect(store.preparedBackup?.fileName == "kya-bnaye-backup-2026-09-21.json")
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let lateEvening = try #require(
            newYork.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 30))
        )
        #expect(
            backupFileName(for: lateEvening, calendar: newYork)
                == "kya-bnaye-backup-2026-12-31.json")
    }

    @Test("the confirmation counts what the file holds")
    func confirmationCounts() async throws {
        await store.prepareExport()
        let data = try #require(store.preparedBackup?.data)
        try store.stageRestore(of: data)

        let pending = try #require(store.pendingRestore)
        #expect(
            BackupStore.confirmationMessage(for: pending).hasPrefix(
                "Replace everything on this phone with 2 recipes, 3 ingredients, 1 pantry item, "
                    + "1 meal cooked, 2 swipes, 1 shopping item?"))
    }

    @Test(
        "a file that can't be restored gives a friendly message and changes nothing",
        arguments: [
            (Data("not json".utf8), "That file isn't a kya-bnaye backup."),
            (
                Data(#"{"version": 99}"#.utf8),
                "This backup was made by a newer version of kya-bnaye. Update the app, then try again."
            ),
            (
                Data(#"{"version": 1, "ingredients": {}}"#.utf8),
                "This backup file is damaged or incomplete."
            ),
        ])
    func unreadableFiles(data: Data, message: String) async throws {
        let before = try await repositories.backup.exportSnapshot()
        let url = try TestData.temporaryDirectory().appending(path: "bad.json")
        try data.write(to: url)

        await store.readBackup(at: url)

        #expect(store.failure?.message == message)
        #expect(store.pendingRestore == nil)
        BackupFixtures.expectIdentical(try await repositories.backup.exportSnapshot(), before)
    }

    @Test("a real export cut off halfway (interrupted copy) is refused and changes nothing")
    func truncatedExport() async throws {
        await store.prepareExport()
        let data = try #require(store.preparedBackup?.data)
        let before = try await repositories.backup.exportSnapshot()
        let url = try TestData.temporaryDirectory().appending(path: "half.json")
        try data.prefix(data.count / 2).write(to: url)

        await store.readBackup(at: url)

        #expect(store.failure?.message == "That file isn't a kya-bnaye backup.")
        #expect(store.pendingRestore == nil)
        BackupFixtures.expectIdentical(try await repositories.backup.exportSnapshot(), before)
    }

    @Test("a missing file is reported as unreadable")
    func missingFile() async throws {
        await store.readBackup(at: try TestData.temporaryDirectory().appending(path: "gone.json"))
        #expect(store.failure?.message.hasPrefix("We couldn't open that file") == true)
    }

    @Test("a backup whose recipe needs an ingredient it lacks is rejected as damaged")
    func inconsistentBackup() throws {
        let bundle = BackupBundle(recipes: [ShoppingFixtures.palakPaneer])
        let data = try BackupCodec().encode(bundle, exportedAt: TestData.instant)

        #expect(
            throws: BackupImportError.inconsistent(
                detail: "recipe palak_paneer needs unknown ingredient spinach")
        ) {
            try store.stageRestore(of: data)
        }
        #expect(store.pendingRestore == nil)
    }

    @Test("a pantry record without its ingredient, or colliding aliases, is rejected")
    func otherInconsistencies() throws {
        #expect(throws: BackupImportError.self) {
            try BackupIntegrity.check(BackupBundle(pantryItems: [TestData.pantry("ghost", .low)]))
        }
        let twins = [
            ShoppingFixtures.ingredient("a", "Aloo", [], .sabziwala),
            ShoppingFixtures.ingredient("b", "Potato", ["aloo"], .sabziwala),
        ]
        #expect(throws: BackupImportError.self) {
            try BackupIntegrity.check(BackupBundle(ingredients: twins))
        }
    }

    @Test("a failed restore write keeps the old data and says so")
    func restoreWriteFails() async throws {
        let before = try await repositories.backup.exportSnapshot()
        let failing = BackupStore(
            repositories: repositories.replacing(backup: FailingReplace(base: repositories.backup)),
            now: { TestData.instant }, calendar: { ShoppingFixtures.calendar })
        try failing.stageRestore(
            of: try BackupCodec().encode(BackupBundle(), exportedAt: TestData.instant))

        await failing.confirmRestore(try #require(failing.pendingRestore))

        #expect(
            failing.failure?.message == "The backup couldn't be restored. Your data wasn't changed."
        )
        BackupFixtures.expectIdentical(try await repositories.backup.exportSnapshot(), before)
    }

    @Test("cancelling the confirmation changes nothing")
    func cancel() async throws {
        let before = try await repositories.backup.exportSnapshot()
        try store.stageRestore(
            of: try BackupCodec().encode(BackupBundle(), exportedAt: TestData.instant))

        store.cancelRestore()

        #expect(store.pendingRestore == nil)
        BackupFixtures.expectIdentical(try await repositories.backup.exportSnapshot(), before)
    }

    @Test("a restore records the file's seed version, then applies the seed")
    func restoreRecordsFileSeedVersion() async throws {
        var reseeds = 0
        let restoring = BackupStore(
            repositories: repositories, now: { TestData.instant },
            calendar: { ShoppingFixtures.calendar }, reseed: { reseeds += 1 })
        try await repositories.seedState.setSeedVersion(5)
        try restoring.stageRestore(
            of: try BackupCodec().encode(BackupBundle(seedVersion: 3), exportedAt: TestData.instant)
        )

        await restoring.confirmRestore(try #require(restoring.pendingRestore))

        #expect(try await repositories.seedState.seedVersion() == 3)
        #expect(reseeds == 1)
        #expect(restoring.restoredMessage?.hasPrefix("Restored ") == true)
    }

    @Test("a schema-1 file (no seed version) restores with the seed version cleared")
    func restoresSchema1File() async throws {
        let restoring = BackupStore(
            repositories: repositories, now: { TestData.instant },
            calendar: { ShoppingFixtures.calendar })
        let legacy = Data(
            #"""
            {"version": 1, "exportedAt": "2026-09-26T12:00:00.000Z", "ingredients": [],
             "pantryItems": [], "recipes": [], "mealLogs": [], "swipeEvents": [],
             "shoppingItems": []}
            """#.utf8)
        try restoring.stageRestore(of: legacy)

        await restoring.confirmRestore(try #require(restoring.pendingRestore))

        #expect(restoring.failure == nil)
        #expect(try await repositories.seedState.seedVersion() == nil)
        #expect(try await repositories.recipes.all().isEmpty)
    }

    @Test("if the seed can't be applied after a restore, the restore stands and says so")
    func reseedFailsAfterRestore() async throws {
        struct SeedFailure: Error {}
        let restoring = BackupStore(
            repositories: repositories, now: { TestData.instant },
            calendar: { ShoppingFixtures.calendar }, reseed: { throw SeedFailure() })
        try restoring.stageRestore(
            of: try BackupCodec().encode(BackupBundle(seedVersion: 2), exportedAt: TestData.instant)
        )

        await restoring.confirmRestore(try #require(restoring.pendingRestore))

        #expect(restoring.failure == nil)
        #expect(restoring.restoredMessage?.contains("next time you open it") == true)
        #expect(try await repositories.recipes.all().isEmpty)
        #expect(try await repositories.seedState.seedVersion() == 2)
    }
}

/// A backup repository that exports normally but fails every restore.
struct FailingReplace: BackupRepository {
    struct Failure: Error {}
    let base: any BackupRepository

    func exportSnapshot() async throws -> RepositorySnapshot { try await base.exportSnapshot() }
    func replaceAll(with snapshot: RepositorySnapshot) async throws { throw Failure() }
}

/// A small but complete data set touching every repository.
enum BackupFixtures {
    static func fill(_ repositories: RepositorySet) async throws {
        let wanted: Set = ["potato", "spinach", "paneer"]
        try await repositories.ingredients.upsert(
            ShoppingFixtures.catalog.filter { wanted.contains($0.id) })
        try await repositories.recipes.upsert([
            ShoppingFixtures.palakPaneer,
            Recipe(
                id: "aloo_sabzi", name: "Aloo Sabzi", mealTypes: [.lunch], minutes: 20, base: .roti,
                ingredients: [RecipeIngredient(ingredientId: "potato", quantityText: "3")],
                steps: ["Cook"],
                tags: DishTags(
                    region: .north, dishType: .drySabzi, flavours: [.spicy], heaviness: .light,
                    protein: .vegOnly),
                source: .user, isFavorite: true),
        ])
        try await repositories.pantry.setLevels([TestData.pantry("paneer", .low)])
        try await repositories.mealLogs.add(
            MealLog(id: "m1", recipeId: "aloo_sabzi", mealType: .lunch, cookedAt: TestData.instant))
        try await repositories.swipeEvents.add(swipe("s1", .right))
        try await repositories.swipeEvents.add(swipe("s2", .left, offset: 60))
        try await repositories.shopping.upsert([
            try ShoppingItem(
                id: "i1", customName: "Candles", reason: .manual, isChecked: true,
                createdAt: TestData.instant)
        ])
        try await repositories.seedState.setSeedVersion(1)
    }

    static func swipe(_ id: String, _ action: SwipeAction, offset: TimeInterval = 0) -> SwipeEvent {
        SwipeEvent(
            id: id, recipeId: "palak_paneer", action: action, mode: .craving,
            at: TestData.instant + offset, deckSeed: 7)
    }

    /// Field-by-field equality of two snapshots (`Ingredient`/`Recipe` `==` compares ids only).
    static func expectIdentical(
        _ actual: RepositorySnapshot, _ expected: RepositorySnapshot,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            actual.ingredients.count == expected.ingredients.count, sourceLocation: sourceLocation)
        #expect(
            zip(actual.ingredients, expected.ingredients).allSatisfy { $0.isIdentical(to: $1) },
            sourceLocation: sourceLocation)
        #expect(actual.recipes.count == expected.recipes.count, sourceLocation: sourceLocation)
        #expect(
            zip(actual.recipes, expected.recipes).allSatisfy { $0.isIdentical(to: $1) },
            sourceLocation: sourceLocation)
        #expect(actual.pantryItems == expected.pantryItems, sourceLocation: sourceLocation)
        #expect(actual.mealLogs == expected.mealLogs, sourceLocation: sourceLocation)
        #expect(actual.swipeEvents == expected.swipeEvents, sourceLocation: sourceLocation)
        #expect(actual.shoppingItems == expected.shoppingItems, sourceLocation: sourceLocation)
        #expect(actual.seedVersion == expected.seedVersion, sourceLocation: sourceLocation)
    }
}
