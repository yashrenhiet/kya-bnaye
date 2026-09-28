import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

final _now = DateTime(2026, 9, 26, 19);
final _earlier = DateTime(2026, 9, 20, 8, 30);

const _potato = Ingredient(
  id: 'potato',
  name: 'Potato',
  aliases: ['aloo'],
  category: IngredientCategory.sabzi,
  role: IngredientRole.core,
  buyFrom: BuyFrom.sabziwala,
  shelfLifeDays: 14,
);
const _onion = Ingredient(
  id: 'onion',
  name: 'Onion',
  category: IngredientCategory.sabzi,
  role: IngredientRole.core,
  buyFrom: BuyFrom.sabziwala,
);
const _paneer = Ingredient(
  id: 'paneer',
  name: 'Paneer',
  category: IngredientCategory.dairy,
  role: IngredientRole.core,
  buyFrom: BuyFrom.dairy,
  shelfLifeDays: 5,
);
const _jeera = Ingredient(
  id: 'jeera',
  name: 'Jeera',
  category: IngredientCategory.masala,
  role: IngredientRole.flavor,
  buyFrom: BuyFrom.kirana,
);
const _salt = Ingredient(
  id: 'salt',
  name: 'Salt',
  category: IngredientCategory.masala,
  role: IngredientRole.staple,
  buyFrom: BuyFrom.kirana,
);
const _oil = Ingredient(
  id: 'oil',
  name: 'Oil',
  category: IngredientCategory.oilGhee,
  role: IngredientRole.staple,
  buyFrom: BuyFrom.kirana,
);
const _dragonfruit = Ingredient(
  id: 'dragonfruit',
  name: 'Dragonfruit',
  category: IngredientCategory.fruit,
  role: IngredientRole.core,
  buyFrom: BuyFrom.other,
  isUserCreated: true,
);

final Map<String, Ingredient> _catalog = {
  for (final i in const [
    _potato,
    _onion,
    _paneer,
    _jeera,
    _salt,
    _oil,
    _dragonfruit,
  ])
    i.id: i,
};

PantryItem _pantry(String id, StockLevel level) =>
    PantryItem(ingredientId: id, level: level, updatedAt: _earlier);

Recipe _recipe(String id, List<RecipeIngredient> ingredients) => Recipe(
  id: id,
  name: id,
  mealTypes: const {MealType.dinner},
  minutes: 20,
  base: DishBase.roti,
  ingredients: ingredients,
  steps: const ['Cook'],
  tags: const DishTags(
    region: Region.north,
    dishType: DishType.curry,
    flavours: {Flavour.savoury},
    heaviness: Heaviness.medium,
    protein: Protein.vegOnly,
  ),
  source: RecipeSource.seed,
);

RecipeIngredient _ri(String id, {bool optional = false}) =>
    RecipeIngredient(ingredientId: id, quantityText: '1', isOptional: optional);

ShoppingItem _existing({
  required String id,
  String? ingredientId,
  String? customName,
  ShoppingReason reason = ShoppingReason.manual,
  bool isChecked = false,
}) => ShoppingItem(
  id: id,
  ingredientId: ingredientId,
  customName: customName,
  reason: reason,
  isChecked: isChecked,
  createdAt: _earlier,
);

/// Deterministic id source that also records how often it was called.
class _Ids {
  int calls = 0;
  String next() => 'shop_${calls++}';
}

