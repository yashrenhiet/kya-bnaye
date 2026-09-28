import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/ranking_context.dart';
import 'package:meta/meta.dart';

/// A dish's score, eligibility, and the one-line reason to show on its card
/// (`docs/design/RECOMMENDER.md` section 6 — every card explains itself).
@immutable
class ScoredRecipe {
  const ScoredRecipe({
    required this.recipe,
    required this.score,
    required this.explanation,
    required this.missingIngredientIds,
    this.tier,
    this.isExplore = false,
  });

  final Recipe recipe;
  final double score;
  final String explanation;

  /// Non-optional ingredients not currently available. Empty for a
  /// "ready now" recipe.
  final List<String> missingIngredientIds;

  /// Kitchen-mode-only badge (Ready now / Missing 1 / Missing 2 / Use it
  /// up). `null` for Craving-mode results, which use free-text explanations
  /// instead of a fixed badge (`docs/design/RECOMMENDER.md` sections 5–6).
  final RecipeTier? tier;

  /// Set by `DeckBuilder`, never by a [RankingStrategy] itself — whether
  /// this card was chosen to broaden the deck rather than for its raw score
  /// (`docs/design/RECOMMENDER.md` section 4, "Exploration").
  final bool isExplore;

  ScoredRecipe copyWith({String? explanation, bool? isExplore}) {
    return ScoredRecipe(
      recipe: recipe,
      score: score,
      explanation: explanation ?? this.explanation,
      missingIngredientIds: missingIngredientIds,
      tier: tier,
      isExplore: isExplore ?? this.isExplore,
    );
  }
}

/// Kitchen mode's fixed badge set, in the display-priority order the deck
/// should surface them in ("expiring-use cards first, then ready, then
/// almost" — `docs/design/RECOMMENDER.md` section 5).
enum RecipeTier { useItUp, readyNow, missing1, missing2 }

/// One of the two ranking strategies behind the shared swipe deck
/// (`docs/design/RECOMMENDER.md` section 1, ADR 007).
abstract interface class RankingStrategy {
  /// Scores [recipe] against [context]. Returns `null` if the recipe should
  /// be excluded from this deck entirely — e.g. Kitchen mode's hard
  /// "more than 2 missing" filter, or either mode's shared reject/never-show
  /// exclusion (see [isHardExcluded]).
  ScoredRecipe? score(Recipe recipe, RankingContext context);

  /// Whether `DeckBuilder` should reserve part of the deck for low-evidence
  /// "explore" picks under this strategy. Kitchen mode answers `false` — a
  /// dish you can't cook isn't a valid exploration pick, there's no filter
  /// bubble to break out of when the pantry itself is the hard constraint.
  bool get supportsExploration;
}

/// Exclusions both rankers must respect before computing a score at all.
///
/// A `neverShow` swipe is checked against **both** the derived event log
/// (`context.neverShownRecipeIds`, ADR 008's source of truth) and
/// `recipe.isHidden` (a durable flag a future Settings screen could also
/// set directly, without going through a swipe) — either one is enough to
/// exclude the recipe.
///
/// The *recent left-swipe* exclusion (`docs/design/RECOMMENDER.md` section
/// 5, "≤3d excluded") is deliberately **not** duplicated here — it shares
/// its day-threshold with `Penalties.rejectPenalty`'s scoring-window logic,
/// so each ranker checks it via that single function (a `null` return means
/// excluded) instead of two places encoding the same threshold.
bool isHardExcluded(Recipe recipe, RankingContext context) {
  return recipe.isHidden || context.neverShownRecipeIds.contains(recipe.id);
}
