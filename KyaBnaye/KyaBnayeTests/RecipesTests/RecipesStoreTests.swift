import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

@Suite("RecipesStore")
@MainActor
struct RecipesStoreTests {
    private typealias F = RecipeTestFixtures

    /// A store observing `repositories`, loaded; cancel the returned task when done.
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

    @Test("loads visible recipes sorted by name with cookable status; hidden excluded")
    func loadsRows() async throws {
        let repositories = try await F.repositories(pantry: [("potato", .plenty), ("jeera", .low)])
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        #expect(store.rows.map(\.id) == ["aloo_matar", "jeera_aloo", "paneer_bhurji"])
        #expect(store.rows.map(\.statusText) == ["1 missing", "Ready", "1 missing"])
        #expect(store.hiddenRecipes.map(\.id) == ["hidden_dish"])
        #expect(!store.hasNoVisibleRecipes)
    }

    @Test("filters: search, cookable now, quick, favourite and meal type")
    func filters() async throws {
        let repositories = try await F.repositories(pantry: [("potato", .plenty), ("jeera", .low)])
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        store.filter.searchText = "aloo"
        #expect(store.rows.map(\.id) == ["aloo_matar", "jeera_aloo"])
        store.filter = RecipeFilter(cookableNow: true)
        #expect(store.rows.map(\.id) == ["jeera_aloo"])
        store.filter = RecipeFilter(quick: true)
        #expect(store.rows.map(\.id) == ["aloo_matar", "jeera_aloo"])
        store.filter = RecipeFilter(favouritesOnly: true)
        #expect(store.rows.map(\.id) == ["paneer_bhurji"])
        store.filter = RecipeFilter(mealType: .dinner)
        #expect(store.rows.map(\.id) == ["aloo_matar", "paneer_bhurji"])
        store.filter = RecipeFilter(mealType: .snack)
        #expect(store.rows.isEmpty)
    }

    @Test("a pantry change elsewhere updates the cookable status")
    func followsPantry() async throws {
        let repositories = try await F.repositories(pantry: [("potato", .plenty)])
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }
        #expect(store.rows.first { $0.id == "jeera_aloo" }?.cookability.isReady == false)

        try await repositories.pantry.setLevels([
            PantryItem(ingredientId: "jeera", level: .plenty, updatedAt: F.now)
        ])
        await recipesWaitUntil {
            store.rows.first { $0.id == "jeera_aloo" }?.cookability.isReady == true
        }
    }

    @Test("toggling favourite writes through and flips back")
    func favourite() async throws {
        let repositories = try await F.repositories()
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        await store.toggleFavorite(F.alooMatar)
        #expect(try await repositories.recipes.recipe(withId: "aloo_matar")?.isFavorite == true)
        #expect(store.recipe(withId: "aloo_matar")?.isFavorite == true)
        #expect(store.confirmation == "Aloo Matar added to favourites")

        await store.toggleFavorite(F.alooMatar)
        #expect(try await repositories.recipes.recipe(withId: "aloo_matar")?.isFavorite == false)
    }

    @Test("hide removes a recipe from the list; unhide brings it back")
    func hideUnhide() async throws {
        let repositories = try await F.repositories()
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        await store.setHidden(true, for: F.jeeraAloo)
        #expect(!store.rows.map(\.id).contains("jeera_aloo"))
        #expect(store.hiddenRecipes.map(\.id) == ["hidden_dish", "jeera_aloo"])
        #expect(try await repositories.recipes.recipe(withId: "jeera_aloo")?.isHidden == true)

        await store.setHidden(false, for: F.hiddenDish)
        #expect(store.rows.map(\.id).contains("hidden_dish"))
        #expect(try await repositories.recipes.recipe(withId: "hidden_dish")?.isHidden == false)
    }

    @Test("delete removes a user recipe but only hides a seed recipe")
    func deleteRules() async throws {
        let repositories = try await F.repositories()
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        #expect(await store.delete(F.paneerBhurji))
        #expect(try await repositories.recipes.recipe(withId: "paneer_bhurji") == nil)

        #expect(await store.delete(F.alooMatar) == false)
        #expect(try await repositories.recipes.recipe(withId: "aloo_matar")?.isHidden == true)
    }

    @Test("add missing lists missing ingredients with reason recipe, without duplicates")
    func addMissing() async throws {
        let existing = try ShoppingItem(
            id: "old", ingredientId: "peas", reason: .manual, isChecked: false, createdAt: F.now)
        let repositories = try await F.repositories(
            pantry: [("potato", .plenty), ("salt", .out)], shopping: [existing])
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }

        #expect(await store.addMissingToShoppingList(F.alooMatar) == 2)
        let list = try await repositories.shopping.all()
        #expect(list.map(\.ingredientId) == ["peas", "jeera", "salt"])
        #expect(list.dropFirst().allSatisfy { $0.reason == .recipe && $0.recipeId == "aloo_matar" })
        #expect(store.confirmation == "Added 2 to your shopping list")

        #expect(await store.addMissingToShoppingList(F.alooMatar) == 0)
        #expect(try await repositories.shopping.all().count == 3)
        #expect(store.confirmation == "Everything missing is already on your list")
    }

    @Test("last made counts calendar days in the injected calendar")
    func lastMade() async throws {
        let calendar = try F.calendar()
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: F.now))
        let log = MealLog(id: "l1", recipeId: "jeera_aloo", mealType: .lunch, cookedAt: twoDaysAgo)
        let repositories = try await F.repositories(logs: [log])
        let store = RecipesStore(repositories: repositories, now: { F.now }, calendar: { calendar })
        let task = Task { await store.observe() }
        defer { task.cancel() }
        await recipesWaitUntil { store.phase == .loaded }

        #expect(store.daysSinceLastCooked("jeera_aloo") == 2)
        #expect(store.daysSinceLastCooked("aloo_matar") == nil)
    }

    @Test("a failing write surfaces an error and changes nothing")
    func writeFailure() async throws {
        let repositories = try await F.repositories()
        let (store, task) = await loadedStore(repositories)
        defer { task.cancel() }
        let ghost = F.alooMatar.copy(id: "ghost", name: "Ghost")

        await store.toggleFavorite(ghost)
        #expect(store.actionError == "Couldn't update Ghost. Please try again.")
        #expect(store.confirmation == nil)
    }
}
