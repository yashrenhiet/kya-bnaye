import 'package:kya_core/src/domain/enums.dart';
import 'package:kya_core/src/domain/ingredient.dart';

/// Resolves free-typed ingredient text ("aloo", "Tamatar", "  Potato ") to a
/// canonical [Ingredient] id.
///
/// This is the guardrail behind the single most important rule in
/// `AGENTS.md` section 5.4: **matching is exact on canonical id after alias
/// resolution, never a substring match** — the bug that made Ratatouille
/// (see `docs/RESEARCH.md`) match "rice" against "rice flour". Every lookup
/// here is an exact match against a normalised key, built once in the
/// constructor, not a `contains()` scan at query time.
class IngredientNormalizer {
  IngredientNormalizer(Iterable<Ingredient> catalog)
    : _byId = {for (final i in catalog) i.id: i} {
    for (final ingredient in _byId.values) {
      _registerKey(_normalise(ingredient.name), ingredient.id);
      for (final alias in ingredient.aliases) {
        _registerKey(_normalise(alias), ingredient.id);
      }
    }
  }

  final Map<String, Ingredient> _byId;
  final Map<String, String> _keyToId = {};

  void _registerKey(String key, String id) {
    final existing = _keyToId[key];
    if (existing != null && existing != id) {
      throw StateError(
        'Alias collision: "$key" maps to both "$existing" and "$id". '
        'Seed-data validators (milestone M2) must catch this before it '
        'ships — see docs/RESEARCH.md on why substring/alias ambiguity is '
        'the recurring bug in this class of app.',
      );
    }
    _keyToId[key] = id;
  }

  static String _normalise(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Looks up an [Ingredient] by exact name or alias match (case/whitespace
  /// insensitive). Returns `null` if nothing in the catalog matches —
  /// callers decide whether to offer creating a user ingredient
  /// (`Ingredient.isUserCreated`), this class never invents one itself.
  Ingredient? find(String text) {
    final id = _keyToId[_normalise(text)];
    return id == null ? null : _byId[id];
  }

  /// True if [text] matches something already in the catalog.
  bool contains(String text) => find(text) != null;

  Ingredient? byId(String id) => _byId[id];

  /// Builds a new, user-created [Ingredient] for text that didn't match
  /// anything in [find]. The caller is responsible for persisting it and,
  /// from then on, including it when constructing future
  /// `IngredientNormalizer` instances.
  Ingredient createUserIngredient(
    String text, {
    required IngredientCategory category,
    required BuyFrom buyFrom,
    IngredientRole role = IngredientRole.core,
  }) {
    final trimmed = text.trim();
    return Ingredient(
      id: 'user_${_normalise(trimmed).replaceAll(' ', '_')}',
      name: trimmed,
      category: category,
      role: role,
      buyFrom: buyFrom,
      isUserCreated: true,
    );
  }

  Iterable<Ingredient> get all => _byId.values;
}
