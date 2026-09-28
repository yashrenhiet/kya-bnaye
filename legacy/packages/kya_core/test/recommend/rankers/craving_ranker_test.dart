import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Isolates non-taste terms: history still feeds penalties, but no longer
/// moves the score through the learned profile.
const _noTaste = ScoringConfig(cravingTasteWeight: 0);

/// Right swipes on three South Indian dishes over the last three days.
List<SwipeEvent> _lovesSouth(DateTime now) => [
  right('masala_dosa', daysBefore(now, 1)),
  right('upma', daysBefore(now, 2)),
  right('lemon_rice', daysBefore(now, 3)),
];

void main() {
  const ranker = CravingRanker();

  ScoredRecipe? score(
    String recipeId, {
    List<PantryItem> pantry = const [],
    List<SwipeEvent> events = const [],
    List<MealLog> meals = const [],
    ScoringConfig config = const ScoringConfig(),
    DateTime? now,
  }) {
    return ranker.score(
      recipe(recipeId),
      contextFor(
        now: now ?? weekdayDinner,
        pantry: pantry,
        events: events,
        meals: meals,
        config: config,
      ),
    );
  }

  test('supports exploration and never sets a Kitchen tier', () {
    expect(ranker.supportsExploration, isTrue);
    expect(score('aloo_matar')!.tier, isNull);
    expect(score('aloo_matar')!.isExplore, isFalse);
  });

  test('ignores the meal slot (breakfast dishes show at dinner)', () {
    expect(score('poha'), isNotNull);
    expect(score('upma'), isNotNull);
  });

  test('lists missing required ingredients but never optional ones', () {
    final result = score('aloo_matar', pantry: haveAll(['potato', 'onion']))!;
    expect(result.missingIngredientIds, ['matar', 'tomato']);
  });

  test('keeps dishes with many missing ingredients (no hard filter)', () {
    final result = score('rajma_chawal');
    expect(result, isNotNull);
    expect(result!.missingIngredientIds, hasLength(6));
  });

  group('taste vs pantry', () {
    test('taste dominates when the pantry is equal', () {
      final events = _lovesSouth(weekdayDinner);
      final upma = score('upma', events: events)!.score;
      final lemonRice = score('lemon_rice', events: events)!.score;
      final alooMatar = score('aloo_matar', events: events)!.score;
      final chole = score('chole_bhature', events: events)!.score;
      expect(upma, greaterThan(alooMatar));
      expect(lemonRice, greaterThan(alooMatar));
      expect(upma, greaterThan(chole));
    });

    test('pantry hint only nudges: a full pantry does not beat taste', () {
      final events = _lovesSouth(weekdayDinner);
      final upma = score('upma', events: events)!;
      final alooMatarAtHome = score(
        'aloo_matar',
        events: events,
        pantry: haveAll(['potato', 'matar', 'onion', 'tomato']),
      )!;
      expect(upma.score, greaterThan(alooMatarAtHome.score));
    });

    test('pantry hint is worth exactly 0.10 when all core items are home', () {
      final none = score('aloo_matar')!.score;
      final all = score(
        'aloo_matar',
        pantry: haveAll(['potato', 'matar']),
      )!.score;
      expect(all - none, closeTo(0.10, 1e-9));
    });

    test('pantry hint is the fraction of core ingredients at home', () {
      final none = score('aloo_matar')!.score;
      final half = score('aloo_matar', pantry: haveAll(['potato']))!.score;
      expect(half - none, closeTo(0.05, 1e-9));
    });

    test('non-core ingredients do not move the pantry hint', () {
      final none = score('aloo_matar')!.score;
      final flavourOnly = score(
        'aloo_matar',
        pantry: haveAll(['onion', 'tomato']),
      )!.score;
      expect(flavourOnly, closeTo(none, 1e-9));
    });

    test('Low still counts toward the pantry hint', () {
      final none = score('aloo_matar')!.score;
      final low = score(
        'aloo_matar',
        pantry: [
          have('potato', level: StockLevel.low),
          have('matar', level: StockLevel.low),
        ],
      )!.score;
      expect(low - none, closeTo(0.10, 1e-9));
    });
  });

  group('small bonuses', () {
    test('quick (≤ 30 min) adds 0.05 on weekdays only', () {
      expect(score('jeera_rice')!.score, closeTo(0.05, 1e-9));
      expect(score('jeera_rice', now: saturdayDinner)!.score, closeTo(0, 1e-9));
      expect(score('rajma_chawal')!.score, closeTo(0, 1e-9));
    });

    test('favourite adds 0.05', () {
      final favourite = recipe('rajma_chawal').copyWith(isFavorite: true);
      final result = ranker.score(favourite, contextFor(now: weekdayDinner))!;
      expect(result.score, closeTo(0.05, 1e-9));
    });

    test('no history, empty pantry, weekend → score is exactly 0', () {
      expect(
        score('chole_bhature', now: saturdayDinner)!.score,
        closeTo(0, 1e-9),
      );
    });
  });

  group('penalties', () {
    test('repeat penalty: cooked 10 days ago costs 0.20', () {
      final result = score(
        'jeera_rice',
        meals: [cooked('jeera_rice', daysBefore(weekdayDinner, 10))],
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.05 - 0.20, 1e-9));
    });

    test('repeat penalty adds 0.02 per extra cook in 90 days (rut)', () {
      final result = score(
        'jeera_rice',
        meals: [
          cooked('jeera_rice', daysBefore(weekdayDinner, 10)),
          cooked('jeera_rice', daysBefore(weekdayDinner, 30)),
          cooked('jeera_rice', daysBefore(weekdayDinner, 60)),
        ],
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.05 - 0.20 - 0.04, 1e-9));
    });

    test('a cook more than 56 days ago carries no repeat penalty', () {
      final result = score(
        'jeera_rice',
        meals: [cooked('jeera_rice', daysBefore(weekdayDinner, 100))],
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.05, 1e-9));
    });

    test('reject penalty: left-swiped 5 days ago costs 0.25', () {
      final result = score(
        'jeera_rice',
        events: [left('jeera_rice', daysBefore(weekdayDinner, 5))],
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.05 - 0.25, 1e-9));
    });

    test('left swipe more than 14 days ago carries no reject penalty', () {
      final result = score(
        'jeera_rice',
        events: [left('jeera_rice', daysBefore(weekdayDinner, 15))],
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.05, 1e-9));
    });

    test('left swipe within 3 days excludes; day 4 is back', () {
      for (final days in [0, 2, 3]) {
        expect(
          score(
            'jeera_rice',
            events: [left('jeera_rice', daysBefore(weekdayDinner, days))],
          ),
          isNull,
          reason: 'left-swiped $days day(s) ago',
        );
      }
      expect(
        score(
          'jeera_rice',
          events: [left('jeera_rice', daysBefore(weekdayDinner, 4))],
        ),
        isNotNull,
      );
    });

    test('an undone left swipe does not exclude', () {
      final swipe = left('jeera_rice', daysBefore(weekdayDinner, 1));
      final undo = SwipeEvent(
        id: 'undo-1',
        recipeId: 'jeera_rice',
        action: SwipeAction.undo,
        mode: SwipeMode.craving,
        at: daysBefore(weekdayDinner, 1),
        deckSeed: 1,
        undoesEventId: swipe.id,
      );
      expect(score('jeera_rice', events: [swipe, undo]), isNotNull);
    });

    test('never-show and hidden recipes are excluded', () {
      expect(
        score(
          'jeera_rice',
          events: [neverShow('jeera_rice', daysBefore(weekdayDinner, 200))],
        ),
        isNull,
      );
      final hidden = recipe('jeera_rice').copyWith(isHidden: true);
      expect(ranker.score(hidden, contextFor(now: weekdayDinner)), isNull);
    });

    test('a dish cooked 10 days ago loses to an unrelated dish when its '
        'core ingredients are Out (repeat penalty outweighs the cook)', () {
      final meals = [cooked('rajma_chawal', daysBefore(weekdayDinner, 10))];
      final pantry = [out('rajma'), out('rice')];
      final rajma = score('rajma_chawal', meals: meals, pantry: pantry)!;
      // Dhokla shares no tag with Rajma Chawal.
      final dhokla = score('dhokla', meals: meals, pantry: pantry)!;
      expect(dhokla.score, greaterThan(rajma.score));
    });
  });

  group('explanations', () {
    test('"Because you liked X." when tag overlap (Jaccard) ≥ 0.34', () {
      // Chole vs Rajma Chawal: 5 shared of 7 distinct tags.
      final result = score(
        'chole_bhature',
        events: [right('rajma_chawal', daysBefore(weekdayDinner, 5))],
      )!;
      expect(result.explanation, 'Because you liked Rajma Chawal.');
    });

    test('a cooked dish counts as liked', () {
      final result = score(
        'chole_bhature',
        meals: [cooked('rajma_chawal', daysBefore(weekdayDinner, 20))],
      )!;
      expect(result.explanation, 'Because you liked Rajma Chawal.');
    });

    test('picks the liked dish with the highest overlap, not the newest', () {
      // Aloo Matar vs Egg Curry: 4/8; vs Dal Tadka: 3/9.
      final result = score(
        'aloo_matar',
        events: [
          right('egg_curry', daysBefore(weekdayDinner, 10)),
          right('dal_tadka', daysBefore(weekdayDinner, 1)),
        ],
      )!;
      expect(result.explanation, 'Because you liked Egg Curry.');
    });

    test('Jaccard of exactly 1/3 is below 0.34 → falls back to a tag', () {
      // Poha vs Lemon Rice: savoury, light, vegOnly shared of 9 → 0.333.
      final result = score(
        'poha',
        events: [right('lemon_rice', daysBefore(weekdayDinner, 1))],
      )!;
      expect(result.explanation, "You've been into savoury lately.");
    });

    test('never cites the candidate itself as the liked dish', () {
      final result = score(
        'rajma_chawal',
        events: [right('rajma_chawal', daysBefore(weekdayDinner, 1))],
      )!;
      expect(result.explanation, isNot(contains('Because you liked')));
      expect(result.explanation, startsWith("You've been into "));
      expect(result.explanation, endsWith(' lately.'));
    });

    test('likes older than 60 days are not cited; weak tags fall through '
        'to the pantry line', () {
      final result = score(
        'chole_bhature',
        events: [right('rajma_chawal', daysBefore(weekdayDinner, 61))],
      )!;
      // Only salt and oil (staples) are "at home".
      expect(result.explanation, 'You already have 2 of 7 ingredients.');
    });

    test('an undone right swipe is not cited', () {
      final swipe = right('rajma_chawal', daysBefore(weekdayDinner, 1));
      final undo = SwipeEvent(
        id: 'undo-1',
        recipeId: 'rajma_chawal',
        action: SwipeAction.undo,
        mode: SwipeMode.craving,
        at: daysBefore(weekdayDinner, 1),
        deckSeed: 1,
        undoesEventId: swipe.id,
      );
      final result = score('chole_bhature', events: [swipe, undo])!;
      expect(result.explanation, 'You already have 2 of 7 ingredients.');
    });

    test('no history → "You already have a of b ingredients."', () {
      final result = score('aloo_matar', pantry: haveAll(['potato']))!;
      // Potato + salt, oil, haldi (staples) of 7 required.
      expect(result.explanation, 'You already have 4 of 7 ingredients.');
    });

    test('tag lines use a human label, not the enum name', () {
      // Spec section 6: "You've been into tangy South Indian lately."
      final result = score(
        'veg_hakka_noodles',
        events: [right('veg_hakka_noodles', daysBefore(weekdayDinner, 1))],
      )!;
      expect(result.explanation, contains('Indo-Chinese'));
    });

    test('never returns an empty explanation', () {
      final contexts = [
        contextFor(now: weekdayDinner),
        contextFor(now: weekdayDinner, events: _lovesSouth(weekdayDinner)),
        contextFor(
          now: saturdayDinner,
          pantry: haveAll(['rice', 'onion']),
          meals: [cooked('dal_tadka', daysBefore(saturdayDinner, 3))],
        ),
      ];
      for (final context in contexts) {
        for (final r in recipes) {
          final result = ranker.score(r, context);
          expect(result?.explanation.trim(), isNotEmpty, reason: r.id);
        }
      }
    });
  });
}
