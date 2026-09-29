import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Going back in onboarding and changing an answer: what was saved on the first pass must
/// follow the new answer.
@Suite("Onboarding revisits")
@MainActor
struct OnboardingRevisitTests {
    let repositories: RepositorySet

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        _ = try await SeedLoader.bundled(in: .main).apply(to: repositories)
    }

    private func loadedStore() async throws -> OnboardingStore {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let pinned = calendar
        var nextId = 0
        let store = OnboardingStore(
            repositories: repositories, now: { TestData.instant }, calendar: { pinned },
            makeId: {
                nextId += 1
                return "onboarding-\(nextId)"
            })
        await store.load()
        return store
    }

    private func level(_ id: String) async throws -> StockLevel? {
        try await repositories.pantry.all().first { $0.ingredientId == id }?.level
    }

    @Test("unticking a fridge item after going back removes the Plenty it was given")
    func fridgeUntickRemoves() async throws {
        let store = try await loadedStore()
        for _ in 0..<2 { await store.advance() }
        store.toggleFridgeItem("tomato")
        await store.advance()
        #expect(try await level("tomato") == .plenty)

        store.back()
        store.toggleFridgeItem("tomato")
        await store.advance()

        #expect(store.step == .dishes)
        #expect(try await level("tomato") == nil)
    }

    @Test("unticking restores the record an item had before onboarding (a re-run)")
    func fridgeUntickRestoresPrevious() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("paneer", .low)])
        let store = try await loadedStore()
        for _ in 0..<2 { await store.advance() }
        store.toggleFridgeItem("paneer")
        await store.advance()
        #expect(try await level("paneer") == .plenty)

        store.back()
        store.toggleFridgeItem("paneer")
        await store.advance()

        #expect(try await level("paneer") == .low)
    }

    @Test("swapping a dish after going back leaves exactly the five final picks in force")
    func swappedPickIsRevoked() async throws {
        let store = try await loadedStore()
        for _ in 0..<3 { await store.advance() }
        let ids = store.dishChoices.prefix(6).map(\.id)
        for id in ids.prefix(5) { store.togglePick(id) }
        await store.advance()
        #expect(store.step == .done)

        store.back()
        store.togglePick(ids[0])
        store.togglePick(ids[5])
        await store.advance()

        let active = SwipeEvent.activeEvents(try await repositories.swipeEvents.all())
        #expect(active.count == OnboardingStore.pickTarget)
        #expect(Set(active.map(\.recipeId)) == Set(ids.dropFirst()))
        #expect(active.allSatisfy { $0.action == .right && $0.mode == .craving })
    }
}
