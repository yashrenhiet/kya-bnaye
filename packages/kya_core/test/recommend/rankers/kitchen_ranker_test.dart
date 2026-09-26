import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Pantry that makes Aloo Matar fully cookable (staples assumed present).
const _alooMatarPantry = ['potato', 'matar', 'onion', 'tomato'];

/// Pantry that makes Palak Paneer fully cookable.
const _palakPaneerPantry = [
  'palak',
  'paneer',
  'onion',
  'ginger_garlic',
  'kasuri_methi',
];

/// Isolates non-taste terms: history still feeds penalties, but no longer
/// nudges the score through the learned profile.
const _noTaste = ScoringConfig(kitchenTasteWeight: 0);

void main() {
  const ranker = KitchenRanker();

  ScoredRecipe? score(
    String recipeId, {
    List<PantryItem> pantry = const [],
    List<SwipeEvent> events = const [],
    List<MealLog> meals = const [],
    MealType? mealType = MealType.dinner,
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
        mealType: mealType,
        config: config,
      ),
    );
  }

  test('does not support exploration', () {
    expect(ranker.supportsExploration, isFalse);
  });

  group('tiers', () {
    test('everything at home → Ready now, nothing missing', () {
      final result = score('aloo_matar', pantry: haveAll(_alooMatarPantry))!;
      expect(result.tier, RecipeTier.readyNow);
      expect(result.missingIngredientIds, isEmpty);
    });

    test('one non-optional ingredient absent → Missing 1', () {
      final result = score(
        'aloo_matar',
        pantry: haveAll(['potato', 'onion', 'tomato']),
      )!;
      expect(result.tier, RecipeTier.missing1);
      expect(result.missingIngredientIds, ['matar']);
    });

    test('two absent → Missing 2, listed in recipe order', () {
      final result = score('aloo_matar', pantry: haveAll(['potato', 'onion']))!;
      expect(result.tier, RecipeTier.missing2);
      expect(result.missingIngredientIds, ['matar', 'tomato']);
    });

    test('more than two missing is excluded (hard filter)', () {
      expect(score('aloo_matar', pantry: haveAll(['potato'])), isNull);
    });

    test('empty pantry excludes every dish needing 3+ non-staples', () {
      expect(score('aloo_matar'), isNull);
      expect(score('dal_tadka'), isNull);
      expect(score('jeera_rice')!.tier, RecipeTier.missing1);
    });

    test('an ingredient expiring within 3 days → Use it up', () {
      final result = score(
        'palak_paneer',
        pantry: [
          have('palak', expiresOn: daysAfter(weekdayDinner, 1)),
          ...haveAll(_palakPaneerPantry.skip(1).toList()),
        ],
      )!;
      expect(result.tier, RecipeTier.useItUp);
      expect(result.missingIngredientIds, isEmpty);
    });

    test('Use it up wins over Missing 2 for the badge', () {
      final result = score(
        'palak_paneer',
        pantry: [
          have('palak', expiresOn: weekdayDinner),
          ...haveAll(['paneer', 'onion']),
        ],
      )!;
      expect(result.tier, RecipeTier.useItUp);
      expect(result.missingIngredientIds, ['ginger_garlic', 'kasuri_methi']);
    });

    test('expiry exactly 3 days out still counts; 4 days does not', () {
      RecipeTier? tierFor(int days) => score(
        'palak_paneer',
        pantry: [
          have('palak', expiresOn: daysAfter(weekdayDinner, days)),
          ...haveAll(_palakPaneerPantry.skip(1).toList()),
        ],
      )!.tier;
      expect(tierFor(3), RecipeTier.useItUp);
      expect(tierFor(4), RecipeTier.readyNow);
    });

    test('an Out item with a near expiry is missing, not "use it up"', () {
      final result = score(
        'palak_paneer',
        pantry: [
          PantryItem(
            ingredientId: 'palak',
            level: StockLevel.out,
            updatedAt: weekdayDinner,
            expiresOn: weekdayDinner,
          ),
          ...haveAll(_palakPaneerPantry.skip(1).toList()),
        ],
      )!;
      expect(result.tier, RecipeTier.missing1);
      expect(result.missingIngredientIds, ['palak']);
    });
  });

  group('availability rules', () {
    test('optional (garnish) ingredients never count as missing', () {
      // Coriander is optional in Aloo Matar and absent from the pantry.
      final result = score('aloo_matar', pantry: haveAll(_alooMatarPantry))!;
      expect(result.missingIngredientIds, isNot(contains('coriander')));
      expect(result.tier, RecipeTier.readyNow);
    });

    test('an Out garnish still does not count as missing', () {
      final result = score(
        'aloo_matar',
        pantry: [...haveAll(_alooMatarPantry), out('coriander')],
      )!;
      expect(result.tier, RecipeTier.readyNow);
    });

    test(
      'an ingredient whose catalog role is optional never counts as missing',
      () {
        // Spec section 5: "optional items never count as missing", and
        // IngredientRole.optional's own doc: "Never counts as missing".
        final kachumber = Recipe(
          id: 'kachumber',
          name: 'Kachumber',
          mealTypes: const {MealType.dinner},
          minutes: 10,
          base: DishBase.none,
          ingredients: const [
            RecipeIngredient(ingredientId: 'onion', quantityText: '1'),
            RecipeIngredient(ingredientId: 'tomato', quantityText: '1'),
            RecipeIngredient(ingredientId: 'coriander', quantityText: '1'),
          ],
          steps: const ['Chop and toss.'],
          tags: recipe('dal_tadka').tags,
          source: RecipeSource.user,
        );
        final result = ranker.score(
          kachumber,
          contextFor(
            now: weekdayDinner,
            pantry: haveAll(['onion', 'tomato']),
            mealType: MealType.dinner,
          ),
        )!;
        expect(result.missingIngredientIds, isEmpty);
        expect(result.tier, RecipeTier.readyNow);
      },
      skip:
          'BUG: availability.dart:19 treats an IngredientRole.optional '
          'ingredient like core/flavour (needs a pantry row), so it counts '
          'as missing unless the recipe line also sets isOptional.',
    );

    test('staples with no pantry row are assumed present', () {
      // Salt, oil and haldi have no pantry rows at all.
      final result = score('aloo_matar', pantry: haveAll(_alooMatarPantry))!;
      expect(result.missingIngredientIds, isEmpty);
    });

    test('a staple explicitly marked Out counts as missing', () {
      final result = score(
        'aloo_matar',
        pantry: [...haveAll(_alooMatarPantry), out('oil')],
      )!;
      expect(result.tier, RecipeTier.missing1);
      expect(result.missingIngredientIds, ['oil']);
    });

    test('a staple Out pushes a Missing 2 dish over the limit', () {
      final result = score(
        'aloo_matar',
        pantry: [
          ...haveAll(['potato', 'onion']),
          out('salt'),
        ],
      );
      expect(result, isNull);
    });

    test('Low counts as available', () {
      final result = score(
        'aloo_matar',
        pantry: [
          for (final id in _alooMatarPantry) have(id, level: StockLevel.low),
        ],
      )!;
      expect(result.tier, RecipeTier.readyNow);
      expect(result.missingIngredientIds, isEmpty);
    });

    test(
      'a staple earns no rarity bonus (weight is its role weight)',
      () {
        final context = contextFor(now: weekdayDinner);
        expect(context.ingredientWeight('salt'), closeTo(0.25, 1e-9));
      },
      skip:
          'BUG: ranking_context.dart:191 — staples are left out of '
          'ingredientFrequency, so rarityBonus reads them as maximally '
          'rare (+0.6): salt weighs 0.85 instead of 0.25.',
    );
  });

  group('scoring', () {
    test('Ready now with no history scores 0.40 + 0.20 + quick', () {
      final result = score('aloo_matar', pantry: haveAll(_alooMatarPantry))!;
      // 30 minutes is quick: 0.40 + 0.20 + 0.05.
      expect(result.score, closeTo(0.65, 1e-9));
    });

    test('expiring boost adds 0.15 × share of items expiring', () {
      final fresh = score('palak_paneer', pantry: haveAll(_palakPaneerPantry))!;
      final expiring = score(
        'palak_paneer',
        pantry: [
          have('palak', expiresOn: daysAfter(weekdayDinner, 2)),
          ...haveAll(_palakPaneerPantry.skip(1).toList()),
        ],
      )!;
      // 1 of Palak Paneer's 7 required ingredients is expiring.
      expect(expiring.score - fresh.score, closeTo(0.15 / 7, 1e-9));
    });

    test('rice after rice costs 0.10 (same base as last meal)', () {
      final pantry = haveAll(['rice', 'lemon', 'curry_leaves']);
      final meals = [cooked('jeera_rice', daysBefore(weekdayDinner, 1))];
      final base = score('lemon_rice', pantry: pantry, config: _noTaste)!;
      final afterRice = score(
        'lemon_rice',
        pantry: pantry,
        meals: meals,
        config: _noTaste,
      )!;
      expect(base.score - afterRice.score, closeTo(0.10, 1e-9));
    });

    test('only the most recent meal decides the "last base"', () {
      final pantry = haveAll(['rice', 'lemon', 'curry_leaves']);
      final meals = [
        cooked('jeera_rice', daysBefore(weekdayDinner, 2)),
        cooked('aloo_matar', daysBefore(weekdayDinner, 1)),
      ];
      final result = score(
        'lemon_rice',
        pantry: pantry,
        meals: meals,
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.65, 1e-9));
    });

    test('a roti dish is not penalised after a rice meal', () {
      final meals = [cooked('jeera_rice', daysBefore(weekdayDinner, 1))];
      final result = score(
        'aloo_matar',
        pantry: haveAll(_alooMatarPantry),
        meals: meals,
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.65, 1e-9));
    });

    test('DishBase.none never triggers the same-base penalty', () {
      final meals = [cooked('poha', daysBefore(weekdayDinner, 1))];
      final result = score(
        'dal_tadka',
        pantry: haveAll(['toor_dal', 'onion', 'tomato']),
        meals: meals,
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.65, 1e-9));
    });

    test('repeat penalty: cooked 2 days ago costs 0.30', () {
      final result = score(
        'dal_tadka',
        pantry: haveAll(['toor_dal', 'onion', 'tomato']),
        meals: [cooked('dal_tadka', daysBefore(weekdayDinner, 2))],
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.65 - 0.30, 1e-9));
      expect(result.tier, RecipeTier.readyNow);
    });

    test('reject penalty: left-swiped 5 days ago costs 0.25', () {
      final result = score(
        'dal_tadka',
        pantry: haveAll(['toor_dal', 'onion', 'tomato']),
        events: [left('dal_tadka', daysBefore(weekdayDinner, 5))],
        config: _noTaste,
      )!;
      expect(result.score, closeTo(0.65 - 0.25, 1e-9));
    });

    test('favourite adds 0.05', () {
      final favourite = recipe('aloo_matar').copyWith(isFavorite: true);
      final result = ranker.score(
        favourite,
        contextFor(
          now: weekdayDinner,
          pantry: haveAll(_alooMatarPantry),
          mealType: MealType.dinner,
        ),
      )!;
      expect(result.score, closeTo(0.70, 1e-9));
    });

    test('taste nudges the score by at most 0.10 × taste', () {
      final plain = score('aloo_matar', pantry: haveAll(_alooMatarPantry))!;
      final liked = score(
        'aloo_matar',
        pantry: haveAll(_alooMatarPantry),
        events: [
          for (var d = 1; d <= 5; d++)
            right('aloo_matar', daysBefore(weekdayDinner, d)),
        ],
      )!;
      final delta = liked.score - plain.score;
      expect(delta, greaterThan(0));
      expect(delta, lessThan(0.10));
    });
  });

  group('exclusions', () {
    test('left swipe within 3 days excludes the recipe', () {
      for (final days in [0, 1, 3]) {
        expect(
          score(
            'aloo_matar',
            pantry: haveAll(_alooMatarPantry),
            events: [left('aloo_matar', daysBefore(weekdayDinner, days))],
          ),
          isNull,
          reason: 'left-swiped $days day(s) ago',
        );
      }
    });

    test('left swipe 4 days ago is back in the deck', () {
      final result = score(
        'aloo_matar',
        pantry: haveAll(_alooMatarPantry),
        events: [left('aloo_matar', daysBefore(weekdayDinner, 4))],
      );
      expect(result, isNotNull);
    });

    test('never-show event excludes the recipe', () {
      final result = score(
        'aloo_matar',
        pantry: haveAll(_alooMatarPantry),
        events: [neverShow('aloo_matar', daysBefore(weekdayDinner, 100))],
      );
      expect(result, isNull);
    });

    test('a hidden recipe is excluded', () {
      final hidden = recipe('aloo_matar').copyWith(isHidden: true);
      final result = ranker.score(
        hidden,
        contextFor(
          now: weekdayDinner,
          pantry: haveAll(_alooMatarPantry),
          mealType: MealType.dinner,
        ),
      );
      expect(result, isNull);
    });
  });

  group('meal-slot filter', () {
    final breakfastPantry = haveAll(['poha', 'onion', 'green_chilli']);

    test('a breakfast-only dish is excluded at dinner', () {
      expect(score('poha', pantry: breakfastPantry), isNull);
    });

    test('the same dish is scored at breakfast', () {
      final result = score(
        'poha',
        pantry: breakfastPantry,
        mealType: MealType.breakfast,
      );
      expect(result?.tier, RecipeTier.readyNow);
    });

    test('the slot is auto-detected from the hour when not given', () {
      final atBreakfast = ranker.score(
        recipe('poha'),
        contextFor(now: weekdayBreakfast, pantry: breakfastPantry),
      );
      final dinnerAtBreakfast = ranker.score(
        recipe('aloo_matar'),
        contextFor(now: weekdayBreakfast, pantry: haveAll(_alooMatarPantry)),
      );
      expect(atBreakfast, isNotNull);
      expect(dinnerAtBreakfast, isNull);
    });
  });

  group('explanations', () {
    test('Ready now says nothing is missing', () {
      final result = score('aloo_matar', pantry: haveAll(_alooMatarPantry))!;
      expect(
        result.explanation,
        'You have everything for this — nothing missing.',
      );
    });

    test('Missing 1 names the missing ingredient and the count', () {
      final result = score(
        'aloo_matar',
        pantry: haveAll(['potato', 'onion', 'tomato']),
      )!;
      expect(
        result.explanation,
        'You have 6 of 7 ingredients. Missing: Matar.',
      );
    });

    test('Missing 2 lists both by display name', () {
      final result = score('aloo_matar', pantry: haveAll(['potato', 'onion']))!;
      expect(
        result.explanation,
        'You have 5 of 7 ingredients. Missing: Matar, Tomato.',
      );
    });

    test('Use it up names the expiring ingredient', () {
      final result = score(
        'palak_paneer',
        pantry: [
          have('palak', expiresOn: daysAfter(weekdayDinner, 2)),
          ...haveAll(_palakPaneerPantry.skip(1).toList()),
        ],
      )!;
      expect(
        result.explanation,
        'Uses your Palak before it spoils. Nothing missing.',
      );
    });

    test('Use it up with gaps says how many are missing', () {
      final result = score(
        'palak_paneer',
        pantry: [
          have('palak', expiresOn: weekdayDinner),
          ...haveAll(['paneer', 'onion']),
        ],
      )!;
      expect(
        result.explanation,
        'Uses your Palak before it spoils. Missing 2.',
      );
    });

    test(
      'Use it up says how many days are left (spec wording)',
      () {
        // Spec section 5/6: "Uses your matar (2 days left). Nothing missing."
        final result = score(
          'palak_paneer',
          pantry: [
            have('palak', expiresOn: daysAfter(weekdayDinner, 2)),
            ...haveAll(_palakPaneerPantry.skip(1).toList()),
          ],
        )!;
        expect(result.explanation, contains('(2 days left)'));
      },
      skip:
          'BUG: kitchen_ranker.dart:141 — Use-it-up text says "before it '
          'spoils" but never says when; spec wants "(2 days left)" / '
          '"(today)".',
    );

    test('every tier yields a non-empty explanation', () {
      final context = contextFor(
        now: weekdayDinner,
        pantry: [
          have('palak', expiresOn: weekdayDinner),
          ...haveAll(['paneer', 'potato', 'matar', 'onion', 'tomato']),
        ],
        mealType: MealType.dinner,
      );
      final scored = [for (final r in recipes) ?ranker.score(r, context)];
      expect(scored, isNotEmpty);
      for (final s in scored) {
        expect(s.explanation.trim(), isNotEmpty, reason: s.recipe.id);
      }
    });
  });

  group('deck ordering', () {
    test('Use it up first, then Ready now, then Missing 1, then Missing 2', () {
      final context = contextFor(
        now: weekdayDinner,
        pantry: [
          have('palak', expiresOn: daysAfter(weekdayDinner, 1)),
          ...haveAll([
            'paneer',
            'onion',
            'ginger_garlic',
            'kasuri_methi',
            'potato',
            'matar',
            'tomato',
          ]),
        ],
        mealType: MealType.dinner,
      );
      final deck = deckFor(context, ranker);
      expect(tiersOf(deck), [
        RecipeTier.useItUp,
        RecipeTier.readyNow,
        RecipeTier.missing1,
        RecipeTier.missing1,
        RecipeTier.missing2,
        RecipeTier.missing2,
      ]);
      expect(idsOf(deck).take(2), ['palak_paneer', 'aloo_matar']);
    });

    test('a low-scoring Ready now card still beats a Missing 1 card', () {
      // Left-swiped 5 days ago (−0.25) and cooked 2 days ago (−0.30).
      final context = contextFor(
        now: weekdayDinner,
        pantry: haveAll(_alooMatarPantry),
        events: [left('aloo_matar', daysBefore(weekdayDinner, 5))],
        meals: [cooked('aloo_matar', daysBefore(weekdayDinner, 2))],
        mealType: MealType.dinner,
      );
      final deck = deckFor(context, ranker);
      expect(deck.first.recipe.id, 'aloo_matar');
      expect(deck.first.score, lessThan(deck[1].score));
    });
  });
}
