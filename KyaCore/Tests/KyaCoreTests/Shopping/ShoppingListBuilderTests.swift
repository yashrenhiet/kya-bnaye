import Foundation
import KyaCore
import Testing

private typealias F = ShoppingFixtures

@Suite("ShoppingListBuilder.build")
struct ShoppingListBuilderTests {
    private let builder = ShoppingListBuilder()
    private let now: Date

    init() throws {
        now = try F.now()
    }

    private func build(
        pantry: [PantryItem] = [],
        existing: [ShoppingItem] = [],
        recipes: [Recipe] = [],
        catalog: [String: Ingredient]? = nil,
        ids: IdCounter? = nil
    ) -> [ShoppingItem] {
        let idSource = ids ?? IdCounter()
        return builder.build(
            pantry: pantry,
            ingredientsById: catalog ?? F.catalog,
            existingItems: existing,
            recipesToShopFor: recipes,
            now: now,
            nextId: idSource.next
        )
    }

    // MARK: empty inputs

    @Test("returns an empty list and never calls nextId")
    func emptyInputs() {
        let ids = IdCounter()
        #expect(build(ids: ids).isEmpty)
        #expect(ids.calls == 0)
    }

    @Test("empty catalog skips every pantry item")
    func emptyCatalog() throws {
        #expect(build(pantry: [try F.pantry("potato", .out)], catalog: [:]).isEmpty)
    }

    @Test("recipe with no ingredients adds nothing")
    func emptyRecipe() {
        #expect(build(recipes: [F.recipe("plain", [])]).isEmpty)
    }

    // MARK: pantry stock levels

    @Test("Out item is listed with reason out")
    func outItem() throws {
        let result = build(pantry: [try F.pantry("paneer", .out)])
        let expected = try ShoppingItem(
            id: "shop_0", ingredientId: "paneer", reason: .out, isChecked: false, createdAt: now)
        #expect(result == [expected])
    }

    @Test("Low item is listed with reason low")
    func lowItem() throws {
        let result = build(pantry: [try F.pantry("onion", .low)])
        #expect(result.count == 1)
        #expect(result.first?.ingredientId == "onion")
        #expect(result.first?.reason == .low)
    }

    @Test("Plenty item is excluded")
    func plentyExcluded() throws {
        let ids = IdCounter()
        #expect(build(pantry: [try F.pantry("potato", .plenty)], ids: ids).isEmpty)
        #expect(ids.calls == 0)
    }

    @Test("auto items carry no customName or recipeId, are unchecked and stamped with now")
    func autoItemShape() throws {
        let result = build(pantry: [try F.pantry("onion", .out)])
        let item = try #require(result.first)
        #expect(result.count == 1)
        #expect(item.customName == nil)
        #expect(item.recipeId == nil)
        #expect(item.isChecked == false)
        #expect(item.createdAt == now)
    }

    @Test("mixed levels keep pantry order")
    func mixedLevels() throws {
        let result = build(pantry: [
            try F.pantry("potato", .plenty),
            try F.pantry("paneer", .out),
            try F.pantry("onion", .low),
        ])
        #expect(result.map(\.ingredientId) == ["paneer", "onion"])
        #expect(result.map(\.reason) == [.out, .low])
    }

    @Test("pantry item whose ingredient is not in the catalog is skipped")
    func unknownPantryItem() throws {
        let ids = IdCounter()
        #expect(build(pantry: [try F.pantry("ghost", .out)], ids: ids).isEmpty)
        #expect(ids.calls == 0)
    }

    @Test("user-created ingredient that is Out is listed")
    func userCreatedOut() throws {
        let result = build(pantry: [try F.pantry("dragonfruit", .out)])
        #expect(result.map(\.ingredientId) == ["dragonfruit"])
    }

    // MARK: recipes to shop for

    @Test("ingredient with no pantry record is added as recipe item")
    func recipeItem() throws {
        let result = build(recipes: [F.recipe("aloo_sabzi", [F.line("potato")])])
        let expected = try ShoppingItem(
            id: "shop_0", ingredientId: "potato", reason: .recipe, recipeId: "aloo_sabzi",
            isChecked: false, createdAt: now)
        #expect(result == [expected])
    }

    @Test("Plenty and Low ingredients count as available")
    func plentyAvailable() throws {
        let result = build(
            pantry: [try F.pantry("potato", .plenty)],
            recipes: [F.recipe("aloo_sabzi", [F.line("potato")])]
        )
        #expect(result.isEmpty)
    }

    @Test("Low ingredient is listed once, as low, not as recipe")
    func lowNotRecipe() throws {
        let result = build(
            pantry: [try F.pantry("onion", .low)],
            recipes: [F.recipe("pyaaz", [F.line("onion")])]
        )
        #expect(result.count == 1)
        #expect(result.first?.reason == .low)
        #expect(result.first?.recipeId == nil)
    }

    @Test("Out ingredient is listed once, as out, not as recipe")
    func outNotRecipe() throws {
        let result = build(
            pantry: [try F.pantry("paneer", .out)],
            recipes: [F.recipe("palak_paneer", [F.line("paneer")])]
        )
        #expect(result.count == 1)
        #expect(result.first?.reason == .out)
    }

    @Test("optional recipe ingredients are never added")
    func optionalNeverAdded() {
        let ids = IdCounter()
        let result = build(
            recipes: [F.recipe("aloo_sabzi", [F.line("potato"), F.line("jeera", optional: true)])],
            ids: ids
        )
        #expect(result.map(\.ingredientId) == ["potato"])
        #expect(ids.calls == 1)
    }

