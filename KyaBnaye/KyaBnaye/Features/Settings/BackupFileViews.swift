import SwiftUI
import UniformTypeIdentifiers

/// The backup JSON as a document for `fileExporter` ("Save to Files").
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Shown once the backup file is built: what it holds, then Share (AirDrop, Mail, a chat)
/// or Save to Files. Keeping a copy off the phone is the whole point, so both are offered.
struct BackupReadySheet: View {
    let backup: PreparedBackup
    let finished: ((any Error)?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xLarge) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Your backup is ready")
                            .font(Typography.headline)
                            .foregroundStyle(ThemeColor.textPrimary.color)
                            .accessibilityAddTraits(.isHeader)
                        Text(backup.summary.description)
                            .font(Typography.body)
                            .foregroundStyle(ThemeColor.textSecondary.color)
                        Text(backup.fileName)
                            .font(Typography.caption)
                            .foregroundStyle(ThemeColor.textSecondary.color)
                    }
                    Text(
                        "Keep it somewhere other than this phone, like Files on iCloud Drive or a chat with yourself."
                    )
                    .font(Typography.supporting)
                    .foregroundStyle(ThemeColor.textSecondary.color)
                    actions
                }
                .padding(Spacing.large)
                .frame(maxWidth: Metrics.readableWidth, alignment: .leading)
            }
            .themedScreen()
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $isSaving, document: BackupDocument(data: backup.data),
                contentType: .json, defaultFilename: backup.fileName
            ) { result in
                switch result {
                case .success: finished(nil)
                case .failure(let error): finished(error)
                }
            }
        }
        .accessibilityIdentifier("backup.ready")
    }

    private var actions: some View {
        VStack(spacing: Spacing.medium) {
            ShareLink(item: backup.fileURL) {
                Label("Share backup", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.primaryAction)
            Button {
                isSaving = true
            } label: {
                Label("Save to Files", systemImage: "folder")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.bordered)
        }
    }
}
