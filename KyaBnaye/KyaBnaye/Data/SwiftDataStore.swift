import Foundation
import KyaCore
import SwiftData

/// Opens the SwiftData stack and vends every `KyaCore` repository over it. This is the
/// only entry point into `Data/`: callers get a ``KyaCore/RepositorySet`` and never see a
/// SwiftData type.
struct SwiftDataStore: Sendable {
    /// Every repository, sharing this store.
    let repositories: RepositorySet

    /// The actor owning the store's context (exposed for tests).
    let actor: DataStoreActor

    private init(container: ModelContainer) {
        let actor = DataStoreActor(modelContainer: container)
        self.actor = actor
        repositories = RepositorySet(store: actor)
    }

    /// File name of the persistent store inside ``defaultDirectory()``.
    static let storeFileName = "KyaBnaye.store"

    /// Opens (creating if needed, migrating if older) the persistent store at `url`.
    ///
    /// - Parameter url: The SQLite store file.
    /// - Returns: The opened store.
    /// - Throws: ``DataStoreError/storeUnavailable(reason:)`` if the directory cannot be
    ///   created or the file cannot be opened or migrated (corruption, a newer schema, a
    ///   directory at `url`, no disk space). Never crashes.
    static func persistent(at url: URL) throws(DataStoreError) -> SwiftDataStore {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw .storeUnavailable(reason: "cannot create the store directory: \(error)")
        }
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(
            schema: schema, url: url, cloudKitDatabase: .none)
        return try open(schema: schema, configuration: configuration)
    }

    /// Opens a fresh, empty store that lives only in memory, for tests and previews.
    /// Every call returns an independent store.
    ///
    /// - Returns: The opened store.
    /// - Throws: ``DataStoreError/storeUnavailable(reason:)`` if SwiftData cannot create
    ///   the container.
    static func inMemory() throws(DataStoreError) -> SwiftDataStore {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let configuration = ModelConfiguration(
            UUID().uuidString, schema: schema, isStoredInMemoryOnly: true,
            cloudKitDatabase: .none)
        return try open(schema: schema, configuration: configuration)
    }

    private static func open(
        schema: Schema, configuration: ModelConfiguration
    ) throws(DataStoreError) -> SwiftDataStore {
        do {
            let container = try ModelContainer(
                for: schema, migrationPlan: KyaMigrationPlan.self,
                configurations: configuration)
            return SwiftDataStore(container: container)
        } catch {
            throw .storeUnavailable(reason: String(describing: error))
        }
    }

    // MARK: Location and recovery

    /// `Application Support/KyaBnaye/`, where the persistent store lives.
    ///
    /// - Throws: ``DataStoreError/storeUnavailable(reason:)`` if the system cannot
    ///   provide Application Support.
    static func defaultDirectory() throws(DataStoreError) -> URL {
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                create: true)
            return support.appending(path: "KyaBnaye", directoryHint: .isDirectory)
        } catch {
            throw .storeUnavailable(reason: "Application Support is unavailable: \(error)")
        }
    }

    /// The default persistent store file.
    ///
    /// - Throws: As ``defaultDirectory()``.
    static func defaultStoreURL() throws(DataStoreError) -> URL {
        try defaultDirectory().appending(path: storeFileName, directoryHint: .notDirectory)
    }

    /// Moves an unreadable store (the file or directory at `url` plus its SQLite `-wal`
    /// and `-shm` companions) into `Unreadable/store-<epoch ms>/` next to it, so the next open
    /// starts empty. The data is kept aside for manual recovery, never deleted.
    ///
    /// - Parameters:
    ///   - url: The store location.
    ///   - now: The timestamp used to name the folder.
    /// - Returns: The folder the files were moved to, or `nil` if there was nothing to
    ///   move.
    /// - Throws: ``DataStoreError/resetFailed(reason:)`` if a file cannot be moved; files
    ///   already moved stay in the folder.
    @discardableResult
    static func moveStoreAside(at url: URL, now: Date = Date()) throws(DataStoreError) -> URL? {
        let fileManager = FileManager.default
        let candidates = ["", "-wal", "-shm"].map {
            url.deletingLastPathComponent().appending(path: url.lastPathComponent + $0)
        }
        let present = candidates.filter { fileManager.fileExists(atPath: $0.path) }
        guard !present.isEmpty else { return nil }
        let stamp = "store-\(Int64((now.timeIntervalSince1970 * 1000).rounded()))"
        let destination = url.deletingLastPathComponent()
            .appending(path: "Unreadable", directoryHint: .isDirectory)
            .appending(path: stamp, directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for file in present {
                try fileManager.moveItem(
                    at: file, to: destination.appending(path: file.lastPathComponent))
            }
        } catch {
            throw .resetFailed(reason: String(describing: error))
        }
        return destination
    }
}
