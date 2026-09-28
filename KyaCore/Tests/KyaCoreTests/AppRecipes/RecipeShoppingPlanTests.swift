import Foundation
import KyaCore
import Testing

@Suite("RecipeShoppingPlan")
struct RecipeShoppingPlanTests {
    private typealias F = AppRecipesFixtures

    private func ids() -> () -> String {
        var next = 0
        return {
            next += 1
            return "id\(next)"
        }
    }

    private func existing(_ ingredientId: String?, checked: Bool, name: String? = nil) throws
        -> ShoppingItem
    {
        try ShoppingItem(
            id: "old-\(ingredientId ?? name ?? "")", ingredientId: ingredientId, customName: name,
            reason: .manual, isChecked: checked, createdAt: F.now)
    }

    @Test("lists every missing required ingredient with reason recipe and the recipe id")
    func listsMissing() {
        let items = RecipeShoppingPlan.missingItems(
            for: F.alooMatar, ingredientsById: F.catalogById,
            pantry: F.pantry([("potato", .plenty), ("oil", .out)]), existingItems: [], now: F.now,
            nextId: ids())
        #expect(items.map(\.ingredientId) == ["peas", "jeera", "oil"])
        #expect(items.map(\.id) == ["id1", "id2", "id3"])
        #expect(items.allSatisfy { $0.reason == .recipe && $0.recipeId == "aloo_matar" })
        #expect(items.allSatisfy { !$0.isChecked && $0.createdAt == F.now && $0.customName == nil })
    }

    @Test("an unchecked existing item blocks a duplicate; checked and free-typed ones do not")
    func dedupe() throws {
        let items = RecipeShoppingPlan.missingItems(
            for: F.alooMatar, ingredientsById: F.catalogById, pantry: [:],
            existingItems: [
                try existing("potato", checked: false),
                try existing("peas", checked: true),
                try existing(nil, checked: false, name: "jeera"),
            ],
            now: F.now, nextId: ids())
        #expect(items.map(\.ingredientId) == ["peas", "jeera"])
    }

    @Test("a ready recipe adds nothing, and never calls nextId")
    func readyRecipe() {
        var calls = 0
        let items = RecipeShoppingPlan.missingItems(
            for: F.alooMatar, ingredientsById: F.catalogById,
            pantry: F.pantry([("potato", .low), ("peas", .plenty), ("jeera", .plenty)]),
            existingItems: [], now: F.now,
            nextId: {
                calls += 1
                return "x"
            })
        #expect(items.isEmpty)
        #expect(calls == 0)
    }

    @Test("adding twice is idempotent once the first batch is on the list")
    func idempotent() {
        let first = RecipeShoppingPlan.missingItems(
            for: F.alooMatar, ingredientsById: F.catalogById, pantry: [:], existingItems: [],
            now: F.now, nextId: ids())
        let second = RecipeShoppingPlan.missingItems(
            for: F.alooMatar, ingredientsById: F.catalogById, pantry: [:], existingItems: first,
            now: F.now, nextId: ids())
        #expect(first.count == 3)
        #expect(second.isEmpty)
    }
}
