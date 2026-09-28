import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// State transitions of the Pantry store over a real in-memory SwiftData store.
@Suite("PantryStore")
@MainActor
struct PantryStoreTests {
    let repositories: RepositorySet
    let calendar: Calendar
    let store: PantryStore

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        self.calendar = calendar
        try await repositories.ingredients.upsert(PantryFixtures.catalog)
        let pinned = calendar
        var nextId = 0
        store = PantryStore(
            repositories: repositories, now: { TestData.instant }, calendar: { pinned },
            makeId: {
                nextId += 1
                return "shop-\(nextId)"
            })
    }

    private func day(_ offset: Int) throws -> Date {
        try #require(
            calendar.date(
                byAdding: .day, value: offset, to: calendar.startOfDay(for: TestData.instant)))
    }

    private func row(_ id: String) throws -> PantryRow {
        let rows = store.sections.flatMap(\.rows) + store.assumedStaples
        return try #require(rows.first { $0.id == id }, "no row \(id)")
    }

    private func stored(_ id: String) async throws -> PantryItem? {
        try await repositories.pantry.all().first { $0.ingredientId == id }
    }

    @Test("loads, groups by category in the fixed order and lists unmarked staples as assumed")
    func loadsAndGroups() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("paneer", .plenty), TestData.pantry("potato", .low),
            TestData.pantry("toor_dal", .out),
        ])
        await store.load()

        #expect(store.phase == .loaded)
        #expect(store.sections.map(\.category) == [.sabzi, .dairy, .dal])
        #expect(store.assumedStaples.map(\.id) == ["salt"])
        #expect(try row("salt").isAssumedStaple)
        #expect(!store.isPantryEmpty)
    }

    @Test("an empty pantry reports the empty state")
    func emptyPantry() async {
        await store.load()
        #expect(store.isPantryEmpty)
        #expect(store.sections.isEmpty)
    }

    @Test("tap cycles Plenty → Low → Out → Plenty, re-estimating expiry on Plenty")
    func cycles() async throws {
        await store.load()
        await store.add(try #require(PantryFixtures.catalog.first { $0.id == "potato" }))
        let fresh = try #require(try await stored("potato"))
        #expect(fresh.level == .plenty)
        #expect(fresh.expiresOn == (try day(30)))
        #expect(fresh.expiryIsEstimated)

        await store.cycle(try row("potato"))
        let low = try #require(try await stored("potato"))
        #expect(low.level == .low)
        #expect(low.expiresOn == (try day(30)))

        await store.cycle(try row("potato"))
        let out = try #require(try await stored("potato"))
        #expect(out.level == .out)
        #expect(out.expiresOn == nil)

        await store.cycle(try row("potato"))
        let again = try #require(try await stored("potato"))
        #expect(again.level == .plenty)
        #expect(again.expiresOn == (try day(30)))
        #expect(again.expiryIsEstimated)
        #expect(try row("potato").effectiveLevel == .plenty)
    }

    @Test("tapping an assumed staple marks it Low")
    func assumedStapleCycle() async throws {
        await store.load()
        await store.cycle(try row("salt"))
        #expect(try await stored("salt")?.level == .low)
        #expect(store.assumedStaples.isEmpty)
    }

    @Test("adding by alias resolves to the canonical ingredient")
    func addByAlias() async throws {
        await store.load()
        store.query = "aloo"
        #expect(store.suggestions.first?.id == "potato")
        #expect(store.newIngredientName == nil)

        await store.add(try #require(store.suggestions.first).ingredient)

        #expect(store.query.isEmpty)
        #expect(try await stored("potato")?.level == .plenty)
        #expect(store.confirmation != nil)
    }

    @Test("unknown text becomes a user ingredient with the chosen category and vendor")
    func unknownBecomesUserIngredient() async throws {
        await store.load()
        store.query = "  Kasuri Methi "
        #expect(store.suggestions.isEmpty)
        #expect(store.newIngredientName == "Kasuri Methi")

        let saved = await store.createAndAdd(
            name: "Kasuri Methi", category: .masala, buyFrom: .kirana)

        #expect(saved)
        let created = try #require(
            try await repositories.ingredients.all().first { $0.id == "user_kasuri_methi" })
        #expect(created.isUserCreated)
        #expect(created.category == .masala)
        #expect(created.buyFrom == .kirana)
        let item = try #require(try await stored("user_kasuri_methi"))
        #expect(item.level == .plenty)
        #expect(item.expiresOn == nil)
        #expect(store.sections.map(\.category) == [.masala])
    }

    @Test("filters: Low shows low and out; Expiring shows soon-to-expire items that are not out")
    func filters() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("potato", .plenty).withExpiresOn(try day(30)),
            TestData.pantry("tomato", .low),
            TestData.pantry("onion", .out).withExpiresOn(try day(-3)),
            TestData.pantry("paneer", .plenty).withExpiresOn(try day(1)),
            TestData.pantry("milk", .low).withExpiresOn(try day(-1)),
        ])
        await store.load()

        store.filter = .low
        #expect(store.sections.flatMap(\.rows).map(\.id).sorted() == ["milk", "onion", "tomato"])
        #expect(store.assumedStaples.isEmpty)

        store.filter = .expiring
        #expect(store.sections.flatMap(\.rows).map(\.id).sorted() == ["milk", "paneer"])

        store.filter = .all
        #expect(store.sections.flatMap(\.rows).count == 5)
    }

    @Test("edit sheet: a picked date is not an estimate; clearing removes it; remove deletes")
    func editAndRemove() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("paneer", .plenty)])
        await store.load()

        #expect(await store.save(try row("paneer"), level: .low, expiry: .date(try day(2))))
        let dated = try #require(try await stored("paneer"))
        #expect(dated.level == .low)
        #expect(dated.expiresOn == (try day(2)))
        #expect(!dated.expiryIsEstimated)

        #expect(await store.save(try row("paneer"), level: .low, expiry: .none))
        #expect(try await stored("paneer")?.expiresOn == nil)

        #expect(await store.remove(try row("paneer")))
        #expect(try await stored("paneer") == nil)
        #expect(store.isPantryEmpty)
    }

    @Test("add to shopping list uses Low/Out as the reason and never duplicates an open item")
    func addToShopping() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("tomato", .low), TestData.pantry("onion", .out),
        ])
        await store.load()

        await store.addToShoppingList(try row("tomato"))
        await store.addToShoppingList(try row("onion"))
        await store.addToShoppingList(try row("tomato"))

        let list = try await repositories.shopping.all()
        #expect(list.map(\.ingredientId) == ["tomato", "onion"])
        #expect(list.map(\.reason) == [.low, .out])
        #expect(list.map(\.id) == ["shop-1", "shop-2"])
        #expect(store.confirmation?.contains("already") == true)
    }

    @Test("expiry badges read expired / today / 1 day / n days and only show within a week")
    func expiryBadges() {
        #expect(ExpiryBadge(daysUntilExpiry: -2, isEstimated: false).text == "expired")
        #expect(ExpiryBadge(daysUntilExpiry: 0, isEstimated: false).text == "today")
        #expect(ExpiryBadge(daysUntilExpiry: 1, isEstimated: true).text == "1 day")
        #expect(ExpiryBadge(daysUntilExpiry: 3, isEstimated: false).text == "3 days")
        #expect(
            ExpiryBadge(daysUntilExpiry: 1, isEstimated: true).accessibilityText
                == "Expires in 1 day, estimated")
        let potato = PantryFixtures.catalog[0]
        let far = PantryRow(
            ingredient: potato, item: TestData.pantry("potato", .plenty), daysUntilExpiry: 8)
        let near = PantryRow(
            ingredient: potato, item: TestData.pantry("potato", .low), daysUntilExpiry: 7)
        let out = PantryRow(
            ingredient: potato, item: TestData.pantry("potato", .out), daysUntilExpiry: 1)
        #expect(far.expiryBadge == nil)
        #expect(near.expiryBadge?.text == "7 days")
        #expect(out.expiryBadge == nil)
    }

    @Test("level cycle and default vendors")
    func rules() {
        #expect(PantryRules.nextLevel(after: nil) == .low)
        #expect(PantryRules.nextLevel(after: .plenty) == .low)
        #expect(PantryRules.nextLevel(after: .low) == .out)
        #expect(PantryRules.nextLevel(after: .out) == .plenty)
        #expect(PantryRules.defaultBuyFrom(for: .sabzi) == .sabziwala)
        #expect(PantryRules.defaultBuyFrom(for: .dairy) == .dairy)
        #expect(PantryRules.defaultBuyFrom(for: .masala) == .kirana)
        #expect(PantryRules.categoryOrder.count == IngredientCategory.allCases.count)
    }
}

