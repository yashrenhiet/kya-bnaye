import Foundation

extension Calendar {
    /// The calendar KyaCore uses when a caller does not pass one: Gregorian, in
    /// the device's current time zone (`TimeZone.current`, which honours the
    /// `TZ` environment variable on macOS/Linux).
    ///
    /// Computed on each access so a time-zone change is picked up immediately.
    /// Pass an explicit calendar wherever determinism matters (tests, golden
    /// fixtures).
    public static var kyaDefault: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Whole calendar days from the date of `start` to the date of `end` in this
    /// calendar's time zone, ignoring time of day.
    ///
    /// Reads each instant's calendar date (era, year, month, day) in this
    /// calendar's time zone, then counts days between those dates in the same
    /// calendar pinned to GMT, which has no DST. A 23- or 25-hour DST day, or a
    /// day whose midnight does not exist (e.g. America/Havana, where clocks jump
    /// from 00:00 to 01:00), still counts as exactly one day. Never divides a
    /// seconds interval by 86 400.
    ///
    /// - Parameters:
    ///   - start: The reference instant.
    ///   - end: The target instant.
    /// - Returns: Positive when `end` falls on a later calendar date, `0` on the
    ///   same date, negative when earlier.
    public func calendarDays(from start: Date, to end: Date) -> Int {
        var dateOnly = self
        dateOnly.timeZone = .gmt
        let units: Set<Calendar.Component> = [.era, .year, .month, .day]
        guard let startDate = dateOnly.date(from: dateComponents(units, from: start)),
            let endDate = dateOnly.date(from: dateComponents(units, from: end))
        else { return 0 }
        return dateOnly.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}
