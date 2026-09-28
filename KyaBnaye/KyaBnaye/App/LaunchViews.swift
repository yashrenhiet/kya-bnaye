import SwiftUI

/// Shows the right screen for the ``AppEnvironment/launchState``: a short loading screen
/// while the data opens and seeds, a recoverable error screen on failure, and once ready
/// either first-run onboarding or the tab shell. Starts the launch when it first appears.
struct AppRootView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(OnboardingGate.completedKey) private var onboardingCompleted = false

    var body: some View {
        content
            .task { await environment.launch() }
    }

    @ViewBuilder
    private var content: some View {
        switch environment.launchState {
        case .loading:
            LaunchLoadingView()
        case .ready:
            if onboardingCompleted || OnboardingGate.isSkippedForThisLaunch() {
                RootTabView()
            } else {
                OnboardingView { onboardingCompleted = true }
            }
        case .failed(let failure):
            LaunchFailureView(
                failure: failure,
                retry: { Task { await environment.launch() } },
                resetData: { Task { await environment.resetDataAndRelaunch() } })
        }
    }
}

/// A calm placeholder while the kitchen data opens (usually well under a second).
struct LaunchLoadingView: View {
    var body: some View {
        VStack(spacing: Spacing.large) {
            ProgressView()
                .controlSize(.large)
                .tint(ThemeColor.accent.color)
            Text("Getting your kitchen ready…")
                .font(Typography.body)
                .foregroundStyle(ThemeColor.textSecondary.color)
        }
        .padding(Spacing.xLarge)
        .themedScreen()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading. Getting your kitchen ready.")
    }
}

/// The recoverable error screen: explains what happened in plain words, offers "Try
/// again" and, when the store itself is unreadable, "Reset data" behind a confirmation
/// that mentions backups. Never a dead end.
struct LaunchFailureView: View {
    let failure: LaunchFailure
    let retry: () -> Void
    let resetData: () -> Void

    @State private var isConfirmingReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xLarge) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(ThemeColor.accent.color)
                    .accessibilityHidden(true)
                message
                actions
                Text(failure.detail)
                    .font(Typography.caption)
                    .foregroundStyle(ThemeColor.textSecondary.color)
                    .textSelection(.enabled)
                    .accessibilityLabel("Technical details: \(failure.detail)")
            }
            .padding(Spacing.xLarge)
            .frame(maxWidth: Metrics.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .confirmationDialog(
            "Erase the data on this phone?", isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset data", role: .destructive, action: resetData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                """
                Your pantry, own recipes, history and shopping list will start empty and \
                the recipe book will be reloaded. The unreadable data is kept aside, not \
                deleted. If you exported a backup, you can restore it from Settings afterwards.
                """)
        }
    }

    private var message: some View {
        VStack(spacing: Spacing.small) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(ThemeColor.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            Text(explanation)
                .font(Typography.body)
                .foregroundStyle(ThemeColor.textSecondary.color)
        }
        .multilineTextAlignment(.center)
    }

    private var actions: some View {
        VStack(spacing: Spacing.medium) {
            Button(action: retry) {
                Text("Try again").frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.primaryAction)
            if failure.canResetData {
                Button(role: .destructive) {
                    isConfirmingReset = true
                } label: {
                    Text("Reset data…")
                        .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Asks for confirmation before erasing data on this phone.")
            }
        }
    }

    private var title: LocalizedStringKey {
        switch failure.kind {
        case .storeUnavailable: "We couldn't open your kitchen data"
        case .seedingFailed: "We couldn't load the recipe book"
        case .resetFailed: "We couldn't reset your data"
        }
    }

    private var explanation: LocalizedStringKey {
        switch failure.kind {
        case .storeUnavailable:
            """
            The data saved on this phone can't be read. Try again, or reset the data and \
            restore a backup if you have one.
            """
        case .seedingFailed:
            """
            Your data is safe. Please try again; if this keeps happening, reinstalling the \
            app restores the recipe book.
            """
        case .resetFailed:
            "Nothing was erased. Please try again, or restart your phone and retry."
        }
    }
}

#Preview("Loading") {
    LaunchLoadingView()
}

#Preview("Store unavailable") {
    LaunchFailureView(
        failure: LaunchFailure(kind: .storeUnavailable, detail: "SQLite error 26"),
        retry: {}, resetData: {})
}
