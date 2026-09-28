import 'package:kya_core/src/domain/domain.dart';

/// Builds the auto-generated portion of the shopping list (F6 in
/// `AGENTS.md` section 3): Low/Out pantry items, plus missing ingredients
/// for recipes the user explicitly asked to shop for. Manual entries are
/// just appended by the caller — this builder only handles the two
/// auto-derived sources.
class ShoppingListBuilder {
  const ShoppingListBuilder();

  /// [existingItems] should be the current *unchecked* shopping list, so an
  /// ingredient already on it isn't added a second time. [nextId] is
  /// injected rather than assumed (e.g. a UUID generator or a repository's
  /// autoincrement) — `kya_core` has no opinion on id generation strategy.
  List<ShoppingItem> build({
    required List<PantryItem> pantry,
    required Map<String, Ingredient> ingredientsById,
    required List<ShoppingItem> existingItems,
    required List<Recipe> recipesToShopFor,
    required DateTime now,
    required String Function() nextId,
  }) {
    final alreadyListed = <String>{
      for (final item in existingItems)
        if (!item.isChecked && item.ingredientId != null) item.ingredientId!,
    };
    final pantryById = {for (final p in pantry) p.ingredientId: p};

    final result = <ShoppingItem>[];

    for (final item in pantry) {
      if (item.level == StockLevel.plenty) continue;
      if (!ingredientsById.containsKey(item.ingredientId)) continue;
      if (!alreadyListed.add(item.ingredientId)) continue;
      result.add(
        ShoppingItem(
          id: nextId(),
          ingredientId: item.ingredientId,
          reason: item.level == StockLevel.out
              ? ShoppingReason.out
              : ShoppingReason.low,
          isChecked: false,
          createdAt: now,
        ),
      );
    }

    for (final recipe in recipesToShopFor) {
      for (final ri in recipe.requiredIngredients) {
        final available = resolveIngredientAvailability(
          ingredientId: ri.ingredientId,
          role: ingredientsById[ri.ingredientId]?.role,
          pantry: pantryById,
        );
        if (available) continue;
        if (!alreadyListed.add(ri.ingredientId)) continue;
        result.add(
          ShoppingItem(
            id: nextId(),
            ingredientId: ri.ingredientId,
            reason: ShoppingReason.recipe,
            recipeId: recipe.id,
            isChecked: false,
            createdAt: now,
          ),
        );
      }
    }

    return result;
  }

  /// Groups items by where the household buys them ("Sabziwala / Kirana /
  /// Dairy / Other", `AGENTS.md` section 4) for the Shopping screen.
  Map<BuyFrom, List<ShoppingItem>> groupByVendor({
    required List<ShoppingItem> items,
    required Map<String, Ingredient> ingredientsById,
  }) {
    final grouped = <BuyFrom, List<ShoppingItem>>{
      for (final vendor in BuyFrom.values) vendor: [],
    };
    for (final item in items) {
      final vendor = item.ingredientId != null
          ? ingredientsById[item.ingredientId]?.buyFrom ?? BuyFrom.other
          : BuyFrom.other;
      grouped[vendor]!.add(item);
    }
    return grouped;
  }
}
