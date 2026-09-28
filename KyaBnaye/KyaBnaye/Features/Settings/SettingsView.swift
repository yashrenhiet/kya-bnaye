import SwiftUI

/// Settings, pushed from Home: backup, the two resets and About. Creates its stores once
/// the data is ready.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var stores: (backup: BackupStore, settings: SettingsStore)?

    var body: some View {
        Group {
            if let stores {
                SettingsList(backup: stores.backup, settings: stores.settings)
            } else {
                ProgressView().themedScreen()
            }
        }
        .navigationTitle("Settings")
        .task {
            guard stores == nil, let repositories = environment.repositories else { return }
            let environment = environment
            stores = (
                BackupStore(
                    repositories: repositories, now: environment.now,
                    calendar: { environment.calendar },
                    reseed: { try await environment.reapplySeed() }),
                SettingsStore(
                    repositories: repositories, reseed: { try await environment.reapplySeed() })
            )
        }
    }
}

private struct SettingsList: View {
    @Bindable var backup: BackupStore
    @Bindable var settings: SettingsStore

    @State private var isImporting = false
    @State private var isConfirmingTasteReset = false
    @State private var isConfirmingDataReset = false

    var body: some View {
        List {
            backupSection
            resetSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .themedScreen()
        .disabled(backup.isWorking || settings.isWorking)
        .overlay {
            if backup.isWorking || settings.isWorking {
                ProgressView().controlSize(.large).accessibilityLabel("Working")
            }
        }
        .sheet(item: $backup.preparedBackup) { prepared in
            BackupReadySheet(backup: prepared) { backup.exportFinished(error: $0) }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): Task { await backup.readBackup(at: url) }
            case .failure(let error): backup.importPickerFailed(error)
            }
        }
        .confirmationDialog(
            "Restore this backup?",
            isPresented: Binding(
                get: { backup.pendingRestore != nil },
                set: { if !$0 { backup.cancelRestore() } }),
            titleVisibility: .visible, presenting: backup.pendingRestore
        ) { pending in
            Button("Replace everything", role: .destructive) {
                Task { await backup.confirmRestore(pending) }
            }
            Button("Cancel", role: .cancel) { backup.cancelRestore() }
        } message: { pending in
            Text(BackupStore.confirmationMessage(for: pending))
        }
        .modifier(
            ResetDialogs(
                settings: settings, isConfirmingTasteReset: $isConfirmingTasteReset,
                isConfirmingDataReset: $isConfirmingDataReset)
        )
        .modifier(SettingsAlerts(backup: backup, settings: settings))
    }

    private var backupSection: some View {
        Section {
            Button {
                Task { await backup.prepareExport() }
            } label: {
                SettingsRowLabel(title: "Export backup", symbolName: "square.and.arrow.up")
            }
            .accessibilityIdentifier("settings.export")
            Button {
                isImporting = true
            } label: {
                SettingsRowLabel(title: "Restore from backup", symbolName: "square.and.arrow.down")
            }
            .accessibilityHint(
                "Pick a backup file. You'll see what's in it before anything changes.")
        } header: {
            SectionHeader("Backup")
        } footer: {
            SectionFooter(
                "Everything stays on this phone. Export a backup now and then so you never lose your pantry, recipes and history."
            )
        }
    }

    private var resetSection: some View {
        Section {
            Button {
                OnboardingGate.requestRerun()
            } label: {
                SettingsRowLabel(title: "Run setup again", symbolName: "sparkles")
            }
            .accessibilityHint("Opens the first-run setup: staples, fridge and dishes you love.")
            Button {
                isConfirmingTasteReset = true
            } label: {
                SettingsRowLabel(title: "Reset my taste…", symbolName: "heart.slash")
            }
            Button(role: .destructive) {
                isConfirmingDataReset = true
            } label: {
                SettingsRowLabel(title: "Reset all data…", symbolName: "trash")
                    .foregroundStyle(ThemeColor.stockOut.color)
            }
        } header: {
            SectionHeader("Start over")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: AboutInfo.version())
                .frame(minHeight: Metrics.minimumTapTarget)
            NavigationLink {
                ImageCreditsView()
            } label: {
                SettingsRowLabel(title: "Photo credits", symbolName: "photo.on.rectangle")
            }
        } header: {
            SectionHeader("About")
        } footer: {
            SectionFooter(
                "Made for Indian home kitchens. Recipes are written by the kya-bnaye team; every photo is free-licensed and credited under Photo credits. No account, no tracking: your data never leaves this phone unless you share a backup."
            )
        }
    }
}

