import KyaCore
import SwiftUI

/// Ingredient lines (quantity + optional flag, swipe to delete) and the alias-aware
/// "Add ingredient" field with suggestions.
struct RecipeEditorIngredientsSection: View {
    @Bindable var store: RecipeEditorStore

    var body: some View {
        Section {
            ForEach(Array(store.draft.ingredients.enumerated()), id: \.element.ingredientId) {
                index, line in
                RecipeEditorIngredientRow(
                    name: store.ingredientName(line.ingredientId),
                    quantity: Binding(
                        get: { line.quantityText },
                        set: { store.setQuantity($0, forLineAt: index) }),
                    isOptional: Binding(
                        get: { line.isOptional },
                        set: { store.setOptional($0, forLineAt: index) }))
            }
            .onDelete { store.removeIngredients(at: $0) }
            TextField("Add ingredient… (aloo, dahi)", text: $store.ingredientQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(minHeight: Metrics.minimumTapTarget)
                .accessibilityLabel("Add ingredient")
                .accessibilityIdentifier("editor.ingredientSearch")
            ForEach(store.suggestions, id: \.id) { ingredient in
                Button {
                    store.addIngredient(ingredient)
                } label: {
                    Label(ingredient.name, systemImage: "plus.circle")
                        .frame(
                            maxWidth: .infinity, minHeight: Metrics.minimumTapTarget,
                            alignment: .leading)
                }
                .accessibilityLabel("Add \(ingredient.name)")
                .accessibilityIdentifier("editor.suggestion.\(ingredient.id)")
            }
            if let name = store.newIngredientName {
                Button {
                    store.addNewIngredient(named: name)
                } label: {
                    Label("Add “\(name)” as a new ingredient", systemImage: "plus.square.dashed")
                        .frame(
                            maxWidth: .infinity, minHeight: Metrics.minimumTapTarget,
                            alignment: .leading)
                }
            }
        } header: {
            SectionHeader("Ingredients")
        } footer: {
            SectionFooter("Mark garnishes as optional so they never count as missing.")
        }
    }
}

/// One ingredient line: name, quantity text and the optional toggle.
private struct RecipeEditorIngredientRow: View {
    let name: String
    @Binding var quantity: String
    @Binding var isOptional: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(name)
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(ThemeColor.textPrimary.color)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.medium) {
                    quantityField
                    optionalToggle.fixedSize()
                }
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    quantityField
                    optionalToggle
                }
            }
        }
        .padding(.vertical, Spacing.xSmall)
    }

    private var quantityField: some View {
        TextField("Quantity, e.g. 2 katori", text: $quantity)
            .font(Typography.body)
            .frame(minWidth: Metrics.minimumTapTarget * 3, minHeight: Metrics.minimumTapTarget)
            .accessibilityLabel("Quantity of \(name)")
    }

    private var optionalToggle: some View {
        Toggle("Optional", isOn: $isOptional)
            .font(Typography.supporting)
            .frame(minHeight: Metrics.minimumTapTarget)
            .accessibilityLabel("\(name) is optional")
    }
}

/// Steps: multi-line text fields (swipe to delete) and "Add step".
struct RecipeEditorStepsSection: View {
    @Bindable var store: RecipeEditorStore

    var body: some View {
        Section {
            ForEach(store.draft.steps.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Text("\(index + 1).")
                        .font(Typography.body.weight(.bold))
                        .foregroundStyle(ThemeColor.accent.color)
                        .accessibilityHidden(true)
                    TextField("Describe this step", text: stepBinding(index), axis: .vertical)
                        .font(Typography.body)
                        .lineLimit(1...6)
                        .frame(minHeight: Metrics.minimumTapTarget)
                        .accessibilityLabel("Step \(index + 1)")
                        .accessibilityIdentifier("editor.step.\(index)")
                }
            }
            .onDelete { store.removeSteps(at: $0) }
            Button {
                store.addStep()
            } label: {
                Label("Add step", systemImage: "plus")
                    .frame(minHeight: Metrics.minimumTapTarget)
            }
        } header: {
            SectionHeader("Steps")
        }
    }

    private func stepBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { store.draft.steps.indices.contains(index) ? store.draft.steps[index] : "" },
            set: { value in
                guard store.draft.steps.indices.contains(index) else { return }
                store.draft.steps[index] = value
            })
    }
}

/// Base and the closed-enum tags (region, dish type, flavours, heaviness, protein).
struct RecipeEditorTagsSection: View {
    @Binding var draft: RecipeDraft
    let toggleFlavour: (Flavour) -> Void

    var body: some View {
        Section {
            Picker("Base", selection: $draft.base) {
                ForEach(DishBase.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Dish type", selection: $draft.dishType) {
                ForEach(DishType.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Region", selection: $draft.region) {
                ForEach(Region.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Heaviness", selection: $draft.heaviness) {
                ForEach(Heaviness.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Protein", selection: $draft.protein) {
                ForEach(Protein.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Flavours")
                    .font(Typography.body)
                FlowLayout {
                    ForEach(Flavour.allCases, id: \.self) { flavour in
                        SelectableChip(
                            title: flavour.displayName, symbolName: "circle",
                            isOn: draft.flavours.contains(flavour)
                        ) {
                            toggleFlavour(flavour)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.xSmall)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Flavours")
        } header: {
            SectionHeader("Tags")
        } footer: {
            SectionFooter("Tags help the deck learn what you like.")
        }
    }
}
