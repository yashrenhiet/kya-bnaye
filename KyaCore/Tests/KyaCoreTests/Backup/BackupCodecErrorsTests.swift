import Foundation
import KyaCore
import Testing

/// A corruption applied to a valid backup document.
typealias BackupCorruption = @Sendable (inout [String: Any]) -> Void

/// Port of `legacy/packages/kya_core/test/backup/backup_codec_errors_test.dart`.
@Suite("BackupCodec errors")
struct BackupCodecErrorsTests {
    static let sections = [
        "ingredients", "pantryItems", "recipes", "mealLogs", "swipeEvents", "shoppingItems",
    ]

    static let requiredFields: [String: [String]] = [
        "ingredients": ["id", "name", "aliases", "category", "role", "buyFrom"],
        "pantryItems": ["ingredientId", "level", "updatedAt"],
        "recipes": [
            "id", "name", "mealTypes", "minutes", "base", "ingredients", "steps", "tags",
            "source",
        ],
        "mealLogs": ["id", "recipeId", "mealType", "cookedAt"],
        "swipeEvents": ["id", "recipeId", "action", "mode", "at", "deckSeed"],
        "shoppingItems": ["id", "reason", "createdAt"],
    ]

    static let unknownEnumValues: [String: BackupCorruption] = [
        "ingredient category": { $0.edit("ingredients", at: 0) { $0["category"] = "meat" } },
        "ingredient role": { $0.edit("ingredients", at: 0) { $0["role"] = "hero" } },
        "ingredient buyFrom": { $0.edit("ingredients", at: 0) { $0["buyFrom"] = "online" } },
        "pantry level": { $0.edit("pantryItems", at: 0) { $0["level"] = "some" } },
        "recipe mealType": { $0.edit("recipes", at: 0) { $0["mealTypes"] = ["brunch"] } },
        "recipe base": { $0.edit("recipes", at: 0) { $0["base"] = "naan" } },
        "recipe source": { $0.edit("recipes", at: 0) { $0["source"] = "web" } },
        "tag region": { editTags(&$0) { $0["region"] = "mars" } },
        "tag dishType": { editTags(&$0) { $0["dishType"] = "soup" } },
        "tag flavour": { editTags(&$0) { $0["flavours"] = ["umami"] } },
        "tag heaviness": { editTags(&$0) { $0["heaviness"] = "huge" } },
        "tag protein": { editTags(&$0) { $0["protein"] = "tofu" } },
        "meal log mealType": { $0.edit("mealLogs", at: 0) { $0["mealType"] = "brunch" } },
        "swipe action": { $0.edit("swipeEvents", at: 0) { $0["action"] = "up" } },
        "swipe mode": { $0.edit("swipeEvents", at: 0) { $0["mode"] = "party" } },
        "shopping reason": { $0.edit("shoppingItems", at: 0) { $0["reason"] = "impulse" } },
        "enum name with wrong case": { $0.edit("pantryItems", at: 0) { $0["level"] = "Plenty" } },
    ]

