import 'package:meta/meta.dart';

/// One line of a recipe's ingredient list.
///
/// [quantityText] is free text ("2 katori", "1 medium") shown to the user —
/// it is deliberately **not** a structured amount+unit, because nothing in
/// v1 needs to do arithmetic on quantities (ADR 005 applies here too: exact
/// amounts are a UI detail, not a scoring input).
@immutable
class RecipeIngredient {
  const RecipeIngredient({
    required this.ingredientId,
    required this.quantityText,
    this.isOptional = false,
  });

  final String ingredientId;
  final String quantityText;

  /// Optional ingredients (usually garnishes) are informational only — they
  /// never make a recipe's "missing ingredients" count go up. This is the
  /// per-recipe complement to `IngredientRole.optional`: an ingredient never
  /// counts as missing if **either** this flag is set **or** its catalog
  /// role is optional (see `resolveIngredientAvailability`). Use this flag
  /// when an ingredient that is core elsewhere is only a garnish here.
  final bool isOptional;

  @override
  bool operator ==(Object other) =>
      other is RecipeIngredient &&
      other.ingredientId == ingredientId &&
      other.quantityText == quantityText &&
      other.isOptional == isOptional;

  @override
  int get hashCode => Object.hash(ingredientId, quantityText, isOptional);
}
