/// Thrown when bundled seed JSON (the manifest or one of its fragments)
/// is structurally invalid: a wrong type, a missing, unknown or forbidden
/// key, an unknown enum value, or an id declared twice.
///
/// Seed data ships inside the app, so this is a build-time authoring error
/// caught by `test/seed/`, never something a user can cause. [location]
/// points at the offending value, e.g.
/// `recipes/sabzi.json › recipes[3].tags.region`, so the fix is obvious.
class SeedFormatException implements Exception {
  /// Creates an exception for the value at [location].
  const SeedFormatException(this.location, this.message);

  /// File path (relative to `assets/seed/`), optionally followed by
  /// ` › ` and a JSON path inside that file.
  final String location;

  /// What is wrong with the value, e.g.
  /// `unknown value "nort" (allowed: north, south, …)`.
  final String message;

  @override
  String toString() => 'SeedFormatException: $location: $message';
}
