import KyaCore
import SwiftUI

/// Shopping: what to buy, grouped by where you buy it. Creates its store once the data is
/// ready and keeps it for the life of the tab, so deletions made this session stick.
struct ShoppingView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var store: ShoppingStore?
    @State private var reloadToken = 0

    var body: some View {
        Group {
            if let store {
                ShoppingListScreen(store: store) { reloadToken += 1 }
            } else {
                ProgressView()
                    .accessibilityLabel("Loading your list")
                    .themedScreen()
            }
        }
        .navigationTitle("Shopping")
        .task(id: reloadToken) {
            guard let repositories = environment.repositories else { return }
            let store =
                self.store
                ?? ShoppingStore(
                    repositories: repositories, now: environment.now,
                    calendar: { [environment] in environment.calendar })
            self.store = store
            await store.load()
            await store.observe()
        }
    }
}

/// The loaded Shopping screen: loading, error, empty and list states.
private struct ShoppingListScreen: View {
    @Bindable var store: ShoppingStore
    /// Reads everything again after a failure.
    let retry: () -> Void
    @State private var isAdding = false

    var body: some View {
        content
            .themedScreen()
            .toolbar { toolbar }
            .sheet(isPresented: $isAdding) { AddShoppingItemSheet(store: store) }
            .errorAlert($store.actionError)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            ProgressView("Loading your list…")
        case .failed(let message):
            LoadFailedView(title: "Couldn't load your list", detail: message, retry: retry)
        case .loaded where store.items.isEmpty:
            CenteredScrollView {
                VStack(spacing: Spacing.large) {
                    EmptyStateView(
                        symbolName: "cart", title: "Your list is clear",
                        message:
                            "Low and Out pantry items land here on their own, grouped by sabziwala, kirana and dairy."
                    )
                    addButton.buttonStyle(.primaryAction)
                }
            }
        case .loaded:
            list
        }
    }

    private var list: some View {
        List {
            ForEach(store.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        ShoppingRowView(row: row) {
                            Task { await store.setChecked(!row.isChecked, itemId: row.id) }
                        } delete: {
                            Task { await store.delete(itemIds: [row.id]) }
                        }
                    }
                } header: {
                    SectionHeader(verbatim: section.vendor.displayName)
                }
            }
            Section {
                addButton
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { moveButton }
    }

    @ViewBuilder
    private var moveButton: some View {
        let count = store.checkedCount
        if count > 0 {
            Button {
                Task { await store.moveBoughtItemsToPantry() }
            } label: {
                Text(
                    count == 1
                        ? "Move 1 bought item to pantry" : "Move \(count) bought items to pantry"
                )
                .font(Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            }
            .buttonStyle(.primaryAction)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.small)
            .background(ThemeColor.background.color)
            .accessibilityHint("Marks them Plenty in your pantry and removes them from the list.")
        }
    }

    private var addButton: some View {
        Button {
            isAdding = true
        } label: {
            Label("Add item", systemImage: "plus")
                .frame(minHeight: Metrics.minimumTapTarget)
        }
        .accessibilityIdentifier("shopping.addItem")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            let text = store.shareText
            if !text.isEmpty {
                ShareLink(item: text, preview: SharePreview("Shopping list")) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityHint("Shares the items still to buy as text.")
            }
        }
    }
}

/// One shopping row: a tick box, the name and why it's on the list. Tapping anywhere on
/// the row ticks it; swipe (or the VoiceOver action) deletes it.
private struct ShoppingRowView: View {
    let row: ShoppingRow
    let toggle: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: row.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        row.isChecked
                            ? ThemeColor.stockPlenty.color : ThemeColor.textSecondary.color
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(row.name)
                        .font(Typography.body)
                        .strikethrough(row.isChecked)
                        .foregroundStyle(ThemeColor.textPrimary.color)
                    Text(row.reasonText)
                        .font(Typography.caption)
                        .foregroundStyle(ThemeColor.textSecondary.color)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Metrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(ThemeColor.surface.color)
        .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.reasonText)")
        .accessibilityValue(row.isChecked ? "Bought" : "Not bought")
        .accessibilityHint(row.isChecked ? "Double-tap to untick." : "Double-tap to tick off.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, toggle)
        .accessibilityAction(named: "Delete", delete)
        .accessibilityIdentifier("shopping.row.\(row.name)")
    }
}
