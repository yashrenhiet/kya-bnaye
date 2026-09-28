import 'package:kya_core/kya_core.dart';

// --- JSON fixtures (SeedCodec) ---

const ingredientFile = 'ingredients/sabzi.json';
const recipeFile = 'recipes/sabzi.json';

Map<String, Object?> manifestJson() => {
  'seedVersion': 1,
  'ingredients': [ingredientFile],
  'recipes': [recipeFile],
};

Map<String, Object?> potatoRow() => {
  'id': 'potato',
  'name': 'Potato',
  'aliases': ['aloo', 'batata'],
  'category': 'sabzi',
  'role': 'core',
  'buyFrom': 'sabziwala',
  'shelfLifeDays': 21,
};

Map<String, Object?> saltRow() => {
  'id': 'salt',
  'name': 'Salt',
  'aliases': <Object?>[],
  'category': 'masala',
  'role': 'staple',
  'buyFrom': 'kirana',
};

Map<String, Object?> alooRecipeRow() => {
  'id': 'jeera_aloo',
  'name': 'Jeera Aloo',
  'mealTypes': ['lunch', 'dinner'],
  'minutes': 20,
  'base': 'roti',
  'tags': <String, Object?>{
    'region': 'north',
    'dishType': 'drySabzi',
    'flavours': ['spicy', 'savoury'],
    'heaviness': 'light',
    'protein': 'vegOnly',
  },
  'ingredients': <Object?>[
    <String, Object?>{'ingredientId': 'potato', 'quantityText': '3 medium'},
    <String, Object?>{
      'ingredientId': 'salt',
      'quantityText': 'to taste',
      'isOptional': true,
    },
  ],
  'steps': ['Boil and cube the potatoes.', 'Temper jeera, toss, serve.'],
  'imageAsset': null,
};

/// A valid `jsonByPath` for [manifestJson]; mutate the returned rows to
/// build negative cases.
Map<String, Object?> fragmentsJson() => {
  ingredientFile: {
    'ingredients': [potatoRow(), saltRow()],
  },
  recipeFile: {
    'recipes': [alooRecipeRow()],
  },
};

// --- Domain fixtures (SeedValidator) ---

Ingredient ingredient(
  String id,
  String name, {
  IngredientCategory category = IngredientCategory.masala,
  IngredientRole role = IngredientRole.core,
  BuyFrom buyFrom = BuyFrom.kirana,
  List<String> aliases = const [],
  int? shelfLifeDays,
}) => Ingredient(
  id: id,
  name: name,
  aliases: aliases,
  category: category,
  role: role,
  buyFrom: buyFrom,
  shelfLifeDays: shelfLifeDays,
);

Ingredient staple(
  String id,
  String name, [
  IngredientCategory category = IngredientCategory.masala,
]) => ingredient(id, name, category: category, role: IngredientRole.staple);

/// Exactly [SeedValidator.minStaples] staples.
final List<Ingredient> fixtureStaples = [
  staple('salt', 'Salt'),
  staple('turmeric', 'Turmeric'),
  staple('red_chilli_powder', 'Red Chilli Powder'),
  staple('coriander_powder', 'Coriander Powder'),
  staple('cumin_seeds', 'Cumin Seeds'),
  staple('mustard_seeds', 'Mustard Seeds'),
  staple('asafoetida', 'Asafoetida'),
  staple('garam_masala', 'Garam Masala'),
  staple('cooking_oil', 'Cooking Oil', IngredientCategory.oilGhee),
  staple('ghee', 'Ghee', IngredientCategory.oilGhee),
  staple('sugar', 'Sugar', IngredientCategory.other),
  staple('atta', 'Atta', IngredientCategory.grains),
];

