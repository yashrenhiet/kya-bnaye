import Foundation
import KyaCore
import Testing

/// Fixtures mirroring `legacy/packages/kya_core/test/seed/seed_fixtures.dart`
/// and its helper files.
enum SeedFixtures {
    // MARK: JSON fixtures (SeedCodec)

    static let ingredientFile = "ingredients/sabzi.json"
    static let recipeFile = "recipes/sabzi.json"
    static let potatoAt = "\(ingredientFile) › ingredients[0]"
    static let recipeAt = "\(recipeFile) › recipes[0]"
    static let codec = SeedCodec()

    static func manifestJSON() -> [String: Any] {
        ["seedVersion": 1, "ingredients": [ingredientFile], "recipes": [recipeFile]]
    }

    static func potatoRow() -> [String: Any] {
        [
            "id": "potato", "name": "Potato", "aliases": ["aloo", "batata"], "category": "sabzi",
            "role": "core", "buyFrom": "sabziwala", "shelfLifeDays": 21,
        ]
    }

    static func saltRow() -> [String: Any] {
        [
            "id": "salt", "name": "Salt", "aliases": [Any](), "category": "masala",
            "role": "staple", "buyFrom": "kirana",
        ]
    }

    static func alooRecipeRow() -> [String: Any] {
        [
            "id": "jeera_aloo",
            "name": "Jeera Aloo",
            "mealTypes": ["lunch", "dinner"],
            "minutes": 20,
            "base": "roti",
            "tags": [
                "region": "north", "dishType": "drySabzi", "flavours": ["spicy", "savoury"],
                "heaviness": "light", "protein": "vegOnly",
            ] as [String: Any],
            "ingredients": [
                ["ingredientId": "potato", "quantityText": "3 medium"],
                ["ingredientId": "salt", "quantityText": "to taste", "isOptional": true],
            ] as [Any],
            "steps": ["Boil and cube the potatoes.", "Temper jeera, toss, serve."],
            "imageAsset": NSNull(),
        ]
    }

    /// A valid `jsonByPath` for ``manifestJSON()``.
    static func fragmentsJSON() -> [String: Any] {
        [
            ingredientFile: ["ingredients": [potatoRow(), saltRow()]],
            recipeFile: ["recipes": [alooRecipeRow()]],
        ]
    }

    /// Fragments whose first ingredient row was changed by `edit`.
    static func withIngredientRow(_ edit: (inout [String: Any]) -> Void) -> [String: Any] {
        var fragments = fragmentsJSON()
        fragments.edit(ingredientFile) { $0.edit("ingredients", at: 0, edit) }
        return fragments
    }

    /// Fragments whose first recipe row was changed by `edit`.
    static func withRecipeRow(_ edit: (inout [String: Any]) -> Void) -> [String: Any] {
        var fragments = fragmentsJSON()
        fragments.edit(recipeFile) { $0.edit("recipes", at: 0, edit) }
        return fragments
    }

    static func decodeFragments(
        _ fragments: [String: Any]
    ) throws(SeedFormatError) -> SeedBundle {
        try codec.decode(
            try codec.decodeManifest(jsonObject: manifestJSON()), jsonByPath: fragments)
    }

    /// The error decoding `fragments` throws, or `nil` if it decodes.
    static func fragmentsError(_ fragments: [String: Any]) -> SeedFormatError? {
        seedError { () throws(SeedFormatError) in _ = try decodeFragments(fragments) }
    }

    /// The error decoding `manifest` throws, or `nil` if it decodes.
    static func manifestError(_ manifest: Any?) -> SeedFormatError? {
        seedError { () throws(SeedFormatError) in _ = try codec.decodeManifest(jsonObject: manifest)
        }
    }

    static func seedError(_ body: () throws(SeedFormatError) -> Void) -> SeedFormatError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    // MARK: Domain fixtures (SeedValidator)

    static func ingredient(
        _ id: String,
        _ name: String,
        category: IngredientCategory = .masala,
        role: IngredientRole = .core,
        buyFrom: BuyFrom = .kirana,
        aliases: [String] = [],
        shelfLifeDays: Int? = nil
    ) -> Ingredient {
        Ingredient(
            id: id, name: name, aliases: aliases, category: category, role: role, buyFrom: buyFrom,
            shelfLifeDays: shelfLifeDays)
    }

    static func staple(
        _ id: String, _ name: String, _ category: IngredientCategory = .masala
    ) -> Ingredient {
        ingredient(id, name, category: category, role: .staple)
    }

    /// Exactly `SeedValidator.staplesRange.lowerBound` (12) staples.
    static let staples: [Ingredient] = [
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
    ]

    static let ingredients: [Ingredient] =
        staples + [
            ingredient(
                "potato", "Potato", category: .sabzi, buyFrom: .sabziwala,
                aliases: ["aloo", "batata"], shelfLifeDays: 21),
            ingredient(
                "onion", "Onion", category: .sabzi, role: .flavor, buyFrom: .sabziwala,
                aliases: ["pyaz"], shelfLifeDays: 30),
            ingredient(
                "coriander_leaves", "Coriander Leaves", category: .sabzi, role: .optional,
                buyFrom: .sabziwala, aliases: ["dhania"], shelfLifeDays: 5),
            ingredient("paneer", "Paneer", category: .dairy, buyFrom: .dairy, shelfLifeDays: 4),
            ingredient(
                "eggs", "Eggs", category: .other, buyFrom: .other, aliases: ["anda"],
                shelfLifeDays: 21),
            ingredient("toor_dal", "Toor Dal", category: .dal),
            ingredient("rice", "Rice", category: .grains),
            ingredient("bread", "Bread", category: .grains),
            // Fruit bought from the kirana: allowed by the default I6 exemption.
            ingredient("coconut", "Coconut", category: .fruit, shelfLifeDays: 14),
        ]

