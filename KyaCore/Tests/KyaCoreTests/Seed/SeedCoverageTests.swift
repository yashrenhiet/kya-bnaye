import Foundation
import KyaCore
import Testing

/// Port of `legacy/packages/kya_core/test/seed/seed_coverage_test.dart`.
///
/// The fixture: 5 recipes, 21 ingredients, all north/medium/30 min; bases
/// roti 2, rice 2, bread 1; proteins vegOnly 2, dalLegume, paneer, egg.
@Suite("SeedValidator coverage")
struct SeedCoverageTests {
    typealias F = SeedFixtures

    /// Targets every bundle meets; each test tightens exactly one of them.
    private func targets(
        minRecipes: Int = 0,
        maxRecipes: Int = 1000,
        minIngredients: Int = 0,
        maxIngredients: Int = 1000,
        mealTypes: [MealType: Int] = [:],
        regions: [Region: Int] = [:],
        perDishType: Int = 0,
        dishTypeExemptions: Set<DishType> = [],
        bases: [DishBase: Int] = [:],
        maxBaseShare: Double = 1,
        heavinessShare: Double = 0,
        quickShare: Double = 0,
        quickMaxMinutes: Int = 30,
        nonVeg: (Double, Double) = (0, 1),
        paneer: Int = 0,
        dalLegume: Int = 0
    ) -> SeedCoverageTargets {
        SeedCoverageTargets(
            minRecipes: minRecipes, maxRecipes: maxRecipes, minIngredients: minIngredients,
            maxIngredients: maxIngredients, minRecipesPerMealType: mealTypes,
            minRecipesPerRegion: regions, minRecipesPerDishType: perDishType,
            dishTypeExemptions: dishTypeExemptions, minRecipesPerBase: bases,
            maxBaseShare: maxBaseShare, minHeavinessShare: heavinessShare,
            quickMaxMinutes: quickMaxMinutes, minQuickShare: quickShare,
            minNonVegShare: nonVeg.0, maxNonVegShare: nonVeg.1, minPaneerRecipes: paneer,
            minDalLegumeRecipes: dalLegume)
    }

    private func coverage(_ targets: SeedCoverageTargets, _ bundle: SeedBundle? = nil)
        -> [SeedIssue]
    {
        SeedValidator().validate(
            bundle ?? F.bundle(), assetExists: { _ in true }, coverage: targets)
    }

    @Test("defaults match the M2 plan")
    func defaults() {
        let t = SeedCoverageTargets()
        #expect(t.minRecipes == 75)
        #expect(t.maxRecipes == 90)
        #expect(t.minIngredients == 220)
        #expect(t.maxIngredients == 280)
        #expect(t.minRecipesPerMealType == [.breakfast: 15, .lunch: 35, .dinner: 35, .snack: 12])
        #expect(Set(t.minRecipesPerRegion.keys) == Set(Region.allCases))
        #expect(t.minRecipesPerRegion[.north] == 8)
        #expect(t.minRecipesPerRegion[.continental] == 1)
        #expect(t.minRecipesPerDishType == 3)
        #expect(t.dishTypeExemptions.isEmpty)
        #expect(t.minRecipesPerBase == [.rice: 12, .roti: 15, .bread: 4, .none: 12])
        #expect(t.maxBaseShare == 0.45)
        #expect(t.minHeavinessShare == 0.15)
        #expect(t.quickMaxMinutes == 30)
        #expect(t.minQuickShare == 0.35)
        #expect(t.minNonVegShare == 0.08)
        #expect(t.maxNonVegShare == 0.15)
        #expect(t.minPaneerRecipes == 5)
        #expect(t.minDalLegumeRecipes == 10)
        #expect(t.minKitchenCandidatesPerMealType == 5)
    }

    @Test("coverage is only checked when targets are given")
    func onlyWhenGiven() {
        #expect(SeedValidator().validate(F.bundle(), assetExists: { _ in true }).isEmpty)
        #expect(!coverage(SeedCoverageTargets()).isEmpty)
    }

    @Test("permissive targets pass the fixture")
    func permissive() {
        #expect(coverage(targets()).isEmpty)
    }

