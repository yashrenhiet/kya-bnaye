import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

// Three synthetic dish families with fully disjoint tags, so each family's
// taste score and evidence can be reasoned about independently.
const _familyA = DishTags(
  region: Region.north,
  dishType: DishType.curry,
  flavours: {Flavour.spicy},
  heaviness: Heaviness.heavy,
  protein: Protein.paneer,
);
const _familyB = DishTags(
  region: Region.south,
  dishType: DishType.breakfast,
  flavours: {Flavour.tangy},
  heaviness: Heaviness.light,
  protein: Protein.vegOnly,
);
const _familyC = DishTags(
  region: Region.gujarati,
  dishType: DishType.snack,
  flavours: {Flavour.sweet},
  heaviness: Heaviness.medium,
  protein: Protein.dalLegume,
);

/// 18 well-liked A dishes, 6 slightly-disliked B dishes (some evidence),
/// 6 never-seen C dishes (zero evidence).
final List<Recipe> _pool = [
  for (var i = 0; i < 18; i++) syntheticRecipe('a$i', _familyA),
  for (var i = 0; i < 6; i++) syntheticRecipe('b$i', _familyB),
  for (var i = 0; i < 6; i++) syntheticRecipe('c$i', _familyC),
];

List<SwipeEvent> _history(DateTime now) => [
  for (var d = 1; d <= 4; d++) right('a0', daysBefore(now, d)),
  left('b0', daysBefore(now, 20)),
];

RankingContext _poolContext({
  List<SwipeEvent>? events,
  ScoringConfig config = const ScoringConfig(),
}) {
  return contextFor(
    now: weekdayDinner,
    events: events ?? _history(weekdayDinner),
    allRecipes: _pool,
    config: config,
    mealType: MealType.dinner,
  );
}

List<ScoredRecipe> _cravingDeck({
  int seed = 7,
  List<Recipe>? candidates,
  RankingContext? context,
}) {
  return const DeckBuilder().build(
    candidates: candidates ?? _pool,
    context: context ?? _poolContext(),
    strategy: const CravingRanker(),
    seed: seed,
  );
}

