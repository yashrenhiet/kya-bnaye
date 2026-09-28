import Foundation
import KyaCore
import Testing

private typealias F = RankerFixtures

private let ranker = CravingRanker()

/// Isolates non-taste terms: history still feeds penalties.
private let noTaste = ScoringConfig(cravingTasteWeight: 0)

private func near(_ value: Double?, _ expected: Double) -> Bool {
    CoreFixtures.near(value, expected)
}

/// Right swipes on three South Indian dishes over the last three days.
private func lovesSouth(_ now: Date) -> [SwipeEvent] {
    [
        F.right("masala_dosa", F.daysBefore(now, 1)),
        F.right("upma", F.daysBefore(now, 2)),
        F.right("lemon_rice", F.daysBefore(now, 3)),
    ]
}

private func score(
    _ recipeId: String,
    pantry: [PantryItem] = [],
    events: [SwipeEvent] = [],
    meals: [MealLog] = [],
    config: ScoringConfig = ScoringConfig(),
    now: Date? = nil
) -> ScoredRecipe? {
    ranker.score(
        F.recipe(recipeId),
        in: F.contextFor(
            now: now ?? F.weekdayDinner, pantry: pantry, events: events, meals: meals,
            config: config))
}

private func undoOf(_ event: SwipeEvent) -> SwipeEvent {
    SwipeEvent(
        id: "undo-1", recipeId: event.recipeId, action: .undo, mode: .craving, at: event.at,
        deckSeed: 1, undoesEventId: event.id)
}

/// Port of `legacy/packages/kya_core/test/recommend/rankers/craving_ranker_test.dart`.
@Suite("CravingRanker")
struct CravingRankerTests {
    private let dinner = F.weekdayDinner

    @Test("supports exploration and never sets a Kitchen tier")
    func exploration() {
        #expect(ranker.supportsExploration)
        #expect(score("aloo_matar") != nil)
        #expect(score("aloo_matar")?.tier == nil)
        #expect(score("aloo_matar")?.isExplore == false)
    }

    @Test("ignores the meal slot (breakfast dishes show at dinner)")
    func ignoresMealSlot() {
        #expect(score("poha") != nil)
        #expect(score("upma") != nil)
    }

    @Test("lists missing required ingredients but never optional ones")
    func missingList() {
        let result = score("aloo_matar", pantry: F.haveAll(["potato", "onion"]))
        #expect(result?.missingIngredientIds == ["matar", "tomato"])
    }

    @Test("keeps dishes with many missing ingredients (no hard filter)")
    func noHardFilter() {
        #expect(score("rajma_chawal")?.missingIngredientIds.count == 6)
    }

    // MARK: taste vs pantry

    @Test("taste dominates when the pantry is equal")
    func tasteDominates() throws {
        let events = lovesSouth(dinner)
        let upma = try #require(score("upma", events: events)).score
        let lemonRice = try #require(score("lemon_rice", events: events)).score
        let alooMatar = try #require(score("aloo_matar", events: events)).score
        let chole = try #require(score("chole_bhature", events: events)).score
        #expect(upma > alooMatar)
        #expect(lemonRice > alooMatar)
        #expect(upma > chole)
    }

