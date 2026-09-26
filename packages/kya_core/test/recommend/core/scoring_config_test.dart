import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

const double eps = 1e-9;

void main() {
  const config = ScoringConfig();

  group('ScoringConfig defaults match RECOMMENDER.md', () {
    test('role weights (section 5)', () {
      expect(config.roleWeight(IngredientRole.core), closeTo(2.4, eps));
      expect(config.roleWeight(IngredientRole.flavor), closeTo(1.2, eps));
      expect(config.roleWeight(IngredientRole.optional), closeTo(0.7, eps));
      expect(config.roleWeight(IngredientRole.staple), closeTo(0.25, eps));
    });

    test(
      'roleWeight is strictly ordered core > flavor > optional > staple',
      () {
        final weights = IngredientRole.values.map(config.roleWeight).toList();
        for (var i = 1; i < weights.length; i++) {
          expect(weights[i], lessThan(weights[i - 1]));
        }
      },
    );

    test('kitchen score weights (section 5)', () {
      expect(config.kitchenWeightedCoverageWeight, closeTo(0.40, eps));
      expect(config.kitchenCoreCoverageWeight, closeTo(0.20, eps));
      expect(config.kitchenExpiringUseWeight, closeTo(0.15, eps));
      expect(config.kitchenTasteWeight, closeTo(0.10, eps));
      expect(config.kitchenFavouriteWeight, closeTo(0.05, eps));
      expect(config.kitchenQuickWeight, closeTo(0.05, eps));
      expect(config.kitchenSameBaseAsLastMealPenalty, closeTo(0.10, eps));
      expect(config.kitchenMaxMissingRequired, 2);
      expect(config.expiringWithinDays, 3);
    });

    test('craving score weights (section 4)', () {
      expect(config.cravingTasteWeight, closeTo(0.60, eps));
      expect(config.cravingPantryHintWeight, closeTo(0.10, eps));
      expect(config.cravingQuickWeight, closeTo(0.05, eps));
      expect(config.cravingFavouriteWeight, closeTo(0.05, eps));
      expect(config.quickThresholdMinutes, 30);
    });

    test('taste tag-dimension weights (section 4)', () {
      expect(config.taggedRegionWeight, closeTo(0.25, eps));
      expect(config.taggedDishTypeWeight, closeTo(0.25, eps));
      expect(config.taggedFlavourWeight, closeTo(0.25, eps));
      expect(config.taggedHeavinessWeight, closeTo(0.10, eps));
      expect(config.taggedProteinWeight, closeTo(0.15, eps));
    });

    test('shared penalties (section 5)', () {
      expect(config.repeatPenaltyWithin7d, closeTo(0.30, eps));
      expect(config.repeatPenaltyWithin14d, closeTo(0.20, eps));
      expect(config.repeatPenaltyWithin28d, closeTo(0.10, eps));
      expect(config.repeatPenaltyWithin56d, closeTo(0.03, eps));
      expect(config.repeatRutWindowDays, 90);
      expect(config.repeatRutPenaltyPerExtraCook, closeTo(0.02, eps));
      expect(config.rejectExclusionWindowDays, 3);
      expect(config.rejectPenaltyWindowDays, 14);
      expect(config.rejectPenaltyWithinWindow, closeTo(0.25, eps));
    });

    test('taste signals, decay and normalisation (section 4)', () {
      expect(config.signalWeightRightSwipe, closeTo(1.0, eps));
      expect(config.signalWeightCooked, closeTo(1.5, eps));
      expect(config.signalWeightLeftSwipe, closeTo(-0.4, eps));
      expect(config.signalWeightNeverShow, closeTo(-3.0, eps));
      expect(config.signalWeightOnboardingPick, closeTo(1.0, eps));
      expect(config.tasteDecayHalfLifeDays, 30);
      expect(config.tasteNormaliseDivisor, closeTo(3.0, eps));
    });

    test('deck composition and explanations (sections 4 and 6)', () {
      expect(config.deckSize, 20);
      expect(config.deckExploreFraction, closeTo(0.20, eps));
      expect(config.similarRecipeWindowDays, 60);
    });
  });

  group('ScoringConfig overrides', () {
    test('an override changes only that field', () {
      const custom = ScoringConfig(roleWeightCore: 9);
      expect(custom.roleWeight(IngredientRole.core), 9);
      expect(custom.roleWeight(IngredientRole.flavor), closeTo(1.2, eps));
      expect(custom.repeatPenaltyWithin7d, closeTo(0.30, eps));
    });

    test('is const-constructible (usable as a default parameter)', () {
      const a = ScoringConfig();
      const b = ScoringConfig();
      expect(identical(a, b), isTrue);
    });
  });
}
