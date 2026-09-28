import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures
private typealias C = RankingContextFixtures

/// Port of `ranking_context_test.dart`: cook and swipe history, recently
/// liked, and taste-profile wiring.
@Suite("RankingContext.build: history precomputation")
struct RankingContextHistoryTests {
    private let masala = C.paneerMasala.id
    private let bhurji = C.paneerBhurji.id
    private let rice = C.jeeraRice.id

    // MARK: cook history

    @Test("last cooked is the latest cook per recipe, input order agnostic")
    func lastCooked() {
        let ctx = C.build(meals: [
            F.cooked("m1", masala, F.daysAgo(10)),
            F.cooked("m2", masala, F.daysAgo(3)),
            F.cooked("m3", masala, F.daysAgo(100)),
            F.cooked("m4", bhurji, F.daysAgo(40)),
        ])
        #expect(ctx.lastCookedAtByRecipe == [masala: F.daysAgo(3), bhurji: F.daysAgo(40)])
    }

    @Test("rut count includes cooks up to 90 days back, not 91")
    func rutWindow() {
        let ctx = C.build(meals: [
            F.cooked("m1", masala, F.daysAgo(3)),
            F.cooked("m2", masala, F.daysAgo(10)),
            F.cooked("m3", masala, F.daysAgo(90)),
            F.cooked("m4", masala, F.daysAgo(91)),
            F.cooked("m5", bhurji, F.daysAgo(200)),
        ])
        #expect(ctx.cookCountInRutWindowByRecipe == [masala: 3])
        #expect(ctx.lastCookedAtByRecipe[bhurji] == F.daysAgo(200))
    }

    @Test("rut window follows the config")
    func rutWindowConfig() {
        let ctx = C.build(
            meals: [F.cooked("m1", masala, F.daysAgo(3)), F.cooked("m2", masala, F.daysAgo(10))],
            config: ScoringConfig(repeatRutWindowDays: 5))
        #expect(ctx.cookCountInRutWindowByRecipe == [masala: 1])
    }

    @Test("context feeds Penalties.repeatPenalty with the rut top-up")
    func feedsRepeatPenalty() {
        let ctx = C.build(meals: [
            F.cooked("m1", masala, F.daysAgo(20)),
            F.cooked("m2", masala, F.daysAgo(50)),
            F.cooked("m3", masala, F.daysAgo(80)),
        ])
        let penalty = Penalties.repeatPenalty(
            lastCookedAt: ctx.lastCookedAtByRecipe[masala],
            cookCountInRutWindow: ctx.cookCountInRutWindowByRecipe[masala] ?? 0,
            now: ctx.now, config: ctx.config)
        #expect(F.near(penalty, 0.10 + 2 * 0.02))
    }

    @Test("lastCookedBase is the base of the most recent cook overall")
    func lastCookedBase() {
        let ctx = C.build(meals: [
            F.cooked("m1", masala, F.daysAgo(3)),
            F.cooked("m2", rice, F.daysAgo(1)),
            F.cooked("m3", bhurji, F.daysAgo(2)),
        ])
        #expect(ctx.lastCookedBase == .rice)
    }

    @Test("lastCookedBase is nil when the latest cook is a deleted recipe")
    func lastCookedBaseDeleted() {
        let ctx = C.build(meals: [
            F.cooked("m1", rice, F.daysAgo(2)), F.cooked("m2", "deleted", F.daysAgo(1)),
        ])
        #expect(ctx.lastCookedBase == nil)
        #expect(ctx.lastCookedAtByRecipe["deleted"] == F.daysAgo(1))
    }

    @Test("a future-dated cook (clock skew) is treated as the latest")
    func futureCook() {
        let future = F.later(days: 2)
        let ctx = C.build(meals: [
            F.cooked("m1", masala, F.daysAgo(1)), F.cooked("m2", masala, future),
        ])
        #expect(ctx.lastCookedAtByRecipe[masala] == future)
    }

    // MARK: swipe history

    @Test("last left swipe per recipe, ignoring undone swipes")
    func lastLeftSwipe() {
        let ctx = C.build(events: [
            F.swipe("e1", masala, .left, F.daysAgo(20)),
            F.swipe("e2", masala, .left, F.daysAgo(5)),
            F.swipe("e3", masala, .left, F.daysAgo(1)),
            F.undo("u3", "e3", F.daysAgo(1)),
            F.swipe("e4", bhurji, .right, F.daysAgo(1)),
        ])
        #expect(ctx.lastLeftSwipeAtByRecipe == [masala: F.daysAgo(5)])
    }

