import Foundation

/// Decodes the bundled seed data: `seed/manifest.json` plus the ingredient and
/// recipe fragment files it lists (`docs/design/SEED_GUIDE.md`).
///
/// Deliberately much stricter than ``BackupCodec``: seed files are authored
/// by hand, so every typo must fail loudly in the seed-asset tests. Unknown
/// keys, app-owned keys (`isUserCreated`, `source`, `isFavorite`,
/// `isHidden`), wrong JSON types (`true` is not `1`, `21.0` is not `21`),
/// unknown or repeated enum names and duplicate ids all throw a
/// ``SeedFormatError`` naming the file and JSON path. Content rules
/// (cross-references, aliases, ranges) are ``SeedValidator``'s job.
///
/// Pure and I/O-free: callers read the files (the app bundle, or the file
/// system in tests) and pass the bytes or parsed JSON in. Decoding never
/// returns partial data.
public struct SeedCodec: Sendable {
    /// File name used in locations for manifest errors.
    public static let manifestFile = "manifest.json"

    private static let ingredientKeys = ["id", "name", "aliases", "category", "role", "buyFrom"]
    private static let recipeKeys = [
        "id", "name", "mealTypes", "minutes", "base", "tags", "ingredients", "steps",
    ]
    private static let tagKeys = ["region", "dishType", "flavours", "heaviness", "protein"]
    private static let forbiddenKeys: Set<String> = [
        "isUserCreated", "source", "isFavorite", "isHidden",
    ]

    /// Creates a codec. Stateless.
    public init() {}

    // MARK: Manifest

    /// Decodes the bytes of `manifest.json`.
    ///
    /// - Parameter data: The file's bytes.
    /// - Returns: The manifest.
    /// - Throws: ``SeedFormatError`` if the bytes are not JSON or the manifest
    ///   is invalid (see ``decodeManifest(jsonObject:)``).
    public func decodeManifest(_ data: Data) throws(SeedFormatError) -> SeedManifest {
        try decodeManifest(jsonObject: try Self.parse(data, file: Self.manifestFile))
    }

    /// Decodes a parsed `manifest.json`.
    ///
    /// - Parameter jsonObject: The parsed document.
    /// - Returns: The manifest.
    /// - Throws: ``SeedFormatError`` unless the document is an object with
    ///   exactly `seedVersion` (an integer ≥ 1), `ingredients` and `recipes`
    ///   (non-empty arrays of unique, relative, lowercase `.json` paths; a
    ///   path may not appear in both lists).
    public func decodeManifest(jsonObject: Any?) throws(SeedFormatError) -> SeedManifest {
        let root = try SeedJSONObject(jsonObject, file: Self.manifestFile)
        try root.checkKeys(required: ["seedVersion", "ingredients", "recipes"])
        let version = try root.integer("seedVersion")
        guard version >= 1 else {
            throw SeedFormatError(
                location: root.locationOf("seedVersion"),
                message: "must be at least 1, got \(version)")
        }
        var seen = Set<String>()
        func paths(_ key: String) throws(SeedFormatError) -> [String] {
            let values = try root.stringList(key)
            guard !values.isEmpty else {
                throw SeedFormatError(
                    location: root.locationOf(key), message: "must list at least one file")
            }
            for (index, value) in values.enumerated() {
                let location = SeedFormatError.location(
                    file: Self.manifestFile, path: "\(key)[\(index)]")
                guard Self.isFragmentPath(value) else {
                    throw SeedFormatError(
                        location: location,
                        message: "invalid path \"\(value)\" (expected a relative lowercase "
                            + "path like \"recipes/sabzi.json\")")
                }
                guard seen.insert(value).inserted else {
                    throw SeedFormatError(
                        location: location, message: "file \"\(value)\" is listed more than once")
                }
            }
            return values
        }
        let ingredientFiles = try paths("ingredients")
        let recipeFiles = try paths("recipes")
        return SeedManifest(
            seedVersion: version, ingredientFiles: ingredientFiles, recipeFiles: recipeFiles)
    }

