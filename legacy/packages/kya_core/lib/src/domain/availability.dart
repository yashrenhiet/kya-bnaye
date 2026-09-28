import 'package:kya_core/src/domain/enums.dart';
import 'package:kya_core/src/domain/pantry_item.dart';

/// The single definition of "is this ingredient available right now" —
/// shared by the recommender (`RankingContext.isIngredientAvailable`) and
/// the shopping-list builder, so the rule can only ever be defined once.
///
/// - A staple is assumed available unless explicitly marked
///   [StockLevel.out] (`AGENTS.md` section 5.4).
/// - An [IngredientRole.optional] ingredient (a garnish) is always treated
///   as available: it never counts as missing, never blocks a recipe and
///   is never auto-added to the shopping list
///   (`docs/design/RECOMMENDER.md` section 5: "optional items never count
///   as missing"). This applies whatever the recipe line says; a line's own
///   `RecipeIngredient.isOptional` flag is the other, per-recipe way to
///   make an ingredient optional.
/// - Every other role (including an id missing from the catalog, where
///   [role] is `null`) needs an actual [PantryItem] recorded as not-out —
///   no record means "never bought".
bool resolveIngredientAvailability({
  required String ingredientId,
  required IngredientRole? role,
  required Map<String, PantryItem> pantry,
}) {
  switch (role) {
    case IngredientRole.optional:
      return true;
    case IngredientRole.staple:
      return pantry[ingredientId]?.level != StockLevel.out;
    case IngredientRole.core || IngredientRole.flavor || null:
      return pantry[ingredientId]?.level.isAvailable ?? false;
  }
}
