import KyaCore
import SwiftUI

/// Pantry: what's at home, grouped by category. Creates its store from the app environment.
struct PantryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: PantryStore?

    var body: some View {
        Group {
            if let store {
                PantryScreen(store: store)
            } else {
                ProgressView()
                    .accessibilityLabel("Loading your pantry")
            }
        }
        .themedScreen()
        .navigationTitle("Pantry")
        .task {
            guard store == nil, let repositories = environment.repositories else { return }
            store = PantryStore(
                repositories: repositories, now: environment.now,
                calendar: { [environment] in environment.calendar })
        }
    }
}

/// The Pantry screen for a ready store: search/add field, filter chips and the grouped list.
private struct PantryScreen: View {
    @Bindable var store: PantryStore
    @State private var isSearching = false
    @State private var editing: PantryRow?
    @State private var newIngredient: NewIngredientRequest?
    @State private var reloadToken = 0

    var body: some View {
        content
            .searchable(
                text: $store.query, isPresented: $isSearching,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Add… (aloo, dahi)")
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSearching = true
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }
            }
            .task(id: reloadToken) { await store.observe() }
            .sheet(item: $editing) { row in
                PantryEditSheet(row: row, store: store)
            }
            .sheet(item: $newIngredient) { request in
                NewIngredientSheet(name: request.name, store: store)
            }
            .errorAlert($store.actionError)
            .safeAreaInset(edge: .bottom) { ConfirmationBanner(message: $store.confirmation) }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            ProgressView("Loading your pantry…")
                .font(Typography.body)
        case .failed(let message):
            LoadFailedView(title: "Couldn't load your pantry", detail: message) { reloadToken += 1 }
        case .loaded:
            if store.query.trimmingCharacters(in: .whitespaces).isEmpty {
                PantryList(store: store, editing: $editing) { isSearching = true }
            } else {
                PantrySearchResults(store: store) { newIngredient = NewIngredientRequest(name: $0) }
            }
        }
    }
}

/// Identifies the "add a new ingredient" sheet.
private struct NewIngredientRequest: Identifiable {
    let name: String
    var id: String { name }
}

/// The grouped pantry list with filter chips, the empty state and assumed staples.
private struct PantryList: View {
    let store: PantryStore
    @Binding var editing: PantryRow?
    let startAdding: () -> Void

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                PantryFilterChips(selection: $store.filter)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            emptyOrFilteredState
            ForEach(store.sections) { section in
                Section {
                    ForEach(section.rows) { row in rowView(row) }
                } header: {
                    SectionHeader(verbatim: section.category.displayName)
                }
            }
            if !store.assumedStaples.isEmpty {
                Section {
                    ForEach(store.assumedStaples) { row in rowView(row) }
                } header: {
                    SectionHeader("Always at home")
                } footer: {
                    SectionFooter(
                        "Staples are assumed at home until you mark them. Tap one to mark it Low.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var emptyOrFilteredState: some View {
        if store.isPantryEmpty && store.filter == .all {
            Section {
                VStack(spacing: Spacing.medium) {
                    EmptyStateView(
                        symbolName: "refrigerator", title: "Nothing in your pantry yet",
                        message: "Add what's at home, then tap an item to mark it Low or Out.")
                    Button(action: startAdding) {
                        Label("Add what's at home", systemImage: "plus")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
                    }
                    .buttonStyle(.primaryAction)
                }
            }
            .listRowBackground(Color.clear)
        } else if store.sections.isEmpty && store.filter != .all {
            Section {
                Text(store.filter == .low ? "Nothing is low or out." : "Nothing expires soon.")
                    .font(Typography.body)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
        }
    }

    private func rowView(_ row: PantryRow) -> some View {
        PantryRowView(row: row) { Task { await store.cycle(row) } }
            .swipeActions(edge: .trailing) {
                Button {
                    Task { await store.addToShoppingList(row) }
                } label: {
                    Label("Add to shopping list", systemImage: "cart.badge.plus")
                }
                .tint(ThemeColor.accent.color)
            }
            .contextMenu {
                Button {
                    editing = row
                } label: {
                    Label("Edit…", systemImage: "pencil")
                }
                Button {
                    Task { await store.addToShoppingList(row) }
                } label: {
                    Label("Add to shopping list", systemImage: "cart.badge.plus")
                }
            }
            .accessibilityAction(named: "Edit") { editing = row }
            .accessibilityAction(named: "Add to shopping list") {
                Task { await store.addToShoppingList(row) }
            }
    }
}

/// Catalog matches for the typed text, plus "add as a new item" when nothing matches exactly.
private struct PantrySearchResults: View {
    let store: PantryStore
    let createNew: (String) -> Void

    var body: some View {
        List {
            if !store.suggestions.isEmpty {
                Section {
                    ForEach(store.suggestions) { row in
                        Button {
                            Task { await store.add(row.ingredient) }
                        } label: {
                            SuggestionLabel(row: row)
                        }
                        .accessibilityIdentifier("pantry.suggestion.\(row.id)")
                    }
                } header: {
                    SectionHeader("Tap to mark Plenty")
                }
            }
            if let name = store.newIngredientName {
                Section {
                    Button {
                        createNew(name)
                    } label: {
                        Label("Add “\(name)” as a new item", systemImage: "plus.circle")
                            .frame(minHeight: Metrics.minimumTapTarget)
                    }
                } footer: {
                    SectionFooter("Not in our list yet. You'll pick where it belongs.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// One suggestion: the ingredient name, and its current level if it is already stocked.
private struct SuggestionLabel: View {
    let row: PantryRow

    var body: some View {
        HStack {
            Text(row.ingredient.name)
                .font(Typography.body)
                .foregroundStyle(ThemeColor.textPrimary.color)
            Spacer()
            if let level = row.item?.level {
                Text("Now \(level.appearance.title)")
                    .font(Typography.caption)
                    .foregroundStyle(ThemeColor.textSecondary.color)
            }
        }
        .frame(minHeight: Metrics.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Marks it Plenty.")
    }
}
