import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Onboarding store transitions over the real bundled seed in an in-memory store.
@Suite("OnboardingStore")
@MainActor
struct OnboardingStoreTests {
    let repositories: RepositorySet
    let store: OnboardingStore

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        _ = try await SeedLoader.bundled(in: .main).apply(to: repositories)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let pinned = calendar
        var nextId = 0
        store = OnboardingStore(
            repositories: repositories, now: { TestData.instant }, calendar: { pinned },
            makeId: {
                nextId += 1
                return "onboarding-\(nextId)"
            })
        await store.load()
    }

    private func pantry() async throws -> [String: PantryItem] {
        Dictionary(
            uniqueKeysWithValues: try await repositories.pantry.all().map { ($0.ingredientId, $0) })
    }

    @Test("loads every staple ticked, common perishables and twenty popular dishes")
    func loads() {
        #expect(store.phase == .ready)
        #expect(store.step == .welcome)
        #expect(store.staples.count == 15)
        #expect(store.tickedStapleIds == Set(store.staples.map(\.id)))
        #expect(store.visibleFridgeItems.first?.id == "onion")
        #expect(store.dishChoices.count == 20)
        #expect(store.dishChoices.first?.id == "aloo_paratha")
    }

    @Test("staples step writes Plenty for ticked staples and Out for unticked ones")
    func staples() async throws {
        await store.advance()
        #expect(store.step == .staples)
        store.toggleStaple("sugar")

        await store.advance()

        #expect(store.step == .fridge)
        let pantry = try await pantry()
        #expect(pantry.count == 15)
        #expect(pantry["sugar"]?.level == .out)
        #expect(pantry["salt"]?.level == .plenty)
    }

    @Test("fridge step is alias-searchable and writes ticked items as Plenty with an estimate")
    func fridge() async throws {
        await store.advance()
        await store.advance()
        store.fridgeQuery = "dahi"
        #expect(store.visibleFridgeItems.map(\.id).first == "curd")
        store.toggleFridgeItem("curd")
        store.fridgeQuery = ""
        #expect(store.visibleFridgeItems.contains { $0.id == "curd" })
        store.toggleFridgeItem("tomato")

        await store.advance()

        #expect(store.step == .dishes)
        let curd = try #require(try await pantry()["curd"])
        #expect(curd.level == .plenty)
        #expect(curd.expiryIsEstimated)
        #expect(curd.expiresOn != nil)
        #expect(try await pantry()["tomato"]?.level == .plenty)
        #expect(try await pantry()["potato"] == nil)
    }

    @Test("five picks become right swipes in Craving mode, recorded once")
    func picks() async throws {
        for _ in 0..<3 { await store.advance() }
        let ids = store.dishChoices.prefix(6).map(\.id)
        for id in ids { store.togglePick(id) }
        #expect(store.pickedRecipeIds.count == OnboardingStore.pickTarget)
        #expect(!store.pickedRecipeIds.contains(ids[5]))
        #expect(!store.canPickMore)

        await store.advance()
        #expect(store.step == .done)
        store.back()
        await store.advance()

        let events = try await repositories.swipeEvents.all()
        #expect(events.count == 5)
        #expect(events.allSatisfy { $0.action == .right && $0.mode == .craving })
        #expect(Set(events.map(\.recipeId)) == Set(ids.prefix(5)))
    }

    @Test("untick frees a slot for another dish")
    func untick() {
        let ids = store.dishChoices.prefix(6).map(\.id)
        for id in ids.prefix(5) { store.togglePick(id) }
        store.togglePick(ids[0])
        store.togglePick(ids[5])
        #expect(store.pickedRecipeIds == Set(ids.dropFirst()))
    }

    @Test("progress counts four steps and hides on the done screen")
    func progress() {
        #expect(OnboardingStore.Step.welcome.progressNumber == 1)
        #expect(OnboardingStore.Step.dishes.progressNumber == 4)
        #expect(OnboardingStore.Step.done.progressNumber == nil)
    }
}

/// The first-launch gate's launch-argument hooks.
@Suite("OnboardingGate")
struct OnboardingGateTests {
    private func defaults() throws -> UserDefaults {
        let name = "OnboardingGateTests-\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test("reset clears completion, re-run marks it incomplete, skip is read from defaults")
    func hooks() throws {
        let defaults = try defaults()
        defaults.set(true, forKey: OnboardingGate.completedKey)
        OnboardingGate.applyLaunchArguments(defaults)
        #expect(defaults.bool(forKey: OnboardingGate.completedKey))

        defaults.set(true, forKey: OnboardingGate.resetArgumentKey)
        OnboardingGate.applyLaunchArguments(defaults)
        #expect(defaults.object(forKey: OnboardingGate.completedKey) == nil)

        defaults.set(true, forKey: OnboardingGate.completedKey)
        OnboardingGate.requestRerun(defaults)
        #expect(!defaults.bool(forKey: OnboardingGate.completedKey))

        #expect(!OnboardingGate.isSkippedForThisLaunch(defaults))
        defaults.set(true, forKey: OnboardingGate.skipArgumentKey)
        #expect(OnboardingGate.isSkippedForThisLaunch(defaults))
    }
}
