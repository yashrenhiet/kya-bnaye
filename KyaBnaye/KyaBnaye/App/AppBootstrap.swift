import Foundation
import KyaCore

/// Why the app could not get its data ready at launch, with the recovery it allows.
struct LaunchFailure: Error, Sendable, Equatable {
    /// What went wrong.
    enum Kind: Sendable, Equatable {
        /// The on-device store could not be opened (corruption or failed migration).
        case storeUnavailable
        /// The store opened, but the bundled recipe book could not be loaded into it.
        case seedingFailed
        /// Moving an unreadable store aside failed.
        case resetFailed
    }

    /// What went wrong.
    let kind: Kind

    /// Developer-facing detail, shown in small print for bug reports.
    let detail: String

    /// Whether "Reset data" can help: only when the store itself is unreadable.
    var canResetData: Bool { kind != .seedingFailed }
}

/// The launch work the ``AppEnvironment`` runs, injected so tests and previews can swap in
/// fakes. ``live(bundle:)`` is the production wiring.
struct AppBootstrap: Sendable {
    /// Opens the store and applies the bundled seed; returns the repositories when ready.
    let open: @Sendable () async throws(LaunchFailure) -> RepositorySet

    /// Moves the unreadable store aside so the next ``open`` starts empty.
    let resetData: @Sendable () async throws(LaunchFailure) -> Void

    /// Applies the bundled seed to already-open repositories if their seed version is
    /// missing or older (e.g. after Settings erased everything).
    let reseed: @Sendable (RepositorySet) async throws(LaunchFailure) -> Void

    /// Creates a bootstrap.
    ///
    /// - Parameters:
    ///   - open: Opens the store and applies the seed.
    ///   - resetData: Moves an unreadable store aside.
    ///   - reseed: Re-applies the seed to open repositories; does nothing by default, for
    ///     tests and previews that don't exercise it.
    init(
        open: @escaping @Sendable () async throws(LaunchFailure) -> RepositorySet,
        resetData: @escaping @Sendable () async throws(LaunchFailure) -> Void,
        reseed: @escaping @Sendable (RepositorySet) async throws(LaunchFailure) -> Void = { _ in }
    ) {
        self.open = open
        self.resetData = resetData
        self.reseed = reseed
    }

    /// Production wiring: the persistent store in Application Support, seeded from the
    /// `seed/` folder in `bundle`.
    ///
    /// - Parameter bundle: The bundle holding `seed/`; `.main` in the app.
    /// - Returns: The bootstrap.
    static func live(bundle: Bundle = .main) -> AppBootstrap {
        let seedLoader = Result { () throws(SeedLoadError) in try SeedLoader.bundled(in: bundle) }
        return AppBootstrap(
            open: { () async throws(LaunchFailure) -> RepositorySet in
                let url = try storeURL()
                return try await openAndSeed(storeAt: url, seedLoader: seedLoader)
            },
            resetData: { () async throws(LaunchFailure) in
                try await moveStoreAside(at: try storeURL())
            },
            reseed: { (repositories) async throws(LaunchFailure) in
                try await applySeed(seedLoader, to: repositories)
            })
    }

    /// Launch argument (`-uiTestFreshStore YES`) that makes every launch start from its own
    /// empty, freshly seeded in-memory store, so UI tests never see each other's data.
    static let freshStoreArgumentKey = "uiTestFreshStore"

    /// The bootstrap for this launch: ``inMemory(bundle:)`` when launched with
    /// `-uiTestFreshStore YES`, otherwise ``live(bundle:)``.
    ///
    /// - Parameters:
    ///   - defaults: Where launch arguments are visible (the argument domain).
    ///   - bundle: The bundle holding `seed/`.
    /// - Returns: The bootstrap.
    static func forLaunch(
        _ defaults: UserDefaults = .standard, bundle: Bundle = .main
    ) -> AppBootstrap {
        defaults.bool(forKey: freshStoreArgumentKey)
            ? inMemory(bundle: bundle) : live(bundle: bundle)
    }

    /// An isolated store that lives only in memory, seeded from `bundle`; nothing persists
    /// between launches. For UI tests and demos.
    ///
    /// - Parameter bundle: The bundle holding `seed/`.
    /// - Returns: The bootstrap.
    static func inMemory(bundle: Bundle = .main) -> AppBootstrap {
        let seedLoader = Result { () throws(SeedLoadError) in try SeedLoader.bundled(in: bundle) }
        return AppBootstrap(
            open: { () async throws(LaunchFailure) -> RepositorySet in
                let store: SwiftDataStore
                do {
                    store = try SwiftDataStore.inMemory()
                } catch {
                    throw LaunchFailure(kind: .storeUnavailable, detail: String(describing: error))
                }
                try await applySeed(seedLoader, to: store.repositories)
                return store.repositories
            },
            resetData: {},
            reseed: { (repositories) async throws(LaunchFailure) in
                try await applySeed(seedLoader, to: repositories)
            })
    }

    /// Applies the seed to open repositories, off the main actor.
    ///
    /// - Parameters:
    ///   - seedLoader: The seed source, or why it is unavailable.
    ///   - repositories: The store to seed.
    /// - Throws: ``LaunchFailure`` of kind `seedingFailed`.
    @concurrent
    static func applySeed(
        _ seedLoader: Result<SeedLoader, SeedLoadError>, to repositories: RepositorySet
    ) async throws(LaunchFailure) {
        do {
            _ = try await seedLoader.get().apply(to: repositories)
        } catch {
            throw LaunchFailure(kind: .seedingFailed, detail: String(describing: error))
        }
    }

    /// Opens the persistent store at `url` and applies the seed, off the main actor.
    ///
    /// - Parameters:
    ///   - url: The store file.
    ///   - seedLoader: The seed source, or why it is unavailable.
    /// - Returns: The ready repositories.
    /// - Throws: ``LaunchFailure`` of kind `storeUnavailable` or `seedingFailed`.
    @concurrent
    static func openAndSeed(
        storeAt url: URL, seedLoader: Result<SeedLoader, SeedLoadError>
    ) async throws(LaunchFailure) -> RepositorySet {
        let store: SwiftDataStore
        do {
            store = try SwiftDataStore.persistent(at: url)
        } catch {
            throw LaunchFailure(kind: .storeUnavailable, detail: String(describing: error))
        }
        try await applySeed(seedLoader, to: store.repositories)
        return store.repositories
    }

    @concurrent
    private static func moveStoreAside(at url: URL) async throws(LaunchFailure) {
        do {
            try SwiftDataStore.moveStoreAside(at: url)
        } catch {
            throw LaunchFailure(kind: .resetFailed, detail: String(describing: error))
        }
    }

    private static func storeURL() throws(LaunchFailure) -> URL {
        do {
            return try SwiftDataStore.defaultStoreURL()
        } catch {
            throw LaunchFailure(kind: .storeUnavailable, detail: String(describing: error))
        }
    }
}
