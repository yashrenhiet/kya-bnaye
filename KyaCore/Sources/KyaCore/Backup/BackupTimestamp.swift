import Foundation

/// ISO-8601 timestamps for backup files. Internal; see ``BackupCodec`` for
/// the documented contract.
///
/// **Writing** always produces UTC with an explicit `Z`, in the Dart oracle's
/// `DateTime.toIso8601String()` shape: `2026-09-26T12:00:00.000Z`, or six
/// fraction digits when the instant has sub-millisecond precision
/// (`2026-03-01T04:05:06.789012Z`). Instants are rounded to the microsecond
/// (Dart's `DateTime` precision).
///
/// **Reading** accepts the grammar of Dart's `DateTime.parse`: optional time,
/// `T` or space separator, optional `:`/`-` separators, `.` or `,` fraction
/// (digits past the sixth are truncated, like Dart), and `Z`/`z` or a
/// `±hh[[:]mm]` offset. A timestamp with no zone is wall-clock time in the
/// codec's local time zone. Unlike Dart, out-of-range fields (month 13,
/// February 30, hour 24) are rejected instead of silently rolled over.
///
/// Pure integer calendar arithmetic (proleptic Gregorian, no `DateFormatter`),
/// so the output never depends on the device locale or time zone.
enum BackupTimestamp {
    private static let secondsFrom1970To2001 = 978_307_200
    private static let secondsPerDay = 86_400

    /// Dart's `DateTime.parse` pattern, with ASCII-only digits (ICU's `\d`
    /// also matches other scripts' digits) and `\z` (ICU's `$` also matches
    /// before a trailing newline; JavaScript's, used by Dart, does not).
    private static let pattern =
        #"^([+-]?[0-9]{4,6})-?([0-9]{2})-?([0-9]{2})"#
        + #"(?:[ T]([0-9]{2})(?::?([0-9]{2})(?::?([0-9]{2})(?:[.,]([0-9]+))?)?)?"#
        + #"( ?[zZ]| ?([-+])([0-9]{2})(?::?([0-9]{2}))?)?)?\z"#

    /// Dart's `DateTime` range: ±100,000,000 days around 1970-01-01.
    private static let maxEpochSeconds = 8_640_000_000_000

    // MARK: Writing

    /// Whether `secondsSinceReferenceDate` (a `Date`'s
    /// `timeIntervalSinceReferenceDate`, i.e. seconds since
    /// 2001-01-01T00:00:00Z) lies within Dart's `DateTime` range (about
    /// ±275,000 years).
    ///
    /// Shared by ``string(from:)`` and ``date(from:localTimeZone:)`` so a
    /// timestamp neither codec direction can produce is also one neither can
    /// consume: a restored backup can never contain an instant this codec
    /// would refuse to re-export.
    private static func isRepresentable(secondsSinceReferenceDate: Double) -> Bool {
        secondsSinceReferenceDate.isFinite
            && abs(secondsSinceReferenceDate + Double(secondsFrom1970To2001))
                <= Double(maxEpochSeconds)
    }

    /// The UTC ISO-8601 string for `date`, or `nil` if it is not finite or
    /// lies outside Dart's `DateTime` range (about ±275,000 years), so every
    /// written timestamp is readable by both this codec and the oracle.
    static func string(from date: Date) -> String? {
        let interval = date.timeIntervalSinceReferenceDate
        guard isRepresentable(secondsSinceReferenceDate: interval) else { return nil }
        var whole = interval.rounded(.down)
        var micros = Int(((interval - whole) * 1_000_000).rounded())
        if micros == 1_000_000 {
            whole += 1
            micros = 0
        }
        let epoch = Int(whole) + secondsFrom1970To2001
        let days = floorDiv(epoch, secondsPerDay)
        let secondOfDay = epoch - days * secondsPerDay
        let (year, month, day) = civil(fromDays: days)
        let fraction = micros % 1000 == 0 ? pad(micros / 1000, 3) : pad(micros, 6)
        return "\(yearText(year))-\(pad(month, 2))-\(pad(day, 2))T"
            + "\(pad(secondOfDay / 3600, 2)):\(pad(secondOfDay % 3600 / 60, 2)):"
            + "\(pad(secondOfDay % 60, 2)).\(fraction)Z"
    }

