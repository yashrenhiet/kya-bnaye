import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// "Reset my taste", "Reset all data" and About.
@Suite("SettingsStore")
@MainActor
struct SettingsStoreTests {
    let store: SwiftDataStore
    let repositories: RepositorySet

    init() async throws {
        store = try SwiftDataStore.inMemory()
        repositories = store.repositories
        try await BackupFixtures.fill(repositories)
    }

    @Test("reset my taste removes every swipe and keeps everything else")
    func resetTaste() async throws {
        let before = try await repositories.backup.exportSnapshot()
        let store = SettingsStore(repositories: repositories, reseed: {})

        await store.resetTaste()

        let after = try await repositories.backup.exportSnapshot()
        #expect(after.swipeEvents.isEmpty)
        BackupFixtures.expectIdentical(
            after,
            RepositorySnapshot(
                ingredients: before.ingredients, pantryItems: before.pantryItems,
                recipes: before.recipes, mealLogs: before.mealLogs,
                shoppingItems: before.shoppingItems, seedVersion: before.seedVersion))
        #expect(store.doneMessage != nil)
        #expect(store.failureMessage == nil)
    }

    @Test("reset my taste leaves the data alone when the write fails")
    func resetTasteFails() async throws {
        let settings = SettingsStore(repositories: repositories, reseed: {})
        await store.actor.setBeforeSaveHook { throw TestData.SimulatedDiskFull() }

        await settings.resetTaste()
        await store.actor.setBeforeSaveHook(nil)

        #expect(try await repositories.swipeEvents.all().count == 2)
        #expect(settings.failureMessage == "Your taste couldn't be reset. Nothing was changed.")
    }

    @Test("reset my taste keeps hidden dishes hidden")
    func resetTasteKeepsHidden() async throws {
        try await repositories.recipes.setHidden(true, forRecipeWithId: "aloo_sabzi")

        await SettingsStore(repositories: repositories, reseed: {}).resetTaste()

        #expect(try await repositories.recipes.recipe(withId: "aloo_sabzi")?.isHidden == true)
    }

    @Test("reset all data erases everything, then reloads the bundled seed")
    func resetAll() async throws {
        let repositories = repositories
        let store = SettingsStore(repositories: repositories) {
            _ = try await SeedLoader.bundled(in: .main).apply(to: repositories)
        }

        await store.resetAllData()

        #expect(try await repositories.recipes.all().count == 80)
        #expect(try await repositories.recipes.recipe(withId: "aloo_sabzi") == nil)
        #expect(try await repositories.pantry.all().isEmpty)
        #expect(try await repositories.mealLogs.all().isEmpty)
        #expect(try await repositories.swipeEvents.all().isEmpty)
        #expect(try await repositories.shopping.all().isEmpty)
        #expect(try await repositories.seedState.seedVersion() == 1)
        #expect(store.failureMessage == nil)
    }

    @Test("a failed reseed after the erase tells the user to reopen the app")
    func resetAllReseedFails() async throws {
        struct Failure: Error {}
        let store = SettingsStore(repositories: repositories) { throw Failure() }

        await store.resetAllData()

        #expect(try await repositories.recipes.all().isEmpty)
        #expect(try await repositories.seedState.seedVersion() == nil)
        #expect(store.failureMessage?.contains("reopen the app") == true)
    }

    @Test("the environment's reseed hook applies the seed to the ready repositories")
    func environmentReseed() async throws {
        let repositories = repositories
        let loader = Result { () throws(SeedLoadError) in try SeedLoader.bundled(in: .main) }
        let environment = AppEnvironment(
            bootstrap: AppBootstrap(
                open: { repositories }, resetData: {},
                reseed: { (repositories) async throws(LaunchFailure) in
                    try await AppBootstrap.applySeed(loader, to: repositories)
                }))
        try await environment.reapplySeed()
        #expect(try await repositories.recipes.all().count == 2)

        await environment.launch()
        try await repositories.backup.replaceAll(with: RepositorySnapshot())
        try await environment.reapplySeed()

        #expect(try await repositories.recipes.all().count == 80)
    }

    @Test("image credits are parsed from the markdown table; the bundled file has none yet")
    func imageCredits() throws {
        let markdown = """
            # Image credits

            | file | recipe id | title | author | source URL | licence | licence URL |
            |---|---|---|---|---|---|---|
            | images/poha.webp | poha | Poha bowl | A. Cook | https://example.com/p | CC0 | https://c.org |
            | broken |

            Trailing text.
            """
        let credits = AboutInfo.parseCredits(markdown)
        #expect(credits.map(\.file) == ["images/poha.webp"])
        #expect(credits.first?.author == "A. Cook")
        #expect(credits.first?.licence == "CC0")
        #expect(credits.first?.sourceURL?.host() == "example.com")
        #expect(try AboutInfo.imageCredits().isEmpty)
        #expect(!AboutInfo.version().isEmpty)
    }
}
