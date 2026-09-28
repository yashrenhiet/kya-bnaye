import 'package:kya_core/src/domain/tag_enums.dart';
import 'package:kya_core/src/domain/tag_key.dart';
import 'package:meta/meta.dart';

/// Closed-enum metadata attached to every `Recipe`, used by both rankers
/// (`docs/design/RECOMMENDER.md` section 3).
@immutable
class DishTags {
  const DishTags({
    required this.region,
    required this.dishType,
    required this.flavours,
    required this.heaviness,
    required this.protein,
  });

  final Region region;
  final DishType dishType;

  /// A dish can be both spicy and tangy — this is deliberately a set, not a
  /// single value.
  final Set<Flavour> flavours;
  final Heaviness heaviness;
  final Protein protein;

  /// Every [TagKey] this dish carries, across all dimensions — the set
  /// `TasteProfile` events are folded into and craving-scored against.
  List<TagKey> get allKeys => [
    TagKey.region(region.name),
    TagKey.dishType(dishType.name),
    for (final f in flavours) TagKey.flavour(f.name),
    TagKey.heaviness(heaviness.name),
    TagKey.protein(protein.name),
  ];

  @override
  bool operator ==(Object other) =>
      other is DishTags &&
      other.region == region &&
      other.dishType == dishType &&
      other.flavours.length == flavours.length &&
      other.flavours.containsAll(flavours) &&
      other.heaviness == heaviness &&
      other.protein == protein;

  @override
  int get hashCode => Object.hash(
    region,
    dishType,
    Object.hashAllUnordered(flavours),
    heaviness,
    protein,
  );
}
