import Foundation
import KyaCore
import Testing

private typealias F = RankerFixtures
private typealias K = KitchenHarness

private func near(_ value: Double?, _ expected: Double) -> Bool {
    CoreFixtures.near(value, expected)
}

/// Port of `kitchen_ranker_test.dart`: scoring, exclusions, meal slot,
/// explanations and deck ordering.
@Suite("KitchenRanker: scoring, exclusions, explanations, ordering")
struct KitchenRankerScoringTests {
    private let dinner = F.weekdayDinner
    private let dalPantry = F.haveAll(["toor_dal", "onion", "tomato"])
    private let lemonRicePantry = F.haveAll(["rice", "lemon", "curry_leaves"])

    // MARK: scoring

    @Test("Ready now with no history scores 0.40 + 0.20 + quick")
    func readyScore() {
        // 30 minutes is quick: 0.40 + 0.20 + 0.05.
        #expect(near(K.score("aloo_matar", pantry: F.haveAll(K.alooMatarPantry))?.score, 0.65))
    }

    @Test("expiring boost adds 0.15 x share of items expiring")
    func expiringBoost() throws {
        let fresh = try #require(K.score("palak_paneer", pantry: F.haveAll(K.palakPaneerPantry)))
        let expiring = try #require(K.score("palak_paneer", pantry: K.palakExpiring(in: 2)))
        // 1 of Palak Paneer's 7 required ingredients is expiring.
        #expect(near(expiring.score - fresh.score, 0.15 / 7))
    }

