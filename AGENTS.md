# AGENTS.md — kya-bnaye

> This is the single source of truth for any agent (woofy or otherwise) working in this repo.
> Read this file first. Deep-dive docs are linked at the bottom and in `docs/`, but this file
> should be enough on its own to know what we're building, why, and how.

**Status as of 2026-09-26: M0 scaffolding is staged and passes format, lint and tests
(`tool/check.sh`, see §9.1). It is waiting for Yasher to commit it. The M1 core (`packages/kya_core/lib/src/`) is drafted but not yet tracked in git.
It passes lint with 560 tests, 24 golden scenarios and 99.6% line coverage. 15 tests are
marked `skip: 'BUG: ...'` for known bugs that must be fixed before M1 exits. Find them
with `grep -rn "skip: 'BUG" packages/kya_core/test`.**

---

## 0. Roles and standards (applies to every task in this repo)

This is not a toy project. Every contribution — human or agent — is held to these three
hats, worn in this order depending on the task:

### As a Principal Flutter Developer (writing code)
- Code ships at **production quality**, not hackathon quality, even for v1. No shortcuts
  that we'd be embarrassed to explain in a code review.
- **Null safety and immutability by default.** Domain models are immutable value objects
  (`copyWith`, `==`/`hashCode` or `freezed`/`equatable`) — no mutable God objects.
- **Widgets stay small and dumb.** Business logic lives in `kya_core` or a Riverpod
  controller, never inline in a `build()` method. If a `build()` method needs a comment to
  explain what it's doing, it needs to be extracted instead.
- **Effective `const` everywhere it's legal**; be deliberate about what rebuilds and why —
  no unnecessary `setState`/`ref.watch` scope, no rebuilding the whole screen for one badge.
- **Every public API in `kya_core` is documented** (`///` doc comments) with pre/post
  conditions where they're not obvious. No unresolved TODOs merged into `main` — either do
  it, ticket it in the plan, or don't write the comment.
- **Errors are handled, not swallowed.** No bare `catch (_) {}`. Async failures surface a
  user-facing state (loading/empty/error), never a silent no-op or a crash.
- **Zero analyzer warnings, ever.** Lints are a gate, not a suggestion.
- Every feature ships with the tests described in §6 **before** it's considered done —
  test-first for `kya_core`, at minimum test-alongside for UI.

### As a Senior Code Reviewer (reviewing any diff, including your own)
Before calling anything done, review it as if someone else wrote it and your name is on
the approval:
- **SOLID and DRY, pragmatically.** Flag duplicated logic, leaky abstractions, and classes
  doing two jobs — but don't invent interfaces or layers nobody asked for (YAGNI still wins).
- **Negative-path audit on every change:** empty pantry, zero recipes, corrupted backup
  JSON, mid-swipe app kill, clock/timezone edge cases (expiry, "days since cooked"),
  duplicate ingredient aliases, offline/first-run state.
- **No dead code, no commented-out blocks, no placeholder strings** left behind.
- **Diffs stay small and reviewable** (target < 300 lines per PR, per §7) with a clear
  single purpose — reviewability is a feature, not friction.
- Accessibility and performance are review blockers, not follow-up tickets (see §4, §6).

### As a Senior Software Architect (planning structure and technical decisions)
- Every non-trivial decision gets **at least two options weighed** (even briefly) before
  landing on one, with the trade-off written down — see the ADR list in §5.8. "Because it's
  familiar" is not a reason on its own.
- **Protect the dependency rule in §5.3** as the single most important architectural
  invariant in this codebase: `kya_core` must never import Flutter, and UI must never touch
  Drift directly. Any PR that violates this gets rejected regardless of how small it looks.
- **Design for the extension points we already know are coming** (cloud sync in v2, a
  second recommender mode, more languages) without building them now — new adapters and
  new `RankingStrategy` implementations should be pluggable, not require touching the core.
- Think in terms of **failure modes and data integrity** before features: what happens to
  the pantry if a migration fails, what happens to `SwipeEvent` history if the device runs
  out of storage, what's the recovery path.

### As an Experienced UX / Product Designer (screens, layout, colour, interaction)
- Every screen decision gets discussed **before** it's built, the way a designer would
  present it: what's the user's emotional state right now (hungry, tired after work,
  indecisive), what's the one primary action on this screen, what happens if they do
  nothing.
