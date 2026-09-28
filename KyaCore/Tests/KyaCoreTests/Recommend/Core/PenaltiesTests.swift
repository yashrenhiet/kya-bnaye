import Foundation
import KyaCore
import Testing

private typealias F = CoreFixtures

private let config = ScoringConfig()

private func repeatPenalty(_ last: Date?, count: Int = 1, now: Date? = nil) -> Double {
    Penalties.repeatPenalty(
        lastCookedAt: last, cookCountInRutWindow: count, now: now ?? F.refNow, config: config)
}

private func rejectPenalty(_ last: Date?, now: Date? = nil) -> Double? {
    Penalties.rejectPenalty(lastLeftSwipeAt: last, now: now ?? F.refNow, config: config)
}

/// Port of `legacy/packages/kya_core/test/recommend/core/penalties_test.dart`.
@Suite("Penalties")
struct PenaltiesTests {
    // MARK: repeatPenalty step boundaries (RECOMMENDER.md 5)

    @Test(
        "repeatPenalty step for days since cooked",
        arguments: [
            (0, 0.30), (1, 0.30), (7, 0.30), (8, 0.20), (14, 0.20), (15, 0.10), (28, 0.10),
            (29, 0.03), (56, 0.03), (57, 0), (90, 0), (365, 0),
        ] as [(Int, Double)])
    func repeatSteps(days: Int, expected: Double) {
        #expect(F.near(repeatPenalty(F.daysAgo(days)), expected))
    }

    @Test("never cooked -> 0 even with a non-zero rut count")
    func neverCooked() {
        #expect(repeatPenalty(nil, count: 5) == 0)
    }

    // MARK: repeatPenalty rut top-up

    @Test("a single cook in the window adds nothing")
    func singleCook() {
        #expect(F.near(repeatPenalty(F.daysAgo(3)), 0.30))
    }

    @Test("each extra cook in the window adds 0.02")
    func extraCooks() {
        #expect(F.near(repeatPenalty(F.daysAgo(3), count: 2), 0.32))
        #expect(F.near(repeatPenalty(F.daysAgo(3), count: 3), 0.34))
        #expect(F.near(repeatPenalty(F.daysAgo(20), count: 6), 0.20))
    }

    @Test("rut still applies after the step penalty has expired")
    func rutAfterStep() {
        #expect(F.near(repeatPenalty(F.daysAgo(60), count: 3), 0.04))
    }

    @Test("zero or negative counts never produce a bonus")
    func noBonus() {
        #expect(F.near(repeatPenalty(F.daysAgo(3), count: 0), 0.30))
        #expect(F.near(repeatPenalty(F.daysAgo(3), count: -4), 0.30))
        #expect(repeatPenalty(F.daysAgo(57), count: 0) == 0)
    }

    @Test("uses the injected config rather than hard-coded weights")
    func repeatCustomConfig() {
        let custom = ScoringConfig(repeatPenaltyWithin7d: 1, repeatRutPenaltyPerExtraCook: 0.5)
        let value = Penalties.repeatPenalty(
            lastCookedAt: F.daysAgo(2), cookCountInRutWindow: 3, now: F.refNow, config: custom)
        #expect(F.near(value, 2))
    }

    // MARK: rejectPenalty (RECOMMENDER.md 5)

    @Test("no left swipe -> 0, not excluded")
    func noLeftSwipe() {
        #expect(rejectPenalty(nil) == 0)
    }

    @Test("days since left swipe -> excluded (nil)", arguments: [0, 1, 2, 3])
    func excluded(days: Int) {
        #expect(rejectPenalty(F.daysAgo(days)) == nil)
    }

    @Test("days since left swipe -> 0.25", arguments: [4, 10, 14])
    func penalised(days: Int) {
        #expect(F.near(rejectPenalty(F.daysAgo(days)), 0.25))
    }

    @Test("days since left swipe -> 0", arguments: [15, 30, 400])
    func free(days: Int) {
        #expect(rejectPenalty(F.daysAgo(days)) == 0)
    }

