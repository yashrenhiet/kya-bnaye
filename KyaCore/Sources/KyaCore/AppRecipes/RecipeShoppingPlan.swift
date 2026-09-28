import Foundation

/// "Add missing to shopping list" for one recipe.
///
/// Follows ``ShoppingListBuilder`` semantics for recipe rows (availability via
/// ``IngredientAvailability``; an ingredient is never added when an
/// **unchecked** item already carries it; checked and free-typed items never
/// block), but emits only ``ShoppingReason/recipe`` rows. The builder itself
/// also adds rows for every Low/Out pantry item, which this action must not do.
public enum RecipeShoppingPlan {
    /// The new shopping items for `recipe`'s missing ingredients.
    ///
    /// Postconditions: one item per missing ingredient not already on the
    /// list, in recipe order; each has reason ``ShoppingReason/recipe``,
    /// ``ShoppingItem/recipeId`` `== recipe.id`, `isChecked == false` and
    /// `createdAt == now`; `nextId` is called once per returned item.
    ///
    /// - Parameters:
    ///   - recipe: The recipe to shop for.
    ///   - ingredientsById: The catalog, keyed by id.
    ///   - pantry: Pantry records keyed by ingredient id.
    ///   - existingItems: The current shopping list.
    ///   - now: Timestamp for new items.
    ///   - nextId: Supplies a fresh item id.
    /// - Returns: The items to upsert; empty when nothing needs adding.
    public static func missingItems(
        for recipe: Recipe,
        ingredientsById: [String: Ingredient],
        pantry: [String: PantryItem],
        existingItems: [ShoppingItem],
        now: Date,
        nextId: () -> String
    ) -> [ShoppingItem] {
        let listed = Set(existingItems.lazy.filter { !$0.isChecked }.compactMap(\.ingredientId))
        let missing = RecipeCookability.evaluate(
            recipe, ingredientsById: ingredientsById, pantry: pantry
        )
        .missingIngredientIds
        return missing.filter { !listed.contains($0) }.map { ingredientId in
            ShoppingItem.catalogBacked(
                id: nextId(), ingredientId: ingredientId, reason: .recipe, recipeId: recipe.id,
                createdAt: now)
        }
    }
}