- **Visual language should feel like a warm Indian kitchen, not a generic productivity
  app**: think turmeric/masala-inspired warm tones, appetising food photography as the hero
  of every card, generous whitespace so a hungry, tired user isn't asked to parse a dense
  UI. Avoid sterile corporate blues and cold greys as primary colours — warmth over
  clinical.
- **Typography and hierarchy**: one clear headline per screen, a legible body size (≥16sp),
  and dish names/photos always the most visually dominant element on a card — never crowded
  by chrome (badges, buttons, meta text).
- **Design tokens over hardcoded values.** Colours, spacing (4/8/12/16/24 scale), radii and
  type styles live in `app/lib/theme/` and are reused, never re-typed per screen.
- **Every interaction needs a visible affordance and a non-gesture fallback** (already a
  rule for swipe in §4) — a UX review is not complete until it's checked against WCAG 2.2 AA.
- Colour and layout proposals are **presented with rationale and at least one alternative**,
  the same way a design review would, before being locked into the theme tokens.

---

## 1. What this is

**kya-bnaye** ("what should I make") is a Flutter mobile app (Android + iOS) that answers
the daily Indian-household question "what do I cook?" using two swipeable modes:

- **Kitchen mode** (default): dishes you can cook **with what's at home right now**.
- **Craving mode**: dishes you'll **love**, based on a taste profile learned from your
  swipes — whether or not the ingredients are at home.

Both modes share one Tinder-style swipe deck: **swipe right = "want this"**, **swipe left =
"not today"**. Every swipe teaches the app your taste. Right-swiped dishes become
**Today's picks**; missing ingredients become a shopping list.

### Design principles (every feature is judged against these)
1. **Answer "kya bnaye?" in one swipe session.** The deck is the product.
2. **Logging must be near-zero effort.** Stock is `Plenty / Low / Out`, never grams. Staples
   (salt, oil, haldi…) are assumed present unless marked Out. If a feature needs typing,
   question the feature.
3. **Offline-first.** No login, no network required for core value. Data stays on the phone.
4. **Suggest, never assume.** Anything inferred (used-up items, expiry) is pre-filled for a
   one-tap confirm, never applied silently.
5. **Explain every recommendation.** e.g. "Uses your palak (expires tomorrow). Nothing missing."
6. **Indian kitchen by default.** Sabzi/kirana/dairy categories, rice-vs-roti rotation, pan-Indian recipes.

---

## 2. Decision log (locked for v1)

| # | Decision |
|---|----------|
| D1 | **Flutter**, one codebase for Android + iOS |
| D2 | **English only** in v1 |
| D3 | **Diet & fasting rules deferred** (veg/Jain/fasting calendar → v2) |
| D4 | **Two modes**, Kitchen + Craving, sharing one swipe deck and one taste profile |
| D5 | **Kitchen mode is the default** every time the app opens |
| D6 | **Pan-Indian everyday recipe set** (~80 dishes), drafted by woofy |
| D7 | **Photos: free-licensed downloads for now**, credits recorded in `IMAGE_CREDITS.md`; revisit before public release |
| D8 | App name **kya-bnaye** is final |
| D9 | **v1 has no group swipe.** Family passes one phone around and decides together. "Pass the phone" mode is v1.1 |
| D10 | Development happens on Yasher's Mac (Xcode + Android Studio both installed) |
| D11 | User commits; **woofy only stages** changes, never runs `git commit` |

Still open, not blocking until beta (M8): Apple Developer Program + Google Play accounts,
final bundle id (`com.yasher.kyabnaye` is a placeholder), real food photography.

---

## 3. Feature plan

### v1.0 — MVP

