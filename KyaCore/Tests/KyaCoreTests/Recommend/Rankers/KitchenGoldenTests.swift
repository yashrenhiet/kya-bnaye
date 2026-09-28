import Foundation
import KyaCore
import Testing

private typealias F = RankerFixtures

private func near(_ value: Double?, _ expected: Double) -> Bool {
    CoreFixtures.near(value, expected)
}

/// Every non-staple ingredient a dinner dish in the fixtures needs.
private let everythingForDinner = [
    "potato", "matar", "palak", "paneer", "toor_dal", "rice", "rajma", "chana", "egg", "noodles",
    "cabbage", "onion", "tomato", "ginger_garlic", "garam_masala", "kasuri_methi", "lemon",
    "curry_leaves", "soy_sauce",
]

private let alooMatarAndBasics = ["potato", "matar", "onion", "tomato"]

private let k4Pantry =
    alooMatarAndBasics + [
        "rice", "rajma", "ginger_garlic", "garam_masala", "lemon", "curry_leaves",
    ]

private func kitchenDeck(
    now: Date? = nil,
    pantry: [PantryItem] = [],
    events: [SwipeEvent] = [],
    meals: [MealLog] = []
) -> [ScoredRecipe] {
    let context = F.contextFor(
        now: now ?? F.weekdayDinner, pantry: pantry, events: events, meals: meals)
    return F.deckFor(context, KitchenRanker())
}

/// Kitchen-mode goldens K1–K12 from
/// `legacy/packages/kya_core/test/recommend/rankers/golden_scenarios_test.dart`.
/// Expected values are frozen from the Dart oracle; the derivation notes live
/// beside each scenario there.
@Suite("Kitchen mode goldens")
struct KitchenGoldenTests {
    private let dinner = F.weekdayDinner

    @Test("fixture clocks fall on the intended weekdays")
    func fixtureClocks() {
        let calendar = Calendar.kyaDefault
        #expect(calendar.component(.weekday, from: F.weekdayDinner) == 4)  // Wednesday
        #expect(calendar.component(.weekday, from: F.saturdayDinner) == 7)  // Saturday
    }

    @Test("K1 pantry=empty (staples only), history=none, now=Wed dinner -> [jeera_rice] Missing 1")
    func k1() {
        let deck = kitchenDeck()
        #expect(F.idsOf(deck) == ["jeera_rice"])
        #expect(F.tiersOf(deck) == [.missing1])
        #expect(deck.first?.explanation.contains("Missing: Rice.") == true)
    }

    @Test("K2 pantry=potato,matar,onion,tomato -> [aloo_matar, dal_tadka, jeera_rice]")
    func k2() {
        let deck = kitchenDeck(pantry: F.haveAll(alooMatarAndBasics))
        #expect(F.idsOf(deck) == ["aloo_matar", "dal_tadka", "jeera_rice"])
        #expect(F.tiersOf(deck) == [.readyNow, .missing1, .missing1])
        #expect(near(deck.first?.score, 0.65))
    }

    @Test("K3 pantry=K2 + palak (expires today) + paneer -> [palak_paneer UseItUp, ...]")
    func k3() {
        let deck = kitchenDeck(
            pantry: [F.have("palak", expiresOn: dinner)]
                + F.haveAll(["paneer"] + alooMatarAndBasics))
        #expect(Array(F.idsOf(deck).prefix(3)) == ["palak_paneer", "aloo_matar", "dal_tadka"])
        #expect(Array(F.tiersOf(deck).prefix(3)) == [.useItUp, .readyNow, .missing1])
        #expect(deck.first?.missingIngredientIds == ["ginger_garlic", "kasuri_methi"])
        #expect(deck.first?.explanation.contains("Palak") == true)
    }

