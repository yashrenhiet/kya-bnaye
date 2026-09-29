import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Double taps and "new item" names that already exist, over a real in-memory store.
@Suite("PantryStore hardening")
@MainActor
struct PantryStoreHardeningTests {
    let repositories: RepositorySet
    let store: PantryStore

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        try await repositories.ingredients.upsert(PantryFixtures.catalog)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let pinned = calendar
        var nextId = 0
        store = PantryStore(
            repositories: repositories, now: { TestData.instant }, calendar: { pinned },
            makeId: {
                nextId += 1
                return "shop-\(nextId)"
            })
    }

    private func row(_ id: String) throws -> PantryRow {
        let rows = store.sections.flatMap(\.rows) + store.assumedStaples
        return try #require(rows.first { $0.id == id }, "no row \(id)")
    }

    private func stored(_ id: String) async throws -> PantryItem? {
        try await repositories.pantry.all().first { $0.ingredientId == id }
    }

    @Test("a double tap on a row moves it two levels, not one")
    func doubleTapCycles() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("potato", .plenty)])
        await store.load()
        let tapped = try row("potato")

        async let first: Void = store.cycle(tapped)
        async let second: Void = store.cycle(tapped)
        _ = await (first, second)

        #expect(try await stored("potato")?.level == .out)
        #expect(try row("potato").effectiveLevel == .out)
    }

    @Test("a double swipe to the shopping list adds the item once")
    func doubleAddToShopping() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("tomato", .low)])
        await store.load()
        let tapped = try row("tomato")

        async let first: Void = store.addToShoppingList(tapped)
        async let second: Void = store.addToShoppingList(tapped)
        _ = await (first, second)

        let list = try await repositories.shopping.all()
        #expect(list.map(\.ingredientId) == ["tomato"])
        #expect(store.confirmation == "Tomato is already on your shopping list")
    }

    @Test("the shopping reason follows the level stored now, not the tapped row's")
    func shoppingReasonUsesCurrentLevel() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("onion", .low)])
        await store.load()
        let staleRow = try row("onion")
        await store.cycle(staleRow)

        await store.addToShoppingList(staleRow)

        #expect(try await repositories.shopping.all().map(\.reason) == [.out])
    }

    @Test("a new item named like an existing alias stocks that ingredient, not a duplicate")
    func newItemMatchingAliasUsesExisting() async throws {
        await store.load()

        let saved = await store.createAndAdd(name: " Aloo ", category: .other, buyFrom: .other)

        #expect(saved)
        #expect(try await stored("potato")?.level == .plenty)
        let catalog = try await repositories.ingredients.all()
        #expect(catalog.count == PantryFixtures.catalog.count)
        #expect(!catalog.contains { $0.isUserCreated })
        // The catalog still loads: no alias collision reached the store.
        await store.load()
        #expect(store.phase == .loaded)
    }
}
