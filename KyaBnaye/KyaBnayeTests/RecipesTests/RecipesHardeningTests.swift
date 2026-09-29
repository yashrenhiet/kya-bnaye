import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Double taps on recipe actions and editor inputs that must never corrupt the catalog.
@Suite("Recipes hardening")
@MainActor
struct RecipesHardeningTests {
    private typealias F = RecipeTestFixtures

    private func loadedStore(_ repositories: RepositorySet) async -> (
        RecipesStore, Task<Void, Never>
    ) {
        let store = RecipesStore(
            repositories: repositories, now: { F.now }, calendar: { .kyaDefault },
            makeId: F.sequentialIds())
        let task = Task { await store.observe() }
        await recipesWaitUntil { store.phase == .loaded }
        return (store, task)
    }

    @Test("a double tap on Favourite flips it twice, back to where it started")
    func doubleTapFavourite() async throws {
        let repositories = try await F.repositories()
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        async let first: Void = store.toggleFavorite(F.alooMatar)
        async let second: Void = store.toggleFavorite(F.alooMatar)
        _ = await (first, second)

        #expect(try await repositories.recipes.recipe(withId: "aloo_matar")?.isFavorite == false)
        #expect(store.recipe(withId: "aloo_matar")?.isFavorite == false)
    }

    @Test("a double tap on Add missing lists each missing ingredient once")
    func doubleTapAddMissing() async throws {
        let repositories = try await F.repositories(pantry: [("potato", .plenty)])
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        async let first = store.addMissingToShoppingList(F.alooMatar)
        async let second = store.addMissingToShoppingList(F.alooMatar)
        let added = await [first, second]

        #expect(added.sorted() == [0, 2])
        let list = try await repositories.shopping.all()
        #expect(list.compactMap(\.ingredientId).sorted() == ["jeera", "peas"])
    }

    @Test("a new ingredient whose id is taken reuses the catalog one instead of overwriting it")
    func newIngredientIdCollision() async throws {
        let repositories = try await F.repositories()
        let existing = Ingredient(
            id: "user_kasuri_methi", name: "Kasuri Methi", category: .masala, role: .flavor,
            buyFrom: .kirana, isUserCreated: true)
        try await repositories.ingredients.upsert([existing])
        let store = RecipeEditorStore(editing: nil, repositories: repositories)
        await store.load()

        store.ingredientQuery = "kasuri_methi"
        let name = try #require(store.newIngredientName)
        store.addNewIngredient(named: name)
        store.draft.name = "Methi Aloo"
        store.toggleMealType(.lunch)
        store.addIngredient(F.potato)
        store.draft.steps = ["Cook."]

        #expect(await store.save() != nil)
        let saved = try #require(
            try await repositories.ingredients.all().first { $0.id == "user_kasuri_methi" })
        #expect(saved.isIdentical(to: existing))
        #expect(store.draft.ingredients.map(\.ingredientId) == ["user_kasuri_methi", "potato"])
    }

    @Test("zero or too many minutes and an empty ingredient list block saving")
    func editorNegativeInputs() async throws {
        let repositories = try await F.repositories()
        let store = RecipeEditorStore(editing: nil, repositories: repositories)
        await store.load()
        store.draft.name = "   "
        store.draft.minutes = 0
        store.toggleMealType(.lunch)
        store.draft.steps = ["  "]

        #expect(await store.save() == nil)

        #expect(store.visibleIssues.contains(.blankName))
        #expect(store.visibleIssues.contains(.minutesOutOfRange))
        #expect(store.visibleIssues.contains(.noIngredients))
        #expect(store.visibleIssues.contains(.noSteps))
        store.draft.minutes = RecipeDraft.minutesRange.upperBound + 1
        #expect(store.issues.contains(.minutesOutOfRange))
        #expect(try await repositories.recipes.all().count == 4)
    }
}