    static let wrongFieldTypes: [String: BackupCorruption] = [
        "ingredient id as int": { $0.edit("ingredients", at: 0) { $0["id"] = 7 } },
        "ingredient aliases as string": {
            $0.edit("ingredients", at: 0) { $0["aliases"] = "aloo" }
        },
        "ingredient shelfLifeDays as string": {
            $0.edit("ingredients", at: 0) { $0["shelfLifeDays"] = "14" }
        },
        "ingredient shelfLifeDays as double": {
            $0.edit("ingredients", at: 0) { $0["shelfLifeDays"] = 14.0 }
        },
        "ingredient isUserCreated as string": {
            $0.edit("ingredients", at: 0) { $0["isUserCreated"] = "yes" }
        },
        "pantry updatedAt as epoch int": {
            $0.edit("pantryItems", at: 0) { $0["updatedAt"] = 1_790_000_000 }
        },
        "pantry updatedAt unparsable": {
            $0.edit("pantryItems", at: 0) { $0["updatedAt"] = "yesterday" }
        },
        "pantry expiresOn unparsable": {
            $0.edit("pantryItems", at: 0) { $0["expiresOn"] = "31/12/2026" }
        },
        "pantry expiryIsEstimated as int": {
            $0.edit("pantryItems", at: 0) { $0["expiryIsEstimated"] = 1 }
        },
        "recipe minutes as string": { $0.edit("recipes", at: 0) { $0["minutes"] = "35" } },
        "recipe minutes as double": { $0.edit("recipes", at: 0) { $0["minutes"] = 35.5 } },
        "recipe minutes as integral double": { $0.edit("recipes", at: 0) { $0["minutes"] = 35.0 } },
        "recipe minutes as bool": { $0.edit("recipes", at: 0) { $0["minutes"] = true } },
        "recipe mealTypes as string": { $0.edit("recipes", at: 0) { $0["mealTypes"] = "dinner" } },
        "recipe mealTypes entry as int": { $0.edit("recipes", at: 0) { $0["mealTypes"] = [1] } },
        "recipe tags as list": { $0.edit("recipes", at: 0) { $0["tags"] = [Int]() } },
        "recipe ingredients as object": {
            $0.edit("recipes", at: 0) { $0["ingredients"] = [String: Any]() }
        },
        "recipe ingredient entry as string": {
            $0.edit("recipes", at: 0) { $0["ingredients"] = ["paneer"] }
        },
        "recipe imageAsset as bool": { $0.edit("recipes", at: 0) { $0["imageAsset"] = true } },
        "recipe isFavorite as string": { $0.edit("recipes", at: 0) { $0["isFavorite"] = "true" } },
        "recipe isFavorite as int": { $0.edit("recipes", at: 0) { $0["isFavorite"] = 1 } },
        "recipe steps as string": { $0.edit("recipes", at: 0) { $0["steps"] = "Cook it" } },
        "tag flavours as string": { editTags(&$0) { $0["flavours"] = "spicy" } },
        "meal log cookedAt as null": { $0.edit("mealLogs", at: 0) { $0["cookedAt"] = NSNull() } },
        "swipe deckSeed as string": { $0.edit("swipeEvents", at: 0) { $0["deckSeed"] = "42" } },
        "swipe undoesEventId as int": {
            $0.edit("swipeEvents", at: 1) { $0["undoesEventId"] = 1 }
        },
        "shopping isChecked as string": {
            $0.edit("shoppingItems", at: 0) { $0["isChecked"] = "no" }
        },
        "shopping recipeId as int": { $0.edit("shoppingItems", at: 1) { $0["recipeId"] = 3 } },
        "ingredient alias entry that is not a string": {
            $0.edit("ingredients", at: 0) { $0["aliases"] = [1, 2] }
        },
        "recipe step entry that is not a string": {
            $0.edit("recipes", at: 0) { $0["steps"] = [["text": "Cook"]] }
        },
    ]

    private static func editTags(
        _ json: inout [String: Any], _ body: (inout [String: Any]) -> Void
    ) {
        json.edit("recipes", at: 0) { $0.edit("tags", body) }
    }

