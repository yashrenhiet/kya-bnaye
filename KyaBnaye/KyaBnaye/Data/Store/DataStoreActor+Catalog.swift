import Foundation
import KyaCore
import SwiftData

// Ingredient catalog and recipe book operations. Orders and semantics follow the
// `KyaCore` port documentation (`IngredientRepository`, `RecipeRepository`).
extension DataStoreActor {
    // MARK: Ingredients

    /// Every ingredient, sorted by id.
    func allIngredients() throws -> [Ingredient] {
        try rows(IngredientRecord.self).sorted { $0.id < $1.id }
    }

    /// Inserts or fully replaces ingredients, atomically; last occurrence wins.
    func upsertIngredients(_ ingredients: [Ingredient]) throws {
        guard !ingredients.isEmpty else { return }
        try write([.ingredients]) {
            var existing = try recordsByKey(IngredientRecord.self)
            try upsert(ingredients, into: &existing)
        }
    }

    /// Inserts ingredients whose id is not stored, atomically; first occurrence wins.
    ///
    /// - Returns: The inserted ids, ascending.
    func insertMissingIngredients(_ ingredients: [Ingredient]) throws -> [String] {
        guard !ingredients.isEmpty else { return [] }
        return try write([.ingredients]) {
            try insertMissing(ingredients, as: IngredientRecord.self)
        }
    }

    // MARK: Recipes

    /// Every recipe (hidden ones included), sorted by id.
    func allRecipes() throws -> [Recipe] {
        try rows(RecipeRecord.self).sorted { $0.id < $1.id }
    }

    /// The recipe with `id`, if stored.
    func recipe(withId id: String) throws -> Recipe? {
        try recipeRecord(withId: id)?.toRow()
    }

    /// Inserts or fully replaces recipes, atomically; last occurrence wins.
    func upsertRecipes(_ recipes: [Recipe]) throws {
        guard !recipes.isEmpty else { return }
        try write([.recipes]) {
            var existing = try recordsByKey(RecipeRecord.self)
            try upsert(recipes, into: &existing)
        }
    }

    /// Inserts recipes whose id is not stored, atomically; first occurrence wins.
    ///
    /// - Returns: The inserted ids, ascending.
    func insertMissingRecipes(_ recipes: [Recipe]) throws -> [String] {
        guard !recipes.isEmpty else { return [] }
        return try write([.recipes]) {
            try insertMissing(recipes, as: RecipeRecord.self)
        }
    }

    /// Sets `isFavorite` on one recipe.
    ///
    /// - Throws: ``KyaCore/RepositoryError/notFound(_:)`` for an unknown id.
    func setFavorite(_ isFavorite: Bool, forRecipeWithId id: String) throws {
        try write([.recipes]) {
            guard let record = try recipeRecord(withId: id) else {
                throw RepositoryError.notFound(id)
            }
            record.isFavorite = isFavorite
        }
    }

    /// Sets `isHidden` on one recipe.
    ///
    /// - Throws: ``KyaCore/RepositoryError/notFound(_:)`` for an unknown id.
    func setHidden(_ isHidden: Bool, forRecipeWithId id: String) throws {
        try write([.recipes]) {
            guard let record = try recipeRecord(withId: id) else {
                throw RepositoryError.notFound(id)
            }
            record.isHidden = isHidden
        }
    }

    /// Deletes one recipe; an unknown id is a no-op.
    func deleteRecipe(id: String) throws {
        try write([.recipes]) {
            if let record = try recipeRecord(withId: id) {
                modelContext.delete(record)
            }
        }
    }

    private func recipeRecord(withId id: String) throws -> RecipeRecord? {
        var descriptor = FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
