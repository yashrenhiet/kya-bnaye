import Foundation

/// The meals cooked on one calendar date.
public struct MealHistoryDay: Sendable, Hashable {
    /// Start of the date in the grouping calendar.
    public let day: Date
    /// Calendar days from this date to "now" (`0` = today).
    public let daysAgo: Int
    /// The meals, newest first.
    public let logs: [MealLog]

    /// Creates a day group.
    ///
    /// - Parameters:
    ///   - day: Start of the date.
    ///   - daysAgo: Calendar days before now.
    ///   - logs: The meals, newest first.
    public init(day: Date, daysAgo: Int, logs: [MealLog]) {
        self.day = day
        self.daysAgo = daysAgo
        self.logs = logs
    }
}

/// Read-side helpers for the "I made this" history screen and recipe detail.
public enum MealHistory {
    /// Groups meal logs by calendar date in `calendar`'s time zone.
    ///
    /// - Parameters:
    ///   - logs: Meal logs in any order.
    ///   - now: The reference instant for ``MealHistoryDay/daysAgo``.
    ///   - calendar: Decides dates; pass the app's injected calendar.
    /// - Returns: One group per date, newest date first; within a date,
    ///   newest meal first (equal times by id, descending).
    public static func days(_ logs: [MealLog], now: Date, calendar: Calendar) -> [MealHistoryDay] {
        let newestFirst = logs.sorted {
            $0.cookedAt == $1.cookedAt ? $0.id > $1.id : $0.cookedAt > $1.cookedAt
        }
        var days: [MealHistoryDay] = []
        var current: [MealLog] = []
        var currentDay: Date?
        for log in newestFirst {
            let day = calendar.startOfDay(for: log.cookedAt)
            if let currentDay, currentDay != day {
                days.append(group(currentDay, current, now: now, calendar: calendar))
                current = []
            }
            currentDay = day
            current.append(log)
        }
        if let currentDay {
            days.append(group(currentDay, current, now: now, calendar: calendar))
        }
        return days
    }

    /// The latest cook time per recipe id.
    ///
    /// - Parameter logs: Meal logs in any order.
    /// - Returns: Recipe id to its most recent ``MealLog/cookedAt``.
    public static func lastCooked(_ logs: [MealLog]) -> [String: Date] {
        logs.reduce(into: [:]) { latest, log in
            if latest[log.recipeId].map({ $0 < log.cookedAt }) ?? true {
                latest[log.recipeId] = log.cookedAt
            }
        }
    }

    /// Calendar days from `date` to `now` ("last made N days ago"), DST-safe.
    ///
    /// - Parameters:
    ///   - date: The earlier instant.
    ///   - now: The reference instant.
    ///   - calendar: Decides dates.
    /// - Returns: `0` for the same date, positive for earlier dates.
    public static func daysSince(_ date: Date, now: Date, calendar: Calendar) -> Int {
        calendar.calendarDays(from: date, to: now)
    }

    /// The meal slot a cook at `now` is logged under, using the same hour
    /// bands as the deck (``RankingContext/mealType(forHour:)``).
    ///
    /// - Parameters:
    ///   - now: The instant of cooking.
    ///   - calendar: Decides the hour.
    /// - Returns: The meal slot.
    public static func currentMealType(now: Date, calendar: Calendar) -> MealType {
        RankingContext.mealType(forHour: calendar.component(.hour, from: now))
    }

    private static func group(
        _ day: Date, _ logs: [MealLog], now: Date, calendar: Calendar
    ) -> MealHistoryDay {
        MealHistoryDay(
            day: day, daysAgo: daysSince(day, now: now, calendar: calendar), logs: logs)
    }
}
