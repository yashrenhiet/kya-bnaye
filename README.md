# kya-bnaye

**"What should I make?"** — answered.

kya-bnaye is a native iOS app that solves the daily Indian-household cooking dilemma with a
simple swipe deck. **Kitchen mode** shows what you can cook right now with what's already in
your pantry. **Craving mode** learns from your swipes and shows you what you'll actually want
to eat. No account, no cloud, no ads — everything runs and stays on your phone.

[![iOS CI](https://github.com/yashrenhiet/kya-bnaye/actions/workflows/ios-ci.yml/badge.svg?branch=main)](https://github.com/yashrenhiet/kya-bnaye/actions/workflows/ios-ci.yml)
![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)
![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-lightgrey?logo=apple)
![Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

---

## Why

Every Indian household asks this question at least once a day, usually while staring into a
half-full fridge. Meal-planning apps tend to assume a Western pantry, a subscription, and an
internet connection. kya-bnaye assumes none of that:

- **Offline-first.** No account, no server, no network calls. Your pantry and swipe history
  never leave your phone unless you export a backup yourself.
- **Two moods, one deck.** Cooking with what you have (Kitchen) and browsing for something
  new to crave (Craving) are different tasks, so they get different ranking logic behind the
  same familiar swipe interface.
- **Learns quietly.** Every swipe is a signal. There's no rating dialog, no survey — just
  swipe left or right and the recommendations get sharper over time.
- **~80 pan-Indian recipes** and 224 ingredients ship in the box, so it's useful on day one.

## Features

- **Kitchen mode** — ranks recipes by what's actually in your pantry, so missing a single
  ingredient doesn't quietly tank a recipe you could otherwise make.
- **Craving mode** — a taste profile built entirely from an append-only swipe log, with
  cold-start handling for brand-new users.
- **Pantry tracking** — stock levels, expiry-aware suggestions, and a "use it up" nudge for
  ingredients about to go bad.
- **Shopping list** — generated from recipes you've swiped right on, with a one-tap "move
  bought items to pantry" flow.
- **Meal history** — what you cooked and when, feeding back into future recommendations.
- **Local backup & restore** — a portable JSON export/import, no account required.
- **Accessible by default** — Dynamic Type, VoiceOver labels, and non-gesture actions for
  every swipe, checked against WCAG 2.2 AA.

## Tech stack

| Layer | Choice |
|---|---|
| Language | Swift 6, strict concurrency, zero warnings |
| UI | SwiftUI |
| Persistence | SwiftData |
| Domain logic | `KyaCore` — a pure Swift package, Foundation-only, zero UI/persistence imports |
| Dependencies | None. On purpose — see [ADR 009](docs/adr/009-native-ios-swift.md). |
| Testing | Swift Testing / XCTest, coverage-gated at ≥ 90% |

The core recommendation and domain logic lives in `KyaCore`, a standalone Swift package with
no dependency on SwiftUI, SwiftData, or UIKit. The app is a thin adapter on top of it. This
split means the "brain" of the app is unit-testable in milliseconds, on any machine, without
a simulator.

## Getting started

### Requirements

- Xcode 26+ (Swift 6.4 toolchain)
- iOS 17+ simulator or device

### Clone and run

```sh
git clone https://github.com/yashrenhiet/kya-bnaye.git
cd kya-bnaye
open KyaBnaye/KyaBnaye.xcodeproj
```

Pick the **KyaBnaye** scheme, choose a simulator, and hit **⌘R**.

### Run the quality gate

```sh
scripts/check.sh              # KyaCore: format, build (-Werror), tests, coverage ≥ 90%
APP=1 scripts/check.sh        # also builds and tests the iOS app (~5 min)
```

Or just the core package, without a simulator:

```sh
cd KyaCore && swift test
```

## Project structure

```
kya-bnaye/
├── KyaCore/            # Swift package: domain models + recommender engine (Foundation only)
├── KyaBnaye/           # iOS app — SwiftUI views, SwiftData persistence, Xcode project
├── seed/               # bundled ingredient + recipe data (JSON)
├── scripts/            # local & CI quality gate, app icon generation
├── docs/               # architecture decisions, design notes, research
└── legacy/             # original Flutter/Dart prototype, kept temporarily as a reference
```

## Testing & quality bar

Every change is expected to pass the same gate CI runs:

- `swift format` lint (strict)
- Build with warnings treated as errors
- Full test suite, run once in the local timezone and once under `America/New_York` to catch
  daylight-saving bugs in date logic
- Line coverage ≥ 90% on `KyaCore`
- App build + unit/UI tests when `APP=1` is set

See [`scripts/check.sh`](scripts/check.sh) for the exact steps.

## Architecture decisions

Non-trivial technical calls (why Swift over Flutter, why no third-party dependencies, why an
append-only swipe log, etc.) are recorded as short ADRs in [`docs/adr/`](docs/adr/). Worth a
skim if you're wondering "why is this built this way."

## Contributing

Issues and pull requests are welcome. A few ground rules, in short:

- Keep diffs small and focused — one purpose per PR.
- `KyaCore` stays dependency-free and UI-framework-free; don't leak `SwiftUI`/`SwiftData`
  imports into it.
- New behavior needs tests alongside it, not after.
- Run `scripts/check.sh` before opening a PR.

## Status

Under active development. Core domain logic and the recommendation engine are in place with
high test coverage; the app UI is being built out feature by feature. Not yet on the App
Store.

## License

No license has been published for this repository yet, so all rights are reserved by
default. If you're interested in using or contributing to this project, please open an issue
to ask about licensing.
