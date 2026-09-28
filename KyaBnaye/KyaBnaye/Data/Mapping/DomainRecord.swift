import Foundation
import KyaCore
import SwiftData

/// A SwiftData model that stores exactly one `KyaCore` value (its ``Row``), keyed on a
/// string id. The adapters are written once against this protocol, so every table gets
/// the same upsert, insert-missing and replace semantics.
protocol DomainRecord: PersistentModel {
    /// The `KyaCore` value this model stores.
    associatedtype Row: Sendable

    /// Entity name used in ``DataStoreError/recordMappingFailed(entity:id:field:)``.
    static var entityName: String { get }

    /// The primary key of `row` (its id, or ingredient id for the pantry).
    static func rowKey(of row: Row) -> String

    /// The primary key of this record.
    var rowKey: String { get }

    /// Creates an empty record for `rowKey`; call ``update(from:)`` before saving.
    init(rowKey: String)

    /// Overwrites every stored field with `row` (keeping the key and any storage-only
    /// fields such as a list position).
    ///
    /// - Throws: ``DataStoreError/recordMappingFailed(entity:id:field:)`` if a field
    ///   cannot be encoded; the record may then be partially updated, so the caller must
    ///   roll the context back.
    func update(from row: Row) throws(DataStoreError)

    /// Maps the stored fields back to the `KyaCore` value.
    ///
    /// - Throws: ``DataStoreError/recordMappingFailed(entity:id:field:)`` if a stored
    ///   value is not valid for this build.
    func toRow() throws(DataStoreError) -> Row
}

extension DomainRecord {
    /// The error for an unmappable `field` of this record.
    func mappingFailure(_ field: String) -> DataStoreError {
        .recordMappingFailed(entity: Self.entityName, id: rowKey, field: field)
    }

    /// Decodes a stored enum raw value.
    ///
    /// - Throws: ``DataStoreError/recordMappingFailed(entity:id:field:)`` for an unknown
    ///   raw value.
    func decode<Value: RawRepresentable>(
        _ raw: String, field: String
    ) throws(DataStoreError) -> Value where Value.RawValue == String {
        guard let value = Value(rawValue: raw) else { throw mappingFailure(field) }
        return value
    }

    /// Decodes stored enum raw values into a set.
    ///
    /// - Throws: ``DataStoreError/recordMappingFailed(entity:id:field:)`` if any raw
    ///   value is unknown.
    func decodeSet<Value: RawRepresentable & Hashable>(
        _ raws: [String], field: String
    ) throws(DataStoreError) -> Set<Value> where Value.RawValue == String {
        var values = Set<Value>()
        for raw in raws {
            let value: Value = try decode(raw, field: field)
            values.insert(value)
        }
        return values
    }
}

/// Stores a set of enum values deterministically (sorted raw values), so identical sets
/// always produce identical rows.
func sortedRawValues<Value: RawRepresentable>(_ values: Set<Value>) -> [String]
where Value.RawValue == String {
    values.map(\.rawValue).sorted()
}

extension IngredientRecord: DomainRecord {
    static let entityName = "Ingredient"

    static func rowKey(of row: Ingredient) -> String { row.id }

    var rowKey: String { id }

    convenience init(rowKey: String) {
        self.init(id: rowKey)
    }

    func update(from row: Ingredient) {
        name = row.name
        aliases = row.aliases
        categoryRaw = row.category.rawValue
        roleRaw = row.role.rawValue
        buyFromRaw = row.buyFrom.rawValue
        shelfLifeDays = row.shelfLifeDays
        isUserCreated = row.isUserCreated
    }

    func toRow() throws(DataStoreError) -> Ingredient {
        Ingredient(
            id: id, name: name, aliases: aliases,
            category: try decode(categoryRaw, field: "category"),
            role: try decode(roleRaw, field: "role"),
            buyFrom: try decode(buyFromRaw, field: "buyFrom"),
            shelfLifeDays: shelfLifeDays, isUserCreated: isUserCreated)
    }
}

extension PantryRecord: DomainRecord {
    static let entityName = "PantryItem"

    static func rowKey(of row: PantryItem) -> String { row.ingredientId }

    var rowKey: String { ingredientId }

    convenience init(rowKey: String) {
        self.init(ingredientId: rowKey)
    }

    func update(from row: PantryItem) {
        levelRaw = row.level.rawValue
        expiresOn = row.expiresOn
        expiryIsEstimated = row.expiryIsEstimated
        updatedAt = row.updatedAt
    }

    func toRow() throws(DataStoreError) -> PantryItem {
        PantryItem(
            ingredientId: ingredientId, level: try decode(levelRaw, field: "level"),
            updatedAt: updatedAt, expiresOn: expiresOn, expiryIsEstimated: expiryIsEstimated)
    }
}

extension MealLogRecord: DomainRecord {
    static let entityName = "MealLog"

    static func rowKey(of row: MealLog) -> String { row.id }

    var rowKey: String { id }

    convenience init(rowKey: String) {
        self.init(id: rowKey)
    }

    func update(from row: MealLog) {
        recipeId = row.recipeId
        mealTypeRaw = row.mealType.rawValue
        cookedAt = row.cookedAt
    }

    func toRow() throws(DataStoreError) -> MealLog {
        MealLog(
            id: id, recipeId: recipeId, mealType: try decode(mealTypeRaw, field: "mealType"),
            cookedAt: cookedAt)
    }
}

extension SwipeEventRecord: DomainRecord {
    static let entityName = "SwipeEvent"

    static func rowKey(of row: SwipeEvent) -> String { row.id }

    var rowKey: String { id }

    convenience init(rowKey: String) {
        self.init(id: rowKey)
    }

    func update(from row: SwipeEvent) {
        recipeId = row.recipeId
        actionRaw = row.action.rawValue
        modeRaw = row.mode.rawValue
        at = row.at
        deckSeed = row.deckSeed
        undoesEventId = row.undoesEventId
    }

    func toRow() throws(DataStoreError) -> SwipeEvent {
        SwipeEvent(
            id: id, recipeId: recipeId, action: try decode(actionRaw, field: "action"),
            mode: try decode(modeRaw, field: "mode"), at: at, deckSeed: deckSeed,
            undoesEventId: undoesEventId)
    }
}

extension ShoppingItemRecord: DomainRecord {
    static let entityName = "ShoppingItem"

    static func rowKey(of row: ShoppingItem) -> String { row.id }

    var rowKey: String { id }

    /// Creates a record at position 0; the shopping adapter assigns the real position.
    convenience init(rowKey: String) {
        self.init(id: rowKey, position: 0)
    }

    func update(from row: ShoppingItem) {
        ingredientId = row.ingredientId
        customName = row.customName
        reasonRaw = row.reason.rawValue
        recipeId = row.recipeId
        isChecked = row.isChecked
        createdAt = row.createdAt
    }

    func toRow() throws(DataStoreError) -> ShoppingItem {
        let reason: ShoppingReason = try decode(reasonRaw, field: "reason")
        do {
            return try ShoppingItem(
                id: id, ingredientId: ingredientId, customName: customName, reason: reason,
                recipeId: recipeId, isChecked: isChecked, createdAt: createdAt)
        } catch {
            throw mappingFailure("ingredientId/customName")
        }
    }
}
