# Recommendation Engine: Kitchen Mode and Craving Mode

> Status: Draft for review · Date: 2026-09-26 · Parent: `docs/PLAN.md` section 4.5
> Everything in this document lives in the pure-Dart `kya_core` package: no Flutter, no DB.

## 1. Two modes, one engine

| | **Kitchen mode** ("What can I make?") | **Craving mode** ("What do I feel like?") |
|---|---|---|
| Question answered | What can I cook **with what's at home**? | What would I **enjoy**, whether or not it's at home? |
| Primary signal | Pantry coverage + expiry | Taste profile learned from swipes |
| Pantry role | Hard driver (filters + score) | Soft hint only (badge + small bonus) |
| Right swipe leads to | Cook now (usually 0–2 missing) | Recipe + "add missing to shopping list" |
| UI | Swipe deck (shared component) | Swipe deck (shared component) |

**Default:** the app always opens in **Kitchen mode** (decision D5). Craving is one tap away.

**Design decision: both modes use the same swipe deck and the same feedback loop.**
Every swipe in either mode teaches the taste profile. One UI component, one event stream,
two ranking strategies (Strategy pattern). This keeps things DRY and gives twice the learning data.

```
                 ┌──────────────── RankingStrategy (interface) ───────────────┐
                 │                                                             │
         KitchenRanker                                               CravingRanker
   (coverage, expiry, tiers)                                  (taste affinity, exploration)
                 │                                                             │
                 └──────────► shared: Penalties (repeat, reject cooldown) ◄────┘
                                          │
                                    DeckBuilder  →  List<SwipeCard>
                                          ▲
                        SwipeEvents ──► TasteProfile (derived)
```

## 2. Swipe semantics

| Gesture | Button (required for a11y) | Meaning | Effect |
|---|---|---|---|
| Swipe right | **Want this** | "I want to eat this" | Adds to **Today's picks**, opens the pick sheet, +1.0 taste signal |
| Swipe left | **Not today** | Soft reject, *not* hate | Hidden for 3 days, down-ranked for 14 days, −0.4 taste signal |
| (none) | **Never show** (card overflow menu) | Hard reject | Recipe excluded until un-hidden in Settings, −3.0 signal on its tags |
| (none) | **Undo** | Mis-swipe | Reverts the last event (last 1 event, current session) |
| Tap card | — | Open details | No signal |

Why left is weak: "not today" usually means "had it yesterday" or "too heavy tonight",
not "I dislike paneer". Treating left as a strong negative would quickly make the profile
too narrow. The asymmetry is intentional and tunable.

### After a right swipe: the pick sheet
```
Picked: Palak Paneer
You have 5 of 7 ingredients.  Missing: paneer, kasuri methi
[ View recipe ]  [ Add missing to shopping list ]  [ Keep swiping ]
```
- **Today's picks** is a small tray on the home screen (the shortlist from this session).
  Picking one and tapping **I made this** logs the meal (existing F5 flow).
- Picks expire at the end of the day. No planner in v1 (YAGNI).

## 3. Dish attributes (new recipe metadata)

The taste model needs tags. Every recipe gets:
```
tags:
  region:    north | south | east | west | gujarati | punjabi | indo-chinese | continental | street
  dishType:  dal | curry | dry-sabzi | rice | bread | breakfast | snack | sweet | one-pot
  flavours:  set of { spicy, tangy, sweet, savoury, mild }
  heaviness: light | medium | heavy
  protein:   paneer | dal-legume | egg | chicken | mutton | fish | veg-only   (tag only; diet filtering is v2)
image:       bundled asset (webp) or generated placeholder card
```
Tags are **closed enums** validated by the seed-data tests. No free text, so no tag drift.

## 4. Taste profile (derived, not stored)

**Decision: the profile is a pure function of the event history.**
`TasteProfile profileFrom(List<SwipeEvent> events, List<MealLog> meals, DateTime now)`.
- Single source of truth (events), no stale cached profile, trivially testable, and
  "reset my taste" means deleting events. A few thousand events is sub-millisecond to fold.
- Add a cache only if profiling shows a need.

### Signals
| Event | Weight |
|---|---|
| Right swipe | +1.0 |
| Cooked ("I made this") | +1.5 (strongest: revealed preference) |
| Left swipe | −0.4 |
| Never show | −3.0 |
| Onboarding "dishes I love" pick | +1.0 |

### Affinity per tag
```
decay(age)        = 0.5 ^ (ageDays / 30)           # 30-day half-life: tastes drift
affinity(tag)     = Σ weight(e) · decay(e.age)   over events whose recipe has that tag
evidence(tag)     = Σ |weight(e)| · decay(e.age)
normalised(tag)   = tanh(affinity(tag) / 3)          # squashes to (−1, 1)
```

