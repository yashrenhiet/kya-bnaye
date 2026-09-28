import Foundation

/// A JSON object found at ``path`` inside the seed file ``file``, read with
/// strict, location-aware accessors. Internal to ``SeedCodec``.
///
/// Every accessor checks the JSON type before reading, so malformed seed data
/// always surfaces as a ``SeedFormatError`` naming the exact file and JSON
/// path. Booleans are never accepted as numbers (or vice versa) and `21.0` is
/// never accepted as an integer (see ``JSONValue``).
///
/// Key checks visit keys in sorted (UTF-16) order, so when an object has
/// several bad keys the one reported is deterministic. The Dart oracle
/// reported the first in document order, which `JSONSerialization` does not
/// preserve.
struct SeedJSONObject {
    /// Seed file path, relative to `seed/`.
    let file: String

    /// JSON path of this object inside ``file``; empty for the root.
    let path: String

    /// The object's members.
    let map: [String: Any]

    /// Wraps `value`, which must be a JSON object with string keys.
    init(_ value: Any?, file: String, path: String = "") throws(SeedFormatError) {
        let location = SeedFormatError.location(file: file, path: path)
        guard let object = value as? [AnyHashable: Any] else {
            throw SeedFormatError(
                location: location, message: "expected an object, got \(JSONValue.describe(value))")
        }
        var map: [String: Any] = [:]
        let nonStringKeys = object.keys.filter { !($0.base is String) }
        if let key = nonStringKeys.map({ "\($0.base)" }).min(by: Self.precedes) {
            throw SeedFormatError(location: location, message: "object key \(key) is not a string")
        }
        for (key, member) in object {
            if let name = key.base as? String { map[name] = member }
        }
        self.file = file
        self.path = path
        self.map = map
    }

    /// Location of this object, for error messages.
    var location: String { SeedFormatError.location(file: file, path: path) }

    /// Location of the value under `key`.
    func locationOf(_ key: String) -> String {
        SeedFormatError.location(file: file, path: child(key))
    }

    private func child(_ key: String) -> String {
        path.isEmpty ? key : "\(path).\(key)"
    }

    /// Rejects `forbidden` keys first, then any key outside `required` and
    /// `optional`, then any missing `required` key (in `required` order).
    func checkKeys(
        required: [String], optional: [String] = [], forbidden: Set<String> = []
    ) throws(SeedFormatError) {
        let keys = map.keys.sorted(by: Self.precedes)
        if let key = keys.first(where: forbidden.contains) {
            throw SeedFormatError(
                location: locationOf(key),
                message: "key \"\(key)\" is not allowed in seed data (the app sets it)")
        }
        let allowed = required + optional
        if let key = keys.first(where: { !allowed.contains($0) }) {
            throw SeedFormatError(
                location: locationOf(key),
                message: "unknown key \"\(key)\" (allowed: \(allowed.joined(separator: ", ")))")
        }
        if let key = required.first(where: { map[$0] == nil }) {
            throw SeedFormatError(location: location, message: "missing required key \"\(key)\"")
        }
    }

    /// The string under `key`.
    func string(_ key: String) throws(SeedFormatError) -> String {
        try typed(key, "a string", JSONValue.string)
    }

    /// The string under `key`, or `nil` if absent or `null`.
    func optionalString(_ key: String) throws(SeedFormatError) -> String? {
        JSONValue.isNull(map[key]) ? nil : try string(key)
    }

    /// The integer under `key` (`21.0` and `true` are rejected).
    func integer(_ key: String) throws(SeedFormatError) -> Int {
        try typed(key, "an integer", JSONValue.integer)
    }

    /// The integer under `key`, or `nil` if absent or `null`.
    func optionalInteger(_ key: String) throws(SeedFormatError) -> Int? {
        JSONValue.isNull(map[key]) ? nil : try integer(key)
    }

    /// The boolean under `key`, or `nil` if absent. An explicit `null` is
    /// rejected: omit the key instead.
    func optionalBool(_ key: String) throws(SeedFormatError) -> Bool? {
        map[key] == nil ? nil : try typed(key, "a boolean", JSONValue.boolean)
    }

    /// The array under `key`.
    func list(_ key: String) throws(SeedFormatError) -> [Any] {
        try typed(key, "an array", JSONValue.array)
    }

    /// The array of strings under `key`.
    func stringList(_ key: String) throws(SeedFormatError) -> [String] {
        var result: [String] = []
        for (index, value) in try list(key).enumerated() {
            guard let text = JSONValue.string(value) else {
                throw SeedFormatError(
                    location: elementLocation(key, index),
                    message: "expected a string, got \(JSONValue.describe(value))")
            }
            result.append(text)
        }
        return result
    }

    /// The case of `T` named by the string under `key`.
    @discardableResult
    func enumValue<T: RawRepresentable & CaseIterable>(
        _ key: String, _: T.Type
    ) throws(SeedFormatError) -> T where T.RawValue == String {
        try Self.enumCase(try string(key), at: locationOf(key))
    }

    /// The distinct cases of `T` named by the array under `key`, in order; a
    /// repeated name is rejected.
    @discardableResult
    func enumList<T: RawRepresentable & CaseIterable & Equatable>(
        _ key: String, _: T.Type
    ) throws(SeedFormatError) -> [T] where T.RawValue == String {
        var result: [T] = []
        for (index, name) in try stringList(key).enumerated() {
            let location = elementLocation(key, index)
            let value: T = try Self.enumCase(name, at: location)
            if result.contains(value) {
                throw SeedFormatError(location: location, message: "duplicate value \"\(name)\"")
            }
            result.append(value)
        }
        return result
    }

    /// The nested object under `key`.
    func object(_ key: String) throws(SeedFormatError) -> SeedJSONObject {
        try SeedJSONObject(map[key], file: file, path: child(key))
    }

    /// The array of objects under `key`.
    func objects(_ key: String) throws(SeedFormatError) -> [SeedJSONObject] {
        var result: [SeedJSONObject] = []
        for (index, value) in try list(key).enumerated() {
            result.append(try SeedJSONObject(value, file: file, path: "\(child(key))[\(index)]"))
        }
        return result
    }

    // MARK: Helpers

    private func typed<T>(
        _ key: String, _ expected: String, _ read: (Any?) -> T?
    ) throws(SeedFormatError) -> T {
        guard let value = read(map[key]) else {
            throw SeedFormatError(
                location: locationOf(key),
                message: "expected \(expected), got \(JSONValue.describe(map[key]))")
        }
        return value
    }

    private func elementLocation(_ key: String, _ index: Int) -> String {
        SeedFormatError.location(file: file, path: "\(child(key))[\(index)]")
    }

    private static func enumCase<T: RawRepresentable & CaseIterable>(
        _ name: String, at location: String
    ) throws(SeedFormatError) -> T where T.RawValue == String {
        guard let value = T(rawValue: name) else {
            let allowed = T.allCases.map(\.rawValue).joined(separator: ", ")
            throw SeedFormatError(
                location: location, message: "unknown value \"\(name)\" (allowed: \(allowed))")
        }
        return value
    }

    /// Dart's `String.compareTo` order (UTF-16 code units).
    static func precedes(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf16.lexicographicallyPrecedes(rhs.utf16)
    }
}
