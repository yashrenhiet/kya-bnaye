/// Every tunable weight and threshold used by both rankers, in one place.
///
/// `docs/design/RECOMMENDER.md` requires these to be data, not scattered magic
/// numbers: "All weights live in one `ScoringConfig` value object and can be
/// tuned without code changes." The defaults are copied from that document's
/// formulas. Override any subset through the initializer; every other field
/// keeps its default.
public struct ScoringConfig: Sendable, Hashable {
    // MARK: Ingredient role weights (RECOMMENDER.md section 5)

    /// Base weight of a ``IngredientRole/core`` ingredient.
    public let roleWeightCore: Double
    /// Base weight of a ``IngredientRole/flavor`` ingredient.
    public let roleWeightFlavor: Double
    /// Base weight of an ``IngredientRole/optional`` ingredient.
    public let roleWeightOptional: Double
    /// Base weight of a ``IngredientRole/staple`` ingredient.
    public let roleWeightStaple: Double

    /// Maximum bonus added to ``roleWeight(_:)`` for an ingredient that none of
    /// the candidate recipes need (maximally rare). Scales linearly down to 0
    /// for an ingredient every candidate needs; see
    /// ``RankingContext/rarityBonus(_:)``.
    public let rarityBonusMax: Double

    // MARK: Kitchen mode (RECOMMENDER.md section 5)

    /// Weight of the role-weighted pantry coverage term.
    public let kitchenWeightedCoverageWeight: Double
    /// Weight of the core-ingredient coverage term.
    public let kitchenCoreCoverageWeight: Double
    /// Weight of the "uses expiring stock" term.
    public let kitchenExpiringUseWeight: Double
    /// Weight of the learned-taste nudge.
    public let kitchenTasteWeight: Double
    /// Bonus for a favourite recipe.
    public let kitchenFavouriteWeight: Double
    /// Bonus for a quick recipe.
    public let kitchenQuickWeight: Double
    /// Penalty when the recipe's base matches the last cooked meal's base.
    public let kitchenSameBaseAsLastMealPenalty: Double
    /// Hard filter: a recipe with more missing non-optional ingredients than
    /// this is excluded from Kitchen mode entirely.
    public let kitchenMaxMissingRequired: Int
    /// Stock expiring within this many calendar days counts as "use it up".
    public let expiringWithinDays: Int

    // MARK: Craving mode (RECOMMENDER.md section 4)

    /// Weight of the learned-taste term (the dominant one).
    public let cravingTasteWeight: Double
    /// Weight of the pantry hint (share of core ingredients at home).
    public let cravingPantryHintWeight: Double
    /// Bonus for a quick recipe on a weekday.
    public let cravingQuickWeight: Double
    /// Bonus for a favourite recipe.
    public let cravingFavouriteWeight: Double
    /// A recipe taking at most this many minutes is "quick".
    public let quickThresholdMinutes: Int

    // MARK: Taste weighted mean across tag dimensions (sums to 1.0)

    /// Weight of the region dimension.
    public let taggedRegionWeight: Double
    /// Weight of the dish-type dimension.
    public let taggedDishTypeWeight: Double
    /// Weight of the flavour dimension (mean over the dish's flavours).
    public let taggedFlavourWeight: Double
    /// Weight of the heaviness dimension.
    public let taggedHeavinessWeight: Double
    /// Weight of the protein dimension.
    public let taggedProteinWeight: Double

    // MARK: Shared penalties

    /// Repeat penalty when last cooked at most 7 calendar days ago.
    public let repeatPenaltyWithin7d: Double
    /// Repeat penalty when last cooked 8–14 calendar days ago.
    public let repeatPenaltyWithin14d: Double
    /// Repeat penalty when last cooked 15–28 calendar days ago.
    public let repeatPenaltyWithin28d: Double
    /// Repeat penalty when last cooked 29–56 calendar days ago.
    public let repeatPenaltyWithin56d: Double
    /// Window, in days, over which cooks are counted for the "rut" top-up.
    public let repeatRutWindowDays: Int
    /// Extra penalty per cook beyond the first inside the rut window.
    public let repeatRutPenaltyPerExtraCook: Double
    /// A recipe left-swiped at most this many calendar days ago is excluded.
    public let rejectExclusionWindowDays: Int
    /// A recipe left-swiped at most this many calendar days ago is penalised.
    public let rejectPenaltyWindowDays: Int
    /// Penalty inside the reject penalty window.
    public let rejectPenaltyWithinWindow: Double

    // MARK: Taste profile decay and normalisation

    /// Half-life, in days, of the exponential signal decay.
    public let tasteDecayHalfLifeDays: Int
    /// Divisor in `tanh(affinity / divisor)`.
    public let tasteNormaliseDivisor: Double
    /// Signal weight of a right swipe.
    public let signalWeightRightSwipe: Double
    /// Signal weight of a cooked meal.
    public let signalWeightCooked: Double
    /// Signal weight of a left swipe.
    public let signalWeightLeftSwipe: Double
    /// Signal weight of a never-show swipe.
    public let signalWeightNeverShow: Double
    /// Signal weight of an onboarding pick. Currently unused: onboarding picks
    /// are recorded as right swipes (see `AGENTS.md`, still-open decisions).
    public let signalWeightOnboardingPick: Double

    // MARK: Deck composition

    /// Maximum number of cards in a deck.
    public let deckSize: Int
    /// Share of a Craving deck reserved for explore cards.
    public let deckExploreFraction: Double

    /// How far back, in days, to look for "because you liked X" explanations
    /// (`docs/design/RECOMMENDER.md` section 6).
    public let similarRecipeWindowDays: Int

