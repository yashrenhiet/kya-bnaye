# kya-bnaye — Product & Engineering Plan (v1)

> Status: **Approved for v1** · Date: 2026-09-26
> Inputs: `docs/RESEARCH.md` (6 open-source apps analysed)
> Decisions locked: see section 8 (Decision log). Scope: **v1 only**.

---

## 1. Product in one line

Two ways to answer "kya bnaye?", both through a swipe deck:
- **Kitchen mode**: dishes you can cook **with what's at home right now**.
- **Craving mode**: dishes you'll **love**, based on your learned taste, whether or not
  the ingredients are at home. Swipe right = "want this", left = "not today".

Every swipe teaches the app your taste, and picks turn into a shopping list for what's missing.

### Design principles (the rules every feature is judged against)
1. **Answer "kya bnaye?" in one swipe session.** The deck is the product. Everything else feeds it.
2. **Logging must be near-zero effort.** Stock is `Plenty / Low / Out`, not grams.
   Staples are assumed. If a feature needs typing, question the feature.
3. **Offline-first.** No login and no network for the core value. Your data stays on your phone.
4. **Suggest, never assume.** Anything the app infers (used-up items, expiry dates) is
   pre-filled for one-tap confirmation, never applied silently.
5. **Explain every recommendation.** "Uses your palak (expires tomorrow). Nothing missing."
6. **Indian kitchen by default.** Everyday recipes, sabzi and kirana categories, rice/roti rotation.

---

## 2. Feature plan

### v1.0 — MVP (what we ship first)

| # | Feature | What it does | Borrowed from |
|---|---------|--------------|---------------|
| F1 | **Onboarding** | 4 screens: welcome → tick "always at home" staples → tick what's in the fridge today → **pick 5 dishes you love** → first deck. Target: done in < 2 min. | Pantry (low friction) |
| F2 | **Pantry** | Items grouped by category (Sabzi, Fruits, Dairy, Grains & Atta, Dal & Pulses, Masala, Oil & Ghee, Packaged, Other). Quick-add search with alias matching ("aloo" → Potato). Tap to cycle Plenty → Low → Out. Optional expiry, auto-estimated from the ingredient's shelf life. | family-kitchen (canonical ids), FridgeCheck (upsert, expiry states) |
| F3 | **Recipe book** | ~60 seeded everyday Indian recipes + add/edit your own. Fields: name, meal types, minutes, base (rice/roti/bread/none), ingredients (linked to catalog), steps, favourite. Search + filters (meal type, quick, favourites, cookable now). | chef-it (seed data), family-kitchen |
| F4 | **Swipe deck + Kitchen mode** | Home screen, mode toggle `Kitchen / Craving`, **Kitchen is the default on every launch**. Tinder-style cards (photo, name, time, reason line, badge). Right = **Want this**, left = **Not today**, overflow = **Never show**, **Undo** last swipe; on-screen buttons for every gesture. Kitchen mode shows only dishes with at most 2 missing items; badges: **Ready now / Missing 1–2 / Use it up**. | Ratatouille (role weights), family-kitchen (repeat penalty), chef-it (tiers, rationale) |
| F4b | **Craving mode + taste profile** | Recommends from learned taste regardless of pantry. Profile derived from swipes and cooks (30-day decay). 80/20 exploit/explore mix so it doesn't get stuck. Explanation per card ("Because you liked Rajma Chawal"). Onboarding step "Pick 5 dishes you love" for cold start. Right swipe opens a pick sheet: **View recipe / Add missing to list / Keep swiping**. | new (see `docs/design/RECOMMENDER.md`) |
| F4c | **Today's picks** | Tray on Home listing today's right-swipes; tap **I made this** to log. Clears at end of day. | new |
| F5 | **"I made this" + history** | One tap logs the meal. Then a sheet: "Used up anything?" with the recipe's perishables pre-listed, so you can mark them Low/Out in one tap. History feeds the repeat penalty. | FridgeCheck (diff review), family-kitchen (history) |
| F6 | **Shopping list** | Auto-filled from Low/Out items + "add missing" from a recipe + manual items. Grouped by **where you buy it**: Sabziwala, Kirana, Dairy, Other. Check off → "Move bought items to pantry" sets them to Plenty. | family-kitchen (shortage math) |
| F7 | **Backup** | Export/import all data as a JSON file (share sheet). Our safety net until sync exists. | Pantry (snapshot reasoning) |

