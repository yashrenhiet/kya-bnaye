import Foundation
import KyaCore
import Testing

private typealias F = RankerFixtures

// Three synthetic dish families with fully disjoint tags, so each family's
// taste score and evidence can be reasoned about independently.
private let familyA = DishTags(
    region: .north, dishType: .curry, flavours: [.spicy], heaviness: .heavy, protein: .paneer)
private let familyB = DishTags(
    region: .south, dishType: .breakfast, flavours: [.tangy], heaviness: .light,
    protein: .vegOnly)
private let familyC = DishTags(
    region: .gujarati, dishType: .snack, flavours: [.sweet], heaviness: .medium,
    protein: .dalLegume)

/// 18 well-liked A dishes, 6 slightly-disliked B dishes (some evidence), 6
/// never-seen C dishes (zero evidence).
private let pool: [Recipe] =
    (0..<18).map { F.syntheticRecipe("a\($0)", familyA) }
    + (0..<6).map { F.syntheticRecipe("b\($0)", familyB) }
    + (0..<6).map { F.syntheticRecipe("c\($0)", familyC) }

private func history(_ now: Date) -> [SwipeEvent] {
    (1...4).map { F.right("a0", F.daysBefore(now, Double($0))) }
        + [F.left("b0", F.daysBefore(now, 20))]
}

private func poolContext(
    events: [SwipeEvent]? = nil,
    config: ScoringConfig = ScoringConfig()
) -> RankingContext {
    F.contextFor(
        now: F.weekdayDinner, events: events ?? history(F.weekdayDinner), mealType: .dinner,
        config: config, allRecipes: pool)
}

private func cravingDeck(
    seed: Int = 7,
    candidates: [Recipe]? = nil,
    context: RankingContext? = nil
) -> [ScoredRecipe] {
    DeckBuilder().build(
        candidates: candidates ?? pool, context: context ?? poolContext(),
        strategy: CravingRanker(), seed: seed)
}

private func kitchenDeck(seed: Int = 7) -> [ScoredRecipe] {
    DeckBuilder().build(
        candidates: pool, context: poolContext(), strategy: KitchenRanker(), seed: seed)
}

/// Port of `legacy/packages/kya_core/test/recommend/rankers/deck_builder_test.dart`.
///
/// Dart shuffled the explore pool with `Random(seed)`, whose sequence Swift
/// cannot reproduce (AGENTS.md 7.1); ``SeededGenerator`` drives it here. Every
/// Dart deck test is already a property (composition, no duplicates, same seed
/// gives the same deck, exploit part seed-independent), so each is kept with
/// its frozen expectations.
@Suite("DeckBuilder")
struct DeckBuilderTests {
    // MARK: deck size

    @Test("caps a craving deck at 20 cards")
    func cravingCap() {
        #expect(pool.count == 30)
        #expect(cravingDeck().count == 20)
    }

    @Test("caps a kitchen deck at 20 cards")
    func kitchenCap() {
        #expect(kitchenDeck().count == 20)
    }

    @Test("honours a configured deck size")
    func configuredSize() {
        let deck = cravingDeck(context: poolContext(config: ScoringConfig(deckSize: 10)))
        #expect(deck.count == 10)
        #expect(deck.filter(\.isExplore).count == 2)
    }

    @Test("fewer candidates than the deck size -> every candidate, once")
    func fewCandidates() {
        let few = Array(pool.prefix(5))
        let deck = cravingDeck(candidates: few)
        #expect(Set(F.idsOf(deck)) == Set(few.map(\.id)))
        #expect(deck.count == 5)
    }

    @Test("empty candidates -> empty deck")
    func emptyCandidates() {
        #expect(cravingDeck(candidates: []).isEmpty)
        #expect(F.deckFor(poolContext(), KitchenRanker(), candidates: []).isEmpty)
    }

    @Test("every candidate excluded -> empty deck")
    func allExcluded() {
        let first3 = Array(pool.prefix(3))
        let events = first3.map { F.neverShow($0.id, F.weekdayDinner) }
        #expect(cravingDeck(candidates: first3, context: poolContext(events: events)).isEmpty)
    }

