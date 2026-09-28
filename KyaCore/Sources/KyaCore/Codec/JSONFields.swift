import Foundation

/// Why a shared entity mapper could not read a JSON object. Internal: each
/// codec wraps it in its own public error (``BackupFormatError`` or
/// ``SeedFormatError``).
struct EntityJSONError: Error, Sendable, Equatable {
    /// What is wrong, naming the entity and field, e.g.
    /// `recipe.minutes: expected an integer, got a string ("35")`.
    let message: String
}

/// A JSON object read field by field with type checks, for the shared entity
/// mappers in ``EntityJSON`` and the backup-only mappers.
///
/// Deliberately lenient about **keys** (unknown keys are ignored, absent
/// boolean flags default to `false`, absent optionals are `nil`) but strict
/// about **types**: a present value of the wrong JSON type always throws,
/// never coerces. The strict key checks of seed data live in the seed codec.
struct JSONFields {
    /// The underlying object.
    let map: [String: Any]

    /// Entity name used in error messages, e.g. `recipe`.
    let entity: String

    /// Wraps `value`, which must be a JSON object with string keys.
    init(_ value: Any?, entity: String) throws(EntityJSONError) {
        guard let map = value as? [String: Any] else {
            throw EntityJSONError(
                message: "\(entity): expected an object, got \(JSONValue.describe(value))")
        }
        self.map = map
        self.entity = entity
    }

    /// The string under `key`.
    func string(_ key: String) throws(EntityJSONError) -> String {
        try typed(key, "a string", JSONValue.string)
    }

    /// The string under `key`, or `nil` when absent or `null`.
    func optionalString(_ key: String) throws(EntityJSONError) -> String? {
        JSONValue.isNull(map[key]) ? nil : try string(key)
    }

    /// The integer under `key` (`35.0` and `true` are rejected).
    func integer(_ key: String) throws(EntityJSONError) -> Int {
        try typed(key, "an integer", JSONValue.integer)
    }

    /// The integer under `key`, or `nil` when absent or `null`.
    func optionalInteger(_ key: String) throws(EntityJSONError) -> Int? {
        JSONValue.isNull(map[key]) ? nil : try integer(key)
    }

    /// The boolean under `key`; `false` when absent or `null` (like the Dart
    /// oracle's `as bool? ?? false`). `1` and `"true"` are rejected.
    func flag(_ key: String) throws(EntityJSONError) -> Bool {
        JSONValue.isNull(map[key]) ? false : try typed(key, "a boolean", JSONValue.boolean)
    }

    /// The array under `key`.
    func array(_ key: String) throws(EntityJSONError) -> [Any] {
        try typed(key, "an array", JSONValue.array)
    }

    /// The array of strings under `key`.
    func stringList(_ key: String) throws(EntityJSONError) -> [String] {
        let values = try array(key)
        var result: [String] = []
        result.reserveCapacity(values.count)
        for (index, value) in values.enumerated() {
            guard let text = JSONValue.string(value) else {
                throw mismatch("\(key)[\(index)]", "a string", value)
            }
            result.append(text)
        }
        return result
    }

    /// The enum case whose raw value is the string under `key`.
    func enumValue<T: RawRepresentable & CaseIterable>(
        _ key: String, _: T.Type = T.self
    ) throws(EntityJSONError) -> T where T.RawValue == String {
        try Self.enumCase(try string(key), at: "\(entity).\(key)")
    }

    /// The set of enum cases named by the array of strings under `key`.
    /// Duplicates are tolerated (they collapse in the set).
    func enumSet<T: RawRepresentable & CaseIterable & Hashable>(
        _ key: String, _: T.Type = T.self
    ) throws(EntityJSONError) -> Set<T> where T.RawValue == String {
        var result = Set<T>()
        for (index, name) in try stringList(key).enumerated() {
            result.insert(try Self.enumCase(name, at: "\(entity).\(key)[\(index)]"))
        }
        return result
    }

    /// The nested object under `key`, named `entity` in messages.
    func object(_ key: String, entity nested: String) throws(EntityJSONError) -> JSONFields {
        try JSONFields(map[key], entity: "\(entity).\(nested)")
    }

    private func typed<T>(
        _ key: String, _ expected: String, _ read: (Any?) -> T?
    ) throws(EntityJSONError) -> T {
        guard let value = read(map[key]) else { throw mismatch(key, expected, map[key]) }
        return value
    }

    private func mismatch(_ path: String, _ expected: String, _ value: Any?) -> EntityJSONError {
        EntityJSONError(
            message: "\(entity).\(path): expected \(expected), got \(JSONValue.describe(value))")
    }

    /// The case of `T` whose raw value is exactly `name` (case-sensitive).
    static func enumCase<T: RawRepresentable & CaseIterable>(
        _ name: String, at location: String
    ) throws(EntityJSONError) -> T where T.RawValue == String {
        guard let value = T(rawValue: name) else {
            let allowed = T.allCases.map(\.rawValue).joined(separator: ", ")
            throw EntityJSONError(
                message: "\(location): unknown value \"\(name)\" (allowed: \(allowed))")
        }
        return value
    }
}
