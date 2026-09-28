import 'package:kya_core/src/recommend/scoring_config.dart';

/// Shared penalty functions used by both `KitchenRanker` and `CravingRanker`
/// (`docs/design/RECOMMENDER.md` section 5, "Shared penalties").
///
/// Kept as free functions rather than methods on the rankers so they can be
/// unit-tested in isolation and so both rankers provably use the exact same
/// formula — a ranker computing its own bespoke repeat penalty would be a
/// DRY violation `AGENTS.md` section 0 explicitly calls out reviewers to
/// catch.
class Penalties {
  const Penalties._();

  /// Discourages suggesting the same dish again too soon after it was
  /// cooked, plus an extra "rut" penalty if it's been cooked unusually often
  /// in the last [ScoringConfig.repeatRutWindowDays].
  static double repeatPenalty({
    required DateTime? lastCookedAt,
    required int cookCountInRutWindow,
    required DateTime now,
    required ScoringConfig config,
  }) {
    if (lastCookedAt == null) return 0;
    final daysSince = _daysBetween(lastCookedAt, now);
    double penalty;
    if (daysSince <= 7) {
      penalty = config.repeatPenaltyWithin7d;
    } else if (daysSince <= 14) {
      penalty = config.repeatPenaltyWithin14d;
    } else if (daysSince <= 28) {
      penalty = config.repeatPenaltyWithin28d;
    } else if (daysSince <= 56) {
      penalty = config.repeatPenaltyWithin56d;
    } else {
      penalty = 0;
    }
    // "Rut" top-up: every cook beyond the first one within the rut window
    // adds a little more friction, so a dish on constant repeat gradually
    // gets pushed down even if each individual gap looks fine.
    final extraCooks = (cookCountInRutWindow - 1).clamp(0, 1 << 30);
    return penalty + extraCooks * config.repeatRutPenaltyPerExtraCook;
  }

  /// Returns `null` if the recipe should be **excluded entirely** (left-
  /// swiped within [ScoringConfig.rejectExclusionWindowDays]), otherwise the
  /// score penalty to apply (0 outside the penalty window).
  static double? rejectPenalty({
    required DateTime? lastLeftSwipeAt,
    required DateTime now,
    required ScoringConfig config,
  }) {
    if (lastLeftSwipeAt == null) return 0;
    final daysSince = _daysBetween(lastLeftSwipeAt, now);
    if (daysSince <= config.rejectExclusionWindowDays) return null;
    if (daysSince <= config.rejectPenaltyWindowDays) {
      return config.rejectPenaltyWithinWindow;
    }
    return 0;
  }

  /// Whole calendar days from [a]'s date to [b]'s date (negative if [b] is
  /// earlier), ignoring time of day.
  ///
  /// Dates are compared as UTC midnights: diffing local midnights would
  /// yield a 23-hour "day" across a DST spring-forward, which
  /// [Duration.inDays] truncates to one day fewer.
  static int _daysBetween(DateTime a, DateTime b) {
    final aDate = DateTime.utc(a.year, a.month, a.day);
    final bDate = DateTime.utc(b.year, b.month, b.day);
    return bDate.difference(aDate).inDays;
  }
}