    // MARK: Fragments

    /// Decodes every fragment listed in `manifest` from raw file bytes.
    /// Entries of `dataByPath` not listed in `manifest` are ignored (and never
    /// parsed).
    ///
    /// - Parameters:
    ///   - manifest: The decoded manifest.
    ///   - dataByPath: Each fragment's bytes, keyed by its manifest path.
    /// - Returns: Every ingredient and recipe, in manifest order.
    /// - Throws: ``SeedFormatError`` as for ``decode(_:jsonByPath:)``, or when
    ///   a listed fragment is not valid JSON.
    public func decode(
        _ manifest: SeedManifest, dataByPath: [String: Data]
    ) throws(SeedFormatError) -> SeedBundle {
        try decode(manifest) { (file) throws(SeedFormatError) -> Any? in
            guard let data = dataByPath[file] else { return nil }
            return try Self.parse(data, file: file)
        }
    }

    /// Decodes every fragment listed in `manifest` from parsed JSON. Entries of
    /// `jsonByPath` not listed in `manifest` are ignored.
    ///
    /// - Parameters:
    ///   - manifest: The decoded manifest.
    ///   - jsonByPath: Each fragment's parsed document (the result of
    ///     `JSONSerialization.jsonObject(with:)`), keyed by its manifest path.
    /// - Returns: Every ingredient and recipe, in manifest order.
    /// - Throws: ``SeedFormatError`` if a listed fragment is missing from
    ///   `jsonByPath`, if any fragment is malformed, or if an ingredient or
    ///   recipe id is declared twice (in the same or different fragments).
    public func decode(
        _ manifest: SeedManifest, jsonByPath: [String: Any]
    ) throws(SeedFormatError) -> SeedBundle {
        try decode(manifest) { (file) throws(SeedFormatError) -> Any? in jsonByPath[file] }
    }

    /// `lookup` returns a fragment's parsed document, or `nil` when the caller
    /// did not provide it.
    private func decode(
        _ manifest: SeedManifest, lookup: (String) throws(SeedFormatError) -> Any?
    ) throws(SeedFormatError) -> SeedBundle {
        var ingredientsSeenAt: [String: String] = [:]
        var ingredients: [Ingredient] = []
        for file in manifest.ingredientFiles {
            for row in try rows(file, key: "ingredients", lookup: lookup) {
                ingredients.append(try ingredient(row, seenAt: &ingredientsSeenAt))
            }
        }
        var recipesSeenAt: [String: String] = [:]
        var recipes: [Recipe] = []
        for file in manifest.recipeFiles {
            for row in try rows(file, key: "recipes", lookup: lookup) {
                recipes.append(try recipe(row, seenAt: &recipesSeenAt))
            }
        }
        return SeedBundle(
            seedVersion: manifest.seedVersion, ingredients: ingredients, recipes: recipes)
    }

    private func rows(
        _ file: String, key: String, lookup: (String) throws(SeedFormatError) -> Any?
    ) throws(SeedFormatError) -> [SeedJSONObject] {
        guard let document = try lookup(file) else {
            throw SeedFormatError(
                location: file,
                message: "listed in \(Self.manifestFile) but its contents were not provided")
        }
        let root = try SeedJSONObject(document, file: file)
        try root.checkKeys(required: [key])
        return try root.objects(key)
    }

    private func ingredient(
        _ row: SeedJSONObject, seenAt: inout [String: String]
    ) throws(SeedFormatError) -> Ingredient {
        try row.checkKeys(
            required: Self.ingredientKeys, optional: ["shelfLifeDays"],
            forbidden: Self.forbiddenKeys)
        try uniqueId(row, kind: "ingredient", seenAt: &seenAt)
        _ = try row.string("name")
        _ = try row.stringList("aliases")
        try row.enumValue("category", IngredientCategory.self)
        try row.enumValue("role", IngredientRole.self)
        try row.enumValue("buyFrom", BuyFrom.self)
        _ = try row.optionalInteger("shelfLifeDays")
        return try Self.map(row) { () throws(EntityJSONError) in
            try EntityJSON.ingredient(from: row.map)
        }
    }

