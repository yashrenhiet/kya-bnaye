import KyaCore
import SwiftUI

extension View {
    /// Attaches the "I made this" follow-ups driven by `store`: the "Used up anything?"
    /// sheet and an alert for failures. Start the flow with ``CookFlowStore/cook(_:)``.
    ///
    /// Swiping the sheet away counts as Skip (nothing changes).
    ///
    /// - Parameter store: The flow to present.
    /// - Returns: The view with the flow attached.
    func cookFlow(_ store: CookFlowStore) -> some View {
        modifier(CookFlowModifier(store: store))
    }
}

private struct CookFlowModifier: ViewModifier {
    let store: CookFlowStore

    func body(content: Content) -> some View {
        content
            .sheet(
                isPresented: Binding(
                    get: { store.isAskingUsedUp },
                    set: { if !$0 { store.skip() } })
            ) {
                UsedUpSheet(store: store)
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { store.errorMessage != nil && !store.isAskingUsedUp },
                    set: { if !$0 { store.errorMessage = nil } }),
                presenting: store.errorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }
}

/// "I made this": logs the meal and runs the used-up flow. Owns its ``CookFlowStore``,
/// created from the app environment, so it can be dropped into any screen:
///
/// ```swift
/// CookButton(recipe: recipe) { message in banner = message }
/// ```
struct CookButton: View {
    /// The dish that was made.
    let recipe: Recipe
    /// Receives short confirmations ("Dal Tadka added to your history") for a banner.
    var onConfirmation: (String) -> Void = { _ in }

    @Environment(AppEnvironment.self) private var environment
    @State private var store: CookFlowStore?

    var body: some View {
        Button {
            guard let store = resolvedStore() else { return }
            Task { await store.cook(recipe) }
        } label: {
            Label("I made this", systemImage: "fork.knife.circle.fill")
                .font(Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
        }
        .buttonStyle(.primaryAction)
        .disabled(store?.isBusy ?? false)
        .accessibilityHint("Adds this dish to your history, then asks what got used up.")
        .accessibilityIdentifier("cook.madeThis")
        .modifier(OptionalCookFlow(store: store))
        .onChange(of: store?.confirmation) { _, message in
            guard let message else { return }
            onConfirmation(message)
            store?.confirmation = nil
        }
    }

    private func resolvedStore() -> CookFlowStore? {
        if let store { return store }
        guard let repositories = environment.repositories else { return nil }
        let created = CookFlowStore(
            repositories: repositories, now: environment.now,
            calendar: { [environment] in environment.calendar })
        store = created
        return created
    }
}

/// Attaches ``View/cookFlow(_:)`` once the button has created its store.
private struct OptionalCookFlow: ViewModifier {
    let store: CookFlowStore?

    func body(content: Content) -> some View {
        if let store {
            content.cookFlow(store)
        } else {
            content
        }
    }
}

/// "Used up anything?": the recipe's perishables that were in stock, each with one-tap
/// Low / Out. Confirm writes only what was tapped; Skip writes nothing.
struct UsedUpSheet: View {
    let store: CookFlowStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.candidates, id: \.ingredient.id) { candidate in
                        UsedUpRow(
                            candidate: candidate, choice: store.choices[candidate.ingredient.id]
                        ) { level in
                            store.choose(level, for: candidate.ingredient.id)
                        }
                    }
                } header: {
                    SectionHeader("Used up anything?")
                } footer: {
                    SectionFooter("Only what you tap changes. Everything else stays as it is.")
                }
                if let message = store.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(ThemeColor.stockOut.color)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeColor.background.color)
            .safeAreaInset(edge: .top) { header }
            .navigationTitle("Nice cooking!")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(store.phase == .savingLevels)
    }

    private var header: some View {
        Text("\(store.recipe?.name ?? String(localized: "This dish")) is in your history.")
            .font(Typography.supporting)
            .foregroundStyle(ThemeColor.textSecondary.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.large)
            .padding(.top, Spacing.small)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Skip") { store.skip() }
                .accessibilityHint("Leaves your pantry unchanged.")
                .accessibilityIdentifier("usedUp.skip")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Confirm") { Task { await store.confirm() } }
                .disabled(store.phase == .savingLevels)
                .accessibilityHint("Saves the levels you picked.")
                .accessibilityIdentifier("usedUp.confirm")
        }
    }
}

/// One perishable with its current level and Low / Out toggles.
private struct UsedUpRow: View {
    let candidate: UsedUpCandidate
    let choice: StockLevel?
    let choose: (StockLevel) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.medium) {
                title
                Spacer(minLength: Spacing.small)
                buttons
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                title
                buttons
            }
        }
        .padding(.vertical, Spacing.xSmall)
        .accessibilityElement(children: .contain)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(candidate.ingredient.name)
                .font(Typography.body)
                .foregroundStyle(ThemeColor.textPrimary.color)
            Text("Was \(candidate.currentLevel.appearance.title)")
                .font(Typography.caption)
                .foregroundStyle(ThemeColor.textSecondary.color)
        }
    }

    private var buttons: some View {
        HStack(spacing: Spacing.small) {
            levelButton(.low)
            levelButton(.out)
        }
    }

    private func levelButton(_ level: StockLevel) -> some View {
        let appearance = level.appearance
        let isSelected = choice == level
        return Button {
            choose(level)
        } label: {
            Label(appearance.title, systemImage: isSelected ? appearance.symbolName : "circle")
                .font(Typography.supporting.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? appearance.color.color : ThemeColor.textPrimary.color)
                .padding(.horizontal, Spacing.medium)
                .frame(minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
                .background(
                    Capsule().strokeBorder(
                        isSelected ? appearance.color.color : ThemeColor.textSecondary.color,
                        lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(candidate.ingredient.name): \(appearance.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("usedUp.\(candidate.ingredient.id).\(level.rawValue)")
    }
}
