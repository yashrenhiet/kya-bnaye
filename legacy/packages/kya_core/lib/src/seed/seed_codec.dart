import 'package:kya_core/src/codec/entity_json.dart';
import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/seed/seed_format_exception.dart';
import 'package:kya_core/src/seed/seed_json.dart';
import 'package:kya_core/src/seed/seed_manifest.dart';

/// Decodes the bundled seed data: `assets/seed/manifest.json` plus the
/// ingredient and recipe fragment files it lists.
///
/// Deliberately much stricter than `BackupCodec`: seed files are authored
/// by hand, so every typo must fail loudly at build time. Unknown keys,
/// app-owned keys (`isUserCreated`, `source`, `isFavorite`, `isHidden`),
/// wrong JSON types, unknown enum names and duplicate ids all throw a
/// [SeedFormatException] naming the file and JSON path. Content rules
/// (cross-references, aliases, ranges) are `SeedValidator`'s job.
///
/// Pure: callers read the files (Flutter `rootBundle` in the app,
/// `dart:io` in tests) and pass the decoded JSON in.
class SeedCodec {
  /// Creates a codec. Stateless.
  const SeedCodec();

  /// File name used in locations for manifest errors.
  static const String manifestFile = 'manifest.json';

  static const _ingredientKeys = [
    'id',
    'name',
    'aliases',
    'category',
    'role',
    'buyFrom',
  ];
  static const _recipeKeys = [
    'id',
    'name',
    'mealTypes',
    'minutes',
    'base',
    'tags',
    'ingredients',
    'steps',
  ];
  static const _tagKeys = [
    'region',
    'dishType',
    'flavours',
    'heaviness',
    'protein',
  ];
  static const _forbiddenKeys = {
    'isUserCreated',
    'source',
    'isFavorite',
    'isHidden',
  };
  static final RegExp _pathPattern = RegExp(
    r'^[a-z0-9_]+(/[a-z0-9_]+)*\.json$',
  );

  /// Decodes the result of `jsonDecode` on `manifest.json`.
  ///
  /// Throws [SeedFormatException] unless [json] is an object with exactly
  /// `seedVersion` (integer ≥ 1), `ingredients` and `recipes` (non-empty
  /// arrays of unique, relative, lowercase `.json` paths).
  SeedManifest decodeManifest(Object? json) {
    final root = SeedJsonObject.from(json, file: manifestFile)
      ..checkKeys(required: const ['seedVersion', 'ingredients', 'recipes']);
    final version = root.integer('seedVersion');
    if (version < 1) {
      throw SeedFormatException(
        root.locationOf('seedVersion'),
        'must be at least 1, got $version',
      );
    }
    final seen = <String>{};
    List<String> paths(String key) {
      final values = root.stringList(key);
      if (values.isEmpty) {
        throw SeedFormatException(
          root.locationOf(key),
          'must list at least one file',
        );
      }
      for (var i = 0; i < values.length; i++) {
        final location = seedLocation(manifestFile, '$key[$i]');
        if (!_pathPattern.hasMatch(values[i])) {
          throw SeedFormatException(
            location,
            'invalid path "${values[i]}" (expected a relative lowercase '
            'path like "recipes/sabzi.json")',
          );
        }
        if (!seen.add(values[i])) {
          throw SeedFormatException(
            location,
            'file "${values[i]}" is listed more than once',
          );
        }
      }
      return values;
    }

    return SeedManifest(
      seedVersion: version,
      ingredientFiles: paths('ingredients'),
      recipeFiles: paths('recipes'),
    );
  }

  /// Decodes every fragment listed in [manifest]. [jsonByPath] maps each
  /// fragment path to the result of `jsonDecode` on that file; entries not
  /// listed in [manifest] are ignored.
  ///
  /// Throws [SeedFormatException] if a listed fragment is missing from
  /// [jsonByPath], if any fragment is malformed, or if an ingredient or
  /// recipe id is declared twice (in the same or different fragments).
  SeedBundle decode(SeedManifest manifest, Map<String, Object?> jsonByPath) {
    final ingredientsSeenAt = <String, String>{};
    final ingredients = <Ingredient>[
      for (final file in manifest.ingredientFiles)
        for (final row in _rows(file, 'ingredients', jsonByPath))
          _ingredient(row, ingredientsSeenAt),
    ];
    final recipesSeenAt = <String, String>{};
    final recipes = <Recipe>[
      for (final file in manifest.recipeFiles)
        for (final row in _rows(file, 'recipes', jsonByPath))
          _recipe(row, recipesSeenAt),
    ];
    return SeedBundle(
      seedVersion: manifest.seedVersion,
      ingredients: ingredients,
      recipes: recipes,
    );
  }

  List<SeedJsonObject> _rows(
    String file,
    String key,
    Map<String, Object?> jsonByPath,
  ) {
    if (!jsonByPath.containsKey(file)) {
      throw SeedFormatException(
        file,
        'listed in $manifestFile but its contents were not provided',
      );
    }
    final root = SeedJsonObject.from(jsonByPath[file], file: file)
      ..checkKeys(required: [key]);
    return root.objects(key);
  }

  Ingredient _ingredient(SeedJsonObject row, Map<String, String> seenAt) {
    row.checkKeys(
      required: _ingredientKeys,
      optional: const ['shelfLifeDays'],
      forbidden: _forbiddenKeys,
    );
    _uniqueId(row, 'ingredient', seenAt);
    row
      ..string('name')
      ..stringList('aliases')
      ..enumValue('category', IngredientCategory.values)
      ..enumValue('role', IngredientRole.values)
      ..enumValue('buyFrom', BuyFrom.values)
      ..optionalInteger('shelfLifeDays');
    return ingredientFromJson(row.json);
  }

  Recipe _recipe(SeedJsonObject row, Map<String, String> seenAt) {
    row.checkKeys(
      required: _recipeKeys,
      optional: const ['imageAsset'],
      forbidden: _forbiddenKeys,
    );
    _uniqueId(row, 'recipe', seenAt);
    row
      ..string('name')
      ..enumList('mealTypes', MealType.values)
      ..integer('minutes')
      ..enumValue('base', DishBase.values)
      ..stringList('steps')
      ..optionalString('imageAsset');
    row.object('tags')
      ..checkKeys(required: _tagKeys)
      ..enumValue('region', Region.values)
      ..enumValue('dishType', DishType.values)
      ..enumList('flavours', Flavour.values)
      ..enumValue('heaviness', Heaviness.values)
      ..enumValue('protein', Protein.values);
    for (final line in row.objects('ingredients')) {
      line
        ..checkKeys(
          required: const ['ingredientId', 'quantityText'],
          optional: const ['isOptional'],
        )
        ..string('ingredientId')
        ..string('quantityText')
        ..optionalBool('isOptional');
    }
    return recipeFromJson({...row.json, 'source': RecipeSource.seed.name});
  }

  void _uniqueId(SeedJsonObject row, String kind, Map<String, String> seen) {
    final id = row.string('id');
    final first = seen[id];
    if (first != null) {
      throw SeedFormatException(
        row.locationOf('id'),
        'duplicate $kind id "$id" (first declared at $first)',
      );
    }
    seen[id] = row.location;
  }
}
