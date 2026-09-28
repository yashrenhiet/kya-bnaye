import KyaCore
import Testing

func makeIngredient(
    _ id: String,
    _ name: String,
    aliases: [String] = [],
    role: IngredientRole = .core
) -> Ingredient {
    Ingredient(id: id, name: name, aliases: aliases, category: .other, role: role, buyFrom: .kirana)
}

/// Dart's `same(x)`: Swift structs have no identity, and `Ingredient ==` only
/// compares ids, so "same" means every field is identical.
func isSame(_ found: Ingredient?, _ expected: Ingredient) -> Bool {
    found?.isIdentical(to: expected) ?? false
}

@Suite("IngredientNormalizer")
struct IngredientNormalizerTests {
    let potato = makeIngredient("potato", "Potato", aliases: ["aloo", "batata"])
    let rice = makeIngredient("rice", "Rice", aliases: ["chawal"])
    let riceFlour = makeIngredient("rice_flour", "Rice Flour", aliases: ["chawal ka atta"])
    let greenChilli = makeIngredient("green_chilli", "Green Chilli", aliases: ["hari mirch"])
    let normalizer: IngredientNormalizer

    init() throws {
        normalizer = try IngredientNormalizer([potato, rice, riceFlour, greenChilli])
    }

    // MARK: find

    @Test("resolves the display name")
    func findName() {
        #expect(isSame(normalizer.find("Potato"), potato))
    }

    @Test("resolves every alias to the same canonical ingredient")
    func findAliases() {
        #expect(isSame(normalizer.find("aloo"), potato))
        #expect(isSame(normalizer.find("batata"), potato))
        #expect(isSame(normalizer.find("hari mirch"), greenChilli))
    }

    @Test("is case-insensitive for names and aliases")
    func caseInsensitive() {
        #expect(isSame(normalizer.find("POTATO"), potato))
        #expect(isSame(normalizer.find("Aloo"), potato))
        #expect(isSame(normalizer.find("HaRi MiRcH"), greenChilli))
    }

    @Test("ignores leading and trailing whitespace")
    func trimsInput() {
        #expect(isSame(normalizer.find("  Potato "), potato))
        #expect(isSame(normalizer.find("\taloo\n"), potato))
    }

    @Test("collapses runs of internal whitespace")
    func collapsesInput() {
        #expect(isSame(normalizer.find("green    chilli"), greenChilli))
        #expect(isSame(normalizer.find("hari\t\nmirch"), greenChilli))
    }

    @Test("normalises aliases stored with odd casing/spacing")
    func messyAliases() throws {
        let messy = try IngredientNormalizer([
            makeIngredient("ginger", "Ginger", aliases: ["  ADRAK  ", "Sonth   "])
        ])

        #expect(messy.find("adrak")?.id == "ginger")
        #expect(messy.find("sonth")?.id == "ginger")
    }

    @Test("returns nil for unknown text")
    func unknownText() {
        #expect(normalizer.find("paneer") == nil)
    }

    @Test("returns nil for empty or whitespace-only text")
    func blankText() {
        #expect(normalizer.find("") == nil)
        #expect(normalizer.find("   ") == nil)
    }

    @Test("does not match on the raw canonical id, only name/alias")
    func notById() {
        #expect(normalizer.find("green_chilli") == nil)
        #expect(isSame(normalizer.ingredient(withId: "green_chilli"), greenChilli))
    }

    @Test("does not remove internal whitespace entirely")
    func keepsInternalSpace() {
        #expect(normalizer.find("greenchilli") == nil)
        #expect(normalizer.find("harimirch") == nil)
    }

    // MARK: exact matching, never substring

    @Test("\"rice\" resolves to rice, not rice flour")
    func riceNotRiceFlour() {
        #expect(isSame(normalizer.find("rice"), rice))
        #expect(isSame(normalizer.find("rice flour"), riceFlour))
    }

    @Test("\"rice\" is unknown when only rice flour is in the catalog")
    func onlyFlour() throws {
        let onlyFlour = try IngredientNormalizer([riceFlour])

        #expect(onlyFlour.find("rice") == nil)
        #expect(onlyFlour.find("flour") == nil)
        #expect(!onlyFlour.contains("rice"))
    }

    @Test("a superstring of a name does not match")
    func superstring() throws {
        let onlyRice = try IngredientNormalizer([rice])

        #expect(onlyRice.find("rice flour") == nil)
        #expect(onlyRice.find("basmati rice") == nil)
    }

    @Test("a prefix or fragment of an alias does not match")
    func fragment() {
        #expect(normalizer.find("alo") == nil)
        #expect(normalizer.find("chawal ka") == nil)
        #expect(normalizer.find("mirch") == nil)
    }

    @Test("an alias of one item never leaks into a longer alias")
    func aliasNoLeak() {
        #expect(isSame(normalizer.find("chawal"), rice))
        #expect(isSame(normalizer.find("chawal ka atta"), riceFlour))
    }

    // MARK: alias collisions

