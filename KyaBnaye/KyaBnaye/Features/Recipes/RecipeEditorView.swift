import KyaCore
import SwiftUI

/// Add / Edit recipe, presented as a sheet. Creates its store from the app environment.
struct RecipeEditorView: View {
    /// The recipe to edit, or `nil` to add a new one.
    let recipe: Recipe?
    /// Receives the confirmation message after a successful save.
    let onSaved: (String) -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var store: RecipeEditorStore?

    var body: some View {
        NavigationStack {
            Group {
                if let store {
                    RecipeEditorScreen(store: store, onSaved: onSaved)
                } else {
                    ProgressView().accessibilityLabel("Loading")
                }
            }
            .themedScreen()
            .navigationTitle(recipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard store == nil, let repositories = environment.repositories else { return }
            let created = RecipeEditorStore(editing: recipe, repositories: repositories)
            store = created
            await created.load()
        }
    }
}

/// The form for a ready store.
private struct RecipeEditorScreen: View {
    @Bindable var store: RecipeEditorStore
    let onSaved: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard let message = await store.save() else { return }
                            onSaved(message)
                            dismiss()
                        }
                    }
                    .disabled(store.isSaving || store.phase != .ready)
                    .accessibilityIdentifier("editor.save")
                }
            }
            .errorAlert($store.saveError)
            .interactiveDismissDisabled(store.draft != store.initialDraft)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            ProgressView("Loading ingredients…")
        case .failed(let message):
            LoadFailedView(
                title: "Couldn't open the editor",
                reassurance: "Your recipes are safe. Please try again.", detail: message
            ) {
                Task { await store.load() }
            }
        case .ready:
            form
        }
    }

    private var form: some View {
        Form {
            if !store.visibleIssues.isEmpty {
                Section {
                    ForEach(store.visibleIssues, id: \.self) { issue in
                        Label(issue.message, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(ThemeColor.stockOut.color)
                    }
                } header: {
                    SectionHeader("Fix these to save")
                }
                .accessibilityElement(children: .contain)
            }
            RecipeEditorBasicsSection(store: store)
            RecipeEditorIngredientsSection(store: store)
            RecipeEditorStepsSection(store: store)
            RecipeEditorTagsSection(draft: $store.draft) { store.toggleFlavour($0) }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Name, cooking time and meal slots.
private struct RecipeEditorBasicsSection: View {
    @Bindable var store: RecipeEditorStore

    var body: some View {
        Section {
            TextField("Name, e.g. Mom's rajma", text: $store.draft.name)
                .font(Typography.body)
                .textInputAutocapitalization(.words)
                .frame(minHeight: Metrics.minimumTapTarget)
                .accessibilityLabel("Name")
                .accessibilityIdentifier("editor.name")
            Stepper(
                value: $store.draft.minutes, in: RecipeDraft.minutesRange, step: 5
            ) {
                Text("Cooking time: \(store.draft.minutes) min")
                    .font(Typography.body)
            }
            .accessibilityValue("\(store.draft.minutes) minutes")
            FlowLayout {
                ForEach(MealType.allCases, id: \.self) { meal in
                    SelectableChip(
                        title: meal.displayName, symbolName: "circle",
                        isOn: store.draft.mealTypes.contains(meal)
                    ) {
                        store.toggleMealType(meal)
                    }
                }
            }
            .padding(.vertical, Spacing.xSmall)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Meals")
        } header: {
            SectionHeader("Dish")
        }
    }
}
