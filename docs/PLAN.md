# kya-bnaye — Product & Engineering Plan (v1)

> **Revision: v2 (2026-09-27)** — native iOS app in Swift/SwiftUI; Android dropped; zero
> third-party dependencies. See [ADR 009](adr/009-native-ios-swift.md). `AGENTS.md` is the
> source of truth; this document holds the full product plan, wireframes and detail.

> Status: **Approved for v1** · Original date: 2026-09-26 · Revised: 2026-09-27 ·
> **M0'–M8 code complete** (beta steps pending, see §6.2) ·
> **Overnight hardening pass (2026-09-27/28) in progress, see §6.3**
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
| F1 | **Onboarding** | 4 steps: welcome → tick "always at home" staples → tick what's in the fridge today → **pick 5 dishes you love** → first deck. Target: done in < 2 min. | Pantry (low friction) |
| F2 | **Pantry** | Items grouped by category (Sabzi, Fruits, Dairy, Grains & Atta, Dal & Pulses, Masala, Oil & Ghee, Packaged, Other). Quick-add search with alias matching ("aloo" → Potato). Tap to cycle Plenty → Low → Out. Optional expiry, auto-estimated from the ingredient's shelf life. | family-kitchen (canonical ids), FridgeCheck (upsert, expiry states) |
| F3 | **Recipe book** | ~80 seeded pan-Indian everyday recipes + add/edit your own. Fields: name, meal types, minutes, base (rice/roti/bread/none), ingredients (linked to catalog), steps, favourite, tags. Search + filters (meal type, quick, favourites, cookable now). | chef-it (seed data), family-kitchen |
| F4 | **Swipe deck + Kitchen mode** | Home screen, mode toggle `Kitchen / Craving`, **Kitchen is the default on every launch**. Tinder-style cards (photo, name, time, reason line, badge). Right = **Want this**, left = **Not today**, overflow = **Never show**, **Undo** last swipe; on-screen buttons and VoiceOver actions for every gesture. Kitchen mode shows only dishes with at most 2 missing items; badges: **Ready now / Missing 1–2 / Use it up**. | Ratatouille (role weights), family-kitchen (repeat penalty), chef-it (tiers, rationale) |
| F4b | **Craving mode + taste profile** | Recommends from learned taste regardless of pantry. Profile derived from swipes and cooks (30-day decay). 80/20 exploit/explore mix so it doesn't get stuck. Explanation per card ("Because you liked Rajma Chawal"). Onboarding step "Pick 5 dishes you love" for cold start. Right swipe opens a pick sheet: **View recipe / Add missing to list / Keep swiping**. | new (see `docs/design/RECOMMENDER.md`) |
| F4c | **Today's picks** | Tray on Home listing today's right-swipes; tap **I made this** to log. Clears at end of day. | new |
| F5 | **"I made this" + history** | One tap logs the meal. Then a sheet: "Used up anything?" with the recipe's perishables pre-listed, so you can mark them Low/Out in one tap. History feeds the repeat penalty. | FridgeCheck (diff review), family-kitchen (history) |
| F6 | **Shopping list** | Auto-filled from Low/Out items + "add missing" from a recipe + manual items. Grouped by **where you buy it**: Sabziwala, Kirana, Dairy, Other. Check off → "Move bought items to pantry" sets them to Plenty. | family-kitchen (shortage math) |
| F7 | **Backup** | Export/import all data as a JSON file via the iOS share sheet (`ShareLink` / `fileImporter`). Our safety net until sync exists. | Pantry (snapshot reasoning) |

### v1.1 — convenience (after real usage feedback)
- Expiry reminders (local notifications via `UserNotifications`: "Paneer expires tomorrow. Paneer bhurji?")
- Leftovers as pantry items ("leftover rice" → lemon rice, fried rice)
- Share today's menu / shopping list to WhatsApp (via `ShareLink` / share sheet)
- Import a recipe from a URL (schema.org JSON-LD parsing)
- Home-screen widget with today's suggestion (WidgetKit extension)
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
accounts/login in v1 · Android (revisit only after the beta, see §7).

---

## 3. Screen layout

Navigation: **`TabView` with 4 tabs**: `Home · Pantry · Recipes · Shopping`, each tab owning
a `NavigationStack`. History and Settings are reached from Home's toolbar.

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
- Cards expose VoiceOver custom actions (Want this / Not today / Never show / Undo) and respect
  **Reduce Motion** (`accessibilityReduceMotion`: cards fade instead of fling).