### v1.1 — convenience (after real usage feedback)
- Expiry reminders (local notifications: "Paneer expires tomorrow. Paneer bhurji?")
- Leftovers as pantry items ("leftover rice" → lemon rice, fried rice)
- Share today's menu / shopping list to WhatsApp
- Import a recipe from a URL (schema.org JSON-LD parsing)
- Home-screen widget with today's suggestion
- Thali mode: suggest dal + sabzi + base combos, not only single dishes
- **"Pass the phone" group swipe**: family members swipe the same deck on one device and the app shows matches

### v2 — bigger bets
- **Diet & fasting** (veg / egg / non-veg / Jain per member, Navratri/Ekadashi filters)
- Household sharing / multi-device sync, plus **Family match** (swipe on your own phones, match when everyone right-swipes)
- Hindi + regional languages
- AI "invent something from my pantry", **only through our own backend proxy with quotas, never a key inside the app**
- Barcode scan (OpenFoodFacts), bill/receipt scan
- Indian seasonal produce boosting

### Explicitly NOT doing (YAGNI)
Social feed, comments, ratings · fridge shelf maps / QR labels · gamification · nutrition/macros ·
accounts/login in v1.

---

## 3. Screen layout

Navigation: **bottom tab bar with 4 tabs**: `Home · Pantry · Recipes · Shopping`.
History and Settings are reached from Home's top bar.

### 3.1 Home: "Kya Bnaye?" swipe deck
```
┌─────────────────────────────────┐
│ Good evening   [History][Gear]  │
│ [ Kitchen | Craving ]  Dinner ▾ │  mode toggle · meal slot (auto)
│ ┌─────────────────────────────┐ │
│ │        [ dish photo ]       │ │
│ │ Palak Paneer       30 min   │ │
│ │ READY NOW                   │ │  badge (Kitchen) / "Explore" (Craving)
│ │ Because you liked Paneer    │ │  reason line
│ │ Butter Masala.              │ │
│ │ Have 5 of 7 ingredients     │ │
│ └─────────────────────────────┘ │  <- swipe left / right ->
│  [Not today]  [Undo]  [Want this]│  buttons mirror gestures (a11y)
│ TODAY'S PICKS (2)               │
│  Palak Paneer   [I made this]   │
│  Masala Dosa    missing 2 [+list]│
├─────────────────────────────────┤
│ Home  Pantry  Recipes  Shopping │
└─────────────────────────────────┘
```
- Right swipe opens the pick sheet: **View recipe / Add missing to shopping list / Keep swiping**.
- Card overflow menu: **Never show this dish**.
- End of deck: "That's all for now" with **Shuffle** and **Switch mode** buttons.
- Empty pantry in Kitchen mode: "Add what's at home" (links to Pantry), or "Try Craving mode".
- Swipe gestures respect the OS reduce-motion setting (cards fade instead of fling).

### 3.2 Pantry
```
┌─────────────────────────────────┐
│ Pantry                    [+]   │
│ [Search] Add… (aloo, dahi)      │  alias-aware autocomplete
│ [All] [Low] [Expiring]          │  filter chips
│ SABZI                           │
│  Potato        ● Plenty         │  tap → cycle level
│  Palak         ● Low   ⏰ 1 day │  expiry badge
│  Tomato        ○ Out            │
│ DAIRY                           │
│  Paneer        ● Plenty ⏰ 2 days│
└─────────────────────────────────┘
```
Long-press → edit sheet (level, expiry, delete). Swipe → "Add to shopping list".

### 3.3 Recipes and recipe detail
```
Recipes                          Recipe detail
[Search]                         Aloo Matar · 25 min · Lunch/Dinner
[Cookable now][Quick][Fav][Meal] INGREDIENTS
 Aloo Matar       ready          [x] Potato [x] Matar [x] Tomato
 Poha             ready          [x] Haldi  [x] Jeera (salt, oil assumed)
 Rajma Chawal    2 missing        [Add missing to list]
[+ Add recipe]                   STEPS 1…n
                                 [Favourite]   [I made this]
```

### 3.4 Shopping
```
Shopping                    [Share]
SABZIWALA
  [ ] Tomato        (from: Out)
  [ ] Palak         (from: Palak Paneer)
KIRANA
  [ ] Besan
DAIRY
  [x] Paneer
[Move 1 bought item to pantry]
+ Add item
```

### 3.5 Other screens
- **Onboarding** (3 steps, skippable) · **History** (list by date, "last made 4 days ago")
- **Settings**: export/import backup, reset data, "about".
- **Add/Edit recipe**: form with ingredient picker (same alias autocomplete as Pantry).

