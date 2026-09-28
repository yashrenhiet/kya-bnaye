import KyaCore
import SwiftUI

/// Step 1: what the app does and how long setup takes.
struct OnboardingWelcomeStep: View {
    let start: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xLarge) {
                EmptyStateView(
                    symbolName: "fork.knife", title: "Kya bnaye?",
                    message: """
                        Tell us what's usually at home and a few dishes you love. \
                        We'll suggest what to cook. Takes under two minutes.
                        """)
                Button(action: start) {
                    Text("Let's start")
                        .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier("onboarding.start")
            }
            .padding(Spacing.xLarge)
            .frame(maxWidth: Metrics.readableWidth)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Step 2: staples that are always at home, all ticked by default.
struct OnboardingStaplesStep: View {
    let store: OnboardingStore

    var body: some View {
        List {
            Section {
                ForEach(store.staples, id: \.id) { staple in
                    ChecklistRow(
                        id: staple.id, title: staple.name,
                        isOn: store.tickedStapleIds.contains(staple.id)
                    ) {
                        store.toggleStaple(staple.id)
                    }
                }
            } header: {
                StepHeading(
                    title: "Always at home?",
                    message: "We'll assume these are there. Untick anything you don't keep.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// Step 3: perishables in the fridge today, searchable by name or alias.
struct OnboardingFridgeStep: View {
    @Bindable var store: OnboardingStore

    var body: some View {
        List {
            Section {
                TextField("Search (e.g. dahi, bhindi)", text: $store.fridgeQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: Metrics.minimumTapTarget)
                    .accessibilityIdentifier("onboarding.fridgeSearch")
                ForEach(store.visibleFridgeItems, id: \.id) { item in
                    ChecklistRow(
                        id: item.id, title: item.name, isOn: store.tickedFridgeIds.contains(item.id)
                    ) {
                        store.toggleFridgeItem(item.id)
                    }
                }
                if store.visibleFridgeItems.isEmpty {
                    Text("No match. You can add it from the Pantry later.")
                        .font(Typography.supporting)
                        .foregroundStyle(ThemeColor.textSecondary.color)
                }
            } header: {
                StepHeading(
                    title: "What's in the fridge today?",
                    message: "Tick what you have. We'll guess when each one goes off.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// Step 4: pick five dishes you love, from a grid of popular ones.
struct OnboardingDishesStep: View {
    let store: OnboardingStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Spacing.medium)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                StepHeading(
                    title: "Pick \(OnboardingStore.pickTarget) dishes you love",
                    message:
                        "\(store.pickedRecipeIds.count) of \(OnboardingStore.pickTarget) picked")
                LazyVGrid(columns: columns, spacing: Spacing.medium) {
                    ForEach(store.dishChoices, id: \.id) { recipe in
                        DishTile(
                            recipe: recipe, isPicked: store.pickedRecipeIds.contains(recipe.id),
                            isEnabled: store.canPickMore
                        ) { store.togglePick(recipe.id) }
                    }
                }
            }
            .padding(Spacing.large)
        }
    }
}

/// The last screen: done, straight to the deck.
struct OnboardingDoneStep: View {
    let finish: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            EmptyStateView(
                symbolName: "checkmark.seal", title: "You're all set",
                message: "Tap an item in the Pantry to mark it Low or Out as things run down.")
            Button(action: finish) {
                Text("Show me what to cook")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.primaryAction)
            .accessibilityIdentifier("onboarding.finish")
        }
        .padding(Spacing.xLarge)
        .frame(maxWidth: Metrics.readableWidth)
    }
}

/// A step's headline and one line of explanation.
private struct StepHeading: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(ThemeColor.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(Typography.body)
                .foregroundStyle(ThemeColor.textSecondary.color)
        }
        .textCase(nil)
        .padding(.bottom, Spacing.small)
    }
}

/// A tickable row: a checkbox symbol and the name. Ticked state is shown by symbol and
/// spoken as selected, not conveyed by colour.
private struct ChecklistRow: View {
    let id: String
    let title: String
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(ThemeColor.accent.color)
                    .imageScale(.large)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(ThemeColor.textPrimary.color)
                Spacer()
            }
            .frame(minHeight: Metrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityValue(isOn ? "Ticked" : "Not ticked")
        .accessibilityIdentifier("onboarding.item.\(id)")
    }
}

/// A dish in the picker grid: an initial on a warm tile (until photos land), name and time.
private struct DishTile: View {
    let recipe: Recipe
    let isPicked: Bool
    let isEnabled: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                ZStack(alignment: .topTrailing) {
                    Text(String(recipe.name.prefix(1)))
                        .font(Typography.display)
                        .foregroundStyle(ThemeColor.accent.color)
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.medium)
                                .fill(ThemeColor.turmeric.color.opacity(0.3)))
                    if isPicked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(ThemeColor.onAccent.color, ThemeColor.accent.color)
                            .padding(Spacing.small)
                    }
                }
                Text(recipe.name)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(ThemeColor.textPrimary.color)
                    .multilineTextAlignment(.leading)
                Text("\(recipe.minutes) min")
                    .font(Typography.caption)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium).fill(ThemeColor.surface.color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium)
                    .strokeBorder(ThemeColor.accent.color, lineWidth: isPicked ? 3 : 0)
            )
            .opacity(isPicked || isEnabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipe.name), \(recipe.minutes) minutes")
        .accessibilityValue(isPicked ? "Picked" : "")
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isPicked || isEnabled ? "" : "You've picked five. Untick one to swap.")
        .accessibilityIdentifier("onboarding.dish.\(recipe.id)")
    }
}
