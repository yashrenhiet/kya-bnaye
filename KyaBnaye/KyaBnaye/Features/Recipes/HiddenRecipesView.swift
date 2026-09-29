import KyaCore
import SwiftUI

/// Recipes the user hid ("Never show"), each with a one-tap Unhide.
struct HiddenRecipesView: View {
    let store: RecipesStore

    var body: some View {
        @Bindable var store = store
        let hidden = store.hiddenRecipes
        Group {
            if hidden.isEmpty {
                CenteredScrollView {
                    EmptyStateView(
                        symbolName: "eye", title: "No hidden recipes",
                        message: "Dishes you hide from the recipe book or the deck appear here.")
                }
            } else {
                List {
                    Section {
                        ForEach(hidden, id: \.id) { recipe in
                            row(recipe)
                        }
                    } footer: {
                        SectionFooter(
                            "Hidden dishes never appear in your recipes or the swipe deck.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .themedScreen()
        .navigationTitle("Hidden recipes")
        .safeAreaInset(edge: .bottom) { ConfirmationBanner(message: $store.confirmation) }
    }

    private func row(_ recipe: Recipe) -> some View {
        AdaptiveStack { isStacked in
            RecipeArtwork(
                recipeId: recipe.id, name: recipe.name, imageAsset: recipe.imageAsset,
                cornerRadius: Radius.small
            )
            .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
            Text(recipe.name)
                .font(Typography.body)
                .foregroundStyle(ThemeColor.textPrimary.color)
            if !isStacked { Spacer(minLength: Spacing.small) }
            Button("Unhide") {
                Task { await store.setHidden(false, for: recipe) }
            }
            .buttonStyle(.bordered)
            .frame(minHeight: Metrics.minimumTapTarget)
            .accessibilityLabel("Unhide \(recipe.name)")
        }
    }
}
