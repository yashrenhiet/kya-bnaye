import KyaCore
import Testing

/// Port of `legacy/packages/kya_core/test/seed/seed_validator_test.dart`
/// (ingredient rules I1–I7).
@Suite("SeedValidator ingredients")
struct SeedValidatorTests {
    typealias F = SeedFixtures

    @Test("the fixture bundle is valid")
    func fixtureValid() {
        #expect(F.validate(F.bundle()).isEmpty)
    }

    @Test("collects every issue instead of stopping at the first")
    func collectsEverything() {
        let issues = F.validate(
            F.bundle(
                ingredients: F.editIngredient("potato") { $0.copy(name: " ") },
                recipes: F.editRecipe("dal_chawal") { $0.copy(minutes: 0) }))
        #expect(Set(issues.map(\.code)) == [.i2IngredientName, .r3Minutes])
    }

    @Test("SeedIssue has value equality and a readable description")
    func issueValue() {
        let issue = SeedIssue(.r3Minutes, "recipes[x]", "bad")
        #expect(issue == SeedIssue(.r3Minutes, "recipes[x]", "bad"))
        #expect(issue.hashValue == SeedIssue(.r3Minutes, "recipes[x]", "bad").hashValue)
        #expect(issue != SeedIssue(.r2MealTypes, "recipes[x]", "bad"))
        #expect(issue.description == "R3 recipes[x]: bad")
        #expect(SeedIssueCode.coverageProtein.rule == "C-protein")
    }