/// A small catalog covering several categories, aliases and one staple.
enum PantryFixtures {
    static let catalog: [Ingredient] = [
        Ingredient(
            id: "potato", name: "Potato", aliases: ["aloo", "batata"], category: .sabzi,
            role: .core, buyFrom: .sabziwala, shelfLifeDays: 30),
        Ingredient(
            id: "tomato", name: "Tomato", aliases: ["tamatar"], category: .sabzi, role: .core,
            buyFrom: .sabziwala, shelfLifeDays: 7),
        Ingredient(
            id: "onion", name: "Onion", aliases: ["pyaaz"], category: .sabzi, role: .core,
            buyFrom: .sabziwala, shelfLifeDays: 30),
        Ingredient(
            id: "paneer", name: "Paneer", category: .dairy, role: .core, buyFrom: .dairy,
            shelfLifeDays: 4),
        Ingredient(
            id: "milk", name: "Milk", aliases: ["doodh"], category: .dairy, role: .core,
            buyFrom: .dairy, shelfLifeDays: 2),
        Ingredient(
            id: "toor_dal", name: "Toor Dal", aliases: ["arhar dal"], category: .dal, role: .core,
            buyFrom: .kirana, shelfLifeDays: 365),
        Ingredient(
            id: "salt", name: "Salt", aliases: ["namak"], category: .masala, role: .staple,
            buyFrom: .kirana),
    ]
}
