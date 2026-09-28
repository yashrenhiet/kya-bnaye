import Foundation
import KyaCore
import Testing

@Suite("UsedUpSuggestions")
struct UsedUpSuggestionsTests {
    private typealias F = AppRecipesFixtures

    private let recipe = F.recipe(
        "mixed",
        ingredients: [
            F.line("potato"), F.line("paneer"), F.line("jeera"), F.line("salt"),
            F.line("coriander", optional: true), F.line("eggs"), F.line("honey"), F.line("banana"),
            F.line("mystery"), F.line("peas"),
        ])

    @Test("perishable: sabzi, fruit and dairy always; other only with a shelf life")
    func perishable() {
        #expect(UsedUpSuggestions.isPerishable(F.potato))
        #expect(UsedUpSuggestions.isPerishable(F.banana))
        #expect(UsedUpSuggestions.isPerishable(F.paneer))
        #expect(UsedUpSuggestions.isPerishable(F.eggs))
        #expect(!UsedUpSuggestions.isPerishable(F.honey))
        #expect(!UsedUpSuggestions.isPerishable(F.jeera))
        #expect(!UsedUpSuggestions.isPerishable(F.salt))
    }

    @Test("lists the recipe's perishables that are in stock, in recipe order")
    func candidates() {
        let pantry = F.pantry([
            ("potato", .plenty), ("paneer", .low), ("jeera", .plenty), ("salt", .plenty),
            ("coriander", .plenty), ("eggs", .plenty), ("honey", .plenty), ("banana", .out),
            ("mystery", .plenty),
        ])
        let result = UsedUpSuggestions.candidates(
            for: recipe, ingredientsById: F.catalogById, pantry: pantry)
        #expect(result.map(\.ingredient.id) == ["potato", "paneer", "coriander", "eggs"])
        #expect(result.map(\.currentLevel) == [.plenty, .low, .plenty, .plenty])
    }

    @Test("nothing at home means nothing to suggest")
    func emptyPantry() {
        #expect(
            UsedUpSuggestions.candidates(for: recipe, ingredientsById: F.catalogById, pantry: [:])
                .isEmpty)
    }

    @Test("a repeated line is suggested once")
    func dedupe() {
        let twice = F.recipe("t", ingredients: [F.line("potato"), F.line("potato")])
        let result = UsedUpSuggestions.candidates(
            for: twice, ingredientsById: F.catalogById, pantry: F.pantry([("potato", .plenty)]))
        #expect(result.count == 1)
    }

    @Test("updates change only the chosen levels, stamp now and keep the expiry")
    func updates() throws {
        let expiry = F.now.addingTimeInterval(86_400)
        let pantry = [
            "potato": PantryItem(
                ingredientId: "potato", level: .plenty, updatedAt: .distantPast, expiresOn: expiry,
                expiryIsEstimated: true),
            "paneer": PantryItem(ingredientId: "paneer", level: .low, updatedAt: .distantPast),
        ]
        let later = F.now.addingTimeInterval(60)
        let items = UsedUpSuggestions.updates(
            choices: ["potato": .out, "paneer": .low, "ghost": .out], pantry: pantry, now: later)
        #expect(items.count == 1)
        let potato = try #require(items.first)
        #expect(potato.ingredientId == "potato")
        #expect(potato.level == .out)
        #expect(potato.updatedAt == later)
        #expect(potato.expiresOn == expiry)
        #expect(potato.expiryIsEstimated)
    }

    @Test("updates are sorted by ingredient id")
    func updatesSorted() {
        let pantry = F.pantry([("potato", .plenty), ("banana", .plenty), ("paneer", .plenty)])
        let items = UsedUpSuggestions.updates(
            choices: ["potato": .low, "banana": .out, "paneer": .low], pantry: pantry, now: F.now)
        #expect(items.map(\.ingredientId) == ["banana", "paneer", "potato"])
    }
}
