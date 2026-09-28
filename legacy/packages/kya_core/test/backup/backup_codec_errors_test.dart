import 'dart:convert';

import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'backup_fixtures.dart';

const _codec = BackupCodec();

/// A valid backup as it looks after being read back from a file.
Map<String, dynamic> _validJson() =>
    jsonDecode(jsonEncode(_codec.encode(fullBundle(), exportedAt: exportedAt)))
        as Map<String, dynamic>;

Map<String, dynamic> _entity(
  Map<String, dynamic> json,
  String key, [
  int index = 0,
]) => (json[key] as List)[index] as Map<String, dynamic>;

Matcher _throwsFormat(Object messageMatcher) => throwsA(
  isA<BackupFormatException>()
      .having((e) => e.message, 'message', messageMatcher)
      .having(
        (e) => e.toString(),
        'toString()',
        startsWith('BackupFormatException: '),
      ),
);

final Matcher _throwsMalformed = _throwsFormat(
  startsWith('Malformed backup data: '),
);

final Matcher _throwsUnsupportedVersion = _throwsFormat(
  allOf(startsWith('Unsupported backup version: '), contains('up to 1')),
);

void main() {
  test('sanity: the unmodified fixture decodes', () {
    expect(() => _codec.decode(_validJson()), returnsNormally);
  });

  group('schema version', () {
    test('future version is rejected with an update hint', () {
      final json = _validJson()..['version'] = BackupCodec.currentVersion + 1;
      expect(
        () => _codec.decode(json),
        _throwsFormat(
          allOf(
            contains('Unsupported backup version: 2'),
            contains('Update the app'),
          ),
        ),
      );
    });

    test('missing version is rejected', () {
      final json = _validJson()..remove('version');
      expect(() => _codec.decode(json), _throwsUnsupportedVersion);
    });

    test('non-int versions are rejected', () {
      for (final bad in <Object?>[
        '1',
        1.0,
        true,
        null,
        <int>[1],
      ]) {
        final json = _validJson()..['version'] = bad;
        expect(() => _codec.decode(json), _throwsUnsupportedVersion);
      }
    });

    test('zero or negative version is rejected', () {
      for (final bad in [0, -1]) {
        final json = _validJson()..['version'] = bad;
        expect(() => _codec.decode(json), _throwsUnsupportedVersion);
      }
    });

    test('empty object is rejected on version before anything else', () {
      expect(
        () => _codec.decode(<String, dynamic>{}),
        _throwsUnsupportedVersion,
      );
    });
  });

  group('top-level sections', () {
    const sections = [
      'ingredients',
      'pantryItems',
      'recipes',
      'mealLogs',
      'swipeEvents',
      'shoppingItems',
    ];

    for (final section in sections) {
      test('missing $section is rejected', () {
        final json = _validJson()..remove(section);
        expect(
          () => _codec.decode(json),
          _throwsFormat('Expected a list, got Null'),
        );
      });

      test('$section as an object is rejected', () {
        final json = _validJson()..[section] = <String, dynamic>{};
        expect(
          () => _codec.decode(json),
          _throwsFormat(startsWith('Expected a list, got ')),
        );
      });

      test('$section containing a non-object entry is rejected', () {
        final json = _validJson();
        (json[section] as List).add('not an object');
        expect(() => _codec.decode(json), _throwsMalformed);
      });
    }
  });

  group('missing required fields', () {
    const required = <String, List<String>>{
      'ingredients': ['id', 'name', 'aliases', 'category', 'role', 'buyFrom'],
      'pantryItems': ['ingredientId', 'level', 'updatedAt'],
      'recipes': [
        'id',
        'name',
        'mealTypes',
        'minutes',
        'base',
        'ingredients',
        'steps',
        'tags',
        'source',
      ],
      'mealLogs': ['id', 'recipeId', 'mealType', 'cookedAt'],
      'swipeEvents': ['id', 'recipeId', 'action', 'mode', 'at', 'deckSeed'],
      'shoppingItems': ['id', 'reason', 'createdAt'],
    };

    required.forEach((section, fields) {
      for (final field in fields) {
        test('$section.$field', () {
          final json = _validJson();
          _entity(json, section).remove(field);
          expect(() => _codec.decode(json), _throwsMalformed);
        });
      }
    });

    test('recipe tag fields', () {
      for (final field in [
        'region',
        'dishType',
        'flavours',
        'heaviness',
        'protein',
      ]) {
        final json = _validJson();
        (_entity(json, 'recipes')['tags'] as Map<String, dynamic>).remove(
          field,
        );
        expect(() => _codec.decode(json), _throwsMalformed, reason: field);
      }
    });

    test('recipe ingredient fields', () {
      for (final field in ['ingredientId', 'quantityText']) {
        final json = _validJson();
        final ingredients = _entity(json, 'recipes')['ingredients'] as List;
        (ingredients.first as Map<String, dynamic>).remove(field);
        expect(() => _codec.decode(json), _throwsMalformed, reason: field);
      }
    });

    test('shopping item with neither ingredientId nor customName', () {
      final json = _validJson();
      _entity(json, 'shoppingItems').remove('ingredientId');
      expect(() => _codec.decode(json), _throwsMalformed);
    });

    test('shopping item without a target is rejected explicitly', () {
      // Must not rely on ShoppingItem's constructor assert, which is
      // stripped from release builds.
      final json = _validJson();
      _entity(json, 'shoppingItems')
        ..['ingredientId'] = null
        ..['customName'] = null;
      expect(
        () => _codec.decode(json),
        _throwsFormat(
          allOf(
            startsWith('Malformed backup data: '),
            contains('neither an ingredientId nor a customName'),
          ),
        ),
      );
    });
  });

  group('unknown enum values', () {
    final cases = <String, void Function(Map<String, dynamic>)>{
      'ingredient category': (j) =>
          _entity(j, 'ingredients')['category'] = 'meat',
      'ingredient role': (j) => _entity(j, 'ingredients')['role'] = 'hero',
      'ingredient buyFrom': (j) =>
          _entity(j, 'ingredients')['buyFrom'] = 'online',
      'pantry level': (j) => _entity(j, 'pantryItems')['level'] = 'some',
      'recipe mealType': (j) => _entity(j, 'recipes')['mealTypes'] = ['brunch'],
      'recipe base': (j) => _entity(j, 'recipes')['base'] = 'naan',
      'recipe source': (j) => _entity(j, 'recipes')['source'] = 'web',
      'tag region': (j) => _tags(j)['region'] = 'mars',
      'tag dishType': (j) => _tags(j)['dishType'] = 'soup',
      'tag flavour': (j) => _tags(j)['flavours'] = ['umami'],
      'tag heaviness': (j) => _tags(j)['heaviness'] = 'huge',
      'tag protein': (j) => _tags(j)['protein'] = 'tofu',
      'meal log mealType': (j) => _entity(j, 'mealLogs')['mealType'] = 'brunch',
      'swipe action': (j) => _entity(j, 'swipeEvents')['action'] = 'up',
      'swipe mode': (j) => _entity(j, 'swipeEvents')['mode'] = 'party',
      'shopping reason': (j) =>
          _entity(j, 'shoppingItems')['reason'] = 'impulse',
      'enum name with wrong case': (j) =>
          _entity(j, 'pantryItems')['level'] = 'Plenty',
    };

    for (final MapEntry(key: name, value: corrupt) in cases.entries) {
      test(name, () {
        final json = _validJson();
        corrupt(json);
        expect(() => _codec.decode(json), _throwsMalformed);
      });
    }
  });

  group('wrong field types', () {
    final cases = <String, void Function(Map<String, dynamic>)>{
      'ingredient id as int': (j) => _entity(j, 'ingredients')['id'] = 7,
      'ingredient aliases as string': (j) =>
          _entity(j, 'ingredients')['aliases'] = 'aloo',
      'ingredient shelfLifeDays as string': (j) =>
          _entity(j, 'ingredients')['shelfLifeDays'] = '14',
      'ingredient isUserCreated as string': (j) =>
          _entity(j, 'ingredients')['isUserCreated'] = 'yes',
      'pantry updatedAt as epoch int': (j) =>
          _entity(j, 'pantryItems')['updatedAt'] = 1790000000,
      'pantry updatedAt unparsable': (j) =>
          _entity(j, 'pantryItems')['updatedAt'] = 'yesterday',
      'pantry expiresOn unparsable': (j) =>
          _entity(j, 'pantryItems')['expiresOn'] = '31/12/2026',
      'pantry expiryIsEstimated as int': (j) =>
          _entity(j, 'pantryItems')['expiryIsEstimated'] = 1,
      'recipe minutes as string': (j) =>
          _entity(j, 'recipes')['minutes'] = '35',
      'recipe minutes as double': (j) =>
          _entity(j, 'recipes')['minutes'] = 35.5,
      'recipe mealTypes as string': (j) =>
          _entity(j, 'recipes')['mealTypes'] = 'dinner',
      'recipe mealTypes entry as int': (j) =>
          _entity(j, 'recipes')['mealTypes'] = [1],
      'recipe tags as list': (j) => _entity(j, 'recipes')['tags'] = <int>[],
      'recipe ingredients as object': (j) =>
          _entity(j, 'recipes')['ingredients'] = <String, dynamic>{},
      'recipe ingredient entry as string': (j) =>
          _entity(j, 'recipes')['ingredients'] = ['paneer'],
      'recipe imageAsset as bool': (j) =>
          _entity(j, 'recipes')['imageAsset'] = true,
      'recipe isFavorite as string': (j) =>
          _entity(j, 'recipes')['isFavorite'] = 'true',
      'recipe steps as string': (j) =>
          _entity(j, 'recipes')['steps'] = 'Cook it',
      'tag flavours as string': (j) => _tags(j)['flavours'] = 'spicy',
      'meal log cookedAt as null': (j) =>
          _entity(j, 'mealLogs')['cookedAt'] = null,
      'swipe deckSeed as string': (j) =>
          _entity(j, 'swipeEvents')['deckSeed'] = '42',
      'swipe undoesEventId as int': (j) =>
          _entity(j, 'swipeEvents', 1)['undoesEventId'] = 1,
      'shopping isChecked as string': (j) =>
          _entity(j, 'shoppingItems')['isChecked'] = 'no',
      'shopping recipeId as int': (j) =>
          _entity(j, 'shoppingItems', 1)['recipeId'] = 3,
    };

    for (final MapEntry(key: name, value: corrupt) in cases.entries) {
      test(name, () {
        final json = _validJson();
        corrupt(json);
        expect(() => _codec.decode(json), _throwsMalformed);
      });
    }

    test('ingredient alias entry that is not a string', () {
      final json = _validJson();
      _entity(json, 'ingredients')['aliases'] = [1, 2];
      expect(() => _codec.decode(json), _throwsMalformed);
    });

    test('recipe step entry that is not a string', () {
      final json = _validJson();
      _entity(json, 'recipes')['steps'] = [
        {'text': 'Cook'},
      ];
      expect(() => _codec.decode(json), _throwsMalformed);
    });
  });

  group('malformed JSON text', () {
    // The codec deliberately accepts an already-parsed map; parsing the
    // file is the caller's job. These pin that contract: invalid text
    // never reaches decode(), and a non-object document is not a Map.
    test('invalid JSON fails in jsonDecode before the codec', () {
      expect(() => jsonDecode('{"version": 1,'), throwsFormatException);
    });

    test('a JSON array document is not a backup map', () {
      expect(jsonDecode('[1, 2, 3]'), isNot(isA<Map<String, dynamic>>()));
    });
  });
}

Map<String, dynamic> _tags(Map<String, dynamic> json) =>
    _entity(json, 'recipes')['tags'] as Map<String, dynamic>;
