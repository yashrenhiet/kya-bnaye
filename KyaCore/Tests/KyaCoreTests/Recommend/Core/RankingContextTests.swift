import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures
private typealias C = RankingContextFixtures

/// Shared data for the `ranking_context_test.dart` port.
enum RankingContextFixtures {
    static let catalog = [
        F.ingredient("paneer", .core),
        F.ingredient("tomato", .core),
        F.ingredient("onion", .core),
        F.ingredient("masala", .flavor),
        F.ingredient("salt", .staple),
        F.ingredient("ghee", .staple),
        F.ingredient("haldi", .staple),
        F.ingredient("dhania", .optional),
    ]

    static let paneerMasala = F.recipe(
        "paneer_masala",
        ingredients: [
            F.uses("paneer"), F.uses("masala"), F.uses("salt"), F.uses("dhania", optional: true),
        ])
    static let paneerBhurji = F.recipe(
        "paneer_bhurji", base: .bread,
        ingredients: [F.uses("paneer"), F.uses("salt"), F.uses("onion", optional: true)])
    /// Role "optional" and unknown ids never count toward rarity frequency.
    static let jeeraRice = F.recipe(
        "jeera_rice", tags: F.otherTags, base: .rice,
        ingredients: [F.uses("dhania"), F.uses("mystery")])
    static let allRecipes = [paneerMasala, paneerBhurji, jeeraRice]

    static func build(
        recipes: [Recipe]? = nil,
        pantry: [PantryItem] = [],
        events: [SwipeEvent] = [],
        meals: [MealLog] = [],
        now: Date? = nil,
        mealType: MealType? = nil,
        config: ScoringConfig = ScoringConfig()
    ) -> RankingContext {
        RankingContext.build(
            allRecipes: recipes ?? allRecipes, pantry: pantry, catalog: catalog, events: events,
            mealLogs: meals, now: now ?? F.refNow, config: config, currentMealType: mealType)
    }
}

/// Port of `ranking_context_test.dart`: empty inputs, lookups, rarity,
/// availability and meal slot.
@Suite("RankingContext.build: lookups, rarity, availability, meal slot")
struct RankingContextTests {
    // MARK: empty inputs

    @Test("produces empty precomputations, never nils")
    func emptyInputs() {
        let ctx = RankingContext.build(
            allRecipes: [], pantry: [], catalog: [], events: [], mealLogs: [], now: F.refNow)
        #expect(ctx.pantry.isEmpty)
        #expect(ctx.ingredientsById.isEmpty)
        #expect(ctx.recipesById.isEmpty)
        #expect(ctx.ingredientFrequency.isEmpty)
        #expect(ctx.totalRecipesForFrequency == 0)
        #expect(ctx.lastCookedAtByRecipe.isEmpty)
        #expect(ctx.cookCountInRutWindowByRecipe.isEmpty)
        #expect(ctx.lastLeftSwipeAtByRecipe.isEmpty)
        #expect(ctx.neverShownRecipeIds.isEmpty)
        #expect(ctx.recentlyLikedRecipeIdsDesc.isEmpty)
        #expect(ctx.lastCookedBase == nil)
        #expect(ctx.tasteProfile.affinity.isEmpty)
        #expect(ctx.now == F.refNow)
        #expect(ctx.currentMealType == .lunch)  // 12:00
    }

    @Test("with no recipes rarity is 0 and weight is the bare role weight")
    func noRecipes() {
        let ctx = C.build(recipes: [])
        #expect(ctx.rarityBonus("paneer") == 0)
        #expect(F.near(ctx.ingredientWeight("paneer"), 2.4))
        #expect(ctx.ingredientWeight("mystery") == 0)
    }

    // MARK: lookups

    @Test("indexes pantry, catalog and recipes by id")
    func lookups() {
        let ctx = C.build(pantry: [F.stock("paneer", .low)])
        #expect(Array(ctx.pantry.keys) == ["paneer"])
        #expect(ctx.pantry["paneer"]?.level == .low)
        #expect(ctx.ingredientsById.count == C.catalog.count)
        #expect(Set(ctx.recipesById.keys) == Set(C.allRecipes.map(\.id)))
        #expect(ctx.recipesById["jeera_rice"]?.isIdentical(to: C.jeeraRice) == true)
    }

    // MARK: ingredient frequency and rarity (RECOMMENDER.md 5)

    @Test("counts only required core/flavor ingredients")
    func frequency() {
        let ctx = C.build()
        #expect(ctx.ingredientFrequency == ["paneer": 2, "masala": 1])
        #expect(ctx.totalRecipesForFrequency == 3)
    }

