import KyaCore
import SwiftUI

/// "That's all for now": Shuffle for a fresh deck, or try the other mode. Undo stays live so
/// a mis-swiped last card can come back.
struct EndOfDeckView: View {
    let store: DeckStore

    var body: some View {
        VStack(spacing: Spacing.large) {
            EmptyStateView(
                symbolName: "sparkles", title: "That's all for now",
                message: store.mode == .kitchen
                    ? "No more dishes you can make right now. Shuffle, or see what you'd love."
                    : "You've seen every suggestion. Shuffle for a fresh mix.")
            HStack(spacing: Spacing.medium) {
                Button {
                    Task { await store.shuffle() }
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier("deck.shuffle")
                Button {
                    Task { await store.setMode(store.mode.other) }
                } label: {
                    Label("Try \(store.mode.other.title)", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("deck.switchMode")
            }
            .disabled(store.isWriting)
            if store.canUndo {
                DeckControls(store: store, hasCard: false) { _ in }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Every dish is hidden (or the book is empty), so no mode has anything to suggest. Undo
/// stays live, so hiding the last dish by mistake can be reverted here.
struct NoRecipesView: View {
    let store: DeckStore
    let openRecipes: () -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            EmptyStateView(
                symbolName: "eye.slash", title: "No dishes to suggest",
                message:
                    "Every dish is hidden. Unhide a few in Recipes → Hidden recipes, or add your own."
            )
            Button(action: openRecipes) {
                Label("Open Recipes", systemImage: "book")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primaryAction)
            .accessibilityHint("Opens the Recipes tab.")
            .accessibilityIdentifier("deck.openRecipes")
            if store.canUndo {
                DeckControls(store: store, hasCard: false) { _ in }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Kitchen mode with nothing stocked: a deck from staples alone would be meaningless, so
/// offer the two useful next steps instead.
struct EmptyPantryView: View {
    let addToPantry: () -> Void
    let tryCraving: () -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            EmptyStateView(
                symbolName: "refrigerator", title: "What's at home?",
                message:
                    "Kitchen mode suggests dishes from your pantry. Mark a few things you have, or pick by craving."
            )
            Button(action: addToPantry) {
                Label("Add what's at home", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.primaryAction)
            .accessibilityHint("Opens the Pantry tab.")
            .accessibilityIdentifier("deck.addToPantry")
            Button(action: tryCraving) {
                Label("Try Craving mode", systemImage: "heart")
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("deck.tryCraving")
        }
        .frame(maxWidth: .infinity)
    }
}
