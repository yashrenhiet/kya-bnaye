import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

void main() {
  final updatedAt = DateTime(2025, 6);

  Map<String, PantryItem> pantryWith(String id, StockLevel level) => {
    id: PantryItem(ingredientId: id, level: level, updatedAt: updatedAt),
  };

  bool available(
    IngredientRole? role,
    Map<String, PantryItem> pantry, {
    String id = 'x',
  }) => resolveIngredientAvailability(
    ingredientId: id,
    role: role,
    pantry: pantry,
  );

  group('resolveIngredientAvailability', () {
    group('staple role', () {
      test('is available with no pantry record at all', () {
        expect(available(IngredientRole.staple, const {}), isTrue);
      });

      test('is available when plenty or low', () {
        expect(
          available(IngredientRole.staple, pantryWith('x', StockLevel.plenty)),
          isTrue,
        );
        expect(
          available(IngredientRole.staple, pantryWith('x', StockLevel.low)),
          isTrue,
        );
      });

      test('is unavailable only when explicitly marked out', () {
        expect(
          available(IngredientRole.staple, pantryWith('x', StockLevel.out)),
          isFalse,
        );
      });

      test('ignores records belonging to other ingredients', () {
        expect(
          available(IngredientRole.staple, pantryWith('y', StockLevel.out)),
          isTrue,
        );
      });
    });

    for (final role in [
      IngredientRole.core,
      IngredientRole.flavor,
      IngredientRole.optional,
      null,
    ]) {
      group('${role?.name ?? 'unknown (null)'} role', () {
        test('is unavailable with no pantry record (never bought)', () {
          expect(available(role, const {}), isFalse);
        });

        test('is available when plenty', () {
          expect(available(role, pantryWith('x', StockLevel.plenty)), isTrue);
        });

        test('low still counts as available', () {
          expect(available(role, pantryWith('x', StockLevel.low)), isTrue);
        });

        test('is unavailable when out', () {
          expect(available(role, pantryWith('x', StockLevel.out)), isFalse);
        });

        test('a record for a different ingredient does not count', () {
          expect(available(role, pantryWith('y', StockLevel.plenty)), isFalse);
        });
      });
    }

    test('matches the ingredient id exactly, never by substring', () {
      final pantry = pantryWith('rice_flour', StockLevel.plenty);

      expect(available(IngredientRole.core, pantry, id: 'rice'), isFalse);
      expect(available(IngredientRole.core, pantry, id: 'rice_flour'), isTrue);
    });
  });
}
