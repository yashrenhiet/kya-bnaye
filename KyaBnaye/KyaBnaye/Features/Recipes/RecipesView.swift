import KyaCore
import SwiftUI

/// Destinations pushed inside the Recipes tab.
enum RecipeRoute: Hashable {
    /// One recipe's detail.
    case detail(String)
    /// The hidden ("Never show") recipes, to unhide them.
    case hidden
}

/// Recipes: the searchable recipe book. Creates its store from the app environment.
struct RecipesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: RecipesStore?

    var body: some View {
        Group {
            if let store {
                RecipesScreen(store: store)
            } else {
                ProgressView()
                    .accessibilityLabel("Loading your recipes")
            }
        }
        .themedScreen()
        .navigationTitle("Recipes")
        .task {
            guard store == nil, let repositories = environment.repositories else { return }
            store = RecipesStore(
                repositories: repositories, now: environment.now,
                calendar: { [environment] in environment.calendar })
        }
    }
}

/// The recipe list for a ready store: search, filter chips, rows and "Add recipe".
private struct RecipesScreen: View {
    @Bindable var store: RecipesStore
    @State private var isAddingRecipe = false
    @State private var reloadToken = 0

    var body: some View {
        content
            .searchable(text: $store.filter.searchText, prompt: Text("Search dishes"))
            .toolbar { toolbar }
            .task(id: reloadToken) { await store.observe() }
            .navigationDestination(for: RecipeRoute.self) { route in
                switch route {
                case .detail(let id): RecipeDetailView(store: store, recipeId: id)
                case .hidden: HiddenRecipesView(store: store)
                }
            }
            .sheet(isPresented: $isAddingRecipe) {
                RecipeEditorView(recipe: nil) { store.confirmation = $0 }
            }
            .errorAlert($store.actionError)
            .safeAreaInset(edge: .bottom) { ConfirmationBanner(message: $store.confirmation) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            ProgressView("Loading your recipes…")
                .font(Typography.body)
        case .failed(let message):
            LoadFailedView(title: "Couldn't load your recipes", detail: message) {
                reloadToken += 1
            }
        case .loaded:
            RecipeList(store: store) { isAddingRecipe = true }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isAddingRecipe = true
            } label: {
                Label("Add recipe", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink(value: RecipeRoute.hidden) {
                Label("Hidden recipes", systemImage: "eye.slash")
            }
            .accessibilityValue("\(store.hiddenRecipes.count)")
        }
    }
}

/// Filter chips, then the recipe rows, or the right empty state.
private struct RecipeList: View {
    let store: RecipesStore
    let addRecipe: () -> Void

    var body: some View {
        @Bindable var store = store
        let rows = store.rows
        List {
            Section {
                RecipeFilterBar(filter: $store.filter)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            if rows.isEmpty {
                emptyState
            } else {
                Section {
                    ForEach(rows) { row in
                        NavigationLink(value: RecipeRoute.detail(row.id)) {
                            RecipeRowView(row: row)
                        }
                        .accessibilityIdentifier("recipes.row.\(row.id)")
                    }
                } footer: {
                    SectionFooter(
                        "Salt, oil and other staples are assumed at home unless marked Out.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var emptyState: some View {
        Section {
            VStack(spacing: Spacing.medium) {
                if store.hasNoVisibleRecipes {
                    EmptyStateView(
                        symbolName: "book", title: "Your recipe book is empty",
                        message: "Add a family favourite, or unhide dishes you hid earlier.")
                    Button(action: addRecipe) {
                        Label("Add recipe", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                    }
                    .buttonStyle(.primaryAction)
                } else {
                    EmptyStateView(
                        symbolName: "magnifyingglass", title: "No dishes match",
                        message: "Try another word, or turn off a filter.")
                    Button("Clear search and filters") { store.filter = RecipeFilter() }
                        .buttonStyle(.bordered)
                        .frame(minHeight: Metrics.minimumTapTarget)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }
}

/// One recipe: thumbnail, name, time and its ready / missing status (text + icon).
///
/// At accessibility text sizes the parts stack vertically so the name keeps the full width.
struct RecipeRowView: View {
    let row: RecipeRow

    var body: some View {
        AdaptiveStack { isStacked in
            RecipeArtwork(recipeId: row.id, name: row.recipe.name, cornerRadius: Radius.small)
                .frame(width: Metrics.minimumTapTarget + Spacing.medium)
                .frame(height: Metrics.minimumTapTarget + Spacing.medium)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(spacing: Spacing.xSmall) {
                    Text(row.recipe.name)
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(ThemeColor.textPrimary.color)
                    if row.recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(Typography.caption)
                            .foregroundStyle(ThemeColor.accent.color)
                            .accessibilityHidden(true)
                    }
                }
                Text("\(row.recipe.minutes) min")
                    .font(Typography.caption)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
            if !isStacked { Spacer(minLength: Spacing.small) }
            StatusBadge(appearance: row.cookability.appearance(title: row.statusText))
        }
        .frame(minHeight: Metrics.minimumTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.recipe.name)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts = [String(localized: "\(row.recipe.minutes) minutes"), row.statusText]
        if row.recipe.isFavorite { parts.append(String(localized: "Favourite")) }
        return parts.joined(separator: ", ")
    }
}