    static func line(_ id: String, optional: Bool = false) -> RecipeIngredient {
        RecipeIngredient(ingredientId: id, quantityText: "1", isOptional: optional)
    }

    static func recipe(
        _ id: String,
        _ name: String,
        dishType: DishType,
        base: DishBase,
        protein: Protein,
        ingredients: [RecipeIngredient],
        mealTypes: Set<MealType> = [.lunch, .dinner],
        flavours: Set<Flavour> = [.savoury],
        imageAsset: String? = nil
    ) -> Recipe {
        Recipe(
            id: id, name: name, mealTypes: mealTypes, minutes: 30, base: base,
            ingredients: ingredients, steps: ["Prepare everything.", "Cook and serve."],
            tags: DishTags(
                region: .north, dishType: dishType, flavours: flavours, heaviness: .medium,
                protein: protein),
            source: .seed, imageAsset: imageAsset)
    }

    /// R9 now expects `images/<recipe id>.webp`, relative to `seed/` (Dart:
    /// `assets/seed/images/`).
    static let jeeraRiceImage = "images/jeera_rice.webp"

    static let recipes: [Recipe] = [
        recipe(
            "aloo_sabzi", "Aloo Sabzi", dishType: .drySabzi, base: .roti, protein: .vegOnly,
            ingredients: [
                line("potato"), line("onion"), line("salt"),
                line("coriander_leaves", optional: true),
            ],
            flavours: [.spicy, .savoury]),
        recipe(
            "dal_chawal", "Dal Chawal", dishType: .dal, base: .rice, protein: .dalLegume,
            ingredients: [line("toor_dal"), line("rice"), line("turmeric")], flavours: [.mild]),
        recipe(
            "paneer_bhurji", "Paneer Bhurji", dishType: .curry, base: .roti, protein: .paneer,
            ingredients: [line("paneer"), line("onion")]),
        recipe(
            "anda_bhurji", "Anda Bhurji", dishType: .breakfast, base: .bread, protein: .egg,
            ingredients: [line("eggs"), line("onion"), line("bread")], mealTypes: [.breakfast]),
        recipe(
            "jeera_rice", "Jeera Rice", dishType: .rice, base: .rice, protein: .vegOnly,
            ingredients: [line("rice"), line("cumin_seeds"), line("ghee")],
            imageAsset: jeeraRiceImage),
    ]

    static func bundle(ingredients: [Ingredient]? = nil, recipes: [Recipe]? = nil) -> SeedBundle {
        SeedBundle(
            seedVersion: 1, ingredients: ingredients ?? Self.ingredients,
            recipes: recipes ?? Self.recipes)
    }

    /// ``ingredients`` with the row `id` replaced by `edit(row)`.
    static func editIngredient(
        _ id: String, _ edit: (Ingredient) -> Ingredient
    ) -> [Ingredient] {
        ingredients.map { $0.id == id ? edit($0) : $0 }
    }

    /// ``recipes`` with the recipe `id` replaced by `edit(recipe)`.
    static func editRecipe(_ id: String, _ edit: (Recipe) -> Recipe) -> [Recipe] {
        recipes.map { $0.id == id ? edit($0) : $0 }
    }

    // MARK: Validation helpers

    static func validate(
        _ bundle: SeedBundle,
        assets: Set<String> = [jeeraRiceImage],
        exemptions: SeedRuleExemptions = SeedRuleExemptions()
    ) -> [SeedIssue] {
        SeedValidator().validate(bundle, assetExists: assets.contains, exemptions: exemptions)
    }

    static func withIngredient(_ id: String, _ edit: (Ingredient) -> Ingredient) -> [SeedIssue] {
        validate(bundle(ingredients: editIngredient(id, edit)))
    }

    static func withRecipe(_ id: String, _ edit: (Recipe) -> Recipe) -> [SeedIssue] {
        validate(bundle(recipes: editRecipe(id, edit)))
    }

    static func withExtraIngredients(_ extra: [Ingredient]) -> [SeedIssue] {
        validate(bundle(ingredients: ingredients + extra))
    }

    static func tags(
        of recipe: Recipe, flavours: Set<Flavour>? = nil, dishType: DishType? = nil,
        protein: Protein? = nil
    ) -> DishTags {
        DishTags(
            region: recipe.tags.region, dishType: dishType ?? recipe.tags.dishType,
            flavours: flavours ?? recipe.tags.flavours, heaviness: recipe.tags.heaviness,
            protein: protein ?? recipe.tags.protein)
    }
}

/// Expects exactly one issue with `code` and `location`, whose message
/// satisfies `message` (any message when `nil`).
func expectOnlyIssue(
    _ issues: [SeedIssue],
    _ code: SeedIssueCode,
    _ location: String,
    _ message: ((String) -> Bool)? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(issues.count == 1, "\(issues)", sourceLocation: sourceLocation)
    guard let issue = issues.first else { return }
    #expect(issue.code == code, "\(issue)", sourceLocation: sourceLocation)
    #expect(issue.location == location, "\(issue)", sourceLocation: sourceLocation)
    if let message {
        #expect(message(issue.message), "\(issue)", sourceLocation: sourceLocation)
    }
}

/// Expects exactly one issue equal to `code`, `location` and `message`.
func expectOnlyIssue(
    _ issues: [SeedIssue],
    _ code: SeedIssueCode,
    _ location: String,
    _ message: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(issues == [SeedIssue(code, location, message)], sourceLocation: sourceLocation)
}