Accessibility: WCAG 2.2 AA. Contrast ≥ 4.5:1, tap targets ≥ 44×44 (48 dp on Android),
**level shown by text + icon, not colour alone**, full screen-reader labels, dynamic type support.

---

## 4. Architecture

### 4.1 Tech stack

| Concern | Choice | Why |
|---------|--------|-----|
| Framework | **Flutter (stable)**, Dart 3 | One codebase for Android + iOS |
| State management | **Riverpod** | Testable, compile-safe DI, no `BuildContext` coupling |
| Local DB | **Drift (SQLite)** | Relational queries (expiring items, recipe↔ingredient joins), typed, migrations, in-memory DB for tests. Isar is deliberately avoided because of maintenance uncertainty. |
| Navigation | **go_router** | Declarative, deep-link ready (widgets and notifications in v1.1) |
| Lints | `very_good_analysis` (or `flutter_lints` + strict) | Enforced style in CI |
| Tests | `test`, `flutter_test`, `integration_test` | First-party |
| CI | GitHub Actions | analyze → test → build APK / iOS (no codesign) |

Exact package versions get pinned at setup time. None are assumed here.

### 4.2 Module layout (Dart pub workspace, two packages)

```
kya-bnaye/
├── pubspec.yaml                 # workspace root
├── packages/
│   └── kya_core/                # PURE DART. Zero Flutter imports. The brain.
│       ├── lib/src/
│       │   ├── domain/          # Ingredient, PantryItem, Recipe, MealLog, ShoppingItem
│       │   ├── catalog/         # IngredientNormalizer (alias → canonical id)
│       │   ├── recommend/       # Recommender, scoring, tiers, explanations
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
│   │   ├── features/
│   │   │   ├── home/            # each feature = screens + widgets + controller (Notifier)
│   │   │   ├── pantry/
│   │   │   ├── recipes/
│   │   │   ├── shopping/
│   │   │   ├── history/
│   │   │   ├── onboarding/
│   │   │   └── settings/
│   │   └── shared/widgets/      # only widgets used by 2+ features
│   ├── assets/seed/             # ingredients.json, recipes.json
│   └── test/ , integration_test/
└── docs/                        # RESEARCH.md, PLAN.md, adr/
```

Why only two packages: `kya_core` has to be isolated so the recommender is testable and
can't depend on the UI. A separate `kya_data` package would only be ceremony at this size,
so data lives in `app/lib/data/`. It can be split out later if a second consumer appears.

### 4.3 Dependency rule (hexagonal / ports and adapters)
```
 features (UI + controllers) ──► kya_core (domain + use-cases + ports)
                                       ▲
 app/data (Drift adapters) ────────────┘  implements ports
```
- `kya_core` depends on **nothing** (maybe `collection`, `meta`).
- UI never touches Drift directly; controllers call repositories through core interfaces.
- Swapping SQLite for cloud sync in v2 = new adapter, zero domain changes (Open/Closed).

### 4.4 Domain model

```dart
Ingredient    { id, name, aliases[], category, role, buyFrom, shelfLifeDays?, isStaple }
  role:     core | flavor | optional | staple      // drives scoring weight
  category: sabzi | fruit | dairy | grains | dal | masala | oilGhee | packaged | other
  buyFrom:  sabziwala | kirana | dairy | other      // shopping grouping

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
                // append-only; TasteProfile and TodaysPicks are derived from it
ShoppingItem  { id, ingredientId?, customName?, reason(out|low|recipe|manual),
                recipeId?, isChecked, createdAt }
```
Rules:
- One `PantryItem` per ingredient (PK = ingredientId). No duplicates, by construction.
- Custom ingredients the user types that aren't in the catalog become `Ingredient` rows
  with `source=user`, so matching still happens on ids.
