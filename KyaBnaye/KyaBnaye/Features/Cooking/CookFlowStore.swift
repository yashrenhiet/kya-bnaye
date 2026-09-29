import Foundation
import KyaCore
import Observation

/// The "I made this" flow (F5): logs the meal, then asks "Used up anything?" about the
/// recipe's perishables that are in stock, and writes only what the user confirms.
///
/// Reusable from any screen (recipe detail, Home's Today's picks): call ``cook(_:)`` and
/// attach ``SwiftUI/View/cookFlow(_:)`` (or just use ``CookButton``). Principle 4, "suggest,
/// never assume": nothing in the pantry changes unless the user taps Low/Out and confirms.
@Observable
@MainActor
final class CookFlowStore {
    /// Where the flow is.
    enum Phase: Equatable {
        /// Nothing in progress.
        case idle
        /// Writing the meal log.
        case logging
        /// The meal is logged; the "Used up anything?" sheet is showing.
        case askingUsedUp
        /// Writing the confirmed pantry changes.
        case savingLevels
    }

    /// Where the flow is.
    private(set) var phase: Phase = .idle
    /// The recipe being cooked (set by ``cook(_:)``).
    private(set) var recipe: Recipe?
    /// The meal log written by the last ``cook(_:)``.
    private(set) var lastLog: MealLog?
    /// Perishables to ask about, in recipe order.
    private(set) var candidates: [UsedUpCandidate] = []
    /// The user's picks: a new level per ingredient id. Absent means "still have it".
    private(set) var choices: [String: StockLevel] = [:]
    /// A failed step, shown as an alert until dismissed.
    var errorMessage: String?
    /// A short confirmation of the last step, shown briefly and announced to VoiceOver.
    var confirmation: String?

    @ObservationIgnored private let repositories: RepositorySet
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private let makeId: () -> String

    /// Creates the store.
    ///
    /// - Parameters:
    ///   - repositories: The ports to read and write through.
    ///   - now: The clock (stamps the meal log and pantry writes).
    ///   - calendar: Decides the meal slot from the hour.
    ///   - makeId: New meal log ids.
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

    /// Whether the "Used up anything?" sheet should be on screen.
    var isAskingUsedUp: Bool { phase == .askingUsedUp || phase == .savingLevels }

    /// Whether a step is writing, so buttons can be disabled against double taps.
    var isBusy: Bool { phase == .logging || phase == .savingLevels }

    /// Logs `recipe` as cooked now (meal slot from the current hour), then offers the
    /// "Used up anything?" sheet if any of its perishables are in stock. Ignored while
    /// another step is in progress.
    ///
    /// - Parameter recipe: The dish that was made.
    func cook(_ recipe: Recipe) async {
        guard phase == .idle else { return }
        phase = .logging
        self.recipe = recipe
        choices = [:]
        candidates = []
        let cookedAt = now()
        let log = MealLog(
            id: makeId(), recipeId: recipe.id,
            mealType: MealHistory.currentMealType(now: cookedAt, calendar: calendar()),
            cookedAt: cookedAt)
        do {
            try await repositories.mealLogs.add(log)
        } catch {
            phase = .idle
            errorMessage = String(
                localized: "Couldn't save that you made \(recipe.name). Please try again.")
            return
        }
        lastLog = log
        confirmation = String(localized: "\(recipe.name) added to your history")
        do {
            let catalog = try await repositories.ingredients.all()
            let pantry = try await repositories.pantry.all()
            candidates = UsedUpSuggestions.candidates(
                for: recipe,
                ingredientsById: Dictionary(catalog.map { ($0.id, $0) }) { _, last in last },
                pantry: Self.keyed(pantry))
        } catch {
            errorMessage = String(
                localized:
                    "Your meal is saved, but the pantry couldn't be read to ask what was used up.")
        }
        phase = candidates.isEmpty ? .idle : .askingUsedUp
    }

    /// Picks a new level for one candidate; picking the same level again clears it
    /// ("still have it").
    ///
    /// - Parameters:
    ///   - level: ``StockLevel/low`` or ``StockLevel/out``.
    ///   - ingredientId: The candidate's ingredient id.
    func choose(_ level: StockLevel, for ingredientId: String) {
        guard candidates.contains(where: { $0.ingredient.id == ingredientId }) else { return }
        choices[ingredientId] = choices[ingredientId] == level ? nil : level
    }

    /// Writes the picked levels in one batch and closes the sheet. With no picks, nothing is
    /// written. On failure the sheet stays open so the user can retry or skip.
    func confirm() async {
        guard phase == .askingUsedUp else { return }
        phase = .savingLevels
        do {
            let updates = UsedUpSuggestions.updates(
                choices: choices, pantry: Self.keyed(try await repositories.pantry.all()),
                now: now())
            try await repositories.pantry.setLevels(updates)
            if !updates.isEmpty {
                confirmation = String(localized: "Pantry updated")
            }
            finish()
        } catch {
            phase = .askingUsedUp
            errorMessage = String(localized: "Couldn't update your pantry. Please try again.")
        }
    }

    /// Closes the sheet without touching the pantry.
    func skip() {
        guard phase == .askingUsedUp else { return }
        finish()
    }

    private func finish() {
        phase = .idle
        candidates = []
        choices = [:]
        // A confirm failure sets `errorMessage` but leaves the sheet open (`confirm()`); once
        // the user retries successfully, or skips instead, the stale failure must not
        // reappear as an alert once the sheet closes (`CookFlowViews.swift`'s alert binding
        // fires whenever `errorMessage != nil && !isAskingUsedUp`).
        errorMessage = nil
    }

    private static func keyed(_ items: [PantryItem]) -> [String: PantryItem] {
        Dictionary(items.map { ($0.ingredientId, $0) }) { _, last in last }
    }
}
