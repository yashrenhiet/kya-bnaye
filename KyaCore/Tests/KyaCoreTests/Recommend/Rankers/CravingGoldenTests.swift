import Foundation
import KyaCore
import Testing

private typealias F = RankerFixtures

private func near(_ value: Double?, _ expected: Double) -> Bool {
    CoreFixtures.near(value, expected)
}

private func cravingDeck(
    now: Date? = nil,
    pantry: [PantryItem] = [],
    events: [SwipeEvent] = [],
    meals: [MealLog] = [],
    candidates: [Recipe]? = nil
) -> [ScoredRecipe] {
    let context = F.contextFor(
        now: now ?? F.weekdayDinner, pantry: pantry, events: events, meals: meals)
    return F.deckFor(context, CravingRanker(), candidates: candidates)
}

/// C1 history: right-swiped dosa (1d), upma (2d), lemon rice (3d).
private func c1History(_ now: Date) -> [SwipeEvent] {
    [
        F.right("masala_dosa", F.daysBefore(now, 1)),
        F.right("upma", F.daysBefore(now, 2)),
        F.right("lemon_rice", F.daysBefore(now, 3)),
    ]
}

private func prefix(_ deck: [ScoredRecipe], _ count: Int) -> [String] {
    Array(F.idsOf(deck).prefix(count))
}

/// Craving-mode goldens C1–C12 from
/// `legacy/packages/kya_core/test/recommend/rankers/golden_scenarios_test.dart`.
/// With 13 candidates every card is an exploit card, so no golden depends on
/// the explore shuffle.
@Suite("Craving mode goldens")
struct CravingGoldenTests {
    private let dinner = F.weekdayDinner

    @Test("C1 pantry=empty, history=C1, now=Wed dinner -> [upma, lemon_rice, masala_dosa]")
    func c1() {
        let deck = cravingDeck(events: c1History(dinner))
        #expect(prefix(deck, 4) == ["upma", "lemon_rice", "masala_dosa", "poha"])
        // Upma ties dosa and lemon rice at Jaccard 0.5; the newest (dosa) is cited.
        #expect(deck.first?.explanation == "Because you liked Masala Dosa.")
        #expect(deck.allSatisfy { $0.tier == nil })
    }

    @Test("C2 pantry=poha,onion,green_chilli, history=C1 -> [upma, poha, lemon_rice]")
    func c2() {
        let deck = cravingDeck(
            pantry: F.haveAll(["poha", "onion", "green_chilli"]), events: c1History(dinner))
        #expect(prefix(deck, 3) == ["upma", "poha", "lemon_rice"])
    }