void main() {
  const builder = ShoppingListBuilder();

  List<ShoppingItem> build({
    List<PantryItem> pantry = const [],
    List<ShoppingItem> existing = const [],
    List<Recipe> recipes = const [],
    Map<String, Ingredient>? catalog,
    _Ids? ids,
  }) {
    final idSource = ids ?? _Ids();
    return builder.build(
      pantry: pantry,
      ingredientsById: catalog ?? _catalog,
      existingItems: existing,
      recipesToShopFor: recipes,
      now: _now,
      nextId: idSource.next,
    );
  }

  group('ShoppingListBuilder.build', () {
    group('empty inputs', () {
      test('returns an empty list and never calls nextId', () {
        final ids = _Ids();
        final result = build(ids: ids);
        expect(result, isEmpty);
        expect(ids.calls, 0);
      });

      test('empty catalog skips every pantry item', () {
        final result = build(
          catalog: const {},
          pantry: [_pantry('potato', StockLevel.out)],
        );
        expect(result, isEmpty);
      });

      test('recipe with no ingredients adds nothing', () {
        expect(build(recipes: [_recipe('plain', const [])]), isEmpty);
      });
    });

    group('pantry stock levels', () {
      test('Out item is listed with reason out', () {
        final result = build(pantry: [_pantry('paneer', StockLevel.out)]);
        expect(result, [
          ShoppingItem(
            id: 'shop_0',
            ingredientId: 'paneer',
            reason: ShoppingReason.out,
            isChecked: false,
            createdAt: _now,
          ),
        ]);
      });

      test('Low item is listed with reason low', () {
        final result = build(pantry: [_pantry('onion', StockLevel.low)]);
        expect(result, hasLength(1));
        expect(result.single.ingredientId, 'onion');
        expect(result.single.reason, ShoppingReason.low);
      });

      test('Plenty item is excluded', () {
        final ids = _Ids();
        final result = build(
          pantry: [_pantry('potato', StockLevel.plenty)],
          ids: ids,
        );
        expect(result, isEmpty);
        expect(ids.calls, 0);
      });

      test('auto items carry no customName or recipeId, are unchecked and '
          'stamped with now', () {
        final item = build(pantry: [_pantry('onion', StockLevel.out)]).single;
        expect(item.customName, isNull);
        expect(item.recipeId, isNull);
        expect(item.isChecked, isFalse);
        expect(item.createdAt, _now);
      });

      test('mixed levels keep pantry order', () {
        final result = build(
          pantry: [
            _pantry('potato', StockLevel.plenty),
            _pantry('paneer', StockLevel.out),
            _pantry('onion', StockLevel.low),
          ],
        );
        expect(result.map((i) => i.ingredientId), ['paneer', 'onion']);
        expect(result.map((i) => i.reason), [
          ShoppingReason.out,
          ShoppingReason.low,
        ]);
      });

      test('pantry item whose ingredient is not in the catalog is skipped', () {
        final ids = _Ids();
        final result = build(
          pantry: [_pantry('ghost', StockLevel.out)],
          ids: ids,
        );
        expect(result, isEmpty);
        expect(ids.calls, 0);
      });

      test('user-created ingredient that is Out is listed', () {
        final result = build(pantry: [_pantry('dragonfruit', StockLevel.out)]);
        expect(result.single.ingredientId, 'dragonfruit');
      });
    });

    group('recipes to shop for', () {
      test('ingredient with no pantry record is added as recipe item', () {
        final result = build(
          recipes: [
            _recipe('aloo_sabzi', [_ri('potato')]),
          ],
        );
        expect(result, [
          ShoppingItem(
            id: 'shop_0',
            ingredientId: 'potato',
            reason: ShoppingReason.recipe,
            recipeId: 'aloo_sabzi',
            isChecked: false,
            createdAt: _now,
          ),
        ]);
      });

      test('Plenty and Low ingredients count as available', () {
        final result = build(
          pantry: [_pantry('potato', StockLevel.plenty)],
          recipes: [
            _recipe('aloo_sabzi', [_ri('potato')]),
          ],
        );
        expect(result, isEmpty);
      });

      test('Low ingredient is listed once, as low, not as recipe', () {
        final result = build(
          pantry: [_pantry('onion', StockLevel.low)],
          recipes: [
            _recipe('pyaaz', [_ri('onion')]),
          ],
        );
        expect(result, hasLength(1));
        expect(result.single.reason, ShoppingReason.low);
        expect(result.single.recipeId, isNull);
      });

      test('Out ingredient is listed once, as out, not as recipe', () {
        final result = build(
          pantry: [_pantry('paneer', StockLevel.out)],
          recipes: [
            _recipe('palak_paneer', [_ri('paneer')]),
          ],
        );
        expect(result, hasLength(1));
        expect(result.single.reason, ShoppingReason.out);
      });

      test('optional recipe ingredients are never added', () {
        final ids = _Ids();
        final result = build(
          recipes: [
            _recipe('aloo_sabzi', [
              _ri('potato'),
              _ri('jeera', optional: true),
            ]),
          ],
          ids: ids,
        );
        expect(result.map((i) => i.ingredientId), ['potato']);
        expect(ids.calls, 1);
      });

      test('ingredient unknown to the catalog is still added', () {
        final result = build(
          recipes: [
            _recipe('mystery', [_ri('saffron')]),
          ],
        );
        expect(result.single.ingredientId, 'saffron');
        expect(result.single.reason, ShoppingReason.recipe);
        expect(result.single.recipeId, 'mystery');
      });

      test('ingredient shared by two recipes is listed once, for the '
          'first recipe', () {
        final result = build(
          recipes: [
            _recipe('palak_paneer', [_ri('paneer')]),
            _recipe('paneer_tikka', [_ri('paneer'), _ri('onion')]),
          ],
        );
        expect(result.map((i) => i.ingredientId), ['paneer', 'onion']);
        expect(result.map((i) => i.recipeId), ['palak_paneer', 'paneer_tikka']);
      });

      test('ingredient repeated within one recipe is listed once', () {
        final result = build(
          recipes: [
            _recipe('double', [_ri('potato'), _ri('potato')]),
          ],
        );
        expect(result, hasLength(1));
      });
    });

    group('staples', () {
      test('staple with no pantry record is assumed available', () {
        final result = build(
          recipes: [
            _recipe('aloo_sabzi', [_ri('salt'), _ri('oil')]),
          ],
        );
        expect(result, isEmpty);
      });

      test('staple marked Plenty or Low is available for recipes', () {
        final result = build(
          pantry: [_pantry('salt', StockLevel.plenty)],
          recipes: [
            _recipe('aloo_sabzi', [_ri('salt')]),
          ],
        );
        expect(result, isEmpty);
      });

      test('staple explicitly marked Out is listed once with reason out', () {
        final result = build(
          pantry: [_pantry('salt', StockLevel.out)],
          recipes: [
            _recipe('aloo_sabzi', [_ri('salt')]),
          ],
        );
        expect(result, hasLength(1));
        expect(result.single.ingredientId, 'salt');
        expect(result.single.reason, ShoppingReason.out);
      });

      test('staple marked Low is listed from the pantry with reason low', () {
        final result = build(pantry: [_pantry('oil', StockLevel.low)]);
        expect(result.single.ingredientId, 'oil');
        expect(result.single.reason, ShoppingReason.low);
      });
    });

    group('dedupe against existing items', () {
      test('unchecked existing item blocks a duplicate pantry row', () {
        final ids = _Ids();
        final result = build(
          pantry: [_pantry('paneer', StockLevel.out)],
          existing: [
            _existing(
              id: 'old_1',
              ingredientId: 'paneer',
              reason: ShoppingReason.out,
            ),
          ],
          ids: ids,
        );
        expect(result, isEmpty);
        expect(ids.calls, 0);
      });

      test('unchecked existing manual item blocks a duplicate recipe row', () {
        final result = build(
          recipes: [
            _recipe('palak_paneer', [_ri('paneer'), _ri('onion')]),
          ],
          existing: [_existing(id: 'old_1', ingredientId: 'paneer')],
        );
        expect(result.map((i) => i.ingredientId), ['onion']);
      });

      test('checked (bought) existing item does not block re-listing', () {
        final result = build(
          pantry: [_pantry('paneer', StockLevel.out)],
          existing: [
            _existing(id: 'old_1', ingredientId: 'paneer', isChecked: true),
          ],
        );
        expect(result.single.ingredientId, 'paneer');
        expect(result.single.id, 'shop_0');
      });

      test('custom-name items never block catalog ingredients', () {
        final result = build(
          pantry: [_pantry('paneer', StockLevel.out)],
          existing: [_existing(id: 'old_1', customName: 'paneer')],
        );
        expect(result.single.ingredientId, 'paneer');
      });

      test('existing items are neither returned nor modified', () {
        final existing = [
          _existing(id: 'old_1', customName: 'Birthday candles'),
          _existing(id: 'old_2', ingredientId: 'paneer'),
          _existing(id: 'old_3', ingredientId: 'onion', isChecked: true),
        ];
        final snapshot = List<ShoppingItem>.of(existing);
        final result = build(
          pantry: [
            _pantry('paneer', StockLevel.out),
            _pantry('potato', StockLevel.low),
          ],
          existing: existing,
        );
        expect(result.map((i) => i.ingredientId), ['potato']);
        expect(result.map((i) => i.id), isNot(contains(startsWith('old_'))));
        expect(existing, snapshot);
      });
    });

    group('ids', () {
      test('nextId is called once per added item, pantry rows first', () {
        final ids = _Ids();
        final result = build(
          pantry: [
            _pantry('paneer', StockLevel.out),
            _pantry('potato', StockLevel.plenty),
            _pantry('onion', StockLevel.low),
          ],
          recipes: [
            _recipe('mix', [_ri('potato'), _ri('jeera'), _ri('paneer')]),
            _recipe('fruit', [_ri('dragonfruit')]),
          ],
          ids: ids,
        );
        expect(result.map((i) => i.id), [
          'shop_0',
          'shop_1',
          'shop_2',
          'shop_3',
        ]);
        expect(result.map((i) => i.ingredientId), [
          'paneer',
          'onion',
          'jeera',
          'dragonfruit',
        ]);
        expect(ids.calls, 4);
      });

      test('same inputs produce identical output', () {
        List<ShoppingItem> run() => build(
          pantry: [_pantry('paneer', StockLevel.out)],
          recipes: [
            _recipe('aloo_sabzi', [_ri('potato')]),
          ],
        );
        expect(run(), run());
      });
    });
  });

  group('ShoppingListBuilder.groupByVendor', () {
    ShoppingItem item(String id, {String? ingredientId, String? custom}) =>
        ShoppingItem(
          id: id,
          ingredientId: ingredientId,
          customName: custom,
          reason: ShoppingReason.manual,
          isChecked: false,
          createdAt: _now,
        );

    test('empty items yield all four vendors with empty lists', () {
      final grouped = builder.groupByVendor(
        items: const [],
        ingredientsById: _catalog,
      );
      expect(grouped.keys, BuyFrom.values);
      for (final list in grouped.values) {
        expect(list, isEmpty);
      }
    });

    test('maps each item to its ingredient vendor', () {
      final potato = item('1', ingredientId: 'potato');
      final paneer = item('2', ingredientId: 'paneer');
      final salt = item('3', ingredientId: 'salt');
      final dragon = item('4', ingredientId: 'dragonfruit');
      final grouped = builder.groupByVendor(
        items: [potato, paneer, salt, dragon],
        ingredientsById: _catalog,
      );
      expect(grouped, {
        BuyFrom.sabziwala: [potato],
        BuyFrom.kirana: [salt],
        BuyFrom.dairy: [paneer],
        BuyFrom.other: [dragon],
      });
    });

    test('custom-name items go to other', () {
      final candles = item('1', custom: 'Birthday candles');
      final grouped = builder.groupByVendor(
        items: [candles],
        ingredientsById: _catalog,
      );
      expect(grouped[BuyFrom.other], [candles]);
    });

    test('unknown ingredient ids go to other', () {
      final ghost = item('1', ingredientId: 'ghost');
      final grouped = builder.groupByVendor(
        items: [ghost],
        ingredientsById: _catalog,
      );
      expect(grouped[BuyFrom.other], [ghost]);
      expect(grouped[BuyFrom.kirana], isEmpty);
    });

    test('preserves input order within a vendor', () {
      final onion = item('1', ingredientId: 'onion');
      final potato = item('2', ingredientId: 'potato');
      final grouped = builder.groupByVendor(
        items: [onion, potato],
        ingredientsById: _catalog,
      );
      expect(grouped[BuyFrom.sabziwala], [onion, potato]);
    });

    test('every input item appears in exactly one group', () {
      final items = [
        item('1', ingredientId: 'potato'),
        item('2', ingredientId: 'ghost'),
        item('3', custom: 'Foil'),
        item('4', ingredientId: 'jeera'),
      ];
      final grouped = builder.groupByVendor(
        items: items,
        ingredientsById: _catalog,
      );
      final flattened = grouped.values.expand((l) => l).toList();
      expect(flattened, unorderedEquals(items));
    });
  });
}
