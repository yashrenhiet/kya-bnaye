import 'package:meta/meta.dart';

/// Which "axis" of recipe metadata a [TagKey] belongs to.
///
/// Kept separate from the tag's own enum type so `TasteProfile`
/// (`docs/design/RECOMMENDER.md` section 4) can hold affinities for tags
/// from every dimension in a single `Map<TagKey, double>` without needing
/// five parallel maps.
enum TagDimension { region, dishType, flavour, heaviness, protein }

/// A single point of taste evidence: one value from one [TagDimension],
/// e.g. `TagKey(TagDimension.region, 'south')`.
///
/// Built via the typed factories below rather than a raw constructor call
/// at use sites, so a call site can never accidentally pair the wrong enum's
/// `.name` with the wrong [TagDimension].
@immutable
class TagKey {
  const TagKey._(this.dimension, this.value);

  factory TagKey.region(String regionName) =>
      TagKey._(TagDimension.region, regionName);
  factory TagKey.dishType(String dishTypeName) =>
      TagKey._(TagDimension.dishType, dishTypeName);
  factory TagKey.flavour(String flavourName) =>
      TagKey._(TagDimension.flavour, flavourName);
  factory TagKey.heaviness(String heavinessName) =>
      TagKey._(TagDimension.heaviness, heavinessName);
  factory TagKey.protein(String proteinName) =>
      TagKey._(TagDimension.protein, proteinName);

  final TagDimension dimension;

  /// The specific enum value's `.name`, e.g. `'south'`, `'spicy'`.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is TagKey && other.dimension == dimension && other.value == value;

  @override
  int get hashCode => Object.hash(dimension, value);

  @override
  String toString() => '${dimension.name}:$value';
}
