import 'package:kya_core/src/domain/enums.dart';
import 'package:meta/meta.dart';

/// A household's current stock of one `Ingredient`.
///
/// One [PantryItem] per ingredient by construction — [ingredientId] is
/// treated as the primary key, so a repository implementation should upsert
/// on it, never insert duplicates (`AGENTS.md` section 5.4).
@immutable
class PantryItem {
  const PantryItem({
    required this.ingredientId,
    required this.level,
    required this.updatedAt,
    this.expiresOn,
    this.expiryIsEstimated = false,
  });

  final String ingredientId;
  final StockLevel level;

  /// `null` means "no known expiry" (e.g. staples, or an ingredient with no
  /// `Ingredient.shelfLifeDays`).
  final DateTime? expiresOn;

  /// True if [expiresOn] was auto-computed from
  /// `Ingredient.shelfLifeDays + updatedAt` rather than entered by the user.
  /// Surfaced in the UI so an estimated date reads differently from a
  /// confirmed one (`AGENTS.md` design principle 4: suggest, never assume).
  final bool expiryIsEstimated;

  final DateTime updatedAt;

  /// Days until [expiresOn], as of [now]. Negative means already expired.
  /// `null` when there's no expiry to compare against.
  int? daysUntilExpiry(DateTime now) {
    final expiry = expiresOn;
    if (expiry == null) return null;
    return _dateOnly(expiry).difference(_dateOnly(now)).inDays;
  }

  bool isExpiringWithin(int days, DateTime now) {
    final remaining = daysUntilExpiry(now);
    return remaining != null && remaining <= days;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  PantryItem copyWith({
    String? ingredientId,
    StockLevel? level,
    DateTime? updatedAt,
    Object? expiresOn = _unset,
    bool? expiryIsEstimated,
  }) {
    return PantryItem(
      ingredientId: ingredientId ?? this.ingredientId,
      level: level ?? this.level,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresOn: identical(expiresOn, _unset)
          ? this.expiresOn
          : expiresOn as DateTime?,
      expiryIsEstimated: expiryIsEstimated ?? this.expiryIsEstimated,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PantryItem &&
      other.ingredientId == ingredientId &&
      other.level == level &&
      other.expiresOn == expiresOn &&
      other.expiryIsEstimated == expiryIsEstimated &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(ingredientId, level, expiresOn, expiryIsEstimated, updatedAt);

  @override
  String toString() => 'PantryItem($ingredientId: $level)';
}

/// Sentinel used so [PantryItem.copyWith] can distinguish "leave `expiresOn`
/// unchanged" from "explicitly set it to null" (clearing an expiry date is a
/// real, valid operation — e.g. the user marks an item as freshly restocked).
const Object _unset = Object();
