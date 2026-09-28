import 'package:kya_core/src/domain/enums.dart';
import 'package:meta/meta.dart';

/// A canonical kitchen ingredient — the single source of truth an
/// [Ingredient] id ever refers to. "Potato", "aloo" and "batata" are three
/// [aliases] pointing at one [Ingredient], never three separate rows.
///
/// See ADR 004/005 and `AGENTS.md` section 5.4: matching is always exact on
/// [id] after alias resolution (see `IngredientNormalizer`), never a
/// substring match.
@immutable
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.role,
    required this.buyFrom,
    this.aliases = const [],
    this.shelfLifeDays,
    this.isUserCreated = false,
  });

  /// Canonical, stable identifier — e.g. `'potato'`. Lowercase,
  /// underscore-free-ish snake-ish text is fine; the exact format doesn't
  /// matter as long as it never changes once seeded (seed data is versioned,
  /// `AGENTS.md` section 5.6).
  final String id;

  /// Display name shown in the UI, e.g. `'Potato'`.
  final String name;

  /// Other names/spellings a user might type to find this ingredient, e.g.
  /// `['aloo', 'batata']`. Used by `IngredientNormalizer`, never by direct
  /// substring search elsewhere.
  final List<String> aliases;

  final IngredientCategory category;
  final IngredientRole role;
  final BuyFrom buyFrom;

  /// Typical shelf life once bought/opened, used to auto-estimate an expiry
  /// date when a `PantryItem` doesn't have one set explicitly. `null` means
  /// "doesn't meaningfully expire" (e.g. salt).
  final int? shelfLifeDays;

  /// True if this row was created on-the-fly because a user typed an
  /// ingredient name that didn't match the seeded catalog or any alias.
  /// Unknown input becomes a first-class ingredient instead of failing
  /// (`AGENTS.md` section 5.4).
  final bool isUserCreated;

  Ingredient copyWith({
    String? id,
    String? name,
    List<String>? aliases,
    IngredientCategory? category,
    IngredientRole? role,
    BuyFrom? buyFrom,
    Object? shelfLifeDays = _unset,
    bool? isUserCreated,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      category: category ?? this.category,
      role: role ?? this.role,
      buyFrom: buyFrom ?? this.buyFrom,
      shelfLifeDays: identical(shelfLifeDays, _unset)
          ? this.shelfLifeDays
          : shelfLifeDays as int?,
      isUserCreated: isUserCreated ?? this.isUserCreated,
    );
  }

  @override
  bool operator ==(Object other) => other is Ingredient && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Ingredient($id)';
}

/// Sentinel used so [Ingredient.copyWith] can distinguish "leave
/// `shelfLifeDays` unchanged" from "explicitly set it to null" (clearing it
/// is valid — `null` means the ingredient doesn't meaningfully expire).
const Object _unset = Object();
