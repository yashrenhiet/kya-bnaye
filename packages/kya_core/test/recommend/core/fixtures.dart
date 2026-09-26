/// Shared builders for the recommender core unit tests.
///
/// Every builder takes only the fields a test cares about and fills the
/// rest with neutral defaults, so each test reads as "given exactly this".
library;

import 'package:kya_core/kya_core.dart';

/// A fixed, DST-free reference instant (IST has no DST, and late September
/// is outside every northern-hemisphere DST switch) used as `now`.
final DateTime refNow = DateTime(2026, 9, 26, 12);

/// [refNow] minus [days] *calendar* days, at [hour]:[minute] local time.
///
/// Built from date parts rather than `Duration` subtraction so the result
/// is the same calendar day in every time zone, DST or not.
DateTime daysAgo(int days, {int hour = 12, int minute = 0}) =>
    DateTime(refNow.year, refNow.month, refNow.day - days, hour, minute);

/// Exact elapsed-time offset from [refNow], for decay maths that is defined
/// on elapsed time rather than calendar days.
DateTime ago(Duration d) => refNow.subtract(d);

const DishTags defaultTags = DishTags(
  region: Region.north,
  dishType: DishType.curry,
  flavours: {Flavour.spicy},
  heaviness: Heaviness.heavy,
  protein: Protein.paneer,
);

const DishTags otherTags = DishTags(
  region: Region.south,
  dishType: DishType.breakfast,
  flavours: {Flavour.tangy, Flavour.mild},
  heaviness: Heaviness.light,
  protein: Protein.dalLegume,
);

Recipe recipe(
  String id, {
  DishTags tags = defaultTags,
  Set<MealType> mealTypes = const {MealType.lunch, MealType.dinner},
  DishBase base = DishBase.roti,
  List<RecipeIngredient> ingredients = const [],
  bool isHidden = false,
  bool isFavorite = false,
  int minutes = 25,
}) => Recipe(
  id: id,
  name: 'Recipe $id',
  mealTypes: mealTypes,
  minutes: minutes,
  base: base,
  ingredients: ingredients,
  steps: const ['Cook'],
  tags: tags,
  source: RecipeSource.seed,
  isHidden: isHidden,
  isFavorite: isFavorite,
);

RecipeIngredient uses(String ingredientId, {bool optional = false}) =>
    RecipeIngredient(
      ingredientId: ingredientId,
      quantityText: '1',
      isOptional: optional,
    );

Ingredient ingredient(String id, IngredientRole role) => Ingredient(
  id: id,
  name: id,
  category: IngredientCategory.other,
  role: role,
  buyFrom: BuyFrom.kirana,
);

PantryItem stock(String ingredientId, StockLevel level) =>
    PantryItem(ingredientId: ingredientId, level: level, updatedAt: refNow);

SwipeEvent swipe(
  String id,
  String recipeId,
  SwipeAction action,
  DateTime at, {
  String? undoes,
}) => SwipeEvent(
  id: id,
  recipeId: recipeId,
  action: action,
  mode: SwipeMode.craving,
  at: at,
  deckSeed: 7,
  undoesEventId: undoes,
);

SwipeEvent undo(String id, String undoes, DateTime at) =>
    swipe(id, 'n/a', SwipeAction.undo, at, undoes: undoes);

MealLog cooked(String id, String recipeId, DateTime at) => MealLog(
  id: id,
  recipeId: recipeId,
  mealType: MealType.dinner,
  cookedAt: at,
);

/// Every [TagKey] carried by [defaultTags].
final List<TagKey> defaultKeys = defaultTags.allKeys;
