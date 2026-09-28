import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Store behaviour beyond the shared contract: cross-adapter change notification,
/// rollback on storage failure, typed mapping errors, persistence and open failures.
@Suite("SwiftDataStore")
struct SwiftDataStoreTests {
    // MARK: Change notification

    @Test("a write through one adapter re-emits observers obtained from another")
    func crossAdapterNotification() async throws {
        let store = try SwiftDataStore.inMemory()
        var pantryUpdates = store.repositories.pantry.watchAll().makeAsyncIterator()
        #expect(try await pantryUpdates.next() == [])

        try await store.repositories.backup.replaceAll(
            with: RepositorySnapshot(pantryItems: [TestData.pantry("onion", .low)]))

        #expect(try await pantryUpdates.next() == [TestData.pantry("onion", .low)])
    }

    @Test("a cancelled observer unregisters from the store")
    func cancelledObserverUnregisters() async throws {
        let store = try SwiftDataStore.inMemory()
        let stream = store.repositories.recipes.watchAll()
        let consumer = Task {
            for try await _ in stream {}
        }
        try await waitUntil { await store.actor.observerCount == 1 }
        consumer.cancel()
        _ = await consumer.result
        try await waitUntil { await store.actor.observerCount == 0 }
    }

    // MARK: Atomicity

    @Test("a failed save rolls the whole batch back")
    func failedSaveRollsBack() async throws {
        let store = try SwiftDataStore.inMemory()
        try await store.repositories.ingredients.upsert([TestData.ingredient("a")])
        await store.actor.setBeforeSaveHook { throw TestData.SimulatedDiskFull() }

        await #expect(throws: TestData.SimulatedDiskFull.self) {
            try await store.repositories.ingredients.upsert([
                TestData.ingredient("a", name: "Edited"), TestData.ingredient("b"),
            ])
        }
        await store.actor.setBeforeSaveHook(nil)

        let catalog = try await store.repositories.ingredients.all()
        #expect(catalog.map(\.id) == ["a"])
        #expect(catalog.first?.name == "a")
    }

    @Test("replaceAll is all-or-nothing when the save fails")
    func replaceAllIsAtomic() async throws {
        let store = try SwiftDataStore.inMemory()
        let repositories = store.repositories
        try await repositories.ingredients.upsert([TestData.ingredient("keep")])
        try await repositories.pantry.setLevels([TestData.pantry("keep", .plenty)])
        try await repositories.seedState.setSeedVersion(3)
        await store.actor.setBeforeSaveHook { throw TestData.SimulatedDiskFull() }

        await #expect(throws: TestData.SimulatedDiskFull.self) {
            try await repositories.backup.replaceAll(with: RepositorySnapshot())
        }
        await store.actor.setBeforeSaveHook(nil)

        let snapshot = try await repositories.backup.exportSnapshot()
        #expect(snapshot.ingredients.map(\.id) == ["keep"])
        #expect(snapshot.pantryItems == [TestData.pantry("keep", .plenty)])
        #expect(snapshot.seedVersion == 3)
    }

    @Test("replaceAll with no seed version clears it")
    func replaceAllClearsSeedVersion() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        try await repositories.seedState.setSeedVersion(2)
        try await repositories.backup.replaceAll(with: RepositorySnapshot(seedVersion: nil))
        #expect(try await repositories.seedState.seedVersion() == nil)
    }

    // MARK: Mapping

    @Test("an unknown stored enum value is a typed error, not a crash")
    func unknownRawValueIsTyped() async throws {
        let store = try SwiftDataStore.inMemory()
        try await store.actor.insertIngredientWithUnknownCategory(id: "moon_rock")

        await #expect(
            throws: DataStoreError.recordMappingFailed(
                entity: "Ingredient", id: "moon_rock", field: "category")
        ) {
            try await store.repositories.ingredients.all()
        }
    }

    @Test("a failing read ends watchAll with the error")
    func watchAllThrowsOnUnreadableRow() async throws {
        let store = try SwiftDataStore.inMemory()
        try await store.actor.insertIngredientWithUnknownCategory(id: "moon_rock")
        var iterator = store.repositories.ingredients.watchAll().makeAsyncIterator()
        await #expect(throws: DataStoreError.self) { _ = try await iterator.next() }
    }

    // MARK: Persistence

    @Test("data survives reopening the persistent store")
    func persistentRoundTrip() async throws {
        let url = try TestData.temporaryDirectory().appending(path: SwiftDataStore.storeFileName)
        do {
            let repositories = try SwiftDataStore.persistent(at: url).repositories
            try await repositories.pantry.setLevels([TestData.pantry("onion", .low)])
            try await repositories.seedState.setSeedVersion(1)
        }
        let reopened = try SwiftDataStore.persistent(at: url).repositories
        #expect(try await reopened.pantry.all() == [TestData.pantry("onion", .low)])
        #expect(try await reopened.seedState.seedVersion() == 1)
    }

    @Test("a directory at the store path is a typed open failure")
    func directoryAtStorePath() throws {
        let url = try TestData.temporaryDirectory().appending(path: "Blocked.store")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        #expect(throws: DataStoreError.self) { try SwiftDataStore.persistent(at: url) }
    }

    @Test("a garbage store file fails to open, and moving it aside recovers")
    func garbageStoreRecovers() async throws {
        let directory = try TestData.temporaryDirectory()
        let url = directory.appending(path: SwiftDataStore.storeFileName)
        try Data("definitely not SQLite".utf8).write(to: url)

        let error = #expect(throws: DataStoreError.self) {
            try SwiftDataStore.persistent(at: url)
        }
        guard case .storeUnavailable = error else {
            Issue.record("expected storeUnavailable, got \(String(describing: error))")
            return
        }

        let aside = try #require(try SwiftDataStore.moveStoreAside(at: url, now: TestData.instant))
        #expect(aside.lastPathComponent == "store-1790000000000")
        #expect(
            FileManager.default.fileExists(
                atPath: aside.appending(path: url.lastPathComponent).path))
        let recovered = try SwiftDataStore.persistent(at: url).repositories
        #expect(try await recovered.ingredients.all().isEmpty)
    }

    @Test("moving aside a missing store does nothing")
    func moveAsideWithoutStore() throws {
        let url = try TestData.temporaryDirectory().appending(path: "Missing.store")
        #expect(try SwiftDataStore.moveStoreAside(at: url) == nil)
    }

    @Test("the default store lives in Application Support/KyaBnaye")
    func defaultLocation() throws {
        let url = try SwiftDataStore.defaultStoreURL()
        #expect(url.lastPathComponent == SwiftDataStore.storeFileName)
        #expect(url.deletingLastPathComponent().lastPathComponent == "KyaBnaye")
    }

    @Test("DataStoreError descriptions name the problem")
    func errorDescriptions() {
        #expect(DataStoreError.storeUnavailable(reason: "x").description.contains("x"))
        #expect(
            DataStoreError.recordMappingFailed(entity: "Recipe", id: "poha", field: "base")
                .description.contains("poha"))
        #expect(DataStoreError.resetFailed(reason: "y").description.contains("y"))
    }
}

/// Polls `condition` until it holds, failing after about two seconds.
func waitUntil(
    _ condition: @Sendable () async -> Bool, sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("condition never became true", sourceLocation: sourceLocation)
}
