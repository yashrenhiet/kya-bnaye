import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

@Suite("HistoryStore")
@MainActor
struct HistoryStoreTests {
    private typealias F = RecipeTestFixtures

    private func observed(
        _ repositories: RepositorySet, now: Date, calendar: Calendar
    ) async -> (HistoryStore, Task<Void, Never>) {
        let store = HistoryStore(repositories: repositories, now: { now }, calendar: { calendar })
        let task = Task { await store.observe() }
        await recipesWaitUntil { store.phase == .loaded }
        return (store, task)
    }

    @Test("empty history loads with no sections")
    func empty() async throws {
        let (store, task) = await observed(
            try await F.repositories(), now: F.now, calendar: try F.calendar())
        defer { task.cancel() }
        #expect(store.sections.isEmpty)
    }

    @Test("groups by date in the injected time zone, newest first, with titles")
    func groupsByLocalDate() async throws {
        let ist = try F.calendar("Asia/Kolkata")
        let utc = try F.calendar("UTC")
        let now = try #require(
            utc.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 6)))
        // 20 Sep 18:00 UTC = 20 Sep 23:30 IST; 20 Sep 19:00 UTC = 21 Sep 00:30 IST.
        let lateNight = try #require(
            utc.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 18)))
        let afterMidnight = try #require(
            utc.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 19)))
        let today = try #require(
            utc.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 5)))
        let logs = [
            MealLog(id: "a", recipeId: "aloo_matar", mealType: .dinner, cookedAt: lateNight),
            MealLog(id: "b", recipeId: "jeera_aloo", mealType: .snack, cookedAt: afterMidnight),
            MealLog(id: "c", recipeId: "gone", mealType: .breakfast, cookedAt: today),
        ]
        let repositories = try await F.repositories(logs: logs)

        let (inIndia, indiaTask) = await observed(repositories, now: now, calendar: ist)
        defer { indiaTask.cancel() }
        #expect(inIndia.sections.map { $0.entries.map(\.id) } == [["c"], ["b"], ["a"]])
        #expect(inIndia.sections.map(\.daysAgo) == [0, 2, 3])
        #expect(inIndia.sections[0].title == "Today")
        #expect(inIndia.sections[1].title.hasSuffix("· 2 days ago"))
        #expect(inIndia.sections[0].entries[0].recipeName == "A deleted recipe")
        #expect(inIndia.sections[1].entries[0].recipeName == "Jeera Aloo")

        let (inUTC, utcTask) = await observed(repositories, now: now, calendar: utc)
        defer { utcTask.cancel() }
        #expect(inUTC.sections.map { $0.entries.map(\.id) } == [["c"], ["b", "a"]])
        #expect(inUTC.sections.map(\.daysAgo) == [0, 3])
    }

    @Test("a meal cooked elsewhere appears without reloading")
    func followsLogs() async throws {
        let repositories = try await F.repositories()
        let (store, task) = await observed(repositories, now: F.now, calendar: try F.calendar())
        defer { task.cancel() }

        try await repositories.mealLogs.add(
            MealLog(id: "new", recipeId: "aloo_matar", mealType: .lunch, cookedAt: F.now))
        await recipesWaitUntil { store.sections.first?.entries.first?.recipeName == "Aloo Matar" }
        #expect(store.sections.first?.title == "Today")
    }
}
