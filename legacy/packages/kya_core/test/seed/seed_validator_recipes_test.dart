import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'seed_fixtures.dart';
import 'seed_validator_helpers.dart';

void main() {
  group('R1 recipe identity', () {
    test('rejects a malformed id', () {
      expect(
        withRecipe('dal_chawal', (r) => r.copyWith(id: 'Dal-Chawal')),
        onlyIssue(
          SeedIssueCode.r1RecipeIdentity,
          'recipes[Dal-Chawal]',
          startsWith('id must match'),
        ),
      );
    });

    test('rejects a duplicate id', () {
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(id: 'jeera_rice', name: 'Other'),
        ),
        onlyIssue(
          SeedIssueCode.r1RecipeIdentity,
          'recipes[jeera_rice]',
          'duplicate id',
        ),
      );
    });

    test('rejects blank, untrimmed and duplicate names', () {
      expect(
        withRecipe('dal_chawal', (r) => r.copyWith(name: ' ')),
        onlyIssue(
          SeedIssueCode.r1RecipeIdentity,
          'recipes[dal_chawal].name',
          'name is blank',
        ),
      );
      expect(
        withRecipe('dal_chawal', (r) => r.copyWith(name: 'Dal Chawal ')),
        onlyIssue(
          SeedIssueCode.r1RecipeIdentity,
          'recipes[dal_chawal].name',
          'name has surrounding whitespace',
        ),
      );
      expect(
        withRecipe('dal_chawal', (r) => r.copyWith(name: 'jeera  RICE')),
        onlyIssue(
          SeedIssueCode.r1RecipeIdentity,
          'recipes[jeera_rice].name',
          'name "Jeera Rice" is also used by dal_chawal',
        ),
      );
    });
  });

  test('R2 rejects a recipe with no meal types', () {
    expect(
      withRecipe('dal_chawal', (r) => r.copyWith(mealTypes: {})),
      onlyIssue(SeedIssueCode.r2MealTypes, 'recipes[dal_chawal].mealTypes'),
    );
  });

  group('R3 minutes', () {
    test('rejects values outside 1..240', () {
      for (final m in [0, 241]) {
        expect(
          withRecipe('dal_chawal', (r) => r.copyWith(minutes: m)),
          onlyIssue(
            SeedIssueCode.r3Minutes,
            'recipes[dal_chawal].minutes',
            '$m is outside 1–240',
          ),
        );
      }
    });

    test('accepts the bounds', () {
      for (final m in [1, 240]) {
        expect(
          withRecipe('dal_chawal', (r) => r.copyWith(minutes: m)),
          isEmpty,
        );
      }
    });
  });

  group('R4 steps', () {
    test('rejects fewer than 2 or more than 12 steps', () {
      for (final n in [1, 13]) {
        expect(
          withRecipe(
            'dal_chawal',
            (r) => r.copyWith(steps: List.filled(n, 'Stir.')),
          ),
          onlyIssue(
            SeedIssueCode.r4Steps,
            'recipes[dal_chawal].steps',
            '$n steps; expected 2–12',
          ),
        );
      }
    });

    test('rejects a blank step', () {
      expect(
        withRecipe('dal_chawal', (r) => r.copyWith(steps: ['Stir.', ' '])),
        onlyIssue(
          SeedIssueCode.r4Steps,
          'recipes[dal_chawal].steps[1]',
          'blank step',
        ),
      );
    });

    test('rejects a step longer than 200 characters', () {
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(steps: ['Stir.', 'x' * 201]),
        ),
        onlyIssue(
          SeedIssueCode.r4Steps,
          'recipes[dal_chawal].steps[1]',
          '201 characters; at most 200',
        ),
      );
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(steps: ['Stir.', 'x' * 200]),
        ),
        isEmpty,
      );
    });
  });

  group('R5 ingredient lines', () {
    test('rejects an empty ingredient list', () {
      final issues = withRecipe(
        'dal_chawal',
        (r) => r.copyWith(ingredients: []),
      );
      expect(
        issues.first,
        issueMatching(
          SeedIssueCode.r5Ingredients,
          'recipes[dal_chawal].ingredients',
          'no ingredients',
        ),
      );
      expect(issueCodes(issues), {
        SeedIssueCode.r5Ingredients,
        SeedIssueCode.r6CoreIngredient,
        SeedIssueCode.r11Protein,
      });
    });

    test('rejects an unknown ingredient id', () {
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(ingredients: [...r.ingredients, line('hing')]),
        ),
        onlyIssue(
          SeedIssueCode.r5Ingredients,
          'recipes[dal_chawal].ingredients[3]',
          'unknown ingredient "hing"',
        ),
      );
    });

    test('rejects a repeated ingredient id', () {
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(
            ingredients: [...r.ingredients, line('rice', optional: true)],
          ),
        ),
        onlyIssue(
          SeedIssueCode.r5Ingredients,
          'recipes[dal_chawal].ingredients[3]',
          'ingredient "rice" is repeated',
        ),
      );
    });

    test('rejects blank quantity text', () {
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(
            ingredients: [
              ...r.ingredients,
              const RecipeIngredient(ingredientId: 'salt', quantityText: ' '),
            ],
          ),
        ),
        onlyIssue(
          SeedIssueCode.r5Ingredients,
          'recipes[dal_chawal].ingredients[3]',
          'blank quantityText',
        ),
      );
    });
  });

  group('R6 core ingredient', () {
    test('rejects a recipe with no core-role ingredient', () {
      expect(
        withRecipe(
          'aloo_sabzi',
          (r) => r.copyWith(ingredients: [line('onion'), line('salt')]),
        ),
        onlyIssue(
          SeedIssueCode.r6CoreIngredient,
          'recipes[aloo_sabzi]'
              '.ingredients',
          'no required ingredient has the core role',
        ),
      );
    });

    test('an optional core line does not count', () {
      expect(
        withRecipe(
          'aloo_sabzi',
          (r) => r.copyWith(
            ingredients: [line('potato', optional: true), line('onion')],
          ),
        ),
        onlyIssue(
          SeedIssueCode.r6CoreIngredient,
          'recipes[aloo_sabzi]'
          '.ingredients',
        ),
      );
    });
  });
}
