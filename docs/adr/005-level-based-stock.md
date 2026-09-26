# ADR 005: Level-based pantry stock (Plenty / Low / Out), not quantities

**Status:** Accepted — 2026-09-26

## Context
`docs/RESEARCH.md` identified the single biggest failure mode of prior-art pantry apps
(Grocy in particular): tracking exact quantities and units is accurate but has enough
data-entry friction that users stop updating it within days, which then makes every
downstream recommendation stale and untrustworthy.

## Decision
Pantry items track a coarse **`level` enum: `plenty | low | out`**, not a numeric quantity
+ unit. Expiry is a single optional date, auto-estimated from the ingredient's typical
shelf life rather than requiring manual entry.

## Alternatives considered
- **Exact quantity + unit** (Grocy's model) — most accurate input to a recommender in
  theory, but the research showed it's the reason users abandon this class of app.
- **Binary have/don't-have** — simpler still, but loses the "about to run out, add to
  shopping list soon" signal that `low` provides, and can't distinguish "half a bag of
  onions" from "one onion left" for recipe planning.

## Consequences
- The recommender (`docs/design/RECOMMENDER.md`) scores on availability and role weight,
  never on exact amounts — a recipe needing "2 onions" and one needing "half an onion"
  are treated identically once the ingredient is marked available.
- Logging stays a single tap to cycle `plenty → low → out`, matching the "near-zero
  effort" design principle in `AGENTS.md` §1.
- If a future version needs real quantities (e.g. for portion scaling), it's an additive
  optional field, not a breaking change to the existing `level` semantics.
