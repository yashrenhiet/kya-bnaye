import Foundation
import KyaCore
import Testing

@Suite("RecipeBook browsing")
struct RecipeBookTests {
    private typealias F = AppRecipesFixtures

    private let recipes = [
        F.recipe("poha", name: "Poha", minutes: 15, mealTypes: [.breakfast]),
        F.recipe(
            "rajma", name: "Rajma Chawal", minutes: 60, mealTypes: [.lunch, .dinner],
            ingredients: [F.line("peas")], isFavorite: true),
        F.recipe("aloo_matar", name: "Aloo Matar", minutes: 30, mealTypes: [.dinner]),
        F.recipe("secret", name: "Secret Dish", minutes: 10, isHidden: true),
        F.recipe("creme", name: "Crème Caramel", minutes: 45, mealTypes: [.snack]),
    ]

    private let pantry = F.pantry([("potato", .plenty)])

    private func browse(_ filter: RecipeFilter) -> [String] {
        RecipeBook.browse(recipes, filter: filter) {
            RecipeCookability.evaluate($0, ingredientsById: F.catalogById, pantry: pantry)
        }
        .map(\.id)
    }

    @Test("no filter: every visible recipe, sorted by name; hidden ones excluded")
    func unfiltered() {
        #expect(browse(RecipeFilter()) == ["aloo_matar", "creme", "poha", "rajma"])
    }

    @Test("search matches name words in any order, ignoring case and accents")
    func search() {
        #expect(browse(RecipeFilter(searchText: "  CHAWAL ")) == ["rajma"])
        #expect(browse(RecipeFilter(searchText: "matar aloo")) == ["aloo_matar"])
        #expect(browse(RecipeFilter(searchText: "creme")) == ["creme"])
        #expect(browse(RecipeFilter(searchText: "biryani")).isEmpty)
    }

    @Test("search never matches hidden recipes or ingredient aliases")
    func searchScope() {
        #expect(browse(RecipeFilter(searchText: "secret")).isEmpty)
        #expect(browse(RecipeFilter(searchText: "aloo")) == ["aloo_matar"])
        #expect(browse(RecipeFilter(searchText: "potato")).isEmpty)
    }

    @Test("cookable now keeps only recipes with nothing missing")
    func cookableNow() {
        #expect(browse(RecipeFilter(cookableNow: true)) == ["aloo_matar", "creme", "poha"])
    }

    @Test("quick keeps recipes of at most 30 minutes")
    func quick() {
        #expect(RecipeFilter.quickMaxMinutes == 30)
        #expect(browse(RecipeFilter(quick: true)) == ["aloo_matar", "poha"])
    }

    @Test("favourites and meal type narrow the list, and filters combine")
    func favouriteAndMeal() {
        #expect(browse(RecipeFilter(favouritesOnly: true)) == ["rajma"])
        #expect(browse(RecipeFilter(mealType: .dinner)) == ["aloo_matar", "rajma"])
        #expect(browse(RecipeFilter(quick: true, mealType: .dinner)) == ["aloo_matar"])
        #expect(browse(RecipeFilter(cookableNow: true, favouritesOnly: true)).isEmpty)
    }

    @Test("isActive reports whether anything narrows the list")
    func isActive() {
        #expect(!RecipeFilter().isActive)
        #expect(!RecipeFilter(searchText: "   ").isActive)
        #expect(RecipeFilter(searchText: "po").isActive)
        #expect(RecipeFilter(mealType: .lunch).isActive)
    }

    @Test("hidden lists only hidden recipes, sorted by name")
    func hidden() {
        let more = recipes + [F.recipe("abc", name: "Aaa", isHidden: true)]
        #expect(RecipeBook.hidden(more).map(\.id) == ["abc", "secret"])
    }

    @Test("equal names tie-break by id")
    func tieBreak() {
        let twins = [F.recipe("b", name: "Dal"), F.recipe("a", name: "dal")]
        let ids = RecipeBook.browse(twins, filter: RecipeFilter()) { _ in
            RecipeCookability(lines: [])
        }
        .map(\.id)
        #expect(ids == ["a", "b"])
    }
}
