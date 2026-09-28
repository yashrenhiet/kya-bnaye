import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'seed_fixtures.dart';
import 'seed_validator_helpers.dart';

/// Targets every bundle meets; each test tightens exactly one of them.
const _permissive = SeedCoverageTargets(
  minRecipes: 0,
  maxRecipes: 1000,
  minIngredients: 0,
  maxIngredients: 1000,
  minRecipesPerMealType: {},
  minRecipesPerRegion: {},
  minRecipesPerDishType: 0,
  minRecipesPerBase: {},
  maxBaseShare: 1,
  minHeavinessShare: 0,
  minQuickShare: 0,
  minNonVegShare: 0,
  maxNonVegShare: 1,
  minPaneerRecipes: 0,
  minDalLegumeRecipes: 0,
);

List<SeedIssue> _coverage(SeedCoverageTargets targets, [SeedBundle? bundle]) =>
    const SeedValidator().validate(
      bundle ?? bundleOf(),
      assetExists: (_) => true,
      coverage: targets,
    );

// The fixture: 5 recipes, 21 ingredients, all north/medium/30 min; bases
// roti 2, rice 2, bread 1; proteins vegOnly 2, dalLegume, paneer, egg.
void main() {
  test('defaults match the M2 plan', () {
    const t = SeedCoverageTargets();
    expect([t.minRecipes, t.maxRecipes], [75, 90]);
    expect([t.minIngredients, t.maxIngredients], [220, 280]);
    expect(t.minRecipesPerMealType, {
      MealType.breakfast: 15,
      MealType.lunch: 35,
      MealType.dinner: 35,
      MealType.snack: 12,
    });
    expect(t.minRecipesPerRegion.keys, unorderedEquals(Region.values));
    expect(t.minRecipesPerRegion[Region.north], 8);
    expect(t.minRecipesPerRegion[Region.continental], 1);
    expect(t.minRecipesPerDishType, 3);
    expect(t.dishTypeExemptions, isEmpty);
    expect(t.minRecipesPerBase, {
      DishBase.rice: 12,
      DishBase.roti: 15,
      DishBase.bread: 4,
      DishBase.none: 12,
    });
    expect(t.maxBaseShare, 0.45);
    expect(t.minHeavinessShare, 0.15);
    expect([t.quickMaxMinutes, t.minQuickShare], [30, 0.35]);
    expect([t.minNonVegShare, t.maxNonVegShare], [0.08, 0.15]);
    expect([t.minPaneerRecipes, t.minDalLegumeRecipes], [5, 10]);
    expect(t.minKitchenCandidatesPerMealType, 5);
  });

  test('coverage is only checked when targets are given', () {
    final issues = const SeedValidator().validate(
      bundleOf(),
      assetExists: (_) => true,
    );
    expect(issues, isEmpty);
    expect(_coverage(const SeedCoverageTargets()), isNotEmpty);
  });

  test('permissive targets pass the fixture', () {
    expect(_coverage(_permissive), isEmpty);
  });

  test('recipe and ingredient totals', () {
    const t = SeedCoverageTargets(
      minRecipes: 6,
      maxRecipes: 10,
      minIngredients: 1,
      maxIngredients: 20,
      minRecipesPerMealType: {},
      minRecipesPerRegion: {},
      minRecipesPerDishType: 0,
      minRecipesPerBase: {},
      maxBaseShare: 1,
      minHeavinessShare: 0,
      minQuickShare: 0,
      minNonVegShare: 0,
      maxNonVegShare: 1,
      minPaneerRecipes: 0,
      minDalLegumeRecipes: 0,
    );
    expect(_coverage(t), [
      issueMatching(
        SeedIssueCode.coverageTotals,
        'recipes',
        '5 recipes; expected 6–10',
      ),
      issueMatching(
        SeedIssueCode.coverageTotals,
        'ingredients',
        '21 ingredients; expected 1–20',
      ),
    ]);
  });

  test('recipes per meal type', () {
    expect(
      _coverage(_with(mealTypes: {MealType.breakfast: 2, MealType.lunch: 4})),
      [
        issueMatching(
          SeedIssueCode.coverageMealTypes,
          'mealTypes.breakfast',
          '1 recipe; expected at least 2',
        ),
      ],
    );
  });

  test('recipes per region', () {
    expect(_coverage(_with(regions: {Region.south: 1, Region.north: 5})), [
      issueMatching(
        SeedIssueCode.coverageRegions,
        'region.south',
        '0 recipes; expected at least 1',
      ),
    ]);
  });

  group('recipes per dish type', () {
    test('every dish type needs the minimum', () {
      final issues = _coverage(_with(perDishType: 1));
      expect(issues.map((i) => i.location), [
        'dishType.bread',
        'dishType.snack',
        'dishType.sweet',
        'dishType.onePot',
      ]);
      expect(issueCodes(issues), {SeedIssueCode.coverageDishTypes});
    });

    test('exempt dish types are skipped', () {
      final issues = _coverage(
        _with(
          perDishType: 1,
          dishTypeExemptions: {
            DishType.bread,
            DishType.snack,
            DishType.sweet,
            DishType.onePot,
          },
        ),
      );
      expect(issues, isEmpty);
    });
  });

  group('bases', () {
    test('minimum per base', () {
      expect(_coverage(_with(bases: {DishBase.none: 1, DishBase.rice: 2})), [
        issueMatching(
          SeedIssueCode.coverageBases,
          'base.none',
          '0 recipes; expected at least 1',
        ),
      ]);
    });

    test('no base may exceed the maximum share', () {
      expect(_coverage(_with(maxBaseShare: 0.3)), [
        issueMatching(
          SeedIssueCode.coverageBases,
          'base.rice',
          '40.0% of recipes; at most 30.0%',
        ),
        issueMatching(
          SeedIssueCode.coverageBases,
          'base.roti',
          '40.0% of recipes; at most 30.0%',
        ),
      ]);
    });
  });

  test('each heaviness needs its share', () {
    expect(_coverage(_with(heavinessShare: 0.15)), [
      issueMatching(
        SeedIssueCode.coverageHeaviness,
        'heaviness.light',
        '0.0% of recipes; expected at least 15.0%',
      ),
      issueMatching(
        SeedIssueCode.coverageHeaviness,
        'heaviness.heavy',
        '0.0% of recipes; expected at least 15.0%',
      ),
    ]);
  });

  test('quick recipes share, using the quick threshold', () {
    expect(_coverage(_with(quickShare: 1)), isEmpty); // all take 30 min
    expect(_coverage(_with(quickShare: 0.35, quickMaxMinutes: 29)), [
      issueMatching(
        SeedIssueCode.coverageQuick,
        'quick (≤ 29 min)',
        '0.0% of recipes; expected at least 35.0%',
      ),
    ]);
  });

  group('protein', () {
    test('non-veg share must sit inside its band', () {
      final expected = [
        issueMatching(
          SeedIssueCode.coverageProtein,
          'protein.nonVeg',
          '20.0% of recipes; expected 8.0%–15.0%',
        ),
      ];
      expect(_coverage(_with(nonVeg: (0.08, 0.15))), expected);
      expect(_coverage(_with(nonVeg: (0.2, 0.2))), isEmpty);
      expect(_coverage(_with(nonVeg: (0.25, 1))), [
        issueMatching(
          SeedIssueCode.coverageProtein,
          'protein.nonVeg',
          '20.0% of recipes; expected 25.0%–100.0%',
        ),
      ]);
    });

    test('paneer and dal/legume minimums', () {
      expect(_coverage(_with(paneer: 2, dalLegume: 2)), [
        issueMatching(
          SeedIssueCode.coverageProtein,
          'protein.paneer',
          '1 recipe; expected at least 2',
        ),
        issueMatching(
          SeedIssueCode.coverageProtein,
          'protein.dalLegume',
          '1 recipe; expected at least 2',
        ),
      ]);
    });
  });

  test('an empty catalogue reports misses without dividing by zero', () {
    final issues = _coverage(
      const SeedCoverageTargets(),
      bundleOf(ingredients: const [], recipes: const []),
    );
    expect(
      issues,
      contains(
        issueMatching(
          SeedIssueCode.coverageTotals,
          'recipes',
          '0 recipes; expected 75–90',
        ),
      ),
    );
    expect(
      issues,
      contains(
        issueMatching(
          SeedIssueCode.coverageHeaviness,
          'heaviness.light',
          '0.0% of recipes; expected at least 15.0%',
        ),
      ),
    );
    expect(
      issues.where((i) => i.code == SeedIssueCode.coverageBases),
      hasLength(DishBase.values.length),
    );
  });

  group('kitchenCandidateCounts', () {
    final now = DateTime.utc(2026, 9, 26, 12);

    test('staples alone unlock recipes missing at most two items', () {
      // aloo_sabzi, dal_chawal and paneer_bhurji miss 2, jeera_rice 1;
      // anda_bhurji misses 3 (eggs, onion, bread) so it is dropped.
      expect(kitchenCandidateCounts(bundleOf(), atHome: {}, now: now), {
        MealType.breakfast: 0,
        MealType.lunch: 4,
        MealType.dinner: 4,
        MealType.snack: 0,
      });
    });

    test('pantry items count as available; unknown ids are harmless', () {
      final counts = kitchenCandidateCounts(
        bundleOf(),
        atHome: {'eggs', 'no_such_thing'},
        now: now,
      );
      expect(counts[MealType.breakfast], 1);
    });

    test('an empty catalogue yields zero for every meal type', () {
      final counts = kitchenCandidateCounts(
        bundleOf(ingredients: const [], recipes: const []),
        atHome: {'eggs'},
        now: now,
      );
      expect(counts, {for (final m in MealType.values) m: 0});
    });
  });
}

