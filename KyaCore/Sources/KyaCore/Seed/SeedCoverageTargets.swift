/// How broad the shipped seed catalogue must be, so every meal slot, region
/// and base has enough dishes for a varied deck (`docs/design/SEED_GUIDE.md`
/// section 7).
///
/// Passed to ``SeedValidator/validate(_:assetExists:coverage:exemptions:)``;
/// leave coverage off while a catalogue is still being written. Defaults are
/// the M2 plan's targets. Shares are fractions of the recipe count
/// (`0.35` = 35%), and every bound is inclusive. A meal type, region or base
/// missing from its dictionary has no minimum.
public struct SeedCoverageTargets: Sendable, Hashable {
    /// Fewest recipes.
    public let minRecipes: Int
    /// Most recipes.
    public let maxRecipes: Int
    /// Fewest ingredients.
    public let minIngredients: Int
    /// Most ingredients.
    public let maxIngredients: Int
    /// Fewest recipes listing each meal type.
    public let minRecipesPerMealType: [MealType: Int]
    /// Fewest recipes per region.
    public let minRecipesPerRegion: [Region: Int]
    /// Fewest recipes of every dish type not in ``dishTypeExemptions``.
    public let minRecipesPerDishType: Int
    /// Dish types deliberately excluded from ``minRecipesPerDishType``.
    public let dishTypeExemptions: Set<DishType>
    /// Fewest recipes per base.
    public let minRecipesPerBase: [DishBase: Int]
    /// Largest share of recipes any single base may have.
    public let maxBaseShare: Double
    /// Smallest share each ``Heaviness`` must have.
    public let minHeavinessShare: Double
    /// A recipe is "quick" when it takes at most this many minutes.
    public let quickMaxMinutes: Int
    /// Smallest share of quick recipes.
    public let minQuickShare: Double
    /// Smallest share of non-veg recipes (protein chicken, mutton, fish or
    /// egg).
    public let minNonVegShare: Double
    /// Largest share of non-veg recipes.
    public let maxNonVegShare: Double
    /// Fewest recipes tagged protein paneer.
    public let minPaneerRecipes: Int
    /// Fewest recipes tagged protein dalLegume.
    public let minDalLegumeRecipes: Int
    /// Fewest Kitchen-mode candidates each meal type must have for a typical
    /// first-run pantry. Checked by the seed-asset test rather than
    /// ``SeedValidator``, because it needs a pantry.
    public let minKitchenCandidatesPerMealType: Int

    /// Creates targets; every parameter defaults to the M2 plan value.
    ///
    /// - Parameters:
    ///   - minRecipes: Fewest recipes (75).
    ///   - maxRecipes: Most recipes (90).
    ///   - minIngredients: Fewest ingredients (220).
    ///   - maxIngredients: Most ingredients (280).
    ///   - minRecipesPerMealType: Breakfast 15, lunch 35, dinner 35, snack 12.
    ///   - minRecipesPerRegion: North, punjabi, south 8; east, west, gujarati,
    ///     street, indoChinese 3; continental 1.
    ///   - minRecipesPerDishType: Fewest recipes per dish type (3).
    ///   - dishTypeExemptions: Dish types without a minimum (none).
    ///   - minRecipesPerBase: Rice 12, roti 15, bread 4, none 12.
    ///   - maxBaseShare: Largest share of one base (0.45).
    ///   - minHeavinessShare: Smallest share per heaviness (0.15).
    ///   - quickMaxMinutes: The "quick" threshold (30).
    ///   - minQuickShare: Smallest quick share (0.35).
    ///   - minNonVegShare: Smallest non-veg share (0.08).
    ///   - maxNonVegShare: Largest non-veg share (0.15).
    ///   - minPaneerRecipes: Fewest paneer recipes (5).
    ///   - minDalLegumeRecipes: Fewest dal/legume recipes (10).
    ///   - minKitchenCandidatesPerMealType: First-run deck size per meal (5).
    public init(
        minRecipes: Int = 75,
        maxRecipes: Int = 90,
        minIngredients: Int = 220,
        maxIngredients: Int = 280,
        minRecipesPerMealType: [MealType: Int] = [
            .breakfast: 15, .lunch: 35, .dinner: 35, .snack: 12,
        ],
        minRecipesPerRegion: [Region: Int] = [
            .north: 8, .punjabi: 8, .south: 8, .east: 3, .west: 3, .gujarati: 3, .street: 3,
            .indoChinese: 3, .continental: 1,
        ],
        minRecipesPerDishType: Int = 3,
        dishTypeExemptions: Set<DishType> = [],
        minRecipesPerBase: [DishBase: Int] = [.rice: 12, .roti: 15, .bread: 4, .none: 12],
        maxBaseShare: Double = 0.45,
        minHeavinessShare: Double = 0.15,
        quickMaxMinutes: Int = 30,
        minQuickShare: Double = 0.35,
        minNonVegShare: Double = 0.08,
        maxNonVegShare: Double = 0.15,
        minPaneerRecipes: Int = 5,
        minDalLegumeRecipes: Int = 10,
        minKitchenCandidatesPerMealType: Int = 5
    ) {
        self.minRecipes = minRecipes
        self.maxRecipes = maxRecipes
        self.minIngredients = minIngredients
        self.maxIngredients = maxIngredients
        self.minRecipesPerMealType = minRecipesPerMealType
        self.minRecipesPerRegion = minRecipesPerRegion
        self.minRecipesPerDishType = minRecipesPerDishType
        self.dishTypeExemptions = dishTypeExemptions
        self.minRecipesPerBase = minRecipesPerBase
        self.maxBaseShare = maxBaseShare
        self.minHeavinessShare = minHeavinessShare
        self.quickMaxMinutes = quickMaxMinutes
        self.minQuickShare = minQuickShare
        self.minNonVegShare = minNonVegShare
        self.maxNonVegShare = maxNonVegShare
        self.minPaneerRecipes = minPaneerRecipes
        self.minDalLegumeRecipes = minDalLegumeRecipes
        self.minKitchenCandidatesPerMealType = minKitchenCandidatesPerMealType
    }
}
