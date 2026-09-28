import Foundation
import KyaCore
import Testing

@Suite("MealHistory")
struct MealHistoryTests {
    private func log(_ id: String, _ recipeId: String, _ at: Date) -> MealLog {
        MealLog(id: id, recipeId: recipeId, mealType: .dinner, cookedAt: at)
    }

    @Test("groups by calendar date in the given time zone, newest day and meal first")
    func groupsByLocalDate() throws {
        let ist = try TestDates.calendar(zone: "Asia/Kolkata")
        let lateNight = try TestDates.utc(2026, 9, 20, 18, 0)  // 20 Sep 23:30 IST
        let afterMidnight = try TestDates.utc(2026, 9, 20, 19, 0)  // 21 Sep 00:30 IST
        let lunch = try TestDates.utc(2026, 9, 21, 7, 0)  // 21 Sep 12:30 IST
        let now = try TestDates.utc(2026, 9, 23, 6, 0)  // 23 Sep IST
        let logs = [
            log("a", "dal", lateNight), log("b", "poha", afterMidnight), log("c", "rajma", lunch),
        ]

        let days = MealHistory.days(logs, now: now, calendar: ist)
        #expect(days.map { $0.logs.map(\.id) } == [["c", "b"], ["a"]])
        #expect(days.map(\.daysAgo) == [2, 3])
        #expect(days[0].day == ist.startOfDay(for: lunch))

        let utcDays = MealHistory.days(logs, now: now, calendar: TestDates.utcCalendar)
        #expect(utcDays.map { $0.logs.map(\.id) } == [["c"], ["b", "a"]])
    }

    @Test("empty history has no days")
    func empty() {
        #expect(MealHistory.days([], now: .now, calendar: TestDates.utcCalendar).isEmpty)
    }

    @Test("equal timestamps order by id descending so the order is stable")
    func stableTies() throws {
        let at = try TestDates.utc(2026, 1, 1, 12)
        let days = MealHistory.days(
            [log("a", "x", at), log("b", "y", at)], now: at, calendar: TestDates.utcCalendar)
        #expect(days.first?.logs.map(\.id) == ["b", "a"])
        #expect(days.first?.daysAgo == 0)
    }

    @Test("lastCooked keeps the latest cook per recipe regardless of input order")
    func lastCooked() throws {
        let early = try TestDates.utc(2026, 1, 1)
        let late = try TestDates.utc(2026, 1, 5)
        let result = MealHistory.lastCooked([
            log("2", "dal", late), log("1", "dal", early), log("3", "poha", early),
        ])
        #expect(result == ["dal": late, "poha": early])
    }

    @Test("daysSince counts calendar dates, across a DST change")
    func daysSince() throws {
        let newYork = try TestDates.calendar(zone: "America/New_York")
        let before = try TestDates.local(2026, 3, 7, 23, 0, calendar: newYork)
        let after = try TestDates.local(2026, 3, 9, 0, 30, calendar: newYork)
        #expect(MealHistory.daysSince(before, now: after, calendar: newYork) == 2)
        #expect(MealHistory.daysSince(after, now: after, calendar: newYork) == 0)
    }

    @Test("the current meal slot follows the hour in the calendar's time zone")
    func currentMealType() throws {
        let ist = try TestDates.calendar(zone: "Asia/Kolkata")
        let instant = try TestDates.utc(2026, 9, 20, 2, 0)  // 07:30 IST, 02:00 UTC
        #expect(MealHistory.currentMealType(now: instant, calendar: ist) == .breakfast)
        #expect(
            MealHistory.currentMealType(now: instant, calendar: TestDates.utcCalendar) == .dinner)
    }
}
