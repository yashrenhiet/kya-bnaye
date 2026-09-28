import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Launch state transitions of the composition root, with fake and real bootstraps.
@Suite("AppEnvironment launch")
@MainActor
struct AppEnvironmentTests {
    @Test("starts loading, then becomes ready with the repositories")
    func launchSucceeds() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let environment = AppEnvironment(
            bootstrap: AppBootstrap(open: { repositories }, resetData: {}))
        guard case .loading = environment.launchState else {
            Issue.record("expected .loading before launch")
            return
        }
        await environment.launch()
        #expect(environment.repositories != nil)
    }

    @Test("a launch after the data is ready does not reopen it")
    func launchIsIdempotent() async throws {
        let repositories = try SwiftDataStore.inMemory().repositories
        let opens = CallCounter()
        let environment = AppEnvironment(
            bootstrap: AppBootstrap(
                open: {
                    await opens.increment()
                    return repositories
                }, resetData: {}))
        await environment.launch()
        await environment.launch()
        #expect(await opens.count == 1)
    }

    @Test("an unreadable persistent store becomes a recoverable failed state")
    func unreadableStoreFails() async throws {
        let url = try TestData.temporaryDirectory().appending(path: "Blocked.store")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let environment = AppEnvironment(bootstrap: Self.realBootstrap(storeAt: url))

        await environment.launch()

        guard case .failed(let failure) = environment.launchState else {
            Issue.record("expected .failed, got \(environment.launchState)")
            return
        }
        #expect(failure.kind == .storeUnavailable)
        #expect(failure.canResetData)
    }

    @Test("reset data moves the broken store aside and relaunches seeded")
    func resetRecovers() async throws {
        let url = try TestData.temporaryDirectory().appending(path: SwiftDataStore.storeFileName)
        try Data("garbage".utf8).write(to: url)
        let environment = AppEnvironment(bootstrap: Self.realBootstrap(storeAt: url))
        await environment.launch()
        #expect(environment.repositories == nil)

        await environment.resetDataAndRelaunch()

        let repositories = try #require(environment.repositories)
        #expect(try await repositories.recipes.all().count == 80)
        #expect(try await repositories.seedState.seedVersion() == 1)
    }

    @Test("relaunching against an existing persisted store keeps edits and doesn't reseed")
    func relaunchWithExistingPersistedStore() async throws {
        let url = try TestData.temporaryDirectory().appending(path: SwiftDataStore.storeFileName)

        do {
            let first = AppEnvironment(bootstrap: Self.realBootstrap(storeAt: url))
            await first.launch()
            let repositories = try #require(first.repositories)
            #expect(try await repositories.ingredients.all().count == 224)
            #expect(try await repositories.recipes.all().count == 80)

            let poha = try #require(try await repositories.recipes.recipe(withId: "poha"))
            try await repositories.recipes.upsert([poha.copy(name: "Mum's Poha")])
            try await repositories.recipes.setHidden(true, forRecipeWithId: "upma")
            try await repositories.pantry.setLevels([TestData.pantry("onion", .low)])
            try await repositories.swipeEvents.add(
                SwipeEvent(
                    id: "e1", recipeId: "poha", action: .right, mode: .kitchen,
                    at: TestData.instant, deckSeed: 1))
        }

        // Simulates the app relaunching: a brand-new AppEnvironment/AppBootstrap pointed at
        // the same on-disk store, as happens on every real cold start after the first.
        let second = AppEnvironment(bootstrap: Self.realBootstrap(storeAt: url))
        await second.launch()

        let repositories = try #require(second.repositories)
        let recipes = try await repositories.recipes.all()
        #expect(recipes.count == 80, "seeding must not duplicate rows on relaunch")
        #expect(try await repositories.ingredients.all().count == 224)
        #expect(try await repositories.recipes.recipe(withId: "poha")?.name == "Mum's Poha")
        #expect(try await repositories.recipes.recipe(withId: "upma")?.isHidden == true)
        #expect(try await repositories.pantry.all() == [TestData.pantry("onion", .low)])
        #expect(try await repositories.swipeEvents.all().map(\.id) == ["e1"])
        #expect(try await repositories.seedState.seedVersion() == 1)
    }

    @Test("a seeding failure is reported without offering a reset")
    func seedingFailure() async throws {
        let url = try TestData.temporaryDirectory().appending(path: SwiftDataStore.storeFileName)
        let bootstrap = AppBootstrap(
            open: { () async throws(LaunchFailure) -> RepositorySet in
                try await AppBootstrap.openAndSeed(
                    storeAt: url, seedLoader: .failure(SeedLoadError.seedFolderMissing))
            }, resetData: {})
        let environment = AppEnvironment(bootstrap: bootstrap)

        await environment.launch()

        guard case .failed(let failure) = environment.launchState else {
            Issue.record("expected .failed, got \(environment.launchState)")
            return
        }
        #expect(failure.kind == .seedingFailed)
        #expect(!failure.canResetData)
    }

    @Test("a failed reset stays failed with a reset failure")
    func resetFailure() async {
        let environment = AppEnvironment(
            bootstrap: AppBootstrap(
                open: { () async throws(LaunchFailure) -> RepositorySet in
                    throw LaunchFailure(kind: .storeUnavailable, detail: "corrupt")
                },
                resetData: { () async throws(LaunchFailure) in
                    throw LaunchFailure(kind: .resetFailed, detail: "read-only")
                }))
        await environment.launch()
        await environment.resetDataAndRelaunch()

        guard case .failed(let failure) = environment.launchState else {
            Issue.record("expected .failed, got \(environment.launchState)")
            return
        }
        #expect(failure == LaunchFailure(kind: .resetFailed, detail: "read-only"))
    }

    @Test("the clock and calendar are injected")
    func clockAndCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let pinned = calendar
        let environment = AppEnvironment(
            bootstrap: AppBootstrap(
                open: { () async throws(LaunchFailure) -> RepositorySet in
                    throw LaunchFailure(kind: .storeUnavailable, detail: "")
                },
                resetData: {}),
            now: { TestData.instant }, calendar: { pinned })
        #expect(environment.now() == TestData.instant)
        #expect(environment.calendar.timeZone.identifier == "Asia/Kolkata")
    }

    /// The production open/reset path, pointed at `url` instead of Application Support.
    private static func realBootstrap(storeAt url: URL) -> AppBootstrap {
        let loader = Result { () throws(SeedLoadError) in try SeedLoader.bundled(in: .main) }
        return AppBootstrap(
            open: { () async throws(LaunchFailure) -> RepositorySet in
                try await AppBootstrap.openAndSeed(storeAt: url, seedLoader: loader)
            },
            resetData: { () async throws(LaunchFailure) in
                do {
                    try SwiftDataStore.moveStoreAside(at: url)
                } catch {
                    throw LaunchFailure(kind: .resetFailed, detail: String(describing: error))
                }
            })
    }
}
