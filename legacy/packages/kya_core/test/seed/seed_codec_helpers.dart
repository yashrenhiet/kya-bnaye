import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'seed_fixtures.dart';

const seedCodec = SeedCodec();

Matcher throwsSeed(Object location, Object message) => throwsA(
  isA<SeedFormatException>()
      .having((e) => e.location, 'location', location)
      .having((e) => e.message, 'message', message),
);

SeedBundle decodeFragments(Map<String, Object?> fragments) =>
    seedCodec.decode(seedCodec.decodeManifest(manifestJson()), fragments);

Map<String, Object?> fragmentRow(Map<String, Object?> fragments, String file) {
  final key = file == ingredientFile ? 'ingredients' : 'recipes';
  final root = fragments[file]! as Map<String, Object?>;
  return (root[key]! as List<Object?>).first! as Map<String, Object?>;
}

/// Fragments whose first ingredient row was changed by [edit].
Map<String, Object?> withIngredientRow(
  void Function(Map<String, Object?>) edit,
) {
  final fragments = fragmentsJson();
  edit(fragmentRow(fragments, ingredientFile));
  return fragments;
}

/// Fragments whose first recipe row was changed by [edit].
Map<String, Object?> withRecipeRow(void Function(Map<String, Object?>) edit) {
  final fragments = fragmentsJson();
  edit(fragmentRow(fragments, recipeFile));
  return fragments;
}

const potatoAt = '$ingredientFile › ingredients[0]';
const recipeAt = '$recipeFile › recipes[0]';
