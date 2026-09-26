# ADR 008: Append-only `SwipeEvent` log; `TasteProfile` is always derived, never stored

**Status:** Accepted — 2026-09-26 · **Implemented:** milestone M1

## Context
The taste profile that drives Craving mode (ADR 007) needs to: (a) decay old signals over
time, (b) be resettable ("Reset my taste" in Settings), (c) never silently drift out of
sync with the actual swipe/cook history, and (d) eventually be replayable/sync-able across
devices (v2 household sync).

## Decision
Every swipe (right/left/never-show/undo) is recorded as an immutable `SwipeEvent` row —
the log is **append-only**, undo is a new event that references the previous one, not a
delete. `TasteProfile` is computed as a **pure function** of
`(List<SwipeEvent>, List<MealLog>, DateTime now)` — it is never persisted as its own
table/row.

## Alternatives considered
- **Store a mutable `TasteProfile` row, updated incrementally on each swipe** — faster to
  read, but introduces a second source of truth that can drift from the event history
  (e.g. after a bug fix to the decay formula, old profiles would be silently wrong until
  recomputed). Also makes "Reset my taste" and "replay history with new scoring weights"
  much harder.
- **Delete events on undo** — simpler, but loses the audit trail and makes "what did the
  app show me and what did I actually do" impossible to answer later, which matters for
  debugging a "the app got my taste wrong" complaint.

## Consequences
- `TasteProfile` is trivially unit-testable: feed a fixed list of events, assert the
  resulting affinities (`docs/design/RECOMMENDER.md` §9).
- A ScoringConfig or decay-formula change takes effect retroactively for free — no
  migration needed, because nothing derived is stored.
- The event table is the natural sync unit for v2 household sharing (append-only logs
  merge far more easily than mutable rows do).
- Trade-off accepted: computing the profile is O(events), not O(1). At the realistic
  scale of this app (thousands of events per household, per `AGENTS.md` §5.6 sizing
  reasoning applied to swipes) this is sub-millisecond and not worth caching yet.