    @Test("ingredient unknown to the catalog is still added")
    func unknownRecipeIngredient() throws {
        let result = build(recipes: [F.recipe("mystery", [F.line("saffron")])])
        let item = try #require(result.first)
        #expect(result.count == 1)
        #expect(item.ingredientId == "saffron")
        #expect(item.reason == .recipe)
        #expect(item.recipeId == "mystery")
    }

    @Test("ingredient shared by two recipes is listed once, for the first recipe")
    func sharedIngredient() {
        let result = build(recipes: [
            F.recipe("palak_paneer", [F.line("paneer")]),
            F.recipe("paneer_tikka", [F.line("paneer"), F.line("onion")]),
        ])
        #expect(result.map(\.ingredientId) == ["paneer", "onion"])
        #expect(result.map(\.recipeId) == ["palak_paneer", "paneer_tikka"])
    }

    @Test("ingredient repeated within one recipe is listed once")
    func repeatedWithinRecipe() {
        let result = build(recipes: [F.recipe("double", [F.line("potato"), F.line("potato")])])
        #expect(result.count == 1)
    }

    // MARK: staples

    @Test("staple with no pantry record is assumed available")
    func stapleAssumedAvailable() {
        let result = build(recipes: [F.recipe("aloo_sabzi", [F.line("salt"), F.line("oil")])])
        #expect(result.isEmpty)
    }

    @Test("staple marked Plenty or Low is available for recipes")
    func stapleAvailable() throws {
        let result = build(
            pantry: [try F.pantry("salt", .plenty)],
            recipes: [F.recipe("aloo_sabzi", [F.line("salt")])]
        )
        #expect(result.isEmpty)
    }

    @Test("staple explicitly marked Out is listed once with reason out")
    func stapleOut() throws {
        let result = build(
            pantry: [try F.pantry("salt", .out)],
            recipes: [F.recipe("aloo_sabzi", [F.line("salt")])]
        )
        #expect(result.count == 1)
        #expect(result.first?.ingredientId == "salt")
        #expect(result.first?.reason == .out)
    }

    @Test("staple marked Low is listed from the pantry with reason low")
    func stapleLow() throws {
        let result = build(pantry: [try F.pantry("oil", .low)])
        #expect(result.count == 1)
        #expect(result.first?.ingredientId == "oil")
        #expect(result.first?.reason == .low)
    }

    // MARK: dedupe against existing items

    @Test("unchecked existing item blocks a duplicate pantry row")
    func existingBlocksPantry() throws {
        let ids = IdCounter()
        let result = build(
            pantry: [try F.pantry("paneer", .out)],
            existing: [try F.existing(id: "old_1", ingredientId: "paneer", reason: .out)],
            ids: ids
        )
        #expect(result.isEmpty)
        #expect(ids.calls == 0)
    }

    @Test("unchecked existing manual item blocks a duplicate recipe row")
    func existingBlocksRecipe() throws {
        let result = build(
            existing: [try F.existing(id: "old_1", ingredientId: "paneer")],
            recipes: [F.recipe("palak_paneer", [F.line("paneer"), F.line("onion")])]
        )
        #expect(result.map(\.ingredientId) == ["onion"])
    }

    @Test("checked (bought) existing item does not block re-listing")
    func checkedDoesNotBlock() throws {
        let result = build(
            pantry: [try F.pantry("paneer", .out)],
            existing: [try F.existing(id: "old_1", ingredientId: "paneer", isChecked: true)]
        )
        #expect(result.count == 1)
        #expect(result.first?.ingredientId == "paneer")
        #expect(result.first?.id == "shop_0")
    }

    @Test("custom-name items never block catalog ingredients")
    func customNameDoesNotBlock() throws {
        let result = build(
            pantry: [try F.pantry("paneer", .out)],
            existing: [try F.existing(id: "old_1", customName: "paneer")]
        )
        #expect(result.map(\.ingredientId) == ["paneer"])
    }

    @Test("existing items are neither returned nor modified")
    func existingUntouched() throws {
        let existing = [
            try F.existing(id: "old_1", customName: "Birthday candles"),
            try F.existing(id: "old_2", ingredientId: "paneer"),
            try F.existing(id: "old_3", ingredientId: "onion", isChecked: true),
        ]
        let snapshot = existing
        let result = build(
            pantry: [try F.pantry("paneer", .out), try F.pantry("potato", .low)],
            existing: existing
        )
        #expect(result.map(\.ingredientId) == ["potato"])
        #expect(!result.contains { $0.id.hasPrefix("old_") })
        #expect(existing == snapshot)
    }

    // MARK: ids

    @Test("nextId is called once per added item, pantry rows first")
    func idsInOrder() throws {
        let ids = IdCounter()
        let result = build(
            pantry: [
                try F.pantry("paneer", .out),
                try F.pantry("potato", .plenty),
                try F.pantry("onion", .low),
            ],
            recipes: [
                F.recipe("mix", [F.line("potato"), F.line("jeera"), F.line("paneer")]),
                F.recipe("fruit", [F.line("dragonfruit")]),
            ],
            ids: ids
        )
        #expect(result.map(\.id) == ["shop_0", "shop_1", "shop_2", "shop_3"])
        #expect(result.map(\.ingredientId) == ["paneer", "onion", "jeera", "dragonfruit"])
        #expect(ids.calls == 4)
    }

    @Test("same inputs produce identical output")
    func deterministic() throws {
        let pantry = [try F.pantry("paneer", .out)]
        let recipes = [F.recipe("aloo_sabzi", [F.line("potato")])]
        #expect(build(pantry: pantry, recipes: recipes) == build(pantry: pantry, recipes: recipes))
    }
}