    @Test("K4 rice dishes + aloo matar ready, cooked jeera_rice yesterday (rice after rice)")
    func k4() {
        let deck = kitchenDeck(
            pantry: F.haveAll(k4Pantry), meals: [F.cooked("jeera_rice", F.daysBefore(dinner, 1))])
        #expect(
            Array(F.idsOf(deck).prefix(4)) == [
                "aloo_matar", "lemon_rice", "rajma_chawal", "jeera_rice",
            ])
        #expect(F.tiersOf(deck).prefix(4).allSatisfy { $0 == .readyNow })
    }

    @Test("K5 pantry=K4, cooked dal_tadka yesterday -> [aloo_matar, jeera_rice, lemon_rice]")
    func k5() {
        let deck = kitchenDeck(
            pantry: F.haveAll(k4Pantry), meals: [F.cooked("dal_tadka", F.daysBefore(dinner, 1))])
        #expect(Array(F.idsOf(deck).prefix(3)) == ["aloo_matar", "jeera_rice", "lemon_rice"])
        #expect(Array(F.tiersOf(deck).prefix(3)) == [.readyNow, .readyNow, .readyNow])
    }

    @Test("K6 breakfast pantry, now=Wed 08:00 -> [poha, upma, masala_dosa]")
    func k6() {
        let deck = kitchenDeck(
            now: F.weekdayBreakfast,
            pantry: F.haveAll(["poha", "onion", "green_chilli", "rava", "potato", "dosa_batter"]))
        #expect(F.idsOf(deck) == ["poha", "upma", "masala_dosa"])
        #expect(F.tiersOf(deck) == [.readyNow, .missing1, .missing1])
    }

    @Test("K7 pantry=K2 at Low + oil Out -> [aloo_matar M1, dal_tadka M2, jeera_rice M2]")
    func k7() {
        let deck = kitchenDeck(
            pantry: alooMatarAndBasics.map { F.have($0, level: .low) } + [F.out("oil")])
        #expect(F.idsOf(deck) == ["aloo_matar", "dal_tadka", "jeera_rice"])
        #expect(F.tiersOf(deck) == [.missing1, .missing2, .missing2])
        #expect(deck.first?.explanation == "You have 6 of 7 ingredients. Missing: Oil.")
    }

    @Test("K8 pantry=K2, left-swiped aloo_matar yesterday -> [dal_tadka, jeera_rice]")
    func k8() {
        let deck = kitchenDeck(
            pantry: F.haveAll(alooMatarAndBasics),
            events: [F.left("aloo_matar", F.daysBefore(dinner, 1))])
        #expect(F.idsOf(deck) == ["dal_tadka", "jeera_rice"])
        #expect(F.tiersOf(deck) == [.missing1, .missing1])
    }

    @Test("K9 pantry=K2, left-swiped aloo_matar 5 days ago -> penalised but its tier leads")
    func k9() {
        let deck = kitchenDeck(
            pantry: F.haveAll(alooMatarAndBasics),
            events: [F.left("aloo_matar", F.daysBefore(dinner, 5))])
        #expect(F.idsOf(deck) == ["aloo_matar", "dal_tadka", "jeera_rice"])
        #expect((deck.first?.score ?? .infinity) < 0.65 - 0.25)
    }

    @Test("K10 pantry=K2, never-show aloo_matar 30 days ago -> [dal_tadka, jeera_rice]")
    func k10() {
        let deck = kitchenDeck(
            pantry: F.haveAll(alooMatarAndBasics),
            events: [F.neverShow("aloo_matar", F.daysBefore(dinner, 30))])
        #expect(F.idsOf(deck) == ["dal_tadka", "jeera_rice"])
    }

    @Test("K11 tomato (expires tomorrow), paneer (2 days) -> all Use it up")
    func k11() {
        let deck = kitchenDeck(
            pantry: [
                F.have("tomato", expiresOn: F.daysAfter(dinner, 1)),
                F.have("paneer", expiresOn: F.daysAfter(dinner, 2)),
            ]
                + F.haveAll([
                    "potato", "matar", "onion", "palak", "ginger_garlic", "kasuri_methi",
                ]))
        #expect(
            Array(F.idsOf(deck).prefix(5)) == [
                "aloo_matar", "palak_paneer", "dal_tadka", "egg_curry", "chole_bhature",
            ])
        #expect(F.tiersOf(deck).prefix(5).allSatisfy { $0 == .useItUp })
        #expect(F.tiersOf(deck).last == .missing1)  // jeera_rice
    }

    @Test("K12 pantry=everything, right-swiped chole (2d) and rajma (5d)")
    func k12() {
        let deck = kitchenDeck(
            pantry: F.haveAll(everythingForDinner),
            events: [
                F.right("chole_bhature", F.daysBefore(dinner, 2)),
                F.right("rajma_chawal", F.daysBefore(dinner, 5)),
            ])
        #expect(
            F.idsOf(deck) == [
                "aloo_matar", "dal_tadka", "veg_hakka_noodles", "lemon_rice", "jeera_rice",
                "chole_bhature", "rajma_chawal", "egg_curry", "palak_paneer",
            ])
        #expect(F.tiersOf(deck).allSatisfy { $0 == .readyNow })
    }
}