/// [_permissive] with one dimension tightened.
SeedCoverageTargets _with({
  Map<MealType, int> mealTypes = const {},
  Map<Region, int> regions = const {},
  int perDishType = 0,
  Set<DishType> dishTypeExemptions = const {},
  Map<DishBase, int> bases = const {},
  double maxBaseShare = 1,
  double heavinessShare = 0,
  double quickShare = 0,
  int quickMaxMinutes = 30,
  (double, double) nonVeg = (0, 1),
  int paneer = 0,
  int dalLegume = 0,
}) => SeedCoverageTargets(
  minRecipes: _permissive.minRecipes,
  maxRecipes: _permissive.maxRecipes,
  minIngredients: _permissive.minIngredients,
  maxIngredients: _permissive.maxIngredients,
  minRecipesPerMealType: mealTypes,
  minRecipesPerRegion: regions,
  minRecipesPerDishType: perDishType,
  dishTypeExemptions: dishTypeExemptions,
  minRecipesPerBase: bases,
  maxBaseShare: maxBaseShare,
  minHeavinessShare: heavinessShare,
  quickMaxMinutes: quickMaxMinutes,
  minQuickShare: quickShare,
  minNonVegShare: nonVeg.$1,
  maxNonVegShare: nonVeg.$2,
  minPaneerRecipes: paneer,
  minDalLegumeRecipes: dalLegume,
);
