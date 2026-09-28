/// Thrown when bundled seed JSON (the manifest or one of its fragments) is
/// structurally invalid: not JSON, a wrong type, a missing, unknown or
/// forbidden key, an unknown or repeated enum value, or an id declared twice.
///
/// Seed data ships inside the app, so this is an authoring error caught by
/// the seed-asset tests, never something a user can cause. ``location``
/// points at the offending value, e.g.
/// `recipes/sabzi.json › recipes[3].tags.region`, so the fix is obvious.
public struct SeedFormatError: Error, Sendable, Hashable, CustomStringConvertible {
    /// Separator between the file path and the JSON path in a ``location``.
    public static let locationSeparator = " › "

    /// File path (relative to `seed/`), optionally followed by
    /// ``locationSeparator`` and a JSON path inside that file.
    public let location: String

    /// What is wrong with the value, e.g.
    /// `unknown value "nort" (allowed: north, south, …)`.
    public let message: String

    /// Creates an error for the value at `location`.
    ///
    /// - Parameters:
    ///   - location: File path, optionally with a JSON path.
    ///   - message: What is wrong.
    public init(location: String, message: String) {
        self.location = location
        self.message = message
    }

    /// `SeedFormatError: <location>: <message>`.
    public var description: String { "SeedFormatError: \(location): \(message)" }

    /// `file` alone, or `file › path` when `path` is non-empty.
    static func location(file: String, path: String) -> String {
        path.isEmpty ? file : file + locationSeparator + path
    }
}