    @Test("pantry hint only nudges: a full pantry does not beat taste")
    func pantryOnlyNudges() throws {
        let events = lovesSouth(dinner)
        let upma = try #require(score("upma", events: events))
        let alooAtHome = try #require(
            score(
                "aloo_matar", pantry: F.haveAll(["potato", "matar", "onion", "tomato"]),
                events: events))
        #expect(upma.score > alooAtHome.score)
    }

    @Test("pantry hint is worth exactly 0.10 when all core items are home")
    func fullPantryHint() throws {
        let none = try #require(score("aloo_matar")).score
        let all = try #require(score("aloo_matar", pantry: F.haveAll(["potato", "matar"]))).score
        #expect(near(all - none, 0.10))
    }

    @Test("pantry hint is the fraction of core ingredients at home")
    func halfPantryHint() throws {
        let none = try #require(score("aloo_matar")).score
        let half = try #require(score("aloo_matar", pantry: F.haveAll(["potato"]))).score
        #expect(near(half - none, 0.05))
    }

    @Test("non-core ingredients do not move the pantry hint")
    func nonCoreHint() throws {
        let none = try #require(score("aloo_matar")).score
        #expect(near(score("aloo_matar", pantry: F.haveAll(["onion", "tomato"]))?.score, none))
    }

    @Test("Low still counts toward the pantry hint")
    func lowHint() throws {
        let none = try #require(score("aloo_matar")).score
        let pantry = [F.have("potato", level: .low), F.have("matar", level: .low)]
        let low = try #require(score("aloo_matar", pantry: pantry)).score
        #expect(near(low - none, 0.10))
    }

    // MARK: small bonuses

    @Test("quick (<= 30 min) adds 0.05 on weekdays only")
    func quickWeekdays() {
        #expect(near(score("jeera_rice")?.score, 0.05))
        #expect(near(score("jeera_rice", now: F.saturdayDinner)?.score, 0))
        #expect(near(score("rajma_chawal")?.score, 0))
    }

    @Test("favourite adds 0.05")
    func favourite() {
        let favourite = F.recipe("rajma_chawal").copy(isFavorite: true)
        #expect(near(ranker.score(favourite, in: F.contextFor(now: dinner))?.score, 0.05))
    }

    @Test("no history, empty pantry, weekend -> score is exactly 0")
    func zeroScore() {
        #expect(near(score("chole_bhature", now: F.saturdayDinner)?.score, 0))
    }

    // MARK: penalties

    @Test("repeat penalty: cooked 10 days ago costs 0.20")
    func repeatPenalty() {
        let result = score(
            "jeera_rice", meals: [F.cooked("jeera_rice", F.daysBefore(dinner, 10))],
            config: noTaste)
        #expect(near(result?.score, 0.05 - 0.20))
    }

    @Test("repeat penalty adds 0.02 per extra cook in 90 days (rut)")
    func rutPenalty() {
        let meals = [10.0, 30, 60].map { F.cooked("jeera_rice", F.daysBefore(dinner, $0)) }
        #expect(near(score("jeera_rice", meals: meals, config: noTaste)?.score, 0.05 - 0.20 - 0.04))
    }

    @Test("a cook more than 56 days ago carries no repeat penalty")
    func oldCook() {
        let result = score(
            "jeera_rice", meals: [F.cooked("jeera_rice", F.daysBefore(dinner, 100))],
            config: noTaste)
        #expect(near(result?.score, 0.05))
    }

    @Test("reject penalty: left-swiped 5 days ago costs 0.25")
    func rejectPenalty() {
        let result = score(
            "jeera_rice", events: [F.left("jeera_rice", F.daysBefore(dinner, 5))], config: noTaste)
        #expect(near(result?.score, 0.05 - 0.25))
    }

    @Test("left swipe more than 14 days ago carries no reject penalty")
    func oldLeftSwipe() {
        let result = score(
            "jeera_rice", events: [F.left("jeera_rice", F.daysBefore(dinner, 15))],
            config: noTaste)
        #expect(near(result?.score, 0.05))
    }

    @Test("left swipe within 3 days excludes; day 4 is back")
    func leftSwipeWindow() {
        for days in [0.0, 2, 3] {
            let result = score(
                "jeera_rice", events: [F.left("jeera_rice", F.daysBefore(dinner, days))])
            #expect(result == nil, "left-swiped \(days) day(s) ago")
        }
        #expect(score("jeera_rice", events: [F.left("jeera_rice", F.daysBefore(dinner, 4))]) != nil)
    }

    @Test("an undone left swipe does not exclude")
    func undoneLeftSwipe() {
        let swipe = F.left("jeera_rice", F.daysBefore(dinner, 1))
        #expect(score("jeera_rice", events: [swipe, undoOf(swipe)]) != nil)
    }

    @Test("never-show and hidden recipes are excluded")
    func neverShowAndHidden() {
        let events = [F.neverShow("jeera_rice", F.daysBefore(dinner, 200))]
        #expect(score("jeera_rice", events: events) == nil)
        let hidden = F.recipe("jeera_rice").copy(isHidden: true)
        #expect(ranker.score(hidden, in: F.contextFor(now: dinner)) == nil)
    }

    @Test("a dish cooked 10 days ago loses to an unrelated dish when its core is Out")
    func repeatOutweighsCook() throws {
        let meals = [F.cooked("rajma_chawal", F.daysBefore(dinner, 10))]
        let pantry = [F.out("rajma"), F.out("rice")]
        let rajma = try #require(score("rajma_chawal", pantry: pantry, meals: meals))
        // Dhokla shares no tag with Rajma Chawal.
        let dhokla = try #require(score("dhokla", pantry: pantry, meals: meals))
        #expect(dhokla.score > rajma.score)
    }
}
