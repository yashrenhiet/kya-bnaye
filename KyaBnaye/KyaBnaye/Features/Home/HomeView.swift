import KyaCore
import SwiftUI

/// Destinations pushed from Home.
enum HomeRoute: Hashable {
    case history
    case settings
}

/// Home: the swipe deck and Today's picks. History and Settings hang off its toolbar.
/// Creates its stores from the app environment; a new ``DeckStore`` (so Kitchen mode) on
/// every launch.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: DeckStore?
    @State private var cookFlow: CookFlowStore?
    @State private var viewingRecipeId: String?

    var body: some View {
        Group {
            if let store, let cookFlow {
                HomeScreen(store: store, cookFlow: cookFlow) { viewingRecipeId = $0 }
            } else {
                ProgressView()
                    .accessibilityLabel("Loading your dishes")
            }
        }
        .themedScreen()
        .navigationTitle("Kya bnaye?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationDestination(for: HomeRoute.self) { route in
            switch route {
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .navigationDestination(item: $viewingRecipeId) { HomeRecipeDetail(recipeId: $0) }
        .task { makeStores() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let store else { return }
            Task { await store.refreshForNewDay() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink(value: HomeRoute.history) {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: HomeRoute.settings) {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    private func makeStores() {
        guard store == nil, let repositories = environment.repositories else { return }
        let calendar = { [environment] in environment.calendar }
        store = DeckStore(repositories: repositories, now: environment.now, calendar: calendar)
        cookFlow = CookFlowStore(
            repositories: repositories, now: environment.now, calendar: calendar)
    }
}

/// The recipe detail from the Recipes tab, opened from Home's pick sheet or Today's picks.
/// Owns a ``RecipesStore`` for its lifetime so favourite, hide and "Add missing" behave
/// exactly as in the recipe book.
private struct HomeRecipeDetail: View {
    let recipeId: String

    @Environment(AppEnvironment.self) private var environment
    @State private var store: RecipesStore?

    var body: some View {
        Group {
            if let store {
                RecipeDetailView(store: store, recipeId: recipeId)
            } else {
                ProgressView("Loading recipe…")
            }
        }
        .themedScreen()
        .task {
            guard store == nil, let repositories = environment.repositories else { return }
            store = RecipesStore(
                repositories: repositories, now: environment.now,
                calendar: { [environment] in environment.calendar })
        }
    }
}
