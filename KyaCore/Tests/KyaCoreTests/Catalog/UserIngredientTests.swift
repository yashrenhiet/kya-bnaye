import KyaCore
import Testing

@Suite("IngredientNormalizer.createUserIngredient")
struct UserIngredientTests {
    let potato = makeIngredient("potato", "Potato", aliases: ["aloo", "batata"])
    let normalizer: IngredientNormalizer

    init() throws {
        normalizer = try IngredientNormalizer([
            potato,
            makeIngredient("rice", "Rice", aliases: ["chawal"]),
            makeIngredient("rice_flour", "Rice Flour", aliases: ["chawal ka atta"]),
            makeIngredient("green_chilli", "Green Chilli", aliases: ["hari mirch"]),
        ])
    }

    private func make(
        _ text: String,
        category: IngredientCategory = .other,
        buyFrom: BuyFrom = .other,
        role: IngredientRole = .core
    ) throws -> Ingredient {
        try IngredientNormalizer.createUserIngredient(
            text, category: category, buyFrom: buyFrom, role: role)
    }

    @Test("builds a user-created ingredient from trimmed text")
    func buildsFromTrimmedText() throws {
        let created = try IngredientNormalizer.createUserIngredient(
            "  Kasuri Methi ", category: .masala, buyFrom: .kirana)

        #expect(created.id == "user_kasuri_methi")
        #expect(created.name == "Kasuri Methi")
        #expect(created.category == .masala)
        #expect(created.buyFrom == .kirana)
        #expect(created.isUserCreated)
        #expect(created.aliases.isEmpty)
        #expect(created.shelfLifeDays == nil)
    }

    @Test("defaults role to core and honours an explicit role")
    func roles() throws {
        let byDefault = try IngredientNormalizer.createUserIngredient(
            "Jaggery", category: .packaged, buyFrom: .kirana)
        let garnish = try make(
            "Microgreens", category: .sabzi, buyFrom: .sabziwala, role: .optional)

        #expect(byDefault.role == .core)
        #expect(garnish.role == .optional)
    }

    @Test("lower-cases and collapses whitespace into single underscores")
    func underscores() throws {
        #expect(try make("Black \t  Cardamom\nPods").id == "user_black_cardamom_pods")
    }

    @Test("equivalent spellings produce the same id")
    func equivalentSpellings() throws {
        #expect(try make("Kala Chana") == (try make("  kala   CHANA ")))
    }

    @Test("the user_ prefix keeps ids from colliding with seed ids")
    func prefix() throws {
        let created = try make("Potato", category: .sabzi, buyFrom: .sabziwala)

        #expect(created.id == "user_potato")
        #expect(created != potato)
    }

    @Test("does not register the new ingredient in any normalizer")
    func notRegistered() throws {
        _ = try make("Kasuri Methi", category: .masala, buyFrom: .kirana)

        #expect(normalizer.find("kasuri methi") == nil)
        #expect(normalizer.ingredient(withId: "user_kasuri_methi") == nil)
        #expect(normalizer.all.count == 4)
    }

    @Test("is findable once included in a rebuilt normalizer")
    func findableAfterRebuild() throws {
        let created = try make("Kasuri Methi", category: .masala, buyFrom: .kirana)

        let rebuilt = try IngredientNormalizer(normalizer.all + [created])

        #expect(isSame(rebuilt.find(" KASURI methi"), created))
        #expect(isSame(rebuilt.ingredient(withId: "user_kasuri_methi"), created))
    }

    @Test(
        "rejects blank text instead of creating a nameless ingredient",
        arguments: ["", "   ", "\t\n", "\u{85}\u{A0}"])
    func rejectsBlank(blank: String) {
        #expect(throws: IngredientNormalizerError.blankName(text: blank)) {
            try make(blank)
        }
    }

    @Test("the blank-name error explains itself")
    func blankDescription() {
        #expect(
            String(describing: IngredientNormalizerError.blankName(text: " "))
                .contains("must not be blank"))
    }
}
