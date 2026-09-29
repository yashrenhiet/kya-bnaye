import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Shopping negative paths and races (lane L5).
@Suite("Shopping hardening")
@MainActor
struct ShoppingHardeningTests {
    let repositories: RepositorySet
    let store: ShoppingStore

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        try await repositories.ingredients.upsert(ShoppingFixtures.catalog)
        store = ShoppingFixtures.store(repositories)
    }

    @Test(
        "a double-submitted add (Return, then Add) stores one row",
        arguments: ["tamatar", "Candles"])
    func doubleSubmit(text: String) async throws {
        await store.load()

        async let first = store.addItem(named: text)
        async let second = store.addItem(named: text)
        let results = await [first, second]

        #expect(results.count { if case .added = $0 { true } else { false } } == 1)
        #expect(results.count { if case .alreadyListed = $0 { true } else { false } } == 1)
        #expect(try await repositories.shopping.all().count == 1)
    }

    @Test("an alias and the name typed at once still store one row")
    func aliasAndNameRace() async throws {
        await store.load()

        async let first = store.addItem(named: "aloo")
        async let second = store.addItem(named: "Potato")
        _ = await [first, second]

        #expect(try await repositories.shopping.all().map(\.ingredientId) == ["potato"])
    }

    @Test("after a failed add, the same text can be added again")
    func failedAddDoesNotBlockRetry() async throws {
        let broken = ShoppingFixtures.store(repositories.replacing(shopping: FailingShopping()))
        guard case .failed = await broken.addItem(named: "Candles") else {
            Issue.record("expected the add to fail")
            return
        }
        guard case .failed = await broken.addItem(named: "Candles") else {
            Issue.record("a retry must try the write again, not report alreadyListed")
            return
        }
    }

    @Test("a ticked row doesn't block adding the same thing again (a second trip)")
    func tickedRowAllowsReAdd() async throws {
        await store.load()
        await store.addItem(named: "Candles")
        await store.setChecked(true, itemId: try #require(store.items.first).id)

        #expect(await store.addItem(named: "candles") == .added(name: "candles"))
        #expect(try await repositories.shopping.all().count == 2)
    }

    @Test("moving with nothing ticked changes nothing and shows no error")
    func moveWithNothingTicked() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("tomato", .out)])
        await store.load()

        await store.moveBoughtItemsToPantry()

        #expect(store.actionError == nil)
        #expect(store.items.map(\.ingredientId) == ["tomato"])
        #expect(try await repositories.pantry.all().first?.level == .out)
    }

    @Test("a double-tapped Move restocks once, clears the ticked rows and shows no error")
    func doubleTapMove() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("tomato", .out), TestData.pantry("paneer", .low),
        ])
        await store.load()
        let tomato = try #require(store.items.first { $0.ingredientId == "tomato" })
        await store.setChecked(true, itemId: tomato.id)

        async let first: Void = store.moveBoughtItemsToPantry()
        async let second: Void = store.moveBoughtItemsToPantry()
        _ = await (first, second)

        #expect(store.actionError == nil)
        #expect(try await repositories.shopping.all().map(\.ingredientId) == ["paneer"])
        let pantry = try await repositories.pantry.all()
        #expect(pantry.first { $0.ingredientId == "tomato" }?.level == .plenty)
        #expect(pantry.first { $0.ingredientId == "paneer" }?.level == .low)
    }

    @Test("a bought auto row is not re-added while the pantry says Plenty")
    func boughtRowStaysGone() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("tomato", .out)])
        await store.load()
        await store.setChecked(true, itemId: try #require(store.items.first).id)
        await store.moveBoughtItemsToPantry()

        await store.load()

        #expect(store.items.isEmpty)
    }
}
