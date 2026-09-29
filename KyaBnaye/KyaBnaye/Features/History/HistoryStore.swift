import Foundation
import KyaCore
import Observation

/// One cooked meal as shown in History.
struct HistoryEntry: Identifiable, Equatable {
    /// The meal log id.
    let id: String
    /// The dish name, or a fallback when the recipe was deleted.
    let recipeName: String
    /// The recipe id (for the artwork).
    let recipeId: String
    /// The recipe's bundled photo (``KyaCore/Recipe/imageAsset``), or `nil` if it has none
    /// or was deleted (the artwork then falls back to its gradient).
    let imageAsset: String?
    /// The meal slot it was cooked for.
    let mealType: MealType
    /// When it was cooked.
    let cookedAt: Date
    /// The time of day it was cooked, e.g. "8:15 PM", in the app calendar's time zone.
    let timeText: String
}

/// One date in History.
struct HistorySection: Identifiable, Equatable {
    /// Start of the date.
    let day: Date
    /// Calendar days before today.
    let daysAgo: Int
    /// The meals cooked that day, newest first.
    let entries: [HistoryEntry]
    /// "Today", "Yesterday" or e.g. "Thursday, 24 Sep · 3 days ago".
    let title: String

    /// The date.
    var id: Date { day }
}

/// A recipe's name and photo path, as needed by ``HistoryEntry``.
struct RecipeSummary: Equatable {
    /// The dish name.
    let name: String
    /// ``KyaCore/Recipe/imageAsset``.
    let imageAsset: String?
}

/// State for History: meal logs grouped by calendar date (in the injected calendar's time
/// zone), newest first, with dish names resolved from the recipe book.
@Observable
@MainActor
final class HistoryStore {
    /// Where the history is in loading.
    enum Phase: Equatable {
        /// Waiting for the first snapshots.
        case loading
        /// Data is on screen.
        case loaded
        /// The history could not be read; the screen offers a retry.
        case failed(String)
    }

    /// The loading phase.
    private(set) var phase: Phase = .loading
    private(set) var logs: [MealLog] = []
    private(set) var recipeSummaries: [String: RecipeSummary] = [:]
    @ObservationIgnored private var hasLogs = false
    @ObservationIgnored private var hasRecipes = false

    @ObservationIgnored private let repositories: RepositorySet
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The ports to read through.
    ///   - now: The clock, for "N days ago".
    ///   - calendar: Decides dates.
    init(
        repositories: RepositorySet,
        now: @escaping () -> Date,
        calendar: @escaping () -> Calendar
    ) {
        self.repositories = repositories
        self.now = now
        self.calendar = calendar
    }

    /// The history grouped by date, newest first.
    var sections: [HistorySection] {
        let calendar = calendar()
        var time = Date.FormatStyle(date: .omitted, time: .shortened)
        time.timeZone = calendar.timeZone
        var date = Date.FormatStyle.dateTime.weekday(.wide).day().month(.abbreviated)
        date.timeZone = calendar.timeZone
        return MealHistory.days(logs, now: now(), calendar: calendar).map { day in
            HistorySection(
                day: day.day, daysAgo: day.daysAgo,
                entries: day.logs.map { log in
                    let summary = recipeSummaries[log.recipeId]
                    return HistoryEntry(
                        id: log.id,
                        recipeName: summary?.name ?? String(localized: "A deleted recipe"),
                        recipeId: log.recipeId, imageAsset: summary?.imageAsset,
                        mealType: log.mealType, cookedAt: log.cookedAt,
                        timeText: log.cookedAt.formatted(time))
                },
                title: Self.title(daysAgo: day.daysAgo, date: day.day.formatted(date)))
        }
    }

    private static func title(daysAgo: Int, date: String) -> String {
        switch daysAgo {
        case ...0: String(localized: "Today")
        case 1: String(localized: "Yesterday")
        default: String(localized: "\(date) · \(daysAgo) days ago")
        }
    }

    /// Follows the meal logs and recipe names until cancelled.
    func observe() async {
        phase = .loading
        hasLogs = false
        hasRecipes = false
        do {
            // Both children loop their stream until cancelled, so neither ever returns
            // normally. A plain tuple of `async let` awaits them left to right and would
            // leave a failure in `recipes` unnoticed behind the still-running `logs` loop;
            // `group.next()` reports the first failure as soon as it happens.
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.observeLogs() }
                group.addTask { try await self.observeRecipes() }
                try await group.next()
                group.cancelAll()
            }
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(
                String(localized: "Your history couldn't be loaded. (\(String(describing: error)))")
            )
        }
    }

    private func observeLogs() async throws {
        for try await snapshot in repositories.mealLogs.watchAll() {
            logs = snapshot
            hasLogs = true
            markLoadedIfReady()
        }
    }

    private func observeRecipes() async throws {
        for try await snapshot in repositories.recipes.watchAll() {
            recipeSummaries = Dictionary(
                snapshot.map { ($0.id, RecipeSummary(name: $0.name, imageAsset: $0.imageAsset)) }
            ) { _, last in last }
            hasRecipes = true
            markLoadedIfReady()
        }
    }

    private func markLoadedIfReady() {
        if hasLogs && hasRecipes { phase = .loaded }
    }
}
