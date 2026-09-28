import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// First-run seeding from the bundled `seed/` folder into a SwiftData store, seed upgrades
/// and every failure path. Upgrade and corruption cases run on a temporary copy of the
/// bundled folder so the real data is never touched.
@Suite("SeedLoader")
struct SeedLoaderTests {
    /// Marks the test bundle, which has no `seed/` folder.
    private final class TestBundleMarker {}

    // MARK: Happy paths

    @Test("a fresh install seeds 224 ingredients, 80 recipes and the version")
    func freshInstall() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let loader = try SeedLoader.bundled(in: .main)

        let outcome = try await loader.apply(to: repositories)

        guard case .applied(let report) = outcome else {
            Issue.record("expected .applied, got \(outcome)")
            return
        }
        #expect(report.previousVersion == nil)
        #expect(report.appliedVersion == 1)
        #expect(report.insertedIngredientIds.count == 224)
        #expect(report.insertedRecipeIds.count == 80)
        #expect(try await repositories.ingredients.all().count == 224)
        let recipes = try await repositories.recipes.all()
        #expect(recipes.count == 80)
        #expect(recipes.allSatisfy { $0.source == .seed && !$0.isFavorite && !$0.isHidden })
        #expect(try await repositories.seedState.seedVersion() == 1)
    }

    @Test("stored recipes read back identical to the bundled seed")
    func seedRoundTrip() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let loader = try SeedLoader.bundled(in: .main)
        let bundle = try loader.loadBundle(try loader.loadManifest())
        _ = try await loader.apply(to: repositories)

        let expected = bundle.recipes.sorted { $0.id < $1.id }
        let stored = try await repositories.recipes.all()
        #expect(stored.count == expected.count)
        #expect(zip(stored, expected).allSatisfy { $0.isIdentical(to: $1) })
        let catalog = try await repositories.ingredients.all()
        let expectedCatalog = bundle.ingredients.sorted { $0.id < $1.id }
        #expect(zip(catalog, expectedCatalog).allSatisfy { $0.isIdentical(to: $1) })
    }

    @Test("a second launch is a no-op")
    func secondLaunch() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let loader = try SeedLoader.bundled(in: .main)
        _ = try await loader.apply(to: repositories)
        try await repositories.recipes.setFavorite(true, forRecipeWithId: "poha")

        #expect(try await loader.apply(to: repositories) == .upToDate(storedVersion: 1))
        #expect(try await repositories.recipes.all().count == 80)
        #expect(try await repositories.recipes.recipe(withId: "poha")?.isFavorite == true)
    }

    @Test("a newer version inserts only missing ids and keeps user edits")
    func newerVersion() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        _ = try await SeedLoader.bundled(in: .main).apply(to: repositories)
        let poha = try #require(try await repositories.recipes.recipe(withId: "poha"))
        let edited = poha.copy(name: "Mum's Poha", minutes: 12, isFavorite: true)
        try await repositories.recipes.upsert([edited])
        try await repositories.recipes.delete(id: "upma")

        let folder = try SeedFolder.copyOfBundled()
        try folder.addRecipeFragment(
            copying: "poha", as: "masala_poha_v2", name: "Masala Poha Special")
        try folder.setVersion(2)
        let outcome = try await SeedLoader(seedDirectory: folder.url).apply(to: repositories)

        #expect(
            outcome
                == .applied(
                    SeedSyncReport(
                        previousVersion: 1, appliedVersion: 2, insertedIngredientIds: [],
                        insertedRecipeIds: ["masala_poha_v2", "upma"])))
        let stored = try #require(try await repositories.recipes.recipe(withId: "poha"))
        #expect(stored.isIdentical(to: edited))
        #expect(try await repositories.recipes.all().count == 81)
        #expect(try await repositories.seedState.seedVersion() == 2)
    }

    // MARK: Failures (nothing partially applied)

    @Test("a corrupted fragment is a typed error and writes nothing")
    func corruptedFragment() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let folder = try SeedFolder.copyOfBundled()
        try Data("{\"recipes\": [ oops".utf8).write(
            to: folder.url.appending(path: "recipes/sabzi.json"))

        let error = await #expect(throws: SeedLoadError.self) {
            try await SeedLoader(seedDirectory: folder.url).apply(to: repositories)
        }
        guard case .malformed(let format) = error else {
            Issue.record("expected .malformed, got \(String(describing: error))")
            return
        }
        #expect(format.location.hasPrefix("recipes/sabzi.json"))
        try await expectEmpty(repositories)
    }

    @Test("a missing fragment is a typed error and writes nothing")
    func missingFragment() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let folder = try SeedFolder.copyOfBundled()
        try FileManager.default.removeItem(at: folder.url.appending(path: "recipes/misc.json"))

        await #expect(throws: SeedLoadError.unreadableFile(path: "recipes/misc.json")) {
            try await SeedLoader(seedDirectory: folder.url).apply(to: repositories)
        }
        try await expectEmpty(repositories)
    }

    @Test("a recipe naming an unknown ingredient fails validation and writes nothing")
    func invalidContent() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let folder = try SeedFolder.copyOfBundled()
        try folder.addRecipeFragment(
            copying: "poha", as: "mystery_dish", name: "Mystery Dish",
            extraIngredientId: "unobtainium")

        let error = await #expect(throws: SeedLoadError.self) {
            try await SeedLoader(seedDirectory: folder.url).apply(to: repositories)
        }
        guard case .invalid(let issues) = error else {
            Issue.record("expected .invalid, got \(String(describing: error))")
            return
        }
        #expect(issues.contains { $0.contains("unobtainium") })
        try await expectEmpty(repositories)
    }

    @Test("a missing manifest is a typed error")
    func missingManifest() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let empty = try TestData.temporaryDirectory()
        await #expect(throws: SeedLoadError.unreadableFile(path: "manifest.json")) {
            try await SeedLoader(seedDirectory: empty).apply(to: repositories)
        }
        #expect(throws: SeedLoadError.seedFolderMissing) {
            try SeedLoader.bundled(in: Bundle(for: TestBundleMarker.self))
        }
    }

    @Test("a storage failure while seeding leaves the version unrecorded")
    func storageFailure() async throws {
        let store = try SwiftDataStore.inMemory()
        await store.actor.setBeforeSaveHook { throw TestData.SimulatedDiskFull() }

        let error = await #expect(throws: SeedLoadError.self) {
            try await SeedLoader.bundled(in: .main).apply(to: store.repositories)
        }
        guard case .syncFailed = error else {
            Issue.record("expected .syncFailed, got \(String(describing: error))")
            return
        }
        await store.actor.setBeforeSaveHook(nil)
        try await expectEmpty(store.repositories)
    }

    @Test(
        "a save failure after ingredients are inserted leaves recipes and the version for the next launch"
    )
    func partialFailureAfterIngredientsCompletesOnRetry() async throws {
        let store = try SwiftDataStore.inMemory()
        let loader = try SeedLoader.bundled(in: .main)
        let bundle = try loader.loadBundle(try loader.loadManifest())

        // Simulates a crash/disk-full after ingredients are committed but before recipes:
        // insert the ingredients directly, then let the real `apply` run and fail while
        // trying to write recipes.
        try await store.repositories.ingredients.upsert(bundle.ingredients)
        await store.actor.setBeforeSaveHook { throw TestData.SimulatedDiskFull() }

        let error = await #expect(throws: SeedLoadError.self) {
            try await loader.apply(to: store.repositories)
        }
        guard case .syncFailed = error else {
            Issue.record("expected .syncFailed, got \(String(describing: error))")
            return
        }
        #expect(try await store.repositories.ingredients.all().count == 224)
        #expect(try await store.repositories.recipes.all().isEmpty)
        #expect(try await store.repositories.seedState.seedVersion() == nil)

        // The next launch retries and completes the sync without duplicating ingredients.
        await store.actor.setBeforeSaveHook(nil)
        let outcome = try await loader.apply(to: store.repositories)
        guard case .applied(let report) = outcome else {
            Issue.record("expected .applied, got \(outcome)")
            return
        }
        #expect(report.insertedIngredientIds.isEmpty)
        #expect(report.insertedRecipeIds.count == 80)
        #expect(try await store.repositories.ingredients.all().count == 224)
        #expect(try await store.repositories.recipes.all().count == 80)
        #expect(try await store.repositories.seedState.seedVersion() == 1)
    }

    @Test("a save failure after recipes are inserted leaves the version unrecorded for a retry")
    func partialFailureAfterRecipesCompletesOnRetry() async throws {
        let store = try SwiftDataStore.inMemory()
        let loader = try SeedLoader.bundled(in: .main)
        let bundle = try loader.loadBundle(try loader.loadManifest())

        // Simulates a crash right before the version write: ingredients and recipes are
        // already committed, only `setSeedVersion` is left.
        try await store.repositories.ingredients.upsert(bundle.ingredients)
        try await store.repositories.recipes.upsert(bundle.recipes)
        await store.actor.setBeforeSaveHook { throw TestData.SimulatedDiskFull() }

        let error = await #expect(throws: SeedLoadError.self) {
            try await loader.apply(to: store.repositories)
        }
        guard case .syncFailed = error else {
            Issue.record("expected .syncFailed, got \(String(describing: error))")
            return
        }
        #expect(try await store.repositories.seedState.seedVersion() == nil)

        await store.actor.setBeforeSaveHook(nil)
        let outcome = try await loader.apply(to: store.repositories)
        guard case .applied(let report) = outcome else {
            Issue.record("expected .applied, got \(outcome)")
            return
        }
        #expect(report.insertedIngredientIds.isEmpty)
        #expect(report.insertedRecipeIds.isEmpty)
        #expect(try await store.repositories.seedState.seedVersion() == 1)
    }

    @Test("SeedLoadError descriptions name the problem")
    func errorDescriptions() {
        let format = SeedFormatError(location: "recipes/x.json", message: "bad")
        #expect(SeedLoadError.seedFolderMissing.description.contains("manifest.json"))
        #expect(SeedLoadError.unreadableFile(path: "a.json").description.contains("a.json"))
        #expect(SeedLoadError.malformed(format).description.contains("recipes/x.json"))
        #expect(SeedLoadError.invalid(issues: ["R1"]).description.contains("R1"))
        #expect(SeedLoadError.syncFailed(reason: "disk").description.contains("disk"))
    }

    private func expectEmpty(_ repositories: RepositorySet) async throws {
        #expect(try await repositories.ingredients.all().isEmpty)
        #expect(try await repositories.recipes.all().isEmpty)
        #expect(try await repositories.seedState.seedVersion() == nil)
    }
}

