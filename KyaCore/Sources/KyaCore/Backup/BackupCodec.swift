import Foundation

/// Encodes a ``BackupBundle`` as a JSON file and decodes it back (F7 in
/// `AGENTS.md` section 3). Pure: callers do the file I/O and share-sheet
/// mechanics.
///
/// **Format** (schema ``currentVersion``): one object with `version`,
/// `exportedAt`, `seedVersion` (an integer ≥ 1, or `null` when unknown) and
/// one array per entity type (`ingredients`, `pantryItems`, `recipes`,
/// `mealLogs`, `swipeEvents`, `shoppingItems`). Enums are written by raw
/// value, `nil` optionals as JSON `null`, sets in enum declaration order.
///
/// **Versions.** Schema 1 is the legacy Dart app's format: the same object
/// without `seedVersion`. Schema 2 adds `seedVersion`, so a restore can tell
/// which seed rows the file already contains. Both are read; schema 1 files
/// decode with ``BackupBundle/seedVersion`` `nil`. Only schema 2 is written.
///
/// **Encoding** is deterministic: keys are sorted, so the same bundle and
/// `exportedAt` always produce the same bytes.
///
/// **Timestamps** are ISO-8601 with fractional seconds, always written in UTC
/// with a `Z` suffix (`2026-09-26T12:00:00.000Z`, or six fraction digits for
/// sub-millisecond instants) and rounded to the microsecond. Reading accepts
/// everything Dart's `DateTime.parse` accepts: `Z` or `±hh:mm` offsets, and
/// zone-less wall-clock times, which are interpreted in ``timeZone``.
///
/// **Divergence from the Dart oracle:** Dart's `DateTime` carries a UTC/local
/// flag and wrote local times without a zone suffix; Swift's `Date` is a bare
/// instant, so every timestamp is written as UTC. The instant (to the
/// microsecond) survives the round trip; the UTC/local flag does not exist to
/// preserve. Out-of-range fields such as month 13 are rejected, where Dart
/// silently rolled them over. A timestamp outside the roughly ±275,000-year
/// range this codec can ever write back out (Dart's `DateTime` range) is
/// likewise rejected on read, so a restored backup can never hold an instant
/// this codec would refuse to re-export.
///
/// **Decoding** is lenient about keys (unknown keys are ignored, so newer
/// minor additions still restore; absent boolean flags mean `false`) but
/// strict about types and values: a wrong JSON type (`1` for a boolean,
/// `35.0` for an integer), unknown enum value or unparsable timestamp throws
/// ``BackupFormatError``. Decoding never returns partial data.
public struct BackupCodec: Sendable {
    /// The schema version this app writes, and the newest it can read.
    public static let currentVersion = 2

    /// Time zone for zone-less timestamps written by other tools (this codec
    /// never writes them).
    public let timeZone: TimeZone

    /// Creates a codec.
    ///
    /// - Parameter timeZone: Zone for zone-less timestamps when decoding;
    ///   defaults to the device's current zone.
    public init(timeZone: TimeZone = .current) {
        self.timeZone = timeZone
    }

    /// Encodes `bundle` as UTF-8 JSON with sorted keys.
    ///
    /// - Parameters:
    ///   - bundle: Everything to back up.
    ///   - exportedAt: When the export happened; written as `exportedAt`.
    /// - Returns: The backup file's bytes.
    /// - Throws: ``BackupEncodingError`` only for dates no clock produces.
    public func encode(
        _ bundle: BackupBundle, exportedAt: Date
    ) throws(BackupEncodingError) -> Data {
        let object = try jsonObject(for: bundle, exportedAt: exportedAt)
        do {
            return try JSONSerialization.data(
                withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        } catch {
            throw .serializationFailed(detail: String(describing: error))
        }
    }

    /// Decodes a backup file.
    ///
    /// - Parameter data: The file's bytes.
    /// - Returns: Every entity, in file order.
    /// - Throws: ``BackupFormatError`` when the bytes are not JSON, the root is
    ///   not an object, the version is unsupported or any entity is malformed.
    public func decode(_ data: Data) throws(BackupFormatError) -> BackupBundle {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw .notAJSONObject(detail: "the file is not valid JSON")
        }
        return try decode(jsonObject: root)
    }

