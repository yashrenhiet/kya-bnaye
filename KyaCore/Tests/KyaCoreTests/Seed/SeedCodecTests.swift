import Foundation
import KyaCore
import Testing

/// Port of `legacy/packages/kya_core/test/seed/seed_codec_test.dart`.
@Suite("SeedCodec")
struct SeedCodecTests {
    typealias F = SeedFixtures

    // MARK: decodeManifest

    @Test("decodes version and fragment lists in order")
    func manifestOrder() throws {
        let manifest = try F.codec.decodeManifest(jsonObject: [
            "seedVersion": 3, "ingredients": ["ingredients/b.json", "ingredients/a.json"],
            "recipes": ["recipes/x.json"],
        ])
        #expect(manifest.seedVersion == 3)
        #expect(manifest.ingredientFiles == ["ingredients/b.json", "ingredients/a.json"])
        #expect(manifest.recipeFiles == ["recipes/x.json"])
        #expect(
            manifest.allFiles == ["ingredients/b.json", "ingredients/a.json", "recipes/x.json"])
    }

    @Test("rejects a non-object document")
    func manifestNotObject() {
        #expect(
            F.manifestError(["recipes/x.json"])
                == SeedFormatError(
                    location: "manifest.json", message: "expected an object, got an array"))
        #expect(
            F.manifestError(nil)
                == SeedFormatError(
                    location: "manifest.json", message: "expected an object, got null"))
    }

    @Test("rejects a missing key")
    func manifestMissingKey() {
        var json = F.manifestJSON()
        json["recipes"] = nil
        #expect(
            F.manifestError(json)
                == SeedFormatError(
                    location: "manifest.json", message: "missing required key \"recipes\""))
    }

    @Test("rejects an unknown key, listing the allowed ones")
    func manifestUnknownKey() {
        var json = F.manifestJSON()
        json["version"] = 1
        #expect(
            F.manifestError(json)
                == SeedFormatError(
                    location: "manifest.json › version",
                    message: "unknown key \"version\" (allowed: seedVersion, ingredients, recipes)")
        )
    }

    @Test("rejects a non-integer or non-positive seedVersion")
    func manifestVersion() throws {
        var json = F.manifestJSON()
        json["seedVersion"] = 1.0
        #expect(
            F.manifestError(json)
                == SeedFormatError(
                    location: "manifest.json › seedVersion",
                    message: "expected an integer, got a number (1.0)"))
        json["seedVersion"] = true
        #expect(F.manifestError(json)?.message == "expected an integer, got a boolean (true)")
        json["seedVersion"] = 0
        #expect(
            F.manifestError(json)
                == SeedFormatError(
                    location: "manifest.json › seedVersion", message: "must be at least 1, got 0"))
    }

    @Test("JSON text keeps booleans, integers and doubles apart")
    func manifestFromText() throws {
        let cases = [
            (
                #"{"seedVersion": 1.0, "ingredients": ["a.json"], "recipes": ["b.json"]}"#,
                "a number (1.0)"
            ),
            (
                #"{"seedVersion": true, "ingredients": ["a.json"], "recipes": ["b.json"]}"#,
                "a boolean (true)"
            ),
            (
                #"{"seedVersion": "1", "ingredients": ["a.json"], "recipes": ["b.json"]}"#,
                "a string (\"1\")"
            ),
        ]
        for (text, got) in cases {
            #expect(
                F.seedError { () throws(SeedFormatError) in
                    _ = try F.codec.decodeManifest(JSONText.data(text))
                }
                    == SeedFormatError(
                        location: "manifest.json › seedVersion",
                        message: "expected an integer, got \(got)"))
        }
        let manifest = try F.codec.decodeManifest(
            JSONText.data(#"{"seedVersion": 2, "ingredients": ["a.json"], "recipes": ["b.json"]}"#))
        #expect(
            manifest
                == SeedManifest(
                    seedVersion: 2, ingredientFiles: ["a.json"], recipeFiles: ["b.json"]))
    }

    @Test("rejects invalid JSON text with the file as location")
    func manifestInvalidText() {
        let error = F.seedError { () throws(SeedFormatError) in
            _ = try F.codec.decodeManifest(JSONText.data(#"{"seedVersion": 1,"#))
        }
        #expect(error?.location == "manifest.json")
        #expect(error?.message.hasPrefix("invalid JSON") == true)
    }

    @Test("rejects an empty fragment list")
    func manifestEmptyList() {
        var json = F.manifestJSON()
        json["recipes"] = [Any]()
        #expect(
            F.manifestError(json)
                == SeedFormatError(
                    location: "manifest.json › recipes", message: "must list at least one file"))
    }

    @Test("rejects a non-string path")
    func manifestNonStringPath() {
        var json = F.manifestJSON()
        json["recipes"] = [7]
        #expect(
            F.manifestError(json)
                == SeedFormatError(
                    location: "manifest.json › recipes[0]",
                    message: "expected a string, got a number (7)"))
    }

    @Test(
        "rejects unsafe or non-JSON paths",
        arguments: [
            "../secret.json", "/abs/path.json", "Recipes/Sabzi.json", "recipes/sabzi.txt",
            "recipes//sabzi.json", "", ".json", "recipes/.json", "recipes/sabzi.json/",
            "recipes/sa.bzi.json", "recipes/sabzi.JSON",
        ])
    func manifestUnsafePath(path: String) {
        var json = F.manifestJSON()
        json["recipes"] = [path]
        let error = F.manifestError(json)
        #expect(error?.location == "manifest.json › recipes[0]")
        #expect(error?.message.hasPrefix("invalid path \"\(path)\"") == true)
    }

    @Test("rejects a path listed twice, even across lists")
    func manifestDuplicatePath() {
        var json = F.manifestJSON()
        json["recipes"] = [F.recipeFile, F.ingredientFile]
        #expect(
            F.manifestError(json)
                == SeedFormatError(
                    location: "manifest.json › recipes[1]",
                    message: "file \"\(F.ingredientFile)\" is listed more than once"))
    }

    // MARK: decode

    @Test("maps every field and forces seed ownership")
    func decodeFields() throws {
        let bundle = try F.decodeFragments(F.fragmentsJSON())
        #expect(bundle.seedVersion == 1)
        let potato = try #require(bundle.ingredients.first)
        #expect(
            potato.isIdentical(
                to: Ingredient(
                    id: "potato", name: "Potato", aliases: ["aloo", "batata"], category: .sabzi,
                    role: .core, buyFrom: .sabziwala, shelfLifeDays: 21, isUserCreated: false)))
        #expect(bundle.ingredients[1].shelfLifeDays == nil)

        let recipe = try #require(bundle.recipes.first)
        #expect(bundle.recipes.count == 1)
        #expect(recipe.id == "jeera_aloo")
        #expect(recipe.mealTypes == [.lunch, .dinner])
        #expect(recipe.minutes == 20)
        #expect(recipe.base == .roti)
        #expect(
            recipe.tags
                == DishTags(
                    region: .north, dishType: .drySabzi, flavours: [.spicy, .savoury],
                    heaviness: .light, protein: .vegOnly))
        #expect(recipe.ingredients.map(\.ingredientId) == ["potato", "salt"])
        #expect(recipe.ingredients.map(\.isOptional) == [false, true])
        #expect(recipe.ingredients.first?.quantityText == "3 medium")
        #expect(recipe.steps.count == 2)
        #expect(recipe.imageAsset == nil)
        #expect(recipe.source == .seed)
        #expect(!recipe.isFavorite)
        #expect(!recipe.isHidden)
    }

    @Test("decodes real JSON bytes and omitted optional keys")
    func decodeBytes() throws {
        let fragments = F.withRecipeRow { $0["imageAsset"] = nil }
        var dataByPath: [String: Data] = [:]
        for (path, document) in fragments {
            dataByPath[path] = try JSONSerialization.data(withJSONObject: document)
        }
        dataByPath["stray/file.json"] = JSONText.data("not json")
        let manifest = try F.codec.decodeManifest(jsonObject: F.manifestJSON())
        let bundle = try F.codec.decode(manifest, dataByPath: dataByPath)
        #expect(bundle.recipes.first?.imageAsset == nil)
        #expect(bundle.ingredients.map(\.id) == ["potato", "salt"])
    }

    @Test("reports invalid fragment bytes and missing fragments by file")
    func decodeBadBytes() throws {
        let manifest = try F.codec.decodeManifest(jsonObject: F.manifestJSON())
        let invalid = F.seedError { () throws(SeedFormatError) in
            _ = try F.codec.decode(manifest, dataByPath: [F.ingredientFile: JSONText.data("{")])
        }
        #expect(invalid?.location == F.ingredientFile)
        #expect(invalid?.message.hasPrefix("invalid JSON") == true)
        let missing = F.seedError { () throws(SeedFormatError) in
            _ = try F.codec.decode(manifest, dataByPath: [:])
        }
        #expect(
            missing
                == SeedFormatError(
                    location: F.ingredientFile,
                    message: "listed in manifest.json but its contents were not provided"))
        let nullDocument = F.seedError { () throws(SeedFormatError) in
            _ = try F.codec.decode(manifest, dataByPath: [F.ingredientFile: JSONText.data("null")])
        }
        #expect(nullDocument?.message == "expected an object, got null")
    }

    @Test("keeps a non-nil imageAsset for the validator to check")
    func decodeImageAsset() throws {
        let bundle = try F.decodeFragments(F.withRecipeRow { $0["imageAsset"] = "images/x.webp" })
        #expect(bundle.recipes.first?.imageAsset == "images/x.webp")
    }

    @Test("keeps fragment order and ignores unlisted files")
    func decodeOrder() throws {
        var manifestJSON = F.manifestJSON()
        manifestJSON["ingredients"] = ["ingredients/b.json", F.ingredientFile]
        let manifest = try F.codec.decodeManifest(jsonObject: manifestJSON)
        var jeera = F.saltRow()
        jeera["id"] = "jeera"
        jeera["name"] = "Jeera"
        var fragments = F.fragmentsJSON()
        fragments["ingredients/b.json"] = ["ingredients": [jeera]]
        fragments["stray/file.json"] = "not even an object"

        let bundle = try F.codec.decode(manifest, jsonByPath: fragments)
        #expect(bundle.ingredients.map(\.id) == ["jeera", "potato", "salt"])
    }

    @Test("rejects a fragment the manifest lists but the caller omitted")
    func decodeOmitted() {
        var fragments = F.fragmentsJSON()
        fragments[F.recipeFile] = nil
        #expect(
            F.fragmentsError(fragments)
                == SeedFormatError(
                    location: F.recipeFile,
                    message: "listed in manifest.json but its contents were not provided"))
    }

    @Test("rejects a fragment that is not an object")
    func decodeNotObject() {
        var fragments = F.fragmentsJSON()
        fragments[F.recipeFile] = NSNull()
        #expect(
            F.fragmentsError(fragments)
                == SeedFormatError(location: F.recipeFile, message: "expected an object, got null"))
    }

    @Test("rejects the wrong top-level key for the fragment kind")
    func decodeWrongKey() {
        var fragments = F.fragmentsJSON()
        fragments[F.ingredientFile] = ["recipes": [Any]()]
        #expect(
            F.fragmentsError(fragments)
                == SeedFormatError(
                    location: "\(F.ingredientFile) › recipes",
                    message: "unknown key \"recipes\" (allowed: ingredients)"))
    }

    @Test("rejects a missing top-level key")
    func decodeMissingKey() {
        var fragments = F.fragmentsJSON()
        fragments[F.recipeFile] = [String: Any]()
        #expect(
            F.fragmentsError(fragments)
                == SeedFormatError(
                    location: F.recipeFile, message: "missing required key \"recipes\""))
    }

    @Test("rejects rows that are not an array of objects")
    func decodeRowsNotObjects() {
        var fragments = F.fragmentsJSON()
        fragments[F.recipeFile] = ["recipes": "x"]
        #expect(
            F.fragmentsError(fragments)
                == SeedFormatError(
                    location: "\(F.recipeFile) › recipes",
                    message: "expected an array, got a string (\"x\")"))
        fragments[F.recipeFile] = ["recipes": [1]]
        #expect(
            F.fragmentsError(fragments)
                == SeedFormatError(
                    location: "\(F.recipeFile) › recipes[0]",
                    message: "expected an object, got a number (1)"))
    }

    @Test("rejects an object with non-string keys")
    func decodeNonStringKeys() {
        var fragments = F.fragmentsJSON()
        fragments[F.recipeFile] = [1: "x"] as [Int: String]
        #expect(
            F.fragmentsError(fragments)
                == SeedFormatError(location: F.recipeFile, message: "object key 1 is not a string"))
    }

    @Test("SeedFormatError description includes location and message")
    func errorDescription() {
        #expect(
            SeedFormatError(location: "a.json › x", message: "bad").description
                == "SeedFormatError: a.json › x: bad")
    }
}
