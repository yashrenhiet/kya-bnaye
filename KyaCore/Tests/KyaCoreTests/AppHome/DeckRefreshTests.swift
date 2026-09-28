import Foundation
import KyaCore
import Testing

@Suite("DeckRefresh")
struct DeckRefreshTests {
    private func card(_ id: String, explanation: String = "old") -> ScoredRecipe {
        ScoredRecipe(
            recipe: CoreFixtures.recipe(id, mealTypes: [.dinner]), score: 1,
            explanation: explanation, missingIngredientIds: [])
    }

    private func ids(_ cards: [ScoredRecipe]) -> [String] { cards.map(\.recipe.id) }

    @Test("a fresh deck drops excluded recipes and keeps the builder's order")
    func fresh() {
        let built = [card("a"), card("b"), card("c")]
        #expect(ids(DeckRefresh.fresh(built, excluding: ["b"])) == ["a", "c"])
        #expect(DeckRefresh.fresh([], excluding: ["b"]).isEmpty)
    }

    @Test("the card on screen stays on top, updated from the rebuild, without a duplicate")
    func pinsTopCard() {
        let current = [card("b"), card("c")]
        let rebuilt = [card("a"), card("b", explanation: "new"), card("d")]

        let result = DeckRefresh.refreshed(
            current: current, rebuilt: rebuilt, excluding: [], keepingTopIf: { _ in true })

        #expect(ids(result) == ["b", "a", "d"])
        #expect(result.first?.explanation == "new")
    }

    @Test("a top card the rebuild no longer offers stays while it is still allowed")
    func keepsStaleTopCard() {
        let current = [card("b")]
        let rebuilt = [card("a")]

        let kept = DeckRefresh.refreshed(
            current: current, rebuilt: rebuilt, excluding: [], keepingTopIf: { _ in true })
        #expect(ids(kept) == ["b", "a"])
        #expect(kept.first?.explanation == "old")

        let dropped = DeckRefresh.refreshed(
            current: current, rebuilt: rebuilt, excluding: [], keepingTopIf: { _ in false })
        #expect(ids(dropped) == ["a"])
    }

    @Test("cards already swiped this session never come back behind the top card")
    func excludesSwiped() {
        let result = DeckRefresh.refreshed(
            current: [card("c")], rebuilt: [card("a"), card("b"), card("c")], excluding: ["a"],
            keepingTopIf: { _ in true })
        #expect(ids(result) == ["c", "b"])
    }

    @Test("with no card on screen the refresh is just a fresh deck")
    func emptyCurrent() {
        let result = DeckRefresh.refreshed(
            current: [], rebuilt: [card("a"), card("b")], excluding: ["b"],
            keepingTopIf: { _ in true })
        #expect(ids(result) == ["a"])
    }
}
