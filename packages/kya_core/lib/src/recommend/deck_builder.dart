import 'dart:math';

import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/ranking_context.dart';
import 'package:kya_core/src/recommend/ranking_strategy.dart';

/// Turns a scored candidate pool into an ordered deck of swipe cards.
///
/// `docs/design/RECOMMENDER.md` section 4: about 80% exploit (top score) /
/// 20% explore (low-evidence tags), **deterministic under a seed** so decks
/// are golden-testable and "Shuffle" is just "build again with a new seed".
class DeckBuilder {
  const DeckBuilder();

  List<ScoredRecipe> build({
    required List<Recipe> candidates,
    required RankingContext context,
    required RankingStrategy strategy,
    required int seed,
  }) {
    final scored = <ScoredRecipe>[
      for (final recipe in candidates) ?strategy.score(recipe, context),
    ];
    if (scored.isEmpty) return const [];

    final orderedByPriority = _sortForDisplay(scored);

    if (!strategy.supportsExploration) {
      return orderedByPriority.take(context.config.deckSize).toList();
    }

    final exploreCount =
        (context.config.deckSize * context.config.deckExploreFraction).round();
    final exploitCount = context.config.deckSize - exploreCount;

    final exploit = orderedByPriority.take(exploitCount).toList();
    final exploitIds = exploit.map((s) => s.recipe.id).toSet();

    // Deterministic tie-breaking shuffle before sorting by evidence, so two
    // equally-under-explored dishes don't always appear in the same order —
    // "Shuffle" changing the seed is meant to feel different each time.
    final explorePool =
        orderedByPriority
            .where((s) => !exploitIds.contains(s.recipe.id))
            .toList()
          ..shuffle(Random(seed))
          ..sort(
            (a, b) =>
                _evidenceOf(a, context).compareTo(_evidenceOf(b, context)),
          );

    final explore = explorePool
        .take(exploreCount)
        .map(
          (s) => s.copyWith(
            isExplore: true,
            explanation: 'Something different: ${_headlineTag(s.recipe)}.',
          ),
        )
        .toList();

    return [...exploit, ...explore];
  }

  double _evidenceOf(ScoredRecipe scored, RankingContext context) {
    var total = 0.0;
    for (final key in scored.recipe.tags.allKeys) {
      total += context.tasteProfile.evidenceFor(key);
    }
    return total;
  }

  /// Kitchen mode has a fixed tier display order regardless of raw score
  /// noise ("expiring-use cards first, then ready, then almost" —
  /// `docs/design/RECOMMENDER.md` section 5). Craving-mode results have no
  /// tier, so they fall through to plain score-descending order.
  List<ScoredRecipe> _sortForDisplay(List<ScoredRecipe> scored) {
    final sorted = [...scored]
      ..sort((a, b) {
        final tierCompare = _tierPriority(
          a.tier,
        ).compareTo(_tierPriority(b.tier));
        if (tierCompare != 0) return tierCompare;
        return b.score.compareTo(a.score);
      });
    return sorted;
  }

  int _tierPriority(RecipeTier? tier) => switch (tier) {
    RecipeTier.useItUp => 0,
    RecipeTier.readyNow => 1,
    RecipeTier.missing1 => 2,
    RecipeTier.missing2 => 3,
    null => 99,
  };

  String _headlineTag(Recipe recipe) => recipe.tags.region.name;
}