    // MARK: kitchen mode

    @Test("kitchen mode never contains explore cards")
    func kitchenNoExplore() {
        let deck = kitchenDeck()
        #expect(deck.filter(\.isExplore).isEmpty)
        #expect(deck.allSatisfy { !$0.explanation.hasPrefix("Something different") })
    }

    // MARK: craving mode composition

    @Test("~80/20: 16 exploit cards then 4 explore cards")
    func composition() {
        let deck = cravingDeck()
        #expect(deck.prefix(16).filter(\.isExplore).isEmpty)
        #expect(deck.dropFirst(16).filter(\.isExplore).count == 4)
    }

    @Test("exploit cards are the top scores, in descending order")
    func exploitOrder() {
        let exploit = Array(cravingDeck().prefix(16))
        #expect(F.idsOf(exploit).allSatisfy { $0.hasPrefix("a") })
        for index in 1..<exploit.count {
            #expect(exploit[index - 1].score >= exploit[index].score)
        }
    }

    @Test("explore cards come from the lowest-evidence dishes")
    func exploreLowestEvidence() {
        // C dishes have zero evidence; B has a little; leftover A has a lot.
        #expect(F.idsOf(cravingDeck().dropFirst(16)).allSatisfy { $0.hasPrefix("c") })
    }

    @Test("explore cards are labelled Something different: <region>.")
    func exploreLabels() {
        for card in cravingDeck().dropFirst(16) {
            #expect(card.isExplore)
            #expect(card.explanation == "Something different: Gujarati.")
        }
    }

    @Test("explore label uses a human region name")
    func exploreHumanLabel() {
        #expect(cravingDeck().last?.explanation == "Something different: Gujarati.")
    }

    @Test("with zero history the first deck is 100% explore")
    func coldStart() {
        let deck = cravingDeck(context: poolContext(events: []))
        #expect(deck.count == 20)
        #expect(deck.filter { !$0.isExplore }.isEmpty)
    }

    @Test("no recipe appears twice in a deck")
    func noDuplicates() {
        for seed in 0..<20 {
            let ids = F.idsOf(cravingDeck(seed: seed))
            #expect(Set(ids).count == ids.count, "seed \(seed)")
        }
    }

    @Test("left-swiped (<= 3 days) and never-show recipes are left out")
    func cooldownExclusion() {
        let events =
            history(F.weekdayDinner) + [
                F.left("a1", F.daysBefore(F.weekdayDinner, 1)),
                F.neverShow("c0", F.daysBefore(F.weekdayDinner, 30)),
            ]
        let ids = F.idsOf(cravingDeck(context: poolContext(events: events)))
        #expect(!ids.contains("a1"))
        #expect(!ids.contains("c0"))
        #expect(ids.count == 20)
    }

    // MARK: determinism

    @Test("same inputs and seed -> identical deck")
    func sameSeed() {
        let first = cravingDeck(seed: 42)
        let second = cravingDeck(seed: 42)
        #expect(F.idsOf(second) == F.idsOf(first))
        #expect(second.map(\.explanation) == first.map(\.explanation))
    }

    @Test("the seed never changes the exploit part")
    func exploitSeedIndependent() {
        let exploit = F.idsOf(cravingDeck(seed: 1).prefix(16))
        for seed in 2..<10 {
            #expect(F.idsOf(cravingDeck(seed: seed).prefix(16)) == exploit)
        }
    }

    @Test("a different seed can change the explore cards (Shuffle)")
    func shuffleChangesExplore() {
        let orders = Set(
            (0..<10).map { F.idsOf(cravingDeck(seed: $0).dropFirst(16)).joined(separator: ",") })
        #expect(orders.count > 1)
    }

    @Test("kitchen decks ignore the seed entirely")
    func kitchenIgnoresSeed() {
        func kitchenIds(_ seed: Int) -> [String] {
            let context = F.contextFor(
                now: F.weekdayDinner, pantry: F.haveAll(["potato", "matar", "onion", "tomato"]))
            return F.idsOf(F.deckFor(context, KitchenRanker(), seed: seed))
        }
        #expect(kitchenIds(99) == kitchenIds(1))
    }
}
