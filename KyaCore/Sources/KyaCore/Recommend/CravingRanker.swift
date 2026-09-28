/// "What would I enjoy, whether or not it's at home?" — the learned-taste mode.
/// Full formula: `docs/design/RECOMMENDER.md` section 4.
///
/// Ignores the meal slot and has no missing-ingredient filter; the pantry only
/// contributes a small hint (share of core ingredients at home). Scores learned
/// taste, the pantry hint, a weekday quick bonus and a favourite bonus, minus
/// the shared repeat and reject penalties.
public struct CravingRanker: RankingStrategy {
    /// Minimum tag-set Jaccard overlap for "Because you liked X." — a
    /// low-overlap "most similar" dish is not actually similar.
    static let minimumSimilarity = 0.34

    /// Minimum normalised affinity for "You've been into X lately." — a barely
    /// positive tag is not worth citing.
    static let minimumCitedAffinity = 0.15

    /// Creates the ranker. It is stateless.
    public init() {}

    /// Always `true`: a Craving deck reserves cards for low-evidence dishes.
    public var supportsExploration: Bool { true }

    /// Scores `recipe` for Craving mode.
    ///
    /// - Parameters:
    ///   - recipe: The candidate.
    ///   - context: Precomputed pantry, history and taste data.
    /// - Returns: `nil` when hidden, never-shown or recently left-swiped;
    ///   otherwise a result with no ``RecipeTier``.
    public func score(_ recipe: Recipe, in context: RankingContext) -> ScoredRecipe? {
        if context.isHardExcluded(recipe) { return nil }
        let config = context.config
        guard
            let rejectPenalty = Penalties.rejectPenalty(
                lastLeftSwipeAt: context.lastLeftSwipeAtByRecipe[recipe.id], now: context.now,
                config: config, calendar: context.calendar)
        else { return nil }

        let required = recipe.requiredIngredients
        let missing = required.map(\.ingredientId).filter { !context.isIngredientAvailable($0) }
        let coreRequired = required.filter {
            context.ingredientsById[$0.ingredientId]?.role == .core
        }
        let coreAvailableCount = coreRequired.filter {
            context.isIngredientAvailable($0.ingredientId)
        }.count
        // No core ingredients reads as "no pantry barrier", not "zero coverage".
        let pantryHint =
            coreRequired.isEmpty ? 1 : Double(coreAvailableCount) / Double(coreRequired.count)

        let taste = context.tasteProfile.tasteScore(for: recipe.tags, config: config)
        let weekday = context.calendar.component(.weekday, from: context.now)
        let isWeekday = (2...6).contains(weekday)  // Gregorian: 1 = Sunday, 7 = Saturday.
        let isQuick = isWeekday && recipe.minutes <= config.quickThresholdMinutes
        let repeatPenalty = Penalties.repeatPenalty(
            lastCookedAt: context.lastCookedAtByRecipe[recipe.id],
            cookCountInRutWindow: context.cookCountInRutWindowByRecipe[recipe.id] ?? 0,
            now: context.now, config: config, calendar: context.calendar)

        var score = config.cravingTasteWeight * taste
        score += config.cravingPantryHintWeight * pantryHint
        score += config.cravingQuickWeight * (isQuick ? 1 : 0)
        score += config.cravingFavouriteWeight * (recipe.isFavorite ? 1 : 0)
        score -= repeatPenalty
        score -= rejectPenalty

        return ScoredRecipe(
            recipe: recipe,
            score: score,
            explanation: explain(recipe, requiredCount: required.count, missing: missing, context),
            missingIngredientIds: missing
        )
    }

    /// The most honest explanation available, in `RECOMMENDER.md` section 6
    /// priority: a concretely similar liked dish, then a favoured tag, then the
    /// pantry line. ("Something different: X" is added by ``DeckBuilder``.)
    private func explain(
        _ recipe: Recipe,
        requiredCount: Int,
        missing: [String],
        _ context: RankingContext
    ) -> String {
        if let similar = mostSimilarLikedRecipe(to: recipe, context) {
            return "Because you liked \(similar.name)."
        }
        if let tag = mostFavouredTag(of: recipe, context) {
            return "You've been into \(tag) lately."
        }
        let availableCount = requiredCount - missing.count
        return "You already have \(availableCount) of \(requiredCount) ingredients."
    }

    /// The recently liked recipe (never `recipe` itself) with the highest tag
    /// Jaccard overlap; ties go to the most recent like. `nil` below
    /// ``minimumSimilarity``.
    private func mostSimilarLikedRecipe(to recipe: Recipe, _ context: RankingContext) -> Recipe? {
        let candidateKeys = Set(recipe.tags.allKeys)
        var best: Recipe?
        var bestScore = 0.0
        for likedId in context.recentlyLikedRecipeIdsDesc where likedId != recipe.id {
            guard let liked = context.recipesById[likedId] else { continue }
            let likedKeys = Set(liked.tags.allKeys)
            let union = candidateKeys.union(likedKeys).count
            if union == 0 { continue }
            let jaccard = Double(candidateKeys.intersection(likedKeys).count) / Double(union)
            if jaccard > bestScore {
                bestScore = jaccard
                best = liked
            }
        }
        return bestScore >= Self.minimumSimilarity ? best : nil
    }

    /// The human label of the recipe's tag with the highest normalised
    /// affinity above ``minimumCitedAffinity``; ties keep ``DishTags/allKeys``
    /// order.
    private func mostFavouredTag(of recipe: Recipe, _ context: RankingContext) -> String? {
        var best: String?
        var bestAffinity = Self.minimumCitedAffinity
        for key in recipe.tags.allKeys {
            let affinity = context.tasteProfile.normalised(key)
            if affinity > bestAffinity {
                bestAffinity = affinity
                best = key.label  // "Indo-Chinese", never "indoChinese".
            }
        }
        return best
    }
}