void main() {
  group('deck size', () {
    test('caps a craving deck at 20 cards', () {
      expect(_pool, hasLength(30));
      expect(_cravingDeck(), hasLength(20));
    });

    test('caps a kitchen deck at 20 cards', () {
      final deck = const DeckBuilder().build(
        candidates: _pool,
        context: _poolContext(),
        strategy: const KitchenRanker(),
        seed: 7,
      );
      expect(deck, hasLength(20));
    });

    test('honours a configured deck size', () {
      final context = _poolContext(config: const ScoringConfig(deckSize: 10));
      final deck = _cravingDeck(context: context);
      expect(deck, hasLength(10));
      expect(deck.where((c) => c.isExplore), hasLength(2));
    });

    test('fewer candidates than the deck size → every candidate, once', () {
      final few = _pool.take(5).toList();
      final deck = _cravingDeck(candidates: few);
      expect(idsOf(deck).toSet(), few.map((r) => r.id).toSet());
      expect(deck, hasLength(5));
    });

    test('empty candidates → empty deck', () {
      expect(_cravingDeck(candidates: const []), isEmpty);
      expect(
        deckFor(_poolContext(), const KitchenRanker(), candidates: []),
        isEmpty,
      );
    });

    test('every candidate excluded → empty deck', () {
      final events = [
        for (final r in _pool.take(3)) neverShow(r.id, weekdayDinner),
      ];
      final deck = _cravingDeck(
        candidates: _pool.take(3).toList(),
        context: _poolContext(events: events),
      );
      expect(deck, isEmpty);
    });
  });

  group('kitchen mode', () {
    test('never contains explore cards', () {
      final deck = const DeckBuilder().build(
        candidates: _pool,
        context: _poolContext(),
        strategy: const KitchenRanker(),
        seed: 7,
      );
      expect(deck.where((c) => c.isExplore), isEmpty);
      expect(
        deck.map((c) => c.explanation),
        everyElement(isNot(startsWith('Something different'))),
      );
    });
  });

  group('craving mode composition', () {
    test('~80/20: 16 exploit cards then 4 explore cards', () {
      final deck = _cravingDeck();
      expect(deck.take(16).where((c) => c.isExplore), isEmpty);
      expect(deck.skip(16).where((c) => c.isExplore), hasLength(4));
    });

    test('exploit cards are the top scores, in descending order', () {
      final deck = _cravingDeck();
      final exploit = deck.take(16).toList();
      expect(idsOf(exploit), everyElement(startsWith('a')));
      for (var i = 1; i < exploit.length; i++) {
        expect(exploit[i - 1].score, greaterThanOrEqualTo(exploit[i].score));
      }
    });

    test('explore cards come from the lowest-evidence dishes', () {
      // C dishes have zero evidence; B has a little; the two leftover A
      // dishes have a lot.
      final explore = _cravingDeck().skip(16);
      expect(idsOf(explore), everyElement(startsWith('c')));
    });

    test('explore cards are labelled "Something different: <region>."', () {
      for (final card in _cravingDeck().skip(16)) {
        expect(card.isExplore, isTrue);
        expect(card.explanation, 'Something different: Gujarati.');
      }
    });

    test('explore label uses a human region name', () {
      // Spec section 4/6: "Something different: Gujarati."
      final card = _cravingDeck().last;
      expect(card.explanation, 'Something different: Gujarati.');
    });

    test('with zero history the first deck is 100% explore', () {
      // Spec section 4, "Cold start": zero picks → 100% explore.
      final deck = _cravingDeck(context: _poolContext(events: const []));
      expect(deck, hasLength(20));
      expect(deck.every((c) => c.isExplore), isTrue);
    });

    test('no recipe appears twice in a deck', () {
      for (var seed = 0; seed < 20; seed++) {
        final ids = idsOf(_cravingDeck(seed: seed));
        expect(ids.toSet(), hasLength(ids.length), reason: 'seed $seed');
      }
    });

    test('left-swiped (≤ 3 days) and never-show recipes are left out', () {
      final events = [
        ..._history(weekdayDinner),
        left('a1', daysBefore(weekdayDinner, 1)),
        neverShow('c0', daysBefore(weekdayDinner, 30)),
      ];
      final ids = idsOf(_cravingDeck(context: _poolContext(events: events)));
      expect(ids, isNot(contains('a1')));
      expect(ids, isNot(contains('c0')));
      expect(ids, hasLength(20));
    });
  });

  group('determinism', () {
    test('same inputs and seed → identical deck', () {
      final first = _cravingDeck(seed: 42);
      final second = _cravingDeck(seed: 42);
      expect(idsOf(second), idsOf(first));
      expect(
        second.map((c) => c.explanation).toList(),
        first.map((c) => c.explanation).toList(),
      );
    });

    test('the seed never changes the exploit part', () {
      final exploit = idsOf(_cravingDeck(seed: 1).take(16));
      for (var seed = 2; seed < 10; seed++) {
        expect(idsOf(_cravingDeck(seed: seed).take(16)), exploit);
      }
    });

    test('a different seed can change the explore cards ("Shuffle")', () {
      final exploreOrders = {
        for (var seed = 0; seed < 10; seed++)
          idsOf(_cravingDeck(seed: seed).skip(16)).join(','),
      };
      expect(exploreOrders.length, greaterThan(1));
    });

    test('kitchen decks ignore the seed entirely', () {
      List<String> kitchenIds(int seed) => idsOf(
        const DeckBuilder().build(
          candidates: recipes,
          context: contextFor(
            now: weekdayDinner,
            pantry: haveAll(['potato', 'matar', 'onion', 'tomato']),
          ),
          strategy: const KitchenRanker(),
          seed: seed,
        ),
      );
      expect(kitchenIds(99), kitchenIds(1));
    });
  });
}
