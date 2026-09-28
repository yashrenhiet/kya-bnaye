import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

import 'seed_fixtures.dart';

List<SeedIssue> validateSeed(
  SeedBundle bundle, {
  Set<String> assets = const {jeeraRiceImage},
  SeedRuleExemptions exemptions = const SeedRuleExemptions(),
}) => const SeedValidator().validate(
  bundle,
  assetExists: assets.contains,
  exemptions: exemptions,
);

List<SeedIssue> withIngredient(
  String id,
  Ingredient Function(Ingredient) edit,
) => validateSeed(bundleOf(ingredients: editIngredient(id, edit)));

List<SeedIssue> withRecipe(String id, Recipe Function(Recipe) edit) =>
    validateSeed(bundleOf(recipes: editRecipe(id, edit)));

List<SeedIssue> withExtraIngredients(List<Ingredient> extra) =>
    validateSeed(bundleOf(ingredients: [...fixtureIngredients, ...extra]));

Matcher issueMatching(SeedIssueCode code, String location, Object message) =>
    isA<SeedIssue>()
        .having((i) => i.code, 'code', code)
        .having((i) => i.location, 'location', location)
        .having((i) => i.message, 'message', message);

/// Exactly one issue, matching [code], [location] and [message].
Matcher onlyIssue(SeedIssueCode code, String location, [Object? message]) =>
    equals([issueMatching(code, location, message ?? anything)]);

Set<SeedIssueCode> issueCodes(List<SeedIssue> issues) => {
  for (final i in issues) i.code,
};

DishTags tagsOf(
  Recipe r, {
  Set<Flavour>? flavours,
  DishType? dishType,
  Protein? protein,
}) => DishTags(
  region: r.tags.region,
  dishType: dishType ?? r.tags.dishType,
  flavours: flavours ?? r.tags.flavours,
  heaviness: r.tags.heaviness,
  protein: protein ?? r.tags.protein,
);
