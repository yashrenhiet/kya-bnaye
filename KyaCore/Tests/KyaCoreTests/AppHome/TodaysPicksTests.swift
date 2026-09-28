import Foundation
import KyaCore
import Testing

@Suite("TodaysPicks")
struct TodaysPicksTests {
    private func event(
        _ id: String, _ recipeId: String, _ action: SwipeAction, _ at: Date,
        mode: SwipeMode = .kitchen, undoes: String? = nil
    ) -> SwipeEvent {
        SwipeEvent(
            id: id, recipeId: recipeId, action: action, mode: mode, at: at, deckSeed: 7,
            undoesEventId: undoes)
    }

    private func cooked(_ id: String, _ recipeId: String, _ at: Date) -> MealLog {
        MealLog(id: id, recipeId: recipeId, mealType: .dinner, cookedAt: at)
    }

    @Test("today's right swipes are picks, newest first; left and never-show are not")
    func rightSwipesOnly() throws {
        let utc = TestDates.utcCalendar
        let now = try TestDates.utc(2026, 9, 23, 20)
        let events = [
            event("1", "poha", .right, try TestDates.utc(2026, 9, 23, 8)),
            event("2", "dal", .left, try TestDates.utc(2026, 9, 23, 9)),
            event("3", "rajma", .right, try TestDates.utc(2026, 9, 23, 19), mode: .craving),
            event("4", "upma", .neverShow, try TestDates.utc(2026, 9, 23, 19, 30)),
        ]

        let picks = TodaysPicks.derive(events: events, mealLogs: [], now: now, calendar: utc)

        #expect(picks.map(\.recipeId) == ["rajma", "poha"])
        #expect(picks.map(\.eventId) == ["3", "1"])
        #expect(picks.map(\.mode) == [.craving, .kitchen])
        #expect(picks.first?.pickedAt == (try TestDates.utc(2026, 9, 23, 19)))
        #expect(picks.allSatisfy { $0.cookedAt == nil })
    }

