import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/kitchen_ranker.dart';
import 'package:kya_core/src/recommend/ranking_context.dart';
import 'package:kya_core/src/seed/seed_manifest.dart';

/// How many recipes in [bundle] Kitchen mode would offer for each meal
/// type, for a household that has exactly [atHome] (ingredient ids, all at
/// `plenty`, no expiry) plus the always-assumed staples.
///
/// Used to prove the seed catalogue gives a first-run user a real deck:
/// no swipe or cooking history, so only pantry coverage decides. Unknown
/// ids in [atHome] are harmless. [now] only feeds `RankingContext`; with
/// no history it does not change which recipes qualify.
Map<MealType, int> kitchenCandidateCounts(
  SeedBundle bundle, {
  required Set<String> atHome,
  required DateTime now,
}) {
  final pantry = [
    for (final id in atHome)
      PantryItem(ingredientId: id, level: StockLevel.plenty, updatedAt: now),
  ];
  const ranker = KitchenRanker();
  int candidates(MealType meal) {
    final context = RankingContext.build(
      allRecipes: bundle.recipes,
      pantry: pantry,
      catalog: bundle.ingredients,
      events: const [],
      mealLogs: const [],
      now: now,
      currentMealType: meal,
    );
    return bundle.recipes.where((r) => ranker.score(r, context) != null).length;
  }

  return {for (final meal in MealType.values) meal: candidates(meal)};
}
