import Foundation
import KyaCore
import Testing

private typealias F = ShoppingFixtures

@Suite("ShoppingListBuilder.restockPlan and MoveBoughtItemsToPantry")
struct ShoppingRestockTests {
    private let calendar = TestDates.utcCalendar
    private let now: Date
    private let paneerExpiry: Date

    init() throws {
        now = try TestDates.utc(2026, 9, 26, 19)
        paneerExpiry = try TestDates.utc(2026, 10, 1)
    }

    private func item(_ id: String, _ ingredientId: String, checked: Bool) throws -> ShoppingItem {
        try ShoppingItem(
            id: id, ingredientId: ingredientId, reason: .out, isChecked: checked,
            createdAt: try F.earlier())
    }

    private func plan(_ items: [ShoppingItem]) -> ShoppingRestockPlan {
        ShoppingListBuilder().restockPlan(
            items: items, ingredientsById: F.catalog, now: now, calendar: calendar)
    }

    @Test("nothing checked plans nothing")
    func nothingChecked() throws {
        let result = plan([try item("1", "paneer", checked: false)])
        #expect(result == ShoppingRestockPlan(pantryUpdates: [], clearedItemIds: []))
    }

    @Test("checked items restock to Plenty with an estimated expiry, sorted by id")
    func restocks() throws {
        let result = plan([
            try item("1", "paneer", checked: true),
            try item("2", "onion", checked: false),
            try item("3", "jeera", checked: true),
        ])
        #expect(
            result.pantryUpdates == [
                PantryItem(ingredientId: "jeera", level: .plenty, updatedAt: now),
                PantryItem(
                    ingredientId: "paneer", level: .plenty, updatedAt: now,
                    expiresOn: paneerExpiry, expiryIsEstimated: true),
            ])
        #expect(result.clearedItemIds == ["1", "3"])
    }

    @Test("duplicates restock once; free-typed and unknown ids are only cleared")
    func duplicatesAndUnknowns() throws {
        let candles = try ShoppingItem(
            id: "c", customName: "Candles", reason: .manual, isChecked: true, createdAt: now)
        let result = plan([
            try item("1", "onion", checked: true), candles,
            try item("2", "ghost", checked: true), try item("3", "onion", checked: true),
        ])
        #expect(result.pantryUpdates.map(\.ingredientId) == ["onion"])
        #expect(result.clearedItemIds == ["1", "c", "2", "3"])
    }

    @Test("the use case writes the pantry and clears only checked items")
    func moveBought() async throws {
        let repos = makeInMemoryRepositorySet()
        try await repos.ingredients.upsert(Array(F.catalog.values))
        try await repos.pantry.setLevels([try F.pantry("paneer", .out), try F.pantry("salt", .low)])
        try await repos.shopping.upsert([
            try item("1", "paneer", checked: true), try item("2", "onion", checked: false),
        ])
        let move = MoveBoughtItemsToPantry(
            shopping: repos.shopping, pantry: repos.pantry, ingredients: repos.ingredients)

        let applied = try await move(now: now, calendar: calendar)

        #expect(applied.clearedItemIds == ["1"])
        #expect(try await repos.shopping.all().map(\.id) == ["2"])
        #expect(
            try await repos.pantry.all() == [
                PantryItem(
                    ingredientId: "paneer", level: .plenty, updatedAt: now,
                    expiresOn: paneerExpiry, expiryIsEstimated: true),
                try F.pantry("salt", .low),
            ])
    }

    @Test("the use case writes nothing when nothing is checked")
    func moveNothing() async throws {
        let repos = makeInMemoryRepositorySet()
        try await repos.shopping.upsert([try item("1", "paneer", checked: false)])
        let move = MoveBoughtItemsToPantry(
            shopping: repos.shopping, pantry: repos.pantry, ingredients: repos.ingredients)
        let applied = try await move(now: now)
        #expect(applied == ShoppingRestockPlan(pantryUpdates: [], clearedItemIds: []))
        #expect(try await repos.shopping.all().map(\.id) == ["1"])
        #expect(try await repos.pantry.all().isEmpty)
    }
}