    @Test("rule ids match the seed guide")
    func ruleIds() {
        #expect(
            SeedIssueCode.allCases.map(\.rule) == [
                "I1", "I2", "I3", "I4", "I5", "I6", "I7", "R1", "R2", "R3", "R4", "R5", "R6", "R7",
                "R8", "R9", "R10", "R11", "C-totals", "C-meals", "C-regions", "C-dishTypes",
                "C-bases", "C-heaviness", "C-quick", "C-protein",
            ])
    }

    // MARK: I1

    @Test(
        "I1 rejects ids outside ^[a-z][a-z0-9_]*$",
        arguments: ["Potato", "1potato", "aloo-gobi", "_x", "", "aloo\n", "caf\u{E9}"])
    func badIngredientId(id: String) {
        expectOnlyIssue(
            F.withExtraIngredients([F.ingredient(id, "Bad Id")]), .i1IngredientId,
            "ingredients[\(id)]"
        ) { $0.hasPrefix("id must match") }
    }

    @Test("I1 reserves the user_ prefix")
    func userPrefix() {
        expectOnlyIssue(
            F.withExtraIngredients([F.ingredient("user_paneer", "My Paneer")]), .i1IngredientId,
            "ingredients[user_paneer]"
        ) { $0.contains("reserved") }
    }

    @Test("I1 rejects duplicate ids")
    func duplicateIngredientId() {
        expectOnlyIssue(
            F.withExtraIngredients([F.ingredient("rice", "Rice Again")]), .i1IngredientId,
            "ingredients[rice]", "duplicate id")
    }

    // MARK: I2

    @Test("I2 rejects a blank name")
    func blankName() {
        expectOnlyIssue(
            F.withIngredient("rice") { $0.copy(name: "  ") }, .i2IngredientName,
            "ingredients[rice].name", "name is blank")
    }

    @Test("I2 rejects surrounding whitespace")
    func untrimmedName() {
        expectOnlyIssue(
            F.withIngredient("rice") { $0.copy(name: "Rice ") }, .i2IngredientName,
            "ingredients[rice].name", "name has surrounding whitespace")
    }

    @Test("I2 rejects names equal after normalising, reported once")
    func duplicateName() {
        expectOnlyIssue(
            F.withExtraIngredients([F.ingredient("rice_2", "RICE")]), .i2IngredientName,
            "ingredients[rice_2].name", "name \"RICE\" is also used by rice")
    }

    @Test("I2 reports an untrimmed duplicate name twice")
    func untrimmedDuplicateName() {
        let issues = F.withExtraIngredients([F.ingredient("rice_2", " Rice")])
        #expect(
            issues == [
                SeedIssue(
                    .i2IngredientName, "ingredients[rice_2].name", "name has surrounding whitespace"
                ),
                SeedIssue(
                    .i2IngredientName, "ingredients[rice_2].name",
                    "name \" Rice\" is also used by rice"),
            ])
    }

    // MARK: I3

    @Test("I3 an alias shared by two ingredients")
    func sharedAlias() {
        expectOnlyIssue(
            F.withExtraIngredients([F.ingredient("sweet_potato", "Sweet Potato", aliases: ["aloo"])]
            ),
            .i3AliasCollision, "ingredients",
            "\"aloo\" resolves to more than one ingredient: potato, sweet_potato")
    }

    @Test("I3 an alias equal to another ingredient's name")
    func aliasEqualsOtherName() {
        expectOnlyIssue(
            F.withExtraIngredients([F.ingredient("shallots", "Shallots", aliases: ["onion"])]),
            .i3AliasCollision, "ingredients"
        ) { $0.contains("onion, shallots") }
    }

    @Test("I3 reports every colliding key, in first-seen order")
    func everyCollidingKey() {
        let issues = F.withExtraIngredients([F.ingredient("x", "X", aliases: ["pyaz", "aloo"])])
        #expect(issues.count == 2)
        #expect(issues.first?.message.contains("\"aloo\"") == true)
        #expect(issues.last?.message.contains("\"pyaz\"") == true)
    }

    @Test("I3 an alias repeated within one ingredient")
    func repeatedAlias() {
        expectOnlyIssue(
            F.withIngredient("potato") { $0.copy(aliases: ["aloo", "batata", "aloo"]) },
            .i3AliasCollision, "ingredients[potato].aliases[2]", "alias \"aloo\" is listed twice")
    }

    @Test("I3 an alias equal to its own name")
    func aliasEqualsOwnName() {
        expectOnlyIssue(
            F.withIngredient("potato") { $0.copy(aliases: ["potato"]) }, .i3AliasCollision,
            "ingredients[potato].aliases[0]", "alias \"potato\" repeats the ingredient name")
    }

    // MARK: I4

    @Test("I4 rejects a blank alias")
    func blankAlias() {
        expectOnlyIssue(
            F.withIngredient("potato") { $0.copy(aliases: ["aloo", " "]) }, .i4AliasFormat,
            "ingredients[potato].aliases[1]", "blank alias")
    }

    @Test(
        "I4 rejects aliases that are not already normalised",
        arguments: ["Aloo", " aloo", "aloo  tikki"])
    func unnormalisedAlias(alias: String) {
        expectOnlyIssue(
            F.withIngredient("potato") { $0.copy(aliases: [alias]) }, .i4AliasFormat,
            "ingredients[potato].aliases[0]"
        ) { $0.contains("must be lowercase, trimmed and single-spaced") }
    }

    // MARK: I5

    @Test("I5 rejects values outside 1..3650", arguments: [0, -1, 3651])
    func shelfLifeRange(days: Int) {
        expectOnlyIssue(
            F.withIngredient("potato") { $0.withShelfLifeDays(days) }, .i5ShelfLife,
            "ingredients[potato].shelfLifeDays", "\(days) is outside 1–3650")
    }

    @Test("I5 accepts the bounds", arguments: [1, 3650])
    func shelfLifeBounds(days: Int) {
        #expect(F.withIngredient("potato") { $0.withShelfLifeDays(days) }.isEmpty)
    }

    @Test(
        "I5 is required for sabzi, fruit, dairy and meat/egg ids",
        arguments: ["potato", "coconut", "paneer", "eggs"])
    func shelfLifeRequired(id: String) {
        expectOnlyIssue(
            F.withIngredient(id) { $0.withShelfLifeDays(nil) }, .i5ShelfLife,
            "ingredients[\(id)].shelfLifeDays", "required for a perishable ingredient")
    }

    @Test("I5 is optional for non-perishables")
    func shelfLifeOptional() {
        #expect(F.ingredients.first { $0.id == "rice" }?.shelfLifeDays == nil)
        #expect(F.validate(F.bundle()).isEmpty)
    }

    // MARK: I6

    @Test("I6 sabzi must come from the sabziwala")
    func sabziVendor() {
        expectOnlyIssue(
            F.withIngredient("potato") { $0.copy(buyFrom: .kirana) }, .i6BuyFrom,
            "ingredients[potato].buyFrom", "sabzi must be bought from sabziwala, not kirana")
    }

    @Test("I6 dairy must come from the dairy")
    func dairyVendor() {
        expectOnlyIssue(
            F.withIngredient("paneer") { $0.copy(buyFrom: .other) }, .i6BuyFrom,
            "ingredients[paneer].buyFrom", "dairy must be bought from dairy, not other")
    }

    @Test("I6 coconut is exempt by default; exemptions are explicit")
    func coconutExemption() {
        #expect(SeedRuleExemptions().buyFrom == ["coconut"])
        expectOnlyIssue(
            F.validate(F.bundle(), exemptions: SeedRuleExemptions(buyFrom: [])), .i6BuyFrom,
            "ingredients[coconut].buyFrom")
    }

    @Test("I6 other categories may come from anywhere")
    func otherVendor() {
        #expect(F.withIngredient("rice") { $0.copy(buyFrom: .other) }.isEmpty)
    }

    // MARK: I7

    @Test("I7 rejects fewer than 12 staples")
    func tooFewStaples() {
        expectOnlyIssue(
            F.withIngredient("atta") { $0.copy(role: .core) }, .i7Staples, "ingredients",
            "11 staples; expected 12–25")
    }

    @Test("I7 rejects more than 25 staples")
    func tooManyStaples() {
        expectOnlyIssue(
            F.withExtraIngredients((0..<14).map { F.staple("extra_\($0)", "Extra \($0)") }),
            .i7Staples, "ingredients", "26 staples; expected 12–25")
    }

    @Test("I7 accepts exactly 25")
    func exactlyMaxStaples() {
        #expect(
            F.withExtraIngredients((0..<13).map { F.staple("extra_\($0)", "Extra \($0)") }).isEmpty)
    }

    @Test("I7 only masala, oilGhee, grains and other may be staples")
    func stapleCategories() {
        expectOnlyIssue(
            F.withExtraIngredients([
                F.ingredient(
                    "lemon", "Lemon", category: .sabzi, role: .staple, buyFrom: .sabziwala,
                    shelfLifeDays: 14)
            ]),
            .i7Staples, "ingredients[lemon].role",
            "a sabzi ingredient cannot be a staple (allowed: masala, oilGhee, grains, other)")
    }

    @Test("SeedValidator.isValidId matches the id pattern")
    func isValidId() {
        #expect(SeedValidator.isValidId("aloo_gobi2"))
        #expect(!SeedValidator.isValidId("Aloo"))
        #expect(SeedValidator.idPattern == "^[a-z][a-z0-9_]*$")
    }
}
