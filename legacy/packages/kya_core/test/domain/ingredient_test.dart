import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

void main() {
  const potato = Ingredient(
    id: 'potato',
    name: 'Potato',
    aliases: ['aloo', 'batata'],
    category: IngredientCategory.sabzi,
    role: IngredientRole.core,
    buyFrom: BuyFrom.sabziwala,
    shelfLifeDays: 21,
  );

  group('Ingredient', () {
    group('construction defaults', () {
      test('aliases default to empty, shelf life null, not user-made', () {
        const salt = Ingredient(
          id: 'salt',
          name: 'Salt',
          category: IngredientCategory.masala,
          role: IngredientRole.staple,
          buyFrom: BuyFrom.kirana,
        );

        expect(salt.aliases, isEmpty);
        expect(salt.shelfLifeDays, isNull);
        expect(salt.isUserCreated, isFalse);
      });
    });

    group('equality', () {
      test('is identity-by-id: same id with different fields is equal', () {
        final renamed = potato.copyWith(
          name: 'Aloo',
          aliases: const [],
          category: IngredientCategory.other,
          role: IngredientRole.optional,
          buyFrom: BuyFrom.other,
          shelfLifeDays: 1,
          isUserCreated: true,
        );

        expect(renamed, equals(potato));
        expect(renamed.hashCode, potato.hashCode);
      });

      test('different ids are not equal even if every other field is', () {
        final other = potato.copyWith(id: 'sweet_potato');

        expect(other, isNot(equals(potato)));
      });

      test('ids are compared case-sensitively', () {
        expect(potato.copyWith(id: 'Potato'), isNot(equals(potato)));
      });

      test('never equals a non-Ingredient with the same id text', () {
        expect(potato, isNot(equals('potato')));
      });

      test('deduplicates by id inside a Set', () {
        final set = {potato, potato.copyWith(name: 'Batata')};

        expect(set, hasLength(1));
      });
    });

    group('copyWith', () {
      test('with no arguments preserves every field', () {
        final copy = potato.copyWith();

        expect(copy.id, potato.id);
        expect(copy.name, potato.name);
        expect(copy.aliases, potato.aliases);
        expect(copy.category, potato.category);
        expect(copy.role, potato.role);
        expect(copy.buyFrom, potato.buyFrom);
        expect(copy.shelfLifeDays, potato.shelfLifeDays);
        expect(copy.isUserCreated, potato.isUserCreated);
      });

      test('replaces only the fields that are passed', () {
        final copy = potato.copyWith(
          name: 'Aloo',
          role: IngredientRole.flavor,
          shelfLifeDays: 30,
        );

        expect(copy.name, 'Aloo');
        expect(copy.role, IngredientRole.flavor);
        expect(copy.shelfLifeDays, 30);
        expect(copy.aliases, ['aloo', 'batata']);
        expect(copy.category, IngredientCategory.sabzi);
        expect(copy.buyFrom, BuyFrom.sabziwala);
        expect(copy.isUserCreated, isFalse);
      });

      test('does not mutate the original', () {
        potato.copyWith(name: 'Changed', shelfLifeDays: 2);

        expect(potato.name, 'Potato');
        expect(potato.shelfLifeDays, 21);
      });

      test('can clear shelfLifeDays back to null', () {
        // Per the doc comment, null shelf life means "doesn't meaningfully
        // expire"; a user editing a mis-seeded ingredient must be able to
        // reach that state, like PantryItem.expiresOn / Recipe.imageAsset.
        int? noShelfLife;
        final cleared = potato.copyWith(shelfLifeDays: noShelfLife);

        expect(cleared.shelfLifeDays, isNull);
        expect(potato.copyWith(name: 'X').shelfLifeDays, 21);
      });
    });

    test('toString identifies the ingredient by id', () {
      expect(potato.toString(), 'Ingredient(potato)');
    });
  });
}
