# Seed data guide

> Status: M2 in progress · Date: 2026-09-26 · Parent: `AGENTS.md` §5.6
> How the bundled ingredient catalogue and recipe book are laid out, written and validated.

## 1. Layout

Everything lives in repo-root `seed/` and ships as-is in the app bundle. There is no merge
or build step. The format is language-neutral. It is unchanged from the Flutter era, apart
from the `imageAsset` path (§8).

```
seed/
├── manifest.json                 # seedVersion + ordered fragment paths
├── ingredients/
│   ├── sabzi_fruit.json
│   ├── staples_grains_dal_dairy.json
│   └── masala_packaged_other.json
├── recipes/
│   ├── breakfast.json  dal_rice.json  sabzi.json
│   └── curry_nonveg.json  street_snacks.json  misc.json
├── images/                       # not present yet; see §8
└── IMAGE_CREDITS.md
```

`manifest.json`:
```json
{ "seedVersion": 1,
  "ingredients": ["ingredients/sabzi_fruit.json", "..."],
  "recipes": ["recipes/breakfast.json", "..."] }
```
Paths are relative to `seed/`. Bump `seedVersion` whenever shipped seed content
changes, so first-run seeding can add new rows without clobbering user edits.

Decoding and validation are pure Swift in `KyaCore/Sources/KyaCore/Seed/`: `SeedCodec`
(strict JSON → `SeedBundle`) and `SeedValidator` (rules in §7). A seed-asset test in
`KyaCore/Tests/KyaCoreTests/` runs both against the real files in `seed/`. The codec is
**strict**. It parses with `JSONSerialization` and checks keys explicitly, so unknown keys,
missing required keys, wrong types and unknown enum values are errors with a file/path
location. Plain `Codable` silently ignores unknown keys, so it is not used here. The Dart
original (`legacy/packages/kya_core/lib/src/seed/`) is the oracle until it is deleted.

## 2. JSON shape

### Ingredient fragment
```json
{ "ingredients": [
    {"id": "potato", "name": "Potato", "aliases": ["aloo", "batata"], "category": "sabzi", "role": "core", "buyFrom": "sabziwala", "shelfLifeDays": 30}
] }
```
| key | type | notes |
|---|---|---|
| `id` | string | `^[a-z][a-z0-9_]*$`, never starts with `user_` (reserved for user-created) |
| `name` | string | Display name, trimmed, unique |
| `aliases` | string[] | Lowercase, may be empty |
| `category` | enum | §3 |
| `role` | enum | §3 |
| `buyFrom` | enum | §3 |
| `shelfLifeDays` | int? | 1..3650; omit when the item doesn't meaningfully expire |

### Recipe fragment
```json
{ "recipes": [
  { "id": "aloo_gobi", "name": "Aloo Gobi", "mealTypes": ["lunch", "dinner"], "minutes": 30, "base": "roti",
    "tags": {"region": "north", "dishType": "drySabzi", "flavours": ["spicy", "savoury"], "heaviness": "medium", "protein": "vegOnly"},
    "ingredients": [
      {"ingredientId": "potato", "quantityText": "2 medium"},
      {"ingredientId": "coriander_leaves", "quantityText": "handful", "isOptional": true}
    ],
    "steps": ["Heat oil, add jeera.", "..."],
    "imageAsset": null }
] }
```
`shelfLifeDays`, `isOptional` and `imageAsset` may be omitted (null / false / null).
**No other keys are allowed.** In particular seed files must not contain `isUserCreated`,
`source`, `isFavorite` or `isHidden`: the codec forces `source=seed` and
`isUserCreated=false`.

### Formatting
- One JSON object per line for ingredient rows and recipe-ingredient rows, so diffs stay
  reviewable.
- Ingredient rows are sorted by `id` within each fragment.

## 3. Enum values

Spelled exactly as the Swift enum `String` raw value (camelCase, byte-identical to the legacy
Dart `.name`). Anything else is a decode error.

