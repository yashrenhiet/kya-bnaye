import 'package:kya_core/src/domain/domain.dart';
import 'package:meta/meta.dart';

/// How broad the shipped seed catalogue must be, so every meal slot,
/// region and base has enough dishes for a varied deck.
///
/// Passed to `SeedValidator.validate(coverage: ...)`; while the catalogue
/// is still being written, leave coverage off. Defaults are the M2 plan's
/// targets. Shares are fractions of the recipe count (0.35 = 35%), and
/// every bound is inclusive.
@immutable
class SeedCoverageTargets {
  /// Creates targets; every parameter defaults to the M2 plan value.
  const SeedCoverageTargets({
    this.minRecipes = 75,
    this.maxRecipes = 90,
    this.minIngredients = 220,
    this.maxIngredients = 280,
    this.minRecipesPerMealType = const {
      MealType.breakfast: 15,
      MealType.lunch: 35,
      MealType.dinner: 35,
      MealType.snack: 12,
    },
    this.minRecipesPerRegion = const {
      Region.north: 8,
      Region.punjabi: 8,
      Region.south: 8,
      Region.east: 3,
      Region.west: 3,
      Region.gujarati: 3,
      Region.street: 3,
      Region.indoChinese: 3,
      Region.continental: 1,
    },
    this.minRecipesPerDishType = 3,
    this.dishTypeExemptions = const {},
    this.minRecipesPerBase = const {
      DishBase.rice: 12,
      DishBase.roti: 15,
      DishBase.bread: 4,
      DishBase.none: 12,
    },
    this.maxBaseShare = 0.45,
    this.minHeavinessShare = 0.15,
    this.quickMaxMinutes = 30,
    this.minQuickShare = 0.35,
    this.minNonVegShare = 0.08,
    this.maxNonVegShare = 0.15,
    this.minPaneerRecipes = 5,
    this.minDalLegumeRecipes = 10,
    this.minKitchenCandidatesPerMealType = 5,
  });

  /// Recipe count bounds.
  final int minRecipes;

  /// See [minRecipes].
  final int maxRecipes;

  /// Ingredient count bounds.
  final int minIngredients;

  /// See [minIngredients].
  final int maxIngredients;

  /// Fewest recipes listing each meal type; a missing entry means 0.
  final Map<MealType, int> minRecipesPerMealType;

  /// Fewest recipes per region; a missing entry means 0.
  final Map<Region, int> minRecipesPerRegion;

  /// Fewest recipes of every dish type not in [dishTypeExemptions].
  final int minRecipesPerDishType;

  /// Dish types deliberately excluded from [minRecipesPerDishType].
  final Set<DishType> dishTypeExemptions;

  /// Fewest recipes per base; a missing entry means 0.
  final Map<DishBase, int> minRecipesPerBase;

  /// Largest share of recipes any single base may have.
  final double maxBaseShare;

  /// Smallest share each [Heaviness] must have.
  final double minHeavinessShare;

  /// A recipe is "quick" when it takes at most this many minutes.
  final int quickMaxMinutes;

  /// Smallest share of quick recipes.
  final double minQuickShare;

  /// Bounds on the share of non-veg recipes (protein chicken, mutton,
  /// fish or egg).
  final double minNonVegShare;

  /// See [minNonVegShare].
  final double maxNonVegShare;

  /// Fewest recipes tagged protein paneer.
  final int minPaneerRecipes;

  /// Fewest recipes tagged protein dalLegume.
  final int minDalLegumeRecipes;

  /// Fewest Kitchen-mode candidates each meal type must have for a
  /// typical first-run pantry (see `kitchenCandidateCounts`). Checked by
  /// the seed asset test rather than `SeedValidator`, because it needs a
  /// pantry.
  final int minKitchenCandidatesPerMealType;
}
