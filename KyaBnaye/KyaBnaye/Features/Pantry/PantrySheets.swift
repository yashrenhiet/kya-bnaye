import KyaCore
import SwiftUI

/// Edit one pantry item: level, expiry date (or none) and "Remove from pantry".
struct PantryEditSheet: View {
    let row: PantryRow
    let store: PantryStore

    @Environment(\.dismiss) private var dismiss
    @State private var level: StockLevel
    @State private var hasExpiry: Bool
    @State private var expiresOn: Date
    @State private var expiryEdited = false
    @State private var isSaving = false

    init(row: PantryRow, store: PantryStore) {
        self.row = row
        self.store = store
        _level = State(initialValue: row.effectiveLevel)
        _hasExpiry = State(initialValue: row.item?.expiresOn != nil)
        _expiresOn = State(initialValue: row.item?.expiresOn ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Level", selection: $level) {
                        ForEach(StockLevel.allCases, id: \.self) { level in
                            Label(level.appearance.title, systemImage: level.appearance.symbolName)
                                .tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    SectionHeader("How much is at home?")
                }
                expirySection
                if !row.isAssumedStaple {
                    Section {
                        Button("Remove from pantry", role: .destructive) {
                            run { await store.remove(row) }
                        }
                    } footer: {
                        SectionFooter(
                            "Use this for things you don't keep at home. It won't be added to your shopping list."
                        )
                    }
                }
            }
            .navigationTitle(row.ingredient.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        run { await store.save(row, level: level, expiry: expiryChoice) }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var expirySection: some View {
        Section {
            Toggle("Has an expiry date", isOn: $hasExpiry)
                .onChange(of: hasExpiry) { expiryEdited = true }
            if hasExpiry {
                DatePicker("Expires on", selection: $expiresOn, displayedComponents: .date)
                    .onChange(of: expiresOn) { expiryEdited = true }
            }
        } header: {
            SectionHeader("Expiry")
        } footer: {
            if row.item?.expiryIsEstimated == true && !expiryEdited {
                SectionFooter(
                    "Estimated from how long it usually keeps. Change it if you know better.")
            }
        }
    }

    private var expiryChoice: PantryStore.ExpiryChoice {
        guard expiryEdited else { return .automatic }
        return hasExpiry ? .date(expiresOn) : .none
    }

    private func run(_ action: @escaping () async -> Bool) {
        isSaving = true
        Task {
            if await action() { dismiss() }
            isSaving = false
        }
    }
}

/// Add an ingredient that is not in the catalog: pick its category and where it's bought.
struct NewIngredientSheet: View {
    let store: PantryStore

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: IngredientCategory = .other
    @State private var buyFrom: BuyFrom = .other
    @State private var isSaving = false

    init(name: String, store: PantryStore) {
        self.store = store
        _name = State(initialValue: name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    SectionHeader("Name")
                }
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(PantryRules.categoryOrder, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    Picker("Bought from", selection: $buyFrom) {
                        ForEach(BuyFrom.allCases, id: \.self) { vendor in
                            Text(vendor.displayName).tag(vendor)
                        }
                    }
                } footer: {
                    SectionFooter(
                        "The category groups your pantry; \"bought from\" groups your shopping list."
                    )
                }
            }
            .onChange(of: category) { oldCategory, newCategory in
                // Follow the category until the user picks a vendor themselves.
                if buyFrom == PantryRules.defaultBuyFrom(for: oldCategory) {
                    buyFrom = PantryRules.defaultBuyFrom(for: newCategory)
                }
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            if await store.createAndAdd(name: name, category: category, buyFrom: buyFrom) {
                dismiss()
            }
            isSaving = false
        }
    }
}