| field | values |
|---|---|
| `category` | sabzi, fruit, dairy, grains, dal, masala, oilGhee, packaged, other |
| `role` | core, flavor, optional, staple |
| `buyFrom` | sabziwala, kirana, dairy, other |
| `mealTypes` (non-empty set) | breakfast, lunch, dinner, snack |
| `base` | rice, roti, bread, none |
| `tags.region` | north, south, east, west, gujarati, punjabi, indoChinese, continental, street |
| `tags.dishType` | dal, curry, drySabzi, rice, bread, breakfast, snack, sweet, onePot |
| `tags.flavours` (non-empty set) | spicy, tangy, sweet, savoury, mild |
| `tags.heaviness` | light, medium, heavy |
| `tags.protein` | paneer, dalLegume, egg, chicken, mutton, fish, vegOnly |

## 4. Ingredient conventions

### Roles
Role decides Kitchen-mode viability: a recipe is dropped when more than 2 non-optional
ingredients are missing, and only `staple` (assumed present unless Out) and `optional`
(never missing) are free.

| role | meaning | examples |
|---|---|---|
| `staple` | In virtually every Indian kitchen; assumed present. 12–25 total, only in masala / oilGhee / grains / other | see list below |
| `flavor` | Aromatics, souring agents, whole spices, speciality masalas, sauces | onion, tomato, ginger, garlic, green_chilli, ginger_garlic_paste, kasuri_methi, tamarind, sambar_powder, pav_bhaji_masala, bay_leaf, cloves |
| `core` | The thing the dish is about: vegetables, fruit, dairy, grains, dals, proteins | potato, paneer, toor_dal, rice, chicken |
| `optional` | Garnish / nice-to-have catalogue items | coriander_leaves, mint, curry_leaves, spring_onion, sev, boondi, nuts, papad, pickle |

**Staples (15):** salt, turmeric, red_chilli_powder, coriander_powder, cumin_seeds,
cumin_powder, mustard_seeds, asafoetida, garam_masala, fenugreek_seeds, carom_seeds,
dry_red_chilli, cooking_oil, ghee, sugar. `wheat_flour` and `rice` are deliberately **not**
staples: they are `core`, so the pantry tracks them.

### Borderline role decisions
- `dry_red_chilli` → staple (a basic tadka item like mustard seeds). The other whole
  spices (bay_leaf, cinnamon, cardamoms, cloves, black_pepper, star_anise...) → flavor.
- `fenugreek_seeds`, `carom_seeds` → staple (small, long-lived, near-universal).
- `chaat_masala` → flavor, not optional: it defines chaat dishes.
- `spring_onion` → optional (mostly garnish). Indo-Chinese recipes still list it; R6 needs
  another core ingredient anyway.
- `chilli_flakes`, `oregano`, `mixed_herbs`, `rose_water`, `kewra_water` → optional
  (sprinkles and finishing aromas).
- `cashews`, `almonds`, `raisins`, `papad`, `pickle`, `sev`, `boondi` → optional. `peanuts`
  → flavor (essential in sabudana khichdi, poha).
- `lemon`, `raw_mango`, `shallots`, `green_garlic`, `red_chilli_fresh` → flavor.
- `cornflour` → flavor (binder/thickener, not the dish itself). `malai` → core like other
  dairy.
- Condiments and leaveners (`tomato_ketchup`, sauces, `baking_soda`, `eno`, `fresh_yeast`,
  `jaggery`, `honey`) → flavor.
- Recipe authors should still set `isOptional: true` on garnish rows (coriander, curry
  leaves, mint) and may mark whole spices optional when the dish works without them.

### Category and buyFrom
- sabzi, fruit → sabziwala (coconut and dates included). dairy → dairy.
- grains, dal, masala, oilGhee, packaged → kirana.
- Meat, fish and eggs live in `other` (no meat category in v1) with `buyFrom: other`;
  tofu too. Other kitchen items in `other` (sugar, jaggery, honey, rose/kewra water, yeast)
  buy from kirana.

### shelfLifeDays
Typical days once bought/opened. Required for every sabzi, fruit and dairy item and for
eggs, chicken, mutton, fish, prawns. Omitted for items that don't meaningfully expire
(salt, sugar, oils, whole spices, vinegar, honey). Ground masalas use 180.

