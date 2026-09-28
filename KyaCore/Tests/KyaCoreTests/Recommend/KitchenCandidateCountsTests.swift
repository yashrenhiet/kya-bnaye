import Foundation
import KyaCore
import Testing

/// The slice of `legacy/packages/kya_core/test/seed/seed_fixtures.dart` that
/// `kitchenCandidateCounts` needs: the fixture catalogue and its 5 recipes.
private enum ViabilityFixtures {
    static func staple(
        _ id: String,
        _ name: String,
        _ category: IngredientCategory = .masala
    ) -> Ingredient {
        Ingredient(id: id, name: name, category: category, role: .staple, buyFrom: .kirana)
    }

    static func core(
        _ id: String,
        _ name: String,
        _ category: IngredientCategory,
        role: IngredientRole = .core
    ) -> Ingredient {
        Ingredient(id: id, name: name, category: category, role: role, buyFrom: .kirana)
    }

    static let ingredients: [Ingredient] = [
        staple("salt", "Salt"),
        staple("turmeric", "Turmeric"),
        staple("red_chilli_powder", "Red Chilli Powder"),
        staple("coriander_powder", "Coriander Powder"),
        staple("cumin_seeds", "Cumin Seeds"),
        staple("mustard_seeds", "Mustard Seeds"),
        staple("asafoetida", "Asafoetida"),
        staple("garam_masala", "Garam Masala"),
        staple("cooking_oil", "Cooking Oil", .oilGhee),
        staple("ghee", "Ghee", .oilGhee),
        staple("sugar", "Sugar", .other),
        staple("atta", "Atta", .grains),
        core("potato", "Potato", .sabzi),
        core("onion", "Onion", .sabzi, role: .flavor),
        core("coriander_leaves", "Coriander Leaves", .sabzi, role: .optional),
        core("paneer", "Paneer", .dairy),
        core("eggs", "Eggs", .other),
        core("toor_dal", "Toor Dal", .dal),
        core("rice", "Rice", .grains),
        core("bread", "Bread", .grains),
        core("coconut", "Coconut", .fruit),
    ]

    static func line(_ id: String, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientId: id, quantityText: "1", isOptional: optional)
    }

    static func recipe(
        _ id: String,
        _ dishType: DishType,
        _ base: DishBase,
        _ protein: Protein,
        _ lines: [RecipeIngredient],
        mealTypes: Set<MealType> = [.lunch, .dinner]
    ) -> Recipe {
        Recipe(
            id: id, name: id, mealTypes: mealTypes, minutes: 30, base: base, ingredients: lines,
            steps: ["Prepare everything.", "Cook and serve."],
            tags: DishTags(
                region: .north, dishType: dishType, flavours: [.savoury], heaviness: .medium,
                protein: protein),
            source: .seed)
    }

    static let recipes: [Recipe] = [
        recipe(
            "aloo_sabzi", .drySabzi, .roti, .vegOnly,
            [line("potato"), line("onion"), line("salt"), line("coriander_leaves", optional: true)]),
        recipe(
            "dal_chawal", .dal, .rice, .dalLegume,
            [line("toor_dal"), line("rice"), line("turmeric")]),
        recipe("paneer_bhurji", .curry, .roti, .paneer, [line("paneer"), line("onion")]),
        recipe(
            "anda_bhurji", .breakfast, .bread, .egg, [line("eggs"), line("onion"), line("bread")],
            mealTypes: [.breakfast]),
        recipe(
            "jeera_rice", .rice, .rice, .vegOnly, [line("rice"), line("cumin_seeds"), line("ghee")]),
    ]
}

/// Port of the `kitchenCandidateCounts` group in
/// `legacy/packages/kya_core/test/seed/seed_coverage_test.dart`.
@Suite("kitchenCandidateCounts")
struct KitchenCandidateCountsTests {
    /// Dart `DateTime.utc(2026, 9, 26, 12)`.
    private let now = Date(timeIntervalSince1970: 1_790_424_000)

    private func counts(
        atHome: Set<String>,
        recipes: [Recipe] = ViabilityFixtures.recipes,
        catalog: [Ingredient] = ViabilityFixtures.ingredients
    ) -> [MealType: Int] {
        kitchenCandidateCounts(recipes: recipes, catalog: catalog, atHome: atHome, now: now)
    }

    @Test("the reference instant is 2026-09-26T12:00Z")
    func referenceInstant() {
        #expect(now.formatted(.iso8601) == "2026-09-26T12:00:00Z")
    }

    @Test("staples alone unlock recipes missing at most two items")
    func staplesAlone() {
        // aloo_sabzi, dal_chawal and paneer_bhurji miss 2, jeera_rice 1;
        // anda_bhurji misses 3 (eggs, onion, bread) so it is dropped.
        #expect(counts(atHome: []) == [.breakfast: 0, .lunch: 4, .dinner: 4, .snack: 0])
    }

    @Test("pantry items count as available; unknown ids are harmless")
    func unknownIds() {
        #expect(counts(atHome: ["eggs", "no_such_thing"])[.breakfast] == 1)
    }

    @Test("an empty catalogue yields zero for every meal type")
    func emptyCatalogue() {
        let result = counts(atHome: ["eggs"], recipes: [], catalog: [])
        #expect(result == Dictionary(uniqueKeysWithValues: MealType.allCases.map { ($0, 0) }))
    }
}
