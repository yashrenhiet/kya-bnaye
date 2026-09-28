import Foundation
import Testing

/// Date builders for tests. Dart's `DateTime(y, m, d, h, min)` is local wall
/// time; ``local(_:_:_:_:_:_:calendar:)`` mirrors it in `Calendar.kyaDefault`
/// (the `TZ` environment variable decides the zone).
enum TestDates {
    /// A UTC Gregorian calendar.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    /// A Gregorian calendar in the named time zone.
    static func calendar(zone identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    /// Wall-clock time in `calendar` (defaults to the process-local calendar).
    static func local(
        _ year: Int,
        _ month: Int = 1,
        _ day: Int = 1,
        _ hour: Int = 0,
        _ minute: Int = 0,
        _ second: Int = 0,
        calendar: Calendar = .kyaDefault
    ) throws -> Date {
        let components = DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return try #require(calendar.date(from: components))
    }

    /// Wall-clock time in UTC.
    static func utc(
        _ year: Int,
        _ month: Int = 1,
        _ day: Int = 1,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) throws -> Date {
        try local(year, month, day, hour, minute, calendar: utcCalendar)
    }
}
