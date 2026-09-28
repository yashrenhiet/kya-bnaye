/// Why ``BackupCodec`` could not restore a file: it is not a backup this app
/// can read — not JSON, a newer (or invalid) schema version, or structurally
/// broken data.
///
/// Callers surface this as a user-facing error, never a crash (`AGENTS.md`
/// section 0: errors are handled, not swallowed). Decoding never returns
/// partial data: any problem anywhere in the file throws.
public enum BackupFormatError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The bytes are not a JSON document whose root is an object. `detail`
    /// says what was found instead.
    case notAJSONObject(detail: String)

    /// `version` is missing, not an integer, below 1 or newer than
    /// ``BackupCodec/currentVersion``. `found` is the value as written
    /// (`null` when missing).
    case unsupportedVersion(found: String)

    /// A top-level entity section is missing or not an array. `found` is a
    /// short JSON type name such as `Null` or `Object`.
    case sectionNotAList(section: String, found: String)

    /// An entity inside a section is malformed: a missing required field, a
    /// wrong JSON type, an unknown enum value, an unparsable timestamp, or a
    /// shopping item with neither an ingredient id nor a custom name.
    /// `detail` names the entity and field.
    case malformed(detail: String)

    /// Human-readable explanation, worded like the Dart oracle's
    /// `BackupFormatException.message` (e.g. `Expected a list, got Null`).
    public var message: String {
        switch self {
        case .notAJSONObject(let detail):
            return "Not a backup file: \(detail)"
        case .unsupportedVersion(let found):
            return "Unsupported backup version: \(found) (this app supports up to "
                + "\(BackupCodec.currentVersion)). Update the app before restoring this file."
        case .sectionNotAList(_, let found):
            return "Expected a list, got \(found)"
        case .malformed(let detail):
            return "Malformed backup data: \(detail)"
        }
    }

    /// `BackupFormatError: ` followed by ``message``.
    public var description: String { "BackupFormatError: \(message)" }
}

/// Why ``BackupCodec/encode(_:exportedAt:)`` could not write a backup.
///
/// Only reachable with dates that no real clock produces (non-finite, or
/// more than about 275,000 years from 1970), which could never be read back.
public enum BackupEncodingError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The timestamp at `field` (e.g. `mealLogs[3].cookedAt`) cannot be
    /// written as ISO-8601.
    case unrepresentableDate(field: String)

    /// `JSONSerialization` rejected the document; `detail` is its message.
    case serializationFailed(detail: String)

    /// Human-readable explanation naming the offending field.
    public var description: String {
        switch self {
        case .unrepresentableDate(let field):
            return "BackupEncodingError: \(field) is not a representable date"
        case .serializationFailed(let detail):
            return "BackupEncodingError: \(detail)"
        }
    }
}
