import Foundation

/// JSON mappers for the entities only backups contain (pantry, history,
/// swipes, shopping). Internal to ``BackupCodec``; catalogue entities go
/// through the shared ``EntityJSON``.
///
/// Like the Dart oracle, readers ignore unknown keys and default absent flags
/// to `false`, but reject wrong JSON types. Timestamps are written by
/// ``BackupTimestamp`` and read in the codec's local time zone when they
/// carry no zone.
enum BackupEntityJSON {
    // MARK: PantryItem

    static func json(_ item: PantryItem, at field: String) throws(BackupEncodingError) -> [String:
        Any]
    {
        var expiresOn: Any = NSNull()
        if let date = item.expiresOn {
            expiresOn = try timestamp(date, at: "\(field).expiresOn")
        }
        return [
            "ingredientId": item.ingredientId,
            "level": item.level.rawValue,
            "expiresOn": expiresOn,
            "expiryIsEstimated": item.expiryIsEstimated,
            "updatedAt": try timestamp(item.updatedAt, at: "\(field).updatedAt"),
        ]
    }

    static func pantryItem(
        from value: Any?, timeZone: TimeZone
    ) throws(EntityJSONError) -> PantryItem {
        let fields = try JSONFields(value, entity: "pantryItem")
        let expiresOnText = try fields.optionalString("expiresOn")
        let ingredientId = try fields.string("ingredientId")
        let level: StockLevel = try fields.enumValue("level")
        let expiresOn =
            expiresOnText == nil ? nil : try fields.timestamp("expiresOn", timeZone: timeZone)
        return PantryItem(
            ingredientId: ingredientId,
            level: level,
            updatedAt: try fields.timestamp("updatedAt", timeZone: timeZone),
            expiresOn: expiresOn,
            expiryIsEstimated: try fields.flag("expiryIsEstimated")
        )
    }

    // MARK: MealLog

    static func json(_ log: MealLog, at field: String) throws(BackupEncodingError) -> [String: Any]
    {
        [
            "id": log.id,
            "recipeId": log.recipeId,
            "mealType": log.mealType.rawValue,
            "cookedAt": try timestamp(log.cookedAt, at: "\(field).cookedAt"),
        ]
    }

    static func mealLog(from value: Any?, timeZone: TimeZone) throws(EntityJSONError) -> MealLog {
        let fields = try JSONFields(value, entity: "mealLog")
        return MealLog(
            id: try fields.string("id"),
            recipeId: try fields.string("recipeId"),
            mealType: try fields.enumValue("mealType"),
            cookedAt: try fields.timestamp("cookedAt", timeZone: timeZone)
        )
    }

    // MARK: SwipeEvent

    static func json(_ event: SwipeEvent, at field: String) throws(BackupEncodingError) -> [String:
        Any]
    {
        [
            "id": event.id,
            "recipeId": event.recipeId,
            "action": event.action.rawValue,
            "mode": event.mode.rawValue,
            "at": try timestamp(event.at, at: "\(field).at"),
            "deckSeed": event.deckSeed,
            "undoesEventId": EntityJSON.nullable(event.undoesEventId),
        ]
    }

    static func swipeEvent(
        from value: Any?, timeZone: TimeZone
    ) throws(EntityJSONError) -> SwipeEvent {
        let fields = try JSONFields(value, entity: "swipeEvent")
        return SwipeEvent(
            id: try fields.string("id"),
            recipeId: try fields.string("recipeId"),
            action: try fields.enumValue("action"),
            mode: try fields.enumValue("mode"),
            at: try fields.timestamp("at", timeZone: timeZone),
            deckSeed: try fields.integer("deckSeed"),
            undoesEventId: try fields.optionalString("undoesEventId")
        )
    }

    // MARK: ShoppingItem

    static func json(_ item: ShoppingItem, at field: String) throws(BackupEncodingError) -> [String:
        Any]
    {
        [
            "id": item.id,
            "ingredientId": EntityJSON.nullable(item.ingredientId),
            "customName": EntityJSON.nullable(item.customName),
            "reason": item.reason.rawValue,
            "recipeId": EntityJSON.nullable(item.recipeId),
            "isChecked": item.isChecked,
            "createdAt": try timestamp(item.createdAt, at: "\(field).createdAt"),
        ]
    }

    /// Reads a shopping item. The "ingredient id or custom name" invariant is
    /// checked explicitly, before the remaining fields, like the oracle.
    static func shoppingItem(
        from value: Any?, timeZone: TimeZone
    ) throws(EntityJSONError) -> ShoppingItem {
        let fields = try JSONFields(value, entity: "shoppingItem")
        let ingredientId = try fields.optionalString("ingredientId")
        let customName = try fields.optionalString("customName")
        let missingTarget = EntityJSONError(
            message: "shopping item \(JSONValue.text(fields.map["id"])) has neither an "
                + "ingredientId nor a customName.")
        guard ingredientId != nil || customName != nil else { throw missingTarget }
        let id = try fields.string("id")
        let reason: ShoppingReason = try fields.enumValue("reason")
        let recipeId = try fields.optionalString("recipeId")
        let isChecked = try fields.flag("isChecked")
        let createdAt = try fields.timestamp("createdAt", timeZone: timeZone)
        do {
            return try ShoppingItem(
                id: id, ingredientId: ingredientId, customName: customName, reason: reason,
                recipeId: recipeId, isChecked: isChecked, createdAt: createdAt)
        } catch {
            throw missingTarget
        }
    }

    // MARK: Helpers

    private static func timestamp(
        _ date: Date, at field: String
    ) throws(BackupEncodingError) -> String {
        guard let text = BackupTimestamp.string(from: date) else {
            throw .unrepresentableDate(field: field)
        }
        return text
    }
}

extension JSONFields {
    /// The ISO-8601 timestamp under `key`; a zone-less value is wall-clock
    /// time in `timeZone`.
    func timestamp(_ key: String, timeZone: TimeZone) throws(EntityJSONError) -> Date {
        let text = try string(key)
        guard let date = BackupTimestamp.date(from: text, localTimeZone: timeZone) else {
            throw EntityJSONError(message: "\(entity).\(key): invalid timestamp \"\(text)\"")
        }
        return date
    }
}
