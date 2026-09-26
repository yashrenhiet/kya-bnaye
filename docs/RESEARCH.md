# kya-bnaye — Competitive Research

> Research date: 2026-09-26. Six open-source GitHub projects were shallow-cloned and read
> source-first (models, matching/recommendation engines, services), not README-first.
> Line counts are Swift only.

## TL;DR

| # | Project | Size | License | Verdict |
|---|---------|------|---------|---------|
| 1 | [zhangxychina/family-kitchen](https://github.com/zhangxychina/family-kitchen) | 9.4k lines, **has tests** | **None** | Best-engineered by far. Steal ideas: planner scoring, portions, voice commands, "confirm before trust". |
| 2 | [abuzarbagewadi/RatatouilleSwiftUI](https://github.com/abuzarbagewadi/RatatouilleSwiftUI) | 1k lines | **None** | Closest to our idea (Indian, offline). Weighted "core vs masala" scoring is gold. |
| 3 | [MatthewKim07/chef-it](https://github.com/MatthewKim07/chef-it) | 14.5k lines | **MIT** | Hackathon app. Good normalizer + Ready/Almost/Excluded tiers. Only one we may legally copy code from. |
| 4 | [dominicmartinelli/FridgeCheck](https://github.com/dominicmartinelli/FridgeCheck) | 4.5k lines + Go server | **None** | Correct AI architecture (backend proxy + quotas). "Scan diff review" UX. |
| 5 | [andrewengland19/Pantry](https://github.com/andrewengland19/Pantry) | 3k lines | **None** | ADHD / low-friction philosophy, voice-shaped service API, barcode via OpenFoodFacts. |
| 6 | [safaauliyaa/cookable-ios](https://github.com/safaauliyaa/cookable-ios) | 0.6k lines | **None** | Toy. Bundled `ingredients.json`. Nothing else to take. |

**Licensing rule for us:** "no license" = all rights reserved. We take **ideas and algorithms
only** from #1, #2, #4, #5, #6 and re-implement in our own words. Only chef-it (MIT) may be
copied with attribution. The Kaggle "Indian Food 101" dataset used by Ratatouille has its own
license — verify before bundling.

---

## 1. family-kitchen (the gold standard)

### Architecture
- **Pure-logic Swift Package `FamilyCore`** (no UI imports) + thin SwiftUI app target.
  Core is unit-tested on macOS (`Tests/FamilyCoreTests`, 1.2k lines) plus UI tests.
- **Single value-type aggregate `FamilyState: Codable`** holding stock, meals, history,
  members, purchases; persisted as one versioned JSON file (`StateFile`) with lenient
  decoding so old files still open. Mutations are `mutating func` on the state = trivially
  testable, no ORM.
- **Canonical ingredient catalog** — `Ingredient(id, en, zh, unit, category, storage)`.
  Recipes reference ingredient **ids**, not strings. Exactly the normalization fix we flagged.
- **Protocol seam for recognition:** `PantryRecognizing` with a `ManualOnlyRecognizer`
  default — the app works fully without ML; ML is a plug-in.
- **CloudKit family sharing** with explicit conflict resolution ("never silently merged into
  duplicate inventory"), local backup before switching, offline-is-not-failure semantics.

### Recommendation / planner algorithm (`FamilyState.plan`, `swapOptions`)
Scores each candidate with interpretable integer-ish weights:
```
+ pantryCoverage * 6        (per-ingredient min(1, have/need), quantity-aware)
+ favourite bonus (3–5)
+ quick (<=30 min) bonus
+ seasonalScore(month) * 3–5
- repeatPenalty(days since eaten): <=7d:26, <=14d:18, <=28d:9, <=56d:3
      + 2 per extra time eaten in last 90 days   ("a rut, even if not lately")
- same starch as previous dinner (rice after rice): -100 in planning, -3 in swaps
- protein variety: -8 per repeat this week, -12 if same as yesterday
- already on this week's plan: -20
+ rotation tie-breaker so every catalogue dish surfaces over successive weeks
```
Hard filters first (allergens, spicy, breakfast vs dinner slot), soft scoring second.

### Features worth stealing
- **Portion factors by age**: adult 1.0; child <2: 0.25, 2–3: 0.4, 4–8: 0.65, 9–13: 0.85;
  + guests. Shopping list scales to "people actually eating".
- **Shopping = required − confirmed stock − already purchased** (`ShoppingLine.shortage`).
- **"Cooked" consumes stock** — `finish(consume:)` decrements pantry by the scaled recipe.
- **Warnings, not blocks**: "Eaten 3 days ago", "same starch as yesterday", "contains allergen".
- **Voice/text commands → confirmable actions** (`KitchenCommands.swift`): parses
  "we already have carrots", "ran out of eggs", "change tomorrow's dinner to X" into a typed
  `KitchenAction` enum the user confirms with one tap. Bilingual, handles Chinese numerals.
- **Scan findings are suggestions**, confidence-bucketed (Clear/Likely/Possible); nothing
  reaches the list unconfirmed. Hand-written label→ingredient map + ignore list
  ("food", "jar", "vegetable") so a generic label never ticks half the pantry.
- **Recipe import from URL via schema.org JSON-LD** — the only network call in the app; parse
  is separated from fetch so it's testable offline. Handles `@graph`, ISO-8601 durations.
- **Storage map**: appliance → compartment; "where is the ginger" shown while cooking.
- **Nutrition estimates** with honest caveats; returns `nil` when data missing rather than
  under-reporting.
- **Bilingual everything** (en/zh per field + per-step). Maps 1:1 to en/hi for us.

### Weaknesses
- One giant `FamilyState` aggregate (~740-line Models.swift) — violates SRP; will hurt at scale.
- Hardcoded US seasons & US allergen table. Weekly-plan-first UX is heavier than "what now?".

---

## 2. RatatouilleSwiftUI (closest idea: Indian + offline)

### Architecture
- Tiny: `PantryStore: ObservableObject` holding `[String]`, a `CSVParser`, and a static
  `RecipeRecommender`. No persistence (pantry lost on relaunch). Recipes re-parsed from CSV
  on every recommend call.
- Dataset: `indian_food.csv`, 255 dishes — `name, ingredients, diet, prep_time, cook_time,
  flavor_profile, course, state, region` (the Kaggle "Indian Food 101" set).

### The one great idea: ingredient roles with weights
Every ingredient is classified, and weighted by role **and rarity** (IDF-like):
```
core     (paneer, dal, poha, besan, rice, potato...)  2.4 + rarity*1.4
flavor   (haldi, jeera, garam masala, curry leaves...) 1.2 + rarity*0.8
optional (dhania, lemon, mint)                         0.7 + rarity*0.3
pantry   (salt, oil, ghee, sugar, water)               0.25 flat
rarity = 1 - (recipes containing ingredient / total recipes)
score  = weightedCoverage*0.70 + coreCoverage*0.25 + timeBonus(<=30m: .05)
```
Tie-break: fewer missing **core** items first. This is exactly right for Indian cooking:
missing salt/oil should never sink a dish; missing paneer must.

### Weaknesses
- Substring matching (`a.contains(b)`) → "rice" matches "rice flour", "oil" matches "boil".
- Unknown ingredients default to `core` (safe but noisy). No persistence, no tests.

---

## 3. chef-it (MIT — code reusable with attribution)

### Architecture
- Swift Package `ChefItKit` (Matching / Normalization / Models / Services / SeedData) +
  app target; Node/Express + Postgres backend for auth & social feed; XcodeGen `project.yml`.
- `RecipeSearchService` protocol with Edamam, TheMealDB and seed-data implementations,
  plus `RecipeDeduplicator` — clean strategy pattern for recipe sources.

### Worth stealing
- `IngredientNormalizer`: lookup map (`"cherry tomatoes" → "tomato"`) + plural fallback +
  category hints + `parseList` splitting on `, ; | \n \t` for fast bulk entry.
- **Three match tiers**: Ready (0 missing) / Almost (1–2 missing) / Excluded.
- **Human-readable rationale** per match ("uses your paneer; missing 1: kasuri methi").
- **Time-of-day feed**: breakfast / lunch / dinner / late-night with time filters.
- Deterministic sort (score, minutes, id) → stable, testable output.
- Cooking mode (step-by-step). Paste-a-list autocomplete.

### Weaknesses / anti-patterns
- **Calls OpenAI (`gpt-4o-mini`) directly from the client** — API key ships in the app.
- Social feed/comments/reviews = scope creep (YAGNI). Views of 1,766 lines.
- Pantry persisted in `UserDefaults`.

---

## 4. FridgeCheck

### Architecture
- SwiftUI + MVVM (`@Observable`) + SwiftData, iOS 17. `ModelContext` passed into VM methods.
- **Go backend proxy** (chi + SQLite + JWT): Sign in with Apple → session JWT in Keychain →
  backend holds the Claude key and **enforces per-user daily quotas** (5 scans / 20 recipe
  generations). Uses structured JSON output instead of "please only return JSON" prompts.
- Allergen tests on the server side (`allergen_test.go`).

### Worth stealing
- **The only correct way to ship LLM features**: never put keys in the app; proxy + quota.
- **`PantryItem.upsert`** — case-insensitive merge so rescans don't duplicate items.
- **Scan diff review**: after a scan, "these pantry items didn't appear — used up?"
  pre-selected but nothing deleted without explicit tap. Keeps inventory honest cheaply.
- Expiry states: expired / expiring within 3 days.
- Multi-photo scan (up to 15 images), images resized before upload.

### Weaknesses
- Requires sign-in + network for core value. No tests on the iOS side.

---

## 5. Pantry (ADHD-friendly)

### Architecture
- v1: SwiftUI + SwiftData (`Product(upc)`, `StockEntry`, `Location`, `MealEntry`,
  `SavedMeal(useCount, lastUsed)`, `ChatMessage`). v2 manifesto migrates to **Expo/React
  Native + expo-sqlite + iCloud JSON snapshot (last-write-wins)**.
- `SystemPromptBuilder` injects inventory + meal plan + dietary prefs into the LLM system
  prompt; LLM returns a fenced `MEAL_PLAN_UPDATE` JSON block the app applies.

### Worth stealing
- **Design principle: minimise friction** — if logging is effort, users quit.
- **Voice-shaped service API**: every capability is a verb (`findItem`, `logConsumption`,
  `suggestLocation`) usable by screens, Siri/App Intents, or an assistant alike.
- **Barcode → OpenFoodFacts** lookup (free, has decent Indian packaged-goods coverage),
  cached in an actor.
- `SavedMeal.useCount/lastUsed` — cheap "your usuals" list.
- Gamified "Pantry Score" (items located %, streaks) for habit building.
- Pragmatic sync reasoning: dataset is tiny (~100 KB) → full JSON snapshots beat diff sync.

### Weaknesses
- Client-side Anthropic API key stored in SwiftData settings. Hardcoded user name in prompt.

---

## 6. cookable-ios
Bundled `ingredients.json` loaded via a repository class; `FlowLayout` chip UI. Nothing new.

---

## Synthesis — what kya-bnaye should adopt

### Architecture decisions
1. **Pure, UI-free core module** (`KyaCore`) containing models, normalizer, recommender,
   planner, shopping math — fully unit-tested. UI is a thin shell. *(family-kitchen, chef-it)*
2. **Canonical `Ingredient` catalog with ids + multilingual aliases**
   (`tamatar`, `tomato`, `टमाटर`, `thakkali`). Recipes and pantry reference ids. Matching is
   exact-on-id after alias resolution — **no substring matching**. *(fixes Ratatouille bug)*
3. **Local-first, offline core value.** Network only for opt-in extras (URL import, AI,
   barcode lookup). *(family-kitchen, Ratatouille)*
4. **Recognition/AI behind protocols** with a manual default implementation. *(family-kitchen)*
5. **Any LLM call goes through our backend proxy with quotas** — never a key in the app. *(FridgeCheck)*
6. **Suggestions are never trusted blindly**: scans, voice, AI all produce confirmable
   actions. *(family-kitchen, FridgeCheck)*
7. Split state into small aggregates (Pantry, Recipes, MealLog, Shopping, Household) —
   don't repeat family-kitchen's god-object.

### Recommender v1 (merged best-of)
```
hardFilter: diet (veg/egg/non-veg/jain), allergens, fasting-day rules, meal slot
score =
    0.45 * weightedCoverage      # role weights: core / masala / optional / staple(salt, oil)
  + 0.20 * coreCoverage          # missing paneer hurts, missing salt doesn't
  + 0.15 * expiringSoonUse       # uses sabzi expiring within 3 days
  - repeatPenalty(daysSinceEaten)# stepped: 7d / 14d / 28d / 56d + rut penalty (90d)
  - sameBaseAsLastMeal           # rice-rice / roti-roti alternation
  + favourite / "usual" bonus
  + quick bonus if weekday & <=30 min
  + seasonal bonus (Indian seasons)
tiers:   Ready now | Missing 1–2 (non-staple) | Use it before it rots
explain: "Uses your palak (expires tomorrow). Missing: none."
```

### Indian-household specifics nobody has done
- **Diet model**: veg / eggetarian / non-veg / **Jain** (no onion, garlic, root veg) /
  **Satvik**; per-member, since households are mixed.
- **Fasting calendar**: Navratri, Ekadashi, Tuesday/Thursday/Saturday no-non-veg, Shravan,
  Ramzan (sehri/iftar slots). Auto-filter + vrat recipes (sabudana, kuttu, samak).
- **Meal structure**: a "meal" is often a **combo** — dal + sabzi + roti/rice + raita.
  Recommend *thali components*, not only single dishes. Plus chai-time snack & tiffin/lunchbox.
- **Indian seasons**: summer (lauki, karela, mango), monsoon, winter (sarson, gajar, methi,
  matar, bathua) — replaces family-kitchen's US table.
- **Staples assumption**: most Indian kitchens always have atta, rice, dal, onion, tomato,
  basic masalas → default "always have" set; zero-effort pantry start.
- **Languages**: English + Hindi first (Hinglish search: "aloo", "bhindi"); regional later.
- **Local units**: katori, chammach, mutthi, "1 packet"; kg/g/L for shopping.
- **Shopping split by vendor**: sabziwala / kirana / dairy / online (Blinkit/Zepto/BigBasket
  deep links later).
- **Leftovers**: rice → lemon rice / fried rice; roti → roti noodles / churi.
- **Cook/maid mode**: share today's menu to WhatsApp in Hindi for the household cook.
- **Portions**: joint families — members with age factors (family-kitchen) + guests.

### Explicit YAGNI (not in v1)
Social feed, comments, reviews (chef-it); appliance/shelf mapping & QR labels (family-kitchen,
Pantry); gamification score; nutrition; multi-device sync.

---

## Platform note (important)
Indian households are overwhelmingly **Android** (~95% market share). An iOS-only app would
miss most of the target user base. Options:
- **Flutter** — single codebase, strong in India's dev ecosystem, good offline DB (Drift/Isar).
- **React Native / Expo** — what Pantry v2 migrated to; expo-sqlite; large ecosystem.
- **Kotlin Multiplatform** — shared core logic + native UI per platform.
- **SwiftUI** — best iOS polish, but iOS-only.

Whatever we choose, the "pure core module" principle above stays: the recommender and data
model must be UI-independent and unit-tested.
