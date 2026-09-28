import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures
private typealias T = TasteFixtures

/// Shared data for the `taste_profile_test.dart` port.
enum TasteFixtures {
    static let tanhOneThird = 0.32151273753163434  // tanh(1 / 3)
    static let tanhHalf = 0.46211715726000974  // tanh(0.5)
    static let tanhOne = 0.7615941559557649  // tanh(1)

    static let paneerCurry = F.recipe("paneer_curry")
    static let idli = F.recipe("idli", tags: F.otherTags)
    static let recipes = [paneerCurry.id: paneerCurry, idli.id: idli]

    static let north = TagKey.region(Region.north.rawValue)
    static let south = TagKey.region(Region.south.rawValue)
    static let spicy = TagKey.flavour(Flavour.spicy.rawValue)
    static let paneer = TagKey.protein(Protein.paneer.rawValue)

    static func fold(
        events: [SwipeEvent] = [],
        meals: [MealLog] = [],
        config: ScoringConfig = ScoringConfig()
    ) -> TasteProfile {
        TasteProfile.from(
            events: events, mealLogs: meals, recipesById: recipes, now: F.refNow, config: config)
    }
}

/// A named signal-weight case: its events/meals and the expected weight.
struct SignalCase: Sendable, CustomTestStringConvertible {
    let name: String
    let events: [SwipeEvent]
    let meals: [MealLog]
    let weight: Double

    var testDescription: String { "\(name) contributes \(weight)" }

    static var all: [SignalCase] {
        let id = T.paneerCurry.id
        return [
            SignalCase(
                name: "right swipe", events: [F.swipe("e", id, .right, F.refNow)], meals: [],
                weight: 1.0),
            SignalCase(
                name: "cooked", events: [], meals: [F.cooked("m", id, F.refNow)], weight: 1.5),
            SignalCase(
                name: "left swipe", events: [F.swipe("e", id, .left, F.refNow)], meals: [],
                weight: -0.4),
            SignalCase(
                name: "never show", events: [F.swipe("e", id, .neverShow, F.refNow)], meals: [],
                weight: -3.0),
        ]
    }
}

/// Port of `taste_profile_test.dart`: folding, signal weights, decay and undo.
@Suite("TasteProfile.from")
struct TasteProfileFoldTests {
    private let curry = T.paneerCurry.id

    // MARK: no history

    @Test("empty history -> empty maps and neutral everywhere")
    func emptyHistory() {
        let profile = T.fold()
        #expect(profile.affinity.isEmpty)
        #expect(profile.evidence.isEmpty)
        for key in F.defaultKeys + F.otherTags.allKeys {
            #expect(profile.normalised(key) == 0)
            #expect(profile.evidence(for: key) == 0)
        }
    }

    @Test("events for unknown (deleted) recipes are skipped")
    func unknownRecipes() {
        let profile = T.fold(
            events: [F.swipe("e1", "ghost", .right, F.refNow)],
            meals: [F.cooked("m1", "ghost", F.refNow)])
        #expect(profile.affinity.isEmpty)
        #expect(profile.evidence.isEmpty)
    }

    // MARK: signal weights (RECOMMENDER.md 4)

    @Test("signal contributes its weight to every tag of the recipe", arguments: SignalCase.all)
    func signalWeight(signal: SignalCase) {
        let profile = T.fold(events: signal.events, meals: signal.meals)
        #expect(Set(profile.affinity.keys) == Set(F.defaultKeys))
        for key in F.defaultKeys {
            #expect(F.near(profile.affinity[key], signal.weight))
            #expect(F.near(profile.evidence(for: key), abs(signal.weight)))
        }
        #expect(profile.affinity[T.south] == nil)
    }

    @Test("every flavour of a multi-flavour dish gets the full weight")
    func multiFlavour() {
        let profile = T.fold(events: [F.swipe("e", T.idli.id, .right, F.refNow)])
        #expect(F.near(profile.affinity[TagKey.flavour("tangy")], 1))
        #expect(F.near(profile.affinity[TagKey.flavour("mild")], 1))
        #expect(profile.affinity.count == F.otherTags.allKeys.count)
    }

    @Test("signals accumulate; evidence sums absolute values")
    func accumulate() {
        let profile = T.fold(
            events: [
                F.swipe("e1", curry, .right, F.refNow),
                F.swipe("e2", curry, .left, F.refNow),
                F.swipe("e3", curry, .left, F.refNow),
            ],
            meals: [F.cooked("m1", curry, F.refNow)])
        #expect(F.near(profile.affinity[T.north], 1.7))  // 1.0 + 1.5 - 0.4 - 0.4
        #expect(F.near(profile.evidence(for: T.north), 3.3))  // 1.0 + 1.5 + 0.4 + 0.4
    }

