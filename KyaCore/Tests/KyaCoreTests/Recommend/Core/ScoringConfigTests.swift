import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures

/// Port of `legacy/packages/kya_core/test/recommend/core/scoring_config_test.dart`.
@Suite("ScoringConfig")
struct ScoringConfigTests {
    private let config = ScoringConfig()

    // MARK: defaults match RECOMMENDER.md

    @Test("role weights (section 5)")
    func roleWeights() {
        #expect(F.near(config.roleWeight(.core), 2.4))
        #expect(F.near(config.roleWeight(.flavor), 1.2))
        #expect(F.near(config.roleWeight(.optional), 0.7))
        #expect(F.near(config.roleWeight(.staple), 0.25))
    }

    @Test("roleWeight is strictly ordered core > flavor > optional > staple")
    func roleWeightOrder() {
        let weights = IngredientRole.allCases.map(config.roleWeight)
        for index in 1..<weights.count {
            #expect(weights[index] < weights[index - 1])
        }
    }

    @Test("kitchen score weights (section 5)")
    func kitchenWeights() {
        #expect(F.near(config.kitchenWeightedCoverageWeight, 0.40))
        #expect(F.near(config.kitchenCoreCoverageWeight, 0.20))
        #expect(F.near(config.kitchenExpiringUseWeight, 0.15))
        #expect(F.near(config.kitchenTasteWeight, 0.10))
        #expect(F.near(config.kitchenFavouriteWeight, 0.05))
        #expect(F.near(config.kitchenQuickWeight, 0.05))
        #expect(F.near(config.kitchenSameBaseAsLastMealPenalty, 0.10))
        #expect(config.kitchenMaxMissingRequired == 2)
        #expect(config.expiringWithinDays == 3)
    }

    @Test("craving score weights (section 4)")
    func cravingWeights() {
        #expect(F.near(config.cravingTasteWeight, 0.60))
        #expect(F.near(config.cravingPantryHintWeight, 0.10))
        #expect(F.near(config.cravingQuickWeight, 0.05))
        #expect(F.near(config.cravingFavouriteWeight, 0.05))
        #expect(config.quickThresholdMinutes == 30)
    }

    @Test("taste tag-dimension weights (section 4)")
    func tagWeights() {
        #expect(F.near(config.taggedRegionWeight, 0.25))
        #expect(F.near(config.taggedDishTypeWeight, 0.25))
        #expect(F.near(config.taggedFlavourWeight, 0.25))
        #expect(F.near(config.taggedHeavinessWeight, 0.10))
        #expect(F.near(config.taggedProteinWeight, 0.15))
    }

    @Test("shared penalties (section 5)")
    func sharedPenalties() {
        #expect(F.near(config.repeatPenaltyWithin7d, 0.30))
        #expect(F.near(config.repeatPenaltyWithin14d, 0.20))
        #expect(F.near(config.repeatPenaltyWithin28d, 0.10))
        #expect(F.near(config.repeatPenaltyWithin56d, 0.03))
        #expect(config.repeatRutWindowDays == 90)
        #expect(F.near(config.repeatRutPenaltyPerExtraCook, 0.02))
        #expect(config.rejectExclusionWindowDays == 3)
        #expect(config.rejectPenaltyWindowDays == 14)
        #expect(F.near(config.rejectPenaltyWithinWindow, 0.25))
    }

    @Test("taste signals, decay and normalisation (section 4)")
    func tasteSignals() {
        #expect(F.near(config.signalWeightRightSwipe, 1.0))
        #expect(F.near(config.signalWeightCooked, 1.5))
        #expect(F.near(config.signalWeightLeftSwipe, -0.4))
        #expect(F.near(config.signalWeightNeverShow, -3.0))
        #expect(F.near(config.signalWeightOnboardingPick, 1.0))
        #expect(config.tasteDecayHalfLifeDays == 30)
        #expect(F.near(config.tasteNormaliseDivisor, 3.0))
    }

    @Test("deck composition and explanations (sections 4 and 6)")
    func deckComposition() {
        #expect(config.deckSize == 20)
        #expect(F.near(config.deckExploreFraction, 0.20))
        #expect(config.similarRecipeWindowDays == 60)
    }

    // MARK: overrides

    @Test("an override changes only that field")
    func override() {
        let custom = ScoringConfig(roleWeightCore: 9)
        #expect(custom.roleWeight(.core) == 9)
        #expect(F.near(custom.roleWeight(.flavor), 1.2))
        #expect(F.near(custom.repeatPenaltyWithin7d, 0.30))
    }

    /// Dart checked `identical(const ScoringConfig(), const ScoringConfig())`;
    /// a Swift value type has no identity, so equal defaults compare equal.
    @Test("default configs are equal values (usable as a default parameter)")
    func defaultsEqual() {
        #expect(ScoringConfig() == ScoringConfig())
        #expect(ScoringConfig(roleWeightCore: 9) != ScoringConfig())
    }
}