### Names and aliases
- `name` is what an Indian English grocery pack or shopper would say: English where it is
  the common word (Okra, Semolina, Gram Flour, Chickpeas), the Indian term where that *is*
  the English usage (Paneer, Ghee, Toor Dal, Pav, Khoya, Malai).
- Hindi/regional names and spellings go in `aliases`, lowercase.
- An alias must not equal the item's own normalised name, and a normalised key (name or
  alias; lowercase, trimmed, collapsed spaces) maps to exactly one ingredient.

### Alias decisions
- `sitaphal` = custard apple (not pumpkin).
- Bare `sarson` is not an alias anywhere; use `sarson ka saag` (mustard_greens) and
  `sarson ka tel` (mustard_oil).
- `methi` = fenugreek leaves; seeds are `methi dana`; dried leaves are `kasuri methi`.
- `corn flour` is not an alias. `cornflour` has `cornstarch`; `makki_atta` is named
  "Maize Flour".
- `chole` → kabuli_chana only (chole_masala has no `chole` alias).
- `dalia` → broken_wheat only (roasted_chana does not use it).
- `lal mirch` → red_chilli_powder; fresh red chilli has no Hindi alias.

## 5. Recipe conventions
- **Water is never an ingredient.**
- **Base** = the starch the dish is cooked in or canonically served with: dals, rajma,
  kadhi, sambar, rasam, fish/egg curries → rice; dry sabzis and paneer curries → roti;
  paratha/puri/bhatura → roti; pav/sliced bread → bread; breakfast batters and snacks →
  none.
- Idli and dosa use `idli_dosa_batter` as the core ingredient.
- Coriander, curry leaves and mint set `isOptional: true` when used as garnish.
- All recipe text is written by us. Nothing is copied from websites or Kaggle.

## 6. Frozen lists

Do not add or rename ids without updating this guide and bumping `seedVersion`.

### Ingredients (224)
**sabzi_fruit.json (76)**
- sabzi (54): amaranth_leaves, ash_gourd, baby_corn, beetroot, bitter_gourd, bottle_gourd,
  brinjal, broccoli, cabbage, capsicum, carrot, cauliflower, cluster_beans, colocasia,
  coriander_leaves, cucumber, curry_leaves, dill, drumstick, fenugreek_leaves,
  french_beans, garlic, ginger, green_chilli, green_garlic, green_peas, ivy_gourd,
  jackfruit, lemon, lettuce, lotus_stem, mint, mushroom, mustard_greens, okra, onion,
  pointed_gourd, potato, pumpkin, radish, raw_banana, raw_mango, raw_papaya,
  red_chilli_fresh, ridge_gourd, shallots, spinach, spring_onion, sweet_corn,
  sweet_potato, tinda, tomato, yam, zucchini
- fruit (22): apple, banana, chikoo, coconut, custard_apple, dates, grapes, guava, jamun,
  kiwi, litchi, mango, muskmelon, orange, papaya, pear, pineapple, plum, pomegranate,
  strawberry, sweet_lime, watermelon

**staples_grains_dal_dairy.json (58)**
- dairy (11): butter, buttermilk, cheese, cheese_slices, curd, fresh_cream, hung_curd,
  khoya, malai, milk, paneer
- grains (24): bajra_flour, basmati_rice, besan, bread, broken_wheat, cornflour,
  flattened_rice, hakka_noodles, idli_dosa_batter, instant_noodles, jowar_flour, maida,
  makki_atta, oats, pasta, pav, puffed_rice, ragi_flour, rice, rice_flour, sabudana,
  sooji, vermicelli, wheat_flour
- dal (16): chana_dal, dried_peas, kabuli_chana, kala_chana, lobia, masoor_dal,
  moong_dal, moth_beans, rajma, roasted_chana, soya_chunks, toor_dal, urad_dal,
  whole_masoor, whole_moong, whole_urad
- oilGhee (7): coconut_oil, cooking_oil, ghee, groundnut_oil, mustard_oil, olive_oil,
  sesame_oil