    @Test("rice after rice costs 0.10 (same base as last meal)")
    func riceAfterRice() throws {
        let meals = [F.cooked("jeera_rice", F.daysBefore(dinner, 1))]
        let base = try #require(K.score("lemon_rice", pantry: lemonRicePantry, config: K.noTaste))
        let afterRice = try #require(
            K.score("lemon_rice", pantry: lemonRicePantry, meals: meals, config: K.noTaste))
        #expect(near(base.score - afterRice.score, 0.10))
    }

    @Test("only the most recent meal decides the last base")
    func mostRecentMeal() {
        let meals = [
            F.cooked("jeera_rice", F.daysBefore(dinner, 2)),
            F.cooked("aloo_matar", F.daysBefore(dinner, 1)),
        ]
        let result = K.score("lemon_rice", pantry: lemonRicePantry, meals: meals, config: K.noTaste)
        #expect(near(result?.score, 0.65))
    }

    @Test("a roti dish is not penalised after a rice meal")
    func rotiAfterRice() {
        let result = K.score(
            "aloo_matar", pantry: F.haveAll(K.alooMatarPantry),
            meals: [F.cooked("jeera_rice", F.daysBefore(dinner, 1))], config: K.noTaste)
        #expect(near(result?.score, 0.65))
    }

    @Test("DishBase.none never triggers the same-base penalty")
    func noneBase() {
        let result = K.score(
            "dal_tadka", pantry: dalPantry, meals: [F.cooked("poha", F.daysBefore(dinner, 1))],
            config: K.noTaste)
        #expect(near(result?.score, 0.65))
    }

    @Test("repeat penalty: cooked 2 days ago costs 0.30")
    func repeatPenalty() throws {
        let result = try #require(
            K.score(
                "dal_tadka", pantry: dalPantry,
                meals: [F.cooked("dal_tadka", F.daysBefore(dinner, 2))], config: K.noTaste))
        #expect(near(result.score, 0.65 - 0.30))
        #expect(result.tier == .readyNow)
    }

    @Test("reject penalty: left-swiped 5 days ago costs 0.25")
    func rejectPenalty() {
        let result = K.score(
            "dal_tadka", pantry: dalPantry, events: [F.left("dal_tadka", F.daysBefore(dinner, 5))],
            config: K.noTaste)
        #expect(near(result?.score, 0.65 - 0.25))
    }

    @Test("favourite adds 0.05")
    func favourite() {
        let favourite = F.recipe("aloo_matar").copy(isFavorite: true)
        let context = F.contextFor(
            now: dinner, pantry: F.haveAll(K.alooMatarPantry), mealType: .dinner)
        #expect(near(K.ranker.score(favourite, in: context)?.score, 0.70))
    }

    @Test("taste nudges the score by at most 0.10 x taste")
    func tasteNudge() throws {
        let plain = try #require(K.score("aloo_matar", pantry: F.haveAll(K.alooMatarPantry)))
        let liked = try #require(
            K.score(
                "aloo_matar", pantry: F.haveAll(K.alooMatarPantry),
                events: (1...5).map { F.right("aloo_matar", F.daysBefore(dinner, Double($0))) }))
        let delta = liked.score - plain.score
        #expect(delta > 0)
        #expect(delta < 0.10)
    }

    // MARK: exclusions

    @Test("left swipe within 3 days excludes the recipe", arguments: [0.0, 1, 3])
    func recentLeftExcluded(days: Double) {
        let result = K.score(
            "aloo_matar", pantry: F.haveAll(K.alooMatarPantry),
            events: [F.left("aloo_matar", F.daysBefore(dinner, days))])
        #expect(result == nil, "left-swiped \(days) day(s) ago")
    }

    @Test("left swipe 4 days ago is back in the deck")
    func leftFourDaysAgo() {
        let result = K.score(
            "aloo_matar", pantry: F.haveAll(K.alooMatarPantry),
            events: [F.left("aloo_matar", F.daysBefore(dinner, 4))])
        #expect(result != nil)
    }

    @Test("never-show event excludes the recipe")
    func neverShowExcluded() {
        let result = K.score(
            "aloo_matar", pantry: F.haveAll(K.alooMatarPantry),
            events: [F.neverShow("aloo_matar", F.daysBefore(dinner, 100))])
        #expect(result == nil)
    }

    @Test("a hidden recipe is excluded")
    func hiddenExcluded() {
        let hidden = F.recipe("aloo_matar").copy(isHidden: true)
        let context = F.contextFor(
            now: dinner, pantry: F.haveAll(K.alooMatarPantry), mealType: .dinner)
        #expect(K.ranker.score(hidden, in: context) == nil)
    }

    // MARK: meal-slot filter

    private let breakfastPantry = F.haveAll(["poha", "onion", "green_chilli"])

    @Test("a breakfast-only dish is excluded at dinner")
    func breakfastAtDinner() {
        #expect(K.score("poha", pantry: breakfastPantry) == nil)
    }

    @Test("the same dish is scored at breakfast")
    func breakfastAtBreakfast() {
        #expect(K.score("poha", pantry: breakfastPantry, mealType: .breakfast)?.tier == .readyNow)
    }

    @Test("the slot is auto-detected from the hour when not given")
    func autoSlot() {
        let atBreakfast = K.ranker.score(
            F.recipe("poha"), in: F.contextFor(now: F.weekdayBreakfast, pantry: breakfastPantry))
        let dinnerAtBreakfast = K.ranker.score(
            F.recipe("aloo_matar"),
            in: F.contextFor(now: F.weekdayBreakfast, pantry: F.haveAll(K.alooMatarPantry)))
        #expect(atBreakfast != nil)
        #expect(dinnerAtBreakfast == nil)
    }

    // MARK: explanations

    @Test("Ready now says nothing is missing")
    func readyExplanation() {
        let result = K.score("aloo_matar", pantry: F.haveAll(K.alooMatarPantry))
        #expect(result?.explanation == "You have everything for this — nothing missing.")
    }

    @Test("Missing 1 names the missing ingredient and the count")
    func missingOneExplanation() {
        let result = K.score("aloo_matar", pantry: F.haveAll(["potato", "onion", "tomato"]))
        #expect(result?.explanation == "You have 6 of 7 ingredients. Missing: Matar.")
    }

    @Test("Missing 2 lists both by display name")
    func missingTwoExplanation() {
        let result = K.score("aloo_matar", pantry: F.haveAll(["potato", "onion"]))
        #expect(result?.explanation == "You have 5 of 7 ingredients. Missing: Matar, Tomato.")
    }

    @Test("Use it up names the expiring ingredient")
    func useItUpExplanation() {
        let result = K.score("palak_paneer", pantry: K.palakExpiring(in: 2))
        #expect(result?.explanation == "Uses your Palak (2 days left). Nothing missing.")
    }

    @Test("Use it up says how many days are left (spec wording)")
    func useItUpDaysLeft() {
        let result = K.score("palak_paneer", pantry: K.palakExpiring(in: 2))
        #expect(result?.explanation.contains("(2 days left)") == true)
    }

    @Test("Use it up with gaps says how many are missing")
    func useItUpGapsExplanation() {
        let pantry = [F.have("palak", expiresOn: dinner)] + F.haveAll(["paneer", "onion"])
        #expect(
            K.score("palak_paneer", pantry: pantry)?.explanation
                == "Uses your Palak (today). Missing 2.")
    }

    @Test("every tier yields a non-empty explanation")
    func nonEmptyExplanations() {
        let pantry =
            [F.have("palak", expiresOn: dinner)]
            + F.haveAll(["paneer", "potato", "matar", "onion", "tomato"])
        let context = F.contextFor(now: dinner, pantry: pantry, mealType: .dinner)
        let scored = F.recipes.compactMap { K.ranker.score($0, in: context) }
        #expect(!scored.isEmpty)
        for card in scored {
            #expect(
                !card.explanation.trimmingCharacters(in: .whitespaces).isEmpty, "\(card.recipe)")
        }
    }

    // MARK: deck ordering

    @Test("Use it up first, then Ready now, then Missing 1, then Missing 2")
    func tierOrdering() {
        let pantry =
            [F.have("palak", expiresOn: F.daysAfter(dinner, 1))]
            + F.haveAll([
                "paneer", "onion", "ginger_garlic", "kasuri_methi", "potato", "matar", "tomato",
            ])
        let deck = F.deckFor(
            F.contextFor(now: dinner, pantry: pantry, mealType: .dinner), K.ranker)
        #expect(
            F.tiersOf(deck) == [.useItUp, .readyNow, .missing1, .missing1, .missing2, .missing2])
        #expect(Array(F.idsOf(deck).prefix(2)) == ["palak_paneer", "aloo_matar"])
    }

    @Test("a low-scoring Ready now card still beats a Missing 1 card")
    func readyBeatsMissing() throws {
        // Left-swiped 5 days ago (-0.25) and cooked 2 days ago (-0.30).
        let context = F.contextFor(
            now: dinner, pantry: F.haveAll(K.alooMatarPantry),
            events: [F.left("aloo_matar", F.daysBefore(dinner, 5))],
            meals: [F.cooked("aloo_matar", F.daysBefore(dinner, 2))], mealType: .dinner)
        let deck = F.deckFor(context, K.ranker)
        try #require(deck.count > 1)
        #expect(deck[0].recipe.id == "aloo_matar")
        #expect(deck[0].score < deck[1].score)
    }
}
