import Foundation
import KyaCore
import Observation

/// State and actions for Add / Edit recipe: the draft, alias-aware ingredient picking,
/// validation (shown once the user tries to save) and saving through the repositories.
@Observable
@MainActor
final class RecipeEditorStore {
    /// Where the editor is in loading the catalog and recipe book.
    enum Phase: Equatable {
        /// Reading the catalog and recipes.
        case loading
        /// Ready to edit.
        case ready
        /// The catalog could not be read; the sheet offers a retry.
        case failed(String)
    }

    /// The loading phase.
    private(set) var phase: Phase = .loading
    /// The form contents.
    var draft: RecipeDraft
    /// What the user typed in the "Add ingredient" field.
    var ingredientQuery = ""
    /// Whether the user has tried to save, so validation messages are shown.
    private(set) var hasAttemptedSave = false
    /// Whether a save is in flight.
    private(set) var isSaving = false
    /// A failed save, shown as an alert until dismissed.
    var saveError: String?

    /// The recipe being edited, or `nil` when adding a new one.
    let editing: Recipe?
    /// The draft as first opened, to tell whether there are unsaved changes.
    let initialDraft: RecipeDraft

    private var catalogById: [String: Ingredient] = [:]
    private var pendingIngredients: [String: Ingredient] = [:]
    @ObservationIgnored private var normalizer: IngredientNormalizer?
    @ObservationIgnored private var existingRecipes: [Recipe] = []
    @ObservationIgnored private let repositories: RepositorySet

    /// Creates the editor.
    ///
    /// - Parameters:
    ///   - editing: The recipe to edit, or `nil` for a new recipe.
    ///   - repositories: The ports to read and write through.
    init(editing: Recipe?, repositories: RepositorySet) {
        self.editing = editing
        self.repositories = repositories
        let draft = editing.map(RecipeDraft.init(recipe:)) ?? RecipeDraft()
        self.draft = draft
        initialDraft = draft
    }

    // MARK: Derived state

    /// Every issue blocking save, in form order (empty = valid).
    var issues: [RecipeDraftIssue] {
        draft.validate(
            ingredientsById: knownIngredients, existingRecipes: existingRecipes,
            editingId: editing?.id)
    }

    /// The issues to show: none until the first save attempt.
    var visibleIssues: [RecipeDraftIssue] { hasAttemptedSave ? issues : [] }

    /// Alias-aware suggestions for ``ingredientQuery`` ("aloo" → Potato), excluding
    /// ingredients already in the recipe.
    var suggestions: [Ingredient] {
        guard let normalizer else { return [] }
        let used = Set(draft.ingredients.map(\.ingredientId))
        return normalizer.suggestions(for: ingredientQuery, limit: 6) { !used.contains($0.id) }
    }

    /// The trimmed query when it matches no ingredient exactly, so it can be added as a new one.
    var newIngredientName: String? {
        let name = ingredientQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let normalizer, normalizer.find(name) == nil else { return nil }
        return name
    }

    /// The display name of an ingredient id in the draft.
    func ingredientName(_ id: String) -> String {
        knownIngredients[id]?.name ?? id
    }

    // MARK: Loading

    /// Reads the catalog and recipe book once.
    func load() async {
        phase = .loading
        do {
            let catalog = try await repositories.ingredients.all()
            existingRecipes = try await repositories.recipes.all()
            let normalizer = try IngredientNormalizer(catalog)
            self.normalizer = normalizer
            catalogById = Dictionary(normalizer.all.map { ($0.id, $0) }) { _, last in last }
            phase = .ready
        } catch {
            phase = .failed(
                String(
                    localized:
                        "The ingredient list couldn't be loaded. (\(String(describing: error)))"))
        }
    }

    // MARK: Editing

    /// Adds a catalog ingredient as a new required line and clears the search.
    func addIngredient(_ ingredient: Ingredient) {
        guard !draft.ingredients.contains(where: { $0.ingredientId == ingredient.id }) else {
            ingredientQuery = ""
            return
        }
        draft.ingredients.append(RecipeIngredient(ingredientId: ingredient.id, quantityText: ""))
        ingredientQuery = ""
    }

