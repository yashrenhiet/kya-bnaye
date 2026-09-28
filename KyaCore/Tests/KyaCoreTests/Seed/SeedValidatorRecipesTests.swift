import KyaCore
import Testing

/// Port of `legacy/packages/kya_core/test/seed/seed_validator_recipes_test.dart`
/// (recipe rules R1–R6).
@Suite("SeedValidator recipes")
struct SeedValidatorRecipesTests {
    typealias F = SeedFixtures

    // MARK: R1

    @Test("R1 rejects a malformed id")
    func malformedId() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(id: "Dal-Chawal") }, .r1RecipeIdentity,
            "recipes[Dal-Chawal]"
        ) { $0.hasPrefix("id must match") }
    }

    @Test("R1 rejects a duplicate id")
    func duplicateId() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(id: "jeera_rice", name: "Other") },
            .r1RecipeIdentity, "recipes[jeera_rice]", "duplicate id")
    }

    @Test("R1 rejects blank, untrimmed and duplicate names")
    func names() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(name: " ") }, .r1RecipeIdentity,
            "recipes[dal_chawal].name", "name is blank")
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(name: "Dal Chawal ") }, .r1RecipeIdentity,
            "recipes[dal_chawal].name", "name has surrounding whitespace")
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(name: "jeera  RICE") }, .r1RecipeIdentity,
            "recipes[jeera_rice].name", "name \"Jeera Rice\" is also used by dal_chawal")
    }

    // MARK: R2, R3

    @Test("R2 rejects a recipe with no meal types")
    func noMealTypes() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(mealTypes: []) }, .r2MealTypes,
            "recipes[dal_chawal].mealTypes", "no meal types")
    }

    @Test("R3 rejects values outside 1..240", arguments: [0, 241])
    func minutesRange(minutes: Int) {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(minutes: minutes) }, .r3Minutes,
            "recipes[dal_chawal].minutes", "\(minutes) is outside 1–240")
    }

    @Test("R3 accepts the bounds", arguments: [1, 240])
    func minutesBounds(minutes: Int) {
        #expect(F.withRecipe("dal_chawal") { $0.copy(minutes: minutes) }.isEmpty)
    }

    // MARK: R4

    @Test("R4 rejects fewer than 2 or more than 12 steps", arguments: [1, 13])
    func stepCount(count: Int) {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(steps: Array(repeating: "Stir.", count: count)) },
            .r4Steps, "recipes[dal_chawal].steps", "\(count) steps; expected 2–12")
    }

    @Test("R4 rejects a blank step")
    func blankStep() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(steps: ["Stir.", " "]) }, .r4Steps,
            "recipes[dal_chawal].steps[1]", "blank step")
    }

    @Test("R4 rejects a step longer than 200 characters")
    func longStep() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") {
                $0.copy(steps: ["Stir.", String(repeating: "x", count: 201)])
            },
            .r4Steps, "recipes[dal_chawal].steps[1]", "201 characters; at most 200")
        #expect(
            F.withRecipe("dal_chawal") {
                $0.copy(steps: ["Stir.", String(repeating: "x", count: 200)])
            }.isEmpty)
    }

    @Test("R4 counts UTF-16 code units, like Dart's String.length")
    func stepLengthUnits() {
        // 101 chilli emoji: 101 characters, but 202 UTF-16 code units.
        let emoji = String(repeating: "\u{1F336}", count: 101)
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(steps: ["Stir.", emoji]) }, .r4Steps,
            "recipes[dal_chawal].steps[1]", "202 characters; at most 200")
    }

    // MARK: R5

    @Test("R5 rejects an empty ingredient list")
    func noIngredients() {
        let issues = F.withRecipe("dal_chawal") { $0.copy(ingredients: []) }
        #expect(
            issues.first
                == SeedIssue(.r5Ingredients, "recipes[dal_chawal].ingredients", "no ingredients"))
        #expect(Set(issues.map(\.code)) == [.r5Ingredients, .r6CoreIngredient, .r11Protein])
    }

    @Test("R5 rejects an unknown ingredient id")
    func unknownIngredient() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(ingredients: $0.ingredients + [F.line("hing")]) },
            .r5Ingredients, "recipes[dal_chawal].ingredients[3]", "unknown ingredient \"hing\"")
    }

    @Test("R5 rejects a repeated ingredient id")
    func repeatedIngredient() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") {
                $0.copy(ingredients: $0.ingredients + [F.line("rice", optional: true)])
            },
            .r5Ingredients, "recipes[dal_chawal].ingredients[3]", "ingredient \"rice\" is repeated")
    }

    @Test("R5 rejects blank quantity text")
    func blankQuantity() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") {
                $0.copy(
                    ingredients: $0.ingredients + [
                        RecipeIngredient(ingredientId: "salt", quantityText: " ")
                    ])
            },
            .r5Ingredients, "recipes[dal_chawal].ingredients[3]", "blank quantityText")
    }

    @Test("R5 reports every problem on one line, in order")
    func severalProblemsOnOneLine() {
        let issues = F.withRecipe("dal_chawal") {
            $0.copy(
                ingredients: $0.ingredients + [
                    RecipeIngredient(ingredientId: "hing", quantityText: ""),
                    RecipeIngredient(ingredientId: "hing", quantityText: "1"),
                ])
        }
        #expect(
            issues.map(\.message) == [
                "unknown ingredient \"hing\"", "blank quantityText", "unknown ingredient \"hing\"",
                "ingredient \"hing\" is repeated",
            ])
    }

    // MARK: R6

    @Test("R6 rejects a recipe with no core-role ingredient")
    func noCore() {
        expectOnlyIssue(
            F.withRecipe("aloo_sabzi") { $0.copy(ingredients: [F.line("onion"), F.line("salt")]) },
            .r6CoreIngredient, "recipes[aloo_sabzi].ingredients",
            "no required ingredient has the core role")
    }

    @Test("R6 an optional core line does not count")
    func optionalCore() {
        expectOnlyIssue(
            F.withRecipe("aloo_sabzi") {
                $0.copy(ingredients: [F.line("potato", optional: true), F.line("onion")])
            },
            .r6CoreIngredient, "recipes[aloo_sabzi].ingredients")
    }
}