    @Test("never-show outweighs a right swipe; evidence still grows")
    func neverShowOutweighs() {
        let profile = T.fold(events: [
            F.swipe("e1", curry, .right, F.refNow), F.swipe("e2", curry, .neverShow, F.refNow),
        ])
        #expect(F.near(profile.affinity[T.paneer], -2))
        #expect(F.near(profile.evidence(for: T.paneer), 4))
        #expect(profile.normalised(T.paneer) < 0)
    }

    @Test("weights come from the injected config")
    func injectedWeights() {
        let custom = ScoringConfig(signalWeightRightSwipe: 6)
        let profile = T.fold(events: [F.swipe("e", curry, .right, F.refNow)], config: custom)
        #expect(F.near(profile.affinity[T.north], 6))
        #expect(profile.config == custom)
    }

    // MARK: 30-day half-life decay

    @Test(
        "right swipe aged (days, hours) decays to factor",
        arguments: [
            (0.0, 0.0, 1), (15, 0, 0.7071067811865476), (30, 0, 0.5), (60, 0, 0.25),
            (90, 0, 0.125), (0, 36, 0.9659363289248456),
        ] as [(Double, Double, Double)])
    func decay(days: Double, hours: Double, factor: Double) {
        let profile = T.fold(events: [
            F.swipe("e", curry, .right, F.ago(days: days, hours: hours))
        ])
        #expect(F.near(profile.affinity[T.north], factor))
        #expect(F.near(profile.evidence(for: T.north), factor))
    }

    @Test("cooked 30 days ago -> 1.5 * 0.5")
    func cookedDecay() {
        let profile = T.fold(meals: [F.cooked("m", curry, F.ago(days: 30))])
        #expect(F.near(profile.affinity[T.north], 0.75))
    }

    @Test("decay applies to negative signals and |w| in evidence")
    func negativeDecay() {
        let profile = T.fold(events: [F.swipe("e", curry, .neverShow, F.ago(days: 60))])
        #expect(F.near(profile.affinity[T.north], -0.75))
        #expect(F.near(profile.evidence(for: T.north), 0.75))
    }

    @Test("mixed ages fold into one decayed sum")
    func mixedAges() {
        let profile = T.fold(
            events: [
                F.swipe("e1", curry, .right, F.refNow),
                F.swipe("e2", curry, .left, F.ago(days: 30)),
            ],
            meals: [F.cooked("m", curry, F.ago(days: 60))])
        #expect(F.near(profile.affinity[T.north], 1.175))  // 1.0 - 0.4 * 0.5 + 1.5 * 0.25
        #expect(F.near(profile.evidence(for: T.north), 1.575))  // 1.0 + 0.4 * 0.5 + 1.5 * 0.25
    }

    @Test("custom half-life is honoured")
    func customHalfLife() {
        let profile = T.fold(
            events: [F.swipe("e", curry, .right, F.ago(days: 10))],
            config: ScoringConfig(tasteDecayHalfLifeDays: 10))
        #expect(F.near(profile.affinity[T.north], 0.5))
    }

    @Test("future-dated events count at full weight, never amplified")
    func futureEvents() {
        let profile = T.fold(
            events: [F.swipe("e", curry, .right, F.later(days: 30))],
            meals: [F.cooked("m", curry, F.later(hours: 5))])
        #expect(F.near(profile.affinity[T.north], 2.5))
        #expect(F.near(profile.evidence(for: T.north), 2.5))
    }

    // MARK: undo (append-only log, ADR 008)

    @Test("undo cancels the undone event and nothing else")
    func undoCancels() {
        let profile = T.fold(events: [
            F.swipe("e1", curry, .right, F.refNow),
            F.swipe("e2", curry, .neverShow, F.refNow),
            F.undo("u1", "e2", F.refNow),
        ])
        #expect(F.near(profile.affinity[T.north], 1))
        #expect(F.near(profile.evidence(for: T.north), 1))
    }

    @Test("undoing the only event leaves an empty profile")
    func undoOnly() {
        let profile = T.fold(events: [
            F.swipe("e1", T.idli.id, .left, F.refNow), F.undo("u1", "e1", F.refNow),
        ])
        #expect(profile.affinity.isEmpty)
        #expect(profile.evidence.isEmpty)
    }

    @Test("undo of an unknown id is harmless")
    func undoUnknown() {
        let profile = T.fold(events: [
            F.swipe("e1", curry, .right, F.refNow), F.undo("u1", "does-not-exist", F.refNow),
        ])
        #expect(F.near(profile.affinity[T.north], 1))
    }

    @Test("undo without a target id is harmless")
    func undoNoTarget() {
        let profile = T.fold(events: [
            F.swipe("e1", curry, .right, F.refNow), F.swipe("u1", curry, .undo, F.refNow),
        ])
        #expect(F.near(profile.affinity[T.north], 1))
    }

    @Test("undo events never touch meal logs")
    func undoMealLog() {
        let profile = T.fold(
            events: [F.undo("u1", "m1", F.refNow)], meals: [F.cooked("m1", curry, F.refNow)])
        #expect(F.near(profile.affinity[T.north], 1.5))
    }
}
