/// Shared JSON mappers for the catalogue entities (ingredients and recipes).
///
/// Internal to `kya_core` (not exported). Both the backup codec and the
/// strict seed codec map through these functions, so a backup and the
/// bundled seed data can never disagree on how an entity is spelled in
/// JSON. The `fromJson` functions assume well-typed input and throw a
/// [TypeError] (or [ArgumentError] for an unknown enum name) otherwise;
/// each caller wraps that in its own format exception.
library;

import 'package:kya_core/src/domain/domain.dart';

/// Eagerly converts a JSON list to `List<String>`, so a non-string entry
/// fails while decoding rather than later, when a lazy `cast` view is
/// first read.
List<String> stringListFromJson(dynamic json) => [
  for (final e in json as List) e as String,
];

// --- Ingredient ---

Map<String, dynamic> ingredientToJson(Ingredient i) => {
  'id': i.id,
  'name': i.name,
  'aliases': i.aliases,
  'category': i.category.name,
  'role': i.role.name,
  'buyFrom': i.buyFrom.name,
  'shelfLifeDays': i.shelfLifeDays,
  'isUserCreated': i.isUserCreated,
};

Ingredient ingredientFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return Ingredient(
    id: map['id'] as String,
    name: map['name'] as String,
    aliases: stringListFromJson(map['aliases']),
    category: IngredientCategory.values.byName(map['category'] as String),
    role: IngredientRole.values.byName(map['role'] as String),
    buyFrom: BuyFrom.values.byName(map['buyFrom'] as String),
    shelfLifeDays: map['shelfLifeDays'] as int?,
    isUserCreated: map['isUserCreated'] as bool? ?? false,
  );
}

// --- Recipe / DishTags / RecipeIngredient ---

Map<String, dynamic> recipeToJson(Recipe r) => {
  'id': r.id,
  'name': r.name,
  'mealTypes': r.mealTypes.map((m) => m.name).toList(),
  'minutes': r.minutes,
  'base': r.base.name,
  'ingredients': r.ingredients.map(recipeIngredientToJson).toList(),
  'steps': r.steps,
  'tags': dishTagsToJson(r.tags),
  'imageAsset': r.imageAsset,
  'isFavorite': r.isFavorite,
  'isHidden': r.isHidden,
  'source': r.source.name,
};

Recipe recipeFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return Recipe(
    id: map['id'] as String,
    name: map['name'] as String,
    mealTypes: (map['mealTypes'] as List)
        .map((m) => MealType.values.byName(m as String))
        .toSet(),
    minutes: map['minutes'] as int,
    base: DishBase.values.byName(map['base'] as String),
    ingredients: (map['ingredients'] as List)
        .map(recipeIngredientFromJson)
        .toList(),
    steps: stringListFromJson(map['steps']),
    tags: dishTagsFromJson(map['tags']),
    imageAsset: map['imageAsset'] as String?,
    isFavorite: map['isFavorite'] as bool? ?? false,
    isHidden: map['isHidden'] as bool? ?? false,
    source: RecipeSource.values.byName(map['source'] as String),
  );
}

Map<String, dynamic> recipeIngredientToJson(RecipeIngredient ri) => {
  'ingredientId': ri.ingredientId,
  'quantityText': ri.quantityText,
  'isOptional': ri.isOptional,
};

RecipeIngredient recipeIngredientFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return RecipeIngredient(
    ingredientId: map['ingredientId'] as String,
    quantityText: map['quantityText'] as String,
    isOptional: map['isOptional'] as bool? ?? false,
  );
}

Map<String, dynamic> dishTagsToJson(DishTags t) => {
  'region': t.region.name,
  'dishType': t.dishType.name,
  'flavours': t.flavours.map((f) => f.name).toList(),
  'heaviness': t.heaviness.name,
  'protein': t.protein.name,
};

DishTags dishTagsFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return DishTags(
    region: Region.values.byName(map['region'] as String),
    dishType: DishType.values.byName(map['dishType'] as String),
    flavours: (map['flavours'] as List)
        .map((f) => Flavour.values.byName(f as String))
        .toSet(),
    heaviness: Heaviness.values.byName(map['heaviness'] as String),
    protein: Protein.values.byName(map['protein'] as String),
  );
}
