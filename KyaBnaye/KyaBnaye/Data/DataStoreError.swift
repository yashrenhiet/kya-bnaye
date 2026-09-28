import Foundation

/// A failure of the on-device data store, typed so the launch flow can offer the right
/// recovery instead of crashing.
enum DataStoreError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The persistent store could not be opened: a corrupt or unreadable file, a failed
    /// schema migration, or a location that cannot be created. Recoverable by resetting
    /// the store (the broken files are moved aside, never silently deleted).
    case storeUnavailable(reason: String)

    /// A stored row holds a value this build cannot map to or from its `KyaCore` type
    /// (e.g. an enum raw value written by a newer build). Nothing was written.
    case recordMappingFailed(entity: String, id: String, field: String)

    /// Moving an unreadable store aside failed; the files are left where they were.
    case resetFailed(reason: String)

    /// A developer-facing summary; user-facing copy lives in the launch views.
    var description: String {
        switch self {
        case .storeUnavailable(let reason):
            "The data store could not be opened: \(reason)"
        case .recordMappingFailed(let entity, let id, let field):
            "Stored \(entity) \"\(id)\" has an unreadable \(field)"
        case .resetFailed(let reason):
            "The data store could not be reset: \(reason)"
        }
    }
}
