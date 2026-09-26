import 'package:kya_core/src/domain/enums.dart';
import 'package:kya_core/src/domain/pantry_item.dart';

/// The single definition of "is this ingredient available right now" —
/// shared by the recommender (`RankingContext.isIngredientAvailable`) and
/// the shopping-list builder, so the rule can only ever be defined once.
///
/// A staple is assumed available unless explicitly marked [StockLevel.out];
/// every other role needs an actual [PantryItem] recorded as not-out — no
/// record means "never bought" (`AGENTS.md` section 5.4).
bool resolveIngredientAvailability({
  required String ingredientId,
  required IngredientRole? role,
  required Map<String, PantryItem> pantry,
}) {
  if (role == IngredientRole.staple) {
    return pantry[ingredientId]?.level != StockLevel.out;
  }
  return pantry[ingredientId]?.level.isAvailable ?? false;
}
