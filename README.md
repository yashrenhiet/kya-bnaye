# kya-bnaye

**"What should I make?"** — a Flutter app (Android + iOS) that answers the daily Indian-household
cooking question through a two-mode swipe deck: **Kitchen mode** (what you can cook with
what's home right now) and **Craving mode** (what you'll love, learned from your swipes).

**Start here → [`AGENTS.md`](./AGENTS.md).** It's the single consolidated source of truth
for the product plan, feature list, architecture, domain model, milestones, and the
engineering/design standards every contribution is held to. Read it before anything else.

## Repo layout

```
kya-bnaye/
├── AGENTS.md              # ← read this first
├── pubspec.yaml           # Dart pub workspace root
├── packages/kya_core/     # pure-Dart domain + recommendation engine
├── app/                   # the Flutter application
├── docs/
│   ├── RESEARCH.md        # prior-art analysis (6 open-source apps)
│   ├── PLAN.md             # original planning doc, full screen wireframes
│   ├── design/RECOMMENDER.md  # recommender algorithm design
│   └── adr/                # architecture decision records
└── .github/workflows/ci.yml
```

## Quick start

```sh
flutter pub get                       # resolves the whole workspace from the root
(cd packages/kya_core && dart test)   # core domain/recommender tests
(cd app && flutter test)              # app widget tests
(cd app && flutter run)               # launch the app
```

## Status

Planning complete, approved for v1. Milestone **M0 (foundations)** is in progress — see
`AGENTS.md` section 7 for the full milestone table.
