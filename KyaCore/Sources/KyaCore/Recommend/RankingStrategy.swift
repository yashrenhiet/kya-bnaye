/// Kitchen mode's fixed badge set, declared in display-priority order
/// ("expiring-use cards first, then ready, then almost" —
/// `docs/design/RECOMMENDER.md` section 5).
public enum RecipeTier: String, Sendable, CaseIterable, Codable {
    /// Uses at least one pantry item expiring soon.
    case useItUp
    /// Nothing missing.
    case readyNow
    /// One required ingredient missing.
    case missing1
    /// Two required ingredients missing.
    case missing2

    /// Sort key for deck display: lower sorts first.
    var displayPriority: Int {
        switch self {
        case .useItUp: 0
        case .readyNow: 1
        case .missing1: 2
        case .missing2: 3
        }
    }
}

/// A recipe's score, the one-line reason shown on its card
/// (`docs/design/RECOMMENDER.md` section 6), and its deck metadata.
public struct ScoredRecipe: Sendable, Hashable {
    /// The scored recipe.
    public let recipe: Recipe
    /// Higher is better. Unbounded; comparable only within one deck build.
    public let score: Double
    /// Plain-language reason for the card.
    public let explanation: String
    /// Required (non-optional) ingredients not currently available, in recipe
    /// order. Empty for a ready-now recipe.
    public let missingIngredientIds: [String]
    /// Kitchen-mode badge; `nil` for Craving-mode results.
    public let tier: RecipeTier?
    /// Set only by ``DeckBuilder``: whether the card was chosen to broaden the
    /// deck rather than for its score.
    public let isExplore: Bool

    /// Creates a scored recipe.
    ///
    /// - Parameters:
    ///   - recipe: The scored recipe.
    ///   - score: The ranker's score.
    ///   - explanation: The card's reason line.
    ///   - missingIngredientIds: Missing required ingredient ids.
    ///   - tier: Kitchen badge, or `nil`.
    ///   - isExplore: Whether this is an explore card.
    public init(
        recipe: Recipe,
        score: Double,
        explanation: String,
        missingIngredientIds: [String],
        tier: RecipeTier? = nil,
        isExplore: Bool = false
    ) {
        self.recipe = recipe
        self.score = score
        self.explanation = explanation
        self.missingIngredientIds = missingIngredientIds
        self.tier = tier
        self.isExplore = isExplore
    }

    /// A copy with a new explanation and/or explore flag; every other field is
    /// unchanged.
    ///
    /// - Parameters:
    ///   - explanation: Replacement explanation, or `nil` to keep it.
    ///   - isExplore: Replacement explore flag, or `nil` to keep it.
    /// - Returns: The updated copy.
    public func copy(explanation: String? = nil, isExplore: Bool? = nil) -> ScoredRecipe {
        ScoredRecipe(
            recipe: recipe,
            score: score,
            explanation: explanation ?? self.explanation,
            missingIngredientIds: missingIngredientIds,
            tier: tier,
            isExplore: isExplore ?? self.isExplore
        )
    }
}

/// One of the ranking strategies behind the shared swipe deck
/// (`docs/design/RECOMMENDER.md` section 1, ADR 007). New modes plug in by
/// conforming, without touching ``DeckBuilder``.
public protocol RankingStrategy: Sendable {
    /// Whether ``DeckBuilder`` should reserve part of the deck for
    /// low-evidence explore picks under this strategy.
    var supportsExploration: Bool { get }

    /// Scores `recipe` against `context`.
    ///
    /// - Parameters:
    ///   - recipe: The candidate.
    ///   - context: Precomputed pantry, history and taste data.
    /// - Returns: `nil` when the recipe is excluded from this deck entirely
    ///   (see ``RankingContext/isHardExcluded(_:)``), otherwise its score.
    func score(_ recipe: Recipe, in context: RankingContext) -> ScoredRecipe?
}