### Craving score
```
taste(recipe)   = weighted mean of normalised(tag) over the recipe's tags
                  (region 0.25, dishType 0.25, flavours 0.25, heaviness 0.10, protein 0.15)

cravingScore =  0.60 · taste
              + 0.10 · pantryHint          # fraction of core ingredients at home
              + 0.05 · quick (≤ 30 min, weekdays)
              + 0.05 · favourite
              − repeatPenalty(daysSinceCooked)       # shared with Kitchen mode
              − rejectPenalty(daysSinceLeftSwipe)     # ≤3d: excluded · ≤14d: 0.25
```

### Exploration (avoiding a filter bubble)
- The **DeckBuilder** fills each deck of 20 with about **80% exploit** (top craving scores) and
  about **20% explore** (recipes whose tags have low `evidence`, so the app learns something new).
- Explore cards are labelled honestly: "Something different: South Indian".
- Deterministic under a seed, so decks can be golden-tested. "Shuffle" changes the seed.

### Cold start
Onboarding gets a step: **"Pick 5 dishes you love"**: a grid of 20 popular dishes with
single-tap selection. These count as +1.0 events. With zero picks, the first decks are
100% explore across diverse tags.

## 5. Kitchen mode scoring (moved from PLAN.md 4.5, now also swipe-based)

```
ingredientWeight = roleWeight(role) + rarityBonus        # core 2.4, flavour 1.2,
                                                         # optional 0.7, staple 0.25
weightedCoverage = Σ weight(available) / Σ weight(all)   # optional items never count as missing
coreCoverage     = same, core ingredients only

kitchenScore = 0.40 · weightedCoverage
             + 0.20 · coreCoverage
             + 0.15 · expiringUse                 # share of items expiring within 3 days
             + 0.10 · taste                       # the learned profile nudges this mode too
             + 0.05 · favourite
             + 0.05 · quick
             − repeatPenalty − rejectPenalty
             − 0.10 · sameBaseAsLastMeal          # rice after rice
```
- Hard filters: meal slot matches; **at most 2** missing non-optional ingredients
  (staples count as available unless marked Out).
- Card badge shows the tier: **Ready now** / **Missing 1** / **Missing 2** / **Use it up: palak (today)**.
- Order: expiring-use cards first, then ready, then almost.

### Shared penalties
```
repeatPenalty(days since cooked):  ≤7d 0.30 · ≤14d 0.20 · ≤28d 0.10 · ≤56d 0.03
                                   + 0.02 per extra cook in the last 90 days ("rut")
rejectPenalty(days since left):    ≤3d excluded · ≤14d 0.25 · else 0
```
All weights live in one `ScoringConfig` value object and can be tuned without code changes.

## 6. Explanations (every card shows one line)

Chosen from the top positive contributor:
- Kitchen: "Uses your matar (2 days left). Nothing missing."
- Craving, similar-dish: "Because you liked Rajma Chawal", from the liked recipe with the
  highest tag overlap (Jaccard) in the last 60 days.
- Craving, tag: "You've been into tangy South Indian lately."
- Explore: "Something different: Gujarati."
- Pantry hint: "You already have 5 of 7 ingredients."

## 7. Domain additions

```dart
SwipeEvent { id, recipeId, action(right|left|never|undo), mode(kitchen|craving),
             at, deckSeed }
Recipe     + tags: DishTags, imageAsset?
// Derived, never persisted:
TasteProfile { Map<TagKey, double> affinity, Map<TagKey, double> evidence }
TodaysPicks  = right-swipe events today whose recipe has no MealLog after the swipe
```
Undo is stored as an event (`undo` referencing the previous id), not a delete. The event log
stays append-only, which makes it simpler to reason about and sync later (v2).

## 8. Group swipe (NOT in v1, decision D9)
In v1 the family simply keeps swiping on one phone and decides together.
- **v1.1 "Pass the phone"**: each family member swipes the same 15-card deck on one device,
  and the app shows **matches** (dishes everyone right-swiped). Fully offline.
- **v2 "Family match"**: members swipe on their own phones, and a match appears when all
  right-swipe. Needs sync, so it ships with household sharing.

## 9. Test plan (kya_core)
- Profile: fold of hand-written event lists gives expected affinities; decay half-life verified.
- Deck: seed-stable composition (16 exploit + 4 explore), cooldown exclusion, no duplicates.
- Asymmetry: 5 left swipes on paneer dishes must not push paneer below neutral if there were
  3 cooks in the same period.
- Golden scenarios for both modes ("pantry X, events Y, now Z → first 5 cards = ...").
- Explanations: each rule produces its string; never an empty reason.