/// A writable copy of the bundled `seed/` folder.
private struct SeedFolder {
    let url: URL

    static func copyOfBundled() throws -> SeedFolder {
        let source = try SeedLoader.bundled(in: .main).seedDirectory
        let url = try TestData.temporaryDirectory().appending(path: "seed")
        try FileManager.default.copyItem(at: source, to: url)
        return SeedFolder(url: url)
    }

    /// Sets the manifest's `seedVersion`.
    func setVersion(_ version: Int) throws {
        var manifest = try object(at: "manifest.json")
        manifest["seedVersion"] = version
        try write(manifest, to: "manifest.json")
    }

    /// Adds `recipes/extra.json` holding a copy of recipe `sourceId` under a new id and
    /// name, and lists it in the manifest.
    func addRecipeFragment(
        copying sourceId: String, as id: String, name: String, extraIngredientId: String? = nil
    ) throws {
        let manifestObject = try object(at: "manifest.json")
        let recipeFiles = try #require(manifestObject["recipes"] as? [String])
        var recipe: [String: Any]?
        for file in recipeFiles {
            let rows = try #require(try object(at: file)["recipes"] as? [[String: Any]])
            recipe = recipe ?? rows.first { $0["id"] as? String == sourceId }
        }
        var copy = try #require(recipe)
        copy["id"] = id
        copy["name"] = name
        if let extraIngredientId {
            var lines = try #require(copy["ingredients"] as? [[String: Any]])
            lines.append(["ingredientId": extraIngredientId, "quantityText": "1"])
            copy["ingredients"] = lines
        }
        try write(["recipes": [copy]], to: "recipes/extra.json")
        var manifest = manifestObject
        manifest["recipes"] = recipeFiles + ["recipes/extra.json"]
        try write(manifest, to: "manifest.json")
    }

    private func object(at path: String) throws -> [String: Any] {
        let data = try Data(contentsOf: url.appending(path: path))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func write(_ object: [String: Any], to path: String) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try data.write(to: url.appending(path: path))
    }
}
