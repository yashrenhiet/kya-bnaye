import Foundation

/// Everything a ``RankingStrategy`` needs to score one recipe, precomputed
/// once per deck build.
///
/// Splitting "gather and precompute" (``build(allRecipes:pantry:catalog:events:mealLogs:now:config:currentMealType:calendar:)``)
/// from "score one recipe" (the rankers) keeps each ranker a small pure
/// function and guarantees both rankers see identical data for one deck.
public struct RankingContext: Sendable {
    /// Pantry rows keyed by ingredient id (the last row wins on duplicates).
    public let pantry: [String: PantryItem]
    /// Catalog keyed by ingredient id.
    public let ingredientsById: [String: Ingredient]
    /// The reference instant; the rankers never read the system clock.
    public let now: Date
    /// Decides calendar dates, weekdays and hours for ``now``.
    public let calendar: Calendar
    /// The taste profile derived from the same history.
    public let tasteProfile: TasteProfile
    /// The scoring weights.
    public let config: ScoringConfig
    /// How many candidate recipes require each ingredient with a core or
    /// flavor role — the input to ``rarityBonus(_:)``.
    public let ingredientFrequency: [String: Int]
    /// Number of candidate recipes the frequencies were counted over.
    public let totalRecipesForFrequency: Int
    /// Latest cook per recipe id.
    public let lastCookedAtByRecipe: [String: Date]
    /// Cooks per recipe id within ``ScoringConfig/repeatRutWindowDays`` whole
    /// elapsed days (24-hour periods, not calendar dates) before ``now``.
    public let cookCountInRutWindowByRecipe: [String: Int]
    /// Latest active left swipe per recipe id.
    public let lastLeftSwipeAtByRecipe: [String: Date]
    /// Recipe ids with an active never-show swipe (no expiry).
    public let neverShownRecipeIds: Set<String>
    /// The meal slot Kitchen mode filters by: explicit, or derived from the
    /// hour of ``now`` via ``mealType(forHour:)``.
    public let currentMealType: MealType
    /// Base of the most recent cook overall, or `nil` (no cooks, or the latest
    /// cook's recipe was deleted).
    public let lastCookedBase: DishBase?
    /// Full recipe lookup, for "because you liked X" similarity.
    public let recipesById: [String: Recipe]
    /// Ids right-swiped or cooked within
    /// ``ScoringConfig/similarRecipeWindowDays`` whole elapsed days, newest
    /// first, deduplicated.
    /// Equal timestamps keep first-seen order (swipes before cooks).
    public let recentlyLikedRecipeIdsDesc: [String]

