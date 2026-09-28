import SwiftUI

/// The app shell: one `NavigationStack` per tab so each tab keeps its own history.
struct RootTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        let selection = $selection
        TabView(selection: selection) {
            tab(.home) { HomeView() }
            tab(.pantry) { PantryView() }
            tab(.recipes) { RecipesView() }
            tab(.shopping) { ShoppingView() }
        }
        .environment(\.selectTab, SelectTabAction { selection.wrappedValue = $0 })
    }

    private func tab(_ tab: AppTab, @ViewBuilder root: () -> some View) -> some View {
        NavigationStack(root: root)
            .tabItem { Label(tab.title, systemImage: tab.symbolName) }
            .tag(tab)
    }
}

#Preview {
    RootTabView()
}
