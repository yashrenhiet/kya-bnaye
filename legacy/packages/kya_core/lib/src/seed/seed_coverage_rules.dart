/// Coverage checks for `SeedValidator`. Internal (not exported).
library;

import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/seed/seed_coverage_targets.dart';
import 'package:kya_core/src/seed/seed_issue.dart';
import 'package:kya_core/src/seed/seed_manifest.dart';

const Set<Protein> _nonVeg = {
  Protein.chicken,
  Protein.mutton,
  Protein.fish,
  Protein.egg,
};

/// Reports every coverage target in [t] that [bundle] misses.
void checkCoverage(
  SeedBundle bundle,
  SeedCoverageTargets t,
  void Function(SeedIssue) report,
) {
  final recipes = bundle.recipes;
  final total = recipes.length;
  double share(int count) => total == 0 ? 0 : count / total;
  String pct(double fraction) => '${(fraction * 100).toStringAsFixed(1)}%';
  int count(bool Function(Recipe) test) => recipes.where(test).length;

  void range(SeedIssueCode code, String what, int n, int min, int max) {
    if (n < min || n > max) {
      report(SeedIssue(code, what, '$n $what; expected $min–$max'));
    }
  }

  void atLeast(SeedIssueCode code, String what, int n, int min) {
    if (n < min) {
      final noun = n == 1 ? 'recipe' : 'recipes';
      report(SeedIssue(code, what, '$n $noun; expected at least $min'));
    }
  }

  range(
    SeedIssueCode.coverageTotals,
    'recipes',
    total,
    t.minRecipes,
    t.maxRecipes,
  );
  range(
    SeedIssueCode.coverageTotals,
    'ingredients',
    bundle.ingredients.length,
    t.minIngredients,
    t.maxIngredients,
  );
  for (final MapEntry(key: meal, value: min)
      in t.minRecipesPerMealType.entries) {
    atLeast(
      SeedIssueCode.coverageMealTypes,
      'mealTypes.${meal.name}',
      count((r) => r.mealTypes.contains(meal)),
      min,
    );
  }
  for (final MapEntry(key: region, value: min)
      in t.minRecipesPerRegion.entries) {
    atLeast(
      SeedIssueCode.coverageRegions,
      'region.${region.name}',
      count((r) => r.tags.region == region),
      min,
    );
  }
  for (final type in DishType.values) {
    if (t.dishTypeExemptions.contains(type)) continue;
    atLeast(
      SeedIssueCode.coverageDishTypes,
      'dishType.${type.name}',
      count((r) => r.tags.dishType == type),
      t.minRecipesPerDishType,
    );
  }
  for (final base in DishBase.values) {
    final n = count((r) => r.base == base);
    atLeast(
      SeedIssueCode.coverageBases,
      'base.${base.name}',
      n,
      t.minRecipesPerBase[base] ?? 0,
    );
    if (share(n) > t.maxBaseShare) {
      report(
        SeedIssue(
          SeedIssueCode.coverageBases,
          'base.${base.name}',
          '${pct(share(n))} of recipes; at most ${pct(t.maxBaseShare)}',
        ),
      );
    }
  }

  void minShare(SeedIssueCode code, String what, int n, double min) {
    if (share(n) < min) {
      report(
        SeedIssue(
          code,
          what,
          '${pct(share(n))} of recipes; expected at least ${pct(min)}',
        ),
      );
    }
  }

  for (final h in Heaviness.values) {
    minShare(
      SeedIssueCode.coverageHeaviness,
      'heaviness.${h.name}',
      count((r) => r.tags.heaviness == h),
      t.minHeavinessShare,
    );
  }
  minShare(
    SeedIssueCode.coverageQuick,
    'quick (≤ ${t.quickMaxMinutes} min)',
    count((r) => r.minutes <= t.quickMaxMinutes),
    t.minQuickShare,
  );
  final nonVeg = share(count((r) => _nonVeg.contains(r.tags.protein)));
  if (nonVeg < t.minNonVegShare || nonVeg > t.maxNonVegShare) {
    report(
      SeedIssue(
        SeedIssueCode.coverageProtein,
        'protein.nonVeg',
        '${pct(nonVeg)} of recipes; expected '
            '${pct(t.minNonVegShare)}–${pct(t.maxNonVegShare)}',
      ),
    );
  }
  atLeast(
    SeedIssueCode.coverageProtein,
    'protein.paneer',
    count((r) => r.tags.protein == Protein.paneer),
    t.minPaneerRecipes,
  );
  atLeast(
    SeedIssueCode.coverageProtein,
    'protein.dalLegume',
    count((r) => r.tags.protein == Protein.dalLegume),
    t.minDalLegumeRecipes,
  );
}
