import 'dart:math' as math;

import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/active_events.dart';
import 'package:kya_core/src/recommend/scoring_config.dart';

/// A household's learned taste, expressed as an affinity score per
/// [TagKey] — e.g. "how much do they seem to like spicy food lately".
///
/// **Always derived, never persisted** (ADR 008): call [profileFrom] with
/// the full event/meal history every time a deck is built. A few thousand
/// events folds in well under a millisecond, and this is what makes "reset
/// my taste" (delete the events) and "the decay formula had a bug, fixed
/// now" retroactively correct for free — there is no separate stored
/// profile that could have drifted out of sync.
class TasteProfile {
  const TasteProfile({
    required this.affinity,
    required this.evidence,
    required this.config,
  });

  /// Raw, decay-weighted sum of signed signal weights per tag. Not squashed
  /// to a fixed range — see [normalised] for that.
  final Map<TagKey, double> affinity;

  /// Sum of *unsigned* decay-weighted signal weights per tag — how much
  /// evidence exists either way, used by the deck builder to find
  /// under-explored tags rather than tags the household actively dislikes.
  final Map<TagKey, double> evidence;

  final ScoringConfig config;

  /// [affinity] squashed to (-1, 1) via `tanh(affinity / divisor)`, per
  /// `docs/design/RECOMMENDER.md` section 4. Zero for a tag with no
  /// evidence at all, which reads correctly as "neutral, unknown".
  double normalised(TagKey key) =>
      _tanh((affinity[key] ?? 0) / config.tasteNormaliseDivisor);

  double evidenceFor(TagKey key) => evidence[key] ?? 0;

  static double _tanh(double x) {
    final e2x = math.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }
}

/// Folds [events] and [mealLogs] into a [TasteProfile] as of [now].
///
/// Onboarding's "pick 5 dishes you love" step is deliberately **not** a
/// separate code path here: `docs/design/RECOMMENDER.md` gives it the same
/// +1.0 weight as an ordinary right swipe, so it's simplest — and least
/// likely to drift out of sync — to just record it as a [SwipeAction.right]
/// event with [SwipeMode.craving] at capture time, rather than duplicating
/// the fold logic for a fourth signal type.
TasteProfile profileFrom({
  required List<SwipeEvent> events,
  required List<MealLog> mealLogs,
  required Map<String, Recipe> recipesById,
  required DateTime now,
  ScoringConfig config = const ScoringConfig(),
}) {
  final affinity = <TagKey, double>{};
  final evidence = <TagKey, double>{};

  void fold(String recipeId, double weight, DateTime at) {
    final recipe = recipesById[recipeId];
    // A recipe the user later deleted still happened, historically, but has
    // no tags left to fold into — skip gracefully rather than throw.
    if (recipe == null) return;
    final decay = _decay(at, now, config.tasteDecayHalfLifeDays);
    final decayed = weight * decay;
    for (final key in recipe.tags.allKeys) {
      affinity[key] = (affinity[key] ?? 0) + decayed;
      evidence[key] = (evidence[key] ?? 0) + decayed.abs();
    }
  }

  for (final event in activeEvents(events)) {
    switch (event.action) {
      case SwipeAction.right:
        fold(event.recipeId, config.signalWeightRightSwipe, event.at);
      case SwipeAction.left:
        fold(event.recipeId, config.signalWeightLeftSwipe, event.at);
      case SwipeAction.neverShow:
        fold(event.recipeId, config.signalWeightNeverShow, event.at);
      case SwipeAction.undo:
        break; // unreachable: activeEvents() already strips undo events
    }
  }

  for (final log in mealLogs) {
    fold(log.recipeId, config.signalWeightCooked, log.cookedAt);
  }

  return TasteProfile(affinity: affinity, evidence: evidence, config: config);
}

double _decay(DateTime at, DateTime now, int halfLifeDays) {
  final ageDays = now.difference(at).inHours / 24.0;
  if (ageDays <= 0) return 1;
  return math.pow(0.5, ageDays / halfLifeDays).toDouble();
}

/// The weighted mean of [profile]'s normalised affinity across every tag
/// dimension of [tags], per `docs/design/RECOMMENDER.md` section 4's
/// "Craving score" formula. Shared by `KitchenRanker` (a small nudge) and
/// `CravingRanker` (the dominant term) so the definition of "how much does
/// this household's taste favour this dish" cannot drift between the two.
double tasteScoreFor(
  DishTags tags,
  TasteProfile profile,
  ScoringConfig config,
) {
  final flavourMean = tags.flavours.isEmpty
      ? 0.0
      : tags.flavours
                .map((f) => profile.normalised(TagKey.flavour(f.name)))
                .reduce((a, b) => a + b) /
            tags.flavours.length;

  return config.taggedRegionWeight *
          profile.normalised(TagKey.region(tags.region.name)) +
      config.taggedDishTypeWeight *
          profile.normalised(TagKey.dishType(tags.dishType.name)) +
      config.taggedFlavourWeight * flavourMean +
      config.taggedHeavinessWeight *
          profile.normalised(TagKey.heaviness(tags.heaviness.name)) +
      config.taggedProteinWeight *
          profile.normalised(TagKey.protein(tags.protein.name));
}
