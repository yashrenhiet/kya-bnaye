import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/penalties.dart';
import 'package:kya_core/src/recommend/ranking_context.dart';
import 'package:kya_core/src/recommend/ranking_strategy.dart';
import 'package:kya_core/src/recommend/taste_profile.dart';

/// "What would I enjoy, whether or not it's at home?" — the learned-taste
/// mode. Full formula: `docs/design/RECOMMENDER.md` section 4.
class CravingRanker implements RankingStrategy {
  const CravingRanker();

  @override
  bool get supportsExploration => true;

  @override
  ScoredRecipe? score(Recipe recipe, RankingContext context) {
    if (isHardExcluded(recipe, context)) return null;

    final rejectPenalty = Penalties.rejectPenalty(
      lastLeftSwipeAt: context.lastLeftSwipeAtByRecipe[recipe.id],
      now: context.now,
      config: context.config,
    );
    if (rejectPenalty == null) return null; // recently left-swiped

    final required = recipe.requiredIngredients.toList();
    final missing = <String>[
      for (final ri in required)
        if (!context.isIngredientAvailable(ri.ingredientId)) ri.ingredientId,
    ];

    final coreRequired = required.where(
      (ri) =>
          context.ingredientsById[ri.ingredientId]?.role == IngredientRole.core,
    );
    final coreAvailableCount = coreRequired
        .where((ri) => context.isIngredientAvailable(ri.ingredientId))
        .length;
    // No core ingredients at all reads as "no pantry barrier", not "zero
    // coverage" — an empty recipe shouldn't be penalised for a hint that
    // doesn't apply to it.
    final pantryHint = coreRequired.isEmpty
        ? 1.0
        : coreAvailableCount / coreRequired.length;

    final taste = tasteScoreFor(
      recipe.tags,
      context.tasteProfile,
      context.config,
    );
    final isWeekday =
        context.now.weekday >= DateTime.monday &&
        context.now.weekday <= DateTime.friday;
    final isQuick =
        isWeekday && recipe.minutes <= context.config.quickThresholdMinutes;
    final repeatPenalty = Penalties.repeatPenalty(
      lastCookedAt: context.lastCookedAtByRecipe[recipe.id],
      cookCountInRutWindow:
          context.cookCountInRutWindowByRecipe[recipe.id] ?? 0,
      now: context.now,
      config: context.config,
    );

    final config = context.config;
    final rawScore =
        config.cravingTasteWeight * taste +
        config.cravingPantryHintWeight * pantryHint +
        config.cravingQuickWeight * (isQuick ? 1 : 0) +
        config.cravingFavouriteWeight * (recipe.isFavorite ? 1 : 0) -
        repeatPenalty -
        rejectPenalty;

    return ScoredRecipe(
      recipe: recipe,
      score: rawScore,
      missingIngredientIds: missing,
      explanation: _explain(recipe, context),
    );
  }

  /// Chooses the most honest explanation available, in the priority order
  /// `docs/design/RECOMMENDER.md` section 6 lists: a concretely similar
  /// liked dish, then a favoured tag, then the pantry hint as a fallback.
  /// ("Something different: X" for explore picks is added by `DeckBuilder`,
  /// not here — see `ranking_strategy.dart`'s SRP note.)
  String _explain(Recipe recipe, RankingContext context) {
    final similar = _mostSimilarLikedRecipe(recipe, context);
    if (similar != null) {
      return 'Because you liked ${similar.name}.';
    }

    final favouredTag = _mostFavouredTag(recipe, context);
    if (favouredTag != null) {
      return "You've been into $favouredTag lately.";
    }

    final requiredCount = recipe.requiredIngredients.length;
    final availableCount =
        requiredCount -
        recipe.requiredIngredients
            .where((ri) => !context.isIngredientAvailable(ri.ingredientId))
            .length;
    return 'You already have $availableCount of $requiredCount ingredients.';
  }

  Recipe? _mostSimilarLikedRecipe(Recipe recipe, RankingContext context) {
    final candidateKeys = recipe.tags.allKeys.toSet();
    Recipe? best;
    double bestScore = 0;
    for (final likedId in context.recentlyLikedRecipeIdsDesc) {
      if (likedId == recipe.id) continue;
      final liked = context.recipesById[likedId];
      if (liked == null) continue;
      final likedKeys = liked.tags.allKeys.toSet();
      final union = candidateKeys.union(likedKeys).length;
      if (union == 0) continue;
      final jaccard = candidateKeys.intersection(likedKeys).length / union;
      if (jaccard > bestScore) {
        bestScore = jaccard;
        best = liked;
      }
    }
    // A low-overlap "most similar" isn't actually similar — require at
    // least a meaningful shared fraction before using it as an explanation.
    return bestScore >= 0.34 ? best : null;
  }

  String? _mostFavouredTag(Recipe recipe, RankingContext context) {
    String? best;
    var bestAffinity = 0.15; // floor: don't cite a barely-positive tag
    for (final key in recipe.tags.allKeys) {
      final affinity = context.tasteProfile.normalised(key);
      if (affinity > bestAffinity) {
        bestAffinity = affinity;
        best = key.label; // "Indo-Chinese", never "indoChinese"
      }
    }
    return best;
  }
}
