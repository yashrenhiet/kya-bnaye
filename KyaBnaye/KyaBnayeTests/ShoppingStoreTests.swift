import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Shopping tab behaviour against a real in-memory store.
@Suite("ShoppingStore")
@MainActor
struct ShoppingStoreTests {
    let repositories: RepositorySet
    let store: ShoppingStore

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        try await repositories.ingredients.upsert(ShoppingFixtures.catalog)
        try await repositories.recipes.upsert([ShoppingFixtures.palakPaneer])
        store = ShoppingFixtures.store(repositories)
    }

    @Test("load lists Low and Out pantry items with their reason, grouped by vendor")
    func autoFillsLowAndOut() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("paneer", .low), TestData.pantry("tomato", .out),
            TestData.pantry("besan", .out), TestData.pantry("onion", .plenty),
        ])
        await store.load()

        #expect(store.phase == .loaded)
        #expect(store.sections.map(\.vendor) == [.sabziwala, .kirana, .dairy])
        let rows = store.sections.flatMap(\.rows)
        #expect(rows.map(\.name) == ["Tomato", "Besan", "Paneer"])
        #expect(rows.map(\.reasonText) == ["from: Out", "from: Out", "from: Low"])
        #expect(try await repositories.shopping.all().count == 3)
    }

    @Test("running auto-fill again never duplicates rows, ticked or not")
    func noDuplicates() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("tomato", .out), TestData.pantry("paneer", .low),
        ])
        await store.load()
        let tomato = try #require(store.items.first { $0.ingredientId == "tomato" })
        await store.setChecked(true, itemId: tomato.id)

        await store.load()
        await ShoppingFixtures.store(repositories).load()

        let stored = try await repositories.shopping.all()
        #expect(stored.count == 2)
        #expect(stored.first { $0.ingredientId == "tomato" }?.isChecked == true)
    }

    @Test("a deleted auto row stays gone until its pantry record changes")
    func deletionIsRemembered() async throws {
        try await repositories.pantry.setLevels([TestData.pantry("tomato", .out)])
        await store.load()
        let tomato = try #require(store.items.first)

        await store.delete(itemIds: [tomato.id])
        await store.load()
        #expect(store.items.isEmpty)

        try await repositories.pantry.setLevels([
            PantryItem(ingredientId: "tomato", level: .low, updatedAt: TestData.instant + 60)
        ])
        await store.load()
        #expect(store.items.map(\.ingredientId) == ["tomato"])
        #expect(store.items.first?.reason == .low)
    }

    @Test("deleting a manual row does not block auto-fill for that ingredient")
    func manualDeletionNotRemembered() async throws {
        await store.load()
        await store.addItem(named: "tamatar")
        await store.delete(itemIds: Set(store.items.map(\.id)))
        try await repositories.pantry.setLevels([TestData.pantry("tomato", .out)])

        await store.load()

        #expect(store.items.map(\.reason) == [.out])
    }

    @Test("a pantry change while observing adds the new Out item")
    func observesPantry() async throws {
        await store.load()
        let observer = Task { await store.observe() }
        defer { observer.cancel() }

        try await repositories.pantry.setLevels([TestData.pantry("besan", .out)])

        try await waitUntil { store.items.contains { $0.ingredientId == "besan" } }
        #expect(try await repositories.shopping.all().count == 1)
    }

    @Test("typed text matching a name or alias becomes that ingredient, anything else stays typed")
    func manualAdd() async throws {
        await store.load()

        #expect(await store.addItem(named: "  Tamatar ") == .added(name: "Tomato"))
        #expect(await store.addItem(named: "Birthday candles") == .added(name: "Birthday candles"))
        #expect(await store.addItem(named: "tomato") == .alreadyListed(name: "Tomato"))
        #expect(
            await store.addItem(named: "birthday  CANDLES")
                == .alreadyListed(name: "Birthday candles"))
        #expect(await store.addItem(named: "   ") == .blank)

        let stored = try await repositories.shopping.all()
        #expect(stored.map(\.ingredientId) == ["tomato", nil])
        #expect(stored.map(\.customName) == [nil, "Birthday candles"])
        #expect(stored.allSatisfy { $0.reason == .manual })
        #expect(
            store.sections.flatMap(\.rows).map(\.reasonText) == ["added by you", "added by you"])
    }

    @Test("suggestions match names and aliases by prefix first")
    func suggestions() async {
        await store.load()

        let potato = store.suggestions(for: "alo")
        #expect(potato.map(\.name) == ["Potato"])
        #expect(potato.first?.matchedAlias == "aloo")
        #expect(store.suggestions(for: "  ").isEmpty)
        #expect(store.suggestions(for: "a").first?.name == "Potato")
    }

    @Test("moving bought items restocks them to Plenty and clears only ticked rows")
    func moveBought() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("tomato", .out), TestData.pantry("paneer", .low),
        ])
        await store.load()
        await store.addItem(named: "Birthday candles")
        for item in store.items where item.ingredientId != "paneer" {
            await store.setChecked(true, itemId: item.id)
        }
        #expect(store.checkedCount == 2)

        await store.moveBoughtItemsToPantry()

        #expect(store.items.map(\.ingredientId) == ["paneer"])
        let tomato = try #require(
            try await repositories.pantry.all().first { $0.ingredientId == "tomato" })
        #expect(tomato.level == .plenty)
        #expect(tomato.expiryIsEstimated)
        #expect(
            tomato.daysUntilExpiry(asOf: TestData.instant, calendar: ShoppingFixtures.calendar) == 5
        )
        #expect(store.actionError == nil)
    }

    @Test("recipe rows name their recipe; an unknown recipe still explains itself")
    func recipeReason() async throws {
        try await repositories.shopping.upsert([
            try ShoppingItem(
                id: "a", ingredientId: "spinach", reason: .recipe, recipeId: "palak_paneer",
                isChecked: false, createdAt: TestData.instant),
            try ShoppingItem(
                id: "b", ingredientId: "mystery", reason: .recipe, recipeId: "gone",
                isChecked: false, createdAt: TestData.instant),
        ])
        await store.load()

        let rows = store.sections.flatMap(\.rows)
        #expect(rows.map(\.reasonText) == ["from: Palak Paneer", "from: a recipe"])
        #expect(store.sections.map(\.vendor) == [.sabziwala, .other])
        #expect(rows.last?.name == "mystery")
    }

    @Test("share text groups still-to-buy items by vendor and leaves ticked ones out")
    func shareText() async throws {
        try await repositories.pantry.setLevels([
            TestData.pantry("paneer", .out), TestData.pantry("tomato", .out),
            TestData.pantry("potato", .low),
        ])
        await store.load()
        await store.addItem(named: "Candles")
        let potato = try #require(store.items.first { $0.ingredientId == "potato" })
        await store.setChecked(true, itemId: potato.id)

        #expect(
            store.shareText == """
                Shopping list

                SABZIWALA
                - Tomato

                DAIRY
                - Paneer

                OTHER
                - Candles
                """)
    }

    @Test("share text is empty when everything is ticked or the list is empty")
    func emptyShareText() async throws {
        await store.load()
        #expect(store.shareText.isEmpty)
        await store.addItem(named: "Candles")
        await store.setChecked(true, itemId: try #require(store.items.first).id)
        #expect(store.shareText.isEmpty)
    }

    @Test("a failed read shows the error state, and a failed write an alert")
    func failures() async throws {
        let broken = ShoppingFixtures.store(repositories.replacing(shopping: FailingShopping()))
        await broken.load()
        guard case .failed = broken.phase else {
            Issue.record("expected .failed, got \(broken.phase)")
            return
        }
        await broken.setChecked(true, itemId: "x")
        #expect(broken.actionError != nil)
        guard case .failed = await broken.addItem(named: "tomato") else {
            Issue.record("expected the add to fail")
            return
        }
    }
}

