import Foundation
import KyaCore
import Observation

/// The destructive Settings actions: "Reset my taste" and "Reset all data". The view asks
/// for confirmation first; these methods assume the user already said yes.
@Observable
@MainActor
final class SettingsStore {
    /// Whether an action is in flight.
    private(set) var isWorking = false
    /// A plain-words note after an action succeeded.
    var doneMessage: String?
    /// The last failure, shown as an alert until dismissed.
    var failureMessage: String?

    @ObservationIgnored private let repositories: RepositorySet
    @ObservationIgnored private let reseed: @MainActor () async throws -> Void

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The data.
    ///   - reseed: Loads the bundled recipe book and catalog into the (just emptied) store.
    init(repositories: RepositorySet, reseed: @escaping @MainActor () async throws -> Void) {
        self.repositories = repositories
        self.reseed = reseed
    }

    /// Forgets every swipe, so Craving mode starts from a blank taste profile. Cooking
    /// history, the pantry, recipes, the list and hidden dishes are kept.
    ///
    /// Uses ``KyaCore/SwipeEventRepository/deleteAll()``, the swipe log's one atomic
    /// removal, so no other table is touched and a failure leaves the log as it was.
    func resetTaste() async {
        await run(failure: String(localized: "Your taste couldn't be reset. Nothing was changed."))
        {
            try await self.repositories.swipeEvents.deleteAll()
            return String(
                localized: "Your taste is reset. Craving mode will learn from your next swipes.")
        }
    }

    /// Erases everything, then reloads the bundled recipe book and ingredient catalog.
    ///
    /// The erase is atomic. If reloading the seed fails afterwards, the store is empty but
    /// its seed version is cleared too, so the next launch reloads it; the message says so.
    func resetAllData() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await repositories.backup.replaceAll(with: RepositorySnapshot())
        } catch {
            failureMessage = String(localized: "Your data couldn't be reset. Nothing was changed.")
            return
        }
        do {
            try await reseed()
            doneMessage = String(
                localized: "All data is reset. The recipe book is back to its original dishes.")
        } catch {
            failureMessage = String(
                localized:
                    "Your data was erased, but the recipe book didn't reload. Close and reopen the app to reload it."
            )
        }
    }

    private func run(failure: String, _ action: () async throws -> String) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            doneMessage = try await action()
        } catch {
            failureMessage = failure
        }
    }
}