- Until real photos land, the photo area shows a generated gradient + dish initial.

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
Long-press (context menu) → edit sheet (level, expiry, delete). Swipe action → "Add to shopping list".

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
`[Share]` uses `ShareLink` (plain-text list of the unticked items, grouped by vendor).

Auto-fill (M7, `Features/Shopping/ShoppingAutoFill.swift`): Low/Out pantry items are added
when the tab first loads and again whenever the pantry changes, never because the list
itself changed. Any row already on the list for that ingredient (ticked or not) blocks a
second one. A deleted auto row stays gone for the session until its pantry record changes
(new level, or the same level set again). "+ Add item" resolves exact names/aliases to a
catalog ingredient (so it restocks the pantry when bought) and keeps anything else as typed;
it never adds a duplicate of an unticked row. Rows are never removed automatically when the
pantry goes back to Plenty ("suggest, never assume").

### 3.5 Other screens
- **Onboarding** (4 steps, skippable) · **History** (list by date, "last made 4 days ago")
- **Settings**: export/import backup, reset data, "Reset my taste", "about".
  Export builds the file first, then offers Share (`ShareLink`) or Save to Files
  (`fileExporter`), named `kya-bnaye-backup-YYYY-MM-DD.json`. Import decodes and checks the
  whole file (format, alias collisions, dangling ingredient ids) before asking "Replace
  everything with N recipes, …?", then calls `replaceAll` once; the phone's seed version is
  kept, because the backup format has none. "Reset my taste" removes swipe events only.
  "Reset all data" replaces everything with an empty snapshot and re-applies the bundled
  seed through `AppEnvironment.reapplySeed()`.
- **Add/Edit recipe**: form with ingredient picker (same alias autocomplete as Pantry).

Accessibility (iOS HIG + WCAG 2.2 AA): contrast ≥ 4.5:1, tap targets ≥ **44×44 pt**,
**level shown by text + icon, not colour alone**, full **VoiceOver** labels, values and
actions (a non-gesture path for every swipe), **Dynamic Type** up to the accessibility sizes
(semantic text styles, no fixed font sizes), and **Reduce Motion** respected.

---

## 4. Architecture

### 4.1 Tech stack