    @Test("rarityBonus = 0.6 * (1 - frequency / total)")
    func rarity() {
        let ctx = C.build()
        #expect(F.near(ctx.rarityBonus("paneer"), 0.6 * (1 - 2.0 / 3)))
        #expect(F.near(ctx.rarityBonus("masala"), 0.6 * (1 - 1.0 / 3)))
        // Staples never earn a rarity bonus (spec weight is a flat 0.25).
        #expect(ctx.rarityBonus("salt") == 0)
        #expect(F.near(ctx.rarityBonus("unknown"), 0.6))
    }

    @Test("an ingredient every recipe needs gets no bonus")
    func everyRecipeNeedsIt() {
        let ctx = C.build(recipes: [C.paneerMasala, C.paneerBhurji])
        #expect(F.near(ctx.rarityBonus("paneer"), 0))
    }

    @Test("ingredientWeight = roleWeight + rarityBonus; unknown -> 0")
    func ingredientWeight() {
        let ctx = C.build()
        #expect(F.near(ctx.ingredientWeight("paneer"), 2.4 + 0.2))
        #expect(F.near(ctx.ingredientWeight("masala"), 1.2 + 0.4))
        #expect(F.near(ctx.ingredientWeight("salt"), 0.25))
        #expect(F.near(ctx.ingredientWeight("dhania"), 0.7 + 0.6))
        #expect(ctx.ingredientWeight("mystery") == 0)
    }

    // MARK: isIngredientAvailable

    private var stocked: RankingContext {
        C.build(pantry: [
            F.stock("paneer", .plenty), F.stock("masala", .low), F.stock("tomato", .out),
            F.stock("ghee", .out), F.stock("haldi", .low), F.stock("mystery", .plenty),
        ])
    }

    @Test("core/flavor need a not-out pantry record")
    func coreFlavorAvailability() {
        let ctx = stocked
        #expect(ctx.isIngredientAvailable("paneer"))
        #expect(ctx.isIngredientAvailable("masala"), "low")
        #expect(!ctx.isIngredientAvailable("tomato"), "out")
        #expect(!ctx.isIngredientAvailable("onion"), "none")
    }

    @Test("optional-role ingredients never count as missing")
    func optionalAvailability() {
        #expect(stocked.isIngredientAvailable("dhania"), "none")
    }

    @Test("staples are assumed present unless explicitly Out")
    func stapleAvailability() {
        let ctx = stocked
        #expect(ctx.isIngredientAvailable("salt"), "no record")
        #expect(ctx.isIngredientAvailable("haldi"), "low")
        #expect(!ctx.isIngredientAvailable("ghee"), "out")
    }

    @Test("ingredients missing from the catalog follow the non-staple rule")
    func unknownAvailability() {
        #expect(stocked.isIngredientAvailable("mystery"))
        #expect(!stocked.isIngredientAvailable("dragonfruit"))
    }

    @Test("empty pantry: only staples are available")
    func emptyPantry() {
        let empty = C.build()
        #expect(empty.isIngredientAvailable("salt"))
        #expect(!empty.isIngredientAvailable("paneer"))
    }

    // MARK: meal slot

    @Test("explicit currentMealType overrides the clock")
    func explicitMealType() {
        #expect(C.build(now: F.wall(2026, 9, 26, 8), mealType: .dinner).currentMealType == .dinner)
    }

    @Test("defaults to the slot for the hour of now")
    func mealTypeFromClock() {
        #expect(C.build(now: F.wall(2026, 9, 26, 7)).currentMealType == .breakfast)
        #expect(C.build(now: F.wall(2026, 9, 26, 20)).currentMealType == .dinner)
    }

    @Test(
        "mealType(forHour:) boundaries",
        arguments: [
            (0, .dinner), (4, .dinner), (5, .breakfast), (10, .breakfast), (11, .lunch),
            (15, .lunch), (16, .snack), (18, .snack), (19, .dinner), (23, .dinner),
        ] as [(Int, MealType)])
    func mealTypeBoundaries(hour: Int, slot: MealType) {
        #expect(RankingContext.mealType(forHour: hour) == slot)
    }

    @Test("recipes can be filtered to the current slot")
    func filterToSlot() {
        let breakfastOnly = F.recipe("poha", mealTypes: [.breakfast, .snack])
        let ctx = C.build(recipes: C.allRecipes + [breakfastOnly], now: F.wall(2026, 9, 26, 17))
        let eligible = ctx.recipesById.values
            .filter { $0.mealTypes.contains(ctx.currentMealType) }
            .map(\.id)
        #expect(eligible == [breakfastOnly.id])
    }
}
