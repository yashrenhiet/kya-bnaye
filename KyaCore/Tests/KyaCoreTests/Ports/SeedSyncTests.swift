import Foundation
import KyaCore
import Testing

private typealias F = ShoppingFixtures

@Suite("SeedSync")
struct SeedSyncTests {
    private let repos = makeInMemoryRepositorySet()

    private var sync: SeedSync {
        SeedSync(ingredients: repos.ingredients, recipes: repos.recipes, seedState: repos.seedState)
    }

    private let seedIngredients = [F.potato, F.onion, F.paneer]
    private let seedRecipes = [
        F.recipe("aloo_sabzi", [F.line("potato")]),
        F.recipe("palak_paneer", [F.line("paneer")]),
    ]

    @Test("first run inserts everything and records the version")
    func firstRun() async throws {
        let outcome = try await sync.apply(
            ingredients: seedIngredients, recipes: seedRecipes, version: 1)
        #expect(
            outcome
                == .applied(
                    SeedSyncReport(
                        previousVersion: nil, appliedVersion: 1,
                        insertedIngredientIds: ["onion", "paneer", "potato"],
                        insertedRecipeIds: ["aloo_sabzi", "palak_paneer"])))
        #expect(try await repos.ingredients.all().map(\.id) == ["onion", "paneer", "potato"])
        #expect(try await repos.recipes.all().map(\.id) == ["aloo_sabzi", "palak_paneer"])
        #expect(try await repos.seedState.seedVersion() == 1)
    }

    @Test("an equal or older version is a no-op")
    func upToDate() async throws {
        try await repos.seedState.setSeedVersion(2)
        for version in [1, 2] {
            let outcome = try await sync.apply(
                ingredients: seedIngredients, recipes: seedRecipes, version: version)
            #expect(outcome == .upToDate(storedVersion: 2))
        }
        #expect(try await repos.ingredients.all().isEmpty)
        #expect(try await repos.recipes.all().isEmpty)
        #expect(try await repos.seedState.seedVersion() == 2)
    }

    @Test("a newer version adds missing rows and never overwrites user edits")
    func upgradeProtectsEdits() async throws {
        _ = try await sync.apply(
            ingredients: [F.potato], recipes: [seedRecipes[0]], version: 1)
        let editedPotato = F.potato.copy(name: "Aloo (mine)")
        let editedRecipe = seedRecipes[0].copy(minutes: 5, isFavorite: true, isHidden: true)
        let userIngredient = F.dragonfruit
        try await repos.ingredients.upsert([editedPotato, userIngredient])
        try await repos.recipes.upsert([editedRecipe])

        let outcome = try await sync.apply(
            ingredients: seedIngredients, recipes: seedRecipes, version: 2)

        #expect(
            outcome
                == .applied(
                    SeedSyncReport(
                        previousVersion: 1, appliedVersion: 2,
                        insertedIngredientIds: ["onion", "paneer"],
                        insertedRecipeIds: ["palak_paneer"])))
        let ingredients = try await repos.ingredients.all()
        #expect(ingredients.map(\.id) == ["dragonfruit", "onion", "paneer", "potato"])
        #expect(ingredients.last?.isIdentical(to: editedPotato) == true)
        #expect(ingredients.first?.isIdentical(to: userIngredient) == true)
        let recipe = try #require(try await repos.recipes.recipe(withId: "aloo_sabzi"))
        #expect(recipe.isIdentical(to: editedRecipe))
        #expect(try await repos.seedState.seedVersion() == 2)
    }

    @Test("a deleted seed recipe returns on the next version bump")
    func deletedSeedRowReturns() async throws {
        _ = try await sync.apply(ingredients: [], recipes: seedRecipes, version: 1)
        try await repos.recipes.delete(id: "aloo_sabzi")
        _ = try await sync.apply(ingredients: [], recipes: seedRecipes, version: 1)
        #expect(try await repos.recipes.all().map(\.id) == ["palak_paneer"])
        _ = try await sync.apply(ingredients: [], recipes: seedRecipes, version: 2)
        #expect(try await repos.recipes.all().map(\.id) == ["aloo_sabzi", "palak_paneer"])
    }

    @Test("a failure keeps the old version so the next launch completes the sync")
    func failureKeepsVersion() async throws {
        let failing = SeedSync(
            ingredients: repos.ingredients, recipes: FailingRecipes(),
            seedState: repos.seedState)
        await #expect(throws: SeedSyncFault.self) {
            try await failing.apply(ingredients: seedIngredients, recipes: seedRecipes, version: 1)
        }
        #expect(try await repos.seedState.seedVersion() == nil)

        let outcome = try await sync.apply(
            ingredients: seedIngredients, recipes: seedRecipes, version: 1)
        #expect(
            outcome
                == .applied(
                    SeedSyncReport(
                        previousVersion: nil, appliedVersion: 1, insertedIngredientIds: [],
                        insertedRecipeIds: ["aloo_sabzi", "palak_paneer"])))
    }

    @Test("the SeedBundle overload applies the bundle's rows and version")
    func bundleOverload() async throws {
        let bundle = SeedBundle(seedVersion: 3, ingredients: [F.onion], recipes: [])
        let outcome = try await sync.apply(bundle)
        #expect(
            outcome
                == .applied(
                    SeedSyncReport(
                        previousVersion: nil, appliedVersion: 3,
                        insertedIngredientIds: ["onion"], insertedRecipeIds: [])))
        #expect(try await repos.seedState.seedVersion() == 3)
    }
}

private struct SeedSyncFault: Error {}

/// A recipe repository whose writes always fail.
private struct FailingRecipes: RecipeRepository {
    func all() async -> [Recipe] { [] }
    func watchAll() -> AsyncThrowingStream<[Recipe], any Error> {
        AsyncThrowingStream { $0.finish(throwing: SeedSyncFault()) }
    }
    func recipe(withId id: String) async -> Recipe? { nil }
    func upsert(_ recipes: [Recipe]) async throws { throw SeedSyncFault() }
    func insertMissing(_ recipes: [Recipe]) async throws -> [String] { throw SeedSyncFault() }
    func setFavorite(_ isFavorite: Bool, forRecipeWithId id: String) async throws {
        throw SeedSyncFault()
    }
    func setHidden(_ isHidden: Bool, forRecipeWithId id: String) async throws {
        throw SeedSyncFault()
    }
    func delete(id: String) async throws { throw SeedSyncFault() }
}
