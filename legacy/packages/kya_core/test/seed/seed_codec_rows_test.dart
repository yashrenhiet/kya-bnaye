import 'package:test/test.dart';

import 'seed_codec_helpers.dart';
import 'seed_fixtures.dart';

void main() {
  group('SeedCodec.decode rejects malformed rows', () {
    group('app-owned keys are forbidden', () {
      for (final key in ['isUserCreated', 'source', 'isFavorite', 'isHidden']) {
        test('$key on an ingredient', () {
          expect(
            () => decodeFragments(withIngredientRow((i) => i[key] = false)),
            throwsSeed(
              '$potatoAt.$key',
              'key "$key" is not allowed in seed data (the app sets it)',
            ),
          );
        });

        test('$key on a recipe', () {
          expect(
            () => decodeFragments(withRecipeRow((r) => r[key] = false)),
            throwsSeed('$recipeAt.$key', contains('not allowed')),
          );
        });
      }
    });

    test('rejects an unknown ingredient key, listing the allowed ones', () {
      expect(
        () => decodeFragments(withIngredientRow((i) => i['shelfLife'] = 3)),
        throwsSeed(
          '$potatoAt.shelfLife',
          'unknown key "shelfLife" (allowed: id, name, aliases, category, '
              'role, buyFrom, shelfLifeDays)',
        ),
      );
    });

    test('rejects unknown keys in tags and recipe ingredient lines', () {
      expect(
        () => decodeFragments(
          withRecipeRow(
            (r) => (r['tags']! as Map<String, Object?>)['diet'] = 1,
          ),
        ),
        throwsSeed('$recipeAt.tags.diet', startsWith('unknown key "diet"')),
      );
      expect(
        () => decodeFragments(
          withRecipeRow(
            (r) =>
                ((r['ingredients']! as List<Object?>).first!
                        as Map<String, Object?>)['qty'] =
                    '1',
          ),
        ),
        throwsSeed(
          '$recipeAt.ingredients[0].qty',
          'unknown key "qty" (allowed: ingredientId, quantityText, '
              'isOptional)',
        ),
      );
    });

    test('rejects a missing required key', () {
      expect(
        () => decodeFragments(withIngredientRow((i) => i.remove('aliases'))),
        throwsSeed(potatoAt, 'missing required key "aliases"'),
      );
      expect(
        () => decodeFragments(withRecipeRow((r) => r.remove('steps'))),
        throwsSeed(recipeAt, 'missing required key "steps"'),
      );
    });

    group('wrong JSON types raise SeedFormatException, not TypeError', () {
      for (final MapEntry(:key, :value) in <String, Object?>{
        'name': 5,
        'aliases': 'aloo',
        'shelfLifeDays': 21.0,
        'category': ['sabzi'],
      }.entries) {
        test('ingredient $key = $value', () {
          expect(
            () => decodeFragments(withIngredientRow((i) => i[key] = value)),
            throwsSeed('$potatoAt.$key', startsWith('expected ')),
          );
        });
      }

      test('alias entry that is not a string', () {
        expect(
          () => decodeFragments(
            withIngredientRow((i) => i['aliases'] = ['aloo', null]),
          ),
          throwsSeed('$potatoAt.aliases[1]', 'expected a string, got null'),
        );
      });

      for (final MapEntry(:key, :value) in <String, Object?>{
        'minutes': '20',
        'mealTypes': 'lunch',
        'steps': [1, 2],
        'tags': 'north',
        'imageAsset': 5,
        'ingredients': {'potato': 1},
      }.entries) {
        test('recipe $key = $value', () {
          expect(
            () => decodeFragments(withRecipeRow((r) => r[key] = value)),
            throwsSeed(startsWith('$recipeAt.$key'), startsWith('expected ')),
          );
        });
      }

      test('isOptional must be a boolean when present', () {
        for (final value in [null, 'yes', 1]) {
          expect(
            () => decodeFragments(
              withRecipeRow(
                (r) =>
                    ((r['ingredients']! as List<Object?>).first!
                            as Map<String, Object?>)['isOptional'] =
                        value,
              ),
            ),
            throwsSeed(
              '$recipeAt.ingredients[0].isOptional',
              startsWith('expected a boolean, got '),
            ),
            reason: '$value',
          );
        }
      });
    });

    group('enums', () {
      test('unknown value names the allowed values', () {
        expect(
          () => decodeFragments(
            withRecipeRow(
              (r) => (r['tags']! as Map<String, Object?>)['region'] = 'nort',
            ),
          ),
          throwsSeed(
            '$recipeAt.tags.region',
            'unknown value "nort" (allowed: north, south, east, west, '
                'gujarati, punjabi, indoChinese, continental, street)',
          ),
        );
      });

      test('kebab-case spellings are rejected (names are camelCase)', () {
        expect(
          () => decodeFragments(
            withIngredientRow((i) => i['category'] = 'oil-ghee'),
          ),
          throwsSeed(
            '$potatoAt.category',
            startsWith('unknown value "oil-ghee"'),
          ),
        );
      });

      test('unknown value inside an enum array is located by index', () {
        expect(
          () => decodeFragments(
            withRecipeRow((r) => r['mealTypes'] = ['lunch', 'tea']),
          ),
          throwsSeed(
            '$recipeAt.mealTypes[1]',
            'unknown value "tea" (allowed: breakfast, lunch, dinner, snack)',
          ),
        );
      });

      test('duplicate value inside an enum array is rejected', () {
        expect(
          () => decodeFragments(
            withRecipeRow(
              (r) => (r['tags']! as Map<String, Object?>)['flavours'] = [
                'spicy',
                'spicy',
              ],
            ),
          ),
          throwsSeed('$recipeAt.tags.flavours[1]', 'duplicate value "spicy"'),
        );
      });

      test('every enum field is checked', () {
        for (final key in ['category', 'role', 'buyFrom']) {
          expect(
            () => decodeFragments(withIngredientRow((i) => i[key] = 'zzz')),
            throwsSeed('$potatoAt.$key', startsWith('unknown value')),
            reason: key,
          );
        }
        expect(
          () => decodeFragments(withRecipeRow((r) => r['base'] = 'naan')),
          throwsSeed('$recipeAt.base', startsWith('unknown value')),
        );
        for (final key in ['dishType', 'heaviness', 'protein']) {
          expect(
            () => decodeFragments(
              withRecipeRow(
                (r) => (r['tags']! as Map<String, Object?>)[key] = 'zzz',
              ),
            ),
            throwsSeed('$recipeAt.tags.$key', startsWith('unknown value')),
            reason: key,
          );
        }
      });
    });

    group('duplicate ids', () {
      test('within one fragment', () {
        final fragments = fragmentsJson();
        ((fragments[ingredientFile]! as Map<String, Object?>)['ingredients']!
                as List<Object?>)
            .add(potatoRow());
        expect(
          () => decodeFragments(fragments),
          throwsSeed(
            '$ingredientFile › ingredients[2].id',
            'duplicate ingredient id "potato" (first declared at '
                '$potatoAt)',
          ),
        );
      });

      test('across fragments', () {
        final manifest = seedCodec.decodeManifest(
          manifestJson()..['recipes'] = [recipeFile, 'recipes/more.json'],
        );
        final fragments = fragmentsJson()
          ..['recipes/more.json'] = {
            'recipes': [alooRecipeRow()],
          };
        expect(
          () => seedCodec.decode(manifest, fragments),
          throwsSeed(
            'recipes/more.json › recipes[0].id',
            'duplicate recipe id "jeera_aloo" (first declared at '
                '$recipeAt)',
          ),
        );
      });
    });
  });
}
