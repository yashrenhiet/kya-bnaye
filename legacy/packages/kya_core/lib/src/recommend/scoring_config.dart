import 'package:kya_core/src/domain/enums.dart';

/// Every tunable weight and threshold used by both rankers, in one place.
///
/// `docs/design/RECOMMENDER.md` is explicit that these must be data, not
/// scattered magic numbers: "All weights live in one `ScoringConfig` value
/// object and can be tuned without code changes." Defaults below are copied
/// directly from that document's formulas.
class ScoringConfig {
  const ScoringConfig({
    this.roleWeightCore = 2.4,
    this.roleWeightFlavor = 1.2,
    this.roleWeightOptional = 0.7,
    this.roleWeightStaple = 0.25,
    this.rarityBonusMax = 0.6,
    this.kitchenWeightedCoverageWeight = 0.40,
    this.kitchenCoreCoverageWeight = 0.20,
    this.kitchenExpiringUseWeight = 0.15,
    this.kitchenTasteWeight = 0.10,
    this.kitchenFavouriteWeight = 0.05,
    this.kitchenQuickWeight = 0.05,
    this.kitchenSameBaseAsLastMealPenalty = 0.10,
    this.kitchenMaxMissingRequired = 2,
    this.expiringWithinDays = 3,
    this.cravingTasteWeight = 0.60,
    this.cravingPantryHintWeight = 0.10,
    this.cravingQuickWeight = 0.05,
    this.cravingFavouriteWeight = 0.05,
    this.quickThresholdMinutes = 30,
    this.taggedRegionWeight = 0.25,
    this.taggedDishTypeWeight = 0.25,
    this.taggedFlavourWeight = 0.25,
    this.taggedHeavinessWeight = 0.10,
    this.taggedProteinWeight = 0.15,
    this.repeatPenaltyWithin7d = 0.30,
    this.repeatPenaltyWithin14d = 0.20,
    this.repeatPenaltyWithin28d = 0.10,
    this.repeatPenaltyWithin56d = 0.03,
    this.repeatRutWindowDays = 90,
    this.repeatRutPenaltyPerExtraCook = 0.02,
    this.rejectExclusionWindowDays = 3,
    this.rejectPenaltyWindowDays = 14,
    this.rejectPenaltyWithinWindow = 0.25,
    this.tasteDecayHalfLifeDays = 30,
    this.tasteNormaliseDivisor = 3.0,
    this.signalWeightRightSwipe = 1.0,
    this.signalWeightCooked = 1.5,
    this.signalWeightLeftSwipe = -0.4,
    this.signalWeightNeverShow = -3.0,
    this.signalWeightOnboardingPick = 1.0,
    this.deckSize = 20,
    this.deckExploreFraction = 0.20,
    this.similarRecipeWindowDays = 60,
  });

  /// [IngredientRole] → base weight, before [rarityBonusMax] is added.
  final double roleWeightCore;
  final double roleWeightFlavor;
  final double roleWeightOptional;
  final double roleWeightStaple;

  double roleWeight(IngredientRole role) => switch (role) {
    IngredientRole.core => roleWeightCore,
    IngredientRole.flavor => roleWeightFlavor,
    IngredientRole.optional => roleWeightOptional,
    IngredientRole.staple => roleWeightStaple,
  };

  /// Maximum bonus added to [roleWeight] for an ingredient that appears in
  /// none of the candidate recipes (i.e. maximally rare); scaled linearly
  /// down to 0 for an ingredient every candidate recipe needs. See
  /// `RankingContext.build` for how ingredient frequency is computed.
  final double rarityBonusMax;

  // --- Kitchen mode (docs/design/RECOMMENDER.md section 5) ---
  final double kitchenWeightedCoverageWeight;
  final double kitchenCoreCoverageWeight;
  final double kitchenExpiringUseWeight;
  final double kitchenTasteWeight;
  final double kitchenFavouriteWeight;
  final double kitchenQuickWeight;
  final double kitchenSameBaseAsLastMealPenalty;

  /// Hard filter: a recipe with more than this many missing non-optional
  /// ingredients is excluded from Kitchen mode entirely.
  final int kitchenMaxMissingRequired;

  final int expiringWithinDays;

  // --- Craving mode (docs/design/RECOMMENDER.md section 4) ---
  final double cravingTasteWeight;
  final double cravingPantryHintWeight;
  final double cravingQuickWeight;
  final double cravingFavouriteWeight;

  final int quickThresholdMinutes;

  // --- Taste weighted-mean across tag dimensions (sums to 1.0) ---
  final double taggedRegionWeight;
  final double taggedDishTypeWeight;
  final double taggedFlavourWeight;
  final double taggedHeavinessWeight;
  final double taggedProteinWeight;

  // --- Shared penalties ---
  final double repeatPenaltyWithin7d;
  final double repeatPenaltyWithin14d;
  final double repeatPenaltyWithin28d;
  final double repeatPenaltyWithin56d;
  final int repeatRutWindowDays;
  final double repeatRutPenaltyPerExtraCook;

  final int rejectExclusionWindowDays;
  final int rejectPenaltyWindowDays;
  final double rejectPenaltyWithinWindow;

  // --- Taste profile decay/normalisation ---
  final int tasteDecayHalfLifeDays;
  final double tasteNormaliseDivisor;
  final double signalWeightRightSwipe;
  final double signalWeightCooked;
  final double signalWeightLeftSwipe;
  final double signalWeightNeverShow;
  final double signalWeightOnboardingPick;

  // --- Deck composition ---
  final int deckSize;
  final double deckExploreFraction;

  /// How far back to look for "because you liked X" similar-recipe
  /// explanations (`docs/design/RECOMMENDER.md` section 6).
  final int similarRecipeWindowDays;
}