    @Test("an undone right swipe is no longer a pick, and an undone undo does not resurrect it")
    func undoRemovesPick() throws {
        let utc = TestDates.utcCalendar
        let now = try TestDates.utc(2026, 9, 23, 20)
        let right = event("r", "poha", .right, try TestDates.utc(2026, 9, 23, 10))
        let undo = event("u", "poha", .undo, try TestDates.utc(2026, 9, 23, 10, 1), undoes: "r")
        let undoOfUndo = event(
            "uu", "poha", .undo, try TestDates.utc(2026, 9, 23, 10, 2), undoes: "u")

        #expect(
            TodaysPicks.derive(events: [right], mealLogs: [], now: now, calendar: utc).count == 1)
        #expect(
            TodaysPicks.derive(events: [right, undo], mealLogs: [], now: now, calendar: utc)
                .isEmpty)
        #expect(
            TodaysPicks.derive(
                events: [undoOfUndo, undo, right], mealLogs: [], now: now, calendar: utc
            ).isEmpty)
    }

    @Test("picks clear at midnight in the calendar's time zone")
    func midnightRollover() throws {
        let ist = try TestDates.calendar(zone: "Asia/Kolkata")
        let lateNight = try TestDates.local(2026, 9, 23, 23, 50, calendar: ist)
        let events = [event("1", "maggi", .right, lateNight)]

        let beforeMidnight = try TestDates.local(2026, 9, 23, 23, 59, calendar: ist)
        let afterMidnight = try TestDates.local(2026, 9, 24, 0, 1, calendar: ist)

        #expect(
            TodaysPicks.derive(events: events, mealLogs: [], now: beforeMidnight, calendar: ist)
                .map(\.recipeId) == ["maggi"])
        #expect(
            TodaysPicks.derive(events: events, mealLogs: [], now: afterMidnight, calendar: ist)
                .isEmpty)
    }

    @Test("\"today\" is decided by the injected calendar, not UTC")
    func timeZoneSafe() throws {
        let ist = try TestDates.calendar(zone: "Asia/Kolkata")
        // 23 Sep 19:00 UTC is already 24 Sep 00:30 in India.
        let swipe = try TestDates.utc(2026, 9, 23, 19)
        let now = try TestDates.utc(2026, 9, 24, 6)  // 24 Sep in both zones
        let events = [event("1", "idli", .right, swipe)]

        #expect(
            TodaysPicks.derive(events: events, mealLogs: [], now: now, calendar: ist)
                .map(\.recipeId) == ["idli"])
        #expect(
            TodaysPicks.derive(
                events: events, mealLogs: [], now: now, calendar: TestDates.utcCalendar
            ).isEmpty)
    }

    @Test("a dish picked twice appears once, at its latest pick")
    func deduplicates() throws {
        let utc = TestDates.utcCalendar
        let now = try TestDates.utc(2026, 9, 23, 20)
        let events = [
            event("1", "poha", .right, try TestDates.utc(2026, 9, 23, 8)),
            event("2", "dal", .right, try TestDates.utc(2026, 9, 23, 9)),
            event("3", "poha", .right, try TestDates.utc(2026, 9, 23, 10), mode: .craving),
        ]

        let picks = TodaysPicks.derive(events: events, mealLogs: [], now: now, calendar: utc)

        #expect(picks.map(\.recipeId) == ["poha", "dal"])
        #expect(picks.first?.eventId == "3")
    }

    @Test("a later left or never-show today withdraws the pick; equal times break ties by id")
    func laterEventWins() throws {
        let utc = TestDates.utcCalendar
        let now = try TestDates.utc(2026, 9, 23, 20)
        let ten = try TestDates.utc(2026, 9, 23, 10)
        let events = [
            event("1", "poha", .right, ten),
            event("2", "poha", .neverShow, try TestDates.utc(2026, 9, 23, 11)),
            event("b", "dal", .right, ten),
            event("a", "dal", .left, ten),
        ]

        let picks = TodaysPicks.derive(events: events, mealLogs: [], now: now, calendar: utc)

        #expect(picks.map(\.recipeId) == ["dal"])
    }

    @Test("a meal cooked today after the pick marks it made; earlier cooks do not")
    func cookedMarking() throws {
        let utc = TestDates.utcCalendar
        let now = try TestDates.utc(2026, 9, 23, 21)
        let events = [
            event("1", "poha", .right, try TestDates.utc(2026, 9, 23, 8)),
            event("2", "dal", .right, try TestDates.utc(2026, 9, 23, 12)),
        ]
        let logs = [
            cooked("m1", "poha", try TestDates.utc(2026, 9, 23, 9)),
            cooked("m2", "poha", try TestDates.utc(2026, 9, 23, 10)),
            cooked("m3", "dal", try TestDates.utc(2026, 9, 23, 11)),
            cooked("m4", "dal", try TestDates.utc(2026, 9, 22, 20)),
        ]

        let picks = TodaysPicks.derive(events: events, mealLogs: logs, now: now, calendar: utc)

        #expect(picks.map(\.recipeId) == ["dal", "poha"])
        #expect(picks.map(\.cookedAt) == [nil, try TestDates.utc(2026, 9, 23, 10)])
        #expect(picks.last?.isMade == true)
        #expect(picks.first?.isMade == false)
    }

    @Test("swipes from earlier days are never picks")
    func earlierDays() throws {
        let utc = TestDates.utcCalendar
        let now = try TestDates.utc(2026, 9, 23, 0, 5)
        let events = [event("1", "poha", .right, try TestDates.utc(2026, 9, 22, 23, 55))]
        #expect(TodaysPicks.derive(events: events, mealLogs: [], now: now, calendar: utc).isEmpty)
        #expect(TodaysPicks.derive(events: [], mealLogs: [], now: now, calendar: utc).isEmpty)
    }

    @Test("the next rollover is the start of the next calendar date, across DST")
    func nextRollover() throws {
        let newYork = try TestDates.calendar(zone: "America/New_York")
        // 8 Mar 2026 is a 23-hour day in New York.
        let now = try TestDates.local(2026, 3, 8, 12, calendar: newYork)
        let expected = try TestDates.local(2026, 3, 9, 0, calendar: newYork)
        #expect(TodaysPicks.nextRollover(after: now, calendar: newYork) == expected)

        let ist = try TestDates.calendar(zone: "Asia/Kolkata")
        let lateNight = try TestDates.local(2026, 9, 23, 23, 59, 59, calendar: ist)
        #expect(
            TodaysPicks.nextRollover(after: lateNight, calendar: ist)
                == (try TestDates.local(2026, 9, 24, calendar: ist)))
    }
}
