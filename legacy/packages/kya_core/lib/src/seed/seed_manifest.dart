import 'package:kya_core/src/domain/domain.dart';
import 'package:meta/meta.dart';

/// The parsed `assets/seed/manifest.json`: which fragment files make up
/// the bundled seed data, and its version.
///
/// Fragment paths are relative to `assets/seed/` and listed in load order.
/// Produced by `SeedCodec.decodeManifest`, which guarantees every path is
/// a safe, unique, relative `.json` path.
@immutable
class SeedManifest {
  /// Creates a manifest. The lists are copied and made unmodifiable.
  SeedManifest({
    required this.seedVersion,
    required List<String> ingredientFiles,
    required List<String> recipeFiles,
  }) : ingredientFiles = List.unmodifiable(ingredientFiles),
       recipeFiles = List.unmodifiable(recipeFiles);

  /// Version of the bundled seed content (`AGENTS.md` section 5.6). Bumped
  /// whenever seed rows change, so first-run seeding can add new rows
  /// without clobbering user edits. Always at least 1.
  final int seedVersion;

  /// Fragment files holding `{"ingredients": [...]}`.
  final List<String> ingredientFiles;

  /// Fragment files holding `{"recipes": [...]}`.
  final List<String> recipeFiles;

  /// Every fragment path, ingredients first.
  List<String> get allFiles => [...ingredientFiles, ...recipeFiles];
}

/// The complete bundled seed catalogue, decoded from a [SeedManifest] and
/// its fragments by `SeedCodec.decode`.
///
/// Every recipe has `source == RecipeSource.seed` and every ingredient
/// `isUserCreated == false`. Ids are unique within each list, but no
/// cross-reference or content rule has been checked yet: run
/// `SeedValidator.validate` for that.
@immutable
class SeedBundle {
  /// Creates a bundle. The lists are copied and made unmodifiable.
  SeedBundle({
    required this.seedVersion,
    required List<Ingredient> ingredients,
    required List<Recipe> recipes,
  }) : ingredients = List.unmodifiable(ingredients),
       recipes = List.unmodifiable(recipes);

  /// Copied from [SeedManifest.seedVersion].
  final int seedVersion;

  /// Catalogue ingredients, in manifest fragment order.
  final List<Ingredient> ingredients;

  /// Seed recipes, in manifest fragment order.
  final List<Recipe> recipes;
}
