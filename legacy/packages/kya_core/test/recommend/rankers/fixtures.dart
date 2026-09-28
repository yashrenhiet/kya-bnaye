/// Shared, hand-checkable fixtures for the ranker and deck-builder tests:
/// a small realistic Indian kitchen catalog, 13 everyday recipes, and
/// helpers for building pantries, swipe events and meal logs against a
/// fixed clock (never `DateTime.now()`).
library;

import 'package:kya_core/kya_core.dart';

// --- Fixed clocks -----------------------------------------------------------

/// Wednesday 23 Sep 2026, 19:00: a weekday dinner.
final DateTime weekdayDinner = DateTime(2026, 9, 23, 19);

/// Wednesday 23 Sep 2026, 08:00: a weekday breakfast.
final DateTime weekdayBreakfast = DateTime(2026, 9, 23, 8);

/// Saturday 26 Sep 2026, 19:00: a weekend dinner (no "quick" bonus in
/// Craving mode).
final DateTime saturdayDinner = DateTime(2026, 9, 26, 19);

/// [now] minus a (possibly fractional) number of days.
DateTime daysBefore(DateTime now, num days) =>
    now.subtract(Duration(minutes: (days * 24 * 60).round()));

/// [now] plus a whole number of days (for expiry dates).
DateTime daysAfter(DateTime now, int days) => now.add(Duration(days: days));

// --- Catalog ----------------------------------------------------------------

Ingredient _ingredient(
  String id,
  String name,
  IngredientRole role, {
  IngredientCategory category = IngredientCategory.other,
  BuyFrom buyFrom = BuyFrom.kirana,
}) {
  return Ingredient(
    id: id,
    name: name,
    category: category,
    role: role,
    buyFrom: buyFrom,
  );
}

const IngredientRole _core = IngredientRole.core;
const IngredientRole _flavor = IngredientRole.flavor;
const IngredientRole _optional = IngredientRole.optional;
const IngredientRole _staple = IngredientRole.staple;
const IngredientCategory _sabzi = IngredientCategory.sabzi;
const IngredientCategory _dairy = IngredientCategory.dairy;
const IngredientCategory _grains = IngredientCategory.grains;
const IngredientCategory _dal = IngredientCategory.dal;
const IngredientCategory _masala = IngredientCategory.masala;

/// ~30 ingredients covering every [IngredientRole].
final List<Ingredient> catalog = [
  // Core.
  _ingredient('potato', 'Potato', _core, category: _sabzi),
  _ingredient('matar', 'Matar', _core, category: _sabzi),
  _ingredient('palak', 'Palak', _core, category: _sabzi),
  _ingredient('cabbage', 'Cabbage', _core, category: _sabzi),
  _ingredient('paneer', 'Paneer', _core, category: _dairy),
  _ingredient('curd', 'Curd', _core, category: _dairy),
  _ingredient('egg', 'Egg', _core),
  _ingredient('rice', 'Rice', _core, category: _grains),
  _ingredient('poha', 'Poha', _core, category: _grains),
  _ingredient('rava', 'Rava', _core, category: _grains),
  _ingredient('besan', 'Besan', _core, category: _grains),
  _ingredient('dosa_batter', 'Dosa batter', _core),
  _ingredient('noodles', 'Noodles', _core),
  _ingredient('toor_dal', 'Toor dal', _core, category: _dal),
  _ingredient('rajma', 'Rajma', _core, category: _dal),
  _ingredient('chana', 'Kabuli chana', _core, category: _dal),
  // Flavour.
  _ingredient('onion', 'Onion', _flavor, category: _sabzi),
  _ingredient('tomato', 'Tomato', _flavor, category: _sabzi),
  _ingredient('ginger_garlic', 'Ginger-garlic', _flavor, category: _sabzi),
  _ingredient('green_chilli', 'Green chilli', _flavor, category: _sabzi),
  _ingredient('lemon', 'Lemon', _flavor, category: _sabzi),
  _ingredient('curry_leaves', 'Curry leaves', _flavor, category: _sabzi),
  _ingredient('garam_masala', 'Garam masala', _flavor, category: _masala),
  _ingredient('kasuri_methi', 'Kasuri methi', _flavor, category: _masala),
  _ingredient('soy_sauce', 'Soy sauce', _flavor),
  // Optional (garnish).
  _ingredient('coriander', 'Coriander', _optional, category: _sabzi),
  _ingredient('cream', 'Cream', _optional, category: _dairy),
  // Staples (assumed present unless marked Out).
  _ingredient('salt', 'Salt', _staple, category: _masala),
  _ingredient('oil', 'Oil', _staple, category: IngredientCategory.oilGhee),
  _ingredient('haldi', 'Haldi', _staple, category: _masala),
  _ingredient('jeera', 'Jeera', _staple, category: _masala),
];

