import 'package:kya_core/src/domain/domain.dart';

/// Thrown when [BackupCodec.decode] is given JSON that isn't a backup this
/// app can restore — a newer, incompatible version, or structurally broken
/// data. Callers surface this as a user-facing error, never a crash
/// (`AGENTS.md` section 0: errors are handled, not swallowed).
class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Everything a full backup/restore (F7 in `AGENTS.md` section 3) needs to
/// round-trip. Deliberately a plain bundle, not a "the whole app state"
/// singleton — repositories decide how these lists map to their own
/// storage.
class BackupBundle {
  const BackupBundle({
    required this.ingredients,
    required this.pantryItems,
    required this.recipes,
    required this.mealLogs,
    required this.swipeEvents,
    required this.shoppingItems,
  });

  final List<Ingredient> ingredients;
  final List<PantryItem> pantryItems;
  final List<Recipe> recipes;
  final List<MealLog> mealLogs;
  final List<SwipeEvent> swipeEvents;
  final List<ShoppingItem> shoppingItems;
}

/// Encodes/decodes a [BackupBundle] as plain JSON-compatible `Map`/`List`
/// structures — callers handle the actual file I/O and share-sheet
/// mechanics (that's a platform concern, so it stays in `app/`, not here).
///
/// Only user-created ingredients and user recipes are worth restoring
/// (seed data reloads from the app's bundled assets, see `AGENTS.md`
/// section 5.6's `seedVersion`) — but v1 backs up everything unconditionally
/// for simplicity; trimming seed rows out is a safe, additive optimisation
/// for later if backup file size ever becomes a problem (YAGNI for now).
class BackupCodec {
  const BackupCodec();

  static const int currentVersion = 1;

  Map<String, dynamic> encode(
    BackupBundle bundle, {
    required DateTime exportedAt,
  }) {
    return {
      'version': currentVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'ingredients': bundle.ingredients.map(_ingredientToJson).toList(),
      'pantryItems': bundle.pantryItems.map(_pantryItemToJson).toList(),
      'recipes': bundle.recipes.map(_recipeToJson).toList(),
      'mealLogs': bundle.mealLogs.map(_mealLogToJson).toList(),
      'swipeEvents': bundle.swipeEvents.map(_swipeEventToJson).toList(),
      'shoppingItems': bundle.shoppingItems.map(_shoppingItemToJson).toList(),
    };
  }

  BackupBundle decode(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int || version > currentVersion) {
      throw BackupFormatException(
        'Unsupported backup version: $version (this app supports up to '
        '$currentVersion). Update the app before restoring this file.',
      );
    }
    try {
      return BackupBundle(
        ingredients: _list(
          json['ingredients'],
        ).map(_ingredientFromJson).toList(),
        pantryItems: _list(
          json['pantryItems'],
        ).map(_pantryItemFromJson).toList(),
        recipes: _list(json['recipes']).map(_recipeFromJson).toList(),
        mealLogs: _list(json['mealLogs']).map(_mealLogFromJson).toList(),
        swipeEvents: _list(
          json['swipeEvents'],
        ).map(_swipeEventFromJson).toList(),
        shoppingItems: _list(
          json['shoppingItems'],
        ).map(_shoppingItemFromJson).toList(),
      );
    } on BackupFormatException {
      rethrow;
    } catch (e) {
      throw BackupFormatException('Malformed backup data: $e');
    }
  }

  static List<dynamic> _list(Object? value) {
    if (value is List) return value;
    throw BackupFormatException('Expected a list, got ${value.runtimeType}');
  }
}

// --- Ingredient ---

Map<String, dynamic> _ingredientToJson(Ingredient i) => {
  'id': i.id,
  'name': i.name,
  'aliases': i.aliases,
  'category': i.category.name,
  'role': i.role.name,
  'buyFrom': i.buyFrom.name,
  'shelfLifeDays': i.shelfLifeDays,
  'isUserCreated': i.isUserCreated,
};

Ingredient _ingredientFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return Ingredient(
    id: map['id'] as String,
    name: map['name'] as String,
    aliases: (map['aliases'] as List).cast<String>(),
    category: IngredientCategory.values.byName(map['category'] as String),
    role: IngredientRole.values.byName(map['role'] as String),
    buyFrom: BuyFrom.values.byName(map['buyFrom'] as String),
    shelfLifeDays: map['shelfLifeDays'] as int?,
    isUserCreated: map['isUserCreated'] as bool? ?? false,
  );
}

// --- PantryItem ---

