import Foundation
import KyaCore
import Testing

/// Port of `legacy/packages/kya_core/test/backup/backup_codec_round_trip_test.dart`.
@Suite("BackupCodec round trip")
struct BackupCodecRoundTripTests {
    let codec = BackupCodec()

    /// Encodes to file bytes and decodes them — the exact path a file
    /// export/import takes.
    private func viaFile(_ bundle: BackupBundle) throws -> BackupBundle {
        try codec.decode(try codec.encode(bundle, exportedAt: try BackupFixtures.exportedAt()))
    }

    private func encoded() throws -> [String: Any] {
        try BackupFixtures.validJSON(codec)
    }

    // MARK: encode

    @Test("writes the current schema version and exportedAt")
    func versionAndExportedAt() throws {
        let json = try encoded()
        #expect(BackupCodec.currentVersion == 2)
        #expect(json["version"] as? Int == BackupCodec.currentVersion)
        #expect(json["exportedAt"] as? String == "2026-09-26T12:00:00.000Z")
    }

    @Test("writes a local exportedAt as the same instant in UTC (Dart wrote it zone-less)")
    func localExportedAt() throws {
        let kolkata = try TestDates.calendar(zone: "Asia/Kolkata")
        let exportedAt = try TestDates.local(2026, 9, 26, 12, calendar: kolkata)
        let json = try JSONText.object(
            try codec.encode(try BackupFixtures.fullBundle(), exportedAt: exportedAt))
        #expect(json["exportedAt"] as? String == "2026-09-26T06:30:00.000Z")
    }

