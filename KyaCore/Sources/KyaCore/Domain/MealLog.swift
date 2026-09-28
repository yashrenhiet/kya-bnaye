import Foundation

/// A record that a recipe was actually cooked — the strongest taste signal,
/// because it is revealed preference, not just intent.
///
/// Equality and hashing are value-based over every field.
public struct MealLog: Sendable, Hashable {
    /// Unique id of this log entry.
    public let id: String

    /// The ``Recipe/id`` that was cooked.
    public let recipeId: String

    /// The meal slot it was cooked for.
    public let mealType: MealType

    /// When it was cooked.
    public let cookedAt: Date

    /// Creates a meal log entry.
    ///
    /// - Parameters:
    ///   - id: Unique id of this entry.
    ///   - recipeId: The recipe that was cooked.
    ///   - mealType: The meal slot.
    ///   - cookedAt: When it was cooked.
    public init(id: String, recipeId: String, mealType: MealType, cookedAt: Date) {
        self.id = id
        self.recipeId = recipeId
        self.mealType = mealType
        self.cookedAt = cookedAt
    }
}
