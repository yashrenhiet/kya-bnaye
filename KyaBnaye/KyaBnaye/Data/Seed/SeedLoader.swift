import Foundation
import KyaCore

/// Why bundled seed data could not be loaded or applied. Nothing is written in the
/// read/decode/validate cases; see ``SeedLoader/apply(to:)`` for the sync case.
enum SeedLoadError: Error, Sendable, Equatable, CustomStringConvertible {
    /// `seed/manifest.json` is not in the app bundle.
    case seedFolderMissing

    /// A file listed by the manifest (or the manifest itself) could not be read.
    case unreadableFile(path: String)

    /// A file is not valid seed JSON (see ``KyaCore/SeedCodec``).
    case malformed(SeedFormatError)

    /// The decoded seed breaks a content rule (see ``KyaCore/SeedValidator``); holds up to
    /// ``SeedLoader/maxReportedIssues`` issue descriptions.
    case invalid(issues: [String])

    /// Writing the seed rows failed; the stored seed version is unchanged, so the next
    /// launch retries (seeding is idempotent).
    case syncFailed(reason: String)

    /// A developer-facing summary.
    var description: String {
        switch self {
        case .seedFolderMissing: "seed/manifest.json is missing from the app bundle"
        case .unreadableFile(let path): "seed/\(path) could not be read"
        case .malformed(let error): error.description
        case .invalid(let issues): "seed data is invalid: " + issues.joined(separator: "; ")
        case .syncFailed(let reason): "seed data could not be saved: \(reason)"
        }
    }
}

/// First-run seeding and seed upgrades: reads `seed/manifest.json` and its fragments from
/// a folder (the app bundle's `seed/` in production), decodes them strictly with
/// ``KyaCore/SeedCodec``, validates them with ``KyaCore/SeedValidator`` and applies them
/// with ``KyaCore/SeedSync`` (insert missing rows, never overwrite, record the version
/// last).
///
/// Everything is read and checked before the first write, so a missing or corrupt
/// fragment never leaves a partial seed behind. Runs off the main actor: file reads and
/// decoding happen on the caller's (non-main) executor and writes on the store actor.
struct SeedLoader: Sendable {
    /// At most this many validator issues are carried in ``SeedLoadError/invalid(issues:)``.
    static let maxReportedIssues = 5

    /// The folder holding `manifest.json`.
    let seedDirectory: URL

    /// A loader over the `seed/` folder reference bundled in `bundle`.
    ///
    /// - Parameter bundle: The app bundle.
    /// - Returns: The loader.
    /// - Throws: ``SeedLoadError/seedFolderMissing`` if `seed/manifest.json` is absent.
    static func bundled(in bundle: Bundle) throws(SeedLoadError) -> SeedLoader {
        guard
            let manifest = bundle.url(
                forResource: "manifest", withExtension: "json", subdirectory: "seed")
        else { throw .seedFolderMissing }
        return SeedLoader(seedDirectory: manifest.deletingLastPathComponent())
    }

    /// Reads and decodes only the manifest.
    ///
    /// - Throws: ``SeedLoadError/unreadableFile(path:)`` or ``SeedLoadError/malformed(_:)``.
    func loadManifest() throws(SeedLoadError) -> SeedManifest {
        let data = try read(SeedCodec.manifestFile)
        do {
            return try SeedCodec().decodeManifest(data)
        } catch {
            throw .malformed(error)
        }
    }

    /// Reads, decodes and validates the whole seed.
    ///
    /// - Parameter manifest: The decoded manifest.
    /// - Returns: The validated bundle.
    /// - Throws: ``SeedLoadError`` for an unreadable, malformed or invalid file.
    func loadBundle(_ manifest: SeedManifest) throws(SeedLoadError) -> SeedBundle {
        var dataByPath: [String: Data] = [:]
        for path in manifest.allFiles {
            dataByPath[path] = try read(path)
        }
        let bundle: SeedBundle
        do {
            bundle = try SeedCodec().decode(manifest, dataByPath: dataByPath)
        } catch {
            throw .malformed(error)
        }
        let directory = seedDirectory
        let issues = SeedValidator().validate(bundle) { asset in
            FileManager.default.fileExists(atPath: directory.appending(path: asset).path)
        }
        guard issues.isEmpty else {
            throw .invalid(issues: issues.prefix(Self.maxReportedIssues).map(\.description))
        }
        return bundle
    }

    /// Applies the seed if it is newer than the stored version. When it is not, only the
    /// manifest is read, so a normal launch stays fast.
    ///
    /// - Parameter repositories: The store to seed.
    /// - Returns: What was done.
    /// - Throws: ``SeedLoadError``; for read/decode/validation failures nothing was
    ///   written. For ``SeedLoadError/syncFailed(reason:)`` some rows may have been
    ///   inserted but the version was not recorded, so the next launch completes it.
    func apply(to repositories: RepositorySet) async throws(SeedLoadError) -> SeedSyncOutcome {
        let manifest = try loadManifest()
        let stored: Int?
        do {
            stored = try await repositories.seedState.seedVersion()
        } catch {
            throw .syncFailed(reason: String(describing: error))
        }
        if let stored, stored >= manifest.seedVersion {
            return .upToDate(storedVersion: stored)
        }
        let bundle = try loadBundle(manifest)
        let sync = SeedSync(
            ingredients: repositories.ingredients, recipes: repositories.recipes,
            seedState: repositories.seedState)
        do {
            return try await sync.apply(bundle)
        } catch {
            throw .syncFailed(reason: String(describing: error))
        }
    }

    private func read(_ path: String) throws(SeedLoadError) -> Data {
        do {
            return try Data(contentsOf: seedDirectory.appending(path: path))
        } catch {
            throw .unreadableFile(path: path)
        }
    }
}