**masala_packaged_other.json (90)**
- masala (48): amchur, anardana, asafoetida, bay_leaf, biryani_masala, black_cardamom,
  black_pepper, black_salt, carom_seeds, chaat_masala, chilli_flakes, chole_masala,
  cinnamon, cloves, coriander_powder, cumin_powder, cumin_seeds, dry_coconut,
  dry_ginger_powder, dry_red_chilli, fennel_seeds, fenugreek_seeds, garam_masala,
  ginger_garlic_paste, green_cardamom, kashmiri_chilli_powder, kasuri_methi,
  kitchen_king_masala, mace, meat_masala, mixed_herbs, mustard_seeds, nigella_seeds,
  nutmeg, oregano, panch_phoron, pav_bhaji_masala, poppy_seeds, rasam_powder,
  red_chilli_powder, saffron, salt, sambar_powder, sesame_seeds, star_anise, tamarind,
  tandoori_masala, turmeric
- packaged (30): almonds, baking_powder, baking_soda, boondi, bread_crumbs, cashews,
  coconut_milk, coffee, condensed_milk, cornflakes, custard_powder, eno, frozen_paratha,
  green_chilli_sauce, gulab_jamun_mix, jam, mayonnaise, papad, peanut_butter, peanuts,
  pickle, raisins, red_chilli_sauce, schezwan_sauce, sev, soy_sauce, tea, tomato_ketchup,
  tomato_puree, vinegar
- other (12): chicken, eggs, fish, fresh_yeast, honey, jaggery, kewra_water, mutton,
  prawns, rose_water, sugar, tofu

### Recipes (80)
Format: id — meal types (B/L/D/S) · region · dishType · base. Dal/rice/curry dishes are
lunch + dinner unless noted.

**breakfast.json (15)**: poha B,S west breakfast none · upma B south breakfast none ·
idli_sambar B south breakfast none · masala_dosa B,D south breakfast none ·
onion_uttapam B,D south breakfast none · besan_chilla B north breakfast none ·
moong_dal_chilla B north breakfast none · aloo_paratha B,L punjabi bread roti ·
gobi_paratha B,L punjabi bread roti · paneer_paratha B,L punjabi bread roti ·
methi_thepla B,S gujarati bread roti · puri_bhaji B,L north breakfast roti ·
sabudana_khichdi B west breakfast none · anda_bhurji B,D north breakfast bread (egg) ·
vegetable_daliya B,D north onePot none

**dal_rice.json (20)**: dal_tadka north dal rice · dal_makhani punjabi dal roti ·
rajma_chawal punjabi curry rice · chole_masala punjabi curry roti · sambar south dal rice ·
rasam south dal rice · yellow_moong_dal north dal rice · kadhi_pakora punjabi curry rice ·
gujarati_dal gujarati dal rice · bengali_masoor_dal east dal rice ·
chana_dal_lauki north dal roti · jeera_rice north rice rice · veg_pulao north rice rice ·
veg_biryani north rice rice (heavy) · lemon_rice south rice rice ·
curd_rice south rice rice (mild) · moong_dal_khichdi north onePot rice (light) ·
bisi_bele_bath south onePot rice · veg_fried_rice indoChinese rice rice ·
masale_bhat west rice rice

**sabzi.json (9)**: aloo_gobi, jeera_aloo, bhindi_masala north drySabzi roti ·
baingan_bharta punjabi drySabzi roti · cabbage_matar, aloo_methi, aloo_baingan north
drySabzi roti · beans_poriyal south drySabzi rice · aloo_posto east drySabzi rice

**curry_nonveg.json (17)**: palak_paneer punjabi curry roti · matar_paneer north ·
paneer_butter_masala punjabi (heavy) · kadai_paneer punjabi · aloo_matar, dum_aloo north ·
malai_kofta north (heavy) · mix_veg_curry north · veg_kurma south · avial south rice ·
butter_chicken punjabi roti · chicken_curry north rice · chicken_biryani south rice rice ·
chilli_chicken indoChinese snack none (D,S) · egg_curry east rice · macher_jhol east rice
(fish) · mutton_curry north rice

