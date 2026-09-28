import Foundation

/// Strict readers for values produced by `JSONSerialization` (or built by hand
/// as `[String: Any]` in tests), shared by the seed and backup codecs.
///
/// `JSONSerialization` returns every number and boolean as an `NSNumber`, and
/// Swift's bridging happily casts `true` to `1`, `1` to `true` and `1.0` to
/// `1`. These helpers inspect the underlying CoreFoundation type instead, so a
/// JSON boolean is never accepted as an integer (or vice versa) and a JSON
/// `1.0` is never accepted as an integer — matching the Dart oracle, where
/// `jsonDecode` yields distinct `bool`, `int` and `double` values.
enum JSONValue {
    /// `value` as a JSON integer, or `nil` for booleans, floating-point numbers
    /// (even integral ones such as `1.0`), integers outside `Int`'s range and
    /// every non-number.
    static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, !isBoolean(number),
            !CFNumberIsFloatType(number)
        else { return nil }
        if String(cString: number.objCType) == "Q" {
            return Int(exactly: number.uint64Value)
        }
        return Int(exactly: number.int64Value)
    }

    /// `value` as a JSON boolean, or `nil` for numbers (including `0` and `1`)
    /// and every non-boolean.
    static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, isBoolean(number) else { return nil }
        return number.boolValue
    }

    /// `value` as a JSON string, or `nil` for every non-string.
    static func string(_ value: Any?) -> String? {
        value as? String
    }

    /// `value` as a JSON array, or `nil` for every non-array.
    static func array(_ value: Any?) -> [Any]? {
        value as? [Any]
    }

    /// Whether `value` is absent or JSON `null`.
    static func isNull(_ value: Any?) -> Bool {
        guard let value else { return true }
        return value is NSNull
    }

    /// Short human description of a decoded JSON value for error messages,
    /// worded like the Dart oracle's `describeJson`: `null`, `a string ("x")`,
    /// `a boolean (true)`, `a number (1.0)`, `an array`, `an object`.
    static func describe(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "null" }
        if let text = value as? String { return "a string (\"\(text)\")" }
        if let number = value as? NSNumber { return "a \(numberKind(number)) (\(text(number)))" }
        if value is [Any] { return "an array" }
        if value is [AnyHashable: Any] { return "an object" }
        return "a \(runtimeTypeName(value))"
    }

    /// Type name for backup error messages, spelled like Dart's
    /// `runtimeType` of a `jsonDecode` result: `Null`, `String`, `bool`,
    /// `int`, `double`, `List<dynamic>`, `_Map<String, dynamic>`.
    static func typeName(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "Null" }
        if value is String { return "String" }
        if let number = value as? NSNumber {
            if isBoolean(number) { return "bool" }
            return integer(number) == nil ? "double" : "int"
        }
        if value is [Any] { return "List<dynamic>" }
        if value is [AnyHashable: Any] { return "_Map<String, dynamic>" }
        return runtimeTypeName(value)
    }

    /// `value` rendered like Dart's string interpolation of a decoded JSON
    /// value: strings unquoted, `null`, `true`, `7`, `1.0`, `[1, 2]`,
    /// `{a: 1}` (object keys sorted, so the text is deterministic).
    static func text(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "null" }
        if let text = value as? String { return text }
        if let number = value as? NSNumber {
            if isBoolean(number) { return number.boolValue ? "true" : "false" }
            if let int = integer(number) { return String(int) }
            return String(number.doubleValue)
        }
        if let array = value as? [Any] {
            return "[" + array.map { text($0) }.joined(separator: ", ") + "]"
        }
        if let object = value as? [String: Any] {
            let entries = object.keys.sorted().map { "\($0): \(text(object[$0]))" }
            return "{" + entries.joined(separator: ", ") + "}"
        }
        return runtimeTypeName(value)
    }

    private static func numberKind(_ number: NSNumber) -> String {
        isBoolean(number) ? "boolean" : "number"
    }

    private static func runtimeTypeName(_ value: Any) -> String {
        "\(type(of: value))"
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
