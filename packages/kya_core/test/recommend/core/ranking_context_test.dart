import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const double eps = 1e-9;

final List<Ingredient> catalog = [
  ingredient('paneer', IngredientRole.core),
  ingredient('tomato', IngredientRole.core),
  ingredient('onion', IngredientRole.core),
  ingredient('masala', IngredientRole.flavor),
  ingredient('salt', IngredientRole.staple),
  ingredient('ghee', IngredientRole.staple),
  ingredient('haldi', IngredientRole.staple),
  ingredient('dhania', IngredientRole.optional),
];

final Recipe paneerMasala = recipe(
  'paneer_masala',
  ingredients: [
    uses('paneer'),
    uses('masala'),
    uses('salt'),
    uses('dhania', optional: true),
  ],
);
final Recipe paneerBhurji = recipe(
  'paneer_bhurji',
  base: DishBase.bread,
  ingredients: [uses('paneer'), uses('salt'), uses('onion', optional: true)],
);
final Recipe jeeraRice = recipe(
  'jeera_rice',
  base: DishBase.rice,
  tags: otherTags,
  // Role "optional" and unknown ids never count toward rarity frequency.
  ingredients: [uses('dhania'), uses('mystery')],
);
final List<Recipe> allRecipes = [paneerMasala, paneerBhurji, jeeraRice];

RankingContext build({
  List<Recipe>? recipes,
  List<PantryItem> pantry = const [],
  List<SwipeEvent> events = const [],
  List<MealLog> meals = const [],
  DateTime? now,
  MealType? mealType,
  ScoringConfig config = const ScoringConfig(),
}) => RankingContext.build(
  allRecipes: recipes ?? allRecipes,
  pantry: pantry,
  catalog: catalog,
  events: events,
  mealLogs: meals,
  now: now ?? refNow,
  config: config,
  currentMealType: mealType,
);

