import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

/// Local wall-clock time with sub-second precision.
final DateTime localTime = DateTime(2026, 9, 26, 19, 30, 15, 123, 456);

/// UTC instant with sub-second precision.
final DateTime utcTime = DateTime.utc(2026, 3, 1, 4, 5, 6, 789, 12);

final DateTime exportedAt = DateTime.utc(2026, 9, 26, 12);

const Ingredient seedIngredient = Ingredient(
  id: 'potato',
  name: 'Potato',
  aliases: ['aloo', 'batata'],
  category: IngredientCategory.sabzi,
  role: IngredientRole.core,
  buyFrom: BuyFrom.sabziwala,
  shelfLifeDays: 14,
);

const Ingredient bareIngredient = Ingredient(
  id: 'salt',
  name: 'Salt',
  category: IngredientCategory.masala,
  role: IngredientRole.staple,
  buyFrom: BuyFrom.kirana,
);

const Ingredient userIngredient = Ingredient(
  id: 'user_dragonfruit',
  name: 'Dragonfruit',
  aliases: ['pitaya'],
  category: IngredientCategory.fruit,
  role: IngredientRole.optional,
  buyFrom: BuyFrom.other,
  shelfLifeDays: 4,
  isUserCreated: true,
);

const Recipe fullRecipe = Recipe(
  id: 'palak_paneer',
  name: 'Palak Paneer',
  mealTypes: {MealType.lunch, MealType.dinner},
  minutes: 35,
  base: DishBase.roti,
  ingredients: [
    RecipeIngredient(ingredientId: 'paneer', quantityText: '200 g'),
    RecipeIngredient(
      ingredientId: 'cream',
      quantityText: '1 tbsp',
      isOptional: true,
    ),
  ],
  steps: ['Blanch palak', 'Blend', 'Add paneer'],
  tags: DishTags(
    region: Region.punjabi,
    dishType: DishType.curry,
    flavours: {Flavour.savoury, Flavour.mild},
    heaviness: Heaviness.heavy,
    protein: Protein.paneer,
  ),
  imageAsset: 'assets/recipes/palak_paneer.webp',
  isFavorite: true,
  isHidden: true,
  source: RecipeSource.user,
);

const Recipe bareRecipe = Recipe(
  id: 'plain_rice',
  name: 'Plain Rice',
  mealTypes: {},
  minutes: 0,
  base: DishBase.none,
  ingredients: [],
  steps: [],
  tags: DishTags(
    region: Region.indoChinese,
    dishType: DishType.onePot,
    flavours: {},
    heaviness: Heaviness.light,
    protein: Protein.vegOnly,
  ),
  source: RecipeSource.seed,
);

/// A bundle exercising every entity type and every nullable field in both
/// its null and non-null state.
BackupBundle fullBundle() => BackupBundle(
  ingredients: const [seedIngredient, bareIngredient, userIngredient],
  pantryItems: [
    PantryItem(
      ingredientId: 'potato',
      level: StockLevel.plenty,
      updatedAt: localTime,
      expiresOn: DateTime(2026, 10, 10),
      expiryIsEstimated: true,
    ),
    PantryItem(ingredientId: 'salt', level: StockLevel.low, updatedAt: utcTime),
    PantryItem(
      ingredientId: 'user_dragonfruit',
      level: StockLevel.out,
      updatedAt: localTime,
      expiresOn: utcTime,
    ),
  ],
  recipes: const [fullRecipe, bareRecipe],
  mealLogs: [
    MealLog(
      id: 'm1',
      recipeId: 'palak_paneer',
      mealType: MealType.dinner,
      cookedAt: localTime,
    ),
    MealLog(
      id: 'm2',
      recipeId: 'plain_rice',
      mealType: MealType.breakfast,
      cookedAt: utcTime,
    ),
  ],
  swipeEvents: [
    SwipeEvent(
      id: 'e1',
      recipeId: 'palak_paneer',
      action: SwipeAction.right,
      mode: SwipeMode.kitchen,
      at: localTime,
      deckSeed: 42,
    ),
    SwipeEvent(
      id: 'e2',
      recipeId: 'palak_paneer',
      action: SwipeAction.undo,
      mode: SwipeMode.craving,
      at: utcTime,
      deckSeed: -7,
      undoesEventId: 'e1',
    ),
    SwipeEvent(
      id: 'e3',
      recipeId: 'plain_rice',
      action: SwipeAction.neverShow,
      mode: SwipeMode.craving,
      at: localTime,
      deckSeed: 0,
    ),
    SwipeEvent(
      id: 'e4',
      recipeId: 'plain_rice',
      action: SwipeAction.left,
      mode: SwipeMode.kitchen,
      at: localTime,
      deckSeed: 1,
    ),
  ],
  shoppingItems: [
    ShoppingItem(
      id: 's1',
      ingredientId: 'potato',
      reason: ShoppingReason.low,
      isChecked: false,
      createdAt: localTime,
    ),
    ShoppingItem(
      id: 's2',
      ingredientId: 'paneer',
      reason: ShoppingReason.recipe,
      recipeId: 'palak_paneer',
      isChecked: true,
      createdAt: utcTime,
    ),
    ShoppingItem(
      id: 's3',
      customName: 'Birthday candles',
      reason: ShoppingReason.manual,
      isChecked: false,
      createdAt: localTime,
    ),
    ShoppingItem(
      id: 's4',
      ingredientId: 'salt',
      reason: ShoppingReason.out,
      isChecked: false,
      createdAt: localTime,
    ),
  ],
);

/// [Ingredient] and [Recipe] equality is id-only, so round-trip checks
/// compare every field explicitly.
void expectIngredientsEqual(List<Ingredient> actual, List<Ingredient> want) {
  expect(actual, hasLength(want.length));
  for (var i = 0; i < want.length; i++) {
    final a = actual[i];
    final w = want[i];
    expect(a.id, w.id);
    expect(a.name, w.name);
    expect(a.aliases, w.aliases);
    expect(a.category, w.category);
    expect(a.role, w.role);
    expect(a.buyFrom, w.buyFrom);
    expect(a.shelfLifeDays, w.shelfLifeDays);
    expect(a.isUserCreated, w.isUserCreated);
  }
}

void expectRecipesEqual(List<Recipe> actual, List<Recipe> want) {
  expect(actual, hasLength(want.length));
  for (var i = 0; i < want.length; i++) {
    final a = actual[i];
    final w = want[i];
    expect(a.id, w.id);
    expect(a.name, w.name);
    expect(a.mealTypes, w.mealTypes);
    expect(a.minutes, w.minutes);
    expect(a.base, w.base);
    expect(a.ingredients, w.ingredients);
    expect(a.steps, w.steps);
    expect(a.tags, w.tags);
    expect(a.imageAsset, w.imageAsset);
    expect(a.isFavorite, w.isFavorite);
    expect(a.isHidden, w.isHidden);
    expect(a.source, w.source);
  }
}

/// Asserts that every entity in [actual] matches [want], field by field.
void expectBundlesEqual(BackupBundle actual, BackupBundle want) {
  expectIngredientsEqual(actual.ingredients, want.ingredients);
  expectRecipesEqual(actual.recipes, want.recipes);
  // The remaining types have full value equality, which also compares
  // DateTime.isUtc.
  expect(actual.pantryItems, want.pantryItems);
  expect(actual.mealLogs, want.mealLogs);
  expect(actual.swipeEvents, want.swipeEvents);
  expect(actual.shoppingItems, want.shoppingItems);
}
