import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

const _tags = DishTags(
  region: Region.north,
  dishType: DishType.dal,
  flavours: {Flavour.savoury},
  heaviness: Heaviness.medium,
  protein: Protein.dalLegume,
);

const _dalTadka = Recipe(
  id: 'dal_tadka',
  name: 'Dal Tadka',
  mealTypes: {MealType.lunch, MealType.dinner},
  minutes: 30,
  base: DishBase.rice,
  ingredients: [
    RecipeIngredient(ingredientId: 'toor_dal', quantityText: '1 katori'),
    RecipeIngredient(ingredientId: 'tomato', quantityText: '2 medium'),
    RecipeIngredient(
      ingredientId: 'coriander',
      quantityText: 'a handful',
      isOptional: true,
    ),
    RecipeIngredient(ingredientId: 'ghee', quantityText: '1 tbsp'),
  ],
  steps: ['Boil dal.', 'Temper with ghee.'],
  tags: _tags,
  source: RecipeSource.seed,
  imageAsset: 'assets/dal_tadka.webp',
);

void main() {
  group('Recipe', () {
    test('defaults: not favourite, not hidden, no image', () {
      const r = Recipe(
        id: 'r',
        name: 'R',
        mealTypes: {MealType.snack},
        minutes: 5,
        base: DishBase.none,
        ingredients: [],
        steps: [],
        tags: _tags,
        source: RecipeSource.user,
      );

      expect(r.isFavorite, isFalse);
      expect(r.isHidden, isFalse);
      expect(r.imageAsset, isNull);
    });

    group('requiredIngredients', () {
      test('excludes optional ingredients and keeps original order', () {
        expect(_dalTadka.requiredIngredients.map((i) => i.ingredientId), [
          'toor_dal',
          'tomato',
          'ghee',
        ]);
      });

      test('is empty when every ingredient is optional', () {
        final garnishOnly = _dalTadka.copyWith(
          ingredients: const [
            RecipeIngredient(
              ingredientId: 'coriander',
              quantityText: 'some',
              isOptional: true,
            ),
          ],
        );

        expect(garnishOnly.requiredIngredients, isEmpty);
      });

      test('is empty for a recipe with no ingredients', () {
        expect(
          _dalTadka.copyWith(ingredients: const []).requiredIngredients,
          isEmpty,
        );
      });

      test('returns all ingredients when none are optional', () {
        const all = [
          RecipeIngredient(ingredientId: 'rice', quantityText: '1 cup'),
          RecipeIngredient(ingredientId: 'water', quantityText: '2 cups'),
        ];

        expect(_dalTadka.copyWith(ingredients: all).requiredIngredients, all);
      });
    });

    group('equality', () {
      test('is identity-by-id regardless of other fields', () {
        final edited = _dalTadka.copyWith(
          name: 'Dal Fry',
          minutes: 45,
          isFavorite: true,
          isHidden: true,
          imageAsset: null,
          source: RecipeSource.user,
        );

        expect(edited, equals(_dalTadka));
        expect(edited.hashCode, _dalTadka.hashCode);
      });

      test('different ids are not equal', () {
        expect(_dalTadka.copyWith(id: 'dal_fry'), isNot(equals(_dalTadka)));
      });
    });

    group('copyWith', () {
      test('with no arguments preserves every field', () {
        final copy = _dalTadka.copyWith();

        expect(copy.id, _dalTadka.id);
        expect(copy.name, _dalTadka.name);
        expect(copy.mealTypes, _dalTadka.mealTypes);
        expect(copy.minutes, _dalTadka.minutes);
        expect(copy.base, _dalTadka.base);
        expect(copy.ingredients, _dalTadka.ingredients);
        expect(copy.steps, _dalTadka.steps);
        expect(copy.tags, _dalTadka.tags);
        expect(copy.imageAsset, _dalTadka.imageAsset);
        expect(copy.isFavorite, _dalTadka.isFavorite);
        expect(copy.isHidden, _dalTadka.isHidden);
        expect(copy.source, _dalTadka.source);
      });

      test('replaces only the fields that are passed', () {
        final copy = _dalTadka.copyWith(
          isFavorite: true,
          mealTypes: {MealType.breakfast},
          base: DishBase.roti,
        );

        expect(copy.isFavorite, isTrue);
        expect(copy.mealTypes, {MealType.breakfast});
        expect(copy.base, DishBase.roti);
        expect(copy.name, 'Dal Tadka');
        expect(copy.isHidden, isFalse);
        expect(copy.imageAsset, 'assets/dal_tadka.webp');
      });

      test('omitting imageAsset leaves it unchanged', () {
        expect(
          _dalTadka.copyWith(minutes: 10).imageAsset,
          'assets/dal_tadka.webp',
        );
      });

      test('passing imageAsset: null explicitly clears it', () {
        final cleared = _dalTadka.copyWith(imageAsset: null);

        expect(cleared.imageAsset, isNull);
        expect(cleared.name, _dalTadka.name);
      });

      test('passing a new imageAsset replaces it', () {
        expect(
          _dalTadka.copyWith(imageAsset: 'assets/new.webp').imageAsset,
          'assets/new.webp',
        );
      });

      test('rejects a non-String imageAsset at runtime', () {
        expect(
          () => _dalTadka.copyWith(imageAsset: 42),
          throwsA(isA<TypeError>()),
        );
      });
    });

    test('toString includes id and name', () {
      expect(_dalTadka.toString(), 'Recipe(dal_tadka, Dal Tadka)');
    });
  });

  group('RecipeIngredient', () {
    const line = RecipeIngredient(
      ingredientId: 'tomato',
      quantityText: '2 medium',
    );

    test('is not optional by default', () {
      expect(line.isOptional, isFalse);
    });

    test('value equality over all fields', () {
      const same = RecipeIngredient(
        ingredientId: 'tomato',
        quantityText: '2 medium',
      );

      expect(line, equals(same));
      expect(line.hashCode, same.hashCode);
    });

    test('differs by id, quantity text, or optionality', () {
      expect(
        line,
        isNot(
          equals(
            const RecipeIngredient(
              ingredientId: 'onion',
              quantityText: '2 medium',
            ),
          ),
        ),
      );
      expect(
        line,
        isNot(
          equals(
            const RecipeIngredient(
              ingredientId: 'tomato',
              quantityText: '3 medium',
            ),
          ),
        ),
      );
      expect(
        line,
        isNot(
          equals(
            const RecipeIngredient(
              ingredientId: 'tomato',
              quantityText: '2 medium',
              isOptional: true,
            ),
          ),
        ),
      );
    });
  });

  group('MealLog', () {
    final cookedAt = DateTime(2025, 6, 1, 20);
    final log = MealLog(
      id: 'm1',
      recipeId: 'dal_tadka',
      mealType: MealType.dinner,
      cookedAt: cookedAt,
    );

    test('value equality over all fields', () {
      final same = MealLog(
        id: 'm1',
        recipeId: 'dal_tadka',
        mealType: MealType.dinner,
        cookedAt: DateTime(2025, 6, 1, 20),
      );

      expect(log, equals(same));
      expect(log.hashCode, same.hashCode);
    });

    test('differs when any field differs', () {
      MealLog with_({
        String id = 'm1',
        String recipeId = 'dal_tadka',
        MealType mealType = MealType.dinner,
        DateTime? at,
      }) => MealLog(
        id: id,
        recipeId: recipeId,
        mealType: mealType,
        cookedAt: at ?? cookedAt,
      );

      expect(with_(id: 'm2'), isNot(equals(log)));
      expect(with_(recipeId: 'poha'), isNot(equals(log)));
      expect(with_(mealType: MealType.lunch), isNot(equals(log)));
      expect(
        with_(at: cookedAt.add(const Duration(minutes: 1))),
        isNot(equals(log)),
      );
    });
  });
}
