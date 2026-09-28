import 'package:meta/meta.dart';

/// Which seed-data rule a [SeedIssue] breaks. Rule ids (`I1`…`R11`) match
/// `docs/design/SEED_GUIDE.md`; coverage codes are only reported when
/// `SeedValidator.validate` is given `SeedCoverageTargets`.
enum SeedIssueCode {
  /// I1: ingredient id format (`^[a-z][a-z0-9_]*$`, no `user_` prefix)
  /// and uniqueness.
  i1IngredientId('I1'),

  /// I2: ingredient name non-blank, trimmed, unique after normalising.
  i2IngredientName('I2'),

  /// I3: every normalised name/alias maps to exactly one ingredient, and
  /// no alias repeats within an ingredient or equals its own name.
  i3AliasCollision('I3'),

  /// I4: aliases non-blank and already normalised (lowercase, trimmed,
  /// single-spaced).
  i4AliasFormat('I4'),

  /// I5: `shelfLifeDays` in range, and present for perishables.
  i5ShelfLife('I5'),

  /// I6: sabzi/fruit bought from the sabziwala, dairy from the dairy.
  i6BuyFrom('I6'),

  /// I7: staple count and which categories may be staples.
  i7Staples('I7'),

  /// R1: recipe id format and uniqueness; names non-blank and unique.
  r1RecipeIdentity('R1'),

  /// R2: at least one meal type.
  r2MealTypes('R2'),

  /// R3: minutes in range.
  r3Minutes('R3'),

  /// R4: step count and step text.
  r4Steps('R4'),

  /// R5: ingredient lines non-empty, known, unique, with quantity text.
  r5Ingredients('R5'),

  /// R6: at least one required core-role ingredient.
  r6CoreIngredient('R6'),

  /// R7: at most 8 required ingredients the user has to shop for.
  r7RequiredCount('R7'),

  /// R8: flavours non-empty; mild never with spicy.
  r8Flavours('R8'),

  /// R9: image asset path format and existence.
  r9ImageAsset('R9'),

  /// R10: dish type agrees with base.
  r10Base('R10'),

  /// R11: protein tag agrees with the ingredient list.
  r11Protein('R11'),

  /// Catalogue totals (recipe and ingredient counts).
  coverageTotals('C-totals'),

  /// Recipes per meal type.
  coverageMealTypes('C-meals'),

  /// Recipes per region.
  coverageRegions('C-regions'),

  /// Recipes per dish type.
  coverageDishTypes('C-dishTypes'),

  /// Recipes per base, and maximum share of any one base.
  coverageBases('C-bases'),

  /// Share of each heaviness.
  coverageHeaviness('C-heaviness'),

  /// Share of quick recipes.
  coverageQuick('C-quick'),

  /// Non-veg share, paneer and dal/legume counts.
  coverageProtein('C-protein');

  const SeedIssueCode(this.rule);

  /// Short rule id as written in the seed guide, e.g. `R5`.
  final String rule;
}

/// One broken seed-data rule, found by `SeedValidator.validate`.
///
/// There are no warnings: anything reported here fails the seed tests.
/// Intentional exceptions are listed explicitly in `SeedRuleExemptions`.
@immutable
class SeedIssue {
  /// Creates an issue for [code] at [location].
  const SeedIssue(this.code, this.location, this.message);

  /// The rule that is broken.
  final SeedIssueCode code;

  /// Where, e.g. `recipes[aloo_gobi].ingredients[2]` or `ingredients`.
  final String location;

  /// What is wrong, in plain language.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is SeedIssue &&
      other.code == code &&
      other.location == location &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, location, message);

  @override
  String toString() => '${code.rule} $location: $message';
}