    @Test("future-dated left swipe (clock skew) stays excluded")
    func futureLeftSwipe() {
        #expect(rejectPenalty(F.later(days: 2)) == nil)
    }

    @Test("uses the injected config windows")
    func rejectCustomConfig() {
        let custom = ScoringConfig(
            rejectExclusionWindowDays: 0, rejectPenaltyWindowDays: 1,
            rejectPenaltyWithinWindow: 0.9)
        func at(_ days: Int) -> Double? {
            Penalties.rejectPenalty(lastLeftSwipeAt: F.daysAgo(days), now: F.refNow, config: custom)
        }
        #expect(at(0) == nil)
        #expect(F.near(at(1), 0.9))
        #expect(at(2) == 0)
    }

    // MARK: day counting is calendar-day based

    @Test("23:59 -> 00:01 next day counts as one day")
    func acrossMidnight() {
        let last = F.wall(2026, 9, 25, 23, 59)
        let now = F.wall(2026, 9, 26, 0, 1)
        #expect(F.near(repeatPenalty(last, now: now), 0.30))
        #expect(rejectPenalty(last, now: now) == nil)
    }

    @Test("3 days + 2 minutes elapsed is 4 calendar days: not excluded")
    func threeDaysTwoMinutes() {
        let last = F.wall(2026, 9, 22, 23, 59)
        let now = F.wall(2026, 9, 26, 0, 1)
        #expect(F.near(rejectPenalty(last, now: now), 0.25))
    }

    @Test("7 days 23:58 elapsed within the same calendar span is 7 days")
    func sevenDaysLong() {
        let last = F.wall(2026, 9, 19, 0, 1)
        let now = F.wall(2026, 9, 26, 23, 59)
        #expect(F.near(repeatPenalty(last, now: now), 0.30))
    }

    @Test("just over 7 days elapsed but 8 calendar days -> 0.20")
    func eightCalendarDays() {
        let last = F.wall(2026, 9, 18, 23, 59)
        let now = F.wall(2026, 9, 26, 0, 1)
        #expect(F.near(repeatPenalty(last, now: now), 0.20))
    }

    @Test("14 -> 15 calendar days at midnight boundary")
    func fourteenToFifteen() {
        let now = F.wall(2026, 9, 26, 0, 1)
        #expect(F.near(rejectPenalty(F.wall(2026, 9, 12), now: now), 0.25))
        #expect(rejectPenalty(F.wall(2026, 9, 11, 23, 59), now: now) == 0)
    }

    @Test("month and year rollovers count calendar days")
    func rollovers() {
        #expect(
            F.near(repeatPenalty(F.wall(2025, 12, 31, 22), now: F.wall(2026, 1, 8, 6)), 0.20))
        // 2028 is a leap year: Feb 28 -> Mar 1 spans two calendar days.
        #expect(rejectPenalty(F.wall(2028, 2, 27, 12), now: F.wall(2028, 3, 1, 12)) == nil)
        #expect(
            F.near(rejectPenalty(F.wall(2028, 2, 26, 12), now: F.wall(2028, 3, 1, 12)), 0.25))
    }

    @Test("a DST spring-forward night does not shorten the day count")
    func springForward() {
        // US DST starts 2026-03-08, EU DST starts 2026-03-29.
        let usNow = F.wall(2026, 3, 9, 12)
        #expect(F.near(rejectPenalty(F.wall(2026, 3, 5, 12), now: usNow), 0.25))
        #expect(F.near(repeatPenalty(F.wall(2026, 3, 1, 12), now: usNow), 0.20))
        let euNow = F.wall(2026, 3, 30, 12)
        #expect(F.near(rejectPenalty(F.wall(2026, 3, 26, 12), now: euNow), 0.25))
        #expect(F.near(repeatPenalty(F.wall(2026, 3, 22, 12), now: euNow), 0.20))
    }
}