    @Test("recipe and ingredient totals")
    func totals() {
        #expect(
            coverage(targets(minRecipes: 6, maxRecipes: 10, minIngredients: 1, maxIngredients: 20))
                == [
                    SeedIssue(.coverageTotals, "recipes", "5 recipes; expected 6–10"),
                    SeedIssue(.coverageTotals, "ingredients", "21 ingredients; expected 1–20"),
                ])
    }

    @Test("recipes per meal type")
    func mealTypes() {
        #expect(
            coverage(targets(mealTypes: [.breakfast: 2, .lunch: 4])) == [
                SeedIssue(
                    .coverageMealTypes, "mealTypes.breakfast", "1 recipe; expected at least 2")
            ])
    }

    @Test("recipes per region")
    func regions() {
        #expect(
            coverage(targets(regions: [.south: 1, .north: 5])) == [
                SeedIssue(.coverageRegions, "region.south", "0 recipes; expected at least 1")
            ])
    }

    @Test("regions are reported in the default targets' order")
    func regionOrder() {
        let issues = coverage(
            targets(regions: [.continental: 1, .east: 1, .punjabi: 1, .south: 1]))
        #expect(
            issues.map(\.location) == [
                "region.punjabi", "region.south", "region.east", "region.continental",
            ])
    }

    @Test("every dish type needs the minimum")
    func dishTypes() {
        let issues = coverage(targets(perDishType: 1))
        #expect(
            issues.map(\.location) == [
                "dishType.bread", "dishType.snack", "dishType.sweet", "dishType.onePot",
            ])
        #expect(Set(issues.map(\.code)) == [.coverageDishTypes])
    }

    @Test("exempt dish types are skipped")
    func dishTypeExemptions() {
        #expect(
            coverage(
                targets(perDishType: 1, dishTypeExemptions: [.bread, .snack, .sweet, .onePot])
            )
            .isEmpty)
    }

    @Test("minimum per base")
    func basesMinimum() {
        #expect(
            coverage(targets(bases: [.none: 1, .rice: 2])) == [
                SeedIssue(.coverageBases, "base.none", "0 recipes; expected at least 1")
            ])
    }

    @Test("no base may exceed the maximum share")
    func baseShare() {
        #expect(
            coverage(targets(maxBaseShare: 0.3)) == [
                SeedIssue(.coverageBases, "base.rice", "40.0% of recipes; at most 30.0%"),
                SeedIssue(.coverageBases, "base.roti", "40.0% of recipes; at most 30.0%"),
            ])
    }

    @Test("each heaviness needs its share")
    func heaviness() {
        #expect(
            coverage(targets(heavinessShare: 0.15)) == [
                SeedIssue(
                    .coverageHeaviness, "heaviness.light",
                    "0.0% of recipes; expected at least 15.0%"),
                SeedIssue(
                    .coverageHeaviness, "heaviness.heavy",
                    "0.0% of recipes; expected at least 15.0%"),
            ])
    }

    @Test("quick recipes share, using the quick threshold")
    func quick() {
        #expect(coverage(targets(quickShare: 1)).isEmpty)  // all take 30 min
        #expect(
            coverage(targets(quickShare: 0.35, quickMaxMinutes: 29)) == [
                SeedIssue(
                    .coverageQuick, "quick (≤ 29 min)", "0.0% of recipes; expected at least 35.0%")
            ])
    }

    @Test("the non-veg share must sit inside its band")
    func nonVeg() {
        #expect(
            coverage(targets(nonVeg: (0.08, 0.15))) == [
                SeedIssue(
                    .coverageProtein, "protein.nonVeg", "20.0% of recipes; expected 8.0%–15.0%")
            ])
        #expect(coverage(targets(nonVeg: (0.2, 0.2))).isEmpty)
        #expect(
            coverage(targets(nonVeg: (0.25, 1))) == [
                SeedIssue(
                    .coverageProtein, "protein.nonVeg", "20.0% of recipes; expected 25.0%–100.0%")
            ])
    }

    @Test("paneer and dal/legume minimums")
    func paneerAndDal() {
        #expect(
            coverage(targets(paneer: 2, dalLegume: 2)) == [
                SeedIssue(.coverageProtein, "protein.paneer", "1 recipe; expected at least 2"),
                SeedIssue(.coverageProtein, "protein.dalLegume", "1 recipe; expected at least 2"),
            ])
    }

    @Test("an empty catalogue reports misses without dividing by zero")
    func emptyCatalogue() {
        let issues = coverage(SeedCoverageTargets(), F.bundle(ingredients: [], recipes: []))
        #expect(issues.contains(SeedIssue(.coverageTotals, "recipes", "0 recipes; expected 75–90")))
        #expect(
            issues.contains(
                SeedIssue(
                    .coverageHeaviness, "heaviness.light",
                    "0.0% of recipes; expected at least 15.0%")))
        #expect(issues.count { $0.code == .coverageBases } == DishBase.allCases.count)
    }

    // MARK: kitchenCandidateCounts (Recommend/) over the seed fixtures

    private func counts(_ bundle: SeedBundle, atHome: Set<String>) throws -> [MealType: Int] {
        kitchenCandidateCounts(
            recipes: bundle.recipes, catalog: bundle.ingredients, atHome: atHome,
            now: try TestDates.utc(2026, 9, 26, 12), calendar: TestDates.utcCalendar)
    }

    @Test("staples alone unlock recipes missing at most two items")
    func staplesAlone() throws {
        // aloo_sabzi, dal_chawal and paneer_bhurji miss 2, jeera_rice 1;
        // anda_bhurji misses 3 (eggs, onion, bread) so it is dropped.
        #expect(
            try counts(F.bundle(), atHome: []) == [.breakfast: 0, .lunch: 4, .dinner: 4, .snack: 0])
    }

    @Test("pantry items count as available; unknown ids are harmless")
    func pantryItems() throws {
        #expect(try counts(F.bundle(), atHome: ["eggs", "no_such_thing"])[.breakfast] == 1)
    }

    @Test("an empty catalogue yields zero for every meal type")
    func emptyCounts() throws {
        let empty = try counts(F.bundle(ingredients: [], recipes: []), atHome: ["eggs"])
        #expect(empty == Dictionary(uniqueKeysWithValues: MealType.allCases.map { ($0, 0) }))
    }
}
