import SwiftUI

/// First-run onboarding (F1). Creates its store from the app environment and calls
/// `finish` when the user completes or skips it.
struct OnboardingView: View {
    let finish: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var store: OnboardingStore?

    var body: some View {
        Group {
            if let store {
                OnboardingFlow(store: store, finish: finish)
            } else {
                LaunchLoadingView()
            }
        }
        .task {
            guard store == nil, let repositories = environment.repositories else { return }
            let store = OnboardingStore(
                repositories: repositories, now: environment.now,
                calendar: { [environment] in environment.calendar })
            self.store = store
            await store.load()
        }
    }
}

/// The step container: progress and Skip on top, the step in the middle, Back/Next below.
private struct OnboardingFlow: View {
    let store: OnboardingStore
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if store.phase == .ready && store.step != .welcome && store.step != .done {
                footer
            }
        }
        .themedScreen()
        .errorAlert(Bindable(store).saveError, title: "Couldn't save")
    }

    private var header: some View {
        HStack(spacing: Spacing.medium) {
            if let number = store.step.progressNumber {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Step \(number) of \(OnboardingStore.Step.progressCount)")
                        .font(Typography.caption)
                        .foregroundStyle(ThemeColor.textSecondary.color)
                    ProgressView(
                        value: Double(number), total: Double(OnboardingStore.Step.progressCount)
                    )
                    .tint(ThemeColor.accent.color)
                    .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer()
            if store.step != .done {
                Button("Skip", action: finish)
                    .font(Typography.body)
                    .frame(minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
                    .accessibilityHint("Skips setup. You can mark your pantry any time.")
                    .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.small)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            LaunchLoadingView()
        case .failed(let message):
            LoadFailedView(
                title: "Setup couldn't start",
                reassurance: "You can skip it and fill in your pantry later, or try again.",
                detail: message
            ) {
                Task { await store.load() }
            }
        case .ready:
            step
        }
    }

    @ViewBuilder
    private var step: some View {
        switch store.step {
        case .welcome:
            OnboardingWelcomeStep { Task { await store.advance() } }
        case .staples:
            OnboardingStaplesStep(store: store)
        case .fridge:
            OnboardingFridgeStep(store: store)
        case .dishes:
            OnboardingDishesStep(store: store)
        case .done:
            OnboardingDoneStep(finish: finish)
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.medium) {
            Button("Back") { store.back() }
                .buttonStyle(.bordered)
                .frame(minHeight: Metrics.minimumTapTarget)
            Button {
                Task { await store.advance() }
            } label: {
                Text(store.step == .dishes ? "Finish" : "Next")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.primaryAction)
            .disabled(store.isSaving)
            .accessibilityIdentifier("onboarding.next")
        }
        .padding(Spacing.large)
        .background(ThemeColor.surface.color.ignoresSafeArea(edges: .bottom))
    }
}