    private func expectMalformed(
        _ json: [String: Any], containing text: String? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let error = BackupFixtures.decodeError(json)
        let message = error?.message ?? "decoded without error"
        #expect(
            message.hasPrefix("Malformed backup data: "), "\(message)",
            sourceLocation: sourceLocation)
        #expect(
            error?.description.hasPrefix("BackupFormatError: ") == true,
            sourceLocation: sourceLocation)
        if let text {
            #expect(message.contains(text), "\(message)", sourceLocation: sourceLocation)
        }
    }

    private func expectUnsupportedVersion(
        _ json: [String: Any], sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let message = BackupFixtures.decodeError(json)?.message ?? "decoded without error"
        #expect(
            message.hasPrefix("Unsupported backup version: ") && message.contains("up to 2"),
            "\(message)", sourceLocation: sourceLocation)
    }

    @Test("sanity: the unmodified fixture decodes")
    func sanity() throws {
        #expect(BackupFixtures.decodeError(try BackupFixtures.validJSON()) == nil)
    }

    // MARK: schema version

    @Test("a future version is rejected with an update hint")
    func futureVersion() throws {
        var json = try BackupFixtures.validJSON()
        json["version"] = BackupCodec.currentVersion + 1
        let error = BackupFixtures.decodeError(json)
        #expect(error == .unsupportedVersion(found: "3"))
        let message = error?.message ?? ""
        #expect(message.contains("Unsupported backup version: 3"))
        #expect(message.contains("Update the app"))
    }

    @Test("a missing version is rejected")
    func missingVersion() throws {
        var json = try BackupFixtures.validJSON()
        json["version"] = nil
        expectUnsupportedVersion(json)
        #expect(BackupFixtures.decodeError(json) == .unsupportedVersion(found: "null"))
    }

    @Test(
        "non-integer versions are rejected",
        arguments: ["string", "double", "bool", "null", "list"])
    func nonIntegerVersion(kind: String) throws {
        let values: [String: Any] = [
            "string": "1", "double": 1.0, "bool": true, "null": NSNull(), "list": [1],
        ]
        var json = try BackupFixtures.validJSON()
        json["version"] = values[kind]
        expectUnsupportedVersion(json)
        // A Swift text round trip writes 1.0 as `1`; `integralDoubleText` covers it.
        if kind != "double" {
            #expect(BackupFixtures.decodeError(try JSONText.roundTrip(json)) != nil)
        }
    }

    @Test("zero or negative version is rejected", arguments: [0, -1])
    func nonPositiveVersion(version: Int) throws {
        var json = try BackupFixtures.validJSON()
        json["version"] = version
        expectUnsupportedVersion(json)
    }

    @Test("an empty object is rejected on version before anything else")
    func emptyObject() {
        expectUnsupportedVersion([:])
    }

    // MARK: top-level sections

    @Test("a missing section is rejected", arguments: sections)
    func missingSection(section: String) throws {
        var json = try BackupFixtures.validJSON()
        json[section] = nil
        let error = BackupFixtures.decodeError(json)
        #expect(error?.message == "Expected a list, got Null")
        #expect(error == .sectionNotAList(section: section, found: "Null"))
    }

    @Test("a section that is an object is rejected", arguments: sections)
    func objectSection(section: String) throws {
        var json = try BackupFixtures.validJSON()
        json[section] = [String: Any]()
        let message = BackupFixtures.decodeError(json)?.message ?? ""
        #expect(message.hasPrefix("Expected a list, got "))
    }

    @Test("a section containing a non-object entry is rejected", arguments: sections)
    func nonObjectEntry(section: String) throws {
        var json = try BackupFixtures.validJSON()
        json.append("not an object", to: section)
        expectMalformed(json, containing: "\(section)[")
    }

    // MARK: missing required fields

    @Test("a missing required field is rejected", arguments: sections)
    func missingRequiredField(section: String) throws {
        for field in try #require(Self.requiredFields[section]) {
            var json = try BackupFixtures.validJSON()
            json.edit(section, at: 0) { $0[field] = nil }
            expectMalformed(json, containing: field)
        }
    }

    @Test("missing recipe tag fields are rejected")
    func missingTagFields() throws {
        for field in ["region", "dishType", "flavours", "heaviness", "protein"] {
            var json = try BackupFixtures.validJSON()
            Self.editTags(&json) { $0[field] = nil }
            expectMalformed(json, containing: "tags.\(field)")
        }
    }

    @Test("missing recipe ingredient fields are rejected")
    func missingRecipeIngredientFields() throws {
        for field in ["ingredientId", "quantityText"] {
            var json = try BackupFixtures.validJSON()
            json.edit("recipes", at: 0) { $0.edit("ingredients", at: 0) { $0[field] = nil } }
            expectMalformed(json, containing: field)
        }
    }

    @Test("a shopping item with neither ingredientId nor customName")
    func shoppingItemWithoutTarget() throws {
        var json = try BackupFixtures.validJSON()
        json.edit("shoppingItems", at: 0) { $0["ingredientId"] = nil }
        expectMalformed(json)
    }

    @Test("a shopping item whose targets are both null is rejected explicitly")
    func shoppingItemNullTargets() throws {
        var json = try BackupFixtures.validJSON()
        json.edit("shoppingItems", at: 0) { item in
            item["ingredientId"] = NSNull()
            item["customName"] = NSNull()
        }
        expectMalformed(
            json, containing: "shopping item s1 has neither an ingredientId nor a customName")
    }

    // MARK: values

    @Test("unknown enum values are rejected", arguments: unknownEnumValues.keys.sorted())
    func unknownEnumValue(name: String) throws {
        var json = try BackupFixtures.validJSON()
        let corrupt = try #require(Self.unknownEnumValues[name])
        corrupt(&json)
        expectMalformed(json, containing: "unknown value")
    }

    @Test("wrong field types are rejected", arguments: wrongFieldTypes.keys.sorted())
    func wrongFieldType(name: String) throws {
        var json = try BackupFixtures.validJSON()
        let corrupt = try #require(Self.wrongFieldTypes[name])
        corrupt(&json)
        expectMalformed(json)
    }

    @Test("wrong types are also rejected after a real JSON text round trip")
    func wrongTypesThroughText() throws {
        // JSONSerialization writes an integral double as `14`, so those cases
        // cannot survive a Swift text round trip; `integralDoubleText` covers them.
        for (name, corrupt) in Self.wrongFieldTypes where !name.contains("double") {
            var json = try BackupFixtures.validJSON()
            corrupt(&json)
            let data = try JSONSerialization.data(withJSONObject: json)
            #expect(throws: BackupFormatError.self, "\(name)") {
                try BackupCodec().decode(data)
            }
        }
    }

    @Test(
        "integral doubles in real JSON text (`1.0`, `35.0`) are not integers",
        arguments: ["version", "minutes", "shelfLifeDays"])
    func integralDoubleText(field: String) throws {
        let sentinel = 987_654_321
        var json = try BackupFixtures.validJSON()
        switch field {
        case "version": json["version"] = sentinel
        case "minutes": json.edit("recipes", at: 0) { $0["minutes"] = sentinel }
        default: json.edit("ingredients", at: 0) { $0["shelfLifeDays"] = sentinel }
        }
        let text = try #require(
            String(data: try JSONSerialization.data(withJSONObject: json), encoding: .utf8))
        let replacement = field == "version" ? "1.0" : "35.0"
        let corrupted = text.replacingOccurrences(of: "\(sentinel)", with: replacement)
        #expect(throws: BackupFormatError.self) {
            try BackupCodec().decode(JSONText.data(corrupted))
        }
    }

    @Test("entity errors name the section, index and field")
    func errorLocation() throws {
        var json = try BackupFixtures.validJSON()
        json.edit("recipes", at: 1) { $0["minutes"] = 35.0 }
        #expect(
            BackupFixtures.decodeError(json)
                == .malformed(
                    detail: "recipes[1]: recipe.minutes: expected an integer, got a number (35.0)"))
    }

    // MARK: not a backup document

    @Test("invalid JSON bytes are rejected, never a crash")
    func invalidJSON() {
        #expect(throws: BackupFormatError.notAJSONObject(detail: "the file is not valid JSON")) {
            try BackupCodec().decode(JSONText.data(#"{"version": 1,"#))
        }
    }

    @Test("a JSON array document is not a backup")
    func arrayDocument() {
        #expect(
            throws: BackupFormatError.notAJSONObject(detail: "expected an object, got an array")
        ) {
            try BackupCodec().decode(JSONText.data("[1, 2, 3]"))
        }
        let message = BackupFormatError.notAJSONObject(detail: "x").message
        #expect(message == "Not a backup file: x")
    }
}
