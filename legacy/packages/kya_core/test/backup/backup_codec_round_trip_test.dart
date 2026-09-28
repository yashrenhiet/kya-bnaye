import 'dart:convert';

import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'backup_fixtures.dart';

void main() {
  const codec = BackupCodec();

  /// Encodes, serialises to a JSON string and back, then decodes — the
  /// exact path a file export/import takes.
  BackupBundle viaJsonText(BackupBundle bundle) {
    final text = jsonEncode(codec.encode(bundle, exportedAt: exportedAt));
    return codec.decode(jsonDecode(text) as Map<String, dynamic>);
  }

  group('BackupCodec.encode', () {
    test('writes the current schema version and exportedAt', () {
      final json = codec.encode(fullBundle(), exportedAt: exportedAt);
      expect(BackupCodec.currentVersion, 1);
      expect(json['version'], BackupCodec.currentVersion);
      expect(json['exportedAt'], '2026-09-26T12:00:00.000Z');
    });

    test('writes local exportedAt without a zone suffix', () {
      final json = codec.encode(
        fullBundle(),
        exportedAt: DateTime(2026, 9, 26, 12),
      );
      expect(json['exportedAt'], '2026-09-26T12:00:00.000');
    });

    test('writes one top-level list per entity type', () {
      final json = codec.encode(fullBundle(), exportedAt: exportedAt);
      expect(json.keys, {
        'version',
        'exportedAt',
        'ingredients',
        'pantryItems',
        'recipes',
        'mealLogs',
        'swipeEvents',
        'shoppingItems',
      });
      expect(json['ingredients'], hasLength(3));
      expect(json['pantryItems'], hasLength(3));
      expect(json['recipes'], hasLength(2));
      expect(json['mealLogs'], hasLength(2));
      expect(json['swipeEvents'], hasLength(4));
      expect(json['shoppingItems'], hasLength(4));
    });

    test('output is JSON-serialisable', () {
      final json = codec.encode(fullBundle(), exportedAt: exportedAt);
      expect(() => jsonEncode(json), returnsNormally);
    });

    test('stores enums by name and DateTimes as ISO-8601 strings', () {
      final json = codec.encode(fullBundle(), exportedAt: exportedAt);
      final swipe = (json['swipeEvents'] as List)[1] as Map<String, dynamic>;
      expect(swipe, {
        'id': 'e2',
        'recipeId': 'palak_paneer',
        'action': 'undo',
        'mode': 'craving',
        'at': '2026-03-01T04:05:06.789012Z',
        'deckSeed': -7,
        'undoesEventId': 'e1',
      });
    });

    test('empty bundle encodes to empty lists', () {
      const empty = BackupBundle(
        ingredients: [],
        pantryItems: [],
        recipes: [],
        mealLogs: [],
        swipeEvents: [],
        shoppingItems: [],
      );
      final json = codec.encode(empty, exportedAt: exportedAt);
      for (final key in ['ingredients', 'recipes', 'shoppingItems']) {
        expect(json[key], isEmpty);
      }
    });
  });

  group('BackupCodec round-trip', () {
    test('restores every entity and field directly from the map', () {
      final bundle = fullBundle();
      final decoded = codec.decode(
        codec.encode(bundle, exportedAt: exportedAt),
      );
      expectBundlesEqual(decoded, bundle);
    });

    test('restores every entity and field through JSON text', () {
      final bundle = fullBundle();
      expectBundlesEqual(viaJsonText(bundle), bundle);
    });

    test('round-trips an empty bundle', () {
      const empty = BackupBundle(
        ingredients: [],
        pantryItems: [],
        recipes: [],
        mealLogs: [],
        swipeEvents: [],
        shoppingItems: [],
      );
      expectBundlesEqual(viaJsonText(empty), empty);
    });

    test('user-created ingredients keep isUserCreated', () {
      final decoded = viaJsonText(fullBundle());
      final user = decoded.ingredients.singleWhere(
        (i) => i.id == userIngredient.id,
      );
      expect(user.isUserCreated, isTrue);
      expect(decoded.ingredients.where((i) => i.isUserCreated), hasLength(1));
    });

    test('undo events keep undoesEventId; others keep null', () {
      final events = viaJsonText(fullBundle()).swipeEvents;
      expect(events.map((e) => e.undoesEventId), [null, 'e1', null, null]);
      expect(events[1].action, SwipeAction.undo);
    });

    test('recipe sets and nullable fields survive', () {
      final recipes = viaJsonText(fullBundle()).recipes;
      expect(recipes[0].mealTypes, {MealType.lunch, MealType.dinner});
      expect(recipes[0].tags.flavours, {Flavour.savoury, Flavour.mild});
      expect(recipes[0].imageAsset, isNotNull);
      expect(recipes[0].requiredIngredients, hasLength(1));
      expect(recipes[1].mealTypes, isEmpty);
      expect(recipes[1].tags.flavours, isEmpty);
      expect(recipes[1].imageAsset, isNull);
    });

    test('shopping items keep null and non-null optional fields', () {
      final items = viaJsonText(fullBundle()).shoppingItems;
      expect(items.map((i) => i.ingredientId), [
        'potato',
        'paneer',
        null,
        'salt',
      ]);
      expect(items.map((i) => i.customName), [
        null,
        null,
        'Birthday candles',
        null,
      ]);
      expect(items.map((i) => i.recipeId), [null, 'palak_paneer', null, null]);
    });

    group('DateTime handling', () {
      test('UTC instants stay UTC with microsecond precision', () {
        final log = viaJsonText(fullBundle()).mealLogs[1];
        expect(log.cookedAt.isUtc, isTrue);
        expect(log.cookedAt, utcTime);
        expect(log.cookedAt.microsecond, 12);
      });

      test('local times stay local with the same wall-clock value', () {
        final log = viaJsonText(fullBundle()).mealLogs[0];
        expect(log.cookedAt.isUtc, isFalse);
        expect(log.cookedAt, localTime);
        expect(log.cookedAt.millisecond, 123);
        expect(log.cookedAt.microsecond, 456);
      });

      test('nullable expiresOn round-trips as null and non-null', () {
        final pantry = viaJsonText(fullBundle()).pantryItems;
        expect(pantry[0].expiresOn, DateTime(2026, 10, 10));
        expect(pantry[1].expiresOn, isNull);
        expect(pantry[2].expiresOn, utcTime);
        expect(pantry[2].expiresOn!.isUtc, isTrue);
      });

      test('offset timestamps written by other tools decode as UTC', () {
        final json = codec.encode(fullBundle(), exportedAt: exportedAt);
        ((json['mealLogs'] as List)[0] as Map<String, dynamic>)['cookedAt'] =
            '2026-09-26T19:30:00+05:30';
        final cookedAt = codec.decode(json).mealLogs[0].cookedAt;
        expect(cookedAt.isUtc, isTrue);
        expect(cookedAt, DateTime.utc(2026, 9, 26, 14));
      });
    });

    group('lenient decoding', () {
      Map<String, dynamic> encoded() =>
          jsonDecode(
                jsonEncode(codec.encode(fullBundle(), exportedAt: exportedAt)),
              )
              as Map<String, dynamic>;

      Map<String, dynamic> first(Map<String, dynamic> json, String key) =>
          (json[key] as List).first as Map<String, dynamic>;

      test('absent boolean flags default to false', () {
        final json = encoded();
        first(json, 'ingredients').remove('isUserCreated');
        first(json, 'pantryItems').remove('expiryIsEstimated');
        first(json, 'recipes').remove('isFavorite');
        first(json, 'recipes').remove('isHidden');
        first(json, 'shoppingItems').remove('isChecked');
        final recipeJson = first(json, 'recipes');
        ((recipeJson['ingredients'] as List).first as Map<String, dynamic>)
            .remove('isOptional');

        final decoded = codec.decode(json);
        expect(decoded.ingredients.first.isUserCreated, isFalse);
        expect(decoded.pantryItems.first.expiryIsEstimated, isFalse);
        expect(decoded.recipes.first.isFavorite, isFalse);
        expect(decoded.recipes.first.isHidden, isFalse);
        expect(decoded.recipes.first.ingredients.first.isOptional, isFalse);
        expect(decoded.shoppingItems.first.isChecked, isFalse);
      });

      test('unknown extra keys are ignored', () {
        final json = encoded()..['futureTopLevel'] = {'a': 1};
        first(json, 'recipes')['futureField'] = 'x';
        expectBundlesEqual(codec.decode(json), fullBundle());
      });
    });
  });
}
