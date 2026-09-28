import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime(2025, 6, 1, 10);

  ShoppingItem catalogItem({
    String id = 's1',
    String? ingredientId = 'onion',
    String? customName,
    ShoppingReason reason = ShoppingReason.out,
    String? recipeId,
    bool isChecked = false,
    DateTime? at,
  }) => ShoppingItem(
    id: id,
    ingredientId: ingredientId,
    customName: customName,
    reason: reason,
    recipeId: recipeId,
    isChecked: isChecked,
    createdAt: at ?? createdAt,
  );

  group('ShoppingItem', () {
    group('invariant: ingredientId or customName is required', () {
      test('asserts when both are null', () {
        expect(
          () => catalogItem(ingredientId: null),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts a catalog-only item', () {
        final item = catalogItem();

        expect(item.ingredientId, 'onion');
        expect(item.customName, isNull);
      });

      test('accepts a free-typed item with no ingredientId', () {
        final item = catalogItem(
          ingredientId: null,
          customName: 'birthday candles',
          reason: ShoppingReason.manual,
        );

        expect(item.ingredientId, isNull);
        expect(item.customName, 'birthday candles');
      });
    });

    group('displayName', () {
      test('resolves a catalog item through the supplied resolver', () {
        final requested = <String>[];
        final name = catalogItem().displayName((id) {
          requested.add(id);
          return 'Onion';
        });

        expect(name, 'Onion');
        expect(requested, ['onion']);
      });

      test('uses customName without calling the resolver', () {
        final item = catalogItem(
          ingredientId: null,
          customName: 'Birthday candles',
        );

        expect(
          item.displayName((_) => fail('resolver must not be called')),
          'Birthday candles',
        );
      });
    });

    group('equality', () {
      test('items with identical fields are equal with equal hashCodes', () {
        final a = catalogItem(
          reason: ShoppingReason.recipe,
          recipeId: 'palak_paneer',
        );
        final b = catalogItem(
          reason: ShoppingReason.recipe,
          recipeId: 'palak_paneer',
        );

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('differs when any single field differs', () {
        final base = catalogItem();

        expect(catalogItem(id: 's2'), isNot(equals(base)));
        expect(catalogItem(ingredientId: 'garlic'), isNot(equals(base)));
        expect(catalogItem(customName: 'Pyaaz'), isNot(equals(base)));
        expect(catalogItem(reason: ShoppingReason.low), isNot(equals(base)));
        expect(catalogItem(recipeId: 'poha'), isNot(equals(base)));
        expect(catalogItem(isChecked: true), isNot(equals(base)));
        expect(
          catalogItem(at: createdAt.add(const Duration(seconds: 1))),
          isNot(equals(base)),
        );
      });
    });
  });

  test('ShoppingReason covers exactly out, low, recipe, manual', () {
    expect(ShoppingReason.values, [
      ShoppingReason.out,
      ShoppingReason.low,
      ShoppingReason.recipe,
      ShoppingReason.manual,
    ]);
  });
}
