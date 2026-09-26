# kyabnaye (Flutter app)

The Flutter application for **kya-bnaye**. See the repo root `AGENTS.md` for the full
product plan and architecture — this file only covers running this package day to day.

## Layout
See `AGENTS.md` section 5.2 for the full module layout. In short:
- `lib/bootstrap/` — app root widget, DI wiring
- `lib/routing/` — go_router config, the 4-tab shell
- `lib/theme/` — colour/spacing/theme tokens (see `lib/theme/app_colors.dart` for the
  current first-draft palette and its rationale)
- `lib/features/*` — one folder per screen (home, pantry, recipes, shopping, history,
  settings); each is currently a placeholder until its milestone (`AGENTS.md` section 7)
- `lib/shared/widgets/` — widgets shared by 2+ features

Business logic (domain models, the recommender, shopping-list builder) lives in the
sibling `packages/kya_core` pure-Dart package, not here — see ADR 004.

## Running
This repo is a Dart pub workspace. Resolve dependencies **from the repo root**, not from
inside `app/`:

```sh
cd .. && flutter pub get
```

Then, from this directory:

```sh
flutter run                 # launch on a connected device/simulator/emulator
flutter test                # widget + unit tests in test/
flutter analyze             # static analysis (must be zero warnings, see AGENTS.md §6)
dart format --set-exit-if-changed lib test   # formatting check
```
