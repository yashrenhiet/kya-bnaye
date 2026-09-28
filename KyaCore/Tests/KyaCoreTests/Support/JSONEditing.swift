import Foundation
import Testing

/// In-place editing of nested `JSONSerialization`-style documents, standing
/// in for the Dart tests' mutation of decoded `Map`/`List` values.
extension Dictionary where Key == String, Value == Any {
    /// Edits the object stored under `key`.
    mutating func edit(_ key: String, _ body: (inout [String: Any]) -> Void) {
        var object = self[key] as? [String: Any] ?? [:]
        body(&object)
        self[key] = object
    }

    /// Edits the object at `index` of the array stored under `key`.
    mutating func edit(_ key: String, at index: Int, _ body: (inout [String: Any]) -> Void) {
        var array = self[key] as? [Any] ?? []
        var object = array[index] as? [String: Any] ?? [:]
        body(&object)
        array[index] = object
        self[key] = array
    }

    /// Appends `element` to the array stored under `key`.
    mutating func append(_ element: Any, to key: String) {
        var array = self[key] as? [Any] ?? []
        array.append(element)
        self[key] = array
    }

    /// The object at `index` of the array under `key`.
    func object(_ key: String, at index: Int = 0) throws -> [String: Any] {
        let array = try #require(self[key] as? [Any])
        return try #require(array[index] as? [String: Any])
    }
}

/// JSON text helpers for tests.
enum JSONText {
    /// Parses `data` as a JSON object.
    static func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Serialises `object` (which must be valid JSON) and parses it back, so
    /// every number and boolean is exactly what `JSONSerialization` produces.
    static func roundTrip(_ object: Any) throws -> Any {
        try JSONSerialization.jsonObject(
            with: try JSONSerialization.data(withJSONObject: object), options: [.fragmentsAllowed])
    }

    /// UTF-8 bytes of `text`.
    static func data(_ text: String) -> Data { Data(text.utf8) }
}