    /// Adds typed text that matched nothing as a new (user) ingredient, created in the
    /// catalog when the recipe is saved. If its id already belongs to a catalog ingredient
    /// ("foo_bar" and an earlier "Foo Bar" both become `user_foo_bar`), that one is used, so
    /// saving never overwrites it.
    func addNewIngredient(named name: String) {
        do {
            let ingredient = try IngredientNormalizer.createUserIngredient(
                name, category: .other, buyFrom: .other)
            if let existing = catalogById[ingredient.id] {
                addIngredient(existing)
                return
            }
            pendingIngredients[ingredient.id] = ingredient
            addIngredient(ingredient)
        } catch {
            saveError = String(localized: "“\(name)” can't be used as an ingredient name.")
        }
    }

    /// Removes ingredient lines.
    func removeIngredients(at offsets: IndexSet) {
        draft.ingredients.remove(atOffsets: offsets)
    }

    /// Replaces one line's quantity text.
    func setQuantity(_ text: String, forLineAt index: Int) {
        guard draft.ingredients.indices.contains(index) else { return }
        let line = draft.ingredients[index]
        draft.ingredients[index] = RecipeIngredient(
            ingredientId: line.ingredientId, quantityText: text, isOptional: line.isOptional)
    }

    /// Sets whether one line is optional (a garnish that never counts as missing).
    func setOptional(_ isOptional: Bool, forLineAt index: Int) {
        guard draft.ingredients.indices.contains(index) else { return }
        let line = draft.ingredients[index]
        draft.ingredients[index] = RecipeIngredient(
            ingredientId: line.ingredientId, quantityText: line.quantityText,
            isOptional: isOptional)
    }

    /// Appends an empty step.
    func addStep() {
        draft.steps.append("")
    }

    /// Removes steps.
    func removeSteps(at offsets: IndexSet) {
        draft.steps.remove(atOffsets: offsets)
    }

    /// Adds or removes a meal slot.
    func toggleMealType(_ meal: MealType) {
        if !draft.mealTypes.insert(meal).inserted { draft.mealTypes.remove(meal) }
    }

    /// Adds or removes a flavour.
    func toggleFlavour(_ flavour: Flavour) {
        if !draft.flavours.insert(flavour).inserted { draft.flavours.remove(flavour) }
    }

    // MARK: Saving

    /// Validates and saves: new user ingredients first, then the recipe (a new recipe gets a
    /// fresh `user_` id; an edit keeps its id, source and current favourite/hidden flags).
    ///
    /// - Returns: A confirmation message, or `nil` if the draft is invalid or saving failed.
    func save() async -> String? {
        hasAttemptedSave = true
        guard issues.isEmpty, !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            let usedIds = Set(draft.ingredients.map(\.ingredientId))
            let newIngredients = pendingIngredients.values.filter { usedIds.contains($0.id) }
            try await repositories.ingredients.upsert(newIngredients.sorted { $0.id < $1.id })
            let recipe = try await recipeToSave()
            try await repositories.recipes.upsert([recipe])
            return editing == nil
                ? String(localized: "\(recipe.name) added to your recipes")
                : String(localized: "\(recipe.name) saved")
        } catch {
            saveError = String(localized: "Couldn't save the recipe. Please try again.")
            return nil
        }
    }

    private func recipeToSave() async throws -> Recipe {
        guard let editing else {
            let id = RecipeDraft.newRecipeId(
                forName: draft.name, existingIds: Set(existingRecipes.map(\.id)))
            return draft.makeRecipe(id: id, source: .user, isFavorite: false, isHidden: false)
        }
        let current = try await repositories.recipes.recipe(withId: editing.id) ?? editing
        return draft.makeRecipe(
            id: editing.id, source: current.source, isFavorite: current.isFavorite,
            isHidden: current.isHidden
        )
        .withImageAsset(current.imageAsset)
    }

    private var knownIngredients: [String: Ingredient] {
        catalogById.merging(pendingIngredients) { existing, _ in existing }
    }
}