    @Test("throws when two ingredients share an alias, naming key and both ids")
    func sharedAlias() {
        let error = #expect(throws: IngredientNormalizerError.self) {
            try IngredientNormalizer([
                makeIngredient("coriander", "Coriander", aliases: ["dhania"]),
                makeIngredient("coriander_seed", "Coriander Seed", aliases: ["dhania"]),
            ])
        }

        #expect(
            error
                == .aliasCollision(
                    key: "dhania", existingId: "coriander", conflictingId: "coriander_seed"))
        let message = error.map(String.init(describing:)) ?? ""
        #expect(message.contains("dhania"))
        #expect(message.contains("\"coriander\""))
        #expect(message.contains("coriander_seed"))
    }

    @Test("detects collisions after case/whitespace normalisation")
    func collisionAfterNormalisation() {
        #expect(
            throws: IngredientNormalizerError.aliasCollision(
                key: "kala namak", existingId: "a", conflictingId: "b")
        ) {
            try IngredientNormalizer([
                makeIngredient("a", "A", aliases: ["Kala Namak"]),
                makeIngredient("b", "B", aliases: ["  kala   NAMAK "]),
            ])
        }
    }

    @Test("throws when an alias equals another ingredient's name")
    func aliasEqualsOtherName() {
        #expect(throws: IngredientNormalizerError.self) {
            try IngredientNormalizer([
                potato, makeIngredient("sweet_potato", "Sweet Potato", aliases: ["potato"]),
            ])
        }
    }

    @Test("throws when two ingredients share a display name")
    func sharedName() {
        #expect(throws: IngredientNormalizerError.self) {
            try IngredientNormalizer([
                makeIngredient("curd", "Curd"), makeIngredient("curd_2", "curd"),
            ])
        }
    }

    @Test("a repeated alias within one ingredient is harmless")
    func repeatedAlias() throws {
        let n = try IngredientNormalizer([
            makeIngredient("onion", "Onion", aliases: ["pyaaz", "Pyaaz", "pyaaz"])
        ])

        #expect(n.find("pyaaz")?.id == "onion")
    }

    @Test("an alias equal to its own name is harmless")
    func aliasEqualsOwnName() throws {
        let n = try IngredientNormalizer([makeIngredient("onion", "Onion", aliases: ["onion"])])

        #expect(n.find("ONION")?.id == "onion")
    }

    @Test("ignores blank aliases instead of matching blank input")
    func blankAliases() throws {
        let n = try IngredientNormalizer([makeIngredient("onion", "Onion", aliases: ["   ", ""])])

        #expect(n.find("") == nil)
        #expect(n.find("  ") == nil)
        #expect(!n.contains("  "))
        #expect(n.find("onion")?.id == "onion")
    }

    // MARK: normalise

    @Test("trims, lower-cases and collapses internal whitespace")
    func normaliseBasics() {
        #expect(IngredientNormalizer.normalise("  Hari \t\n MIRCH ") == "hari mirch")
    }

    @Test("maps blank or whitespace-only text to the empty key")
    func normaliseBlank() {
        #expect(IngredientNormalizer.normalise("") == "")
        #expect(IngredientNormalizer.normalise(" \t\n") == "")
    }

    @Test("keeps punctuation and underscores untouched")
    func normalisePunctuation() {
        #expect(IngredientNormalizer.normalise("Black-Eyed_Peas") == "black-eyed_peas")
    }

    @Test("equal keys are exactly the texts find treats as the same")
    func normaliseMatchesFind() {
        let key = IngredientNormalizer.normalise("  CHAWAL   ka Atta")
        #expect(key == "chawal ka atta")
        #expect(isSame(normalizer.find(key), riceFlour))
    }

    // MARK: contains / ingredient(withId:) / all

    @Test("contains mirrors find for known and unknown text")
    func containsMirrorsFind() {
        #expect(normalizer.contains(" ALOO "))
        #expect(normalizer.contains("Rice Flour"))
        #expect(!normalizer.contains("rice atta"))
        #expect(!normalizer.contains(""))
    }

    @Test("ingredient(withId:) returns the ingredient for a known id")
    func byIdKnown() {
        #expect(isSame(normalizer.ingredient(withId: "rice_flour"), riceFlour))
    }

    @Test("ingredient(withId:) is exact and case-sensitive")
    func byIdExact() {
        #expect(normalizer.ingredient(withId: "Rice") == nil)
        #expect(normalizer.ingredient(withId: "ric") == nil)
        #expect(normalizer.ingredient(withId: " rice") == nil)
    }

    @Test("ingredient(withId:) does not resolve names or aliases")
    func byIdNotNames() {
        #expect(normalizer.ingredient(withId: "aloo") == nil)
        #expect(normalizer.ingredient(withId: "Potato") == nil)
    }

    @Test("all exposes every catalog ingredient once, in catalog order")
    func allInOrder() {
        #expect(normalizer.all.map(\.id) == ["potato", "rice", "rice_flour", "green_chilli"])
    }

    @Test("empty catalog finds nothing and exposes nothing")
    func emptyCatalog() throws {
        let empty = try IngredientNormalizer([])

        #expect(empty.find("rice") == nil)
        #expect(!empty.contains(""))
        #expect(empty.ingredient(withId: "rice") == nil)
        #expect(empty.all.isEmpty)
    }
}