void main() {
  group('RankingContext.build with empty inputs', () {
    test('produces empty precomputations, never nulls', () {
      final ctx = RankingContext.build(
        allRecipes: const [],
        pantry: const [],
        catalog: const [],
        events: const [],
        mealLogs: const [],
        now: refNow,
      );
      expect(ctx.pantry, isEmpty);
      expect(ctx.ingredientsById, isEmpty);
      expect(ctx.recipesById, isEmpty);
      expect(ctx.ingredientFrequency, isEmpty);
      expect(ctx.totalRecipesForFrequency, 0);
      expect(ctx.lastCookedAtByRecipe, isEmpty);
      expect(ctx.cookCountInRutWindowByRecipe, isEmpty);
      expect(ctx.lastLeftSwipeAtByRecipe, isEmpty);
      expect(ctx.neverShownRecipeIds, isEmpty);
      expect(ctx.recentlyLikedRecipeIdsDesc, isEmpty);
      expect(ctx.lastCookedBase, isNull);
      expect(ctx.tasteProfile.affinity, isEmpty);
      expect(ctx.now, refNow);
      expect(ctx.currentMealType, MealType.lunch); // 12:00
    });

    test('with no recipes rarity is 0 and weight is the bare role weight', () {
      final ctx = build(recipes: const []);
      expect(ctx.rarityBonus('paneer'), 0);
      expect(ctx.ingredientWeight('paneer'), closeTo(2.4, eps));
      expect(ctx.ingredientWeight('mystery'), 0);
    });
  });

  group('lookups', () {
    test('indexes pantry, catalog and recipes by id', () {
      final ctx = build(pantry: [stock('paneer', StockLevel.low)]);
      expect(ctx.pantry.keys, ['paneer']);
      expect(ctx.pantry['paneer']!.level, StockLevel.low);
      expect(ctx.ingredientsById.length, catalog.length);
      expect(
        ctx.recipesById.keys,
        unorderedEquals(allRecipes.map((r) => r.id)),
      );
      expect(ctx.recipesById['jeera_rice'], same(jeeraRice));
    });
  });

  group('ingredient frequency and rarity (RECOMMENDER.md 5)', () {
    test('counts only required core/flavor ingredients', () {
      final ctx = build();
      expect(ctx.ingredientFrequency, {'paneer': 2, 'masala': 1});
      expect(ctx.totalRecipesForFrequency, 3);
    });

    test('rarityBonus = 0.6 * (1 - frequency / total)', () {
      final ctx = build();
      expect(ctx.rarityBonus('paneer'), closeTo(0.6 * (1 - 2 / 3), eps));
      expect(ctx.rarityBonus('masala'), closeTo(0.6 * (1 - 1 / 3), eps));
      expect(ctx.rarityBonus('salt'), closeTo(0.6, eps));
      expect(ctx.rarityBonus('unknown'), closeTo(0.6, eps));
    });

    test('an ingredient every recipe needs gets no bonus', () {
      final ctx = build(recipes: [paneerMasala, paneerBhurji]);
      expect(ctx.rarityBonus('paneer'), closeTo(0, eps));
    });

    test('ingredientWeight = roleWeight + rarityBonus; unknown -> 0', () {
      final ctx = build();
      expect(ctx.ingredientWeight('paneer'), closeTo(2.4 + 0.2, eps));
      expect(ctx.ingredientWeight('masala'), closeTo(1.2 + 0.4, eps));
      expect(ctx.ingredientWeight('salt'), closeTo(0.25 + 0.6, eps));
      expect(ctx.ingredientWeight('dhania'), closeTo(0.7 + 0.6, eps));
      expect(ctx.ingredientWeight('mystery'), 0);
    });
  });

  group('isIngredientAvailable', () {
    final ctx = build(
      pantry: [
        stock('paneer', StockLevel.plenty),
        stock('masala', StockLevel.low),
        stock('tomato', StockLevel.out),
        stock('ghee', StockLevel.out),
        stock('haldi', StockLevel.low),
        stock('mystery', StockLevel.plenty),
      ],
    );

    test('non-staples need a not-out pantry record', () {
      expect(ctx.isIngredientAvailable('paneer'), isTrue);
      expect(ctx.isIngredientAvailable('masala'), isTrue, reason: 'low');
      expect(ctx.isIngredientAvailable('tomato'), isFalse, reason: 'out');
      expect(ctx.isIngredientAvailable('onion'), isFalse, reason: 'none');
      expect(ctx.isIngredientAvailable('dhania'), isFalse, reason: 'none');
    });

    test('staples are assumed present unless explicitly Out', () {
      expect(ctx.isIngredientAvailable('salt'), isTrue, reason: 'no record');
      expect(ctx.isIngredientAvailable('haldi'), isTrue, reason: 'low');
      expect(ctx.isIngredientAvailable('ghee'), isFalse, reason: 'out');
    });

    test('ingredients missing from the catalog follow the non-staple rule', () {
      expect(ctx.isIngredientAvailable('mystery'), isTrue);
      expect(ctx.isIngredientAvailable('dragonfruit'), isFalse);
    });

    test('empty pantry: only staples are available', () {
      final empty = build();
      expect(empty.isIngredientAvailable('salt'), isTrue);
      expect(empty.isIngredientAvailable('paneer'), isFalse);
    });
  });

  group('cook history precomputation', () {
    test('last cooked is the latest cook per recipe, input order agnostic', () {
      final ctx = build(
        meals: [
          cooked('m1', paneerMasala.id, daysAgo(10)),
          cooked('m2', paneerMasala.id, daysAgo(3)),
          cooked('m3', paneerMasala.id, daysAgo(100)),
          cooked('m4', paneerBhurji.id, daysAgo(40)),
        ],
      );
      expect(ctx.lastCookedAtByRecipe, {
        paneerMasala.id: daysAgo(3),
        paneerBhurji.id: daysAgo(40),
      });
    });

    test('rut count includes cooks up to 90 days back, not 91', () {
      final ctx = build(
        meals: [
          cooked('m1', paneerMasala.id, daysAgo(3)),
          cooked('m2', paneerMasala.id, daysAgo(10)),
          cooked('m3', paneerMasala.id, daysAgo(90)),
          cooked('m4', paneerMasala.id, daysAgo(91)),
          cooked('m5', paneerBhurji.id, daysAgo(200)),
        ],
      );
      expect(ctx.cookCountInRutWindowByRecipe, {paneerMasala.id: 3});
      expect(ctx.lastCookedAtByRecipe[paneerBhurji.id], daysAgo(200));
    });

    test('rut window follows the config', () {
      final ctx = build(
        meals: [
          cooked('m1', paneerMasala.id, daysAgo(3)),
          cooked('m2', paneerMasala.id, daysAgo(10)),
        ],
        config: const ScoringConfig(repeatRutWindowDays: 5),
      );
      expect(ctx.cookCountInRutWindowByRecipe, {paneerMasala.id: 1});
    });

    test('context feeds Penalties.repeatPenalty with the rut top-up', () {
      final ctx = build(
        meals: [
          cooked('m1', paneerMasala.id, daysAgo(20)),
          cooked('m2', paneerMasala.id, daysAgo(50)),
          cooked('m3', paneerMasala.id, daysAgo(80)),
        ],
      );
      final penalty = Penalties.repeatPenalty(
        lastCookedAt: ctx.lastCookedAtByRecipe[paneerMasala.id],
        cookCountInRutWindow:
            ctx.cookCountInRutWindowByRecipe[paneerMasala.id] ?? 0,
        now: ctx.now,
        config: ctx.config,
      );
      expect(penalty, closeTo(0.10 + 2 * 0.02, eps));
    });

    test('lastCookedBase is the base of the most recent cook overall', () {
      final ctx = build(
        meals: [
          cooked('m1', paneerMasala.id, daysAgo(3)),
          cooked('m2', jeeraRice.id, daysAgo(1)),
          cooked('m3', paneerBhurji.id, daysAgo(2)),
        ],
      );
      expect(ctx.lastCookedBase, DishBase.rice);
    });

    test('lastCookedBase is null when the latest cook is a deleted recipe', () {
      final ctx = build(
        meals: [
          cooked('m1', jeeraRice.id, daysAgo(2)),
          cooked('m2', 'deleted', daysAgo(1)),
        ],
      );
      expect(ctx.lastCookedBase, isNull);
      expect(ctx.lastCookedAtByRecipe['deleted'], daysAgo(1));
    });

    test('a future-dated cook (clock skew) is treated as the latest', () {
      final future = refNow.add(const Duration(days: 2));
      final ctx = build(
        meals: [
          cooked('m1', paneerMasala.id, daysAgo(1)),
          cooked('m2', paneerMasala.id, future),
        ],
      );
      expect(ctx.lastCookedAtByRecipe[paneerMasala.id], future);
    });
  });

  group('swipe history precomputation', () {
    test('last left swipe per recipe, ignoring undone swipes', () {
      final ctx = build(
        events: [
          swipe('e1', paneerMasala.id, SwipeAction.left, daysAgo(20)),
          swipe('e2', paneerMasala.id, SwipeAction.left, daysAgo(5)),
          swipe('e3', paneerMasala.id, SwipeAction.left, daysAgo(1)),
          undo('u3', 'e3', daysAgo(1)),
          swipe('e4', paneerBhurji.id, SwipeAction.right, daysAgo(1)),
        ],
      );
      expect(ctx.lastLeftSwipeAtByRecipe, {paneerMasala.id: daysAgo(5)});
    });

    test('left swipe older than every window is still recorded', () {
      final ctx = build(
        events: [swipe('e1', jeeraRice.id, SwipeAction.left, daysAgo(400))],
      );
      expect(ctx.lastLeftSwipeAtByRecipe[jeeraRice.id], daysAgo(400));
      final penalty = Penalties.rejectPenalty(
        lastLeftSwipeAt: ctx.lastLeftSwipeAtByRecipe[jeeraRice.id],
        now: ctx.now,
        config: ctx.config,
      );
      expect(penalty, 0);
    });

    test('never-show ids exclude undone never-shows', () {
      final ctx = build(
        events: [
          swipe('e1', paneerBhurji.id, SwipeAction.neverShow, daysAgo(300)),
          swipe('e2', jeeraRice.id, SwipeAction.neverShow, daysAgo(1)),
          undo('u2', 'e2', daysAgo(1)),
          swipe('e3', paneerMasala.id, SwipeAction.left, daysAgo(1)),
        ],
      );
      expect(ctx.neverShownRecipeIds, {paneerBhurji.id});
    });

    test('never-show has no expiry', () {
      final ctx = build(
        events: [
          swipe('e1', paneerBhurji.id, SwipeAction.neverShow, daysAgo(3650)),
        ],
      );
      expect(ctx.neverShownRecipeIds, contains(paneerBhurji.id));
    });
  });

  group('recently liked (RECOMMENDER.md 6)', () {
    test('right swipes and cooks within 60 days, deduped, newest first', () {
      final ctx = build(
        events: [
          swipe('e1', jeeraRice.id, SwipeAction.right, daysAgo(2)),
          swipe('e2', paneerMasala.id, SwipeAction.right, daysAgo(70)),
          swipe('e3', paneerBhurji.id, SwipeAction.right, daysAgo(10)),
          swipe('e4', paneerBhurji.id, SwipeAction.right, daysAgo(30)),
          swipe('e5', 'left_only', SwipeAction.left, daysAgo(1)),
          swipe('e6', 'never', SwipeAction.neverShow, daysAgo(1)),
          swipe('e7', 'undone', SwipeAction.right, refNow),
          undo('u7', 'e7', refNow),
        ],
        meals: [
          cooked('m1', paneerMasala.id, daysAgo(3)),
          cooked('m2', paneerBhurji.id, daysAgo(59)),
        ],
      );
      expect(ctx.recentlyLikedRecipeIdsDesc, [
        jeeraRice.id,
        paneerMasala.id,
        paneerBhurji.id,
      ]);
    });

    test('60 days back is included, 61 is not', () {
      final ctx = build(
        events: [swipe('e1', jeeraRice.id, SwipeAction.right, daysAgo(60))],
        meals: [cooked('m1', paneerMasala.id, daysAgo(61))],
      );
      expect(ctx.recentlyLikedRecipeIdsDesc, [jeeraRice.id]);
    });

    test('a cook newer than a swipe of the same recipe moves it up', () {
      final ctx = build(
        events: [
          swipe('e1', paneerMasala.id, SwipeAction.right, daysAgo(20)),
          swipe('e2', jeeraRice.id, SwipeAction.right, daysAgo(10)),
        ],
        meals: [cooked('m1', paneerMasala.id, daysAgo(1))],
      );
      expect(ctx.recentlyLikedRecipeIdsDesc, [paneerMasala.id, jeeraRice.id]);
    });
  });

  group('taste profile wiring', () {
    test('matches profileFrom over the same history', () {
      final events = [
        swipe('e1', paneerMasala.id, SwipeAction.right, daysAgo(4)),
        swipe('e2', jeeraRice.id, SwipeAction.left, daysAgo(1)),
      ];
      final meals = [cooked('m1', paneerBhurji.id, daysAgo(12))];
      final ctx = build(events: events, meals: meals);
      final direct = profileFrom(
        events: events,
        mealLogs: meals,
        recipesById: {for (final r in allRecipes) r.id: r},
        now: refNow,
      );
      expect(ctx.tasteProfile.affinity.length, direct.affinity.length);
      for (final MapEntry(:key, :value) in direct.affinity.entries) {
        expect(ctx.tasteProfile.affinity[key], closeTo(value, eps));
        expect(
          ctx.tasteProfile.evidenceFor(key),
          closeTo(direct.evidenceFor(key), eps),
        );
      }
    });

    test('passes the same config through to the profile', () {
      const custom = ScoringConfig(signalWeightRightSwipe: 2);
      final ctx = build(
        events: [swipe('e1', paneerMasala.id, SwipeAction.right, refNow)],
        config: custom,
      );
      expect(ctx.config, same(custom));
      expect(ctx.tasteProfile.config, same(custom));
      expect(
        ctx.tasteProfile.affinity[TagKey.region('north')],
        closeTo(2, eps),
      );
    });
  });

  group('meal slot', () {
    test('explicit currentMealType overrides the clock', () {
      final ctx = build(
        now: DateTime(2026, 9, 26, 8),
        mealType: MealType.dinner,
      );
      expect(ctx.currentMealType, MealType.dinner);
    });

    test('defaults to the slot for the hour of now', () {
      expect(
        build(now: DateTime(2026, 9, 26, 7)).currentMealType,
        MealType.breakfast,
      );
      expect(
        build(now: DateTime(2026, 9, 26, 20)).currentMealType,
        MealType.dinner,
      );
    });

    const boundaries = <int, MealType>{
      0: MealType.dinner,
      4: MealType.dinner,
      5: MealType.breakfast,
      10: MealType.breakfast,
      11: MealType.lunch,
      15: MealType.lunch,
      16: MealType.snack,
      18: MealType.snack,
      19: MealType.dinner,
      23: MealType.dinner,
    };
    for (final MapEntry(key: hour, value: slot) in boundaries.entries) {
      test('mealTypeForHour($hour) -> ${slot.name}', () {
        expect(mealTypeForHour(hour), slot);
      });
    }

    test('recipes can be filtered to the current slot', () {
      final breakfastOnly = recipe(
        'poha',
        mealTypes: const {MealType.breakfast, MealType.snack},
      );
      final ctx = build(
        recipes: [...allRecipes, breakfastOnly],
        now: DateTime(2026, 9, 26, 17),
      );
      final eligible = ctx.recipesById.values
          .where((r) => r.mealTypes.contains(ctx.currentMealType))
          .map((r) => r.id);
      expect(eligible, [breakfastOnly.id]);
    });
  });
}
