import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'seed_fixtures.dart';
import 'seed_validator_helpers.dart';

void main() {
  group('R7 shoppable ingredient count', () {
    final extras = [for (var n = 0; n < 9; n++) ingredient('x_$n', 'X $n')];
    List<SeedIssue> withLines(int core) => validateSeed(
      bundleOf(
        ingredients: [...fixtureIngredients, ...extras],
        recipes: editRecipe(
          'dal_chawal',
          (r) => r.copyWith(
            ingredients: [
              for (var n = 0; n < core; n++) line('x_$n'),
              // Staples and optional lines never count.
              for (final s in fixtureStaples) line(s.id),
              line('coriander_leaves'),
              line('toor_dal', optional: true),
            ],
          ),
        ),
      ),
    );

    test('rejects more than 8 required core/flavor ingredients', () {
      expect(
        withLines(9),
        contains(
          issueMatching(
            SeedIssueCode.r7RequiredCount,
            'recipes[dal_chawal].ingredients',
            '9 required core/flavor ingredients; at most 8',
          ),
        ),
      );
    });

    test('accepts 8, ignoring staples and optional ones', () {
      expect(
        issueCodes(withLines(8)),
        isNot(contains(SeedIssueCode.r7RequiredCount)),
      );
    });
  });

  group('R8 flavours', () {
    test('rejects empty flavours', () {
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(tags: tagsOf(r, flavours: {})),
        ),
        onlyIssue(
          SeedIssueCode.r8Flavours,
          'recipes[dal_chawal].tags.flavours',
          'no flavours',
        ),
      );
    });

    test('rejects mild together with spicy', () {
      expect(
        withRecipe(
          'dal_chawal',
          (r) => r.copyWith(
            tags: tagsOf(r, flavours: {Flavour.mild, Flavour.spicy}),
          ),
        ),
        onlyIssue(
          SeedIssueCode.r8Flavours,
          'recipes[dal_chawal].tags.flavours',
          'a dish cannot be both mild and spicy',
        ),
      );
    });
  });

  group('R9 image asset', () {
    test('rejects a path that is not assets/seed/images/<id>.webp', () {
      for (final path in [
        'assets/seed/images/jeera_rice.jpg',
        'assets/seed/images/other.webp',
        'images/jeera_rice.webp',
      ]) {
        expect(
          withRecipe('jeera_rice', (r) => r.copyWith(imageAsset: path)),
          onlyIssue(
            SeedIssueCode.r9ImageAsset,
            'recipes[jeera_rice].imageAsset',
            '"$path" must be "$jeeraRiceImage"',
          ),
        );
      }
    });

    test('rejects a missing asset file', () {
      expect(
        validateSeed(bundleOf(), assets: const {}),
        onlyIssue(
          SeedIssueCode.r9ImageAsset,
          'recipes[jeera_rice].imageAsset',
          '"$jeeraRiceImage" not found',
        ),
      );
    });

    test('a null image asset is fine and never looked up', () {
      final bundle = bundleOf(
        recipes: editRecipe('jeera_rice', (r) => r.copyWith(imageAsset: null)),
      );
      final issues = const SeedValidator().validate(
        bundle,
        assetExists: (path) => fail('looked up $path'),
      );
      expect(issues, isEmpty);
    });
  });

  group('R10 base', () {
    test('a rice dish needs base rice', () {
      expect(
        withRecipe('jeera_rice', (r) => r.copyWith(base: DishBase.roti)),
        onlyIssue(
          SeedIssueCode.r10Base,
          'recipes[jeera_rice].base',
          'a rice dish needs base rice, not roti',
        ),
      );
    });

    test('a bread dish needs base roti or bread', () {
      Recipe bread(Recipe r, DishBase base) => r.copyWith(
        base: base,
        tags: tagsOf(r, dishType: DishType.bread),
      );
      expect(
        withRecipe('aloo_sabzi', (r) => bread(r, DishBase.none)),
        onlyIssue(
          SeedIssueCode.r10Base,
          'recipes[aloo_sabzi].base',
          'a bread dish needs base roti or bread, not none',
        ),
      );
      expect(
        withRecipe('aloo_sabzi', (r) => bread(r, DishBase.bread)),
        isEmpty,
      );
    });

    test('other dish types may use any base', () {
      expect(
        withRecipe('aloo_sabzi', (r) => r.copyWith(base: DishBase.none)),
        isEmpty,
      );
    });
  });

  group('R11 protein', () {
    final seafood = [
      ingredient(
        'fish',
        'Fish',
        category: IngredientCategory.other,
        buyFrom: BuyFrom.other,
        shelfLifeDays: 2,
      ),
      ingredient(
        'prawns',
        'Prawns',
        category: IngredientCategory.other,
        buyFrom: BuyFrom.other,
        shelfLifeDays: 2,
      ),
    ];
    List<SeedIssue> withRecipe(Recipe Function(Recipe) edit) => validateSeed(
      bundleOf(
        ingredients: [...fixtureIngredients, ...seafood],
        recipes: editRecipe('paneer_bhurji', edit),
      ),
    );

    test('paneer needs a required paneer line', () {
      expect(
        withRecipe(
          (r) => r.copyWith(
            ingredients: [line('potato'), line('paneer', optional: true)],
          ),
        ),
        onlyIssue(
          SeedIssueCode.r11Protein,
          'recipes[paneer_bhurji].tags.protein',
          'paneer needs a required ingredient: paneer',
        ),
      );
    });

    test('egg needs eggs', () {
      expect(
        withRecipe((r) => r.copyWith(tags: tagsOf(r, protein: Protein.egg))),
        onlyIssue(
          SeedIssueCode.r11Protein,
          'recipes[paneer_bhurji].tags.protein',
          'egg needs a required ingredient: eggs',
        ),
      );
    });

    test('chicken and mutton need their own ingredient', () {
      for (final p in [Protein.chicken, Protein.mutton]) {
        expect(
          withRecipe((r) => r.copyWith(tags: tagsOf(r, protein: p))),
          onlyIssue(
            SeedIssueCode.r11Protein,
            'recipes[paneer_bhurji].tags.protein',
            '${p.name} needs a required ingredient: ${p.name}',
          ),
        );
      }
    });

    test('fish is satisfied by fish or prawns', () {
      for (final id in ['fish', 'prawns']) {
        expect(
          withRecipe(
            (r) => r.copyWith(
              ingredients: [line(id), line('onion')],
              tags: tagsOf(r, protein: Protein.fish),
            ),
          ),
          isEmpty,
          reason: id,
        );
      }
      expect(
        withRecipe((r) => r.copyWith(tags: tagsOf(r, protein: Protein.fish))),
        onlyIssue(
          SeedIssueCode.r11Protein,
          'recipes[paneer_bhurji].tags.protein',
          'fish needs a required ingredient: fish or prawns',
        ),
      );
    });

    test('dalLegume needs a required dal-category ingredient', () {
      expect(
        withRecipe(
          (r) => r.copyWith(
            tags: tagsOf(r, protein: Protein.dalLegume),
            ingredients: [...r.ingredients, line('toor_dal', optional: true)],
          ),
        ),
        onlyIssue(
          SeedIssueCode.r11Protein,
          'recipes[paneer_bhurji].tags.protein',
          'dalLegume needs a required dal ingredient',
        ),
      );
    });

    test('vegOnly allows no paneer, egg, meat or fish, even optional', () {
      expect(
        withRecipe(
          (r) => r.copyWith(
            tags: tagsOf(r, protein: Protein.vegOnly),
            ingredients: [line('potato'), line('eggs', optional: true)],
          ),
        ),
        onlyIssue(
          SeedIssueCode.r11Protein,
          'recipes[paneer_bhurji].tags.protein',
          'vegOnly dish contains eggs',
        ),
      );
      expect(
        withRecipe(
          (r) => r.copyWith(tags: tagsOf(r, protein: Protein.vegOnly)),
        ),
        onlyIssue(
          SeedIssueCode.r11Protein,
          'recipes[paneer_bhurji].tags.protein',
          'vegOnly dish contains paneer',
        ),
      );
    });
  });
}
