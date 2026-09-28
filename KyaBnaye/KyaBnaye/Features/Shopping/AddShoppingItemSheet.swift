import SwiftUI

/// "+ Add item": type anything, pick a catalog suggestion ("alo" offers Potato), or keep
/// the text as typed. Stays open so several things can be added in a row.
struct AddShoppingItemSheet: View {
    let store: ShoppingStore

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var feedback: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Tomato, aloo, candles…", text: $text)
                        .font(Typography.body)
                        .focused($isFieldFocused)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { add { await store.addItem(named: text) } }
                        .frame(minHeight: Metrics.minimumTapTarget)
                        .accessibilityLabel("Item name")
                        .accessibilityIdentifier("shopping.add.field")
                } footer: {
                    if let feedback {
                        Text(feedback)
                            .font(Typography.caption)
                            .foregroundStyle(ThemeColor.textSecondary.color)
                            .accessibilityIdentifier("shopping.add.feedback")
                    }
                }
                suggestions
            }
            .scrollContentBackground(.hidden)
            .themedScreen()
            .navigationTitle("Add item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("shopping.add.done")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add { await store.addItem(named: text) } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("shopping.add.confirm")
                }
            }
            .onAppear { isFieldFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var suggestions: some View {
        let matches = store.suggestions(for: text)
        if !matches.isEmpty {
            Section {
                ForEach(matches) { suggestion in
                    Button {
                        add { await store.addSuggestion(suggestion) }
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text(suggestion.name)
                                .font(Typography.body)
                                .foregroundStyle(ThemeColor.textPrimary.color)
                            if let alias = suggestion.matchedAlias {
                                Text("also called \(alias)")
                                    .font(Typography.caption)
                                    .foregroundStyle(ThemeColor.textSecondary.color)
                            }
                        }
                        .frame(
                            maxWidth: .infinity, minHeight: Metrics.minimumTapTarget,
                            alignment: .leading
                        )
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(ThemeColor.surface.color)
                    .accessibilityHint("Adds it to your shopping list.")
                }
            } header: {
                SectionHeader("From your kitchen list")
            }
        }
    }

    /// Runs an add, then clears the field and says what happened.
    private func add(_ action: @escaping () async -> ShoppingAddResult) {
        Task {
            switch await action() {
            case .added(let name):
                feedback = String(localized: "Added \(name).")
                text = ""
            case .alreadyListed(let name):
                feedback = String(localized: "\(name) is already on your list.")
            case .failed(let message):
                feedback = message
            case .blank:
                break
            }
            isFieldFocused = true
        }
    }
}
