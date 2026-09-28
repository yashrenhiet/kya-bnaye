import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures

private func contextFor(_ recipes: [Recipe], events: [SwipeEvent] = []) -> RankingContext {
    RankingContext.build(
        allRecipes: recipes, pantry: [], catalog: [], events: events, mealLogs: [], now: F.refNow)
}

/// Port of `legacy/packages/kya_core/test/recommend/core/ranking_strategy_test.dart`.
@Suite("RankingStrategy support: isHardExcluded, ScoredRecipe, RecipeTier")
struct RankingStrategyTests {
    private let plain = F.recipe("plain")
    private let hidden = F.recipe("hidden", isHidden: true)
    private let nevered = F.recipe("nevered")
    private let undone = F.recipe("undone")
    private let lefted = F.recipe("lefted")
    private let ctx: RankingContext

    init() {
        ctx = contextFor(
            [plain, hidden, nevered, undone, lefted],
            events: [
                F.swipe("e1", "nevered", .neverShow, F.daysAgo(200)),
                F.swipe("e2", "undone", .neverShow, F.refNow),
                F.undo("u2", "e2", F.refNow),
                F.swipe("e3", "lefted", .left, F.refNow),
            ])
    }

    // MARK: isHardExcluded

    @Test("a recipe with no history is eligible")
    func plainEligible() {
        #expect(!ctx.isHardExcluded(plain))
    }

    @Test("isHidden alone excludes (Settings flag, no swipe needed)")
    func hiddenExcluded() {
        #expect(ctx.isHardExcluded(hidden))
    }

    @Test("a never-show swipe excludes regardless of age")
    func neverShowExcluded() {
        #expect(ctx.isHardExcluded(nevered))
    }

    @Test("an undone never-show does not exclude")
    func undoneNeverShow() {
        #expect(!ctx.isHardExcluded(undone))
    }

    @Test("a recent left swipe is not a hard exclusion (penalty owns it)")
    func leftSwipeNotHard() {
        #expect(!ctx.isHardExcluded(lefted))
        let penalty = Penalties.rejectPenalty(
            lastLeftSwipeAt: ctx.lastLeftSwipeAtByRecipe[lefted.id], now: ctx.now,
            config: ctx.config)
        #expect(penalty == nil)
    }

    @Test("un-hiding the flag restores eligibility")
    func unhide() {
        #expect(!ctx.isHardExcluded(hidden.copy(isHidden: false)))
    }

    @Test("never-show matches by id even for a recipe not in the context")
    func strangerById() {
        let stranger = F.recipe(nevered.id, tags: F.otherTags)
        #expect(!contextFor([]).isHardExcluded(stranger))
        #expect(ctx.isHardExcluded(stranger))
    }

    // MARK: ScoredRecipe

    private var base: ScoredRecipe {
        ScoredRecipe(
            recipe: F.recipe("r"), score: 0.42, explanation: "Nothing missing.",
            missingIngredientIds: ["paneer"], tier: .missing1)
    }

    @Test("defaults: not explore; tier nil when omitted")
    func scoredDefaults() {
        let craving = ScoredRecipe(
            recipe: F.recipe("r"), score: 0, explanation: "x", missingIngredientIds: [])
        #expect(!craving.isExplore)
        #expect(craving.tier == nil)
        #expect(!base.isExplore)
    }

    @Test("copy with no arguments preserves every field")
    func copyPreserves() {
        let copy = base.copy()
        #expect(copy.recipe.isIdentical(to: F.recipe("r")))
        #expect(F.near(copy.score, 0.42, eps: 1e-12))
        #expect(copy.explanation == "Nothing missing.")
        #expect(copy.missingIngredientIds == ["paneer"])
        #expect(copy.tier == .missing1)
        #expect(!copy.isExplore)
        #expect(copy == base)
    }

    @Test("copy replaces only explanation and isExplore")
    func copyReplaces() {
        let original = base
        let copy = original.copy(explanation: "Something different: Gujarati.", isExplore: true)
        #expect(copy.explanation == "Something different: Gujarati.")
        #expect(copy.isExplore)
        #expect(F.near(copy.score, 0.42, eps: 1e-12))
        #expect(copy.tier == .missing1)
        #expect(copy.missingIngredientIds == ["paneer"])
        #expect(original.explanation == "Nothing missing.", "immutable")
        #expect(!original.isExplore)
    }

    // MARK: RecipeTier

    @Test("declares display priority: use-it-up, ready, missing 1, 2")
    func tierOrder() {
        #expect(RecipeTier.allCases == [.useItUp, .readyNow, .missing1, .missing2])
    }
}