    @Test("left swipe older than every window is still recorded")
    func oldLeftSwipe() {
        let ctx = C.build(events: [F.swipe("e1", rice, .left, F.daysAgo(400))])
        #expect(ctx.lastLeftSwipeAtByRecipe[rice] == F.daysAgo(400))
        let penalty = Penalties.rejectPenalty(
            lastLeftSwipeAt: ctx.lastLeftSwipeAtByRecipe[rice], now: ctx.now, config: ctx.config)
        #expect(penalty == 0)
    }

    @Test("never-show ids exclude undone never-shows")
    func neverShown() {
        let ctx = C.build(events: [
            F.swipe("e1", bhurji, .neverShow, F.daysAgo(300)),
            F.swipe("e2", rice, .neverShow, F.daysAgo(1)),
            F.undo("u2", "e2", F.daysAgo(1)),
            F.swipe("e3", masala, .left, F.daysAgo(1)),
        ])
        #expect(ctx.neverShownRecipeIds == [bhurji])
    }

    @Test("never-show has no expiry")
    func neverShowNoExpiry() {
        let ctx = C.build(events: [F.swipe("e1", bhurji, .neverShow, F.daysAgo(3650))])
        #expect(ctx.neverShownRecipeIds.contains(bhurji))
    }

    // MARK: recently liked (RECOMMENDER.md 6)

    @Test("right swipes and cooks within 60 days, deduped, newest first")
    func recentlyLiked() {
        let ctx = C.build(
            events: [
                F.swipe("e1", rice, .right, F.daysAgo(2)),
                F.swipe("e2", masala, .right, F.daysAgo(70)),
                F.swipe("e3", bhurji, .right, F.daysAgo(10)),
                F.swipe("e4", bhurji, .right, F.daysAgo(30)),
                F.swipe("e5", "left_only", .left, F.daysAgo(1)),
                F.swipe("e6", "never", .neverShow, F.daysAgo(1)),
                F.swipe("e7", "undone", .right, F.refNow),
                F.undo("u7", "e7", F.refNow),
            ],
            meals: [F.cooked("m1", masala, F.daysAgo(3)), F.cooked("m2", bhurji, F.daysAgo(59))])
        #expect(ctx.recentlyLikedRecipeIdsDesc == [rice, masala, bhurji])
    }

    @Test("60 days back is included, 61 is not")
    func likeWindowBoundary() {
        let ctx = C.build(
            events: [F.swipe("e1", rice, .right, F.daysAgo(60))],
            meals: [F.cooked("m1", masala, F.daysAgo(61))])
        #expect(ctx.recentlyLikedRecipeIdsDesc == [rice])
    }

    @Test("a cook newer than a swipe of the same recipe moves it up")
    func cookMovesUp() {
        let ctx = C.build(
            events: [
                F.swipe("e1", masala, .right, F.daysAgo(20)),
                F.swipe("e2", rice, .right, F.daysAgo(10)),
            ],
            meals: [F.cooked("m1", masala, F.daysAgo(1))])
        #expect(ctx.recentlyLikedRecipeIdsDesc == [masala, rice])
    }

    // MARK: taste profile wiring

    @Test("matches TasteProfile.from over the same history")
    func tasteProfileWiring() {
        let events = [
            F.swipe("e1", masala, .right, F.daysAgo(4)), F.swipe("e2", rice, .left, F.daysAgo(1)),
        ]
        let meals = [F.cooked("m1", bhurji, F.daysAgo(12))]
        let ctx = C.build(events: events, meals: meals)
        let direct = TasteProfile.from(
            events: events, mealLogs: meals,
            recipesById: Dictionary(uniqueKeysWithValues: C.allRecipes.map { ($0.id, $0) }),
            now: F.refNow)
        #expect(ctx.tasteProfile.affinity.count == direct.affinity.count)
        for (key, value) in direct.affinity {
            #expect(F.near(ctx.tasteProfile.affinity[key], value))
            #expect(F.near(ctx.tasteProfile.evidence(for: key), direct.evidence(for: key)))
        }
    }

    @Test("passes the same config through to the profile")
    func configPassThrough() {
        let custom = ScoringConfig(signalWeightRightSwipe: 2)
        let ctx = C.build(events: [F.swipe("e1", masala, .right, F.refNow)], config: custom)
        #expect(ctx.config == custom)
        #expect(ctx.tasteProfile.config == custom)
        #expect(F.near(ctx.tasteProfile.affinity[TagKey.region("north")], 2))
    }
}
