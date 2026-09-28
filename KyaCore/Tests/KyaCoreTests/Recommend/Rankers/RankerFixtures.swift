import Foundation
import KyaCore

/// Shared, hand-checkable fixtures for the ranker and deck-builder tests,
/// mirroring `legacy/packages/kya_core/test/recommend/rankers/fixtures.dart`:
/// a small Indian kitchen catalog, 13 everyday recipes (see
/// ``RankerRecipes``), and helpers over fixed local-time clocks.
enum RankerFixtures {
    // MARK: Fixed clocks

    /// Wednesday 23 Sep 2026, 19:00: a weekday dinner.
    static var weekdayDinner: Date { CoreFixtures.wall(2026, 9, 23, 19) }

    /// Wednesday 23 Sep 2026, 08:00: a weekday breakfast.
    static var weekdayBreakfast: Date { CoreFixtures.wall(2026, 9, 23, 8) }

    /// Saturday 26 Sep 2026, 19:00: a weekend dinner (no Craving quick bonus).
    static var saturdayDinner: Date { CoreFixtures.wall(2026, 9, 26, 19) }

    /// `now` minus a (possibly fractional) number of days, rounded to whole
    /// minutes of elapsed time.
    static func daysBefore(_ now: Date, _ days: Double) -> Date {
        now.addingTimeInterval(-60 * (days * 24 * 60).rounded())
    }

    /// `now` plus a whole number of 24-hour days (for expiry dates).
    static func daysAfter(_ now: Date, _ days: Int) -> Date {
        now.addingTimeInterval(Double(days) * 86_400)
    }

    // MARK: Catalog

    private static func item(
        _ id: String,
        _ name: String,
        _ role: IngredientRole,
        _ category: IngredientCategory = .other
    ) -> Ingredient {
        Ingredient(id: id, name: name, category: category, role: role, buyFrom: .kirana)
    }

    /// ~30 ingredients covering every ``IngredientRole``.
    static let catalog: [Ingredient] = [
        item("potato", "Potato", .core, .sabzi),
        item("matar", "Matar", .core, .sabzi),
        item("palak", "Palak", .core, .sabzi),
        item("cabbage", "Cabbage", .core, .sabzi),
        item("paneer", "Paneer", .core, .dairy),
        item("curd", "Curd", .core, .dairy),
        item("egg", "Egg", .core),
        item("rice", "Rice", .core, .grains),
        item("poha", "Poha", .core, .grains),
        item("rava", "Rava", .core, .grains),
        item("besan", "Besan", .core, .grains),
        item("dosa_batter", "Dosa batter", .core),
        item("noodles", "Noodles", .core),
        item("toor_dal", "Toor dal", .core, .dal),
        item("rajma", "Rajma", .core, .dal),
        item("chana", "Kabuli chana", .core, .dal),
        item("onion", "Onion", .flavor, .sabzi),
        item("tomato", "Tomato", .flavor, .sabzi),
        item("ginger_garlic", "Ginger-garlic", .flavor, .sabzi),
        item("green_chilli", "Green chilli", .flavor, .sabzi),
        item("lemon", "Lemon", .flavor, .sabzi),
        item("curry_leaves", "Curry leaves", .flavor, .sabzi),
        item("garam_masala", "Garam masala", .flavor, .masala),
        item("kasuri_methi", "Kasuri methi", .flavor, .masala),
        item("soy_sauce", "Soy sauce", .flavor),
        item("coriander", "Coriander", .optional, .sabzi),
        item("cream", "Cream", .optional, .dairy),
        item("salt", "Salt", .staple, .masala),
        item("oil", "Oil", .staple, .oilGhee),
        item("haldi", "Haldi", .staple, .masala),
        item("jeera", "Jeera", .staple, .masala),
    ]

    /// The 13 fixture recipes.
    static var recipes: [Recipe] { RankerRecipes.all }

    /// Looks up a fixture recipe by id; a typo yields an obviously wrong
    /// placeholder so the test fails loudly.
    static func recipe(_ id: String) -> Recipe {
        recipes.first { $0.id == id }
            ?? CoreFixtures.recipe("missing-fixture-\(id)", mealTypes: [])
    }

    // MARK: Pantry

    /// One pantry row, stocked a week before the fixed clocks.
    static func have(
        _ ingredientId: String,
        level: StockLevel = .plenty,
        expiresOn: Date? = nil
    ) -> PantryItem {
        PantryItem(
            ingredientId: ingredientId, level: level, updatedAt: CoreFixtures.wall(2026, 9, 16),
            expiresOn: expiresOn)
    }

    /// Every id at ``StockLevel/plenty``, no expiry.
    static func haveAll(_ ids: [String]) -> [PantryItem] { ids.map { have($0) } }

    /// `ingredientId` explicitly marked Out.
    static func out(_ ingredientId: String) -> PantryItem { have(ingredientId, level: .out) }

    // MARK: History

    private static func event(_ recipeId: String, _ action: SwipeAction, _ at: Date) -> SwipeEvent {
        SwipeEvent(
            id: "\(action.rawValue)-\(recipeId)-\(at.timeIntervalSince1970)", recipeId: recipeId,
            action: action, mode: .craving, at: at, deckSeed: 1)
    }

    static func right(_ recipeId: String, _ at: Date) -> SwipeEvent { event(recipeId, .right, at) }

    static func left(_ recipeId: String, _ at: Date) -> SwipeEvent { event(recipeId, .left, at) }

    static func neverShow(_ recipeId: String, _ at: Date) -> SwipeEvent {
        event(recipeId, .neverShow, at)
    }

    static func cooked(_ recipeId: String, _ at: Date) -> MealLog {
        MealLog(
            id: "cook-\(recipeId)-\(at.timeIntervalSince1970)", recipeId: recipeId,
            mealType: .dinner, cookedAt: at)
    }

    // MARK: Ranking helpers

    /// A context over the fixture catalog; `allRecipes` defaults to the 13
    /// fixture recipes, which fixes every ingredient's rarity bonus.
    static func contextFor(
        now: Date,
        pantry: [PantryItem] = [],
        events: [SwipeEvent] = [],
        meals: [MealLog] = [],
        mealType: MealType? = nil,
        config: ScoringConfig = ScoringConfig(),
        allRecipes: [Recipe]? = nil
    ) -> RankingContext {
        RankingContext.build(
            allRecipes: allRecipes ?? recipes, pantry: pantry, catalog: catalog, events: events,
            mealLogs: meals, now: now, config: config, currentMealType: mealType)
    }

    /// A full deck over `candidates` (defaults to every fixture recipe).
    static func deckFor(
        _ context: RankingContext,
        _ strategy: some RankingStrategy,
        candidates: [Recipe]? = nil,
        seed: Int = 7
    ) -> [ScoredRecipe] {
        DeckBuilder().build(
            candidates: candidates ?? recipes, context: context, strategy: strategy, seed: seed)
    }

    static func idsOf(_ cards: some Sequence<ScoredRecipe>) -> [String] { cards.map(\.recipe.id) }

    static func tiersOf(_ cards: some Sequence<ScoredRecipe>) -> [RecipeTier?] { cards.map(\.tier) }

    /// A recipe with no ingredients (every pantry reads as ready; pantry hint
    /// 1.0), available at every meal, not quick.
    static func syntheticRecipe(_ id: String, _ tags: DishTags) -> Recipe {
        Recipe(
            id: id, name: "Dish \(id)", mealTypes: Set(MealType.allCases), minutes: 45,
            base: .none, ingredients: [], steps: ["Cook."], tags: tags, source: .user)
    }
}
