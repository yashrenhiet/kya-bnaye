/// Recipe rules R1–R11 for `SeedValidator`. Internal (not exported).
library;

import 'package:kya_core/src/catalog/ingredient_normalizer.dart';
import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/seed/seed_issue.dart';
import 'package:kya_core/src/seed/seed_manifest.dart';

/// Recipe id format (R1); the same as for ingredient ids.
final RegExp _idPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Allowed `minutes` range (R3), inclusive.
const int minRecipeMinutes = 1;

/// See [minRecipeMinutes].
const int maxRecipeMinutes = 240;

/// Allowed step count (R4), inclusive.
const int minRecipeSteps = 2;

/// See [minRecipeSteps].
const int maxRecipeSteps = 12;

/// Longest allowed step text (R4).
const int maxStepLength = 200;

/// Most required ingredients a user may have to shop for (R7).
const int maxShoppableIngredients = 8;

/// Folder every seed recipe image lives in (R9).
const String seedImageDir = 'assets/seed/images';

/// Ingredient ids that make a dish carry a given protein tag (R11).
const Map<Protein, Set<String>> proteinIngredientIds = {
  Protein.paneer: {'paneer'},
  Protein.egg: {'eggs'},
  Protein.chicken: {'chicken'},
  Protein.mutton: {'mutton'},
  Protein.fish: {'fish', 'prawns'},
};

/// Reports every R1–R11 issue in [bundle].
void checkRecipeRules(
  SeedBundle bundle,
  bool Function(String path) assetExists,
  void Function(SeedIssue) report,
) {
  final catalogue = {for (final i in bundle.ingredients) i.id: i};
  final ids = <String>{};
  final nameOwners = <String, String>{};
  for (final r in bundle.recipes) {
    _RecipeCheck(r, catalogue, report)
      ..identity(ids, nameOwners)
      ..basics()
      ..ingredients()
      ..tags()
      ..image(assetExists);
  }
}

class _RecipeCheck {
  _RecipeCheck(this.r, this.catalogue, this.report);

  final Recipe r;
  final Map<String, Ingredient> catalogue;
  final void Function(SeedIssue) report;

  void issue(SeedIssueCode code, String field, String message) =>
      report(SeedIssue(code, 'recipes[${r.id}]$field', message));

  Iterable<RecipeIngredient> get required => r.requiredIngredients;

  void identity(Set<String> ids, Map<String, String> nameOwners) {
    const code = SeedIssueCode.r1RecipeIdentity;
    if (!_idPattern.hasMatch(r.id)) {
      issue(code, '', 'id must match $_idPattern');
    }
    if (!ids.add(r.id)) issue(code, '', 'duplicate id');
    if (r.name.trim().isEmpty) {
      issue(code, '.name', 'name is blank');
      return;
    }
    if (r.name != r.name.trim()) {
      issue(code, '.name', 'name has surrounding whitespace');
    }
    final owner = nameOwners.putIfAbsent(
      IngredientNormalizer.normalise(r.name),
      () => r.id,
    );
    if (owner != r.id) {
      issue(code, '.name', 'name "${r.name}" is also used by $owner');
    }
  }

  void basics() {
    if (r.mealTypes.isEmpty) {
      issue(SeedIssueCode.r2MealTypes, '.mealTypes', 'no meal types');
    }
    if (r.minutes < minRecipeMinutes || r.minutes > maxRecipeMinutes) {
      issue(
        SeedIssueCode.r3Minutes,
        '.minutes',
        '${r.minutes} is outside $minRecipeMinutes–$maxRecipeMinutes',
      );
    }
    final steps = r.steps.length;
    if (steps < minRecipeSteps || steps > maxRecipeSteps) {
      issue(
        SeedIssueCode.r4Steps,
        '.steps',
        '$steps steps; expected $minRecipeSteps–$maxRecipeSteps',
      );
    }
    for (var n = 0; n < steps; n++) {
      final step = r.steps[n];
      if (step.trim().isEmpty) {
        issue(SeedIssueCode.r4Steps, '.steps[$n]', 'blank step');
      } else if (step.length > maxStepLength) {
        issue(
          SeedIssueCode.r4Steps,
          '.steps[$n]',
          '${step.length} characters; at most $maxStepLength',
        );
      }
    }
  }

