import KyaCore
import SwiftUI

/// Home for a ready store: greeting, mode and meal-slot controls, the deck (or its end /
/// empty-pantry / error state), then Today's picks.
struct HomeScreen: View {
    let store: DeckStore
    let cookFlow: CookFlowStore
    /// Opens a recipe's detail.
    let viewRecipe: (String) -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.selectTab) private var selectTab
    @State private var reloadToken = 0

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text(HomeGreeting.text(now: environment.now(), calendar: environment.calendar))
                    .font(Typography.headline)
                    .foregroundStyle(ThemeColor.textPrimary.color)
                    .accessibilityAddTraits(.isHeader)
                DeckHeader(store: store)
                deck
                TodaysPicksTray(store: store, cookFlow: cookFlow, viewRecipe: viewRecipe)
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.medium)
            .frame(maxWidth: Metrics.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .task(id: reloadToken) { await store.observe() }
        .sheet(isPresented: isShowingPick) {
            if let card = store.pickedCard {
                PickSheet(store: store, card: card) {
                    store.pickedCard = nil
                    viewRecipe(card.recipe.id)
                }
            }
        }
        .cookFlow(cookFlow)
        .errorAlert($store.actionError)
        .safeAreaInset(edge: .bottom) { ConfirmationBanner(message: $store.confirmation) }
        .onChange(of: cookFlow.confirmation) { _, message in
            guard let message else { return }
            store.confirmation = message
            cookFlow.confirmation = nil
        }
    }

    @ViewBuilder
    private var deck: some View {
        switch store.content {
        case .loading:
            ProgressView("Finding dishes…")
                .font(Typography.body)
                .frame(maxWidth: .infinity, minHeight: 240)
        case .card(let card):
            DeckArea(store: store, card: card)
        case .endOfDeck:
            EndOfDeckView(store: store)
        case .emptyPantry:
            EmptyPantryView {
                selectTab(.pantry)
            } tryCraving: {
                Task { await store.setMode(.craving) }
            }
        case .noRecipes:
            NoRecipesView(store: store) { selectTab(.recipes) }
        case .failed(let message):
            // Home already scrolls, so the error state is laid out inline.
            LoadFailedView(
                title: "Couldn't load your dishes", detail: message, scrolls: false
            ) {
                reloadToken += 1
            }
        }
    }

    private var isShowingPick: Binding<Bool> {
        Binding(
            get: { store.pickedCard != nil },
            set: { if !$0 { store.pickedCard = nil } })
    }
}

/// `Kitchen | Craving` and the meal-slot menu.
private struct DeckHeader: View {
    let store: DeckStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.medium) {
                modePicker
                mealMenu
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                modePicker
                mealMenu
            }
        }
    }

    private var modePicker: some View {
        Picker(
            "Mode",
            selection: Binding(
                get: { store.mode },
                set: { mode in Task { await store.setMode(mode) } })
        ) {
            ForEach(SwipeMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: Metrics.minimumTapTarget)
        .disabled(store.isWriting)
        .accessibilityIdentifier("home.mode")
        .accessibilityHint("Kitchen shows what you can cook now; Craving shows what you'd love.")
    }

    private var mealMenu: some View {
        Menu {
            Button {
                Task { await store.setMealType(nil) }
            } label: {
                Label(
                    "Now (automatic)",
                    systemImage: store.mealTypeOverride == nil ? "checkmark" : "clock")
            }
            ForEach(MealType.allCases, id: \.self) { meal in
                Button {
                    Task { await store.setMealType(meal) }
                } label: {
                    if store.mealTypeOverride == meal {
                        Label(meal.displayName, systemImage: "checkmark")
                    } else {
                        Text(meal.displayName)
                    }
                }
                .accessibilityIdentifier("home.meal.\(meal.rawValue)")
            }
        } label: {
            Label(store.mealType.displayName, systemImage: "chevron.down")
                .labelStyle(TrailingIconLabelStyle())
                .font(Typography.body.weight(.semibold))
                // Never truncate: when it no longer fits beside the picker, the header stacks.
                .fixedSize()
                .frame(minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
        }
        .disabled(store.mode == .craving || store.isWriting)
        .accessibilityLabel("Meal")
        .accessibilityValue(store.mealType.displayName)
        .accessibilityHint(
            store.mode == .craving
                ? "Craving mode suggests dishes for any meal."
                : "Changes which meal to suggest for."
        )
        .accessibilityIdentifier("home.meal")
    }
}

/// Title first, then a small trailing icon ("Dinner ⌄").
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xSmall) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}
