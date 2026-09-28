import Foundation
import KyaCore
import Testing

private let tags = DishTags(
    region: .north,
    dishType: .dal,
    flavours: [.savoury],
    heaviness: .medium,
    protein: .dalLegume
)

private let dalTadka = Recipe(
    id: "dal_tadka",
    name: "Dal Tadka",
    mealTypes: [.lunch, .dinner],
    minutes: 30,
    base: .rice,
    ingredients: [
        RecipeIngredient(ingredientId: "toor_dal", quantityText: "1 katori"),
        RecipeIngredient(ingredientId: "tomato", quantityText: "2 medium"),
        RecipeIngredient(ingredientId: "coriander", quantityText: "a handful", isOptional: true),
        RecipeIngredient(ingredientId: "ghee", quantityText: "1 tbsp"),
    ],
    steps: ["Boil dal.", "Temper with ghee."],
    tags: tags,
    source: .seed,
    imageAsset: "assets/dal_tadka.webp"
)

@Suite("Recipe")
struct RecipeTests {
    @Test("defaults: not favourite, not hidden, no image")
    func defaults() {
        let recipe = Recipe(
            id: "r", name: "R", mealTypes: [.snack], minutes: 5, base: .none, ingredients: [],
            steps: [], tags: tags, source: .user)

        #expect(!recipe.isFavorite)
        #expect(!recipe.isHidden)
        #expect(recipe.imageAsset == nil)
    }

    // MARK: requiredIngredients

    @Test("requiredIngredients excludes optional lines and keeps original order")
    func requiredExcludesOptional() {
        #expect(dalTadka.requiredIngredients.map(\.ingredientId) == ["toor_dal", "tomato", "ghee"])
    }

    @Test("requiredIngredients is empty when every ingredient is optional")
    func requiredEmptyWhenAllOptional() {
        let garnishOnly = dalTadka.copy(ingredients: [
            RecipeIngredient(ingredientId: "coriander", quantityText: "some", isOptional: true)
        ])

        #expect(garnishOnly.requiredIngredients.isEmpty)
    }

    @Test("requiredIngredients is empty for a recipe with no ingredients")
    func requiredEmptyWhenNoIngredients() {
        #expect(dalTadka.copy(ingredients: []).requiredIngredients.isEmpty)
    }

    @Test("requiredIngredients returns all lines when none are optional")
    func requiredAll() {
        let all = [
            RecipeIngredient(ingredientId: "rice", quantityText: "1 cup"),
            RecipeIngredient(ingredientId: "water", quantityText: "2 cups"),
        ]

        #expect(dalTadka.copy(ingredients: all).requiredIngredients == all)
    }

    // MARK: equality

    @Test("is identity-by-id regardless of other fields")
    func identityById() {
        let edited = dalTadka.copy(
            name: "Dal Fry", minutes: 45, source: .user, isFavorite: true, isHidden: true
        ).withImageAsset(nil)

        #expect(edited == dalTadka)
        #expect(edited.hashValue == dalTadka.hashValue)
        #expect(!edited.isIdentical(to: dalTadka))
    }

    @Test("different ids are not equal")
    func differentIds() {
        #expect(dalTadka.copy(id: "dal_fry") != dalTadka)
    }

    @Test("isIdentical compares every field")
    func isIdentical() {
        #expect(dalTadka.isIdentical(to: dalTadka.copy()))
        let variants = [
            dalTadka.copy(id: "x"), dalTadka.copy(name: "x"), dalTadka.copy(mealTypes: [.snack]),
            dalTadka.copy(minutes: 1), dalTadka.copy(base: .roti), dalTadka.copy(ingredients: []),
            dalTadka.copy(steps: []),
            dalTadka.copy(
                tags: DishTags(
                    region: .south, dishType: .dal, flavours: [.savoury], heaviness: .medium,
                    protein: .dalLegume)),
            dalTadka.withImageAsset("other.webp"), dalTadka.copy(isFavorite: true),
            dalTadka.copy(isHidden: true), dalTadka.copy(source: .user),
        ]
        for variant in variants {
            #expect(!dalTadka.isIdentical(to: variant))
        }
    }

    // MARK: copy

