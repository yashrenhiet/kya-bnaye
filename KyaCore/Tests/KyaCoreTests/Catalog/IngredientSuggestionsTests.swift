import KyaCore
import Testing

@Suite("IngredientNormalizer.suggestions")
struct IngredientSuggestionsTests {
    let normalizer: IngredientNormalizer

    init() throws {
        normalizer = try IngredientNormalizer([
            makeIngredient("potato", "Potato", aliases: ["aloo", "batata"]),
            makeIngredient("sweet_potato", "Sweet Potato", aliases: ["shakarkandi"]),
            makeIngredient("rice", "Rice", aliases: ["chawal"]),
            makeIngredient("rice_flour", "Rice Flour", aliases: ["chawal ka atta"]),
            makeIngredient("curd", "Curd", aliases: ["dahi", "yogurt"]),
            makeIngredient("aloo_bukhara", "Plum", aliases: ["aloo bukhara"]),
        ])
    }

    private func ids(_ text: String, limit: Int = 8) -> [String] {
        normalizer.suggestions(for: text, limit: limit).map(\.id)
    }

    @Test("an alias prefix proposes the canonical ingredient")
    func aliasPrefix() {
        #expect(ids("dah") == ["curd"])
        #expect(ids("  ALO ") == ["aloo_bukhara", "potato"])
    }

    @Test("the exact alias match ranks first, ahead of name prefixes")
    func exactFirst() {
        #expect(ids("aloo") == ["potato", "aloo_bukhara"])
        #expect(ids("rice") == ["rice", "rice_flour"])
    }

    @Test("ranks name prefix, then alias prefix, then later-word prefix")
    func ranking() {
        #expect(ids("pot") == ["potato", "sweet_potato"])
        #expect(ids("p") == ["aloo_bukhara", "potato", "sweet_potato"])
        #expect(ids("atta") == ["rice_flour"])
    }

    @Test("blank text, no match or a non-positive limit give nothing")
    func empty() {
        #expect(ids("   ").isEmpty)
        #expect(ids("paneer").isEmpty)
        #expect(ids("pot", limit: 0).isEmpty)
    }

    @Test("honours the limit and the candidate filter")
    func limitAndFilter() {
        #expect(ids("p", limit: 1).count == 1)
        let filtered = normalizer.suggestions(for: "pot") { $0.id != "potato" }
        #expect(filtered.map(\.id) == ["sweet_potato"])
    }
}