    /// Decodes an already-parsed backup document (the result of
    /// `JSONSerialization.jsonObject(with:)`).
    ///
    /// The version is checked before anything else, then `seedVersion`; then
    /// each section is checked and decoded in turn (ingredients, pantry items,
    /// recipes, meal logs, swipe events, shopping items), stopping at the
    /// first problem.
    ///
    /// - Parameter jsonObject: The parsed document.
    /// - Returns: Every entity, in document order.
    /// - Throws: ``BackupFormatError`` as for ``decode(_:)``.
    public func decode(jsonObject: Any) throws(BackupFormatError) -> BackupBundle {
        guard let root = jsonObject as? [String: Any] else {
            throw .notAJSONObject(
                detail: "expected an object, got \(JSONValue.describe(jsonObject))")
        }
        guard let version = JSONValue.integer(root["version"]),
            (1...Self.currentVersion).contains(version)
        else {
            throw .unsupportedVersion(found: JSONValue.text(root["version"]))
        }
        let zone = timeZone
        return BackupBundle(
            seedVersion: try seedVersion(in: root),
            ingredients: try section("ingredients", of: root) { (value) throws(EntityJSONError) in
                try EntityJSON.ingredient(from: value)
            },
            pantryItems: try section("pantryItems", of: root) { (value) throws(EntityJSONError) in
                try BackupEntityJSON.pantryItem(from: value, timeZone: zone)
            },
            recipes: try section("recipes", of: root) { (value) throws(EntityJSONError) in
                try EntityJSON.recipe(from: value)
            },
            mealLogs: try section("mealLogs", of: root) { (value) throws(EntityJSONError) in
                try BackupEntityJSON.mealLog(from: value, timeZone: zone)
            },
            swipeEvents: try section("swipeEvents", of: root) { (value) throws(EntityJSONError) in
                try BackupEntityJSON.swipeEvent(from: value, timeZone: zone)
            },
            shoppingItems: try section("shoppingItems", of: root) {
                (value) throws(EntityJSONError) in
                try BackupEntityJSON.shoppingItem(from: value, timeZone: zone)
            }
        )
    }

    // MARK: Internals

    private func jsonObject(
        for bundle: BackupBundle, exportedAt: Date
    ) throws(BackupEncodingError) -> [String: Any] {
        guard let exported = BackupTimestamp.string(from: exportedAt) else {
            throw .unrepresentableDate(field: "exportedAt")
        }
        var pantry: [Any] = []
        for (index, item) in bundle.pantryItems.enumerated() {
            pantry.append(try BackupEntityJSON.json(item, at: "pantryItems[\(index)]"))
        }
        var logs: [Any] = []
        for (index, log) in bundle.mealLogs.enumerated() {
            logs.append(try BackupEntityJSON.json(log, at: "mealLogs[\(index)]"))
        }
        var events: [Any] = []
        for (index, event) in bundle.swipeEvents.enumerated() {
            events.append(try BackupEntityJSON.json(event, at: "swipeEvents[\(index)]"))
        }
        var shopping: [Any] = []
        for (index, item) in bundle.shoppingItems.enumerated() {
            shopping.append(try BackupEntityJSON.json(item, at: "shoppingItems[\(index)]"))
        }
        return [
            "version": Self.currentVersion,
            "exportedAt": exported,
            "seedVersion": bundle.seedVersion.map { $0 as Any } ?? NSNull(),
            "ingredients": bundle.ingredients.map(EntityJSON.json(_:)),
            "pantryItems": pantry,
            "recipes": bundle.recipes.map(EntityJSON.json(_:)),
            "mealLogs": logs,
            "swipeEvents": events,
            "shoppingItems": shopping,
        ]
    }

    /// The optional `seedVersion`: absent or `null` means unknown (always the
    /// case in schema 1); anything else must be an integer ≥ 1.
    private func seedVersion(in root: [String: Any]) throws(BackupFormatError) -> Int? {
        let value = root["seedVersion"]
        if JSONValue.isNull(value) { return nil }
        guard let version = JSONValue.integer(value), version >= 1 else {
            throw .malformed(
                detail: "seedVersion: expected an integer ≥ 1, got \(JSONValue.describe(value))")
        }
        return version
    }

    /// Decodes every entry of the array under `key` with `read`, wrapping
    /// entity errors as ``BackupFormatError/malformed(detail:)``.
    private func section<T>(
        _ key: String,
        of root: [String: Any],
        _ read: (Any) throws(EntityJSONError) -> T
    ) throws(BackupFormatError) -> [T] {
        guard let entries = JSONValue.array(root[key]) else {
            throw .sectionNotAList(section: key, found: JSONValue.typeName(root[key]))
        }
        var result: [T] = []
        result.reserveCapacity(entries.count)
        for (index, entry) in entries.enumerated() {
            do {
                result.append(try read(entry))
            } catch {
                throw .malformed(detail: "\(key)[\(index)]: \(error.message)")
            }
        }
        return result
    }
}
