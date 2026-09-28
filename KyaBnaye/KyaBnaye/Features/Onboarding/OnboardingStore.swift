import Foundation
import KyaCore
import Observation

/// State and actions for first-run onboarding (F1): welcome → staples → fridge → five
/// favourite dishes → done. Each step's choices are saved when the user moves past it, so
/// skipping later keeps what was already set up.
@Observable
@MainActor
final class OnboardingStore {
    /// The onboarding screens, in order.
    enum Step: Int, CaseIterable, Comparable {
        case welcome
        case staples
        case fridge
        case dishes
        case done

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }

        /// 1-based position for the progress indicator, or `nil` on the final screen.
        var progressNumber: Int? { self == .done ? nil : rawValue + 1 }

        /// How many steps the progress indicator counts.
        static let progressCount = 4
    }

    /// Where the catalog is in loading.
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// How many dishes the user is asked to pick.
    static let pickTarget = 5

    /// Perishables pre-listed on the fridge step, most common first.
    static let commonFridgeIds = [
        "onion", "tomato", "potato", "ginger", "garlic", "green_chilli", "coriander_leaves",
        "lemon", "curry_leaves", "spinach", "cauliflower", "cabbage", "capsicum", "carrot",
        "okra", "brinjal", "green_peas", "cucumber", "milk", "curd", "paneer", "butter",
        "eggs", "bread", "banana", "apple",
    ]

    /// Popular everyday dishes offered on the "dishes you love" step.
    static let popularRecipeIds = [
        "aloo_paratha", "poha", "masala_dosa", "idli_sambar", "upma", "rajma_chawal",
        "chole_bhature", "dal_tadka", "palak_paneer", "paneer_butter_masala", "butter_chicken",
        "chicken_biryani", "veg_biryani", "aloo_gobi", "bhindi_masala", "pav_bhaji",
        "dal_makhani", "kadhi_pakora", "egg_curry", "veg_hakka_noodles",
    ]

    /// The current screen.
    private(set) var step: Step = .welcome
    /// The catalog loading phase.
    private(set) var phase: Phase = .loading
    /// Whether a step is being saved.
    private(set) var isSaving = false
    /// A failed save, shown as an alert; the user stays on the step and can retry.
    var saveError: String?

    /// Staple ingredients, all ticked by default.
    private(set) var staples: [Ingredient] = []
    /// Staples the user says are always at home.
    private(set) var tickedStapleIds: Set<String> = []
    /// The fridge step's search text.
    var fridgeQuery = ""
    /// Perishables the user has at home today.
    private(set) var tickedFridgeIds: Set<String> = []
    /// The dishes offered on the last step.
    private(set) var dishChoices: [Recipe] = []
    /// The dishes picked so far (at most ``pickTarget``).
    private(set) var pickedRecipeIds: Set<String> = []

    @ObservationIgnored private var perishables: [Ingredient] = []
    @ObservationIgnored private var normalizer: IngredientNormalizer?
    @ObservationIgnored private var recordedPickIds: Set<String> = []
    @ObservationIgnored private let repositories: RepositorySet
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private let makeId: () -> String

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The ports to read and write through.
    ///   - now: The clock.
    ///   - calendar: The calendar defining "day" for expiry estimates.
    ///   - makeId: New swipe event ids.
    init(
        repositories: RepositorySet,
        now: @escaping () -> Date,
        calendar: @escaping () -> Calendar,
        makeId: @escaping () -> String = { UUID().uuidString }
    ) {
        self.repositories = repositories
        self.now = now
        self.calendar = calendar
        self.makeId = makeId
    }

    /// The perishables to show: the common ones (plus anything ticked) when not searching,
    /// otherwise alias-aware matches ("dahi" → Curd).
    var visibleFridgeItems: [Ingredient] {
        guard let normalizer else { return [] }
        if fridgeQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let common = Self.commonFridgeIds.compactMap(normalizer.ingredient(withId:))
            let extra = perishables.filter {
                tickedFridgeIds.contains($0.id) && !Self.commonFridgeIds.contains($0.id)
            }
            return common + extra
        }
        let perishableIds = Set(perishables.map(\.id))
        return normalizer.suggestions(for: fridgeQuery, limit: 20) { perishableIds.contains($0.id) }
    }

    /// Whether the user may pick another dish.
    var canPickMore: Bool { pickedRecipeIds.count < Self.pickTarget }

    /// Loads staples, perishables and the dish choices.
    func load() async {
        phase = .loading
        do {
            let catalog = try await repositories.ingredients.all()
            let recipes = try await repositories.recipes.all()
            let normalizer = try IngredientNormalizer(catalog)
            self.normalizer = normalizer
            staples = normalizer.all.filter { $0.role == .staple }.sorted(by: Self.byName)
            tickedStapleIds = Set(staples.map(\.id))
            perishables = normalizer.all.filter(Self.isPerishable).sorted(by: Self.byName)
            dishChoices = Self.dishChoices(from: recipes)
            phase = .ready
        } catch {
            phase = .failed(
                String(
                    localized:
                        "Setup couldn't load the kitchen list. (\(String(describing: error)))"))
        }
    }

    /// Ticks or unticks a staple.
    func toggleStaple(_ id: String) {
        tickedStapleIds.formSymmetricDifference([id])
    }

    /// Ticks or unticks a perishable on the fridge step.
    func toggleFridgeItem(_ id: String) {
        tickedFridgeIds.formSymmetricDifference([id])
    }

    /// Ticks or unticks a dish; ignored once ``pickTarget`` dishes are picked.
    func togglePick(_ recipeId: String) {
        if pickedRecipeIds.contains(recipeId) {
            pickedRecipeIds.remove(recipeId)
        } else if canPickMore {
            pickedRecipeIds.insert(recipeId)
        }
    }

    /// Saves the current step's choices, then moves to the next step. Stays put on failure.
    func advance() async {
        guard !isSaving, let next = Step(rawValue: step.rawValue + 1) else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await saveCurrentStep()
            step = next
        } catch {
            saveError = String(localized: "Couldn't save this step. Please try again.")
        }
    }

    /// Goes back one step without saving (choices stay ticked).
    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    // MARK: Private

    private func saveCurrentStep() async throws {
        switch step {
        case .welcome, .done:
            return
        case .staples:
            let items = staples.map { staple in
                tickedStapleIds.contains(staple.id)
                    ? plenty(staple)
                    : PantryItem(ingredientId: staple.id, level: .out, updatedAt: now())
            }
            try await repositories.pantry.setLevels(items)
        case .fridge:
            let ticked = perishables.filter { tickedFridgeIds.contains($0.id) }
            try await repositories.pantry.setLevels(ticked.map(plenty))
        case .dishes:
            try await recordPicks()
        }
    }

    /// Records each new pick as a right swipe in Craving mode (`AGENTS.md` M1 decisions).
    /// Picks already recorded (the user went back and forward) are not recorded twice.
    private func recordPicks() async throws {
        let newPicks = dishChoices.map(\.id).filter {
            pickedRecipeIds.contains($0) && !recordedPickIds.contains($0)
        }
        for recipeId in newPicks {
            try await repositories.swipeEvents.add(
                SwipeEvent(
                    id: makeId(), recipeId: recipeId, action: .right, mode: .craving, at: now(),
                    deckSeed: 0))
            recordedPickIds.insert(recipeId)
        }
    }

    private func plenty(_ ingredient: Ingredient) -> PantryItem {
        PantryItem(ingredientId: ingredient.id, level: .plenty, updatedAt: now())
            .withEstimatedExpiry(shelfLifeDays: ingredient.shelfLifeDays, calendar: calendar())
    }

    /// Popular seed dishes first, topped up with other visible recipes to 20.
    private static func dishChoices(from recipes: [Recipe]) -> [Recipe] {
        let visible = recipes.filter { !$0.isHidden }
        let byId = Dictionary(visible.map { ($0.id, $0) }) { first, _ in first }
        let popular = popularRecipeIds.compactMap { byId[$0] }
        let chosen = Set(popular.map(\.id))
        let others = visible.filter { !chosen.contains($0.id) }.sorted { $0.name < $1.name }
        return Array((popular + others).prefix(popularRecipeIds.count))
    }

    /// Things that go off within a month: what "in the fridge today" means here.
    private static func isPerishable(_ ingredient: Ingredient) -> Bool {
        guard ingredient.role != .staple, let days = ingredient.shelfLifeDays else { return false }
        return days <= 30
    }

    private static func byName(_ lhs: Ingredient, _ rhs: Ingredient) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
