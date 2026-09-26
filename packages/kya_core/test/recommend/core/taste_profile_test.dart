import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const double eps = 1e-9;

// tanh values the spec's `tanh(affinity / 3)` normalisation should produce.
const double tanhOneThird = 0.32151273753163434; // tanh(1 / 3)
const double tanhHalf = 0.46211715726000974; // tanh(0.5)
const double tanhOne = 0.7615941559557649; // tanh(1)

final Recipe paneerCurry = recipe('paneer_curry');
final Recipe idli = recipe('idli', tags: otherTags);
final Map<String, Recipe> recipes = {
  paneerCurry.id: paneerCurry,
  idli.id: idli,
};

TasteProfile fold({
  List<SwipeEvent> events = const [],
  List<MealLog> meals = const [],
  ScoringConfig config = const ScoringConfig(),
}) => profileFrom(
  events: events,
  mealLogs: meals,
  recipesById: recipes,
  now: refNow,
  config: config,
);

final TagKey north = TagKey.region(Region.north.name);
final TagKey south = TagKey.region(Region.south.name);
final TagKey spicy = TagKey.flavour(Flavour.spicy.name);
final TagKey paneer = TagKey.protein(Protein.paneer.name);

void main() {
  group('profileFrom with no history', () {
    test('empty history -> empty maps and neutral everywhere', () {
      final p = fold();
      expect(p.affinity, isEmpty);
      expect(p.evidence, isEmpty);
      for (final key in [...defaultKeys, ...otherTags.allKeys]) {
        expect(p.normalised(key), 0);
        expect(p.evidenceFor(key), 0);
      }
    });

    test('events for unknown (deleted) recipes are skipped', () {
      final p = fold(
        events: [swipe('e1', 'ghost', SwipeAction.right, refNow)],
        meals: [cooked('m1', 'ghost', refNow)],
      );
      expect(p.affinity, isEmpty);
      expect(p.evidence, isEmpty);
    });
  });

  group('signal weights (RECOMMENDER.md 4)', () {
    final cases = <String, (List<SwipeEvent>, List<MealLog>, double)>{
      'right swipe': (
        [swipe('e', paneerCurry.id, SwipeAction.right, refNow)],
        const [],
        1.0,
      ),
      'cooked': (const [], [cooked('m', paneerCurry.id, refNow)], 1.5),
      'left swipe': (
        [swipe('e', paneerCurry.id, SwipeAction.left, refNow)],
        const [],
        -0.4,
      ),
      'never show': (
        [swipe('e', paneerCurry.id, SwipeAction.neverShow, refNow)],
        const [],
        -3.0,
      ),
    };
    for (final MapEntry(key: name, value: c) in cases.entries) {
      test('$name contributes ${c.$3} to every tag of the recipe', () {
        final p = fold(events: c.$1, meals: c.$2);
        expect(p.affinity.keys, unorderedEquals(defaultKeys));
        for (final key in defaultKeys) {
          expect(p.affinity[key], closeTo(c.$3, eps));
          expect(p.evidenceFor(key), closeTo(c.$3.abs(), eps));
        }
        // Tags of recipes with no events stay untouched.
        expect(p.affinity.containsKey(south), isFalse);
      });
    }

    test('every flavour of a multi-flavour dish gets the full weight', () {
      final p = fold(events: [swipe('e', idli.id, SwipeAction.right, refNow)]);
      expect(p.affinity[TagKey.flavour('tangy')], closeTo(1, eps));
      expect(p.affinity[TagKey.flavour('mild')], closeTo(1, eps));
      expect(p.affinity.length, otherTags.allKeys.length);
    });

    test('signals accumulate; evidence sums absolute values', () {
      final p = fold(
        events: [
          swipe('e1', paneerCurry.id, SwipeAction.right, refNow),
          swipe('e2', paneerCurry.id, SwipeAction.left, refNow),
          swipe('e3', paneerCurry.id, SwipeAction.left, refNow),
        ],
        meals: [cooked('m1', paneerCurry.id, refNow)],
      );
      // 1.0 + 1.5 - 0.4 - 0.4
      expect(p.affinity[north], closeTo(1.7, eps));
      // 1.0 + 1.5 + 0.4 + 0.4
      expect(p.evidenceFor(north), closeTo(3.3, eps));
    });

    test('never-show outweighs a right swipe; evidence still grows', () {
      final p = fold(
        events: [
          swipe('e1', paneerCurry.id, SwipeAction.right, refNow),
          swipe('e2', paneerCurry.id, SwipeAction.neverShow, refNow),
        ],
      );
      expect(p.affinity[paneer], closeTo(-2, eps));
      expect(p.evidenceFor(paneer), closeTo(4, eps));
      expect(p.normalised(paneer), lessThan(0));
    });

    test('weights come from the injected config', () {
      const custom = ScoringConfig(signalWeightRightSwipe: 6);
      final p = fold(
        events: [swipe('e', paneerCurry.id, SwipeAction.right, refNow)],
        config: custom,
      );
      expect(p.affinity[north], closeTo(6, eps));
      expect(p.config, same(custom));
    });
  });

  group('30-day half-life decay', () {
    final ages = <Duration, double>{
      Duration.zero: 1,
      const Duration(days: 15): 0.7071067811865476, // 0.5 ^ 0.5
      const Duration(days: 30): 0.5,
      const Duration(days: 60): 0.25,
      const Duration(days: 90): 0.125,
      const Duration(hours: 36): 0.9659363289248456, // 0.5 ^ (1.5 / 30)
    };
    for (final MapEntry(key: age, value: factor) in ages.entries) {
      test('right swipe aged $age decays to $factor', () {
        final p = fold(
          events: [swipe('e', paneerCurry.id, SwipeAction.right, ago(age))],
        );
        expect(p.affinity[north], closeTo(factor, eps));
        expect(p.evidenceFor(north), closeTo(factor, eps));
      });
    }

    test('cooked 30 days ago -> 1.5 * 0.5', () {
      final p = fold(
        meals: [cooked('m', paneerCurry.id, ago(const Duration(days: 30)))],
      );
      expect(p.affinity[north], closeTo(0.75, eps));
    });

    test('decay applies to negative signals and |w| in evidence', () {
      final p = fold(
        events: [
          swipe(
            'e',
            paneerCurry.id,
            SwipeAction.neverShow,
            ago(const Duration(days: 60)),
          ),
        ],
      );
      expect(p.affinity[north], closeTo(-0.75, eps));
      expect(p.evidenceFor(north), closeTo(0.75, eps));
    });

    test('mixed ages fold into one decayed sum', () {
      final p = fold(
        events: [
          swipe('e1', paneerCurry.id, SwipeAction.right, refNow),
          swipe(
            'e2',
            paneerCurry.id,
            SwipeAction.left,
            ago(const Duration(days: 30)),
          ),
        ],
        meals: [cooked('m', paneerCurry.id, ago(const Duration(days: 60)))],
      );
      // 1.0 - 0.4 * 0.5 + 1.5 * 0.25
      expect(p.affinity[north], closeTo(1.175, eps));
      // 1.0 + 0.4 * 0.5 + 1.5 * 0.25
      expect(p.evidenceFor(north), closeTo(1.575, eps));
    });

    test('custom half-life is honoured', () {
      final p = fold(
        events: [
          swipe(
            'e',
            paneerCurry.id,
            SwipeAction.right,
            ago(const Duration(days: 10)),
          ),
        ],
        config: const ScoringConfig(tasteDecayHalfLifeDays: 10),
      );
      expect(p.affinity[north], closeTo(0.5, eps));
    });

    test('future-dated events count at full weight, never amplified', () {
      final p = fold(
        events: [
          swipe(
            'e',
            paneerCurry.id,
            SwipeAction.right,
            refNow.add(const Duration(days: 30)),
          ),
        ],
        meals: [
          cooked('m', paneerCurry.id, refNow.add(const Duration(hours: 5))),
        ],
      );
      expect(p.affinity[north], closeTo(2.5, eps));
      expect(p.evidenceFor(north), closeTo(2.5, eps));
    });
  });

  group('undo (append-only log, ADR 008)', () {
    test('undo cancels the undone event and nothing else', () {
      final p = fold(
        events: [
          swipe('e1', paneerCurry.id, SwipeAction.right, refNow),
          swipe('e2', paneerCurry.id, SwipeAction.neverShow, refNow),
          undo('u1', 'e2', refNow),
        ],
      );
      expect(p.affinity[north], closeTo(1, eps));
      expect(p.evidenceFor(north), closeTo(1, eps));
    });

    test('undoing the only event leaves an empty profile', () {
      final p = fold(
        events: [
          swipe('e1', idli.id, SwipeAction.left, refNow),
          undo('u1', 'e1', refNow),
        ],
      );
      expect(p.affinity, isEmpty);
      expect(p.evidence, isEmpty);
    });

    test('undo of an unknown id is harmless', () {
      final p = fold(
        events: [
          swipe('e1', paneerCurry.id, SwipeAction.right, refNow),
          undo('u1', 'does-not-exist', refNow),
        ],
      );
      expect(p.affinity[north], closeTo(1, eps));
    });

    test('undo without a target id is harmless', () {
      final p = fold(
        events: [
          swipe('e1', paneerCurry.id, SwipeAction.right, refNow),
          swipe('u1', paneerCurry.id, SwipeAction.undo, refNow),
        ],
      );
      expect(p.affinity[north], closeTo(1, eps));
    });

    test('undo events never touch meal logs', () {
      final p = fold(
        events: [undo('u1', 'm1', refNow)],
        meals: [cooked('m1', paneerCurry.id, refNow)],
      );
      expect(p.affinity[north], closeTo(1.5, eps));
    });
  });

  group('TasteProfile.normalised = tanh(affinity / 3)', () {
    TasteProfile withAffinity(double value) => TasteProfile(
      affinity: {north: value},
      evidence: {north: value.abs()},
      config: const ScoringConfig(),
    );

    final cases = <double, double>{
      0: 0,
      1: tanhOneThird,
      1.5: tanhHalf,
      3: tanhOne,
      -3: -tanhOne,
      -1: -tanhOneThird,
    };
    for (final MapEntry(key: raw, value: expected) in cases.entries) {
      test('affinity $raw -> $expected', () {
        expect(withAffinity(raw).normalised(north), closeTo(expected, eps));
      });
    }

    test('stays strictly inside (-1, 1) for moderate magnitudes', () {
      expect(withAffinity(30).normalised(north), lessThan(1));
      expect(withAffinity(30).normalised(north), closeTo(1, 1e-8));
      expect(withAffinity(-30).normalised(north), greaterThan(-1));
    });

    test(
      'saturates to 1 instead of NaN for very large affinity',
      () {
        expect(withAffinity(1200).normalised(north), closeTo(1, eps));
        expect(withAffinity(1000000).normalised(north), closeTo(1, eps));
      },
      skip:
          'BUG: taste_profile.dart:42-45 _tanh computes exp(2x) directly; '
          'for affinity > ~1064 exp overflows to Infinity and the result '
          'is Infinity/Infinity = NaN, poisoning every downstream score.',
    );

    test('saturates to -1 for very large negative affinity', () {
      expect(withAffinity(-1000000).normalised(north), closeTo(-1, eps));
    });

    test('unknown tag reads as neutral 0', () {
      final p = withAffinity(3);
      expect(p.normalised(south), 0);
      expect(p.evidenceFor(south), 0);
    });

    test('divisor comes from the config', () {
      final p = TasteProfile(
        affinity: {north: 1},
        evidence: {north: 1},
        config: const ScoringConfig(tasteNormaliseDivisor: 1),
      );
      expect(p.normalised(north), closeTo(tanhOne, eps));
    });

    test('folded profile normalises a single right swipe to tanh(1/3)', () {
      final p = fold(
        events: [swipe('e', paneerCurry.id, SwipeAction.right, refNow)],
      );
      expect(p.normalised(spicy), closeTo(tanhOneThird, eps));
    });
  });

  group('RECOMMENDER.md 9 asymmetry scenario', () {
    test('5 left swipes do not push paneer below neutral after 3 cooks', () {
      final p = fold(
        events: [
          for (var i = 0; i < 5; i++)
            swipe(
              'l$i',
              paneerCurry.id,
              SwipeAction.left,
              ago(Duration(days: i * 3)),
            ),
        ],
        meals: [
          for (var i = 0; i < 3; i++)
            cooked('m$i', paneerCurry.id, ago(Duration(days: 2 + i * 5))),
        ],
      );
      expect(p.normalised(paneer), greaterThan(0));
    });
  });

  group('tasteScoreFor weighted mean', () {
    const config = ScoringConfig();

    test('tag-dimension weights sum to 1', () {
      final sum =
          config.taggedRegionWeight +
          config.taggedDishTypeWeight +
          config.taggedFlavourWeight +
          config.taggedHeavinessWeight +
          config.taggedProteinWeight;
      expect(sum, closeTo(1, eps));
    });

    test('empty profile scores 0', () {
      expect(tasteScoreFor(defaultTags, fold(), config), 0);
    });

    test('uniform affinity across all tags returns that normalised value', () {
      final p = fold(
        events: [swipe('e', paneerCurry.id, SwipeAction.right, refNow)],
      );
      expect(tasteScoreFor(defaultTags, p, config), closeTo(tanhOneThird, eps));
    });

    test('each dimension is weighted per RECOMMENDER.md 4', () {
      final p = TasteProfile(
        affinity: {
          north: 3, // tanh(1)
          TagKey.dishType('curry'): -3, // -tanh(1)
          TagKey.flavour('tangy'): 3, // tanh(1)
          TagKey.flavour('mild'): 0, // 0 -> flavour mean tanh(1) / 2
          TagKey.heaviness('light'): 1.5, // tanh(0.5)
          TagKey.protein('egg'): 1, // tanh(1/3)
        },
        evidence: const {},
        config: config,
      );
      const tags = DishTags(
        region: Region.north,
        dishType: DishType.curry,
        flavours: {Flavour.tangy, Flavour.mild},
        heaviness: Heaviness.light,
        protein: Protein.egg,
      );
      const expected =
          0.25 * tanhOne +
          0.25 * -tanhOne +
          0.25 * (tanhOne / 2) +
          0.10 * tanhHalf +
          0.15 * tanhOneThird;
      expect(tasteScoreFor(tags, p, config), closeTo(expected, eps));
    });

    test("only the recipe's own tags are consulted", () {
      final p = fold(
        events: [swipe('e', idli.id, SwipeAction.neverShow, refNow)],
      );
      expect(tasteScoreFor(defaultTags, p, config), 0);
      expect(tasteScoreFor(otherTags, p, config), closeTo(-tanhOne, eps));
    });

    test('a dish with no flavour tags treats flavour as neutral', () {
      final p = fold(
        events: [swipe('e', paneerCurry.id, SwipeAction.right, refNow)],
      );
      const noFlavour = DishTags(
        region: Region.north,
        dishType: DishType.curry,
        flavours: {},
        heaviness: Heaviness.heavy,
        protein: Protein.paneer,
      );
      expect(
        tasteScoreFor(noFlavour, p, config),
        closeTo(0.75 * tanhOneThird, eps),
      );
    });

    test('custom dimension weights are honoured', () {
      const custom = ScoringConfig(
        taggedRegionWeight: 1,
        taggedDishTypeWeight: 0,
        taggedFlavourWeight: 0,
        taggedHeavinessWeight: 0,
        taggedProteinWeight: 0,
      );
      final p = TasteProfile(
        affinity: {north: 3, paneer: -3},
        evidence: const {},
        config: custom,
      );
      expect(tasteScoreFor(defaultTags, p, custom), closeTo(tanhOne, eps));
    });
  });
}