**street_snacks.json (16)**: pav_bhaji D,S street curry bread · chole_bhature L punjabi
bread roti (heavy) · vada_pav S street snack bread · misal_pav B,S west curry bread ·
bhel_puri S street snack none (light) · samosa S street snack none · aloo_tikki_chaat S
street snack none · onion_pakora S north snack none · khaman_dhokla B,S gujarati snack
none · medu_vada B,S south snack none · bombay_sandwich B,S street snack bread ·
veg_hakka_noodles D,S indoChinese onePot none · gobi_manchurian D,S indoChinese snack
none · chilli_paneer D,S indoChinese snack none · masala_maggi B,S street snack none ·
masala_pasta D,S continental onePot none

**misc.json (3)**: sooji_halwa B,S north sweet none · gajar_halwa S,D punjabi sweet none ·
rice_kheer S,D north sweet none

## 7. Validation rules (summary)

`SeedCodec` rejects unknown or forbidden keys, unknown enum values and duplicate ids across
fragments, with a location such as
`recipes/sabzi.json › recipes[3].tags.region: unknown value "nort" (allowed: north, ...)`.
`SeedValidator` collects every issue (no warnings; exemptions are explicit sets).

| rule | check |
|---|---|
| I1 | id format, no `user_` prefix, unique |
| I2 | name non-blank, trimmed, unique after normalising |
| I3 | every normalised name/alias maps to one id; no alias repeated or equal to own name |
| I4 | aliases non-blank and lowercase |
| I5 | shelfLifeDays null or 1..3650; required for sabzi, fruit, dairy, eggs, chicken, mutton, fish, prawns |
| I6 | sabzi/fruit → sabziwala; dairy → dairy (exemptions: `SeedRuleExemptions`, passed as `validate(exemptions: ...)`, default `{coconut}`) |
| I7 | 12..25 staples, only in masala, oilGhee, grains, other |
| I8 | rows sorted by id within each fragment (asset test) |
| R1 | recipe id format, unique; names unique after normalising |
| R2 | mealTypes non-empty |
| R3 | minutes 1..240 |
| R4 | 2..12 steps, each non-blank and ≤200 chars |
| R5 | ingredients non-empty, ids exist, no duplicates, quantityText non-blank |
| R6 | at least one required ingredient with catalogue role core |
| R7 | at most 8 required ingredients that are neither staple nor optional role |
| R8 | flavours non-empty; mild never with spicy |
| R9 | imageAsset null or `images/<recipe id>.webp` (relative to `seed/`) and the file exists |
| R10 | dishType rice → base rice; dishType bread → base roti or bread |
| R11 | protein tag matches a required ingredient (paneer, eggs, chicken, mutton, fish/prawns, a dal-category item for dalLegume); vegOnly has none of those |

Coverage targets (`SeedCoverageTargets` in `KyaCore/Sources/KyaCore/Seed/`, enabled once
content is complete):
- recipes 75..90, ingredients 220..280
- breakfast ≥15, lunch ≥35, dinner ≥35, snack ≥12
- regions north/punjabi/south ≥8 each; east/west/gujarati/street/indoChinese ≥3;
  continental ≥1; every dishType ≥3
- base rice ≥12, roti ≥15, bread ≥4, none ≥12, no base >45%
- each heaviness ≥15%; quick (≤30 min) ≥35%; non-veg (chicken/mutton/fish/egg) 8–15%;
  paneer ≥5; dalLegume ≥10
- deck viability: staples + onion, tomato, potato, ginger, garlic, green_chilli, curd,
  milk, wheat_flour, rice, toor_dal → at least 5 Kitchen-mode candidates per meal type.

## 8. Photos
- v1 ships with every `imageAsset` null. The app renders a gradient and initial fallback.
- Photos are sourced by a human (licence checks need judgement). Prefer CC0, public domain,
  Unsplash or Pexels. Avoid CC BY-SA, NC and ND licences.
- `seed/images/<recipe id>.webp` (stored in JSON as `images/<recipe id>.webp`), ≤60 KB (target ~40 KB), one row per file in
  `IMAGE_CREDITS.md` (file, recipe id, title, author, source URL, licence, licence URL,
  retrieved, modifications).
- Add `seed/images/` to the KyaBnaye app bundle resources only when the first image lands.