// --- Recipes ----------------------------------------------------------------

const Set<MealType> _lunchDinner = {MealType.lunch, MealType.dinner};

Recipe _recipe({
  required String id,
  required String name,
  required Set<MealType> meals,
  required int minutes,
  required DishBase base,
  required List<String> required,
  required DishTags tags,
  List<String> optional = const [],
}) {
  return Recipe(
    id: id,
    name: name,
    mealTypes: meals,
    minutes: minutes,
    base: base,
    ingredients: [
      for (final i in required)
        RecipeIngredient(ingredientId: i, quantityText: 'as needed'),
      for (final i in optional)
        RecipeIngredient(
          ingredientId: i,
          quantityText: 'to garnish',
          isOptional: true,
        ),
    ],
    steps: const ['Cook it the way ghar pe banta hai.'],
    tags: tags,
    source: RecipeSource.seed,
  );
}

/// 13 everyday recipes. Required-ingredient order matters: it is the order
/// "Missing: ..." explanations list them in.
final List<Recipe> recipes = [
  _recipe(
    id: 'aloo_matar',
    name: 'Aloo Matar',
    meals: _lunchDinner,
    minutes: 30,
    base: DishBase.roti,
    required: ['potato', 'matar', 'onion', 'tomato', 'salt', 'oil', 'haldi'],
    optional: ['coriander'],
    tags: const DishTags(
      region: Region.north,
      dishType: DishType.curry,
      flavours: {Flavour.spicy, Flavour.savoury},
      heaviness: Heaviness.medium,
      protein: Protein.vegOnly,
    ),
  ),
  _recipe(
    id: 'palak_paneer',
    name: 'Palak Paneer',
    meals: _lunchDinner,
    minutes: 35,
    base: DishBase.roti,
    required: [
      'palak',
      'paneer',
      'onion',
      'ginger_garlic',
      'kasuri_methi',
      'salt',
      'oil',
    ],
    optional: ['cream'],
    tags: const DishTags(
      region: Region.north,
      dishType: DishType.curry,
      flavours: {Flavour.savoury, Flavour.mild},
      heaviness: Heaviness.medium,
      protein: Protein.paneer,
    ),
  ),
  _recipe(
    id: 'dal_tadka',
    name: 'Dal Tadka',
    meals: _lunchDinner,
    minutes: 30,
    base: DishBase.none,
    required: ['toor_dal', 'onion', 'tomato', 'jeera', 'haldi', 'salt', 'oil'],
    optional: ['coriander'],
    tags: const DishTags(
      region: Region.north,
      dishType: DishType.dal,
      flavours: {Flavour.savoury, Flavour.spicy},
      heaviness: Heaviness.light,
      protein: Protein.dalLegume,
    ),
  ),
  _recipe(
    id: 'jeera_rice',
    name: 'Jeera Rice',
    meals: _lunchDinner,
    minutes: 20,
    base: DishBase.rice,
    required: ['rice', 'jeera', 'oil', 'salt'],
    tags: const DishTags(
      region: Region.north,
      dishType: DishType.rice,
      flavours: {Flavour.savoury, Flavour.mild},
      heaviness: Heaviness.light,
      protein: Protein.vegOnly,
    ),
  ),
  _recipe(
    id: 'rajma_chawal',
    name: 'Rajma Chawal',
    meals: _lunchDinner,
    minutes: 60,
    base: DishBase.rice,
    required: [
      'rajma',
      'rice',
      'onion',
      'tomato',
      'ginger_garlic',
      'garam_masala',
      'salt',
      'oil',
    ],
    tags: const DishTags(
      region: Region.punjabi,
      dishType: DishType.curry,
      flavours: {Flavour.spicy, Flavour.savoury},
      heaviness: Heaviness.heavy,
      protein: Protein.dalLegume,
    ),
  ),
  _recipe(
    id: 'chole_bhature',
    name: 'Chole Bhature',
    meals: _lunchDinner,
    minutes: 50,
    base: DishBase.bread,
    required: [
      'chana',
      'onion',
      'tomato',
      'ginger_garlic',
      'garam_masala',
      'salt',
      'oil',
    ],
    tags: const DishTags(
      region: Region.punjabi,
      dishType: DishType.curry,
      flavours: {Flavour.spicy, Flavour.tangy},
      heaviness: Heaviness.heavy,
      protein: Protein.dalLegume,
    ),
  ),
  _recipe(
    id: 'masala_dosa',
    name: 'Masala Dosa',
    meals: const {MealType.breakfast, MealType.lunch},
    minutes: 40,
    base: DishBase.none,
    required: [
      'dosa_batter',
      'potato',
      'onion',
      'green_chilli',
      'curry_leaves',
      'salt',
      'oil',
    ],
    tags: const DishTags(
      region: Region.south,
      dishType: DishType.breakfast,
      flavours: {Flavour.savoury, Flavour.spicy},
      heaviness: Heaviness.medium,
      protein: Protein.vegOnly,
    ),
  ),
  _recipe(
    id: 'lemon_rice',
    name: 'Lemon Rice',
    meals: _lunchDinner,
    minutes: 20,
    base: DishBase.rice,
    required: ['rice', 'lemon', 'curry_leaves', 'haldi', 'salt', 'oil'],
    tags: const DishTags(
      region: Region.south,
      dishType: DishType.rice,
      flavours: {Flavour.tangy, Flavour.savoury},
      heaviness: Heaviness.light,
      protein: Protein.vegOnly,
    ),
  ),
  _recipe(
    id: 'poha',
    name: 'Kanda Poha',
    meals: const {MealType.breakfast, MealType.snack},
    minutes: 15,
    base: DishBase.none,
    required: ['poha', 'onion', 'green_chilli', 'haldi', 'salt', 'oil'],
    optional: ['lemon', 'coriander'],
    tags: const DishTags(
      region: Region.west,
      dishType: DishType.breakfast,
      flavours: {Flavour.savoury, Flavour.mild},
      heaviness: Heaviness.light,
      protein: Protein.vegOnly,
    ),
  ),
  _recipe(
    id: 'upma',
    name: 'Upma',
    meals: const {MealType.breakfast},
    minutes: 20,
    base: DishBase.none,
    required: ['rava', 'onion', 'green_chilli', 'curry_leaves', 'salt', 'oil'],
    tags: const DishTags(
      region: Region.south,
      dishType: DishType.breakfast,
      flavours: {Flavour.savoury, Flavour.mild},
      heaviness: Heaviness.light,
      protein: Protein.vegOnly,
    ),
  ),
  _recipe(
    id: 'egg_curry',
    name: 'Egg Curry',
    meals: _lunchDinner,
    minutes: 35,
    base: DishBase.rice,
    required: [
      'egg',
      'onion',
      'tomato',
      'ginger_garlic',
      'garam_masala',
      'haldi',
      'salt',
      'oil',
    ],
    tags: const DishTags(
      region: Region.east,
      dishType: DishType.curry,
      flavours: {Flavour.spicy, Flavour.savoury},
      heaviness: Heaviness.medium,
      protein: Protein.egg,
    ),
  ),
  _recipe(
    id: 'dhokla',
    name: 'Khaman Dhokla',
    meals: const {MealType.breakfast, MealType.snack},
    minutes: 30,
    base: DishBase.none,
    required: ['besan', 'curd', 'lemon', 'green_chilli', 'salt', 'oil'],
    tags: const DishTags(
      region: Region.gujarati,
      dishType: DishType.snack,
      flavours: {Flavour.sweet, Flavour.tangy},
      heaviness: Heaviness.light,
      protein: Protein.vegOnly,
    ),
  ),
  _recipe(
    id: 'veg_hakka_noodles',
    name: 'Veg Hakka Noodles',
    meals: const {MealType.dinner, MealType.snack},
    minutes: 25,
    base: DishBase.none,
    required: [
      'noodles',
      'cabbage',
      'soy_sauce',
      'ginger_garlic',
      'oil',
      'salt',
    ],
    tags: const DishTags(
      region: Region.indoChinese,
      dishType: DishType.onePot,
      flavours: {Flavour.spicy, Flavour.savoury},
      heaviness: Heaviness.medium,
      protein: Protein.vegOnly,
    ),
  ),
];

