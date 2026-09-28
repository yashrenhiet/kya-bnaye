import Foundation
import KyaCore
import Testing

@Suite("Calendar day math")
struct CalendarDaysTests {
    @Test("kyaDefault is Gregorian in the current time zone")
    func kyaDefault() {
        let calendar = Calendar.kyaDefault
        #expect(calendar.identifier == .gregorian)
        #expect(calendar.timeZone == TimeZone.current)
    }

    @Test("counts calendar dates, ignoring time of day, in both directions")
    func ignoresTimeOfDay() throws {
        let calendar = TestDates.utcCalendar
        let start = try TestDates.utc(2025, 6, 9, 23, 59)
        let end = try TestDates.utc(2025, 6, 10, 0, 1)
        #expect(calendar.calendarDays(from: start, to: end) == 1)
        #expect(calendar.calendarDays(from: end, to: start) == -1)
        #expect(calendar.calendarDays(from: start, to: start) == 0)
    }

    @Test("the same instant can be different days in different zones")
    func zoneDecidesTheDate() throws {
        let instant = try TestDates.utc(2025, 6, 1, 20)
        let next = try TestDates.utc(2025, 6, 2, 1)
        #expect(TestDates.utcCalendar.calendarDays(from: instant, to: next) == 1)
        let kolkata = try TestDates.calendar(zone: "Asia/Kolkata")
        #expect(kolkata.calendarDays(from: instant, to: next) == 0)
    }

    @Test(
        "every consecutive day of 2025 is exactly one calendar day apart",
        arguments: [
            "America/New_York", "Europe/London", "Australia/Lord_Howe", "America/Havana",
            "America/Santiago", "Asia/Kolkata", "UTC",
        ])
    func consecutiveDays(zone: String) throws {
        let calendar = try TestDates.calendar(zone: zone)
        var day = try TestDates.local(2025, calendar: calendar)
        var failures: [Date] = []
        while calendar.component(.year, from: day) == 2025 {
            let next = try #require(calendar.date(byAdding: .day, value: 1, to: day))
            if calendar.calendarDays(from: day, to: next) != 1 {
                failures.append(day)
            }
            day = next
        }
        #expect(failures.isEmpty)
    }

    @Test("New York DST days are one calendar day despite 23/25-hour lengths")
    func newYorkTransitions() throws {
        let calendar = try TestDates.calendar(zone: "America/New_York")
        let springStart = try TestDates.local(2025, 3, 9, calendar: calendar)
        let springEnd = try TestDates.local(2025, 3, 10, calendar: calendar)
        #expect(springEnd.timeIntervalSince(springStart) == 23 * 3_600)
        #expect(calendar.calendarDays(from: springStart, to: springEnd) == 1)

        let fallStart = try TestDates.local(2025, 11, 2, calendar: calendar)
        let fallEnd = try TestDates.local(2025, 11, 3, calendar: calendar)
        #expect(fallEnd.timeIntervalSince(fallStart) == 25 * 3_600)
        #expect(calendar.calendarDays(from: fallStart, to: fallEnd) == 1)
        #expect(
            calendar.calendarDays(
                from: try TestDates.local(2025, 11, 2, 23, 30, calendar: calendar),
                to: try TestDates.local(2025, 11, 3, 0, 15, calendar: calendar)) == 1)
    }
}
