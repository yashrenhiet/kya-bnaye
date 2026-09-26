import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/penalties.dart';
import 'package:kya_core/src/recommend/ranking_context.dart';
import 'package:kya_core/src/recommend/ranking_strategy.dart';
import 'package:kya_core/src/recommend/taste_profile.dart';

/// "What can I make with what's home right now?" — the default mode
/// (decision D5). Full formula: `docs/design/RECOMMENDER.md` section 5.
class KitchenRanker implements RankingStrategy {
  const KitchenRanker();

  @override
  bool get supportsExploration => false;

  @override
  ScoredRecipe? score(Recipe recipe, RankingContext context) {
    if (isHardExcluded(recipe, context)) return null;
    if (!recipe.mealTypes.contains(context.currentMealType)) return null;

    final rejectPenalty = Penalties.rejectPenalty(
      lastLeftSwipeAt: context.lastLeftSwipeAtByRecipe[recipe.id],
      now: context.now,
      config: context.config,
    );
    if (rejectPenalty == null) return null; // recently left-swiped

    final required = recipe.requiredIngredients.toList();
    final missing = <String>[];
    final expiringSoon = <String>[];
    double totalWeight = 0;
    double availableWeight = 0;
    double coreTotalWeight = 0;
    double coreAvailableWeight = 0;

    for (final ri in required) {
      final ingredient = context.ingredientsById[ri.ingredientId];
      final weight = context.ingredientWeight(ri.ingredientId);
      final available = context.isIngredientAvailable(ri.ingredientId);

      totalWeight += weight;
      if (available) {
        availableWeight += weight;
      } else {
        missing.add(ri.ingredientId);
      }

      if (ingredient?.role == IngredientRole.core) {
        coreTotalWeight += weight;
        if (available) coreAvailableWeight += weight;
      }

      final pantryItem = context.pantry[ri.ingredientId];
      if (available &&
          pantryItem != null &&
          pantryItem.isExpiringWithin(
            context.config.expiringWithinDays,
            context.now,
          )) {
        expiringSoon.add(ri.ingredientId);
      }
    }

    if (missing.length > context.config.kitchenMaxMissingRequired) return null;

    final weightedCoverage = totalWeight > 0
        ? availableWeight / totalWeight
        : 1.0;
    final coreCoverage = coreTotalWeight > 0
        ? coreAvailableWeight / coreTotalWeight
        : 1.0;
    final expiringUse = required.isEmpty
        ? 0.0
        : expiringSoon.length / required.length;
    final taste = tasteScoreFor(
      recipe.tags,
      context.tasteProfile,
      context.config,
    );
    final isQuick = recipe.minutes <= context.config.quickThresholdMinutes;
    final sameBase =
        recipe.base != DishBase.none && recipe.base == context.lastCookedBase;
    final repeatPenalty = Penalties.repeatPenalty(
      lastCookedAt: context.lastCookedAtByRecipe[recipe.id],
      cookCountInRutWindow:
          context.cookCountInRutWindowByRecipe[recipe.id] ?? 0,
      now: context.now,
      config: context.config,
    );

    final config = context.config;
    final rawScore =
        config.kitchenWeightedCoverageWeight * weightedCoverage +
        config.kitchenCoreCoverageWeight * coreCoverage +
        config.kitchenExpiringUseWeight * expiringUse +
        config.kitchenTasteWeight * taste +
        config.kitchenFavouriteWeight * (recipe.isFavorite ? 1 : 0) +
        config.kitchenQuickWeight * (isQuick ? 1 : 0) -
        repeatPenalty -
        rejectPenalty -
        config.kitchenSameBaseAsLastMealPenalty * (sameBase ? 1 : 0);

    final tier = expiringSoon.isNotEmpty
        ? RecipeTier.useItUp
        : switch (missing.length) {
            0 => RecipeTier.readyNow,
            1 => RecipeTier.missing1,
            _ => RecipeTier.missing2,
          };

    return ScoredRecipe(
      recipe: recipe,
      score: rawScore,
      tier: tier,
      missingIngredientIds: missing,
      explanation: _explain(
        tier: tier,
        expiringIngredientIds: expiringSoon,
        missingIngredientIds: missing,
        availableCount: required.length - missing.length,
        totalCount: required.length,
        context: context,
      ),
    );
  }

  String _explain({
    required RecipeTier tier,
    required List<String> expiringIngredientIds,
    required List<String> missingIngredientIds,
    required int availableCount,
    required int totalCount,
    required RankingContext context,
  }) {
    String nameOf(String id) => context.ingredientsById[id]?.name ?? id;

    if (tier == RecipeTier.useItUp) {
      final name = nameOf(expiringIngredientIds.first);
      final tail = missingIngredientIds.isEmpty
          ? 'Nothing missing.'
          : 'Missing ${missingIngredientIds.length}.';
      return 'Uses your $name before it spoils. $tail';
    }
    if (tier == RecipeTier.readyNow) {
      return 'You have everything for this — nothing missing.';
    }
    final missingNames = missingIngredientIds.map(nameOf).join(', ');
    return 'You have $availableCount of $totalCount ingredients. '
        'Missing: $missingNames.';
  }
}
