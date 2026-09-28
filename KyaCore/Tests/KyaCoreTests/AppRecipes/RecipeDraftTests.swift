import Foundation
import KyaCore
import Testing

@Suite("RecipeDraft validation and building")
struct RecipeDraftTests {
    private typealias F = AppRecipesFixtures

    private var valid: RecipeDraft {
        RecipeDraft(
            name: "Jeera Aloo", mealTypes: [.lunch], minutes: 20, base: .roti,
            ingredients: [F.line("potato"), F.line("jeera")], steps: ["Fry jeera.", "Add aloo."],
            region: .north, dishType: .drySabzi, flavours: [.savoury], heaviness: .light,
            protein: .vegOnly)
    }

    private func issues(_ draft: RecipeDraft, existing: [Recipe] = [], editing: String? = nil)
        -> [RecipeDraftIssue]
    {
        draft.validate(
            ingredientsById: F.catalogById, existingRecipes: existing, editingId: editing)
    }

    @Test("a complete draft has no issues")
    func validDraft() {
        #expect(issues(valid).isEmpty)
    }

    @Test("blank name, no meal types, bad minutes and no steps are reported in field order")
    func basics() {
        var draft = valid
        draft.name = "   "
        draft.mealTypes = []
        draft.minutes = 0
        draft.steps = ["  ", ""]
        #expect(issues(draft) == [.blankName, .noMealTypes, .minutesOutOfRange, .noSteps])
        draft.minutes = RecipeDraft.minutesRange.upperBound + 1
        #expect(issues(draft).contains(.minutesOutOfRange))
    }

    @Test("a name already used by another recipe is rejected, but not by the recipe itself")
    func duplicateName() {
        let existing = [F.recipe("jeera_aloo", name: "jeera  aloo")]
        #expect(issues(valid, existing: existing) == [.duplicateName])
        #expect(issues(valid, existing: existing, editing: "jeera_aloo").isEmpty)
    }

    @Test("ingredients: none, unknown, repeated and no required core line")
    func ingredients() {
        var draft = valid
        draft.ingredients = []
        #expect(issues(draft) == [.noIngredients, .noCoreIngredient])
        draft.ingredients = [F.line("mystery"), F.line("jeera"), F.line("jeera")]
        #expect(
            issues(draft) == [
                .unknownIngredient("mystery"), .repeatedIngredient("jeera"), .noCoreIngredient,
            ])
        draft.ingredients = [F.line("potato", optional: true), F.line("salt")]
        #expect(issues(draft) == [.noCoreIngredient])
    }

    @Test("flavours must be non-empty and never both mild and spicy")
    func flavours() {
        var draft = valid
        draft.flavours = []
        #expect(issues(draft) == [.noFlavours])
        draft.flavours = [.mild, .spicy]
        #expect(issues(draft) == [.mildAndSpicy])
    }

    @Test("rice dishes need a rice base; breads need roti or bread")
    func base() {
        var draft = valid
        draft.dishType = .rice
        #expect(issues(draft) == [.baseMismatch])
        draft.base = .rice
        #expect(issues(draft).isEmpty)
        draft.dishType = .bread
        draft.base = .bread
        #expect(issues(draft).isEmpty)
    }

    @Test("every issue has a user-facing message")
    func messages() {
        let all: [RecipeDraftIssue] = [
            .blankName, .duplicateName, .noMealTypes, .minutesOutOfRange, .noSteps,
            .noIngredients, .unknownIngredient("x"), .repeatedIngredient("x"), .noCoreIngredient,
            .noFlavours, .mildAndSpicy, .baseMismatch,
        ]
        #expect(all.allSatisfy { !$0.message.isEmpty })
        #expect(Set(all.map(\.message)).count == all.count)
    }

    @Test("makeRecipe trims text, drops blank steps and keeps flags")
    func makeRecipe() {
        var draft = valid
        draft.name = "  Jeera Aloo "
        draft.steps = [" Fry jeera. ", "  ", "Add aloo."]
        draft.ingredients = [RecipeIngredient(ingredientId: "potato", quantityText: " 2 ")]
        let recipe = draft.makeRecipe(
            id: "user_x", source: .user, isFavorite: true, isHidden: false)
        #expect(recipe.id == "user_x")
        #expect(recipe.name == "Jeera Aloo")
        #expect(recipe.steps == ["Fry jeera.", "Add aloo."])
        #expect(recipe.ingredients == [RecipeIngredient(ingredientId: "potato", quantityText: "2")])
        #expect(recipe.isFavorite)
        #expect(recipe.source == .user)
        #expect(
            recipe.tags
                == DishTags(
                    region: .north, dishType: .drySabzi, flavours: [.savoury], heaviness: .light,
                    protein: .vegOnly))
    }

    @Test("a draft built from a recipe round-trips its editable fields")
    func roundTrip() {
        let draft = RecipeDraft(recipe: F.alooMatar)
        let rebuilt = draft.makeRecipe(
            id: F.alooMatar.id, source: .seed, isFavorite: false, isHidden: false)
        #expect(rebuilt.isIdentical(to: F.alooMatar))
    }

    @Test("new ids are user-prefixed slugs, unique among existing ids")
    func newIds() {
        #expect(
            RecipeDraft.newRecipeId(forName: "Mom's Dal-Fry!", existingIds: [])
                == "user_mom_s_dal_fry")
        #expect(
            RecipeDraft.newRecipeId(forName: "Dal", existingIds: ["user_dal", "user_dal_2"])
                == "user_dal_3")
        #expect(RecipeDraft.newRecipeId(forName: "पोहा", existingIds: []) == "user_recipe")
        #expect(
            SeedValidator.isValidId(RecipeDraft.newRecipeId(forName: "9 Bean", existingIds: [])))
    }

    @Test("the default draft is empty and invalid only for missing content")
    func defaultDraft() {
        let draft = RecipeDraft()
        #expect(draft.name.isEmpty)
        #expect(
            issues(draft) == [
                .blankName, .noMealTypes, .noSteps, .noIngredients, .noCoreIngredient,
            ])
    }
}