    /// Creates a configuration; every parameter defaults to the spec value.
    public init(
        roleWeightCore: Double = 2.4,
        roleWeightFlavor: Double = 1.2,
        roleWeightOptional: Double = 0.7,
        roleWeightStaple: Double = 0.25,
        rarityBonusMax: Double = 0.6,
        kitchenWeightedCoverageWeight: Double = 0.40,
        kitchenCoreCoverageWeight: Double = 0.20,
        kitchenExpiringUseWeight: Double = 0.15,
        kitchenTasteWeight: Double = 0.10,
        kitchenFavouriteWeight: Double = 0.05,
        kitchenQuickWeight: Double = 0.05,
        kitchenSameBaseAsLastMealPenalty: Double = 0.10,
        kitchenMaxMissingRequired: Int = 2,
        expiringWithinDays: Int = 3,
        cravingTasteWeight: Double = 0.60,
        cravingPantryHintWeight: Double = 0.10,
        cravingQuickWeight: Double = 0.05,
        cravingFavouriteWeight: Double = 0.05,
        quickThresholdMinutes: Int = 30,
        taggedRegionWeight: Double = 0.25,
        taggedDishTypeWeight: Double = 0.25,
        taggedFlavourWeight: Double = 0.25,
        taggedHeavinessWeight: Double = 0.10,
        taggedProteinWeight: Double = 0.15,
        repeatPenaltyWithin7d: Double = 0.30,
        repeatPenaltyWithin14d: Double = 0.20,
        repeatPenaltyWithin28d: Double = 0.10,
        repeatPenaltyWithin56d: Double = 0.03,
        repeatRutWindowDays: Int = 90,
        repeatRutPenaltyPerExtraCook: Double = 0.02,
        rejectExclusionWindowDays: Int = 3,
        rejectPenaltyWindowDays: Int = 14,
        rejectPenaltyWithinWindow: Double = 0.25,
        tasteDecayHalfLifeDays: Int = 30,
        tasteNormaliseDivisor: Double = 3.0,
        signalWeightRightSwipe: Double = 1.0,
        signalWeightCooked: Double = 1.5,
        signalWeightLeftSwipe: Double = -0.4,
        signalWeightNeverShow: Double = -3.0,
        signalWeightOnboardingPick: Double = 1.0,
        deckSize: Int = 20,
        deckExploreFraction: Double = 0.20,
        similarRecipeWindowDays: Int = 60
    ) {
        self.roleWeightCore = roleWeightCore
        self.roleWeightFlavor = roleWeightFlavor
        self.roleWeightOptional = roleWeightOptional
        self.roleWeightStaple = roleWeightStaple
        self.rarityBonusMax = rarityBonusMax
        self.kitchenWeightedCoverageWeight = kitchenWeightedCoverageWeight
        self.kitchenCoreCoverageWeight = kitchenCoreCoverageWeight
        self.kitchenExpiringUseWeight = kitchenExpiringUseWeight
        self.kitchenTasteWeight = kitchenTasteWeight
        self.kitchenFavouriteWeight = kitchenFavouriteWeight
        self.kitchenQuickWeight = kitchenQuickWeight
        self.kitchenSameBaseAsLastMealPenalty = kitchenSameBaseAsLastMealPenalty
        self.kitchenMaxMissingRequired = kitchenMaxMissingRequired
        self.expiringWithinDays = expiringWithinDays
        self.cravingTasteWeight = cravingTasteWeight
        self.cravingPantryHintWeight = cravingPantryHintWeight
        self.cravingQuickWeight = cravingQuickWeight
        self.cravingFavouriteWeight = cravingFavouriteWeight
        self.quickThresholdMinutes = quickThresholdMinutes
        self.taggedRegionWeight = taggedRegionWeight
        self.taggedDishTypeWeight = taggedDishTypeWeight
        self.taggedFlavourWeight = taggedFlavourWeight
        self.taggedHeavinessWeight = taggedHeavinessWeight
        self.taggedProteinWeight = taggedProteinWeight
        self.repeatPenaltyWithin7d = repeatPenaltyWithin7d
        self.repeatPenaltyWithin14d = repeatPenaltyWithin14d
        self.repeatPenaltyWithin28d = repeatPenaltyWithin28d
        self.repeatPenaltyWithin56d = repeatPenaltyWithin56d
        self.repeatRutWindowDays = repeatRutWindowDays
        self.repeatRutPenaltyPerExtraCook = repeatRutPenaltyPerExtraCook
        self.rejectExclusionWindowDays = rejectExclusionWindowDays
        self.rejectPenaltyWindowDays = rejectPenaltyWindowDays
        self.rejectPenaltyWithinWindow = rejectPenaltyWithinWindow
        self.tasteDecayHalfLifeDays = tasteDecayHalfLifeDays
        self.tasteNormaliseDivisor = tasteNormaliseDivisor
        self.signalWeightRightSwipe = signalWeightRightSwipe
        self.signalWeightCooked = signalWeightCooked
        self.signalWeightLeftSwipe = signalWeightLeftSwipe
        self.signalWeightNeverShow = signalWeightNeverShow
        self.signalWeightOnboardingPick = signalWeightOnboardingPick
        self.deckSize = deckSize
        self.deckExploreFraction = deckExploreFraction
        self.similarRecipeWindowDays = similarRecipeWindowDays
    }

    /// The base weight for `role`, before ``rarityBonusMax`` is applied.
    ///
    /// - Parameter role: The ingredient's catalog role.
    /// - Returns: The configured weight for that role.
    public func roleWeight(_ role: IngredientRole) -> Double {
        switch role {
        case .core: roleWeightCore
        case .flavor: roleWeightFlavor
        case .optional: roleWeightOptional
        case .staple: roleWeightStaple
        }
    }
}
