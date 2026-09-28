import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

@Suite("RecipeEditorStore")
@MainActor
struct RecipeEditorStoreTests {
    private typealias F = RecipeTestFixtures

    private func loadedEditor(editing: Recipe? = nil) async throws
        -> (RecipeEditorStore, RepositorySet)
    {
        let repositories = try await F.repositories()
        let store = RecipeEditorStore(editing: editing, repositories: repositories)
        await store.load()
        #expect(store.phase == .ready)
        return (store, repositories)
    }

    private func fillValid(_ store: RecipeEditorStore) {
        store.draft.name = "Aloo Tikki"
        store.toggleMealType(.snack)
        store.ingredientQuery = "aloo"
        if let potato = store.suggestions.first { store.addIngredient(potato) }
        store.draft.steps = ["Mash and fry."]
    }

    @Test("validation is hidden until the first save attempt, then lists every issue")
    func validationOnSave() async throws {
        let (store, repositories) = try await loadedEditor()
        #expect(store.visibleIssues.isEmpty)

        #expect(await store.save() == nil)
        #expect(
            store.visibleIssues == [
                .blankName, .noMealTypes, .noSteps, .noIngredients, .noCoreIngredient,
            ])
        #expect(try await repositories.recipes.all().count == 4)
    }

    @Test("ingredient search resolves aliases and hides already-added ingredients")
    func aliasSuggestions() async throws {
        let (store, _) = try await loadedEditor()
        store.ingredientQuery = "matar"
        #expect(store.suggestions.map(\.id) == ["peas"])
        store.addIngredient(F.peas)
        #expect(store.ingredientQuery.isEmpty)
        store.ingredientQuery = "matar"
        #expect(store.suggestions.isEmpty)
        #expect(store.newIngredientName == nil)
    }

    @Test("a new recipe saves as a user recipe with a fresh id")
    func saveNew() async throws {
        let (store, repositories) = try await loadedEditor()
        fillValid(store)
        store.setQuantity("4 medium", forLineAt: 0)

        #expect(await store.save() == "Aloo Tikki added to your recipes")
        let saved = try #require(try await repositories.recipes.recipe(withId: "user_aloo_tikki"))
        #expect(saved.source == .user)
        #expect(saved.mealTypes == [.snack])
        #expect(
            saved.ingredients == [
                RecipeIngredient(ingredientId: "potato", quantityText: "4 medium")
            ])
        #expect(saved.steps == ["Mash and fry."])
    }

    @Test("an unknown typed ingredient is created as a user ingredient on save")
    func newIngredient() async throws {
        let (store, repositories) = try await loadedEditor()
        fillValid(store)
        store.ingredientQuery = "Kasuri Methi"
        let name = try #require(store.newIngredientName)
        store.addNewIngredient(named: name)
        store.setOptional(true, forLineAt: 1)

        #expect(await store.save() != nil)
        let created = try await repositories.ingredients.all().first {
            $0.id == "user_kasuri_methi"
        }
        #expect(created?.isUserCreated == true)
        let recipe = try #require(try await repositories.recipes.recipe(withId: "user_aloo_tikki"))
        #expect(
            recipe.ingredients.last
                == RecipeIngredient(
                    ingredientId: "user_kasuri_methi", quantityText: "", isOptional: true))
    }

    @Test("an edit keeps the id, source and current favourite flag")
    func saveEdit() async throws {
        let (store, repositories) = try await loadedEditor(editing: F.alooMatar)
        try await repositories.recipes.setFavorite(true, forRecipeWithId: "aloo_matar")
        store.draft.minutes = 35
        store.toggleFlavour(.spicy)

        #expect(await store.save() == "Aloo Matar saved")
        let saved = try #require(try await repositories.recipes.recipe(withId: "aloo_matar"))
        #expect(saved.minutes == 35)
        #expect(saved.source == .seed)
        #expect(saved.isFavorite)
        #expect(saved.tags.flavours == [.savoury, .spicy])
    }

    @Test("renaming to another recipe's name is rejected")
    func duplicateName() async throws {
        let (store, _) = try await loadedEditor(editing: F.alooMatar)
        store.draft.name = "jeera aloo"
        #expect(await store.save() == nil)
        #expect(store.visibleIssues == [.duplicateName])
    }

    @Test("removing lines and steps edits the draft")
    func removals() async throws {
        let (store, _) = try await loadedEditor(editing: F.alooMatar)
        store.removeIngredients(at: IndexSet(integer: 0))
        store.addStep()
        store.removeSteps(at: IndexSet(integer: 0))
        #expect(store.draft.ingredients.map(\.ingredientId) == ["peas", "jeera", "salt"])
        #expect(store.draft.steps == ["Cook.", ""])
        #expect(store.draft != store.initialDraft)
    }
}