final List<Ingredient> fixtureIngredients = [
  ...fixtureStaples,
  ingredient(
    'potato',
    'Potato',
    category: IngredientCategory.sabzi,
    buyFrom: BuyFrom.sabziwala,
    aliases: ['aloo', 'batata'],
    shelfLifeDays: 21,
  ),
  ingredient(
    'onion',
    'Onion',
    category: IngredientCategory.sabzi,
    role: IngredientRole.flavor,
    buyFrom: BuyFrom.sabziwala,
    aliases: ['pyaz'],
    shelfLifeDays: 30,
  ),
  ingredient(
    'coriander_leaves',
    'Coriander Leaves',
    category: IngredientCategory.sabzi,
    role: IngredientRole.optional,
    buyFrom: BuyFrom.sabziwala,
    aliases: ['dhania'],
    shelfLifeDays: 5,
  ),
  ingredient(
    'paneer',
    'Paneer',
    category: IngredientCategory.dairy,
    buyFrom: BuyFrom.dairy,
    shelfLifeDays: 4,
  ),
  ingredient(
    'eggs',
    'Eggs',
    category: IngredientCategory.other,
    buyFrom: BuyFrom.other,
    aliases: ['anda'],
    shelfLifeDays: 21,
  ),
  ingredient('toor_dal', 'Toor Dal', category: IngredientCategory.dal),
  ingredient('rice', 'Rice', category: IngredientCategory.grains),
  ingredient('bread', 'Bread', category: IngredientCategory.grains),
  // Fruit bought from the kirana: allowed by the default I6 exemption.
  ingredient(
    'coconut',
    'Coconut',
    category: IngredientCategory.fruit,
    shelfLifeDays: 14,
  ),
];

RecipeIngredient line(String id, {bool optional = false}) =>
    RecipeIngredient(ingredientId: id, quantityText: '1', isOptional: optional);

Recipe recipe(
  String id,
  String name, {
  required DishType dishType,
  required DishBase base,
  required Protein protein,
  required List<RecipeIngredient> ingredients,
  Set<MealType> mealTypes = const {MealType.lunch, MealType.dinner},
  Set<Flavour> flavours = const {Flavour.savoury},
  Region region = Region.north,
  Heaviness heaviness = Heaviness.medium,
  int minutes = 30,
  String? imageAsset,
}) => Recipe(
  id: id,
  name: name,
  mealTypes: mealTypes,
  minutes: minutes,
  base: base,
  ingredients: ingredients,
  steps: const ['Prepare everything.', 'Cook and serve.'],
  tags: DishTags(
    region: region,
    dishType: dishType,
    flavours: flavours,
    heaviness: heaviness,
    protein: protein,
  ),
  source: RecipeSource.seed,
  imageAsset: imageAsset,
);

const jeeraRiceImage = 'assets/seed/images/jeera_rice.webp';

final List<Recipe> fixtureRecipes = [
  recipe(
    'aloo_sabzi',
    'Aloo Sabzi',
    dishType: DishType.drySabzi,
    base: DishBase.roti,
    protein: Protein.vegOnly,
    flavours: {Flavour.spicy, Flavour.savoury},
    ingredients: [
      line('potato'),
      line('onion'),
      line('salt'),
      line('coriander_leaves', optional: true),
    ],
  ),
  recipe(
    'dal_chawal',
    'Dal Chawal',
    dishType: DishType.dal,
    base: DishBase.rice,
    protein: Protein.dalLegume,
    flavours: {Flavour.mild},
    ingredients: [line('toor_dal'), line('rice'), line('turmeric')],
  ),
  recipe(
    'paneer_bhurji',
    'Paneer Bhurji',
    dishType: DishType.curry,
    base: DishBase.roti,
    protein: Protein.paneer,
    ingredients: [line('paneer'), line('onion')],
  ),
  recipe(
    'anda_bhurji',
    'Anda Bhurji',
    dishType: DishType.breakfast,
    base: DishBase.bread,
    protein: Protein.egg,
    mealTypes: {MealType.breakfast},
    ingredients: [line('eggs'), line('onion'), line('bread')],
  ),
  recipe(
    'jeera_rice',
    'Jeera Rice',
    dishType: DishType.rice,
    base: DishBase.rice,
    protein: Protein.vegOnly,
    ingredients: [line('rice'), line('cumin_seeds'), line('ghee')],
    imageAsset: jeeraRiceImage,
  ),
];

SeedBundle bundleOf({List<Ingredient>? ingredients, List<Recipe>? recipes}) =>
    SeedBundle(
      seedVersion: 1,
      ingredients: ingredients ?? fixtureIngredients,
      recipes: recipes ?? fixtureRecipes,
    );

/// [fixtureIngredients] with the row [id] replaced by `edit(row)`.
List<Ingredient> editIngredient(
  String id,
  Ingredient Function(Ingredient) edit,
) => [
  for (final i in fixtureIngredients)
    if (i.id == id) edit(i) else i,
];

/// [fixtureRecipes] with the recipe [id] replaced by `edit(recipe)`.
List<Recipe> editRecipe(String id, Recipe Function(Recipe) edit) => [
  for (final r in fixtureRecipes)
    if (r.id == id) edit(r) else r,
];
