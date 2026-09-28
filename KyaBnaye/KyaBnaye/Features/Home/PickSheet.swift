import KyaCore
import SwiftUI

/// After a right swipe: "Picked: Palak Paneer", what's missing, and the three next steps,
/// View recipe / Add missing to shopping list / Keep swiping (`RECOMMENDER.md` section 2).
struct PickSheet: View {
    let store: DeckStore
    let card: ScoredRecipe
    let viewRecipe: () -> Void

    @State private var addedMessage: String?
    @State private var errorMessage: String?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    summary
                    actions
                }
                .padding(Spacing.large)
            }
            .background(ThemeColor.background.color)
            .navigationTitle("Picked")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            RecipeArtwork(
                recipeId: card.recipe.id, name: card.recipe.name, cornerRadius: Radius.medium
            )
            .frame(width: Metrics.minimumTapTarget * 2, height: Metrics.minimumTapTarget * 2)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(card.recipe.name)
                    .font(Typography.headline)
                    .foregroundStyle(ThemeColor.textPrimary.color)
                    .accessibilityAddTraits(.isHeader)
                Text(card.haveText)
                    .font(Typography.supporting)
                    .foregroundStyle(ThemeColor.textSecondary.color)
                Text(missingText)
                    .font(Typography.supporting)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: Spacing.medium) {
            Button(action: viewRecipe) {
                Label("View recipe", systemImage: "book")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("pick.viewRecipe")
            addMissingButton
            Button {
                store.pickedCard = nil
            } label: {
                Label("Keep swiping", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.primaryAction)
            .accessibilityIdentifier("pick.keepSwiping")
        }
    }

    @ViewBuilder
    private var addMissingButton: some View {
        if let addedMessage {
            Label(addedMessage, systemImage: "checkmark.circle.fill")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(ThemeColor.stockPlenty.color)
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                .accessibilityIdentifier("pick.added")
        } else {
            Button {
                Task { await addMissing() }
            } label: {
                Label("Add missing to shopping list", systemImage: "cart.badge.plus")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .disabled(card.missingIngredientIds.isEmpty || isAdding)
            .accessibilityHint(
                card.missingIngredientIds.isEmpty ? "Nothing is missing." : missingText
            )
            .accessibilityIdentifier("pick.addMissing")
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(Typography.supporting)
                    .foregroundStyle(ThemeColor.stockOut.color)
            }
        }
    }

    private var missingText: String {
        let names = store.ingredientNames(card.missingIngredientIds)
        return names.isEmpty
            ? String(localized: "Nothing missing.")
            : String(localized: "Missing: \(names.joined(separator: ", "))")
    }

    /// Adds the missing items, reporting the outcome inside the sheet (an alert on Home
    /// would stay hidden behind it), so the store's message is taken rather than repeated.
    private func addMissing() async {
        isAdding = true
        defer { isAdding = false }
        errorMessage = nil
        await store.addMissingToShoppingList(card.recipe)
        if let error = store.actionError {
            errorMessage = error
            store.actionError = nil
        } else if let confirmation = store.confirmation {
            addedMessage = confirmation
            store.confirmation = nil
            AccessibilityNotification.Announcement(confirmation).post()
        }
    }
}
