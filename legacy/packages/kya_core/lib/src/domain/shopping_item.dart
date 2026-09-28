import 'package:meta/meta.dart';

/// Why an item landed on the shopping list — shown to the user so a list
/// built automatically still feels explainable, not mysterious
/// (`AGENTS.md` design principle 5).
enum ShoppingReason { out, low, recipe, manual }

@immutable
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.reason,
    required this.isChecked,
    required this.createdAt,
    this.ingredientId,
    this.customName,
    this.recipeId,
  }) : assert(
         ingredientId != null || customName != null,
         'A shopping item needs either a catalog ingredientId or a '
         'free-typed customName.',
       );

  final String id;

  /// Set when this item maps to a catalog `Ingredient`; `null` for a
  /// free-typed item the user added manually that doesn't match anything
  /// (e.g. "birthday candles").
  final String? ingredientId;

  /// Set only when [ingredientId] is null.
  final String? customName;

  final ShoppingReason reason;

  /// Set when [reason] is [ShoppingReason.recipe] — which recipe asked for
  /// this ingredient, so the UI can show "for: Palak Paneer".
  final String? recipeId;

  final bool isChecked;
  final DateTime createdAt;

  /// The name to display, regardless of whether this is catalog-backed.
  /// Catalog display names are resolved by the caller (this class doesn't
  /// depend on a repository); pass the resolved name in directly.
  String displayName(String Function(String ingredientId) resolveName) =>
      customName ?? resolveName(ingredientId!);

  @override
  bool operator ==(Object other) =>
      other is ShoppingItem &&
      other.id == id &&
      other.ingredientId == ingredientId &&
      other.customName == customName &&
      other.reason == reason &&
      other.recipeId == recipeId &&
      other.isChecked == isChecked &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    ingredientId,
    customName,
    reason,
    recipeId,
    isChecked,
    createdAt,
  );
}
