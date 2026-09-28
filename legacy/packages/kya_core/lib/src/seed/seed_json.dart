/// Strict, location-aware reading of decoded seed JSON.
///
/// Internal to `kya_core` (not exported). Every accessor checks the JSON
/// type before reading, so malformed seed data always surfaces as a
/// [SeedFormatException] naming the exact file and JSON path, never as a
/// raw [TypeError].
library;

import 'package:kya_core/src/seed/seed_format_exception.dart';

/// Separator between the file path and the JSON path in a location.
const String seedLocationSeparator = ' › ';

/// A JSON object found at [path] inside the seed file [file].
///
/// Accessing a nested object through [object] or [objects] also replaces
/// it in [json] with its checked, `String`-keyed copy, so once every field
/// has been read [json] is safe to hand to the shared entity mappers.
final class SeedJsonObject {
  SeedJsonObject._(this.file, this.path, this._map);

  /// Wraps [value], which must be a JSON object with string keys.
  factory SeedJsonObject.from(
    Object? value, {
    required String file,
    String path = '',
  }) {
    final location = seedLocation(file, path);
    if (value is! Map) {
      throw SeedFormatException(
        location,
        'expected an object, got ${describeJson(value)}',
      );
    }
    final map = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw SeedFormatException(location, 'object key $key is not a string');
      }
      map[key] = entry.value;
    }
    return SeedJsonObject._(file, path, map);
  }

  /// Seed file path, relative to `assets/seed/`.
  final String file;

  /// JSON path of this object inside [file]; empty for the root.
  final String path;

  final Map<String, Object?> _map;

  /// The checked map (see the class docs for when nested values are
  /// replaced by their checked copies).
  Map<String, Object?> get json => _map;

  /// Location of this object, for error messages.
  String get location => seedLocation(file, path);

  /// Location of the value under [key].
  String locationOf(String key) => seedLocation(file, _child(key));

  String _child(String key) => path.isEmpty ? key : '$path.$key';

  /// Rejects [forbidden] keys first, then any key outside [required] and
  /// [optional], then any missing [required] key.
  void checkKeys({
    required List<String> required,
    List<String> optional = const [],
    Set<String> forbidden = const {},
  }) {
    for (final key in _map.keys) {
      if (forbidden.contains(key)) {
        throw SeedFormatException(
          locationOf(key),
          'key "$key" is not allowed in seed data (the app sets it)',
        );
      }
    }
    final allowed = [...required, ...optional];
    for (final key in _map.keys) {
      if (!allowed.contains(key)) {
        throw SeedFormatException(
          locationOf(key),
          'unknown key "$key" (allowed: ${allowed.join(', ')})',
        );
      }
    }
    for (final key in required) {
      if (!_map.containsKey(key)) {
        throw SeedFormatException(location, 'missing required key "$key"');
      }
    }
  }

  /// The string under [key].
  String string(String key) => _typed<String>(key, 'a string');

  /// The string under [key], or `null` if absent or `null`.
  String? optionalString(String key) => _map[key] == null ? null : string(key);

  /// The integer under [key] (`21.0` is rejected: it is not an integer).
  int integer(String key) => _typed<int>(key, 'an integer');

  /// The integer under [key], or `null` if absent or `null`.
  int? optionalInteger(String key) => _map[key] == null ? null : integer(key);

  /// The boolean under [key], or `null` if absent. An explicit `null` is
  /// rejected: omit the key instead.
  bool? optionalBool(String key) =>
      _map.containsKey(key) ? _typed<bool>(key, 'a boolean') : null;

  /// The array under [key].
  List<Object?> list(String key) => _typed<List<Object?>>(key, 'an array');

  /// The array of strings under [key].
  List<String> stringList(String key) {
    final values = list(key);
    return [
      for (var i = 0; i < values.length; i++)
        _element<String>(key, i, values[i], 'a string'),
    ];
  }

  /// The [values] entry named by the string under [key].
  T enumValue<T extends Enum>(String key, List<T> values) =>
      _enum(locationOf(key), string(key), values);

  /// The distinct [values] entries named by the array under [key].
  List<T> enumList<T extends Enum>(String key, List<T> values) {
    final names = stringList(key);
    final result = <T>[];
    for (var i = 0; i < names.length; i++) {
      final location = seedLocation(file, '${_child(key)}[$i]');
      final value = _enum(location, names[i], values);
      if (result.contains(value)) {
        throw SeedFormatException(location, 'duplicate value "${names[i]}"');
      }
      result.add(value);
    }
    return result;
  }

  /// The nested object under [key].
  SeedJsonObject object(String key) {
    final child = SeedJsonObject.from(_map[key], file: file, path: _child(key));
    _map[key] = child._map;
    return child;
  }

  /// The array of objects under [key].
  List<SeedJsonObject> objects(String key) {
    final values = list(key);
    final children = [
      for (var i = 0; i < values.length; i++)
        SeedJsonObject.from(values[i], file: file, path: '${_child(key)}[$i]'),
    ];
    _map[key] = [for (final c in children) c._map];
    return children;
  }

  T _typed<T>(String key, String expected) {
    final value = _map[key];
    if (value is T) return value;
    throw SeedFormatException(
      locationOf(key),
      'expected $expected, got ${describeJson(value)}',
    );
  }

  T _element<T>(String key, int index, Object? value, String expected) {
    if (value is T) return value;
    throw SeedFormatException(
      seedLocation(file, '${_child(key)}[$index]'),
      'expected $expected, got ${describeJson(value)}',
    );
  }

  static T _enum<T extends Enum>(String location, String name, List<T> all) {
    final value = all.asNameMap()[name];
    if (value != null) return value;
    final allowed = all.map((v) => v.name).join(', ');
    throw SeedFormatException(
      location,
      'unknown value "$name" (allowed: $allowed)',
    );
  }
}

/// `file` alone, or `file › path` when [path] is non-empty.
String seedLocation(String file, String path) =>
    path.isEmpty ? file : '$file$seedLocationSeparator$path';

/// Short human description of a decoded JSON value for error messages.
String describeJson(Object? value) => switch (value) {
  null => 'null',
  String() => 'a string ("$value")',
  bool() => 'a boolean ($value)',
  num() => 'a number ($value)',
  List<Object?>() => 'an array',
  Map<Object?, Object?>() => 'an object',
  _ => 'a ${value.runtimeType}',
};