/// Looks up a fixture recipe by id; throws on a typo so tests fail loudly.
Recipe recipe(String id) => recipes.firstWhere((r) => r.id == id);

// --- Pantry -----------------------------------------------------------------

/// One pantry row. Stocked a week before the fixed clocks.
PantryItem have(
  String ingredientId, {
  StockLevel level = StockLevel.plenty,
  DateTime? expiresOn,
}) {
  return PantryItem(
    ingredientId: ingredientId,
    level: level,
    updatedAt: DateTime(2026, 9, 16),
    expiresOn: expiresOn,
  );
}

/// Every id in [ids] at [StockLevel.plenty], no expiry.
List<PantryItem> haveAll(List<String> ids) => [for (final id in ids) have(id)];

/// [ingredientId] explicitly marked Out.
PantryItem out(String ingredientId) =>
    have(ingredientId, level: StockLevel.out);

// --- History ----------------------------------------------------------------

SwipeEvent _event(String recipeId, SwipeAction action, DateTime at) {
  return SwipeEvent(
    id: '${action.name}-$recipeId-${at.toIso8601String()}',
    recipeId: recipeId,
    action: action,
    mode: SwipeMode.craving,
    at: at,
    deckSeed: 1,
  );
}

SwipeEvent right(String recipeId, DateTime at) =>
    _event(recipeId, SwipeAction.right, at);

