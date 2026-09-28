import 'package:kya_core/src/domain/dish_tags.dart';
import 'package:kya_core/src/domain/recipe_ingredient.dart';
import 'package:kya_core/src/domain/tag_enums.dart';
import 'package:meta/meta.dart';

enum RecipeSource { seed, user }

/// A dish: everything needed to decide whether to recommend it, show it in
/// the swipe deck, and cook it.
@immutable
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.mealTypes,
    required this.minutes,
    required this.base,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.source,
    this.imageAsset,
    this.isFavorite = false,
    this.isHidden = false,
  });

  final String id;
  final String name;

  /// Which meal slots this dish fits — a breakfast dish can also be a snack,
  /// etc., so this is a set, not a single value.
  final Set<MealType> mealTypes;

  final int minutes;
  final DishBase base;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final DishTags tags;

  /// `null` until milestone M2 seeds real assets — the UI falls back to a
  /// generated gradient+initial card rather than blocking on this
  /// (`AGENTS.md` section 5.6).
  final String? imageAsset;

  final bool isFavorite;

  /// "Never show" (`docs/design/RECOMMENDER.md` section 2) — excluded from
  /// every deck until un-hidden in Settings.
  final bool isHidden;

  final RecipeSource source;

  /// Non-optional ingredients only — the ones that count toward "missing".
  Iterable<RecipeIngredient> get requiredIngredients =>
      ingredients.where((i) => !i.isOptional);

  Recipe copyWith({
    String? id,
    String? name,
    Set<MealType>? mealTypes,
    int? minutes,
    DishBase? base,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    DishTags? tags,
    Object? imageAsset = _unset,
    bool? isFavorite,
    bool? isHidden,
    RecipeSource? source,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      mealTypes: mealTypes ?? this.mealTypes,
      minutes: minutes ?? this.minutes,
      base: base ?? this.base,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      imageAsset: identical(imageAsset, _unset)
          ? this.imageAsset
          : imageAsset as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      isHidden: isHidden ?? this.isHidden,
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) => other is Recipe && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Recipe($id, $name)';
}

const Object _unset = Object();