| Concern | Choice | Why |
|---------|--------|-----|
| Language | **Swift 6.4**, Swift 6 language mode, strict concurrency, warnings as errors | Data-race safety at compile time |
| UI | **SwiftUI**, iOS 17+ | First-party, declarative, ships with Xcode |
| State | **`@Observable` stores** (Observation framework), `@MainActor` | Fine-grained updates, plain Swift, testable without views |
| Local DB | **SwiftData**, only behind `KyaCore` repository protocols | First-party, migrations, in-memory `ModelContainer` for tests |
| Navigation | **`NavigationStack` + `TabView`** | Value-based paths, deep-link ready (widget, notifications in v1.1) |
| Tests | **Swift Testing** (`@Test`, `#expect`) for logic; XCTest/**XCUITest** for E2E | First-party, parameterised tests |
| Format/lint | **`swift format`** (bundled with the toolchain), `lint --strict` | No download |
| CI | **GitHub Actions, macOS runner** (`.github/workflows/ios-ci.yml`) | `swift build`/`swift test` for `KyaCore`, `xcodebuild` for the app; only `actions/checkout` as a third-party action |
| Dependencies | **None (policy)** | The corporate proxy may block packages; any dependency needs its own ADR |

`KyaCore`: `swift-tools-version:6.0`, platforms iOS 17 and macOS 14, so `swift test` runs
on the host with no simulator.

### 4.2 Module layout (one SwiftPM package + one Xcode app)

```
kya-bnaye/
├── KyaCore/                        # SwiftPM package. Foundation only. The brain.
│   ├── Package.swift
│   ├── Sources/KyaCore/
│   │   ├── Domain/                 # Ingredient, PantryItem, Recipe, MealLog, SwipeEvent, ShoppingItem
│   │   ├── Catalog/                # IngredientNormalizer (alias → canonical id)
│   │   ├── Recommend/              # KitchenRanker, CravingRanker, TasteProfile, DeckBuilder, ScoringConfig
│   │   ├── Shopping/               # ShoppingListBuilder
│   │   ├── Codec/                  # shared strict JSON helpers (JSONValue, field readers, entity JSON)
│   │   ├── Backup/                 # JSON export/import codec
│   │   ├── Seed/                   # SeedCodec (strict), SeedValidator, SeedCoverageTargets
│   │   ├── Ports/                  # repository protocols
│   │   └── Support/                # SplitMix64 seeded RNG, calendar-day helpers
│   ├── Sources/KyaCoreContracts/   # repository contract suite + in-memory adapters, linked by test targets only
│   └── Tests/KyaCoreTests/         # swift test, fast, no simulator
├── KyaBnaye/                       # iOS app (Xcode project), created in M0'
│   ├── KyaBnaye.xcodeproj
│   ├── KyaBnaye/
│   │   ├── App/                    # @main, composition root (wires Data adapters into stores)
│   │   ├── Theme/                  # colour, typography, spacing, radius tokens
│   │   ├── Data/                   # ADAPTERS: SwiftData @Model classes, mappers, repo impls, seed loader
│   │   ├── Features/
│   │   │   ├── Home/               # each feature = views + @Observable store
│   │   │   ├── Pantry/
│   │   │   ├── Recipes/
│   │   │   ├── Shopping/
│   │   │   ├── History/
│   │   │   ├── Onboarding/
│   │   │   └── Settings/
│   │   └── Shared/                 # only views used by 2+ features
│   ├── KyaBnayeTests/              # stores + Data adapters (Swift Testing)
│   └── KyaBnayeUITests/            # XCUITest E2E
├── seed/                           # manifest.json, ingredients/*.json, recipes/*.json, IMAGE_CREDITS.md
├── scripts/check.sh                # local gate
├── legacy/                         # Flutter/Dart oracle — TEMPORARY, deleted after M1' + M2'
└── docs/                           # RESEARCH.md, PLAN.md, design/, adr/
```

Why only one package: `KyaCore` has to be isolated so the recommender is independent of
the UI and heavily tested. A separate data package would be ceremony at this size, so the
adapters live in `KyaBnaye/KyaBnaye/Data/` until a second consumer (e.g. a WidgetKit
extension) justifies splitting them out. `KyaCoreContracts` exists so the **same**
repository contract tests run against both the in-memory and the SwiftData adapters.

### 4.3 Dependency rule (ports and adapters)
```
 Features (views + @Observable stores) ──► KyaCore (domain + use cases + ports)
                                                 ▲
 KyaBnaye/Data (SwiftData adapters) ─────────────┘  implements ports
```
- `KyaCore` imports **Foundation only**: never SwiftUI, SwiftData, UIKit (or AppKit/Combine),
  and it has no package dependencies. `scripts/check.sh` fails on a forbidden import.
- SwiftData `@Model` classes exist **only** in `KyaBnaye/Data/`. They map to and from
  `KyaCore` structs at the adapter boundary; no `@Model` type crosses a port.
- Views observe `@Observable` stores, which call `KyaCore` repository protocols. **No view
  imports SwiftData and no view uses `@Query`** (ADR 009 weighs this against the idiomatic
  `@Query` style).
- Swapping local storage for cloud sync in v2 = a new adapter, zero domain changes (Open/Closed).

### 4.4 Domain model

All types are immutable `Sendable`, `Equatable`, `Hashable` structs. Enums are `String`-backed
and each raw value matches the seed/backup JSON name **byte for byte** (camelCase).

```swift
struct Ingredient { let id: String; let name: String; let aliases: [String]
                    let category: Category; let role: Role; let buyFrom: BuyFrom
                    let shelfLifeDays: Int?; let isUserCreated: Bool }
enum Role: String     { case core, flavor, optional, staple }   // drives scoring weight
enum Category: String { case sabzi, fruit, dairy, grains, dal, masala, oilGhee, packaged, other }
enum BuyFrom: String  { case sabziwala, kirana, dairy, other }  // shopping grouping

struct PantryItem { let ingredientId: String                    // key
                    let level: StockLevel; let expiresOn: Date?
                    let expiryIsEstimated: Bool; let updatedAt: Date }
enum StockLevel: String { case plenty, low, out }

struct Recipe { let id: String; let name: String; let mealTypes: Set<MealType>
                let minutes: Int; let base: Base; let ingredients: [RecipeIngredient]
                let steps: [String]; let tags: DishTags; let imageAsset: String?
                let isFavorite: Bool; let isHidden: Bool; let source: Source }
struct RecipeIngredient { let ingredientId: String; let quantityText: String  // "2 katori"
                          let isOptional: Bool }
struct DishTags { let region: Region; let dishType: DishType; let flavours: Set<Flavour> // non-empty
                  let heaviness: Heaviness; let protein: Protein }
enum MealType: String  { case breakfast, lunch, dinner, snack }
enum Base: String      { case rice, roti, bread, none }         // rotation penalty
enum Source: String    { case seed, user }
enum Region: String    { case north, south, east, west, gujarati, punjabi, indoChinese, continental, street }
enum DishType: String  { case dal, curry, drySabzi, rice, bread, breakfast, snack, sweet, onePot }
enum Flavour: String   { case spicy, tangy, sweet, savoury, mild }
enum Heaviness: String { case light, medium, heavy }
enum Protein: String   { case paneer, dalLegume, egg, chicken, mutton, fish, vegOnly }

struct MealLog { let id: String; let recipeId: String; let mealType: MealType; let cookedAt: Date }
struct SwipeEvent { let id: String; let recipeId: String; let action: SwipeAction
                    let mode: DeckMode; let at: Date; let deckSeed: UInt64
                    let undoesEventId: String? }
enum SwipeAction: String { case right, left, neverShow, undo }
enum DeckMode: String    { case kitchen, craving }
// append-only; TasteProfile and TodaysPicks are derived from it, never stored

struct ShoppingItem { let id: String; let ingredientId: String?; let customName: String?
                      let reason: ShoppingReason; let recipeId: String?
                      let isChecked: Bool; let createdAt: Date }
enum ShoppingReason: String { case out, low, recipe, manual }
```
Rules:
- One `PantryItem` per ingredient (key = `ingredientId`). No duplicates, by construction.
- Custom ingredients the user types that aren't in the catalog become `Ingredient` values
  with `isUserCreated = true` (ids prefixed `user_`), so matching still happens on ids.
- **Matching is exact on canonical id after alias resolution. No substring matching**
  (avoids Ratatouille's "rice" = "rice flour" bug).
- Staples (salt, oil, haldi…) are assumed available unless explicitly marked Out.
- An ingredient never counts as missing if the recipe line sets `isOptional` or its
  catalog role is `optional`.

### 4.5 Recommender: two modes, one engine
Full design: **`docs/design/RECOMMENDER.md`**. Logic is unchanged by the port. Summary:
- `RankingStrategy` protocol with two implementations (Strategy pattern):
  **KitchenRanker** (pantry coverage with core/masala/staple role weights + rarity bonus,
  expiry boost, tiers) and **CravingRanker** (learned taste affinity, pantry only as a small hint).
- Shared penalties: repeat (7/14/28/56-day steps + 90-day rut), left-swipe cooldown
  (hidden 3 days, down-ranked 14), same-base-as-last-meal (rice after rice).
- **TasteProfile is a pure function of the append-only SwipeEvent + MealLog history**
  (30-day decay, tanh-normalised tag affinities). Never stored, so nothing can go stale.
- **DeckBuilder** composes ~20 cards: about 80% exploit, 20% explore, deterministic under a
  seed via the **SplitMix64** RNG in `KyaCore/Support`. Cold start (zero evidence) = all
  Craving cards are explore cards.
- Day counting uses `Calendar` with an explicit `TimeZone` and `startOfDay`, never seconds / 86400.
- Every card carries a one-line explanation. All weights live in one `ScoringConfig` value type.

### 4.6 Seed data (done in M2; codec being ported)
Authoring rules, enum tables and frozen id lists: **`docs/design/SEED_GUIDE.md`**.
- **Content: 224 ingredients and 80 recipes**, written by us (Kaggle "Indian Food 101" is
  inspiration only). The format is unchanged from the Flutter era.
- **Layout** in repo-root `seed/`, bundled into the app as-is (no merge step):
  `manifest.json` (`seedVersion` + ordered fragment paths), 3 `ingredients/*.json`
  fragments (rows sorted by id) and 6 `recipes/*.json` fragments with closed-enum tags.
- **Strict `SeedCodec`** (`JSONSerialization` + explicit key checks, not `Codable`): unknown
  or forbidden keys, missing keys, wrong types and unknown enum values are errors with a
  file/path location; forces `source=seed` / `isUserCreated=false`.
- **`SeedValidator`** collects every issue: ids/aliases unique, referential integrity, role and
  buyFrom conventions, protein/base consistency, and `SeedCoverageTargets`.
- **Photos:** every `imageAsset` is **null in v1**; the app renders a generated
  gradient + initial fallback. When photos arrive they are `images/<recipe id>.webp`
  (relative to `seed/`), free-licensed (CC0/PD/Unsplash/Pexels preferred), credited in
  `seed/IMAGE_CREDITS.md`, ≤ 60 KB (~40 KB target).
- Loaded into SwiftData on first run by the seed loader in `KyaBnaye/Data/`. `seedVersion`
  lets later seed recipes be added without clobbering user edits.

### 4.7 Data flow example: "I made this"
```
HomeView → MealStore.cook(recipe)                    (@Observable, @MainActor)
  → try await MealLogRepository.add(log)             (KyaCore port → SwiftData adapter)
  → store sets state → "Used up anything?" sheet (perishables pre-listed)
  → try await PantryRepository.setLevels(confirmed changes)
  → repositories publish changes as AsyncStream (for await in each store's .task)
  → PantryStore / HomeStore update → Home + Pantry views re-render via Observation
```
Failures surface as an error state on the store, never a silent no-op or a crash.

### 4.8 Architecture Decision Records
Short ADRs in `docs/adr/`:
001 Flutter (**superseded by 009**) · 002 Riverpod (**superseded by 009**) · 003 Drift
(**superseded by 009**) · 004 pure core (restated for Swift as `KyaCore` by 009) ·
005 level-based stock · 006 offline-first, no accounts in v1 · 007 two-mode recommender with
derived taste profile · 008 append-only swipe event log · **009 native iOS Swift,
ports-and-adapters kept, zero dependencies**.

---

## 5. Quality strategy

| Layer | Tooling | Target |
|-------|---------|--------|
| Core (`KyaCore`: recommender, normalizer, shopping, backup) | `swift test` (Swift Testing), run twice: default TZ and `TZ=America/New_York` | ≥ 90% line coverage; golden scenarios ("pantry = X, history = Y → top 3 = Z") for both modes, frozen from `legacy/` |
| Seed data | `swift test` seed-asset tests against `seed/` | 100% referential integrity (ids, aliases, tags, images); coverage targets met |
| Repository contracts | `KyaCoreContracts` suite run against the in-memory adapters **and** the SwiftData adapters (in-memory `ModelContainer`) | Every repository method behaves identically on both |
| Data layer | SwiftData in-memory `ModelContainer` | Every mapper round trip; seeding by `seedVersion`; migrations from the v1 schema onward |
| Stores | Swift Testing + fake repositories (`KyaCore` protocols) | Every state transition, including loading / empty / error |
| Views | SwiftUI previews for loaded / empty / error states; accessibility audit | Labels, values and actions present; Dynamic Type and Reduce Motion checked |
| E2E | XCUITest | Critical path: onboarding → pantry → swipe right (both modes) → add missing to list → I made this → shopping |
| Gate | `scripts/check.sh` | `swift format lint --strict`, forbidden-import check, build with warnings as errors, tests in both TZs, coverage ≥ 90% |
| CI | GitHub Actions macOS runner, on every PR | Job `core`: build (warnings as errors) + `swift test` + `TZ=America/New_York swift test`. Job `app`: `xcodebuild` simulator build + unit/UI tests, no code signing |

Definition of Done (every feature): tests green · zero warnings · accessibility labels
checked · files < 400 lines (enforced by `scripts/check.sh`) · small reviewed diff · docs updated if behaviour changed.

---

## 6. Execution plan

One developer part-time with woofy pairing. Re-baselined after the pivot:
**≈ 11–13 weeks from 2026-09-26** to a TestFlight beta used daily at home.

### 6.1 Flutter-era milestones (history)

| Milestone | Status |
|-----------|--------|
| **M0 Foundations** (Flutter workspace, CI) | Done, then superseded by M0' |
| **M1 Core brain** (Dart `kya_core`, 719 tests, 99.5% coverage) | Done, then ported in M1' |
| **M2 Seed data** (224 ingredients, 80 recipes, Dart codec/validator) | Data done and moved to `seed/`; codec ported in M2'; spot-check pending |

### 6.2 iOS milestones

| Milestone | Status | Scope | Exit criteria | Est. |
|-----------|--------|-------|---------------|------|
| **M0' Swift foundations** | Done | `KyaCore` package skeleton, `scripts/check.sh`, `ios-ci.yml`, Xcode app skeleton with 4-tab `TabView` and theme tokens, ADR 009 | Gate and CI green; app runs on an iOS 27 simulator | 0.5 wk |
| **M1' Port core brain** | Done — 730 tests, 99% coverage, both TZs | Domain, normalizer, KitchenRanker, CravingRanker, TasteProfile, DeckBuilder, shopping builder, backup codec, repository ports + contracts, ported from `legacy/packages/kya_core`. **No UI** | Same goldens pass with frozen expected values; ≥ 90% coverage; green under `TZ=America/New_York` | 1.5–2 wk |
| **M2' Port seed codec/validator** | Done (code); **spot-check pending** | `SeedCodec` (strict), `SeedValidator`, `SeedCoverageTargets`; data already in `seed/` | Validators green on `seed/`; Dart decode-error cases reproduced; **Yasher's 20-recipe spot-check** (below) | 0.5–1 wk |
| **M3 Data layer** | Done — 76 contract checks on SwiftData | SwiftData `@Model`s, mappers, repository adapters, `AsyncStream` change observation, first-run seeding with `seedVersion` | Contract suite green on SwiftData adapters; mapper, seeding and migration tests green | 1 wk |
| **M4 Pantry + Onboarding** | Done | F1, F2 | Onboard in < 2 min; add/cycle/expiry works; store tests green | 1.5 wk |
| **M5 Recipes** | Done | F3: list, filters, detail, add/edit | Own recipe added and recommended | 1.5 wk |
| **M6 Swipe deck + both modes** | Done | F4, F4b, F4c, F5: swipe card (gesture + buttons + VoiceOver actions + Reduce Motion), mode toggle, pick sheet, Today's picks, taste onboarding step, history | Decks match core goldens; swipe, undo, never-show and picks work; "used up" sheet updates pantry | 2 wk |
| **M7 Shopping + Backup** | Done (backup format v2) | F6, F7 (`ShareLink` export, `fileImporter` import) | Out/Low auto-listed; bought → pantry; export → wipe → import restores everything | 1 wk |
| **M8 Polish + Beta** | Code done — 272 app unit + 18 UI tests; TestFlight + 2-wk dogfood pending | Accessibility audit (VoiceOver, Dynamic Type, contrast, 44 pt targets), empty/error states, app icon, launch screen, perf check on the oldest iPhone simulator the iOS 17 target supports, XCUITest E2E | TestFlight internal testing; **you use it daily for 2 weeks** | 1–1.5 wk |

**M2 spot-check list (Yasher, 20 recipes):** masala_dosa, poha, aloo_paratha, anda_bhurji,
dal_tadka, rajma_chawal, sambar, veg_biryani, curd_rice, aloo_gobi, baingan_bharta,
beans_poriyal, palak_paneer, butter_chicken, macher_jhol, malai_kofta, pav_bhaji,
chole_bhature, veg_hakka_noodles, gajar_halwa.

`legacy/` is deleted once M1' and M2' are done. Porting rules (frozen goldens, explicit
tie-breaks for Dictionary/Set order, SplitMix64 property tests for shuffle-dependent
DeckBuilder tests, strict seed parsing, calendar-day math) are in `AGENTS.md` §7.1.

### Working process
- **Vertical slices after M3:** each milestone ships a usable feature end-to-end (view → store → repository → SwiftData).
- **Small branches and PRs** per task (target < 300-line diffs); conventional commit messages.
  Woofy stages, you commit (per your standing rule).
- **Test-first for `KyaCore`:** write the golden scenario, then the scoring code.
- **Dogfooding gate:** v1.1 scope is decided from what annoys you in 2 weeks of real use,
  not from this document.
- Weekly checkpoint: demo on a device or simulator, update the milestone table, re-prioritise.

### Release plumbing (needed by M8)
- Apple Developer Program (annual fee) → **TestFlight only**. No Play Store.
- App display name: **kya-bnaye**. Bundle id: `com.yasher.kyabnaye` (placeholder; must be
  globally unique, confirm before the first TestFlight upload).

### 6.3 Overnight hardening pass (2026-09-27/28)

After M8 code-complete, six review lanes were queued to hunt for real defects and spec gaps
while Yasher was away (no commits made; nothing pushed). **Work runs sequentially, one lane
at a time** — parallel dispatch hit a temporary API budget wall, and a stalled agent's session
did not survive a later restart, so lane state must be tracked here, not assumed from agent
history. A fresh agent picking this up should re-read AGENTS.md + this section, confirm the
gate is still green (`MIN_COVERAGE=90 scripts/check.sh`), then continue with the next
**Not started** lane below. Do not repeat a **Done** lane.

| Lane | Scope | Status | Notes |
|---|---|---|---|
| L1 KyaCore | `KyaCore/Sources`, `KyaCore/Tests` | **Done** | Fixed a `BackupTimestamp` round-trip overflow bug (timestamps near Dart's `DateTime` bound decoded but couldn't re-encode); added regression tests. Deduplicated a `ShoppingItem` construction helper across `ShoppingListBuilder`/`RecipeShoppingPlan`. Full Recommend/Backup/Seed logic diffed against `legacy/packages/kya_core` line-by-line — no further bugs found. Gate: 731 tests, 99%+ coverage, green across 5 time zones. |
| L2 Data + App | `KyaBnaye/KyaBnaye/App`, `KyaBnaye/KyaBnaye/Data` + their tests | **Done** | No production bugs found (DataStoreActor atomicity/rollback, migration plan, seeding idempotency, launch-failure/Reset-data path all already solid). Closed a real test-coverage gap: added a relaunch-with-existing-persisted-store test at the `AppEnvironment`/`AppBootstrap` composition-root level (not just raw store reopen), plus two SeedLoader partial-failure/retry tests. Flagged one **product question, not a bug**: deleted seed recipes reappear on a seed-version bump (documented, intentional "no tombstones" trade-off in `KyaCore/Ports/SeedSync.swift`) — worth deciding whether Recipes UI should map "delete" to "hide" for seed-origin recipes. |
| L3 Home/Cooking/History | `Features/Home`, `Features/Cooking`, `Features/History` + tests/UITests | **In progress** | Gate was actually **red** on resume, not green as previously reported (confirms the "don't trust agent history" rule). Found and fixed 4 real defects, gate now passes (731 KyaCore tests, 99.17% cov; app build+test 18/18, 0 failures): (1) a line-length lint violation in `DeckStore+Scheduling.swift`; (2)+(3) a Swift 6 compiler crash ("region-based isolation checker" bug, flaky/order-dependent) triggered by `group.addTask { @MainActor in ... }` inside a `@MainActor`-isolated class's `withThrowingTaskGroup` — fixed in `HistoryStore.swift` and `DeckStore.swift` (7 call sites total) by dropping the redundant `@MainActor in` annotation, since the class is already `@MainActor` and the hop happens implicitly; audited the whole app for the same pattern, none left. (4) **The big one:** `DeckStore+Swipes.swift` — referenced by doc comments in `DeckStore.swift` and by every `DeckStoreTests.swift` test — **did not exist on disk**. `swipe()` and `undo()` were completely unimplemented; the app could not build at all. Reconstructed both from the test suite's contract (swipe right/left/neverShow, undo incl. un-hiding a reverted neverShow, expectedTopId race guard for `DeckArea`'s fling animation, error handling on a failed write) and added the file. Still open for this lane: full spec-conformance re-read against PLAN §2-3 (F4, F4b, F4c, F5) + AGENTS.md §3/§4, deck refresh on mode/meal/pantry change and midnight, Cooking flow concurrency, VoiceOver/Reduce Motion/Dynamic Type audit on the swipe card, screenshots in light/dark/largest text. |
| L4 Pantry/Onboarding/Recipes | `Features/Pantry`, `Features/Onboarding`, `Features/Recipes` + tests/UITests | **Not started** | Spec conformance against F1, F2, F3; input validation; hide/unhide/delete; screenshots in light/dark/largest text. |
| L5 Shopping/Settings/Shared/Theme | `Features/Shopping`, `Features/Settings`, `Shared/`, `Theme/` + tests/UITests | **Not started** | Spec conformance against F6, F7; backup export/import round-trip edge cases; WCAG AA contrast sweep of every colour pair in light and dark; screenshots. |
| L6 CI compatibility | `.github/workflows/**`, `scripts/check.sh` (read-only audit) | **Not started** | Confirm the GitHub-hosted macOS runner + Xcode version in `ios-ci.yml` actually exists and matches what the sources need (local dev is Xcode 27 / iOS 27 simulators, which is newer than any real GitHub runner as of this writing — the workflow's runner/Xcode selection needs to be resolved dynamically or pinned to the newest actually-available combination, not assumed). Audit sources for anything that needs a newer toolchain than CI will have. Read-only: report cross-lane fixes rather than editing sources directly. |

Ground rules every lane must follow (from `/tmp/overnight_rules.md`, which does not persist
across agent-session restarts — copy these into the lane's prompt directly, do not rely on
the file existing): no git commands at all (D11 — stage/commit is Yasher's alone); no
`rm -rf` or deleting directories; don't touch `legacy/`, `seed/*.json`; no network
installs/sudo; one simple shell command per call; skip anything risky or needing a product
decision and list it instead of guessing. Each lane edits only its own files/tests, uses its
own simulator + derived data path to avoid clashing with other lanes, keeps files < 400
lines and zero warnings, and adds behaviour-level tests (not thin mock-count tests) for every
fix. Finish with `APP=1 MIN_COVERAGE=90 scripts/check.sh` green before declaring the pass done,
then update this table and `AGENTS.md`'s status block.

---

## 7. Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Users stop updating the pantry | Recommendations go stale and the app dies | Level-based stock, staples assumed, "used up?" sheet after cooking, shopping→pantry auto-move |
| Seed data quality/effort | Bad suggestions on day 1 | Data done in M2, strict codec + validators, 20-recipe human spot-check |
| Ingredient naming chaos | Missed matches | Canonical ids + aliases; unknown input creates a user ingredient instead of failing |
| Scoring feels "off" | Low trust | Weights in config, explanations on every card, golden tests to prevent regressions |
| Port drifts from Dart behaviour | Subtle recommendation bugs | Frozen goldens from `legacy/`, explicit tie-breaks, TZ test run, porting rules (`AGENTS.md` §7.1) |
| Data loss (no cloud) | User anger | JSON backup/restore in v1; sync in v2 |
| Taste profile gets stuck in a bubble | Same 10 dishes forever | 20% explore cards, weak left-swipe signal, 30-day decay, "Reset my taste" in Settings |
| Swipe fatigue / accidental swipes | Wrong signals | Undo, buttons as alternative, deck capped at 20, left swipe = soft signal |
| Dish photos: licensing + app size | Legal risk, heavy app bundle | Licence-clean sources only, credits file, webp size budget, gradient + initial fallback |
| Scope creep | Never ships | This doc's YAGNI list; v1.1 decided only after dogfooding |
| Proxy blocks a needed package | Build breaks, work stalls | **Zero third-party dependency policy**; any dependency needs an ADR |
| macOS security tooling deletes toolchain binaries | Local builds break (as with Flutter) | Xcode-only toolchain: nothing downloaded or installed outside Xcode |
| iOS-only reach | Android households (most of India) can't use it | Accepted trade-off (ADR 009); Android dropped — revisit after the beta |
| TestFlight needs a paid Apple account | Blocks the beta | Enrol before M8 (still open) |

---

## 8. Decision log

| # | Decision | Date |
|---|----------|------|
| D1 | ~~**Flutter**, one codebase for Android + iOS~~ — **superseded by D12** | 2026-09-26 |
| D2 | **English only** in v1 | 2026-09-26 |
| D3 | **Diet & fasting deferred** to a later version | 2026-09-26 |
| D4 | **Two modes**, Kitchen + Craving, sharing one swipe deck and one taste profile | 2026-09-26 |
| D5 | **Kitchen mode is the default** when the app opens | 2026-09-26 |
| D6 | **Pan-Indian everyday recipe set** drafted by woofy (~80 dishes) | 2026-09-26 |
| D7 | **Photos: free-licensed downloads for now** (credits recorded); revisit before public release | 2026-09-26 |
| D8 | App name **kya-bnaye** is final | 2026-09-26 |
| D9 | **v1 only.** No group swipe: the family keeps swiping on one phone and decides together. "Pass the phone" stays on the v1.1 list and gets revisited after dogfooding | 2026-09-26 |
| D10 | Development on Yasher's Mac with **Xcode only** (Xcode 27, Swift 6.4, iOS simulators); no other toolchain | 2026-09-26 |
| D11 | User commits; **woofy only stages** changes, never runs `git commit` | 2026-09-26 |
| D12 | **Native iOS: Swift 6 + SwiftUI, iOS only**, zero third-party dependencies; Android dropped; `legacy/` Dart is the oracle until the port matches it (ADR 009) | 2026-09-26 |

### Still open (blocking only the beta)
- Apple Developer Program account: needed only at **M8** (TestFlight).
- Final bundle id (`com.yasher.kyabnaye` is a placeholder).
- Real food photography to replace the gradient fallback / downloaded images (before any public release).
- M2 exit: Yasher's 20-recipe spot-check (§6.2).