| # | Feature | Summary |
|---|---------|---------|
| F1 | **Onboarding** | 4 steps: welcome → tick "always at home" staples → tick today's fridge contents → pick 5 dishes you love → first deck. Target < 2 min. |
| F2 | **Pantry** | Grouped by category (Sabzi, Fruits, Dairy, Grains & Atta, Dal & Pulses, Masala, Oil & Ghee, Packaged, Other). Alias-aware search ("aloo" → Potato). Tap cycles Plenty → Low → Out. Auto-estimated expiry. |
| F3 | **Recipe book** | ~80 seeded pan-Indian recipes + user add/edit. Fields: name, meal types, minutes, base (rice/roti/bread/none), tagged ingredients, steps, favourite, tags (region/dishType/flavours/heaviness/protein). |
| F4 | **Swipe deck + Kitchen mode** | Home screen, `Kitchen / Craving` toggle (Kitchen default). Tinder cards: photo, name, time, reason, badge. Right = Want this, left = Not today, overflow = Never show, Undo. On-screen buttons mirror every gesture (a11y). Kitchen mode: only dishes with ≤ 2 missing ingredients; badges **Ready now / Missing 1–2 / Use it up**. |
| F4b | **Craving mode + taste profile** | Ranks by learned taste regardless of pantry. Profile derived (not stored) from swipe/cook history with 30-day decay. ~80/20 exploit/explore mix. Per-card explanation ("Because you liked Rajma Chawal"). |
| F4c | **Today's picks** | Home tray of today's right-swipes; "I made this" logs the meal; clears at end of day. |
| F5 | **"I made this" + history** | Logs the meal, then a pre-filled "Used up anything?" sheet for the recipe's perishables. History drives the repeat penalty. |
| F6 | **Shopping list** | Auto-built from Low/Out items + missing recipe ingredients + manual entries. Grouped by **Sabziwala / Kirana / Dairy / Other**. "Move bought items to pantry" sets them back to Plenty. |
| F7 | **Backup** | Export/import all data as a JSON file via the share sheet. |

### v1.1 — convenience (decided after 2 weeks of real dogfooding, not before)
Expiry reminders · leftovers as pantry items · share menu/list to WhatsApp · recipe import
from URL (schema.org JSON-LD) · home-screen widget · thali mode (dal+sabzi+base combos) ·
**"Pass the phone" group swipe** (same deck, one device, shows matches).

### v2 — bigger bets
Diet & fasting per member (veg/egg/non-veg/Jain, Navratri/Ekadashi) · household sync +
**Family match** (swipe on separate phones) · Hindi + regional languages · AI suggestions
**only through our own backend proxy with quotas, never an API key inside the app** ·
barcode scan (OpenFoodFacts) · receipt/bill scan · Indian seasonal produce boosting.

### Explicitly NOT doing (YAGNI)
Social feed/comments/ratings · fridge shelf maps / QR labels · gamification · nutrition/macros ·
accounts/login in v1.

---

## 4. Screens

Bottom tab bar, 4 tabs: **Home · Pantry · Recipes · Shopping**. History and Settings hang
off Home's top bar. Full ASCII wireframes are in `docs/PLAN.md` §3. Highlights:

- **Home** = the swipe deck. Mode toggle at top. Right swipe → pick sheet (View recipe /
  Add missing to list / Keep swiping). End of deck → Shuffle / Switch mode.
- **Pantry** = category list, tap-to-cycle level, expiry badges, swipe → add to shopping list.
- **Recipes** = search + filters (Cookable now / Quick / Favourite / Meal), detail view shows
  matched/missing ingredients and Favourite / I made this.
- **Shopping** = grouped by where you buy it, checkboxes, "move bought → pantry".

**Accessibility (WCAG 2.2 AA):** contrast ≥ 4.5:1, tap targets ≥ 44×44 (48dp Android),
level shown by text+icon not colour alone, full screen-reader labels, reduce-motion respected
(cards fade instead of fling), dynamic type support.

---

## 5. Architecture

### 5.1 Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | **Flutter (stable)**, Dart 3 | One codebase, Android + iOS |
| State management | **Riverpod** | Testable, compile-safe DI, no `BuildContext` coupling |
| Local DB | **Drift (SQLite)** | Relational queries, typed, migrations, in-memory DB for tests |
| Navigation | **go_router** | Declarative, deep-link ready for widgets/notifications later |
| Lints | `very_good_analysis` (or strict `flutter_lints`) | Enforced in CI |
| Tests | `test`, `flutter_test`, `integration_test` | First-party tooling only |
| CI | GitHub Actions | analyze → test → build APK / iOS (no codesign) |

Exact package versions get pinned at M0, not assumed here.

### 5.2 Module layout (two packages)