    /// Precomputes a context from raw repository data.
    ///
    /// - Parameters:
    ///   - allRecipes: Every candidate recipe; also fixes rarity frequencies.
    ///   - pantry: Current pantry rows.
    ///   - catalog: Every known ingredient.
    ///   - events: The full swipe log, including undo events.
    ///   - mealLogs: Every cooked meal.
    ///   - now: The reference instant.
    ///   - config: The scoring weights.
    ///   - currentMealType: Overrides the hour-based meal slot when non-`nil`.
    ///   - calendar: Decides calendar dates, weekdays and hours.
    /// - Returns: The immutable context.
    public static func build(
        allRecipes: [Recipe],
        pantry: [PantryItem],
        catalog: [Ingredient],
        events: [SwipeEvent],
        mealLogs: [MealLog],
        now: Date,
        config: ScoringConfig = ScoringConfig(),
        currentMealType: MealType? = nil,
        calendar: Calendar = .kyaDefault
    ) -> RankingContext {
        let pantryById = Dictionary(pantry.map { ($0.ingredientId, $0) }, uniquingKeysWith: { $1 })
        let ingredientsById = Dictionary(
            catalog.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        let recipesById = Dictionary(allRecipes.map { ($0.id, $0) }, uniquingKeysWith: { $1 })

        var frequency: [String: Int] = [:]
        for recipe in allRecipes {
            for line in recipe.requiredIngredients {
                let role = ingredientsById[line.ingredientId]?.role
                guard role == .core || role == .flavor else { continue }
                frequency[line.ingredientId, default: 0] += 1
            }
        }

        let elapsedDays = { (then: Date) -> Int in Self.elapsedWholeDays(from: then, to: now) }
        let cooks = CookHistory(
            mealLogs: mealLogs, recipesById: recipesById,
            isInRutWindow: { elapsedDays($0) <= config.repeatRutWindowDays })
        let swipes = SwipeHistory(
            events: events,
            isInLikeWindow: { elapsedDays($0) <= config.similarRecipeWindowDays })

        var liked = swipes.likedAt
        for log in mealLogs where elapsedDays(log.cookedAt) <= config.similarRecipeWindowDays {
            liked.record(log.recipeId, at: log.cookedAt)
        }

        return RankingContext(
            pantry: pantryById,
            ingredientsById: ingredientsById,
            now: now,
            calendar: calendar,
            tasteProfile: TasteProfile.from(
                events: events, mealLogs: mealLogs, recipesById: recipesById, now: now,
                config: config),
            config: config,
            ingredientFrequency: frequency,
            totalRecipesForFrequency: allRecipes.count,
            lastCookedAtByRecipe: cooks.lastCookedAt,
            cookCountInRutWindowByRecipe: cooks.countInRutWindow,
            lastLeftSwipeAtByRecipe: swipes.lastLeftAt,
            neverShownRecipeIds: swipes.neverShown,
            currentMealType: currentMealType
                ?? mealType(forHour: calendar.component(.hour, from: now)),
            lastCookedBase: cooks.lastBase,
            recipesById: recipesById,
            recentlyLikedRecipeIdsDesc: liked.idsNewestFirst
        )
    }

    /// Whether the ingredient counts as at home: optional-role ingredients
    /// always, staples unless marked Out, anything else only with a not-Out
    /// pantry row (see ``IngredientAvailability``).
    ///
    /// - Parameter ingredientId: Canonical ingredient id.
    /// - Returns: `true` when available.
    public func isIngredientAvailable(_ ingredientId: String) -> Bool {
        IngredientAvailability.isAvailable(
            ingredientId: ingredientId, role: ingredientsById[ingredientId]?.role,
            pantry: pantry)
    }

    /// Linear bonus for ingredients few candidate recipes need:
    /// `rarityBonusMax × clamp(1 − frequency / total, 0, 1)`.
    ///
    /// Staples always get `0`: they are assumed present, so having one is never
    /// special. With no candidate recipes the bonus is `0`. An id missing from
    /// the catalog is treated as maximally rare.
    ///
    /// - Parameter ingredientId: Canonical ingredient id.
    /// - Returns: A bonus in `[0, rarityBonusMax]`.
    public func rarityBonus(_ ingredientId: String) -> Double {
        if totalRecipesForFrequency == 0 { return 0 }
        if ingredientsById[ingredientId]?.role == .staple { return 0 }
        let frequency = Double(ingredientFrequency[ingredientId] ?? 0)
        let rarity = 1 - frequency / Double(totalRecipesForFrequency)
        return config.rarityBonusMax * min(max(rarity, 0), 1)
    }

    /// ``ScoringConfig/roleWeight(_:)`` plus ``rarityBonus(_:)``; `0` for an id
    /// missing from the catalog.
    ///
    /// - Parameter ingredientId: Canonical ingredient id.
    /// - Returns: The ingredient's coverage weight.
    public func ingredientWeight(_ ingredientId: String) -> Double {
        guard let ingredient = ingredientsById[ingredientId] else { return 0 }
        return config.roleWeight(ingredient.role) + rarityBonus(ingredientId)
    }

    /// Exclusions both rankers apply before scoring: the durable
    /// ``Recipe/isHidden`` flag, or an active never-show swipe for the id.
    ///
    /// The recent left-swipe exclusion is deliberately not duplicated here; it
    /// is owned by ``Penalties/rejectPenalty(lastLeftSwipeAt:now:config:calendar:)``.
    ///
    /// - Parameter recipe: The candidate.
    /// - Returns: `true` when the recipe must not appear in any deck.
    public func isHardExcluded(_ recipe: Recipe) -> Bool {
        recipe.isHidden || neverShownRecipeIds.contains(recipe.id)
    }

    /// Whole elapsed 24-hour periods from `start` to `end`, truncated toward
    /// zero (negative when `end` is earlier) — the Dart oracle's
    /// `end.difference(start).inDays`.
    ///
    /// The rut and "recently liked" windows are defined on elapsed time, unlike
    /// the penalty steps, which count calendar dates. Counting days in a GMT
    /// calendar measures exactly that, because GMT has no DST.
    static func elapsedWholeDays(from start: Date, to end: Date) -> Int {
        var gmt = Calendar(identifier: .gregorian)
        gmt.timeZone = .gmt
        return gmt.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Default meal slot for an hour of the day: 5–10 breakfast, 11–15 lunch,
    /// 16–18 snack, otherwise dinner.
    ///
    /// - Parameter hour: Hour of day, `0...23`.
    /// - Returns: The meal slot.
    public static func mealType(forHour hour: Int) -> MealType {
        switch hour {
        case 5..<11: .breakfast
        case 11..<16: .lunch
        case 16..<19: .snack
        default: .dinner
        }
    }
}
