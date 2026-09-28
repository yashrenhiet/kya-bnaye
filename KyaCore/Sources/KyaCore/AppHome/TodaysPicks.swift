import Foundation

/// One dish on Home's "Today's picks" tray: a recipe the user swiped right on today.
public struct TodaysPick: Sendable, Hashable {
    /// The picked ``Recipe/id``.
    public let recipeId: String
    /// The right-swipe ``SwipeEvent/id`` that makes it a pick (the latest one today).
    public let eventId: String
    /// When it was picked.
    public let pickedAt: Date
    /// The deck mode it was picked in.
    public let mode: SwipeMode
    /// The latest "I made this" for the recipe today at or after ``pickedAt``, if any.
    public let cookedAt: Date?

    /// Creates a pick.
    ///
    /// - Parameters:
    ///   - recipeId: The picked recipe id.
    ///   - eventId: The right-swipe event id.
    ///   - pickedAt: When it was picked.
    ///   - mode: The deck mode.
    ///   - cookedAt: When it was made after picking, or `nil`.
    public init(
        recipeId: String, eventId: String, pickedAt: Date, mode: SwipeMode, cookedAt: Date?
    ) {
        self.recipeId = recipeId
        self.eventId = eventId
        self.pickedAt = pickedAt
        self.mode = mode
        self.cookedAt = cookedAt
    }

    /// Whether the dish was made after it was picked.
    public var isMade: Bool { cookedAt != nil }
}

/// Derives "Today's picks" (F4c) from the append-only swipe log. Picks are never stored
/// (ADR 008): they can't go stale, an undo removes a pick simply by being appended, and
/// they clear at midnight because "today" is recomputed from the clock.
public enum TodaysPicks {
    /// Today's picks, newest first.
    ///
    /// A recipe is a pick when its latest **active** event (see
    /// ``SwipeEvent/activeEvents(_:)``) on today's calendar date is a right swipe. So an
    /// undone right swipe is not a pick, and a later left or never-show swipe today
    /// withdraws it. Events are ordered by ``SwipeEvent/at``, ties by ``SwipeEvent/id``, so
    /// the result never depends on the input order.
    ///
    /// - Parameters:
    ///   - events: The full swipe log, including undo events, in any order.
    ///   - mealLogs: Cooking history, used only for ``TodaysPick/cookedAt``.
    ///   - now: The reference instant; decides "today".
    ///   - calendar: Decides calendar dates; pass the app's injected calendar.
    /// - Returns: One pick per recipe, newest ``TodaysPick/pickedAt`` first (ties by
    ///   event id, descending); empty when nothing was picked today.
    public static func derive(
        events: [SwipeEvent], mealLogs: [MealLog], now: Date, calendar: Calendar
    ) -> [TodaysPick] {
        let isToday = { (date: Date) in calendar.isDate(date, inSameDayAs: now) }
        var latestByRecipe: [String: SwipeEvent] = [:]
        for event in SwipeEvent.activeEvents(events) where isToday(event.at) {
            if let current = latestByRecipe[event.recipeId], !isLater(event, than: current) {
                continue
            }
            latestByRecipe[event.recipeId] = event
        }
        return latestByRecipe.values
            .filter { $0.action == .right }
            .sorted { isLater($0, than: $1) }
            .map { event in
                TodaysPick(
                    recipeId: event.recipeId, eventId: event.id, pickedAt: event.at,
                    mode: event.mode,
                    cookedAt: mealLogs.lazy
                        .filter { $0.recipeId == event.recipeId && $0.cookedAt >= event.at }
                        .map(\.cookedAt)
                        .filter(isToday)
                        .max())
            }
    }

    /// When the picks next clear: the start of the calendar date after `now`'s.
    ///
    /// DST-safe: a 23- or 25-hour day still rolls over at its real midnight (or the first
    /// instant of the next date where midnight does not exist).
    ///
    /// - Parameters:
    ///   - now: The reference instant.
    ///   - calendar: Decides calendar dates.
    /// - Returns: The first instant of the next calendar date; an hour after `now` in the
    ///   (theoretical) case the calendar cannot compute it.
    public static func nextRollover(after now: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .day, for: now)?.end ?? now.addingTimeInterval(3_600)
    }

    private static func isLater(_ lhs: SwipeEvent, than rhs: SwipeEvent) -> Bool {
        lhs.at != rhs.at ? lhs.at > rhs.at : lhs.id > rhs.id
    }
}
