/// "What can I make with what's home right now?" — the default mode
/// (decision D5). Full formula: `docs/design/RECOMMENDER.md` section 5.
///
/// Filters to the current meal slot and to recipes with at most
/// ``ScoringConfig/kitchenMaxMissingRequired`` missing ingredients, then scores
/// role-weighted coverage, core coverage, expiring-stock use, a small taste
/// nudge, favourite and quick bonuses, minus the shared penalties and the
/// same-base-as-last-meal penalty.
public struct KitchenRanker: RankingStrategy {
    /// Creates the ranker. It is stateless.
    public init() {}

    /// Always `false`: a dish you can't cook is not a valid explore pick.
    public var supportsExploration: Bool { false }

    /// Scores `recipe` for Kitchen mode.
    ///
    /// - Parameters:
    ///   - recipe: The candidate.
    ///   - context: Precomputed pantry, history and taste data.
    /// - Returns: `nil` when hidden, never-shown, outside the meal slot,
    ///   recently left-swiped, or missing too many ingredients.
    public func score(_ recipe: Recipe, in context: RankingContext) -> ScoredRecipe? {
        if context.isHardExcluded(recipe) { return nil }
        if !recipe.mealTypes.contains(context.currentMealType) { return nil }
        let config = context.config
        guard
            let rejectPenalty = Penalties.rejectPenalty(
                lastLeftSwipeAt: context.lastLeftSwipeAtByRecipe[recipe.id], now: context.now,
                config: config, calendar: context.calendar)
        else { return nil }

        let required = recipe.requiredIngredients
        let coverage = Coverage(required: required, context: context)
        if coverage.missing.count > config.kitchenMaxMissingRequired { return nil }

        let expiringUse =
            required.isEmpty ? 0 : Double(coverage.expiring.count) / Double(required.count)
        let taste = context.tasteProfile.tasteScore(for: recipe.tags, config: config)
        let isQuick = recipe.minutes <= config.quickThresholdMinutes
        let sameBase = recipe.base != .none && recipe.base == context.lastCookedBase
        let repeatPenalty = Penalties.repeatPenalty(
            lastCookedAt: context.lastCookedAtByRecipe[recipe.id],
            cookCountInRutWindow: context.cookCountInRutWindowByRecipe[recipe.id] ?? 0,
            now: context.now, config: config, calendar: context.calendar)

        var score = config.kitchenWeightedCoverageWeight * coverage.weightedCoverage
        score += config.kitchenCoreCoverageWeight * coverage.coreCoverage
        score += config.kitchenExpiringUseWeight * expiringUse
        score += config.kitchenTasteWeight * taste
        score += config.kitchenFavouriteWeight * (recipe.isFavorite ? 1 : 0)
        score += config.kitchenQuickWeight * (isQuick ? 1 : 0)
        score -= repeatPenalty
        score -= rejectPenalty
        score -= config.kitchenSameBaseAsLastMealPenalty * (sameBase ? 1 : 0)

        let tier: RecipeTier =
            if !coverage.expiring.isEmpty {
                .useItUp
            } else {
                switch coverage.missing.count {
                case 0: .readyNow
                case 1: .missing1
                default: .missing2
                }
            }
        return ScoredRecipe(
            recipe: recipe,
            score: score,
            explanation: explain(
                tier: tier, coverage: coverage, totalCount: required.count, context: context),
            missingIngredientIds: coverage.missing,
            tier: tier
        )
    }

    private func explain(
        tier: RecipeTier,
        coverage: Coverage,
        totalCount: Int,
        context: RankingContext
    ) -> String {
        func nameOf(_ id: String) -> String { context.ingredientsById[id]?.name ?? id }

        // First soonest-expiring item wins ties (recipe order).
        if let soonest = coverage.expiring.min(by: { $0.daysLeft < $1.daysLeft }) {
            let tail =
                coverage.missing.isEmpty ? "Nothing missing." : "Missing \(coverage.missing.count)."
            return "Uses your \(nameOf(soonest.id)) (\(timeLeft(soonest.daysLeft))). \(tail)"
        }
        if tier == .readyNow {
            return "You have everything for this — nothing missing."
        }
        let names = coverage.missing.map(nameOf).joined(separator: ", ")
        let availableCount = totalCount - coverage.missing.count
        return "You have \(availableCount) of \(totalCount) ingredients. Missing: \(names)."
    }

    /// Spec wording for the Use-it-up badge: "today", "1 day left", "2 days
    /// left"; an item already past its date is said plainly.
    private func timeLeft(_ daysLeft: Int) -> String {
        switch daysLeft {
        case ..<0: "past its date"
        case 0: "today"
        case 1: "1 day left"
        default: "\(daysLeft) days left"
        }
    }
}

/// Pantry coverage of one recipe's required ingredients, in recipe order.
private struct Coverage {
    private(set) var missing: [String] = []
    private(set) var expiring: [(id: String, daysLeft: Int)] = []
    private(set) var weightedCoverage = 1.0
    private(set) var coreCoverage = 1.0

    init(required: [RecipeIngredient], context: RankingContext) {
        var totalWeight = 0.0
        var availableWeight = 0.0
        var coreTotalWeight = 0.0
        var coreAvailableWeight = 0.0
        for line in required {
            let id = line.ingredientId
            let weight = context.ingredientWeight(id)
            let available = context.isIngredientAvailable(id)
            totalWeight += weight
            if available { availableWeight += weight } else { missing.append(id) }
            if context.ingredientsById[id]?.role == .core {
                coreTotalWeight += weight
                if available { coreAvailableWeight += weight }
            }
            // Needs a real, not-Out pantry row: only stock at home can spoil.
            if available, let item = context.pantry[id], item.level.isAvailable,
                let daysLeft = item.daysUntilExpiry(asOf: context.now, calendar: context.calendar),
                daysLeft <= context.config.expiringWithinDays
            {
                expiring.append((id, daysLeft))
            }
        }
        if totalWeight > 0 { weightedCoverage = availableWeight / totalWeight }
        if coreTotalWeight > 0 { coreCoverage = coreAvailableWeight / coreTotalWeight }
    }
}
