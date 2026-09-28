import Foundation
import KyaCore
import Testing

@Suite("RecipeCookability")
struct RecipeCookabilityTests {
    private typealias F = AppRecipesFixtures

    private func evaluate(_ pantry: [String: PantryItem]) -> RecipeCookability {
        RecipeCookability.evaluate(F.alooMatar, ingredientsById: F.catalogById, pantry: pantry)
    }

    @Test("empty pantry: every core/flavor line is missing, staples assumed, garnish optional")
    func emptyPantry() {
        let result = evaluate([:])
        #expect(result.missingIngredientIds == ["potato", "peas", "jeera"])
        #expect(result.missingCount == 3)
        #expect(!result.isReady)
        #expect(
            result.lines.map(\.status) == [
                .missing, .missing, .missing, .assumedStaple, .assumedStaple, .optional,
            ])
    }

    @Test("everything at home (low counts) is ready")
    func ready() {
        let result = evaluate(F.pantry([("potato", .plenty), ("peas", .low), ("jeera", .plenty)]))
        #expect(result.isReady)
        #expect(result.missingIngredientIds.isEmpty)
        #expect(result.lines.prefix(3).allSatisfy { $0.status == .have })
    }

    @Test("a staple with a stock record shows as have; marked out it is missing")
    func stapleStates() {
        let pantry = F.pantry([
            ("potato", .plenty), ("peas", .plenty), ("jeera", .plenty), ("salt", .low),
            ("oil", .out),
        ])
        let result = evaluate(pantry)
        #expect(result.lines[3].status == .have)
        #expect(result.lines[4].status == .missing)
        #expect(result.missingIngredientIds == ["oil"])
    }

    @Test("optional lines and optional-role ingredients never count as missing")
    func optionalNeverMissing() {
        let recipe = F.recipe(
            "r", ingredients: [F.line("potato", optional: true), F.line("coriander")])
        let result = RecipeCookability.evaluate(recipe, ingredientsById: F.catalogById, pantry: [:])
        #expect(result.isReady)
        #expect(result.lines.map(\.status) == [.optional, .optional])
    }

    @Test("an id unknown to the catalog is missing unless stocked")
    func unknownIngredient() {
        let recipe = F.recipe("r", ingredients: [F.line("mystery")])
        let missing = RecipeCookability.evaluate(recipe, ingredientsById: [:], pantry: [:])
        #expect(missing.missingIngredientIds == ["mystery"])
        #expect(missing.lines[0].ingredient == nil)
        let stocked = RecipeCookability.evaluate(
            recipe, ingredientsById: [:], pantry: F.pantry([("mystery", .plenty)]))
        #expect(stocked.isReady)
    }

    @Test("agrees with IngredientAvailability on every line and level")
    func agreesWithAvailability() {
        for level in StockLevel.allCases {
            let pantry = F.pantry(F.catalog.map { ($0.id, level) })
            let result = evaluate(pantry)
            for entry in result.lines {
                let available = IngredientAvailability.isAvailable(
                    entry.line, role: entry.ingredient?.role, pantry: pantry)
                #expect(available == (entry.status != .missing))
            }
        }
    }

    @Test("a repeated missing ingredient is listed once")
    func dedupesMissing() {
        let recipe = F.recipe("r", ingredients: [F.line("potato"), F.line("potato")])
        let result = RecipeCookability.evaluate(recipe, ingredientsById: F.catalogById, pantry: [:])
        #expect(result.missingIngredientIds == ["potato"])
    }
}
