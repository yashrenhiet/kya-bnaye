/// Golden scenarios ("pantry=X, history=Y, now=Z → top 3 = [...]") for both
/// modes over the 13 fixture recipes (`AGENTS.md` section 6,
/// `docs/design/RECOMMENDER.md` section 9).
///
/// Every expectation was derived by hand from the spec formulas; the key
/// numbers are noted beside each scenario so a failing golden can be
/// re-checked without re-deriving everything. Kitchen weights include the
/// rarity bonus 0.6 × (1 − f/13), where f is how many fixture recipes need
/// the ingredient as core/flavour.
library;

import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const RecipeTier _ready = RecipeTier.readyNow;
const RecipeTier _m1 = RecipeTier.missing1;
const RecipeTier _m2 = RecipeTier.missing2;
const RecipeTier _useItUp = RecipeTier.useItUp;

/// Every non-staple ingredient a dinner dish in the fixtures needs.
const _everythingForDinner = [
  'potato',
  'matar',
  'palak',
  'paneer',
  'toor_dal',
  'rice',
  'rajma',
  'chana',
  'egg',
  'noodles',
  'cabbage',
  'onion',
  'tomato',
  'ginger_garlic',
  'garam_masala',
  'kasuri_methi',
  'lemon',
  'curry_leaves',
  'soy_sauce',
];

const _alooMatarAndBasics = ['potato', 'matar', 'onion', 'tomato'];

