import 'dart:convert';

import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'seed_codec_helpers.dart';
import 'seed_fixtures.dart';

void main() {
  group('decodeManifest', () {
    test('decodes version and fragment lists in order', () {
      final manifest = seedCodec.decodeManifest({
        'seedVersion': 3,
        'ingredients': ['ingredients/b.json', 'ingredients/a.json'],
        'recipes': ['recipes/x.json'],
      });

      expect(manifest.seedVersion, 3);
      expect(manifest.ingredientFiles, [
        'ingredients/b.json',
        'ingredients/a.json',
      ]);
      expect(manifest.recipeFiles, ['recipes/x.json']);
      expect(manifest.allFiles, hasLength(3));
      expect(() => manifest.recipeFiles.add('x'), throwsUnsupportedError);
    });

    test('rejects a non-object document', () {
      expect(
        () => seedCodec.decodeManifest(['recipes/x.json']),
        throwsSeed('manifest.json', 'expected an object, got an array'),
      );
    });

    test('rejects a missing key', () {
      expect(
        () => seedCodec.decodeManifest(manifestJson()..remove('recipes')),
        throwsSeed('manifest.json', 'missing required key "recipes"'),
      );
    });

    test('rejects an unknown key, listing the allowed ones', () {
      expect(
        () => seedCodec.decodeManifest(manifestJson()..['version'] = 1),
        throwsSeed(
          'manifest.json › version',
          'unknown key "version" (allowed: seedVersion, ingredients, '
              'recipes)',
        ),
      );
    });

    test('rejects a non-integer or non-positive seedVersion', () {
      expect(
        () => seedCodec.decodeManifest(manifestJson()..['seedVersion'] = 1.0),
        throwsSeed(
          'manifest.json › seedVersion',
          'expected an integer, got a number (1.0)',
        ),
      );
      expect(
        () => seedCodec.decodeManifest(manifestJson()..['seedVersion'] = 0),
        throwsSeed('manifest.json › seedVersion', 'must be at least 1, got 0'),
      );
    });

    test('rejects an empty fragment list', () {
      expect(
        () =>
            seedCodec.decodeManifest(manifestJson()..['recipes'] = <Object?>[]),
        throwsSeed('manifest.json › recipes', 'must list at least one file'),
      );
    });

    test('rejects a non-string path', () {
      expect(
        () => seedCodec.decodeManifest(manifestJson()..['recipes'] = [7]),
        throwsSeed(
          'manifest.json › recipes[0]',
          'expected a string, got a number (7)',
        ),
      );
    });

    test('rejects unsafe or non-JSON paths', () {
      for (final path in [
        '../secret.json',
        '/abs/path.json',
        'Recipes/Sabzi.json',
        'recipes/sabzi.txt',
        'recipes//sabzi.json',
        '',
      ]) {
        expect(
          () => seedCodec.decodeManifest(manifestJson()..['recipes'] = [path]),
          throwsSeed(
            'manifest.json › recipes[0]',
            startsWith('invalid path "$path"'),
          ),
          reason: path,
        );
      }
    });

    test('rejects a path listed twice, even across lists', () {
      final json = manifestJson()..['recipes'] = [recipeFile, ingredientFile];
      expect(
        () => seedCodec.decodeManifest(json),
        throwsSeed(
          'manifest.json › recipes[1]',
          'file "$ingredientFile" is listed more than once',
        ),
      );
    });
  });

  group('decode', () {
    test('maps every field and forces seed ownership', () {
      final bundle = decodeFragments(fragmentsJson());

      expect(bundle.seedVersion, 1);
      final potato = bundle.ingredients.first;
      expect(potato.id, 'potato');
      expect(potato.name, 'Potato');
      expect(potato.aliases, ['aloo', 'batata']);
      expect(potato.category, IngredientCategory.sabzi);
      expect(potato.role, IngredientRole.core);
      expect(potato.buyFrom, BuyFrom.sabziwala);
      expect(potato.shelfLifeDays, 21);
      expect(potato.isUserCreated, isFalse);
      expect(bundle.ingredients[1].shelfLifeDays, isNull);

      final r = bundle.recipes.single;
      expect(r.id, 'jeera_aloo');
      expect(r.mealTypes, {MealType.lunch, MealType.dinner});
      expect(r.minutes, 20);
      expect(r.base, DishBase.roti);
      expect(r.tags.region, Region.north);
      expect(r.tags.dishType, DishType.drySabzi);
      expect(r.tags.flavours, {Flavour.spicy, Flavour.savoury});
      expect(r.tags.heaviness, Heaviness.light);
      expect(r.tags.protein, Protein.vegOnly);
      expect(r.ingredients.map((i) => i.ingredientId), ['potato', 'salt']);
      expect(r.ingredients.map((i) => i.isOptional), [false, true]);
      expect(r.ingredients.first.quantityText, '3 medium');
      expect(r.steps, hasLength(2));
      expect(r.imageAsset, isNull);
      expect(r.source, RecipeSource.seed);
      expect(r.isFavorite, isFalse);
      expect(r.isHidden, isFalse);
    });

    test('decodes real jsonDecode output and omitted optional keys', () {
      final fragments = withRecipeRow((r) => r.remove('imageAsset'));
      final decoded = jsonDecode(jsonEncode(fragments)) as Map<String, Object?>;

      expect(decodeFragments(decoded).recipes.single.imageAsset, isNull);
    });

    test('keeps a non-null imageAsset for the validator to check', () {
      final bundle = decodeFragments(
        withRecipeRow((r) => r['imageAsset'] = 'assets/seed/images/x.webp'),
      );
      expect(bundle.recipes.single.imageAsset, 'assets/seed/images/x.webp');
    });

    test('keeps fragment order and ignores unlisted files', () {
      final manifest = seedCodec.decodeManifest(
        manifestJson()
          ..['ingredients'] = ['ingredients/b.json', ingredientFile],
      );
      final fragments = fragmentsJson()
        ..['ingredients/b.json'] = {
          'ingredients': [
            {...saltRow(), 'id': 'jeera', 'name': 'Jeera'},
          ],
        }
        ..['stray/file.json'] = 'not even an object';

      final bundle = seedCodec.decode(manifest, fragments);

      expect(bundle.ingredients.map((i) => i.id), ['jeera', 'potato', 'salt']);
      expect(bundle.recipes.clear, throwsUnsupportedError);
    });

    test('rejects a fragment the manifest lists but the caller omitted', () {
      expect(
        () => decodeFragments(fragmentsJson()..remove(recipeFile)),
        throwsSeed(
          recipeFile,
          'listed in manifest.json but its contents were not provided',
        ),
      );
    });

    test('rejects a fragment that is not an object', () {
      expect(
        () => decodeFragments(fragmentsJson()..[recipeFile] = null),
        throwsSeed(recipeFile, 'expected an object, got null'),
      );
    });

    test('rejects the wrong top-level key for the fragment kind', () {
      final fragments = fragmentsJson()
        ..[ingredientFile] = {'recipes': <Object?>[]};
      expect(
        () => decodeFragments(fragments),
        throwsSeed(
          '$ingredientFile › recipes',
          'unknown key "recipes" (allowed: ingredients)',
        ),
      );
    });

    test('rejects a missing top-level key', () {
      expect(
        () => decodeFragments(
          fragmentsJson()..[recipeFile] = <String, Object?>{},
        ),
        throwsSeed(recipeFile, 'missing required key "recipes"'),
      );
    });

    test('rejects rows that are not an array of objects', () {
      expect(
        () => decodeFragments(fragmentsJson()..[recipeFile] = {'recipes': 'x'}),
        throwsSeed(
          '$recipeFile › recipes',
          'expected an array, got a string ("x")',
        ),
      );
      expect(
        () => decodeFragments(
          fragmentsJson()
            ..[recipeFile] = {
              'recipes': [1],
            },
        ),
        throwsSeed(
          '$recipeFile › recipes[0]',
          'expected an object, got a '
              'number (1)',
        ),
      );
    });

    test('rejects an object with non-string keys', () {
      final fragments = fragmentsJson()
        ..[recipeFile] = <Object?, Object?>{1: 'x'};
      expect(
        () => decodeFragments(fragments),
        throwsSeed(recipeFile, 'object key 1 is not a string'),
      );
    });
  });

  test('SeedFormatException.toString includes location and message', () {
    expect(
      const SeedFormatException('a.json › x', 'bad').toString(),
      'SeedFormatException: a.json › x: bad',
    );
  });
}