```
kya-bnaye/
├── pubspec.yaml                 # workspace root
├── packages/
│   └── kya_core/                # PURE DART. Zero Flutter imports. The brain.
│       ├── lib/src/
│       │   ├── domain/          # Ingredient, PantryItem, Recipe, MealLog, SwipeEvent, ShoppingItem
│       │   ├── catalog/         # IngredientNormalizer (alias → canonical id)
│       │   ├── recommend/       # KitchenRanker, CravingRanker, TasteProfile, DeckBuilder
│       │   ├── shopping/        # ShoppingListBuilder
│       │   ├── backup/          # JSON export/import codec
│       │   └── ports/           # Repository interfaces (abstract classes)
│       └── test/                # dart test, fast, no emulator
├── app/                         # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── bootstrap/           # DI (ProviderScope overrides), seed-on-first-run
│   │   ├── routing/             # go_router config
│   │   ├── theme/               # colours, typography, spacing tokens
│   │   ├── data/                # ADAPTERS: Drift DB, tables, DAOs, repo impls, seed loader
│   │   ├── features/            # home, pantry, recipes, shopping, history, onboarding, settings
│   │   └── shared/widgets/      # only widgets used by 2+ features
│   ├── assets/seed/             # ingredients.json, recipes.json, IMAGE_CREDITS.md
│   └── test/ , integration_test/
└── docs/
```

`kya_core` is isolated on purpose: the recommender must be UI-independent and heavily
tested. A separate `kya_data` package would be ceremony at this size — data lives in
`app/lib/data/` until a second consumer justifies splitting it out.

### 5.3 Dependency rule (ports and adapters)
```
features (UI + controllers) ──► kya_core (domain + use-cases + ports)
                                      ▲
app/data (Drift adapters) ───────────┘  implements ports
```
`kya_core` depends on nothing but `collection`/`meta`. UI never touches Drift directly.
Swapping SQLite for cloud sync in v2 = a new adapter, zero domain changes.

### 5.4 Domain model