    private func recipe(
        _ row: SeedJSONObject, seenAt: inout [String: String]
    ) throws(SeedFormatError) -> Recipe {
        try row.checkKeys(
            required: Self.recipeKeys, optional: ["imageAsset"], forbidden: Self.forbiddenKeys)
        try uniqueId(row, kind: "recipe", seenAt: &seenAt)
        _ = try row.string("name")
        try row.enumList("mealTypes", MealType.self)
        _ = try row.integer("minutes")
        try row.enumValue("base", DishBase.self)
        _ = try row.stringList("steps")
        _ = try row.optionalString("imageAsset")
        let tags = try row.object("tags")
        try tags.checkKeys(required: Self.tagKeys)
        try tags.enumValue("region", Region.self)
        try tags.enumValue("dishType", DishType.self)
        try tags.enumList("flavours", Flavour.self)
        try tags.enumValue("heaviness", Heaviness.self)
        try tags.enumValue("protein", Protein.self)
        for line in try row.objects("ingredients") {
            try line.checkKeys(
                required: ["ingredientId", "quantityText"], optional: ["isOptional"])
            _ = try line.string("ingredientId")
            _ = try line.string("quantityText")
            _ = try line.optionalBool("isOptional")
        }
        var json = row.map
        json["source"] = RecipeSource.seed.rawValue
        return try Self.map(row) { () throws(EntityJSONError) in
            try EntityJSON.recipe(from: json)
        }
    }

    private func uniqueId(
        _ row: SeedJSONObject, kind: String, seenAt: inout [String: String]
    ) throws(SeedFormatError) {
        let id = try row.string("id")
        if let first = seenAt[id] {
            throw SeedFormatError(
                location: row.locationOf("id"),
                message: "duplicate \(kind) id \"\(id)\" (first declared at \(first))")
        }
        seenAt[id] = row.location
    }

    // MARK: Helpers

    /// Runs a shared entity mapper on a row the strict checks already
    /// accepted. Those checks are a superset of the mapper's, so a mapper
    /// error means the two disagree; it is still reported, never swallowed.
    private static func map<T>(
        _ row: SeedJSONObject, _ read: () throws(EntityJSONError) -> T
    ) throws(SeedFormatError) -> T {
        do {
            return try read()
        } catch {
            throw SeedFormatError(location: row.location, message: error.message)
        }
    }

    /// Parses one file's bytes; any JSON value is allowed at the root, so a
    /// wrong root type gets the usual "expected an object" message.
    private static func parse(_ data: Data, file: String) throws(SeedFormatError) -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            let detail = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String
            throw SeedFormatError(
                location: file, message: "invalid JSON" + (detail.map { ": \($0)" } ?? ""))
        }
    }

    /// `^[a-z0-9_]+(/[a-z0-9_]+)*\.json$`: relative, lowercase, no empty,
    /// `.` or `..` segments.
    static func isFragmentPath(_ path: String) -> Bool {
        let bytes = Array(path.utf8)
        let suffix = Array(".json".utf8)
        guard bytes.count > suffix.count, bytes.suffix(suffix.count).elementsEqual(suffix) else {
            return false
        }
        return bytes.dropLast(suffix.count).split(
            separator: UInt8(ascii: "/"), omittingEmptySubsequences: false
        )
        .allSatisfy { segment in
            !segment.isEmpty
                && segment.allSatisfy { byte in
                    (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
                        || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                        || byte == UInt8(ascii: "_")
                }
        }
    }
}