  void ingredients() {
    const code = SeedIssueCode.r5Ingredients;
    if (r.ingredients.isEmpty) issue(code, '.ingredients', 'no ingredients');
    final seen = <String>{};
    for (var n = 0; n < r.ingredients.length; n++) {
      final line = r.ingredients[n];
      final field = '.ingredients[$n]';
      if (!catalogue.containsKey(line.ingredientId)) {
        issue(code, field, 'unknown ingredient "${line.ingredientId}"');
      }
      if (!seen.add(line.ingredientId)) {
        issue(code, field, 'ingredient "${line.ingredientId}" is repeated');
      }
      if (line.quantityText.trim().isEmpty) {
        issue(code, field, 'blank quantityText');
      }
    }
    final roles = [for (final ri in required) catalogue[ri.ingredientId]?.role];
    if (!roles.contains(IngredientRole.core)) {
      issue(
        SeedIssueCode.r6CoreIngredient,
        '.ingredients',
        'no required ingredient has the core role',
      );
    }
    final shoppable = roles
        .where(
          (role) =>
              role == IngredientRole.core || role == IngredientRole.flavor,
        )
        .length;
    if (shoppable > maxShoppableIngredients) {
      issue(
        SeedIssueCode.r7RequiredCount,
        '.ingredients',
        '$shoppable required core/flavor ingredients; at most '
            '$maxShoppableIngredients',
      );
    }
  }

  void tags() {
    final t = r.tags;
    if (t.flavours.isEmpty) {
      issue(SeedIssueCode.r8Flavours, '.tags.flavours', 'no flavours');
    } else if (t.flavours.containsAll(const {Flavour.mild, Flavour.spicy})) {
      issue(
        SeedIssueCode.r8Flavours,
        '.tags.flavours',
        'a dish cannot be both mild and spicy',
      );
    }
    final allowedBases = switch (t.dishType) {
      DishType.rice => const {DishBase.rice},
      DishType.bread => const {DishBase.roti, DishBase.bread},
      _ => null,
    };
    if (allowedBases != null && !allowedBases.contains(r.base)) {
      issue(
        SeedIssueCode.r10Base,
        '.base',
        'a ${t.dishType.name} dish needs base '
            '${allowedBases.map((b) => b.name).join(' or ')}, '
            'not ${r.base.name}',
      );
    }
    _protein(t.protein);
  }

  void _protein(Protein protein) {
    const code = SeedIssueCode.r11Protein;
    final requiredIds = {for (final ri in required) ri.ingredientId};
    final expected = proteinIngredientIds[protein];
    if (expected != null && requiredIds.intersection(expected).isEmpty) {
      issue(
        code,
        '.tags.protein',
        '${protein.name} needs a required ingredient: '
            '${expected.join(' or ')}',
      );
    } else if (protein == Protein.dalLegume &&
        !requiredIds.any(
          (id) => catalogue[id]?.category == IngredientCategory.dal,
        )) {
      issue(code, '.tags.protein', 'dalLegume needs a required dal ingredient');
    } else if (protein == Protein.vegOnly) {
      final animal = proteinIngredientIds.values.expand((ids) => ids).toSet();
      final found = [
        for (final ri in r.ingredients)
          if (animal.contains(ri.ingredientId)) ri.ingredientId,
      ];
      if (found.isNotEmpty) {
        issue(
          code,
          '.tags.protein',
          'vegOnly dish contains ${found.join(', ')}',
        );
      }
    }
  }

  void image(bool Function(String path) assetExists) {
    final path = r.imageAsset;
    if (path == null) return;
    final expected = '$seedImageDir/${r.id}.webp';
    if (path != expected) {
      issue(
        SeedIssueCode.r9ImageAsset,
        '.imageAsset',
        '"$path" must be "$expected"',
      );
    } else if (!assetExists(path)) {
      issue(SeedIssueCode.r9ImageAsset, '.imageAsset', '"$path" not found');
    }
  }
}
