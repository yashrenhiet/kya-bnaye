import KyaCore
import Testing

/// Port of `legacy/packages/kya_core/test/seed/seed_validator_tags_test.dart`
/// (recipe rules R7–R11). R9 now expects `images/<recipe id>.webp`,
/// relative to `seed/` (the Dart original used `assets/seed/images/`).
@Suite("SeedValidator tags and images")
struct SeedValidatorTagsTests {
    typealias F = SeedFixtures

    // MARK: R7

    private func withLines(_ core: Int) -> [SeedIssue] {
        let extras = (0..<9).map { F.ingredient("x_\($0)", "X \($0)") }
        return F.validate(
            F.bundle(
                ingredients: F.ingredients + extras,
                recipes: F.editRecipe("dal_chawal") { recipe in
                    recipe.copy(
                        ingredients: (0..<core).map { F.line("x_\($0)") }
                            // Staples and optional lines never count.
                            + F.staples.map { F.line($0.id) }
                            + [F.line("coriander_leaves"), F.line("toor_dal", optional: true)])
                }))
    }

    @Test("R7 rejects more than 8 required core/flavor ingredients")
    func tooManyShoppable() {
        #expect(
            withLines(9).contains(
                SeedIssue(
                    .r7RequiredCount, "recipes[dal_chawal].ingredients",
                    "9 required core/flavor ingredients; at most 8")))
    }

    @Test("R7 accepts 8, ignoring staples and optional ones")
    func eightShoppable() {
        #expect(!withLines(8).map(\.code).contains(.r7RequiredCount))
    }

    // MARK: R8

    @Test("R8 rejects empty flavours")
    func noFlavours() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") { $0.copy(tags: F.tags(of: $0, flavours: [])) }, .r8Flavours,
            "recipes[dal_chawal].tags.flavours", "no flavours")
    }

    @Test("R8 rejects mild together with spicy")
    func mildAndSpicy() {
        expectOnlyIssue(
            F.withRecipe("dal_chawal") {
                $0.copy(tags: F.tags(of: $0, flavours: [.mild, .spicy]))
            },
            .r8Flavours, "recipes[dal_chawal].tags.flavours", "a dish cannot be both mild and spicy"
        )
    }

    // MARK: R9

    @Test(
        "R9 rejects a path that is not images/<id>.webp",
        arguments: [
            "images/jeera_rice.jpg", "images/other.webp", "assets/seed/images/jeera_rice.webp",
            "seed/images/jeera_rice.webp", "/images/jeera_rice.webp",
        ])
    func wrongImagePath(path: String) {
        expectOnlyIssue(
            F.withRecipe("jeera_rice") { $0.withImageAsset(path) }, .r9ImageAsset,
            "recipes[jeera_rice].imageAsset", "\"\(path)\" must be \"\(F.jeeraRiceImage)\"")
    }

    @Test("R9 rejects a missing asset file")
    func missingImage() {
        expectOnlyIssue(
            F.validate(F.bundle(), assets: []), .r9ImageAsset, "recipes[jeera_rice].imageAsset",
            "\"\(F.jeeraRiceImage)\" not found")
    }

    @Test("R9 a nil image asset is fine and never looked up")
    func nilImage() {
        let bundle = F.bundle(recipes: F.editRecipe("jeera_rice") { $0.withImageAsset(nil) })
        var lookups: [String] = []
        let issues = SeedValidator().validate(bundle) { path in
            lookups.append(path)
            return false
        }
        #expect(issues.isEmpty)
        #expect(lookups.isEmpty)
    }

    // MARK: R10

    @Test("R10 a rice dish needs base rice")
    func riceBase() {
        expectOnlyIssue(
            F.withRecipe("jeera_rice") { $0.copy(base: .roti) }, .r10Base,
            "recipes[jeera_rice].base", "a rice dish needs base rice, not roti")
    }

    @Test("R10 a bread dish needs base roti or bread")
    func breadBase() {
        func bread(_ recipe: Recipe, _ base: DishBase) -> Recipe {
            recipe.copy(base: base, tags: F.tags(of: recipe, dishType: .bread))
        }
        expectOnlyIssue(
            F.withRecipe("aloo_sabzi") { bread($0, .none) }, .r10Base, "recipes[aloo_sabzi].base",
            "a bread dish needs base roti or bread, not none")
        #expect(F.withRecipe("aloo_sabzi") { bread($0, .bread) }.isEmpty)
    }

    @Test("R10 other dish types may use any base")
    func anyBase() {
        #expect(F.withRecipe("aloo_sabzi") { $0.copy(base: DishBase.none) }.isEmpty)
    }

    // MARK: R11

    private func withProteinRecipe(_ edit: (Recipe) -> Recipe) -> [SeedIssue] {
        let seafood = [
            F.ingredient("fish", "Fish", category: .other, buyFrom: .other, shelfLifeDays: 2),
            F.ingredient("prawns", "Prawns", category: .other, buyFrom: .other, shelfLifeDays: 2),
        ]
        return F.validate(
            F.bundle(
                ingredients: F.ingredients + seafood, recipes: F.editRecipe("paneer_bhurji", edit)))
    }

    private let proteinAt = "recipes[paneer_bhurji].tags.protein"

    @Test("R11 paneer needs a required paneer line")
    func paneerLine() {
        expectOnlyIssue(
            withProteinRecipe {
                $0.copy(ingredients: [F.line("potato"), F.line("paneer", optional: true)])
            }, .r11Protein, proteinAt, "paneer needs a required ingredient: paneer")
    }

    @Test("R11 egg needs eggs")
    func eggLine() {
        expectOnlyIssue(
            withProteinRecipe { $0.copy(tags: F.tags(of: $0, protein: .egg)) }, .r11Protein,
            proteinAt, "egg needs a required ingredient: eggs")
    }

    @Test(
        "R11 chicken and mutton need their own ingredient", arguments: [Protein.chicken, .mutton])
    func meatLine(protein: Protein) {
        expectOnlyIssue(
            withProteinRecipe { $0.copy(tags: F.tags(of: $0, protein: protein)) }, .r11Protein,
            proteinAt, "\(protein.rawValue) needs a required ingredient: \(protein.rawValue)")
    }

    @Test("R11 fish is satisfied by fish or prawns")
    func fishLine() {
        for id in ["fish", "prawns"] {
            #expect(
                withProteinRecipe {
                    $0.copy(
                        ingredients: [F.line(id), F.line("onion")],
                        tags: F.tags(of: $0, protein: .fish))
                }.isEmpty, "\(id)")
        }
        expectOnlyIssue(
            withProteinRecipe { $0.copy(tags: F.tags(of: $0, protein: .fish)) }, .r11Protein,
            proteinAt, "fish needs a required ingredient: fish or prawns")
    }

    @Test("R11 dalLegume needs a required dal-category ingredient")
    func dalLine() {
        expectOnlyIssue(
            withProteinRecipe {
                $0.copy(
                    ingredients: $0.ingredients + [F.line("toor_dal", optional: true)],
                    tags: F.tags(of: $0, protein: .dalLegume))
            }, .r11Protein, proteinAt, "dalLegume needs a required dal ingredient")
    }

    @Test("R11 vegOnly allows no paneer, egg, meat or fish, even optional")
    func vegOnly() {
        expectOnlyIssue(
            withProteinRecipe {
                $0.copy(
                    ingredients: [F.line("potato"), F.line("eggs", optional: true)],
                    tags: F.tags(of: $0, protein: .vegOnly))
            }, .r11Protein, proteinAt, "vegOnly dish contains eggs")
        expectOnlyIssue(
            withProteinRecipe { $0.copy(tags: F.tags(of: $0, protein: .vegOnly)) }, .r11Protein,
            proteinAt, "vegOnly dish contains paneer")
    }
}
