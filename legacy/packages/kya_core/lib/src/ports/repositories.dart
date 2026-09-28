/// Repository interfaces `kya_core` depends on but never implements.
///
/// This is the other half of the dependency rule in ADR 004/`AGENTS.md`
/// section 5.3: `app/lib/data/` provides Drift-backed implementations of
/// these at milestone M3. Controllers and use-cases depend on these
/// interfaces, never on Drift directly, so swapping storage later (v2 cloud
/// sync) means writing a new adapter with zero changes here.
///
/// Read methods return [Stream]s so the app layer can wire them straight
/// into Riverpod's `StreamProvider` and get automatic rebuilds on change
/// (`AGENTS.md` section 5.7's "I made this" data-flow example) — that
/// reactivity is a UI-layer concern, but the *shape* of "reads are
/// streams, writes are futures" belongs in the contract itself.
library;

import 'package:kya_core/src/domain/domain.dart';

abstract interface class IngredientRepository {
  Stream<List<Ingredient>> watchAll();
  Future<void> upsert(Ingredient ingredient);
}

abstract interface class PantryRepository {
  Stream<List<PantryItem>> watchAll();

  /// Upserts on [PantryItem.ingredientId] — one row per ingredient by
  /// construction (`AGENTS.md` section 5.4).
  Future<void> upsert(PantryItem item);
}

abstract interface class RecipeRepository {
  Stream<List<Recipe>> watchAll();
  Future<Recipe?> getById(String id);
  Future<void> upsert(Recipe recipe);
  Future<void> delete(String id);
}

abstract interface class MealLogRepository {
  Stream<List<MealLog>> watchAll();
  Future<void> add(MealLog log);
}

/// The append-only log ADR 008 describes. There is deliberately no
/// `update`/`delete` here — an "undo" is `add`ing a new
/// [SwipeEvent] with [SwipeAction.undo], never mutating history.
abstract interface class SwipeEventRepository {
  Stream<List<SwipeEvent>> watchAll();
  Future<void> add(SwipeEvent event);
}

abstract interface class ShoppingRepository {
  Stream<List<ShoppingItem>> watchAll();
  Future<void> upsert(ShoppingItem item);
  Future<void> delete(String id);
}
