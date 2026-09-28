import KyaCore
import SwiftUI

/// Recipe detail: photo placeholder, name and meta, what's at home vs missing, steps, and the
/// two actions a cook wants here, Favourite and "I made this".
struct RecipeDetailView: View {
    let store: RecipesStore
    let recipeId: String

    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    var body: some View {
        Group {
            if let recipe = store.recipe(withId: recipeId) {
                RecipeDetailContent(store: store, recipe: recipe)
                    .toolbar { toolbar(for: recipe) }
                    .sheet(isPresented: $isEditing) {
                        RecipeEditorView(recipe: recipe) { store.confirmation = $0 }
                    }
                    .confirmationDialog(
                        "Delete \(recipe.name)?", isPresented: $isConfirmingDelete,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            Task { await store.delete(recipe) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Your history of cooking it is kept.")
                    }
            } else if store.phase == .loading {
                ProgressView("Loading recipe…")
            } else {
                EmptyStateView(
                    symbolName: "book.closed", title: "Recipe not found",
                    message: "It may have been deleted.")
            }
        }
        .themedScreen()
        .navigationBarTitleDisplayMode(.inline)
        // The list's observation stops while this screen covers it; keep "last made" and
        // the have/missing marks live here (e.g. right after "I made this").
        .task { await store.observe() }
    }

    @ToolbarContentBuilder
    private func toolbar(for recipe: Recipe) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    Task { await store.setHidden(!recipe.isHidden, for: recipe) }
                } label: {
                    recipe.isHidden
                        ? Label("Unhide", systemImage: "eye")
                        : Label("Hide from recipes and deck", systemImage: "eye.slash")
                }
                if recipe.source == .user {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("recipe.more")
        }
    }
}

/// The scrolling body of the detail screen plus its bottom action bar.
private struct RecipeDetailContent: View {
    let store: RecipesStore
    let recipe: Recipe

    var body: some View {
        let cookability = store.cookability(for: recipe)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                RecipeArtwork(recipeId: recipe.id, name: recipe.name)
                    .aspectRatio(16 / 9, contentMode: .fit)
                RecipeHeader(
                    recipe: recipe, cookability: cookability,
                    daysSinceCooked: store.daysSinceLastCooked(recipe.id))
                RecipeIngredientsSection(cookability: cookability) {
                    Task { await store.addMissingToShoppingList(recipe) }
                }
                RecipeStepsSection(steps: recipe.steps)
            }
            .padding(Spacing.large)
            .frame(maxWidth: Metrics.readableWidth * 1.5)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    private var actionBar: some View {
        @Bindable var store = store
        return VStack(spacing: Spacing.small) {
            ConfirmationBanner(message: $store.confirmation)
            HStack(spacing: Spacing.medium) {
                favouriteButton
                CookButton(recipe: recipe) { store.confirmation = $0 }
            }
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .background(ThemeColor.background.color)
        .overlay(alignment: .top) { Divider() }
    }

    private var favouriteButton: some View {
        Button {
            Task { await store.toggleFavorite(recipe) }
        } label: {
            Label(
                recipe.isFavorite ? "Favourite" : "Add to favourites",
                systemImage: recipe.isFavorite ? "heart.fill" : "heart"
            )
            .labelStyle(.iconOnly)
            .font(Typography.headline)
            .frame(minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ThemeColor.accent.color)
        .background(Circle().fill(ThemeColor.surface.color))
        .overlay(Circle().strokeBorder(ThemeColor.accent.color.opacity(0.5)))
        .accessibilityLabel("Favourite")
        .accessibilityValue(recipe.isFavorite ? "On" : "Off")
        .accessibilityAddTraits(recipe.isFavorite ? .isSelected : [])
        .accessibilityIdentifier("recipe.favourite")
    }
}

/// Name, meta line, "last made", tags and the overall ready / missing status.
private struct RecipeHeader: View {
    let recipe: Recipe
    let cookability: RecipeCookability
    let daysSinceCooked: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(recipe.name)
                .font(Typography.display)
                .foregroundStyle(ThemeColor.textPrimary.color)
                .accessibilityAddTraits(.isHeader)
            Text(metaLine)
                .font(Typography.supporting)
                .foregroundStyle(ThemeColor.textSecondary.color)
            Label(lastMadeText, systemImage: "clock.arrow.circlepath")
                .font(Typography.supporting)
                .foregroundStyle(ThemeColor.textSecondary.color)
            FlowLayout {
                ForEach(recipe.tagDisplayNames, id: \.self) { title in
                    Text(title)
                        .font(Typography.caption)
                        .foregroundStyle(ThemeColor.textPrimary.color)
                        .padding(.horizontal, Spacing.small)
                        .padding(.vertical, Spacing.xSmall)
                        .background(Capsule().fill(ThemeColor.turmeric.color.opacity(0.3)))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tags: \(recipe.tagDisplayNames.joined(separator: ", "))")
            StatusBadge(
                appearance: cookability.appearance(
                    title: cookability.isReady
                        ? String(localized: "Ready to cook")
                        : String(localized: "\(cookability.missingCount) missing")))
        }
    }

    private var metaLine: String {
        var parts = [String(localized: "\(recipe.minutes) min"), recipe.mealTypesText]
        if recipe.base != .none { parts.append(recipe.base.displayName) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var lastMadeText: String {
        switch daysSinceCooked {
        case nil: String(localized: "Not made yet")
        case let days? where days <= 0: String(localized: "Last made today")
        case 1: String(localized: "Last made yesterday")
        case let days?: String(localized: "Last made \(days) days ago")
        }
    }
}
