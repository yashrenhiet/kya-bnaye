/// Turns a scored candidate pool into an ordered deck of swipe cards
/// (`docs/design/RECOMMENDER.md` section 4).
///
/// - Kitchen-style strategies (no exploration): the top
///   ``ScoringConfig/deckSize`` cards in display order — tier first
///   (use-it-up, ready, missing 1, missing 2), then score descending.
/// - Exploring strategies: about 80% exploit (top scores) followed by about 20%
///   explore (lowest total tag evidence), each explore card labelled
///   "Something different: <region>." With zero taste evidence (cold start)
///   every card is an explore card in score order and keeps its ranker's
///   explanation.
///
/// Deterministic under a seed: the explore pool is shuffled with
/// ``SeededGenerator`` before the (stable) evidence sort, so "Shuffle" is just
/// "build again with a new seed". Equal-priority cards keep candidate order.
public struct DeckBuilder: Sendable {
    /// Creates the builder. It is stateless.
    public init() {}

    /// Builds a deck.
    ///
    /// - Parameters:
    ///   - candidates: Recipes to consider, in a stable order (ties keep it).
    ///   - context: Precomputed pantry, history and taste data.
    ///   - strategy: The ranking mode.
    ///   - seed: Drives the explore shuffle; ignored when the strategy does not
    ///     explore or there is no taste evidence.
    /// - Returns: At most ``ScoringConfig/deckSize`` cards with no duplicates
    ///   (assuming unique candidate ids); empty when every candidate is
    ///   excluded.
    public func build(
        candidates: [Recipe],
        context: RankingContext,
        strategy: some RankingStrategy,
        seed: Int
    ) -> [ScoredRecipe] {
        let scored = candidates.compactMap { strategy.score($0, in: context) }
        if scored.isEmpty { return [] }

        let deckSize = max(context.config.deckSize, 0)
        let ordered = Self.sortedForDisplay(scored)
        guard strategy.supportsExploration else { return Array(ordered.prefix(deckSize)) }

        if Self.hasNoTasteEvidence(context.tasteProfile) {
            return ordered.prefix(deckSize).map { $0.copy(isExplore: true) }
        }

        let exploreCount = min(
            max(Int((Double(deckSize) * context.config.deckExploreFraction).rounded()), 0),
            deckSize)
        let exploit = Array(ordered.prefix(deckSize - exploreCount))
        let exploitIds = Set(exploit.map(\.recipe.id))

        var pool = ordered.filter { !exploitIds.contains($0.recipe.id) }
        var generator = SeededGenerator(seed: seed)
        generator.shuffle(&pool)
        let profile = context.tasteProfile
        let explore = Self.stableSorted(pool, by: { Self.evidence(of: $0, in: profile) })
            .prefix(exploreCount)
            .map {
                $0.copy(
                    explanation: "Something different: \($0.recipe.tags.region.label).",
                    isExplore: true)
            }
        return exploit + explore
    }

    /// Whether the profile holds no evidence at all (empty or all zero).
    private static func hasNoTasteEvidence(_ profile: TasteProfile) -> Bool {
        profile.evidence.values.allSatisfy { $0 == 0 }
    }

    /// Total evidence over the recipe's tags, summed in ``DishTags/allKeys``
    /// order.
    private static func evidence(of card: ScoredRecipe, in profile: TasteProfile) -> Double {
        card.recipe.tags.allKeys.reduce(0) { $0 + profile.evidence(for: $1) }
    }

    /// Tier display priority (Craving results, with no tier, sort last), then
    /// score descending; equal keys keep input order.
    private static func sortedForDisplay(_ scored: [ScoredRecipe]) -> [ScoredRecipe] {
        scored.enumerated()
            .sorted { lhs, rhs in
                let lhsTier = lhs.element.tier?.displayPriority ?? Int.max
                let rhsTier = rhs.element.tier?.displayPriority ?? Int.max
                if lhsTier != rhsTier { return lhsTier < rhsTier }
                if lhs.element.score != rhs.element.score {
                    return lhs.element.score > rhs.element.score
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// Ascending by `key`; equal keys keep input order.
    private static func stableSorted(
        _ cards: [ScoredRecipe],
        by key: (ScoredRecipe) -> Double
    ) -> [ScoredRecipe] {
        cards.map { (card: $0, key: key($0)) }
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.key != rhs.element.key
                    ? lhs.element.key < rhs.element.key : lhs.offset < rhs.offset
            }
            .map(\.element.card)
    }
}