    // MARK: Reading

    /// Parses `text`; a zone-less timestamp is wall-clock time in
    /// `localTimeZone`. Returns `nil` when `text` is not a valid timestamp.
    static func date(from text: String, localTimeZone: TimeZone) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        func group(_ index: Int) -> String? {
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
        func number(_ index: Int) -> Int? { group(index).flatMap { Int($0) } }

        guard let year = number(1), let month = number(2), let day = number(3),
            (1...12).contains(month), (1...daysIn(month, of: year)).contains(day)
        else { return nil }
        let hour = number(4) ?? 0
        let minute = number(5) ?? 0
        let second = number(6) ?? 0
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second)
        else { return nil }
        let micros = group(7).flatMap(microseconds(fromFraction:)) ?? 0

        let wholeSeconds: Int
        if group(8) == nil {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = localTimeZone
            let components = DateComponents(
                year: year, month: month, day: day, hour: hour, minute: minute, second: second)
            guard let local = calendar.date(from: components) else { return nil }
            wholeSeconds = Int(local.timeIntervalSinceReferenceDate.rounded(.down))
        } else {
            let offsetHours = number(10) ?? 0
            let offsetMinutes = number(11) ?? 0
            guard (0...23).contains(offsetHours), (0...59).contains(offsetMinutes) else {
                return nil
            }
            let sign = group(9) == "-" ? -1 : 1
            let offset = sign * (offsetHours * 3600 + offsetMinutes * 60)
            let epoch =
                daysFromCivil(year: year, month: month, day: day) * secondsPerDay
                + hour * 3600 + minute * 60 + second - offset
            wholeSeconds = epoch - secondsFrom1970To2001
        }
        let interval = Double(wholeSeconds) + Double(micros) / 1_000_000
        // Reject a timestamp this codec could never write back out (see
        // `isRepresentable(secondsSinceReferenceDate:)`) instead of silently
        // accepting an instant `string(from:)` would refuse to re-export. The
        // fractional part matters: a whole-seconds value exactly at the limit
        // still overflows once its microseconds are added.
        guard isRepresentable(secondsSinceReferenceDate: interval) else { return nil }
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    /// First six fraction digits as microseconds (right-padded, truncated).
    private static func microseconds(fromFraction digits: String) -> Int? {
        let six = String((digits + "000000").prefix(6))
        return Int(six)
    }

    // MARK: Calendar arithmetic (Howard Hinnant's civil-date algorithms)

    private static func floorDiv(_ lhs: Int, _ rhs: Int) -> Int {
        let quotient = lhs / rhs
        return (lhs % rhs != 0 && (lhs < 0) != (rhs < 0)) ? quotient - 1 : quotient
    }

    private static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    private static func daysIn(_ month: Int, of year: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    /// Days since 1970-01-01 for a proleptic Gregorian date.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = floorDiv(shiftedYear, 400)
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// Proleptic Gregorian date for days since 1970-01-01.
    private static func civil(fromDays days: Int) -> (year: Int, month: Int, day: Int) {
        let shifted = days + 719_468
        let era = floorDiv(shifted, 146_097)
        let dayOfEra = shifted - era * 146_097
        let yearOfEra =
            (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    // MARK: Formatting

    /// Dart's year format: four digits within ±9999, else a sign and six.
    private static func yearText(_ year: Int) -> String {
        let sign = year < 0 ? "-" : (year > 9999 ? "+" : "")
        return sign + pad(abs(year), abs(year) > 9999 ? 6 : 4)
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
