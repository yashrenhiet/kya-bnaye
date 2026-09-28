# kya-bnaye

**"What should I make?"** is a native **iOS app** (Swift 6, SwiftUI) that answers the daily
Indian-household cooking question with a two-mode swipe deck. **Kitchen mode** shows what
you can cook with what's at home right now. **Craving mode** shows what you'll love, learned
from your swipes. The app works offline, needs no account, and has zero third-party
dependencies.

**Start here → [`AGENTS.md`](./AGENTS.md).** It is the source of truth for the product,
architecture, milestones and engineering standards. The move from Flutter to native iOS is
recorded in [`docs/adr/009-native-ios-swift.md`](docs/adr/009-native-ios-swift.md).

## Layout

```
kya-bnaye/
├── AGENTS.md          # read this first
├── KyaCore/           # SwiftPM package: domain + recommender, Foundation only
├── KyaBnaye/          # iOS app (Xcode project, SwiftUI; SwiftData only in Data/), coming in M0'
├── seed/              # bundled ingredient + recipe JSON
├── scripts/check.sh   # local gate
├── legacy/            # Flutter/Dart original, used as the behaviour oracle for the port (temporary)
└── docs/              # ADRs, recommender and seed design, research, original plan
```

## Develop

Requires Xcode 27 (Swift 6.4).

```sh
scripts/check.sh                 # swift format lint, build (warnings as errors), tests, coverage ≥ 90%
(cd KyaCore && swift test)       # core tests only, on the host, no simulator
```

Once the app project lands, open `KyaBnaye/KyaBnaye.xcodeproj` in Xcode and run the
`KyaBnaye` scheme on an iOS simulator.

## Status

The Swift pivot happened on 2026-09-26. Swift foundations (M0') are in progress. See
`AGENTS.md` §7.
