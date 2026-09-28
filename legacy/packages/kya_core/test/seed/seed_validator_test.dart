import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'seed_fixtures.dart';
import 'seed_validator_helpers.dart';

void main() {
  test('the fixture bundle is valid', () {
    expect(validateSeed(bundleOf()), isEmpty);
  });

  test('collects every issue instead of stopping at the first', () {
    final issues = validateSeed(
      bundleOf(
        ingredients: editIngredient('potato', (i) => i.copyWith(name: ' ')),
        recipes: editRecipe('dal_chawal', (r) => r.copyWith(minutes: 0)),
      ),
    );
    expect(issueCodes(issues), {
      SeedIssueCode.i2IngredientName,
      SeedIssueCode.r3Minutes,
    });
  });

  test('SeedIssue has value equality and a readable toString', () {
    const a = SeedIssue(SeedIssueCode.r3Minutes, 'recipes[x]', 'bad');
    expect(a, const SeedIssue(SeedIssueCode.r3Minutes, 'recipes[x]', 'bad'));
    expect(
      a.hashCode,
      const SeedIssue(SeedIssueCode.r3Minutes, 'recipes[x]', 'bad').hashCode,
    );
    expect(
      a,
      isNot(const SeedIssue(SeedIssueCode.r2MealTypes, 'recipes[x]', 'bad')),
    );
    expect(a.toString(), 'R3 recipes[x]: bad');
  });

  group('I1 ingredient id', () {
    test(r'rejects ids outside ^[a-z][a-z0-9_]*$', () {
      for (final id in ['Potato', '1potato', 'aloo-gobi', '_x', '']) {
        final issues = withExtraIngredients([ingredient(id, 'Bad Id')]);
        expect(
          issues,
          onlyIssue(
            SeedIssueCode.i1IngredientId,
            'ingredients[$id]',
            startsWith('id must match'),
          ),
          reason: id,
        );
      }
    });

    test('reserves the user_ prefix', () {
      expect(
        withExtraIngredients([ingredient('user_paneer', 'My Paneer')]),
        onlyIssue(
          SeedIssueCode.i1IngredientId,
          'ingredients[user_paneer]',
          contains('reserved'),
        ),
      );
    });

    test('rejects duplicate ids', () {
      expect(
        withExtraIngredients([ingredient('rice', 'Rice Again')]),
        onlyIssue(
          SeedIssueCode.i1IngredientId,
          'ingredients[rice]',
          'duplicate id',
        ),
      );
    });
  });

  group('I2 ingredient name', () {
    test('rejects a blank name', () {
      expect(
        withIngredient('rice', (i) => i.copyWith(name: '  ')),
        onlyIssue(
          SeedIssueCode.i2IngredientName,
          'ingredients[rice].name',
          'name is blank',
        ),
      );
    });

    test('rejects surrounding whitespace', () {
      expect(
        withIngredient('rice', (i) => i.copyWith(name: 'Rice ')),
        onlyIssue(
          SeedIssueCode.i2IngredientName,
          'ingredients[rice].name',
          'name has surrounding whitespace',
        ),
      );
    });

    test('rejects names equal after normalising, reported once', () {
      expect(
        withExtraIngredients([ingredient('rice_2', 'RICE')]),
        onlyIssue(
          SeedIssueCode.i2IngredientName,
          'ingredients[rice_2].name',
          'name "RICE" is also used by rice',
        ),
      );
    });
  });

  group('I3 alias collisions', () {
    test('an alias shared by two ingredients', () {
      expect(
        withExtraIngredients([
          ingredient('sweet_potato', 'Sweet Potato', aliases: ['aloo']),
        ]),
        onlyIssue(
          SeedIssueCode.i3AliasCollision,
          'ingredients',
          '"aloo" resolves to more than one ingredient: potato, '
              'sweet_potato',
        ),
      );
    });

    test("an alias equal to another ingredient's name", () {
      expect(
        withExtraIngredients([
          ingredient('shallots', 'Shallots', aliases: ['onion']),
        ]),
        onlyIssue(
          SeedIssueCode.i3AliasCollision,
          'ingredients',
          contains('onion, shallots'),
        ),
      );
    });

    test('reports every colliding key', () {
      final issues = withExtraIngredients([
        ingredient('x', 'X', aliases: ['aloo', 'pyaz']),
      ]);
      expect(issues.map((i) => i.message), [
        contains('"aloo"'),
        contains('"pyaz"'),
      ]);
    });

    test('an alias repeated within one ingredient', () {
      expect(
        withIngredient(
          'potato',
          (i) => i.copyWith(aliases: ['aloo', 'batata', 'aloo']),
        ),
        onlyIssue(
          SeedIssueCode.i3AliasCollision,
          'ingredients[potato].aliases[2]',
          'alias "aloo" is listed twice',
        ),
      );
    });

    test('an alias equal to its own name', () {
      expect(
        withIngredient('potato', (i) => i.copyWith(aliases: ['potato'])),
        onlyIssue(
          SeedIssueCode.i3AliasCollision,
          'ingredients[potato].aliases[0]',
          'alias "potato" repeats the ingredient name',
        ),
      );
    });
  });

  group('I4 alias format', () {
    test('rejects a blank alias', () {
      expect(
        withIngredient('potato', (i) => i.copyWith(aliases: ['aloo', ' '])),
        onlyIssue(
          SeedIssueCode.i4AliasFormat,
          'ingredients[potato].aliases[1]',
          'blank alias',
        ),
      );
    });

    test('rejects aliases that are not already normalised', () {
      for (final alias in ['Aloo', ' aloo', 'aloo  tikki']) {
        expect(
          withIngredient('potato', (i) => i.copyWith(aliases: [alias])),
          onlyIssue(
            SeedIssueCode.i4AliasFormat,
            'ingredients[potato].aliases[0]',
            contains('must be lowercase, trimmed and single-spaced'),
          ),
          reason: alias,
        );
      }
    });
  });

  group('I5 shelf life', () {
    test('rejects values outside 1..3650', () {
      for (final days in [0, -1, 3651]) {
        expect(
          withIngredient('potato', (i) => i.copyWith(shelfLifeDays: days)),
          onlyIssue(
            SeedIssueCode.i5ShelfLife,
            'ingredients[potato].shelfLifeDays',
            '$days is outside 1–3650',
          ),
        );
      }
    });

    test('accepts the bounds', () {
      for (final days in [1, 3650]) {
        expect(
          withIngredient('potato', (i) => i.copyWith(shelfLifeDays: days)),
          isEmpty,
        );
      }
    });

    test('is required for sabzi, fruit, dairy and meat/egg ids', () {
      for (final id in ['potato', 'coconut', 'paneer', 'eggs']) {
        expect(
          withIngredient(id, (i) => i.copyWith(shelfLifeDays: null)),
          onlyIssue(
            SeedIssueCode.i5ShelfLife,
            'ingredients[$id].shelfLifeDays',
            'required for a perishable ingredient',
          ),
          reason: id,
        );
      }
    });

    test('is optional for non-perishables', () {
      expect(
        fixtureIngredients.firstWhere((i) => i.id == 'rice').shelfLifeDays,
        isNull,
      );
      expect(validateSeed(bundleOf()), isEmpty);
    });
  });

  group('I6 buy from', () {
    test('sabzi must come from the sabziwala', () {
      expect(
        withIngredient('potato', (i) => i.copyWith(buyFrom: BuyFrom.kirana)),
        onlyIssue(
          SeedIssueCode.i6BuyFrom,
          'ingredients[potato].buyFrom',
          'sabzi must be bought from sabziwala, not kirana',
        ),
      );
    });

    test('dairy must come from the dairy', () {
      expect(
        withIngredient('paneer', (i) => i.copyWith(buyFrom: BuyFrom.other)),
        onlyIssue(
          SeedIssueCode.i6BuyFrom,
          'ingredients[paneer].buyFrom',
          'dairy must be bought from dairy, not other',
        ),
      );
    });

    test('coconut is exempt by default; exemptions are explicit', () {
      expect(const SeedRuleExemptions().buyFrom, {'coconut'});
      expect(
        validateSeed(
          bundleOf(),
          exemptions: const SeedRuleExemptions(buyFrom: {}),
        ),
        onlyIssue(SeedIssueCode.i6BuyFrom, 'ingredients[coconut].buyFrom'),
      );
    });

    test('other categories may come from anywhere', () {
      expect(
        withIngredient('rice', (i) => i.copyWith(buyFrom: BuyFrom.other)),
        isEmpty,
      );
    });
  });

  group('I7 staples', () {
    test('rejects fewer than 12 staples', () {
      expect(
        withIngredient('atta', (i) => i.copyWith(role: IngredientRole.core)),
        onlyIssue(
          SeedIssueCode.i7Staples,
          'ingredients',
          '11 staples; expected 12–25',
        ),
      );
    });

    test('rejects more than 25 staples', () {
      expect(
        withExtraIngredients([
          for (var n = 0; n < 14; n++) staple('extra_$n', 'Extra $n'),
        ]),
        onlyIssue(
          SeedIssueCode.i7Staples,
          'ingredients',
          '26 staples; expected 12–25',
        ),
      );
    });

    test('accepts exactly 25', () {
      expect(
        withExtraIngredients([
          for (var n = 0; n < 13; n++) staple('extra_$n', 'Extra $n'),
        ]),
        isEmpty,
      );
    });

    test('only masala, oilGhee, grains and other may be staples', () {
      expect(
        withExtraIngredients([
          ingredient(
            'lemon',
            'Lemon',
            category: IngredientCategory.sabzi,
            role: IngredientRole.staple,
            buyFrom: BuyFrom.sabziwala,
            shelfLifeDays: 14,
          ),
        ]),
        onlyIssue(
          SeedIssueCode.i7Staples,
          'ingredients[lemon].role',
          startsWith('a sabzi ingredient cannot be a staple'),
        ),
      );
    });
  });
}
