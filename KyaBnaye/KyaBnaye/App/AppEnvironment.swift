import Foundation
import KyaCore
import Observation

/// Where the app is in getting its data ready.
enum LaunchState: Sendable {
    /// Opening the store and applying the bundled seed.
    case loading
    /// Data is ready; every feature reads and writes through these repositories.
    case ready(RepositorySet)
    /// Data could not be made ready; the launch screen offers recovery.
    case failed(LaunchFailure)
}

/// The composition root, created once at launch and injected through the SwiftUI
/// environment. It owns the repositories (once ready), the clock and the calendar, so
/// feature stores get all their dependencies from one place and tests can pin time.
///
/// Knows nothing about SwiftData: the store is opened by the injected ``AppBootstrap``.
@Observable
@MainActor
final class AppEnvironment {
    /// The current launch state.
    private(set) var launchState: LaunchState = .loading

    /// The current instant; injected so stores and tests share one notion of "now".
    let now: @Sendable () -> Date

    @ObservationIgnored private let makeCalendar: @Sendable () -> Calendar
    @ObservationIgnored private let bootstrap: AppBootstrap
    @ObservationIgnored private var isLaunching = false

    /// Creates the environment. Call ``launch()`` to open the data.
    ///
    /// - Parameters:
    ///   - bootstrap: Opens the store and seeds it.
    ///   - now: The clock; defaults to the system clock.
    ///   - calendar: The calendar provider, read on each access so time-zone changes are
    ///     picked up; defaults to `Calendar.kyaDefault`.
    init(
        bootstrap: AppBootstrap,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: @escaping @Sendable () -> Calendar = { .kyaDefault }
    ) {
        self.bootstrap = bootstrap
        self.now = now
        makeCalendar = calendar
    }

    /// The calendar (and time zone) that defines "today" for expiry and history.
    var calendar: Calendar { makeCalendar() }

    /// The repositories, once ``launchState`` is ``LaunchState/ready(_:)``.
    var repositories: RepositorySet? {
        if case .ready(let repositories) = launchState { repositories } else { nil }
    }

    /// Opens the store and applies the seed, showing ``LaunchState/loading`` meanwhile.
    /// The work runs off the main actor. A call while a launch is in flight, or after the
    /// data is ready, does nothing.
    func launch() async {
        guard !isLaunching, repositories == nil else { return }
        isLaunching = true
        defer { isLaunching = false }
        launchState = .loading
        do {
            launchState = .ready(try await bootstrap.open())
        } catch {
            launchState = .failed(error)
        }
    }

    /// Moves the unreadable store aside, then launches again with an empty, freshly
    /// seeded store. Only call after the user confirmed; the UI explains that a backup
    /// can be restored afterwards.
    func resetDataAndRelaunch() async {
        guard !isLaunching, repositories == nil else { return }
        isLaunching = true
        launchState = .loading
        do {
            try await bootstrap.resetData()
        } catch {
            launchState = .failed(error)
            isLaunching = false
            return
        }
        isLaunching = false
        await launch()
    }

    /// Loads the bundled recipe book and ingredient catalog into the ready repositories if
    /// their seed version is missing or older, e.g. right after Settings erased all data.
    /// Rows already stored are never overwritten. Does nothing before the data is ready.
    ///
    /// - Throws: ``LaunchFailure`` of kind `seedingFailed`; whatever was inserted stays,
    ///   and the next launch completes the seed.
    func reapplySeed() async throws(LaunchFailure) {
        guard let repositories else { return }
        try await bootstrap.reseed(repositories)
    }
}