void main() {
  const kitchen = KitchenRanker();
  const craving = CravingRanker();

  List<ScoredRecipe> kitchenDeck({
    DateTime? now,
    List<PantryItem> pantry = const [],
    List<SwipeEvent> events = const [],
    List<MealLog> meals = const [],
  }) {
    final at = now ?? weekdayDinner;
    return deckFor(
      contextFor(now: at, pantry: pantry, events: events, meals: meals),
      kitchen,
    );
  }

  List<ScoredRecipe> cravingDeck({
    DateTime? now,
    List<PantryItem> pantry = const [],
    List<SwipeEvent> events = const [],
    List<MealLog> meals = const [],
    List<Recipe>? candidates,
  }) {
    final at = now ?? weekdayDinner;
    return deckFor(
      contextFor(now: at, pantry: pantry, events: events, meals: meals),
      craving,
      candidates: candidates,
    );
  }

  test('fixture clocks fall on the intended weekdays', () {
    expect(weekdayDinner.weekday, DateTime.wednesday);
    expect(saturdayDinner.weekday, DateTime.saturday);
  });

  group('Kitchen mode goldens', () {
    test('K1 pantry=empty (staples only), history=none, now=Wed dinner '
        '→ [jeera_rice] Missing 1', () {
      // Every other dinner dish needs 3+ non-staples.
      final deck = kitchenDeck();
      expect(idsOf(deck), ['jeera_rice']);
      expect(tiersOf(deck), [_m1]);
      expect(deck.single.explanation, contains('Missing: Rice.'));
    });

    test('K2 pantry=potato,matar,onion,tomato, history=none, now=Wed dinner '
        '→ [aloo_matar, dal_tadka, jeera_rice]', () {
      // Missing 1: dal 0.40 × 6.35/9.31 + 0.05 = 0.323;
      //            jeera 0.40 × 2.55/5.41 + 0.05 = 0.238.
      final deck = kitchenDeck(pantry: haveAll(_alooMatarAndBasics));
      expect(idsOf(deck), ['aloo_matar', 'dal_tadka', 'jeera_rice']);
      expect(tiersOf(deck), [_ready, _m1, _m1]);
      expect(deck.first.score, closeTo(0.65, 1e-9));
    });

    test('K3 pantry=K2 + palak (expires today) + paneer, history=none, '
        'now=Wed dinner → [palak_paneer UseItUp, aloo_matar, dal_tadka]', () {
      final deck = kitchenDeck(
        pantry: [
          have('palak', expiresOn: weekdayDinner),
          ...haveAll(['paneer', ..._alooMatarAndBasics]),
        ],
      );
      expect(idsOf(deck).take(3), ['palak_paneer', 'aloo_matar', 'dal_tadka']);
      expect(tiersOf(deck).take(3), [_useItUp, _ready, _m1]);
      expect(deck.first.missingIngredientIds, [
        'ginger_garlic',
        'kasuri_methi',
      ]);
      expect(deck.first.explanation, contains('Palak'));
    });

    test('K4 pantry=rice dishes + aloo matar ready, history=cooked '
        'jeera_rice yesterday, now=Wed dinner '
        '→ [aloo_matar, lemon_rice, rajma_chawal] (rice after rice)', () {
      // n = tanh(1.5·0.977/3) = 0.453 on jeera_rice's tags.
      // aloo 0.6 + 0.1·0.238 + 0.05 = 0.674
      // lemon 0.6 + 0.1·0.283 + 0.05 − 0.10 (rice base) = 0.578
      // rajma 0.6 + 0.1·0.057 − 0.10 = 0.506
      // jeera 0.6 + 0.045 + 0.05 − 0.30 (repeat) − 0.10 = 0.295
      final deck = kitchenDeck(
        pantry: haveAll([
          ..._alooMatarAndBasics,
          'rice',
          'rajma',
          'ginger_garlic',
          'garam_masala',
          'lemon',
          'curry_leaves',
        ]),
        meals: [cooked('jeera_rice', daysBefore(weekdayDinner, 1))],
      );
      expect(idsOf(deck).take(4), [
        'aloo_matar',
        'lemon_rice',
        'rajma_chawal',
        'jeera_rice',
      ]);
      expect(tiersOf(deck).take(4), everyElement(_ready));
    });

    test('K5 pantry=K4, history=cooked dal_tadka yesterday (no base), '
        'now=Wed dinner → [aloo_matar, jeera_rice, lemon_rice]', () {
      // n = 0.453 on dal_tadka's tags; no same-base penalty for anyone.
      // aloo 0.6727 > jeera 0.6715 > lemon 0.6602 > rajma 0.6181.
      final deck = kitchenDeck(
        pantry: haveAll([
          ..._alooMatarAndBasics,
          'rice',
          'rajma',
          'ginger_garlic',
          'garam_masala',
          'lemon',
          'curry_leaves',
        ]),
        meals: [cooked('dal_tadka', daysBefore(weekdayDinner, 1))],
      );
      expect(idsOf(deck).take(3), ['aloo_matar', 'jeera_rice', 'lemon_rice']);
      expect(tiersOf(deck).take(3), [_ready, _ready, _ready]);
    });

    test('K6 pantry=poha,onion,green_chilli,rava,potato,dosa_batter, '
        'history=none, now=Wed 08:00 → [poha, upma, masala_dosa]', () {
      // Breakfast slot auto-detected. Upma/dosa miss curry leaves:
      // upma 0.40·0.822 + 0.20 + 0.05 = 0.579; dosa 0.40·0.864 + 0.20 = 0.546.
      final deck = kitchenDeck(
        now: weekdayBreakfast,
        pantry: haveAll([
          'poha',
          'onion',
          'green_chilli',
          'rava',
          'potato',
          'dosa_batter',
        ]),
      );
      expect(idsOf(deck), ['poha', 'upma', 'masala_dosa']);
      expect(tiersOf(deck), [_ready, _m1, _m1]);
    });

    test('K7 pantry=K2 at Low + oil Out, history=none, now=Wed dinner '
        '→ [aloo_matar M1, dal_tadka M2, jeera_rice M2]', () {
      final deck = kitchenDeck(
        pantry: [
          for (final id in _alooMatarAndBasics) have(id, level: StockLevel.low),
          out('oil'),
        ],
      );
      expect(idsOf(deck), ['aloo_matar', 'dal_tadka', 'jeera_rice']);
      expect(tiersOf(deck), [_m1, _m2, _m2]);
      expect(
        deck.first.explanation,
        'You have 6 of 7 ingredients. Missing: Oil.',
      );
    });

    test('K8 pantry=K2, history=left-swiped aloo_matar yesterday, '
        'now=Wed dinner → [dal_tadka, jeera_rice]', () {
      final deck = kitchenDeck(
        pantry: haveAll(_alooMatarAndBasics),
        events: [left('aloo_matar', daysBefore(weekdayDinner, 1))],
      );
      expect(idsOf(deck), ['dal_tadka', 'jeera_rice']);
      expect(tiersOf(deck), [_m1, _m1]);
    });

    test('K9 pantry=K2, history=left-swiped aloo_matar 5 days ago, '
        'now=Wed dinner → [aloo_matar, dal_tadka, jeera_rice] '
        '(penalised but its tier still leads)', () {
      final deck = kitchenDeck(
        pantry: haveAll(_alooMatarAndBasics),
        events: [left('aloo_matar', daysBefore(weekdayDinner, 5))],
      );
      expect(idsOf(deck), ['aloo_matar', 'dal_tadka', 'jeera_rice']);
      expect(deck.first.score, lessThan(0.65 - 0.25));
    });

    test('K10 pantry=K2, history=never-show aloo_matar 30 days ago, '
        'now=Wed dinner → [dal_tadka, jeera_rice]', () {
      final deck = kitchenDeck(
        pantry: haveAll(_alooMatarAndBasics),
        events: [neverShow('aloo_matar', daysBefore(weekdayDinner, 30))],
      );
      expect(idsOf(deck), ['dal_tadka', 'jeera_rice']);
    });

    test('K11 pantry=tomato (expires tomorrow), paneer (2 days) + palak '
        'paneer & aloo matar basics, history=none, now=Wed dinner '
        '→ [aloo_matar, palak_paneer, dal_tadka] all Use it up', () {
      // aloo 0.6 + 0.15/7 + 0.05 = 0.671; palak 0.6 + 0.15/7 = 0.621;
      // dal (misses toor dal) 0.273 + 0.021 + 0.05 = 0.344;
      // egg_curry 0.261, chole 0.251 (both Missing 2 but Use it up).
      final deck = kitchenDeck(
        pantry: [
          have('tomato', expiresOn: daysAfter(weekdayDinner, 1)),
          have('paneer', expiresOn: daysAfter(weekdayDinner, 2)),
          ...haveAll([
            'potato',
            'matar',
            'onion',
            'palak',
            'ginger_garlic',
            'kasuri_methi',
          ]),
        ],
      );
      expect(idsOf(deck).take(5), [
        'aloo_matar',
        'palak_paneer',
        'dal_tadka',
        'egg_curry',
        'chole_bhature',
      ]);
      expect(tiersOf(deck).take(5), everyElement(_useItUp));
      expect(tiersOf(deck).last, _m1); // jeera_rice
    });

    test('K12 pantry=everything, history=right-swiped chole (2d) and '
        'rajma (5d), now=Wed dinner '
        '→ [aloo_matar, dal_tadka, veg_hakka_noodles]', () {
      // Taste nudges only 0.10×: quick (+0.05) outweighs a Punjabi craving.
      // aloo 0.6742, dal 0.6687, noodles 0.6605, lemon 0.6575,
      // jeera 0.6536, chole 0.6518, rajma 0.6515.
      final deck = kitchenDeck(
        pantry: haveAll(_everythingForDinner),
        events: [
          right('chole_bhature', daysBefore(weekdayDinner, 2)),
          right('rajma_chawal', daysBefore(weekdayDinner, 5)),
        ],
      );
      expect(idsOf(deck), [
        'aloo_matar',
        'dal_tadka',
        'veg_hakka_noodles',
        'lemon_rice',
        'jeera_rice',
        'chole_bhature',
        'rajma_chawal',
        'egg_curry',
        'palak_paneer',
      ]);
      expect(tiersOf(deck), everyElement(_ready));
    });
  });

  group('Craving mode goldens', () {
    test('C1 pantry=empty, history=right-swiped dosa (1d), upma (2d), '
        'lemon rice (3d), now=Wed dinner '
        '→ [upma, lemon_rice, masala_dosa]', () {
      // upma 0.6·0.626 + 0.05 = 0.425; lemon 0.6·0.558 + 0.05 = 0.385;
      // dosa 0.6·0.602 = 0.361 (40 min, not quick); poha 0.314.
      final deck = cravingDeck(
        events: [
          right('masala_dosa', daysBefore(weekdayDinner, 1)),
          right('upma', daysBefore(weekdayDinner, 2)),
          right('lemon_rice', daysBefore(weekdayDinner, 3)),
        ],
      );
      expect(idsOf(deck).take(4), [
        'upma',
        'lemon_rice',
        'masala_dosa',
        'poha',
      ]);
      // Upma ties dosa and lemon rice at Jaccard 0.5; the newest (dosa)
      // is cited.
      expect(deck.first.explanation, 'Because you liked Masala Dosa.');
      expect(deck.every((c) => c.tier == null), isTrue);
    });

    test('C2 pantry=poha,onion,green_chilli, history=C1, now=Wed dinner '
        '→ [upma, poha, lemon_rice] (pantry nudges poha up one place)', () {
      // poha 0.314 + 0.10 = 0.414 < upma 0.425.
      final deck = cravingDeck(
        pantry: haveAll(['poha', 'onion', 'green_chilli']),
        events: [
          right('masala_dosa', daysBefore(weekdayDinner, 1)),
          right('upma', daysBefore(weekdayDinner, 2)),
          right('lemon_rice', daysBefore(weekdayDinner, 3)),
        ],
      );
      expect(idsOf(deck).take(3), ['upma', 'poha', 'lemon_rice']);
    });

    test('C3 pantry=empty, history=cooked rajma (10d) + right-swiped chole '
        '(2d), now=Wed dinner → [chole_bhature, aloo_matar, dal_tadka]', () {
      // chole 0.345; aloo 0.216; dal 0.180; egg 0.166;
      // rajma 0.351 − 0.20 (repeat, 10 days) = 0.151.
      final deck = cravingDeck(
        events: [right('chole_bhature', daysBefore(weekdayDinner, 2))],
        meals: [cooked('rajma_chawal', daysBefore(weekdayDinner, 10))],
      );
      expect(idsOf(deck).take(5), [
        'chole_bhature',
        'aloo_matar',
        'dal_tadka',
        'egg_curry',
        'rajma_chawal',
      ]);
      expect(deck.first.explanation, 'Because you liked Rajma Chawal.');
    });

    test('C4 pantry=rajma,rice, history=C3, now=Wed dinner '
        '→ [chole_bhature, rajma_chawal, aloo_matar]', () {
      // Rajma's core is home: 0.151 + 0.10 = 0.251 > aloo 0.216.
      final deck = cravingDeck(
        pantry: haveAll(['rajma', 'rice']),
        events: [right('chole_bhature', daysBefore(weekdayDinner, 2))],
        meals: [cooked('rajma_chawal', daysBefore(weekdayDinner, 10))],
      );
      expect(idsOf(deck).take(3), [
        'chole_bhature',
        'rajma_chawal',
        'aloo_matar',
      ]);
    });

    test('C5 pantry=empty, history=C1 + left-swiped upma yesterday, '
        'now=Wed dinner → [lemon_rice, masala_dosa, poha] (upma hidden)', () {
      // lemon 0.359, dosa 0.327, poha 0.274.
      final deck = cravingDeck(
        events: [
          right('masala_dosa', daysBefore(weekdayDinner, 1)),
          right('upma', daysBefore(weekdayDinner, 2)),
          right('lemon_rice', daysBefore(weekdayDinner, 3)),
          left('upma', daysBefore(weekdayDinner, 1)),
        ],
      );
      expect(idsOf(deck).take(3), ['lemon_rice', 'masala_dosa', 'poha']);
      expect(idsOf(deck), isNot(contains('upma')));
    });

    test('C6 pantry=empty, history=C1 + left-swiped upma 5 days ago, '
        'now=Wed dinner → [lemon_rice, masala_dosa, poha] (upma demoted)', () {
      // upma 0.381 − 0.25 = 0.131, below poha 0.278.
      final deck = cravingDeck(
        events: [
          right('masala_dosa', daysBefore(weekdayDinner, 1)),
          right('upma', daysBefore(weekdayDinner, 2)),
          right('lemon_rice', daysBefore(weekdayDinner, 3)),
          left('upma', daysBefore(weekdayDinner, 5)),
        ],
      );
      expect(idsOf(deck).take(3), ['lemon_rice', 'masala_dosa', 'poha']);
      expect(idsOf(deck), contains('upma'));
    });

    test('C7 pantry=empty, history=C1 + never-show lemon rice yesterday, '
        'now=Wed dinner → [poha, upma, masala_dosa]', () {
      // −3.0 on lemon rice's tags flips south/savoury/vegOnly slightly
      // negative: poha 0.1345, upma 0.1312, dosa 0.1207.
      final deck = cravingDeck(
        events: [
          right('masala_dosa', daysBefore(weekdayDinner, 1)),
          right('upma', daysBefore(weekdayDinner, 2)),
          right('lemon_rice', daysBefore(weekdayDinner, 3)),
          neverShow('lemon_rice', daysBefore(weekdayDinner, 1)),
        ],
      );
      expect(idsOf(deck).take(3), ['poha', 'upma', 'masala_dosa']);
      expect(idsOf(deck), isNot(contains('lemon_rice')));
    });

    test('C8 pantry=empty, history=right-swiped chole (2d), now=Wed dinner '
        '→ [chole_bhature, rajma_chawal, aloo_matar]', () {
      // n = 0.308 on chole's tags. chole 0.185; rajma 0.162;
      // aloo 0.069 + 0.05 quick = 0.119; dal 0.101.
      final deck = cravingDeck(
        events: [right('chole_bhature', daysBefore(weekdayDinner, 2))],
      );
      expect(idsOf(deck).take(4), [
        'chole_bhature',
        'rajma_chawal',
        'aloo_matar',
        'dal_tadka',
      ]);
      expect(deck[1].explanation, 'Because you liked Chole Bhature.');
    });

    test('C9 pantry=egg, history=right-swiped egg curry yesterday, '
        'now=Wed dinner → [egg_curry, aloo_matar, veg_hakka_noodles]', () {
      // egg 0.189 + 0.10 = 0.289; aloo 0.113 + 0.05 = 0.163;
      // noodles 0.066 + 0.05 = 0.116; dal 0.097.
      final deck = cravingDeck(
        pantry: haveAll(['egg']),
        events: [right('egg_curry', daysBefore(weekdayDinner, 1))],
      );
      expect(idsOf(deck).take(3), [
        'egg_curry',
        'aloo_matar',
        'veg_hakka_noodles',
      ]);
      final explanations = deck.take(3).map((c) => c.explanation).toList();
      // Egg curry cannot cite itself; its region tag is the first above
      // the 0.15 floor.
      expect(explanations[0], startsWith("You've been into "));
      // Aloo Matar vs Egg Curry: Jaccard 4/8.
      expect(explanations[1], 'Because you liked Egg Curry.');
      // Noodles vs Egg Curry: Jaccard 3/9 < 0.34 → strongest tag (spicy).
      expect(explanations[2], "You've been into spicy lately.");
    });

    test('C10 pantry=empty, history=cooked dal tadka 5× in 60 days '
        '(last 8d ago), now=Wed dinner '
        '→ [aloo_matar, jeera_rice, dal_tadka] (rut)', () {
      // n = 0.857 on dal's tags. dal 0.514 + 0.05 − (0.20 + 4×0.02)
      // = 0.284; aloo 0.307; jeera 0.294; rajma 0.206.
      final deck = cravingDeck(
        meals: [
          for (final d in [60, 45, 30, 20, 8])
            cooked('dal_tadka', daysBefore(weekdayDinner, d)),
        ],
      );
      expect(idsOf(deck).take(4), [
        'aloo_matar',
        'jeera_rice',
        'dal_tadka',
        'rajma_chawal',
      ]);
    });

    test('C11 pantry=potato,matar,egg, history=none, favourite=aloo matar, '
        'now=Sat dinner → [aloo_matar, egg_curry, masala_dosa]', () {
      // Weekend: no quick bonus. aloo 0.10 + 0.05 fav; egg 0.10;
      // dosa 0.05 (1 of 2 core); everything else 0.
      final candidates = [
        for (final r in recipes)
          if (r.id == 'aloo_matar') r.copyWith(isFavorite: true) else r,
      ];
      final deck = cravingDeck(
        now: saturdayDinner,
        pantry: haveAll(['potato', 'matar', 'egg']),
        candidates: candidates,
      );
      expect(idsOf(deck).take(3), ['aloo_matar', 'egg_curry', 'masala_dosa']);
      expect(deck[0].score, closeTo(0.15, 1e-9));
      expect(deck[1].score, closeTo(0.10, 1e-9));
      expect(deck[2].score, closeTo(0.05, 1e-9));
      // No history → pantry line.
      expect(deck[0].explanation, 'You already have 5 of 7 ingredients.');
      expect(deck[2].explanation, 'You already have 3 of 7 ingredients.');
    });

    test('C12 pantry=empty, history=none, now=Wed dinner → quick dishes '
        'lead, every card scored 0.05 or 0', () {
      final deck = cravingDeck();
      expect(deck, hasLength(recipes.length));
      final quick = deck.takeWhile((c) => c.score > 0.01).toList();
      expect(quick.map((c) => c.recipe.minutes), everyElement(lessThan(31)));
      expect(quick, hasLength(8));
      for (final card in deck) {
        expect(card.explanation, startsWith('You already have '));
      }
    });
  });
}
