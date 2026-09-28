import Foundation
import KyaCore
import Testing

/// Port of `legacy/packages/kya_core/test/seed/seed_codec_rows_test.dart`.
@Suite("SeedCodec rejects malformed rows")
struct SeedCodecRowsTests {
    typealias F = SeedFixtures

    static let forbiddenKeys = ["isUserCreated", "source", "isFavorite", "isHidden"]

    private func expectError(
        _ fragments: [String: Any], at location: String, _ message: (String) -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let error = F.fragmentsError(fragments)
        #expect(
            error?.location == location, "\(String(describing: error))",
            sourceLocation: sourceLocation)
        #expect(
            message(error?.message ?? ""), "\(String(describing: error))",
            sourceLocation: sourceLocation)
    }

    private func expectError(
        _ fragments: [String: Any], at location: String, _ message: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            F.fragmentsError(fragments) == SeedFormatError(location: location, message: message),
            sourceLocation: sourceLocation)
    }

    private static func editTags(
        _ row: inout [String: Any], _ body: (inout [String: Any]) -> Void
    ) {
        row.edit("tags", body)
    }

    // MARK: forbidden and unknown keys

    @Test("app-owned keys are forbidden on an ingredient", arguments: forbiddenKeys)
    func forbiddenOnIngredient(key: String) {
        expectError(
            F.withIngredientRow { $0[key] = false }, at: "\(F.potatoAt).\(key)",
            "key \"\(key)\" is not allowed in seed data (the app sets it)")
    }

    @Test("app-owned keys are forbidden on a recipe", arguments: forbiddenKeys)
    func forbiddenOnRecipe(key: String) {
        expectError(F.withRecipeRow { $0[key] = false }, at: "\(F.recipeAt).\(key)") {
            $0.contains("not allowed")
        }
    }

    @Test("forbidden keys are reported before unknown ones, deterministically")
    func forbiddenBeforeUnknown() {
        let fragments = F.withIngredientRow { row in
            row["aaa"] = 1
            row["source"] = "seed"
            row["isUserCreated"] = false
        }
        for _ in 0..<5 {
            expectError(fragments, at: "\(F.potatoAt).isUserCreated") { $0.contains("not allowed") }
        }
        let unknown = F.withIngredientRow { row in
            row["zeta"] = 1
            row["alpha"] = 1
        }
        expectError(unknown, at: "\(F.potatoAt).alpha") { $0.hasPrefix("unknown key \"alpha\"") }
    }

    @Test("rejects an unknown ingredient key, listing the allowed ones")
    func unknownIngredientKey() {
        expectError(
            F.withIngredientRow { $0["shelfLife"] = 3 }, at: "\(F.potatoAt).shelfLife",
            "unknown key \"shelfLife\" (allowed: id, name, aliases, category, role, buyFrom, "
                + "shelfLifeDays)")
    }

    @Test("rejects unknown keys in tags and recipe ingredient lines")
    func unknownNestedKeys() {
        expectError(
            F.withRecipeRow { Self.editTags(&$0) { $0["diet"] = 1 } },
            at: "\(F.recipeAt).tags.diet"
        ) { $0.hasPrefix("unknown key \"diet\"") }
        expectError(
            F.withRecipeRow { $0.edit("ingredients", at: 0) { $0["qty"] = "1" } },
            at: "\(F.recipeAt).ingredients[0].qty",
            "unknown key \"qty\" (allowed: ingredientId, quantityText, isOptional)")
    }

    @Test("rejects a missing required key")
    func missingRequiredKey() {
        expectError(
            F.withIngredientRow { $0["aliases"] = nil }, at: F.potatoAt,
            "missing required key \"aliases\"")
        expectError(
            F.withRecipeRow { $0["steps"] = nil }, at: F.recipeAt, "missing required key \"steps\"")
        expectError(
            F.withRecipeRow { Self.editTags(&$0) { $0["protein"] = nil } },
            at: "\(F.recipeAt).tags",
            "missing required key \"protein\"")
    }

    // MARK: wrong JSON types

    @Test(
        "wrong ingredient field types raise SeedFormatError",
        arguments: ["name", "aliases", "shelfLifeDays", "category"])
    func wrongIngredientType(key: String) {
        let values: [String: Any] = [
            "name": 5, "aliases": "aloo", "shelfLifeDays": 21.0, "category": ["sabzi"],
        ]
        expectError(F.withIngredientRow { $0[key] = values[key] }, at: "\(F.potatoAt).\(key)") {
            $0.hasPrefix("expected ")
        }
    }

    @Test("booleans are not integers and integral doubles are not integers")
    func numberKinds() {
        expectError(
            F.withIngredientRow { $0["shelfLifeDays"] = true }, at: "\(F.potatoAt).shelfLifeDays",
            "expected an integer, got a boolean (true)")
        expectError(
            F.withIngredientRow { $0["shelfLifeDays"] = 21.0 }, at: "\(F.potatoAt).shelfLifeDays",
            "expected an integer, got a number (21.0)")
        expectError(
            F.withRecipeRow { $0.edit("ingredients", at: 0) { $0["isOptional"] = 0 } },
            at: "\(F.recipeAt).ingredients[0].isOptional", "expected a boolean, got a number (0)")
    }

    @Test("an alias entry that is not a string")
    func aliasEntry() {
        expectError(
            F.withIngredientRow { $0["aliases"] = ["aloo", NSNull()] },
            at: "\(F.potatoAt).aliases[1]",
            "expected a string, got null")
    }

    @Test(
        "wrong recipe field types raise SeedFormatError",
        arguments: ["minutes", "mealTypes", "steps", "tags", "imageAsset", "ingredients"])
    func wrongRecipeType(key: String) {
        let values: [String: Any] = [
            "minutes": "20", "mealTypes": "lunch", "steps": [1, 2], "tags": "north",
            "imageAsset": 5, "ingredients": ["potato": 1],
        ]
        let error = F.fragmentsError(F.withRecipeRow { $0[key] = values[key] })
        #expect(
            error?.location.hasPrefix("\(F.recipeAt).\(key)") == true,
            "\(String(describing: error))")
        #expect(error?.message.hasPrefix("expected ") == true, "\(String(describing: error))")
    }

    @Test("isOptional must be a boolean when present", arguments: ["null", "string", "int"])
    func isOptionalType(kind: String) {
        let values: [String: Any] = ["null": NSNull(), "string": "yes", "int": 1]
        expectError(
            F.withRecipeRow { $0.edit("ingredients", at: 0) { $0["isOptional"] = values[kind] } },
            at: "\(F.recipeAt).ingredients[0].isOptional"
        ) { $0.hasPrefix("expected a boolean, got ") }
    }

    // MARK: enums

    @Test("an unknown value names the allowed values")
    func unknownValue() {
        expectError(
            F.withRecipeRow { Self.editTags(&$0) { $0["region"] = "nort" } },
            at: "\(F.recipeAt).tags.region",
            "unknown value \"nort\" (allowed: north, south, east, west, gujarati, punjabi, "
                + "indoChinese, continental, street)")
    }

    @Test("kebab-case spellings are rejected (names are camelCase)")
    func kebabCase() {
        expectError(
            F.withIngredientRow { $0["category"] = "oil-ghee" }, at: "\(F.potatoAt).category"
        ) {
            $0.hasPrefix("unknown value \"oil-ghee\"")
        }
    }

    @Test("an unknown value inside an enum array is located by index")
    func unknownInArray() {
        expectError(
            F.withRecipeRow { $0["mealTypes"] = ["lunch", "tea"] },
            at: "\(F.recipeAt).mealTypes[1]",
            "unknown value \"tea\" (allowed: breakfast, lunch, dinner, snack)")
    }

    @Test("a duplicate value inside an enum array is rejected")
    func duplicateInArray() {
        expectError(
            F.withRecipeRow { Self.editTags(&$0) { $0["flavours"] = ["spicy", "spicy"] } },
            at: "\(F.recipeAt).tags.flavours[1]", "duplicate value \"spicy\"")
    }

    @Test("every enum field is checked")
    func everyEnumField() {
        for key in ["category", "role", "buyFrom"] {
            expectError(F.withIngredientRow { $0[key] = "zzz" }, at: "\(F.potatoAt).\(key)") {
                $0.hasPrefix("unknown value")
            }
        }
        expectError(F.withRecipeRow { $0["base"] = "naan" }, at: "\(F.recipeAt).base") {
            $0.hasPrefix("unknown value")
        }
        for key in ["dishType", "heaviness", "protein"] {
            expectError(
                F.withRecipeRow { Self.editTags(&$0) { $0[key] = "zzz" } },
                at: "\(F.recipeAt).tags.\(key)"
            ) { $0.hasPrefix("unknown value") }
        }
    }

    // MARK: duplicate ids

    @Test("duplicate ids within one fragment")
    func duplicateWithinFragment() {
        var fragments = F.fragmentsJSON()
        fragments.edit(F.ingredientFile) { $0.append(F.potatoRow(), to: "ingredients") }
        expectError(
            fragments, at: "\(F.ingredientFile) › ingredients[2].id",
            "duplicate ingredient id \"potato\" (first declared at \(F.potatoAt))")
    }

    @Test("duplicate ids across fragments")
    func duplicateAcrossFragments() throws {
        var manifestJSON = F.manifestJSON()
        manifestJSON["recipes"] = [F.recipeFile, "recipes/more.json"]
        let manifest = try F.codec.decodeManifest(jsonObject: manifestJSON)
        var fragments = F.fragmentsJSON()
        fragments["recipes/more.json"] = ["recipes": [F.alooRecipeRow()]]
        let error = F.seedError { () throws(SeedFormatError) in
            _ = try F.codec.decode(manifest, jsonByPath: fragments)
        }
        #expect(
            error
                == SeedFormatError(
                    location: "recipes/more.json › recipes[0].id",
                    message: "duplicate recipe id \"jeera_aloo\" (first declared at \(F.recipeAt))")
        )
    }
}
