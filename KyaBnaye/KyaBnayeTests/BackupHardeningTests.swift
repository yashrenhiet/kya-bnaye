import Foundation
import KyaCore
import Testing

@testable import KyaBnaye

/// Backup import edge cases (lane L5): odd files, cancelled sheets, importing over data.
@Suite("Backup hardening")
@MainActor
struct BackupHardeningTests {
    let repositories: RepositorySet
    let store: BackupStore

    init() async throws {
        repositories = try SwiftDataStore.inMemory().repositories
        store = BackupStore(
            repositories: repositories, now: { TestData.instant },
            calendar: { ShoppingFixtures.calendar },
            temporaryDirectory: try TestData.temporaryDirectory())
        try await BackupFixtures.fill(repositories)
    }

    @Test(
        "an empty file, or JSON with no or a nonsense version, isn't called a newer backup",
        arguments: [
            Data(),
            Data("{}".utf8),
            Data(#"{"version": 0}"#.utf8),
            Data(#"{"version": "two"}"#.utf8),
            Data("[1, 2, 3]".utf8),
        ])
    func notABackup(data: Data) async throws {
        let before = try await repositories.backup.exportSnapshot()

        await store.readBackup(at: try write(data))

        #expect(store.failure?.message == "That file isn't a kya-bnaye backup.")
        #expect(store.pendingRestore == nil)
        BackupFixtures.expectIdentical(try await repositories.backup.exportSnapshot(), before)
    }

    @Test("a file from a newer app still asks the user to update")
    func newerVersion() async throws {
        await store.readBackup(at: try write(Data(#"{"version": 3}"#.utf8)))

        #expect(store.failure?.message.hasPrefix("This backup was made by a newer version") == true)
    }

    @Test("a file over the size limit is refused without being read, and changes nothing")
    func tooLarge() async throws {
        let before = try await repositories.backup.exportSnapshot()
        await store.prepareExport()
        let data = try #require(store.preparedBackup?.data)

        await store.readBackup(at: try write(data), maxBytes: data.count - 1)

        #expect(store.failure?.message == "That file is far too big to be a kya-bnaye backup.")
        #expect(store.failure?.detail == "file is \(data.count) bytes")
        #expect(store.pendingRestore == nil)
        BackupFixtures.expectIdentical(try await repositories.backup.exportSnapshot(), before)
    }

    @Test("a file exactly at the size limit is read normally")
    func atLimit() async throws {
        await store.prepareExport()
        let data = try #require(store.preparedBackup?.data)

        await store.readBackup(at: try write(data), maxBytes: data.count)

        #expect(store.failure == nil)
        #expect(store.pendingRestore?.summary.recipes == 2)
    }

    @Test("the real limit comfortably fits a big household's backup")
    func limitIsGenerous() {
        #expect(BackupStore.maxFileBytes == 50 * 1024 * 1024)
    }

    @Test("closing the file picker or the Files save sheet is not reported as an error")
    func cancelledSheets() {
        store.importPickerFailed(CocoaError(.userCancelled))
        #expect(store.failure == nil)

        store.exportFinished(error: CocoaError(.userCancelled))
        #expect(store.failure == nil)
        #expect(store.preparedBackup == nil)
    }

    @Test("a picker or save that really fails is still reported")
    func realSheetFailures() {
        store.importPickerFailed(CocoaError(.fileReadNoPermission))
        #expect(store.failure?.message.hasPrefix("We couldn't open that file") == true)
        store.failure = nil

        store.exportFinished(error: CocoaError(.fileWriteOutOfSpace))
        #expect(store.failure?.message == "The backup wasn't saved. Please try again.")
    }

    @Test("importing over existing data replaces it: rows not in the file are gone")
    func importReplacesRatherThanMerges() async throws {
        await store.prepareExport()
        let data = try #require(store.preparedBackup?.data)
        try await repositories.shopping.upsert([
            try ShoppingItem(
                id: "later", customName: "Added after export", reason: .manual, isChecked: false,
                createdAt: TestData.instant)
        ])
        try await repositories.swipeEvents.add(BackupFixtures.swipe("s3", .right, offset: 120))

        try store.stageRestore(of: data)
        await store.confirmRestore(try #require(store.pendingRestore))

        #expect(try await repositories.shopping.all().map(\.id) == ["i1"])
        #expect(try await repositories.swipeEvents.all().map(\.id).sorted() == ["s1", "s2"])
        #expect(store.failure == nil)
    }

    private func write(_ data: Data) throws -> URL {
        let url = try TestData.temporaryDirectory().appending(path: "picked.json")
        try data.write(to: url)
        return url
    }
}
