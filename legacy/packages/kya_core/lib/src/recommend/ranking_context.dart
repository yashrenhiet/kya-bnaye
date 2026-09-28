import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/active_events.dart';
import 'package:kya_core/src/recommend/scoring_config.dart';
import 'package:kya_core/src/recommend/taste_profile.dart';

/// Everything a `RankingStrategy` needs to score one recipe, precomputed
/// once per deck build rather than recomputed per recipe.
///
/// Splitting "gather and precompute" (`build`) from "score one recipe"
/// (the rankers) keeps each ranker's `score()` method a small, easily
/// golden-tested pure function, and guarantees `KitchenRanker` and
/// `CravingRanker` see identical pantry/history data for the same deck.
class RankingContext {
  const RankingContext({
    required this.pantry,
    required this.ingredientsById,
    required this.now,
    required this.tasteProfile,
    required this.config,
    required this.ingredientFrequency,
    required this.totalRecipesForFrequency,
    required this.lastCookedAtByRecipe,
    required this.cookCountInRutWindowByRecipe,
    required this.lastLeftSwipeAtByRecipe,
    required this.neverShownRecipeIds,
    required this.currentMealType,
    required this.recipesById,
    required this.recentlyLikedRecipeIdsDesc,
    this.lastCookedBase,
  });

  factory RankingContext.build({
    required List<Recipe> allRecipes,
    required List<PantryItem> pantry,
    required List<Ingredient> catalog,
    required List<SwipeEvent> events,
    required List<MealLog> mealLogs,
    required DateTime now,
    ScoringConfig config = const ScoringConfig(),
    MealType? currentMealType,
  }) {
    final pantryById = {for (final p in pantry) p.ingredientId: p};
    final ingredientsById = {for (final i in catalog) i.id: i};
    final recipesById = {for (final r in allRecipes) r.id: r};

    // Rarity bonus input: how many candidate recipes actually need this
    // ingredient (core/flavor roles only — optional/staple ingredients
    // don't make an ingredient feel "special" to have).
    final ingredientFrequency = <String, int>{};
    for (final recipe in allRecipes) {
      for (final ri in recipe.requiredIngredients) {
        final role = ingredientsById[ri.ingredientId]?.role;
        if (role != IngredientRole.core && role != IngredientRole.flavor) {
          continue;
        }
        ingredientFrequency[ri.ingredientId] =
            (ingredientFrequency[ri.ingredientId] ?? 0) + 1;
      }
    }

    final lastCookedAtByRecipe = <String, DateTime>{};
    final cookCountInRutWindowByRecipe = <String, int>{};
    DishBase? lastCookedBase;
    DateTime? mostRecentCookAt;
    for (final log in mealLogs) {
      final current = lastCookedAtByRecipe[log.recipeId];
      if (current == null || log.cookedAt.isAfter(current)) {
        lastCookedAtByRecipe[log.recipeId] = log.cookedAt;
      }
      if (now.difference(log.cookedAt).inDays <= config.repeatRutWindowDays) {
        cookCountInRutWindowByRecipe[log.recipeId] =
            (cookCountInRutWindowByRecipe[log.recipeId] ?? 0) + 1;
      }
      if (mostRecentCookAt == null || log.cookedAt.isAfter(mostRecentCookAt)) {
        mostRecentCookAt = log.cookedAt;
        lastCookedBase = recipesById[log.recipeId]?.base;
      }
    }

    final lastLeftSwipeAtByRecipe = <String, DateTime>{};
    final neverShownRecipeIds = <String>{};
    // Most-recent-first, deduped: right-swipes and cooks within the
    // similarity window, used for "because you liked X" explanations
    // (`docs/design/RECOMMENDER.md` section 6). Built from a single
    // chronologically-sorted merge of both signals.
    final likedAt = <String, DateTime>{};
    for (final event in activeEvents(events)) {
      switch (event.action) {
        case SwipeAction.left:
          final current = lastLeftSwipeAtByRecipe[event.recipeId];
          if (current == null || event.at.isAfter(current)) {
            lastLeftSwipeAtByRecipe[event.recipeId] = event.at;
          }
        case SwipeAction.neverShow:
          neverShownRecipeIds.add(event.recipeId);
        case SwipeAction.right:
          if (now.difference(event.at).inDays <=
              config.similarRecipeWindowDays) {
            final current = likedAt[event.recipeId];
            if (current == null || event.at.isAfter(current)) {
              likedAt[event.recipeId] = event.at;
            }
          }
        case SwipeAction.undo:
          break;
      }
    }
    for (final log in mealLogs) {
      if (now.difference(log.cookedAt).inDays <=
          config.similarRecipeWindowDays) {
        final current = likedAt[log.recipeId];
        if (current == null || log.cookedAt.isAfter(current)) {
          likedAt[log.recipeId] = log.cookedAt;
        }
      }
    }
    final recentlyLikedRecipeIdsDesc = likedAt.keys.toList()
      ..sort((a, b) => likedAt[b]!.compareTo(likedAt[a]!));

    return RankingContext(
      pantry: pantryById,
      ingredientsById: ingredientsById,
      now: now,
      tasteProfile: profileFrom(
        events: events,
        mealLogs: mealLogs,
        recipesById: recipesById,
        now: now,
        config: config,
      ),
      config: config,
      ingredientFrequency: ingredientFrequency,
      totalRecipesForFrequency: allRecipes.length,
      lastCookedAtByRecipe: lastCookedAtByRecipe,
      cookCountInRutWindowByRecipe: cookCountInRutWindowByRecipe,
      lastLeftSwipeAtByRecipe: lastLeftSwipeAtByRecipe,
      neverShownRecipeIds: neverShownRecipeIds,
      currentMealType: currentMealType ?? mealTypeForHour(now.hour),
      recipesById: recipesById,
      recentlyLikedRecipeIdsDesc: recentlyLikedRecipeIdsDesc,
      lastCookedBase: lastCookedBase,
    );
  }

