import 'package:kya_core/src/domain/tag_enums.dart';
import 'package:meta/meta.dart';

/// A record that a recipe was actually cooked. The strongest signal
/// (`docs/design/RECOMMENDER.md` section 4: +1.5, stronger than any swipe)
/// because it's revealed preference, not just intent.
@immutable
class MealLog {
  const MealLog({
    required this.id,
    required this.recipeId,
    required this.mealType,
    required this.cookedAt,
  });

  final String id;
  final String recipeId;
  final MealType mealType;
  final DateTime cookedAt;

  @override
  bool operator ==(Object other) =>
      other is MealLog &&
      other.id == id &&
      other.recipeId == recipeId &&
      other.mealType == mealType &&
      other.cookedAt == cookedAt;

  @override
  int get hashCode => Object.hash(id, recipeId, mealType, cookedAt);
}
