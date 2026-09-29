import Foundation
import Testing

@testable import KyaBnaye

@Suite("DeckStore scheduling")
@MainActor
struct DeckSchedulingTests {
    private static var newYork: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ month: Int, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(
            Self.newYork.date(
                from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
            ))
    }

    private func wallClock(_ date: Date) -> [Int] {
        let parts = Self.newYork.dateComponents([.day, .hour, .minute], from: date)
        return [parts.day ?? -1, parts.hour ?? -1, parts.minute ?? -1]
    }

    @Test(
        "the next slot change is the next local boundary hour, even on DST days",
        arguments: [
            // (day, month, hour, minute) -> (day, hour) of the expected wake-up
            ([8, 3, 1, 0], [8, 5]),  // spring forward: 23-hour day, still 05:00 local
            ([1, 11, 1, 0], [1, 5]),  // fall back: 25-hour day, still 05:00 local
            ([8, 3, 12, 0], [8, 16]),
            ([23, 9, 10, 59], [23, 11]),
            ([23, 9, 19, 0], [24, 5]),  // exactly on a boundary: the next one
            ([23, 9, 23, 30], [24, 5]),
        ])
    func nextSlotChange(now: [Int], expected: [Int]) throws {
        let start = try date(now[0], now[1], now[2], now[3])

        let next = DeckStore.nextMealSlotChange(after: start, calendar: Self.newYork)

        #expect(wallClock(next) == [expected[0], expected[1], 0])
        #expect(next > start)
    }
}
