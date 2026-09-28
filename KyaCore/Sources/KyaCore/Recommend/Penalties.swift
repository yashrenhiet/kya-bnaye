import Foundation

/// Shared penalty functions used by both ``KitchenRanker`` and
/// ``CravingRanker`` (`docs/design/RECOMMENDER.md` section 5, "Shared
/// penalties").
///
/// Kept as static functions rather than ranker methods so they can be tested
/// in isolation and so both rankers provably use the same formula.
public enum Penalties {
    /// Discourages suggesting a dish again too soon after it was cooked, plus a
    /// "rut" top-up when it was cooked unusually often recently.
    ///
    /// Steps by whole calendar days since `lastCookedAt`: ≤7 → 7-day penalty,
    /// ≤14, ≤28, ≤56, then 0. Every cook beyond the first inside
    /// ``ScoringConfig/repeatRutWindowDays`` adds
    /// ``ScoringConfig/repeatRutPenaltyPerExtraCook``; zero or negative counts
    /// never produce a bonus.
    ///
    /// - Parameters:
    ///   - lastCookedAt: The most recent cook of the recipe, or `nil` if never.
    ///   - cookCountInRutWindow: Cooks of the recipe inside the rut window.
    ///   - now: The reference instant.
    ///   - config: The scoring weights.
    ///   - calendar: Decides which calendar date each instant falls on.
    /// - Returns: The non-negative penalty; `0` when never cooked.
    public static func repeatPenalty(
        lastCookedAt: Date?,
        cookCountInRutWindow: Int,
        now: Date,
        config: ScoringConfig,
        calendar: Calendar = .kyaDefault
    ) -> Double {
        guard let lastCookedAt else { return 0 }
        let daysSince = calendar.calendarDays(from: lastCookedAt, to: now)
        let step: Double =
            if daysSince <= 7 {
                config.repeatPenaltyWithin7d
            } else if daysSince <= 14 {
                config.repeatPenaltyWithin14d
            } else if daysSince <= 28 {
                config.repeatPenaltyWithin28d
            } else if daysSince <= 56 {
                config.repeatPenaltyWithin56d
            } else {
                0
            }
        let extraCooks = max(cookCountInRutWindow - 1, 0)
        return step + Double(extraCooks) * config.repeatRutPenaltyPerExtraCook
    }

    /// The left-swipe cooldown: excluded entirely inside
    /// ``ScoringConfig/rejectExclusionWindowDays``, penalised inside
    /// ``ScoringConfig/rejectPenaltyWindowDays``, free afterwards.
    ///
    /// A future-dated swipe (clock skew) counts as "today" or earlier and so
    /// stays excluded.
    ///
    /// - Parameters:
    ///   - lastLeftSwipeAt: The most recent active left swipe, or `nil`.
    ///   - now: The reference instant.
    ///   - config: The scoring weights.
    ///   - calendar: Decides which calendar date each instant falls on.
    /// - Returns: `nil` when the recipe must be excluded, otherwise the penalty
    ///   (`0` outside the penalty window or with no left swipe).
    public static func rejectPenalty(
        lastLeftSwipeAt: Date?,
        now: Date,
        config: ScoringConfig,
        calendar: Calendar = .kyaDefault
    ) -> Double? {
        guard let lastLeftSwipeAt else { return 0 }
        let daysSince = calendar.calendarDays(from: lastLeftSwipeAt, to: now)
        if daysSince <= config.rejectExclusionWindowDays { return nil }
        if daysSince <= config.rejectPenaltyWindowDays {
            return config.rejectPenaltyWithinWindow
        }
        return 0
    }
}