Map<String, dynamic> _pantryItemToJson(PantryItem p) => {
  'ingredientId': p.ingredientId,
  'level': p.level.name,
  'expiresOn': p.expiresOn?.toIso8601String(),
  'expiryIsEstimated': p.expiryIsEstimated,
  'updatedAt': p.updatedAt.toIso8601String(),
};

PantryItem _pantryItemFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  final expiresOn = map['expiresOn'] as String?;
  return PantryItem(
    ingredientId: map['ingredientId'] as String,
    level: StockLevel.values.byName(map['level'] as String),
    expiresOn: expiresOn == null ? null : DateTime.parse(expiresOn),
    expiryIsEstimated: map['expiryIsEstimated'] as bool? ?? false,
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}

// --- Recipe / DishTags / RecipeIngredient ---

Map<String, dynamic> _recipeToJson(Recipe r) => {
  'id': r.id,
  'name': r.name,
  'mealTypes': r.mealTypes.map((m) => m.name).toList(),
  'minutes': r.minutes,
  'base': r.base.name,
  'ingredients': r.ingredients.map(_recipeIngredientToJson).toList(),
  'steps': r.steps,
  'tags': _dishTagsToJson(r.tags),
  'imageAsset': r.imageAsset,
  'isFavorite': r.isFavorite,
  'isHidden': r.isHidden,
  'source': r.source.name,
};

Recipe _recipeFromJson(dynamic json) {
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
        .map(_recipeIngredientFromJson)
        .toList(),
    steps: (map['steps'] as List).cast<String>(),
    tags: _dishTagsFromJson(map['tags']),
    imageAsset: map['imageAsset'] as String?,
    isFavorite: map['isFavorite'] as bool? ?? false,
    isHidden: map['isHidden'] as bool? ?? false,
    source: RecipeSource.values.byName(map['source'] as String),
  );
}

Map<String, dynamic> _recipeIngredientToJson(RecipeIngredient ri) => {
  'ingredientId': ri.ingredientId,
  'quantityText': ri.quantityText,
  'isOptional': ri.isOptional,
};

RecipeIngredient _recipeIngredientFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return RecipeIngredient(
    ingredientId: map['ingredientId'] as String,
    quantityText: map['quantityText'] as String,
    isOptional: map['isOptional'] as bool? ?? false,
  );
}

Map<String, dynamic> _dishTagsToJson(DishTags t) => {
  'region': t.region.name,
  'dishType': t.dishType.name,
  'flavours': t.flavours.map((f) => f.name).toList(),
  'heaviness': t.heaviness.name,
  'protein': t.protein.name,
};

DishTags _dishTagsFromJson(dynamic json) {
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

// --- MealLog ---

Map<String, dynamic> _mealLogToJson(MealLog m) => {
  'id': m.id,
  'recipeId': m.recipeId,
  'mealType': m.mealType.name,
  'cookedAt': m.cookedAt.toIso8601String(),
};

MealLog _mealLogFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return MealLog(
    id: map['id'] as String,
    recipeId: map['recipeId'] as String,
    mealType: MealType.values.byName(map['mealType'] as String),
    cookedAt: DateTime.parse(map['cookedAt'] as String),
  );
}

// --- SwipeEvent ---

Map<String, dynamic> _swipeEventToJson(SwipeEvent e) => {
  'id': e.id,
  'recipeId': e.recipeId,
  'action': e.action.name,
  'mode': e.mode.name,
  'at': e.at.toIso8601String(),
  'deckSeed': e.deckSeed,
  'undoesEventId': e.undoesEventId,
};

SwipeEvent _swipeEventFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return SwipeEvent(
    id: map['id'] as String,
    recipeId: map['recipeId'] as String,
    action: SwipeAction.values.byName(map['action'] as String),
    mode: SwipeMode.values.byName(map['mode'] as String),
    at: DateTime.parse(map['at'] as String),
    deckSeed: map['deckSeed'] as int,
    undoesEventId: map['undoesEventId'] as String?,
  );
}

// --- ShoppingItem ---

Map<String, dynamic> _shoppingItemToJson(ShoppingItem s) => {
  'id': s.id,
  'ingredientId': s.ingredientId,
  'customName': s.customName,
  'reason': s.reason.name,
  'recipeId': s.recipeId,
  'isChecked': s.isChecked,
  'createdAt': s.createdAt.toIso8601String(),
};

ShoppingItem _shoppingItemFromJson(dynamic json) {
  final map = json as Map<String, dynamic>;
  return ShoppingItem(
    id: map['id'] as String,
    ingredientId: map['ingredientId'] as String?,
    customName: map['customName'] as String?,
    reason: ShoppingReason.values.byName(map['reason'] as String),
    recipeId: map['recipeId'] as String?,
    isChecked: map['isChecked'] as bool? ?? false,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}
