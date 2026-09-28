# ADR 004: Pure-Dart `kya_core` package, isolated from Flutter

**Status:** Accepted, 2026-09-26 · **Carried over to Swift by [ADR 009](009-native-ios-swift.md)**

> Note (2026-09-26): the principle still holds, and the names change. `kya_core` becomes
> the SwiftPM package `KyaCore/`, which imports Foundation only (no SwiftUI, SwiftData
> or UIKit). `app/` becomes `KyaBnaye/`, and its SwiftData adapters in `KyaBnaye/Data/`
> implement the `KyaCore` protocols. The package boundary enforces the rule: `KyaCore`'s
> `Package.swift` declares no dependencies. The Dart implementation (now `legacy/`) is
> the port's oracle. The body below describes the original Dart layout.

## Context
The recommendation engine (two ranking strategies, taste-profile derivation, deck
composition — see `docs/design/RECOMMENDER.md`) is the single most important, most
algorithmically tricky part of this app, and the part most in need of fast, exhaustive
unit testing (golden scenarios, edge cases). Testing it through the widget tree would be
slow and would tempt logic to leak into widgets over time.

## Decision
Split the repository into a **Dart pub workspace** with two members: `packages/kya_core`
(pure Dart — domain models, normalizer, recommender, shopping builder, backup codec,
repository *interfaces*) and `app/` (the Flutter application, which depends on
`kya_core` and provides the concrete Drift-backed implementations of its interfaces).

## Alternatives considered
- **Single Flutter app, logic in `lib/domain/`** — simplest to start, but nothing stops
  a Flutter import from creeping into "pure" domain code over time; the boundary is only
  a convention, not enforced by the package system.
- **Three packages** (`kya_core`, `kya_data`, `app`) — considered for a stricter
  ports-and-adapters split, but rejected as premature: at this app's size, `app/lib/data/`
  is a fine home for the Drift adapters, and splitting it out only adds a third
  `pubspec.yaml`/CI target for no current benefit. Revisit if a second consumer of the
  data layer (e.g. a companion CLI or widget extension) appears.

## Consequences
- `kya_core` can only ever depend on `collection`/`meta`-style pure-Dart packages — a
  Flutter import in `kya_core` is a build error, not just a lint warning, because the
  package's `pubspec.yaml` has no `flutter` dependency at all.
- `dart test` on `kya_core` runs in milliseconds with no emulator/simulator required,
  which is what makes the ≥90% coverage target in `AGENTS.md` §6 realistic.
- Any PR that imports `package:flutter/...` inside `packages/kya_core/lib` is rejected in
  review regardless of how small it looks (`AGENTS.md` §0, Architect standards).