/// Shared shopping test data.
enum ShoppingFixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .gmt
        return calendar
    }()

    static let catalog: [Ingredient] = [
        ingredient("tomato", "Tomato", ["tamatar"], .sabziwala),
        ingredient("potato", "Potato", ["aloo", "batata"], .sabziwala),
        ingredient("spinach", "Spinach", ["palak"], .sabziwala),
        ingredient("onion", "Onion", ["pyaz"], .sabziwala),
        ingredient("besan", "Besan", ["gram flour"], .kirana),
        ingredient("paneer", "Paneer", [], .dairy),
    ]

    static let palakPaneer = Recipe(
        id: "palak_paneer", name: "Palak Paneer", mealTypes: [.dinner], minutes: 30, base: .roti,
        ingredients: [
            RecipeIngredient(ingredientId: "spinach", quantityText: "1 bunch"),
            RecipeIngredient(ingredientId: "paneer", quantityText: "200 g"),
        ],
        steps: ["Blanch", "Blend", "Simmer"],
        tags: DishTags(
            region: .north, dishType: .curry, flavours: [.savoury], heaviness: .medium,
            protein: .paneer),
        source: .seed)

    static func ingredient(
        _ id: String, _ name: String, _ aliases: [String], _ buyFrom: BuyFrom
    ) -> Ingredient {
        Ingredient(
            id: id, name: name, aliases: aliases, category: .sabzi, role: .core, buyFrom: buyFrom,
            shelfLifeDays: 5)
    }

    @MainActor
    static func store(_ repositories: RepositorySet) -> ShoppingStore {
        ShoppingStore(repositories: repositories, now: { TestData.instant }, calendar: { calendar })
    }
}

/// A shopping repository whose every call fails.
struct FailingShopping: ShoppingRepository {
    struct Failure: Error {}

    func all() async throws -> [ShoppingItem] { throw Failure() }
    func watchAll() -> AsyncThrowingStream<[ShoppingItem], any Error> {
        AsyncThrowingStream { $0.finish(throwing: Failure()) }
    }
    func upsert(_ items: [ShoppingItem]) async throws { throw Failure() }
    func setChecked(_ isChecked: Bool, forItemWithId id: String) async throws { throw Failure() }
    func delete(ids: Set<String>) async throws { throw Failure() }
}

extension RepositorySet {
    /// A copy with some members swapped, for failure injection.
    func replacing(
        shopping: (any ShoppingRepository)? = nil, backup: (any BackupRepository)? = nil
    ) -> RepositorySet {
        RepositorySet(
            ingredients: ingredients, pantry: pantry, recipes: recipes, mealLogs: mealLogs,
            swipeEvents: swipeEvents, shopping: shopping ?? self.shopping, seedState: seedState,
            backup: backup ?? self.backup)
    }
}

/// Polls `condition` on the main actor until it holds, failing after `timeout`.
@MainActor
func waitUntil(
    timeout: Duration = .seconds(5), _ condition: @MainActor () -> Bool,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("condition not met within \(timeout)", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}
