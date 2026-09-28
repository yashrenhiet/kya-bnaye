import Foundation
import KyaCore
import Observation

/// A backup file ready to share or save.
struct PreparedBackup: Identifiable, Equatable, Sendable {
    /// The file name, e.g. `kya-bnaye-backup-2026-09-27.json`.
    let fileName: String
    /// The file's bytes.
    let data: Data
    /// A copy of the file in the temporary directory, for the share sheet.
    let fileURL: URL
    /// What the file holds.
    let summary: BackupSummary

    var id: String { fileName }
}

/// A decoded backup waiting for the user to confirm "Replace everything".
struct PendingRestore: Identifiable, Sendable {
    /// Everything in the file.
    let bundle: BackupBundle
    /// What the file holds.
    let summary: BackupSummary

    let id = UUID()
}

/// Export and import of the whole-app JSON backup (F7).
///
/// Export reads one consistent snapshot, encodes it with ``KyaCore/BackupCodec`` and hands
/// the file to the share sheet or Files. Import decodes and checks the file completely
/// before anything is written, asks for confirmation with the row counts, then replaces
/// everything in one atomic write, so a bad file or a failed write never leaves half of
/// the old data and half of the new.
@Observable
@MainActor
final class BackupStore {
    /// Whether work is in flight, so buttons can show progress and not double-fire.
    private(set) var isWorking = false
    /// The backup ready to share or save; the view presents it while non-`nil`.
    var preparedBackup: PreparedBackup?
    /// A decoded file awaiting confirmation; the view asks while non-`nil`.
    var pendingRestore: PendingRestore?
    /// A plain-words success note after a restore.
    var restoredMessage: String?
    /// The last failure, shown as an alert until dismissed.
    var failure: BackupFailure?

    @ObservationIgnored private let repositories: RepositorySet
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let calendar: @MainActor () -> Calendar
    @ObservationIgnored private let temporaryDirectory: URL
    @ObservationIgnored private let reseed: @MainActor () async throws -> Void

    /// A failure to show: what happened in plain words, plus developer detail.
    struct BackupFailure: Equatable, Sendable {
        let message: String
        let detail: String
    }

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The data to export and replace.
    ///   - now: The clock, for `exportedAt` and the file name.
    ///   - calendar: Defines the date in the file name.
    ///   - temporaryDirectory: Where the shareable copy is written.
    ///   - reseed: Applies the bundled seed after a restore, adding seed rows the file
    ///     predates; does nothing by default.
    init(
        repositories: RepositorySet,
        now: @escaping @Sendable () -> Date,
        calendar: @escaping @MainActor () -> Calendar,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        reseed: @escaping @MainActor () async throws -> Void = {}
    ) {
        self.repositories = repositories
        self.now = now
        self.calendar = calendar
        self.temporaryDirectory = temporaryDirectory
        self.reseed = reseed
    }

    // MARK: Export

    /// Builds the backup file from everything stored; sets ``preparedBackup`` on success
    /// and ``failure`` otherwise.
    func prepareExport() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let exportedAt = now()
        let fileName = backupFileName(for: exportedAt, calendar: calendar())
        do {
            let bundle = BackupBundle(try await repositories.backup.exportSnapshot())
            let data = try BackupCodec().encode(bundle, exportedAt: exportedAt)
            let url = temporaryDirectory.appending(path: fileName)
            try await Self.write(data, to: url)
            preparedBackup = PreparedBackup(
                fileName: fileName, data: data, fileURL: url, summary: bundle.summary)
        } catch {
            failure = BackupFailure(
                message: String(
                    localized:
                        "We couldn't create the backup. Nothing was changed; please try again."),
                detail: String(describing: error))
        }
    }

    /// Reports the result of saving the file to Files.
    ///
    /// - Parameter error: Why saving failed, or `nil` when it was saved or cancelled.
    func exportFinished(error: (any Error)?) {
        preparedBackup = nil
        if let error {
            failure = BackupFailure(
                message: String(localized: "The backup wasn't saved. Please try again."),
                detail: String(describing: error))
        }
    }

    // MARK: Import

    /// Reads and checks a file picked in Files, then asks for confirmation via
    /// ``pendingRestore``. Nothing is written yet.
    ///
    /// - Parameter url: The picked file (security-scoped).
    func readBackup(at url: URL) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let data = try await Self.read(url)
            try stageRestore(of: data)
        } catch {
            fail(error)
        }
    }

    /// Reports that the file picker itself failed.
    func importPickerFailed(_ error: any Error) {
        fail(.unreadableFile(detail: String(describing: error)))
    }

    /// Decodes and checks backup bytes, then asks for confirmation. Nothing is written.
    ///
    /// - Parameter data: The file's bytes.
    /// - Throws: ``BackupImportError`` for anything that can't be restored.
    func stageRestore(of data: Data) throws(BackupImportError) {
        let bundle: BackupBundle
        do {
            bundle = try BackupCodec().decode(data)
        } catch {
            throw .format(error)
        }
        try BackupIntegrity.check(bundle)
        pendingRestore = PendingRestore(bundle: bundle, summary: bundle.summary)
    }

    /// The confirmation question for a restore.
    ///
    /// - Parameter pending: The restore awaiting confirmation.
    /// - Returns: E.g. "Replace everything on this phone with 80 recipes, …?".
    static func confirmationMessage(for pending: PendingRestore) -> String {
        String(
            localized: """
                Replace everything on this phone with \(pending.summary.description)? \
                Your current pantry, recipes, history and list will be replaced.
                """)
    }

    /// Replaces all data with the confirmed file, atomically; on failure nothing changed.
    /// Then applies the bundled seed, so dishes and ingredients added since the file was
    /// made appear too (rows from the file are never overwritten). If only that second step
    /// fails, the restore stands and the next launch completes the seed.
    ///
    /// Takes the restore the user confirmed rather than reading ``pendingRestore``, because
    /// the dialog clears that as it closes, possibly before its button action runs.
    ///
    /// - Parameter pending: The confirmed restore.
    func confirmRestore(_ pending: PendingRestore) async {
        guard !isWorking else { return }
        pendingRestore = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await repositories.backup.replaceAll(with: pending.bundle.snapshot)
        } catch {
            failure = BackupFailure(
                message: String(
                    localized: "The backup couldn't be restored. Your data wasn't changed."),
                detail: String(describing: error))
            return
        }
        do {
            try await reseed()
            restoredMessage = String(localized: "Restored \(pending.summary.description).")
        } catch {
            restoredMessage = String(
                localized: """
                    Restored \(pending.summary.description). New dishes from this version of \
                    the app will be added the next time you open it.
                    """)
        }
    }

    /// Drops the file awaiting confirmation.
    func cancelRestore() {
        pendingRestore = nil
    }

    // MARK: Internals

    private func fail(_ error: BackupImportError) {
        failure = BackupFailure(message: error.userMessage, detail: error.detail)
    }

    @concurrent
    private static func write(_ data: Data, to url: URL) async throws {
        try data.write(to: url, options: .atomic)
    }

    @concurrent
    private static func read(_ url: URL) async throws(BackupImportError) -> Data {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw .unreadableFile(detail: String(describing: error))
        }
    }
}