    @Test("C3 cooked rajma (10d) + right-swiped chole (2d) -> [chole, aloo_matar, dal_tadka]")
    func c3() {
        let deck = cravingDeck(
            events: [F.right("chole_bhature", F.daysBefore(dinner, 2))],
            meals: [F.cooked("rajma_chawal", F.daysBefore(dinner, 10))])
        #expect(
            prefix(deck, 5) == [
                "chole_bhature", "aloo_matar", "dal_tadka", "egg_curry", "rajma_chawal",
            ])
        #expect(deck.first?.explanation == "Because you liked Rajma Chawal.")
    }

    @Test("C4 pantry=rajma,rice, history=C3 -> [chole_bhature, rajma_chawal, aloo_matar]")
    func c4() {
        let deck = cravingDeck(
            pantry: F.haveAll(["rajma", "rice"]),
            events: [F.right("chole_bhature", F.daysBefore(dinner, 2))],
            meals: [F.cooked("rajma_chawal", F.daysBefore(dinner, 10))])
        #expect(prefix(deck, 3) == ["chole_bhature", "rajma_chawal", "aloo_matar"])
    }

    @Test("C5 history=C1 + left-swiped upma yesterday -> upma hidden")
    func c5() {
        let deck = cravingDeck(
            events: c1History(dinner) + [F.left("upma", F.daysBefore(dinner, 1))])
        #expect(prefix(deck, 3) == ["lemon_rice", "masala_dosa", "poha"])
        #expect(!F.idsOf(deck).contains("upma"))
    }

    @Test("C6 history=C1 + left-swiped upma 5 days ago -> upma demoted")
    func c6() {
        let deck = cravingDeck(
            events: c1History(dinner) + [F.left("upma", F.daysBefore(dinner, 5))])
        #expect(prefix(deck, 3) == ["lemon_rice", "masala_dosa", "poha"])
        #expect(F.idsOf(deck).contains("upma"))
    }

    @Test("C7 history=C1 + never-show lemon rice yesterday -> [poha, upma, masala_dosa]")
    func c7() {
        let deck = cravingDeck(
            events: c1History(dinner) + [F.neverShow("lemon_rice", F.daysBefore(dinner, 1))])
        #expect(prefix(deck, 3) == ["poha", "upma", "masala_dosa"])
        #expect(!F.idsOf(deck).contains("lemon_rice"))
    }

    @Test("C8 right-swiped chole (2d) -> [chole_bhature, rajma_chawal, aloo_matar]")
    func c8() throws {
        let deck = cravingDeck(events: [F.right("chole_bhature", F.daysBefore(dinner, 2))])
        #expect(prefix(deck, 4) == ["chole_bhature", "rajma_chawal", "aloo_matar", "dal_tadka"])
        try #require(deck.count > 1)
        #expect(deck[1].explanation == "Because you liked Chole Bhature.")
    }

    @Test("C9 pantry=egg, right-swiped egg curry yesterday -> [egg_curry, aloo_matar, noodles]")
    func c9() {
        let deck = cravingDeck(
            pantry: F.haveAll(["egg"]), events: [F.right("egg_curry", F.daysBefore(dinner, 1))])
        #expect(prefix(deck, 3) == ["egg_curry", "aloo_matar", "veg_hakka_noodles"])
        let explanations = deck.prefix(3).map(\.explanation)
        // Egg curry cannot cite itself; its region tag is the first above the floor.
        #expect(explanations.first?.hasPrefix("You've been into ") == true)
        // Aloo Matar vs Egg Curry: Jaccard 4/8.
        #expect(explanations.dropFirst().first == "Because you liked Egg Curry.")
        // Noodles vs Egg Curry: Jaccard 3/9 < 0.34 -> strongest tag (spicy).
        #expect(explanations.last == "You've been into spicy lately.")
    }

    @Test("C10 cooked dal tadka 5x in 60 days (last 8d ago) -> rut")
    func c10() {
        let meals = [60.0, 45, 30, 20, 8].map { F.cooked("dal_tadka", F.daysBefore(dinner, $0)) }
        let deck = cravingDeck(meals: meals)
        #expect(prefix(deck, 4) == ["aloo_matar", "jeera_rice", "dal_tadka", "rajma_chawal"])
    }

    @Test("C11 pantry=potato,matar,egg, favourite=aloo matar, now=Sat dinner")
    func c11() throws {
        let candidates = F.recipes.map { $0.id == "aloo_matar" ? $0.copy(isFavorite: true) : $0 }
        let deck = cravingDeck(
            now: F.saturdayDinner, pantry: F.haveAll(["potato", "matar", "egg"]),
            candidates: candidates)
        #expect(prefix(deck, 3) == ["aloo_matar", "egg_curry", "masala_dosa"])
        try #require(deck.count > 2)
        #expect(near(deck[0].score, 0.15))
        #expect(near(deck[1].score, 0.10))
        #expect(near(deck[2].score, 0.05))
        // No history -> pantry line.
        #expect(deck[0].explanation == "You already have 5 of 7 ingredients.")
        #expect(deck[2].explanation == "You already have 3 of 7 ingredients.")
    }

    @Test("C12 pantry=empty, history=none -> quick dishes lead, every card 0.05 or 0")
    func c12() {
        let deck = cravingDeck()
        #expect(deck.count == F.recipes.count)
        let quick = deck.prefix { $0.score > 0.01 }
        #expect(quick.allSatisfy { $0.recipe.minutes < 31 })
        #expect(quick.count == 8)
        #expect(deck.allSatisfy { $0.explanation.hasPrefix("You already have ") })
    }
}
