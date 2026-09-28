import Foundation

/// A household's current stock of one ``Ingredient``.
///
/// One `PantryItem` per ingredient by construction — ``ingredientId`` is the
/// primary key, so a repository must upsert on it, never insert duplicates.
///
/// Equality and hashing are value-based over every field.
public struct PantryItem: Sendable, Hashable, CustomStringConvertible {
    /// The ``Ingredient/id`` this stock record belongs to (primary key).
    public let ingredientId: String

    /// How much is at home.
    public let level: StockLevel

    /// `nil` means "no known expiry" (e.g. staples, or an ingredient with no
    /// ``Ingredient/shelfLifeDays``). Only its calendar date is meaningful.
    public let expiresOn: Date?

    /// True if ``expiresOn`` was estimated from ``Ingredient/shelfLifeDays``
    /// plus ``updatedAt`` rather than entered by the user, so the UI can show an
    /// estimate differently from a confirmed date.
    public let expiryIsEstimated: Bool

    /// When this record was last changed.
    public let updatedAt: Date

    /// Creates a pantry record.
    ///
    /// - Parameters:
    ///   - ingredientId: The ingredient this record belongs to.
    ///   - level: Current stock level.
    ///   - updatedAt: When the record was last changed.
    ///   - expiresOn: Known or estimated expiry; defaults to `nil`.
    ///   - expiryIsEstimated: Whether `expiresOn` is an estimate; defaults to
    ///     `false`.
    public init(
        ingredientId: String,
        level: StockLevel,
        updatedAt: Date,
        expiresOn: Date? = nil,
        expiryIsEstimated: Bool = false
    ) {
        self.ingredientId = ingredientId
        self.level = level
        self.updatedAt = updatedAt
        self.expiresOn = expiresOn
        self.expiryIsEstimated = expiryIsEstimated
    }

    /// Calendar days from `now` until ``expiresOn``, ignoring time of day.
    ///
    /// Negative means already expired; `0` means it expires today. Computed on
    /// calendar dates in `calendar`'s time zone, so it is independent of DST
    /// transitions (never divides seconds by 86 400).
    ///
    /// - Parameters:
    ///   - now: The reference instant.
    ///   - calendar: Calendar (and time zone) defining "day"; defaults to
    ///     ``Foundation/Calendar/kyaDefault``.
    /// - Returns: The day difference, or `nil` when there is no expiry.
    public func daysUntilExpiry(asOf now: Date, calendar: Calendar = .kyaDefault) -> Int? {
        guard let expiresOn else { return nil }
        return calendar.calendarDays(from: now, to: expiresOn)
    }

    /// Whether the item expires within `days` calendar days of `now`
    /// (inclusive). Already-expired items count as expiring; items with no
    /// expiry never do.
    ///
    /// - Parameters:
    ///   - days: Window size in calendar days; `0` means "today or earlier".
    ///   - now: The reference instant.
    ///   - calendar: Calendar (and time zone) defining "day"; defaults to
    ///     ``Foundation/Calendar/kyaDefault``.
    /// - Returns: `true` if ``daysUntilExpiry(asOf:calendar:)`` is non-`nil` and
    ///   `<= days`.
    public func isExpiringWithin(
        _ days: Int,
        asOf now: Date,
        calendar: Calendar = .kyaDefault
    ) -> Bool {
        guard let remaining = daysUntilExpiry(asOf: now, calendar: calendar) else { return false }
        return remaining <= days
    }

    /// Estimates an expiry date as `shelfLifeDays` calendar days after the
    /// calendar date of `updatedAt` (start of that day in `calendar`).
    ///
    /// - Parameters:
    ///   - updatedAt: When the item was bought/restocked.
    ///   - shelfLifeDays: The ingredient's ``Ingredient/shelfLifeDays``.
    ///   - calendar: Calendar (and time zone) defining "day"; defaults to
    ///     ``Foundation/Calendar/kyaDefault``.
    /// - Returns: The estimated expiry, or `nil` when `shelfLifeDays` is `nil`.
    public static func estimatedExpiry(
        updatedAt: Date,
        shelfLifeDays: Int?,
        calendar: Calendar = .kyaDefault
    ) -> Date? {
        guard let shelfLifeDays else { return nil }
        return calendar.date(
            byAdding: .day, value: shelfLifeDays, to: calendar.startOfDay(for: updatedAt))
    }

    /// Returns a copy whose expiry is estimated from `shelfLifeDays` and
    /// ``updatedAt``. With a `nil` shelf life the copy has no expiry and is not
    /// marked as estimated.
    ///
    /// - Parameters:
    ///   - shelfLifeDays: The ingredient's ``Ingredient/shelfLifeDays``.
    ///   - calendar: Calendar (and time zone) defining "day"; defaults to
    ///     ``Foundation/Calendar/kyaDefault``.
    /// - Returns: The modified copy; `self` is unchanged.
    public func withEstimatedExpiry(
        shelfLifeDays: Int?,
        calendar: Calendar = .kyaDefault
    ) -> PantryItem {
        let estimate = Self.estimatedExpiry(
            updatedAt: updatedAt, shelfLifeDays: shelfLifeDays, calendar: calendar)
        return PantryItem(
            ingredientId: ingredientId,
            level: level,
            updatedAt: updatedAt,
            expiresOn: estimate,
            expiryIsEstimated: estimate != nil
        )
    }

    /// Returns a copy with the given non-optional fields replaced; every `nil`
    /// argument keeps the current value. Use ``withExpiresOn(_:)`` to change
    /// (or clear) the optional expiry.
    ///
    /// - Parameters:
    ///   - ingredientId: Replacement id, or `nil` to keep.
    ///   - level: Replacement level, or `nil` to keep.
    ///   - updatedAt: Replacement timestamp, or `nil` to keep.
    ///   - expiryIsEstimated: Replacement flag, or `nil` to keep.
    /// - Returns: The modified copy; `self` is unchanged.
    public func copy(
        ingredientId: String? = nil,
        level: StockLevel? = nil,
        updatedAt: Date? = nil,
        expiryIsEstimated: Bool? = nil
    ) -> PantryItem {
        PantryItem(
            ingredientId: ingredientId ?? self.ingredientId,
            level: level ?? self.level,
            updatedAt: updatedAt ?? self.updatedAt,
            expiresOn: expiresOn,
            expiryIsEstimated: expiryIsEstimated ?? self.expiryIsEstimated
        )
    }

    /// Returns a copy with ``expiresOn`` set to `date`; passing `nil` clears
    /// the expiry. ``expiryIsEstimated`` is left unchanged.
    ///
    /// - Parameter date: The new expiry, or `nil` to clear it.
    /// - Returns: The modified copy; `self` is unchanged.
    public func withExpiresOn(_ date: Date?) -> PantryItem {
        PantryItem(
            ingredientId: ingredientId,
            level: level,
            updatedAt: updatedAt,
            expiresOn: date,
            expiryIsEstimated: expiryIsEstimated
        )
    }

    /// Shows the ingredient id and level, e.g. `"PantryItem(milk: StockLevel.low)"`.
    public var description: String { "PantryItem(\(ingredientId): StockLevel.\(level.rawValue))" }
}