/// A Settings row: icon plus title, at least 44 pt tall.
private struct SettingsRowLabel: View {
    let title: LocalizedStringKey
    let symbolName: String

    var body: some View {
        Label(title, systemImage: symbolName)
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// The confirmations for "Reset my taste" and "Reset all data".
private struct ResetDialogs: ViewModifier {
    let settings: SettingsStore
    @Binding var isConfirmingTasteReset: Bool
    @Binding var isConfirmingDataReset: Bool

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Reset your taste?", isPresented: $isConfirmingTasteReset, titleVisibility: .visible
            ) {
                Button("Reset my taste", role: .destructive) {
                    Task { await settings.resetTaste() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Craving mode forgets every swipe and learns your taste again. Your pantry, recipes, cooking history and list stay."
                )
            }
            .confirmationDialog(
                "Erase all your data?", isPresented: $isConfirmingDataReset,
                titleVisibility: .visible
            ) {
                Button("Erase everything", role: .destructive) {
                    Task { await settings.resetAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Your pantry, own recipes, history, swipes and list will be deleted and the recipe book reloaded. Export a backup first if you might want this back."
                )
            }
    }
}

/// Success and failure alerts for both stores.
private struct SettingsAlerts: ViewModifier {
    @Bindable var backup: BackupStore
    @Bindable var settings: SettingsStore

    func body(content: Content) -> some View {
        content
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { backup.failure != nil }, set: { if !$0 { backup.failure = nil } }),
                presenting: backup.failure
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { failure in
                Text("\(failure.message)\n\n\(failure.detail)")
            }
            .errorAlert(Bindable(settings).failureMessage)
            .alert(
                "Done",
                isPresented: Binding(
                    get: { backup.restoredMessage != nil || settings.doneMessage != nil },
                    set: {
                        if !$0 {
                            backup.restoredMessage = nil
                            settings.doneMessage = nil
                        }
                    })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backup.restoredMessage ?? settings.doneMessage ?? "")
            }
    }
}

/// The photo credits bundled with the recipe book.
private struct ImageCreditsView: View {
    @State private var result: Result<[ImageCredit], any Error>?

    var body: some View {
        content
            .themedScreen()
            .navigationTitle("Photo credits")
            .task { result = Result { try AboutInfo.imageCredits() } }
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case nil:
            ProgressView()
        case .failure:
            CenteredScrollView {
                EmptyStateView(
                    symbolName: "exclamationmark.triangle", title: "Credits unavailable",
                    message:
                        "The credits file is missing from this build. Reinstalling the app restores it."
                )
            }
        case .success(let credits) where credits.isEmpty:
            CenteredScrollView {
                EmptyStateView(
                    symbolName: "photo.on.rectangle", title: "No photos yet",
                    message:
                        "Every dish shows an illustrated card for now. When photos arrive, each one is credited here."
                )
            }
        case .success(let credits):
            List(credits) { credit in
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(credit.title).font(Typography.body)
                    Text("\(credit.author) · \(credit.licence)")
                        .font(Typography.caption)
                        .foregroundStyle(ThemeColor.textSecondary.color)
                    if let url = credit.sourceURL {
                        Link("Source", destination: url).font(Typography.caption)
                    }
                }
                .frame(minHeight: Metrics.minimumTapTarget)
            }
            .scrollContentBackground(.hidden)
        }
    }
}