- **Matching is exact on canonical id after alias resolution. No substring matching**
  (avoids Ratatouille's "rice" = "rice flour" bug).
- Staples (salt, oil, water, haldi…) are assumed available unless explicitly marked Out.

### 4.5 Recommender: two modes, one engine
Full design: **`docs/design/RECOMMENDER.md`**. Summary:
- `RankingStrategy` interface with two implementations (Strategy pattern):
  **KitchenRanker** (pantry coverage with core/masala/staple role weights, expiry boost,
  tiers) and **CravingRanker** (learned taste affinity, pantry only as a small hint).
- Shared penalties: repeat (7/14/28/56-day steps + 90-day rut), left-swipe cooldown
  (hidden 3 days, down-ranked 14), rice-after-rice.
- **TasteProfile is derived from the append-only SwipeEvent + MealLog history** (30-day
  decay, tanh-normalised tag affinities). Never stored, so nothing can go stale.
- **DeckBuilder** composes 20 cards: about 80% exploit, 20% explore, deterministic under a seed.
- Every card carries a one-line explanation. All weights live in one `ScoringConfig`.

### 4.6 Seed data (the biggest non-code task)
- `ingredients.json`: ~250 Indian kitchen ingredients with aliases (aloo, batata, potato),
  role, category, buyFrom, shelfLifeDays.
- `recipes.json`: ~80 everyday recipes: breakfasts (poha, upma, paratha, besan chilla),
  dal/sabzi staples, rice dishes, quick snacks, **plus craving dishes** (chole bhature,
  masala dosa, pav bhaji, biryani, hakka noodles…) so Craving mode has range.
  Each recipe has **tags** (closed enums) and a **photo**.
- **Photos**: licence-clean only (own photos, CC0/Unsplash-licence with attribution
  recorded in `assets/seed/IMAGE_CREDITS.md`). Fallback: generated gradient card with the
  dish initial, so a missing photo never blocks a recipe. Bundled as compressed webp,
  with a size budget (~40 KB each).
- **Written by us.** Kaggle "Indian Food 101" is inspiration only unless its licence is
  verified. A validation test checks that every recipe ingredient id exists in the catalog
  and that there are no duplicate aliases.
- Loaded into Drift on first run. Versioned (`seedVersion`) so updates can add new seed
  recipes without overwriting user edits.

### 4.7 Data flow example: "I made this"
```
HomeScreen → MealController.cook(recipe)
  → MealLogRepository.add(log)                     (port → Drift adapter)
  → shows "Used up anything?" sheet (perishables pre-listed)
  → PantryRepository.setLevels(confirmed changes)
  → Riverpod streams (Drift watch queries) → Home + Pantry rebuild automatically
```

### 4.8 Architecture Decision Records
Short ADRs in `docs/adr/`:
001 Flutter · 002 Riverpod · 003 Drift · 004 pure-Dart core · 005 level-based stock ·
006 offline-first, no accounts in v1 · 007 two-mode recommender with derived taste profile ·
008 append-only swipe event log.

---

## 5. Quality strategy

| Layer | Tooling | Target |
|-------|---------|--------|
| Core (recommender, normalizer, shopping, backup) | `dart test` | ≥ 90% line coverage; golden scenario tests ("pantry = X, history = Y → top 3 = Z") |
| Seed data | `dart test` validators | 100% referential integrity |
| Data layer | Drift in-memory DB | Every repository method; migration tests from v1 schema onward |
| Controllers | Riverpod `ProviderContainer` + fakes | Every state transition |
| Widgets | `flutter_test` | Each screen: loaded / empty / error states; semantics labels present |
| E2E | `integration_test` | Critical path: onboarding → pantry → swipe right (both modes) → add missing to list → I made this → shopping |
| CI | GitHub Actions on every PR | `dart format --set-exit-if-changed`, analyze (zero warnings), tests, debug APK build |

Definition of Done (every feature): tests green · zero analyzer warnings · accessibility
labels checked · files < 600 lines · reviewed diff · docs updated if behaviour changed.

---

## 6. Execution plan

Sizing assumes one developer part-time with woofy pairing. Weeks are rough estimates.

| Milestone | Scope | Exit criteria | Est. |
|-----------|-------|---------------|------|
| **M0: Foundations** | Workspace, two packages, lints, CI, theme tokens, router skeleton with 4 empty tabs, ADRs | CI green on an empty app running on Android emulator + iOS simulator | 0.5 wk |
| **M1: Core brain** | Domain models, normalizer, **KitchenRanker, CravingRanker, TasteProfile, DeckBuilder**, shopping builder, backup codec: **no UI** | ≥ 90% coverage; 20+ golden scenarios across both modes pass | 2 wk |
| **M2: Seed data** | 250 ingredients + 80 tagged recipes + photos, validators | Validators green (ids, tags, images); manual spot-check of 20 recipes | 1.5–2 wk (runs parallel with M1) |
| **M3: Data layer** | Drift schema, DAOs, repository adapters, first-run seeding, watch streams | Repository + migration tests green | 1 wk |
| **M4: Pantry + Onboarding** | F1, F2 | Onboard in < 90 s; add/cycle/expiry works; widget tests | 1.5 wk |
| **M5: Recipes** | F3: list, filters, detail, add/edit | Can add own recipe and see it recommended | 1.5 wk |
| **M6: Swipe deck + both modes** | F4, F4b, F4c, F5: swipe card widget (gesture + buttons + reduce-motion), mode toggle, pick sheet, Today's picks, taste onboarding step, history | Decks match core goldens; swipe, undo, never-show and picks work on both platforms; "used up" sheet updates pantry | 2 wk |
| **M7: Shopping + Backup** | F6, F7 | Out/Low auto-listed; bought → pantry; export → wipe → import restores everything | 1 wk |
| **M8: Polish + Beta** | A11y pass, empty/error states, app icon, splash, perf check on a low-end Android device, E2E test | Internal testing on Play Console + TestFlight; **you use it daily for 2 weeks** | 1–1.5 wk |

**Total ≈ 12–14 weeks part-time** to a beta you actually use at home.

### Working process
- **Vertical slices after M3:** each milestone ships a usable feature end-to-end (UI → controller → repo → DB).
- **Small branches and PRs** per task (target < 300-line diffs); conventional commit messages.
  Woofy stages, you commit (per your standing rule).
- **Test-first for `kya_core`:** write the golden scenario, then the scoring code.
- **Dogfooding gate:** v1.1 scope is decided from what annoys you in 2 weeks of real use,
  not from this document.
- Weekly checkpoint: demo on a device, update the milestone table, re-prioritise.

### Release plumbing (needed by M8)
- Google Play developer account (one-time fee) → Internal testing track.
- Apple Developer Program (annual fee) → TestFlight. A Mac with Xcode is required for iOS builds.
- App display name: **kya-bnaye**. Bundle/application id: `com.yasher.kyabnaye` (placeholder; must be
  globally unique on both stores, confirm before the first store upload).

---

## 7. Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Users stop updating the pantry | Recommendations go stale and the app dies | Level-based stock, staples assumed, "used up?" sheet after cooking, shopping→pantry auto-move |
| Seed data quality/effort | Bad suggestions on day 1 | Budgeted milestone M2, validators, start with 60 recipes you actually cook |
| Ingredient naming chaos | Missed matches | Canonical ids + aliases; unknown input creates a user ingredient instead of failing |
| Scoring feels "off" | Low trust | Weights in config, explanations on every card, golden tests to prevent regressions |
| Data loss (no cloud) | User anger | JSON backup/restore in v1; sync in v2 |
| Taste profile gets stuck in a bubble | Same 10 dishes forever | 20% explore cards, weak left-swipe signal, 30-day decay, "Reset my taste" in Settings |
| Swipe fatigue / accidental swipes | Wrong signals | Undo, buttons as alternative, deck capped at 20, left swipe = soft signal |
| Dish photos: licensing + app size | Legal risk, heavy APK | Licence-clean sources only, credits file, webp size budget, placeholder fallback |
| Scope creep | Never ships | This doc's YAGNI list; v1.1 decided only after dogfooding |
| iOS build needs Mac/Xcode + paid account | Blocks iOS beta | Android-first internal testing if needed; iOS follows |

---

## 8. Decision log

| # | Decision | Date |
|---|----------|------|
| D1 | **Flutter**, one codebase for Android + iOS | 2026-09-26 |
| D2 | **English only** in v1 | 2026-09-26 |
| D3 | **Diet & fasting deferred** to a later version | 2026-09-26 |
| D4 | **Two modes**, Kitchen + Craving, sharing one swipe deck and one taste profile | 2026-09-26 |
| D5 | **Kitchen mode is the default** when the app opens | 2026-09-26 |
| D6 | **Pan-Indian everyday recipe set** drafted by woofy (~80 dishes) | 2026-09-26 |
| D7 | **Photos: free-licensed downloads for now** (credits recorded); revisit before public release | 2026-09-26 |
| D8 | App name **kya-bnaye** is final | 2026-09-26 |
| D9 | **v1 only.** No group swipe: the family keeps swiping on one phone and decides together. "Pass the phone" stays on the v1.1 list and gets revisited after dogfooding | 2026-09-26 |
| D10 | Development on Yasher's Mac with Xcode (iOS + Android builds) | 2026-09-26 |

### Still open (not blocking M0–M7)
- Apple Developer Program + Google Play developer accounts: needed only at **M8** (beta).
- Final bundle id (see Release plumbing).
- Real food photography to replace downloaded images (before any public release).