SwipeEvent left(String recipeId, DateTime at) =>
    _event(recipeId, SwipeAction.left, at);

SwipeEvent neverShow(String recipeId, DateTime at) =>
    _event(recipeId, SwipeAction.neverShow, at);

MealLog cooked(String recipeId, DateTime at) {
  return MealLog(
    id: 'cook-$recipeId-${at.toIso8601String()}',
    recipeId: recipeId,
    mealType: MealType.dinner,
    cookedAt: at,
  );
}

// --- Ranking helpers --------------------------------------------------------

/// A [RankingContext] over the fixture catalog. [allRecipes] defaults to
/// the 13 fixture recipes, which fixes every ingredient's rarity bonus.
RankingContext contextFor({
  required DateTime now,
  List<PantryItem> pantry = const [],
  List<SwipeEvent> events = const [],
  List<MealLog> meals = const [],
  MealType? mealType,
  ScoringConfig config = const ScoringConfig(),
  List<Recipe>? allRecipes,
}) {
  return RankingContext.build(
    allRecipes: allRecipes ?? recipes,
    pantry: pantry,
    catalog: catalog,
    events: events,
    mealLogs: meals,
    now: now,
    config: config,
    currentMealType: mealType,
  );
}

/// Builds a full deck over [candidates] (defaults to every fixture recipe).
List<ScoredRecipe> deckFor(
  RankingContext context,
  RankingStrategy strategy, {
  List<Recipe>? candidates,
  int seed = 7,
}) {
  return const DeckBuilder().build(
    candidates: candidates ?? recipes,
    context: context,
    strategy: strategy,
    seed: seed,
  );
}

List<String> idsOf(Iterable<ScoredRecipe> cards) => [
  for (final c in cards) c.recipe.id,
];

List<RecipeTier?> tiersOf(Iterable<ScoredRecipe> cards) => [
  for (final c in cards) c.tier,
];

/// A recipe with no ingredients (so every pantry reads as "ready" and the
/// pantry hint is 1.0), available at every meal, not quick — used where
/// only tags and scores matter, e.g. deck composition.
Recipe syntheticRecipe(String id, DishTags tags) {
  return Recipe(
    id: id,
    name: 'Dish $id',
    mealTypes: MealType.values.toSet(),
    minutes: 45,
    base: DishBase.none,
    ingredients: const [],
    steps: const ['Cook.'],
    tags: tags,
    source: RecipeSource.user,
  );
}