    @Test("copy with no arguments preserves every field")
    func copyPreserves() {
        let copy = dalTadka.copy()

        #expect(copy.id == dalTadka.id)
        #expect(copy.name == dalTadka.name)
        #expect(copy.mealTypes == dalTadka.mealTypes)
        #expect(copy.minutes == dalTadka.minutes)
        #expect(copy.base == dalTadka.base)
        #expect(copy.ingredients == dalTadka.ingredients)
        #expect(copy.steps == dalTadka.steps)
        #expect(copy.tags == dalTadka.tags)
        #expect(copy.imageAsset == dalTadka.imageAsset)
        #expect(copy.isFavorite == dalTadka.isFavorite)
        #expect(copy.isHidden == dalTadka.isHidden)
        #expect(copy.source == dalTadka.source)
    }

    @Test("copy replaces only the fields that are passed")
    func copyReplaces() {
        let copy = dalTadka.copy(mealTypes: [.breakfast], base: .roti, isFavorite: true)

        #expect(copy.isFavorite)
        #expect(copy.mealTypes == [.breakfast])
        #expect(copy.base == .roti)
        #expect(copy.name == "Dal Tadka")
        #expect(!copy.isHidden)
        #expect(copy.imageAsset == "assets/dal_tadka.webp")
    }

    @Test("copy leaves imageAsset unchanged")
    func copyKeepsImage() {
        #expect(dalTadka.copy(minutes: 10).imageAsset == "assets/dal_tadka.webp")
    }

    @Test("withImageAsset(nil) clears it")
    func clearImage() {
        let cleared = dalTadka.withImageAsset(nil)

        #expect(cleared.imageAsset == nil)
        #expect(cleared.name == dalTadka.name)
    }

    @Test("withImageAsset replaces it")
    func replaceImage() {
        #expect(dalTadka.withImageAsset("assets/new.webp").imageAsset == "assets/new.webp")
    }

    @Test("description includes id and name")
    func description() {
        #expect(dalTadka.description == "Recipe(dal_tadka, Dal Tadka)")
    }
}

@Suite("RecipeIngredient")
struct RecipeIngredientTests {
    private let line = RecipeIngredient(ingredientId: "tomato", quantityText: "2 medium")

    @Test("is not optional by default")
    func notOptionalByDefault() {
        #expect(!line.isOptional)
    }

    @Test("value equality over all fields")
    func valueEquality() {
        let same = RecipeIngredient(ingredientId: "tomato", quantityText: "2 medium")

        #expect(line == same)
        #expect(line.hashValue == same.hashValue)
    }

    @Test("differs by id, quantity text, or optionality")
    func differsByAnyField() {
        #expect(line != RecipeIngredient(ingredientId: "onion", quantityText: "2 medium"))
        #expect(line != RecipeIngredient(ingredientId: "tomato", quantityText: "3 medium"))
        #expect(
            line
                != RecipeIngredient(
                    ingredientId: "tomato", quantityText: "2 medium", isOptional: true))
    }
}

@Suite("MealLog")
struct MealLogTests {
    private let cookedAt: Date
    private let log: MealLog

    init() throws {
        cookedAt = try TestDates.local(2025, 6, 1, 20)
        log = MealLog(id: "m1", recipeId: "dal_tadka", mealType: .dinner, cookedAt: cookedAt)
    }

    @Test("value equality over all fields")
    func valueEquality() throws {
        let same = MealLog(
            id: "m1", recipeId: "dal_tadka", mealType: .dinner,
            cookedAt: try TestDates.local(2025, 6, 1, 20))

        #expect(log == same)
        #expect(log.hashValue == same.hashValue)
    }

    @Test("differs when any field differs")
    func differsByAnyField() {
        func with(
            id: String = "m1",
            recipeId: String = "dal_tadka",
            mealType: MealType = .dinner,
            at: Date? = nil
        ) -> MealLog {
            MealLog(id: id, recipeId: recipeId, mealType: mealType, cookedAt: at ?? cookedAt)
        }

        #expect(with(id: "m2") != log)
        #expect(with(recipeId: "poha") != log)
        #expect(with(mealType: .lunch) != log)
        #expect(with(at: cookedAt.addingTimeInterval(60)) != log)
    }
}
