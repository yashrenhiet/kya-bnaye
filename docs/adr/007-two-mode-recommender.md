# ADR 007: Two-mode recommender (Kitchen / Craving) via a shared Strategy interface

**Status:** Accepted — 2026-09-26 · **Implemented:** milestone M1

## Context
The product needs to answer two different questions that researched prior-art apps only
ever answer one of: "what can I cook with what I have" (every pantry app in
`docs/RESEARCH.md`) versus "what would I enjoy" regardless of pantry state (no researched
app did this with a swipeable, learned-taste UI). Both need to feel like the same product,
not two bolted-together features, and both should teach each other from the same
user interactions.

## Decision
Model both modes behind one `RankingStrategy` interface (Strategy pattern):
`KitchenRanker` (pantry coverage-driven) and `CravingRanker` (learned-taste-driven), both
consuming the same shared penalty functions (repeat cooldown, left-swipe cooldown,
same-base-as-last-meal) and both feeding the same `SwipeEvent` log. Full scoring design in
`docs/design/RECOMMENDER.md`.

## Alternatives considered
- **Two entirely separate recommenders/screens** — simpler to reason about in isolation,
  but would duplicate the penalty logic and, more importantly, would only teach the taste
  profile from Craving-mode swipes, halving the learning signal and confusing users with
  two different card designs for what is conceptually "the same deck, different filter".
- **One recommender with a single blended score** (no explicit mode toggle) — rejected:
  users explicitly asked for two distinct mental models ("what can I make" vs "what do I
  feel like"), and blending them into one number would hide that distinction and make the
  per-card explanation harder to write honestly.

## Consequences
- Adding a third mode later (e.g. a "quick lunch" mode) means writing one more
  `RankingStrategy` implementation, not touching `KitchenRanker`/`CravingRanker` or the
  shared penalty functions (Open/Closed principle, `AGENTS.md` §0 Architect standards).
- Every swipe, in either mode, contributes to the one `TasteProfile` (ADR 008), so the
  app learns roughly twice as fast as a single-mode app would.
- `ScoringConfig` holds all weights for both strategies in one place, so tuning is a data
  change, not a code change (`AGENTS.md` §5.5).