    @Test("writes one top-level list per entity type")
    func sections() throws {
        let json = try encoded()
        #expect(
            Set(json.keys) == [
                "version", "exportedAt", "seedVersion", "ingredients", "pantryItems", "recipes",
                "mealLogs", "swipeEvents", "shoppingItems",
            ])
        let counts = [
            "ingredients": 3, "pantryItems": 3, "recipes": 2, "mealLogs": 2, "swipeEvents": 4,
            "shoppingItems": 4,
        ]
        for (key, count) in counts {
            #expect((json[key] as? [Any])?.count == count, "\(key)")
        }
    }

    @Test("stores enums by name and dates as ISO-8601 strings")
    func swipeEventShape() throws {
        let swipe = try encoded().object("swipeEvents", at: 1)
        let expected: [String: Any] = [
            "id": "e2", "recipeId": "palak_paneer", "action": "undo", "mode": "craving",
            "at": "2026-03-01T04:05:06.789012Z", "deckSeed": -7, "undoesEventId": "e1",
        ]
        #expect(NSDictionary(dictionary: swipe).isEqual(to: expected))
    }

    @Test("writes every field of every entity, with null for nil optionals")
    func entityShapes() throws {
        let json = try encoded()
        let recipe = try json.object("recipes", at: 1)
        #expect(recipe["imageAsset"] is NSNull)
        #expect(recipe["mealTypes"] as? [String] == [])
        #expect(try json.object("recipes")["mealTypes"] as? [String] == ["lunch", "dinner"])
        let tags = try #require(try json.object("recipes")["tags"] as? [String: Any])
        #expect(tags["flavours"] as? [String] == ["savoury", "mild"])
        #expect(try json.object("ingredients", at: 1)["shelfLifeDays"] is NSNull)
        #expect(try json.object("ingredients", at: 2)["isUserCreated"] as? Bool == true)
        #expect(try json.object("pantryItems", at: 1)["expiresOn"] is NSNull)
        #expect(try json.object("shoppingItems", at: 2)["ingredientId"] is NSNull)
        #expect(
            try json.object("mealLogs", at: 1)["cookedAt"] as? String
                == "2026-03-01T04:05:06.789012Z")
    }

    @Test("output is deterministic, with sorted keys and unescaped slashes")
    func deterministic() throws {
        let bundle = try BackupFixtures.fullBundle()
        let exportedAt = try BackupFixtures.exportedAt()
        let first = try codec.encode(bundle, exportedAt: exportedAt)
        #expect(first == (try codec.encode(bundle, exportedAt: exportedAt)))
        let text = try #require(String(data: first, encoding: .utf8))
        #expect(
            text.hasPrefix(#"{"exportedAt":"2026-09-26T12:00:00.000Z","ingredients":[{"aliases""#))
        #expect(text.contains(#""imageAsset":"assets/recipes/palak_paneer.webp""#))
    }

    @Test("writes the seed version, or null when unknown")
    func seedVersionField() throws {
        #expect(try encoded()["seedVersion"] as? Int == 4)
        let json = try JSONText.object(
            try codec.encode(BackupBundle(), exportedAt: try BackupFixtures.exportedAt()))
        #expect(json["seedVersion"] is NSNull)
    }

    @Test("empty bundle encodes to empty lists")
    func emptyBundle() throws {
        let json = try JSONText.object(
            try codec.encode(BackupBundle(), exportedAt: try BackupFixtures.exportedAt()))
        for key in ["ingredients", "recipes", "shoppingItems"] {
            #expect((json[key] as? [Any])?.isEmpty == true, "\(key)")
        }
    }

    // MARK: round trip

    @Test("restores every entity and field from the parsed document")
    func fromObject() throws {
        let bundle = try BackupFixtures.fullBundle()
        BackupFixtures.expectEqual(try codec.decode(jsonObject: try encoded()), bundle)
    }

    @Test("restores every entity and field through file bytes")
    func throughBytes() throws {
        let bundle = try BackupFixtures.fullBundle()
        BackupFixtures.expectEqual(try viaFile(bundle), bundle)
    }

    @Test("round-trips an empty bundle")
    func emptyRoundTrip() throws {
        BackupFixtures.expectEqual(try viaFile(BackupBundle()), BackupBundle())
    }

    @Test("user-created ingredients keep isUserCreated")
    func userIngredients() throws {
        let decoded = try viaFile(try BackupFixtures.fullBundle())
        let user = try #require(decoded.ingredients.first { $0.id == "user_dragonfruit" })
        #expect(user.isUserCreated)
        #expect(decoded.ingredients.count(where: \.isUserCreated) == 1)
    }

    @Test("undo events keep undoesEventId; others keep nil")
    func undoEvents() throws {
        let events = try viaFile(try BackupFixtures.fullBundle()).swipeEvents
        #expect(events.map(\.undoesEventId) == [nil, "e1", nil, nil])
        #expect(events[1].action == .undo)
    }

    @Test("recipe sets and nullable fields survive")
    func recipeFields() throws {
        let recipes = try viaFile(try BackupFixtures.fullBundle()).recipes
        #expect(recipes[0].mealTypes == [.lunch, .dinner])
        #expect(recipes[0].tags.flavours == [.savoury, .mild])
        #expect(recipes[0].imageAsset != nil)
        #expect(recipes[0].requiredIngredients.count == 1)
        #expect(recipes[1].mealTypes.isEmpty)
        #expect(recipes[1].tags.flavours.isEmpty)
        #expect(recipes[1].imageAsset == nil)
    }

    @Test("shopping items keep nil and non-nil optional fields")
    func shoppingFields() throws {
        let items = try viaFile(try BackupFixtures.fullBundle()).shoppingItems
        #expect(items.map(\.ingredientId) == ["potato", "paneer", nil, "salt"])
        #expect(items.map(\.customName) == [nil, nil, "Birthday candles", nil])
        #expect(items.map(\.recipeId) == [nil, "palak_paneer", nil, nil])
    }

    // MARK: dates

    @Test("UTC instants survive with microsecond precision")
    func utcInstants() throws {
        let log = try viaFile(try BackupFixtures.fullBundle()).mealLogs[1]
        #expect(log.cookedAt == (try BackupFixtures.utcTime()))
        let micros = Int((log.cookedAt.timeIntervalSince1970 * 1_000_000).rounded())
        #expect(micros % 1_000_000 == 789_012)
    }

    @Test("local wall-clock instants survive with the same wall-clock value")
    func localInstants() throws {
        let log = try viaFile(try BackupFixtures.fullBundle()).mealLogs[0]
        #expect(log.cookedAt == (try BackupFixtures.localTime()))
        let parts = Calendar.kyaDefault.dateComponents(
            [.hour, .minute, .second, .nanosecond], from: log.cookedAt)
        #expect([parts.hour, parts.minute, parts.second] == [19, 30, 15])
        let micros = Int((Double(parts.nanosecond ?? 0) / 1000).rounded())
        #expect(micros == 123_456)
    }

    @Test("nullable expiresOn round-trips as nil and non-nil")
    func expiresOn() throws {
        let pantry = try viaFile(try BackupFixtures.fullBundle()).pantryItems
        #expect(pantry[0].expiresOn == (try TestDates.local(2026, 10, 10)))
        #expect(pantry[1].expiresOn == nil)
        #expect(pantry[2].expiresOn == (try BackupFixtures.utcTime()))
    }

    @Test("offset timestamps written by other tools decode to the right instant")
    func offsetTimestamps() throws {
        var json = try encoded()
        json.edit("mealLogs", at: 0) { $0["cookedAt"] = "2026-09-26T19:30:00+05:30" }
        let cookedAt = try codec.decode(jsonObject: json).mealLogs[0].cookedAt
        #expect(cookedAt == (try TestDates.utc(2026, 9, 26, 14)))
    }

    // MARK: lenient decoding

    @Test("absent boolean flags default to false")
    func absentFlags() throws {
        var json = try encoded()
        json.edit("ingredients", at: 0) { $0["isUserCreated"] = nil }
        json.edit("pantryItems", at: 0) { $0["expiryIsEstimated"] = nil }
        json.edit("recipes", at: 0) { recipe in
            recipe["isFavorite"] = nil
            recipe["isHidden"] = nil
            recipe.edit("ingredients", at: 0) { $0["isOptional"] = nil }
        }
        json.edit("shoppingItems", at: 0) { $0["isChecked"] = nil }

        let decoded = try codec.decode(jsonObject: json)
        #expect(!decoded.ingredients[0].isUserCreated)
        #expect(!decoded.pantryItems[0].expiryIsEstimated)
        #expect(!decoded.recipes[0].isFavorite)
        #expect(!decoded.recipes[0].isHidden)
        #expect(!decoded.recipes[0].ingredients[0].isOptional)
        #expect(!decoded.shoppingItems[0].isChecked)
    }

    @Test("unknown extra keys are ignored")
    func unknownKeys() throws {
        var json = try encoded()
        json["futureTopLevel"] = ["a": 1]
        json.edit("recipes", at: 0) { $0["futureField"] = "x" }
        BackupFixtures.expectEqual(
            try codec.decode(jsonObject: json), try BackupFixtures.fullBundle())
    }
}