```dart
Ingredient    { id, name, aliases[], category, role, buyFrom, shelfLifeDays?, isStaple }
  role:     core | flavor | optional | staple      // drives scoring weight
  category: sabzi | fruit | dairy | grains | dal | masala | oilGhee | packaged | other
  buyFrom:  sabziwala | kirana | dairy | other

PantryItem    { ingredientId (PK), level, expiresOn?, expiryEstimated, updatedAt }
  level:    plenty | low | out

Recipe        { id, name, mealTypes{breakfast,lunch,dinner,snack}, minutes, base,
                ingredients[RecipeIngredient], steps[], tags: DishTags, imageAsset?,
                isFavorite, isHidden, source, createdAt }
DishTags      { region, dishType, flavours{}, heaviness, protein }   // closed enums
  base:     rice | roti | bread | none              // rotation penalty
  source:   seed | user
RecipeIngredient { ingredientId, quantityText ("2 katori"), isOptional }

MealLog       { id, recipeId, mealType, cookedAt }
SwipeEvent    { id, recipeId, action(right|left|never|undo), mode(kitchen|craving), at, deckSeed }
                // append-only; TasteProfile and TodaysPicks are derived from it, never stored
ShoppingItem  { id, ingredientId?, customName?, reason(out|low|recipe|manual),
                recipeId?, isChecked, createdAt }
```
Rules: one `PantryItem` per ingredient (PK = ingredientId) · matching is **exact on
canonical id after alias resolution, never substring** (avoids the "rice" matches "rice
flour" bug seen in prior art) · unknown user input becomes a `source=user` Ingredient
instead of failing.

### 5.5 Recommender — two modes, one engine

Full design: **`docs/design/RECOMMENDER.md`**. Summary:
- `RankingStrategy` interface, Strategy pattern: **KitchenRanker** (pantry coverage,
  core/masala/staple role weights + rarity bonus, expiry boost, tiers) and **CravingRanker**
  (learned taste affinity, pantry as a small hint only).
- Shared penalties: repeat cooldown (7/14/28/56-day steps + 90-day "rut"), left-swipe
  cooldown (hidden 3 days, down-ranked 14 days), same-base-as-last-meal (rice after rice).
- `TasteProfile` = pure function of the append-only `SwipeEvent` + `MealLog` history, 30-day
  exponential decay, tanh-normalised per-tag affinity. Never persisted, can't go stale.
- `DeckBuilder` composes ~20 cards per deck: ~80% exploit (top score) / ~20% explore (low
  `evidence` tags), deterministic under a seed so it's golden-testable.
- Every card carries a plain-language explanation built from the top scoring contributor.
- All weights live in one `ScoringConfig` value object — tunable without code changes.

### 5.6 Seed data (the biggest non-code task)
- `ingredients.json`: ~250 Indian kitchen ingredients + aliases, role, category, buyFrom,
  shelfLifeDays.
- `recipes.json`: ~80 pan-Indian everyday recipes (breakfasts, dal/sabzi staples, rice
  dishes, quick snacks, plus craving dishes like chole bhature, dosa, pav bhaji, biryani)
  each with tags (closed enums) and a photo.
- **Photos:** free-licensed only (CC0/Unsplash-style with attribution), credited in
  `assets/seed/IMAGE_CREDITS.md`; webp, ~40KB budget; generated gradient+initial fallback
  when no photo exists so a missing photo never blocks a recipe.
- Written by us (Kaggle "Indian Food 101" is inspiration only, pending licence check).
  Validators enforce: every recipe ingredient id exists in the catalog, no duplicate
  aliases, every tag is a known enum value.
- Loaded into Drift on first run; `seedVersion` allows adding new seed recipes later
  without clobbering user edits.

### 5.7 Example data flow: "I made this"
```
HomeScreen → MealController.cook(recipe)
  → MealLogRepository.add(log)                     (port → Drift adapter)
  → shows "Used up anything?" sheet (perishables pre-listed)
  → PantryRepository.setLevels(confirmed changes)
  → Riverpod streams (Drift watch queries) → Home + Pantry rebuild automatically
```

### 5.8 ADRs
Short records live in `docs/adr/`: 001 Flutter · 002 Riverpod · 003 Drift · 004 pure-Dart
core · 005 level-based stock · 006 offline-first, no accounts in v1 · 007 two-mode
recommender with derived taste profile · 008 append-only swipe event log.

---

## 6. Quality bar

| Layer | Tooling | Target |
|---|---|---|
| Core (`kya_core`) | `dart test` | ≥ 90% coverage; golden scenarios ("pantry=X, history=Y → top 3=Z") for both modes |
| Seed data | `dart test` validators | 100% referential integrity (ids, aliases, tags, images) |
| Data layer | Drift in-memory DB | Every repo method + migration tests |
| Controllers | Riverpod `ProviderContainer` + fakes | Every state transition |
| Widgets | `flutter_test` | Loaded/empty/error states; semantics labels present |
| E2E | `integration_test` | onboarding → pantry → swipe right (both modes) → add missing to list → I made this → shopping |
| CI | GitHub Actions per PR | `dart format --set-exit-if-changed`, zero analyzer warnings, tests, debug APK build |

**Definition of done** for any feature: tests green · zero analyzer warnings ·
accessibility labels checked · files < 600 lines · small reviewed diff · docs updated if
behaviour changed.

---

## 7. Execution plan

One developer part-time + woofy pairing. **≈ 12–14 weeks total.**

| Milestone | Scope | Exit criteria | Est. |
|---|---|---|---|
| **M0 Foundations** | Workspace, two packages, lints, CI, theme tokens, router skeleton (4 empty tabs), ADRs | CI green on Android emulator + iOS simulator | 0.5 wk |
| **M1 Core brain** | Domain models, normalizer, KitchenRanker, CravingRanker, TasteProfile, DeckBuilder, shopping builder, backup codec — **no UI** | ≥ 90% coverage; 20+ golden scenarios pass | 2 wk |
| **M2 Seed data** | 250 ingredients + 80 tagged recipes + photos, validators (runs parallel with M1) | Validators green; 20 recipes spot-checked | 1.5–2 wk |
| **M3 Data layer** | Drift schema, DAOs, repository adapters, first-run seeding, watch streams | Repo + migration tests green | 1 wk |
| **M4 Pantry + Onboarding** | F1, F2 | Onboard < 2 min; add/cycle/expiry works | 1.5 wk |
| **M5 Recipes** | F3: list, filters, detail, add/edit | Own recipe added and recommended | 1.5 wk |
| **M6 Swipe deck + both modes** | F4, F4b, F4c, F5 | Decks match core goldens; swipe/undo/never-show/picks work both platforms; "used up" sheet updates pantry | 2 wk |
| **M7 Shopping + Backup** | F6, F7 | Out/Low auto-listed; bought→pantry; export→wipe→import restores everything | 1 wk |
| **M8 Polish + Beta** | A11y pass, empty/error states, icon, splash, low-end perf check, E2E | Play internal testing + TestFlight; **daily use for 2 weeks** | 1–1.5 wk |

**Working process:** vertical slices after M3 (each milestone ships something usable
end-to-end) · small PRs, target < 300-line diffs, conventional commits · woofy stages,
Yasher commits · test-first for `kya_core` · v1.1 scope decided from real 2-week dogfooding,
not from this document · weekly device demo + re-prioritise.

**Release plumbing needed by M8:** Google Play developer account, Apple Developer Program
(Xcode already installed — see §9), final bundle id.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Users stop updating the pantry | Level-based stock, assumed staples, "used up?" sheet, shopping→pantry auto-move |
| Seed data quality/effort | Dedicated M2 milestone, validators, real household recipes |
| Ingredient naming chaos | Canonical ids + aliases; unmatched input becomes a user ingredient, never fails |
| Scoring feels "off" | Config-driven weights, per-card explanations, golden-test regressions |
| Data loss (no cloud in v1) | JSON backup/restore now, sync in v2 |
| Taste profile filter bubble | 20% explore cards, weak left-swipe signal, 30-day decay, "Reset my taste" |
| Swipe fatigue / mis-swipes | Undo, equivalent buttons, 20-card deck cap, left = soft signal |
| Photo licensing / app size | Licence-clean sources, credits file, webp size budget, placeholder fallback |
| Scope creep | This doc's explicit YAGNI list; v1.1 decided only after dogfooding |
| iOS builds need Mac + paid account | Already resolved for dev — see §9. Store account still needed at M8 |

---

## 9. Development environment (this machine)

Confirmed working as of 2026-09-26:
- **Flutter** 3.47.5 (stable), installed via Homebrew (`/opt/homebrew/bin/flutter`).
- **Android toolchain**: SDK 36.0.0, cmdline-tools installed at
  `~/Library/Android/sdk/cmdline-tools/latest`, all licenses accepted.
- **Xcode** 27.0 at `/Applications/Xcode.app`, CocoaPods 1.17.0.
- **Proxy**: this network requires `sysproxy.wal-mart.com:8080` for `pub.dev`,
  `dl.google.com`, `cdn.cocoapods.org`, etc. `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` and
  `ANDROID_HOME` are exported in `~/.zshrc` (only active in a fresh interactive shell —
  restart Terminal after any env change). `flutter doctor` shows one cosmetic warning
  (`cocoapods.org` marketing site blocked by proxy) that does not affect real `pod install`.
- Verified end-to-end with a throwaway `flutter create` + `flutter pub get` (packages
  resolved and downloaded for real, not just a doctor ping).

If `flutter doctor` ever regresses, re-check: cmdline-tools present, licenses accepted,
proxy env vars loaded in the current shell.

### 9.1 macOS security removes Flutter host binaries (found 2026-09-26)

Security tooling on this Mac flags and deletes SDK binaries: `dart-sdk/bin/dartaotruntime`
and `artifacts/engine/darwin-x64/impellerc` are gone. `flutter doctor` still shows
green because it never runs them. **Do not** re-download them (`flutter precache
--force`), strip quarantine (`xattr -d`), or restore them. Bypassing the flag is a
decision for Yasher/IT, not for an agent.

What still works locally, on the JIT VM (`dartvm`), with no `dartaotruntime`:
- `dart format`, `flutter pub get`.
- **`tool/check.sh`** is the local gate for `kya_core`. It runs format, then
  `tool/analyze.dart`, then `package:test` with `--compiler=source`, then line coverage.
  `tool/analyze.dart` drives the SDK's JIT analysis server and treats infos as fatal.
  Run `MIN_COVERAGE=90 tool/check.sh` to enforce the M1 coverage gate.
- `dart --packages=.dart_tool/package_config.json tool/analyze.dart app` lints the app.

What is blocked locally:
- `dart analyze` and `dart test`, because they need `dartaotruntime`.
- `flutter test`, because it needs `impellerc`.
- `flutter run` and `flutter build`, because they need the frontend server on
  `dartaotruntime`.

CI (GitHub Actions, Linux) is unaffected and keeps running the real tools.

**Impact:** M1 (core) and M2 (seed data) can proceed locally. M4+ (UI, device runs,
iOS builds) needs one of these, and the choice is still open:
1. An IT allowlist for the Flutter SDK. iOS builds need it eventually anyway.
2. A podman Linux container for analyze, test and APK builds.
3. CI as the only app gate.

---

## 10. Reference docs

This file is the consolidated source of truth. For deeper background:
- `docs/RESEARCH.md` — analysis of 6 open-source pantry/recipe apps (architecture and
  algorithm ideas we borrowed from, and what we deliberately avoided).
- `docs/PLAN.md` — original planning document with full ASCII wireframes for every screen.
- `docs/design/RECOMMENDER.md` — full recommender design: scoring formulas, taste-profile
  math, deck composition, test plan.

When plans change, **update this file first**, then the detail docs if needed.
