import 'dart:math';

import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/recommend/ranking_context.dart';
import 'package:kya_core/src/recommend/ranking_strategy.dart';

/// Turns a scored candidate pool into an ordered deck of swipe cards.
///
/// `docs/design/RECOMMENDER.md` section 4: about 80% exploit (top score) /
/// 20% explore (low-evidence tags), **deterministic under a seed** so decks
/// are golden-testable and "Shuffle" is just "build again with a new seed".
/// With zero taste evidence (cold start) a craving deck is 100% explore.
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

    // Cold start (`docs/design/RECOMMENDER.md` section 4): with no taste
    // evidence at all there is nothing to exploit yet, so every card is an
    // explore card. Scores then only carry the pantry/quick/favourite
    // hints, so the deck keeps that honest order and each card keeps its
    // ranker's explanation — "Something different" would have nothing to
    // be different from.
    if (_hasNoTasteEvidence(context)) {
      return [
        for (final s in orderedByPriority.take(context.config.deckSize))
          s.copyWith(isExplore: true),
      ];
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
            explanation: 'Something different: ${s.recipe.tags.region.label}.',
          ),
        )
        .toList();

    return [...exploit, ...explore];
  }

  bool _hasNoTasteEvidence(RankingContext context) =>
      context.tasteProfile.evidence.values.every((e) => e == 0);

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
}