  final Map<String, PantryItem> pantry;
  final Map<String, Ingredient> ingredientsById;
  final DateTime now;
  final TasteProfile tasteProfile;
  final ScoringConfig config;

  /// Number of candidate recipes requiring each ingredient as core/flavor —
  /// the input to [rarityBonus].
  final Map<String, int> ingredientFrequency;
  final int totalRecipesForFrequency;

  final Map<String, DateTime> lastCookedAtByRecipe;
  final Map<String, int> cookCountInRutWindowByRecipe;
  final Map<String, DateTime> lastLeftSwipeAtByRecipe;
  final Set<String> neverShownRecipeIds;

  /// Auto-detected from time of day unless overridden (`AGENTS.md` section
  /// 4: "meal slot (auto)"). Used to filter Kitchen-mode candidates to
  /// dishes that fit the current meal.
  final MealType currentMealType;
  final DishBase? lastCookedBase;

  /// Full recipe lookup — used for "because you liked X" similarity
  /// explanations, which need another recipe's tags, not just its id.
  final Map<String, Recipe> recipesById;

  /// Ids of recipes right-swiped or cooked within
  /// [ScoringConfig.similarRecipeWindowDays], most recent first, deduped.
  final List<String> recentlyLikedRecipeIdsDesc;

  /// A staple is available unless explicitly marked [StockLevel.out]; an
  /// optional-role ingredient is always available (never missing); any
  /// other role needs an actual [PantryItem] recorded as not-out. See
  /// `domain/availability.dart` for the shared rule definition (also used
  /// by the shopping-list builder).
  bool isIngredientAvailable(String ingredientId) =>
      resolveIngredientAvailability(
        ingredientId: ingredientId,
        role: ingredientsById[ingredientId]?.role,
        pantry: pantry,
      );

  /// Linear bonus for ingredients few candidate recipes need — having one
  /// of these at home unlocks disproportionately more of the deck than
  /// having, say, onions (`docs/design/RECOMMENDER.md` section 5).
  ///
  /// Staples always get 0: they are assumed to be at home, so having one
  /// can never be "special", and the spec pins their weight at the bare
  /// role weight (0.25). Staples are deliberately absent from
  /// [ingredientFrequency], so without this guard they would read as
  /// maximally rare.
  double rarityBonus(String ingredientId) {
    if (totalRecipesForFrequency == 0) return 0;
    if (ingredientsById[ingredientId]?.role == IngredientRole.staple) {
      return 0;
    }
    final frequency = ingredientFrequency[ingredientId] ?? 0;
    final rarity = 1 - (frequency / totalRecipesForFrequency);
    return config.rarityBonusMax * rarity.clamp(0, 1);
  }

  double ingredientWeight(String ingredientId) {
    final ingredient = ingredientsById[ingredientId];
    if (ingredient == null) return 0;
    return config.roleWeight(ingredient.role) + rarityBonus(ingredientId);
  }
}

/// Default meal-slot detection from the hour of day, used when
/// [RankingContext.build] isn't given an explicit `currentMealType`.
/// Boundaries are approximate on purpose — this only affects which meal
/// slot's dishes appear in the Kitchen-mode deck, not any scoring math.
MealType mealTypeForHour(int hour) {
  if (hour >= 5 && hour < 11) return MealType.breakfast;
  if (hour >= 11 && hour < 16) return MealType.lunch;
  if (hour >= 16 && hour < 19) return MealType.snack;
  return MealType.dinner;
}
