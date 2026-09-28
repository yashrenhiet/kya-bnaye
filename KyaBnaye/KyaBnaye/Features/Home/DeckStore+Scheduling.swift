import Foundation
import KyaCore

/// Wakes the deck for midnight and meal-slot rollovers. Split out of `DeckStore.swift` to
/// keep that file under the line-count limit.
extension DeckStore {
    /// Wakes ``refreshForNewDay()`` at the next midnight **and** the next meal-slot change,
    /// so a session left open in the foreground (no background/foreground cycle to trigger
    /// `HomeView`'s `scenePhase` handler) still moves off a stale slot, e.g. lunch cards with
    /// "expires today" reasons still showing at 4pm. `refreshForNewDay()` itself decides
    /// whether a rebuild is actually needed.
    func followDays() async throws {
        while true {
            let current = now()
            let midnight = TodaysPicks.nextRollover(after: current, calendar: calendar())
            let nextSlot = Self.nextMealSlotChange(after: current, calendar: calendar())
            let next = min(midnight, nextSlot)
            try await Task.sleep(for: .seconds(max(next.timeIntervalSince(current), 1)))
            await refreshForNewDay()
        }
    }

    /// The next hour boundary (in `calendar`) at which
    /// ``RankingContext/mealType(forHour:)`` changes: 05:00, 11:00, 16:00 or 19:00, on
    /// `now`'s date or the next one if every boundary today has passed.
    static func nextMealSlotChange(after now: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: now)
        let boundaries = [5, 11, 16, 19].compactMap {
            calendar.date(byAdding: .hour, value: $0, to: startOfDay)
        }
        if let today = boundaries.first(where: { $0 > now }) { return today }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let tomorrowFiveAM = calendar.date(byAdding: .hour, value: 5, to: tomorrow)
        return tomorrowFiveAM ?? now.addingTimeInterval(3_600)
    }
}
