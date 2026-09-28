# ADR 009: Native iOS app in Swift (supersedes Flutter, Riverpod, Drift)

**Status:** Accepted, 2026-09-26 (decided by Yasher) · **Supersedes:** ADR 001, 002, 003 ·
**Restates:** ADR 004 for Swift

## Context
M0 to M2 were built in Flutter. Two blockers on the only development machine made M3 and
later impossible to build locally:

1. **macOS security tooling deletes Flutter SDK host binaries.** `dart-sdk/bin/dartaotruntime`
   and `artifacts/engine/darwin-x64/impellerc` are removed on sight. `flutter build ios
   --simulator` fails with `kernel_snapshot_program failed: Unable to find dartaotruntime
   binary`. `dart test`, `dart analyze`, `flutter test`, `flutter run` and `flutter build`
   all need one of those binaries. Restoring them means bypassing the security flag, which
   is IT's decision.
2. **The corporate proxy blocks pub.dev archives.** It returns `403 MediaTypeBlocked` for
   many packages, and not always the same ones: drift, drift_dev, sqflite_common,
   path_provider (jni_util), and share_plus dependencies among them. There is no internal
   pub mirror, because Dart pub is not an Artifactory package type.

A probe SwiftUI + SwiftData + Swift Testing package, with **zero third-party dependencies**,
built and passed on the iPhone 18 Pro simulator (Xcode 27, Swift 6.4). Nothing it needs
goes through the proxy.

## Options
- **Stay on Flutter and wait for an IT allowlist plus a pub.dev proxy exception.** This
  keeps the Android reach (ADR 001). But the timeline is unknown, and both exceptions
  have to be granted and then keep holding. Progress on everything past M2 stops until
  then.
- **Kotlin Multiplatform or React Native.** Both still need large toolchain and package
  downloads (Gradle/Maven, npm, CocoaPods) through the same proxy and security tooling,
  so they carry the same class of risk with a rewrite on top. Rejected.
- **Native Swift/SwiftUI with zero third-party dependencies.** Everything ships with Xcode,
  which is already installed and allowed. Verified by the probe. The cost is losing
  Android. **Chosen.**

## Decision
Build kya-bnaye as a **native iOS-only app**: Swift 6 (language mode 6, strict
concurrency), SwiftUI, `@Observable`, SwiftData for local storage, Swift Testing for tests.
**Android is dropped.** Taking on any third-party dependency requires its own ADR.

### Architecture: keep ports-and-adapters (restates ADR 004)
- **Option A: SwiftData `@Query` directly in views.** This is idiomatic SwiftUI and means
  less code. But `@Model` reference types would spread through the UI. The recommender
  would have to accept persistence types or copy them ad hoc, SwiftData would become
  necessary to test logic, and a v2 sync adapter would require touching views.
- **Option B: keep the invariant. Chosen.**
  - `KyaCore` is a SwiftPM package that imports **Foundation only**. Its domain types
    are immutable `Sendable` structs and enums. It also holds the recommender, shopping
    builder, backup and seed codecs, and the repository protocols (ports).
  - SwiftData `@Model` classes exist **only** in `KyaBnaye/Data/`. They map to and from
    `KyaCore` structs and implement the `KyaCore` repository protocols.
  - Views observe `@Observable` stores. The stores get their data through `KyaCore`
    repository protocols. **No view imports SwiftData.**
  - `KyaCore` targets iOS 17 and macOS 14, so `swift test` runs on the host with no
    simulator.

## Consequences
- The app is iOS-only. Most of the Indian audience is on Android (`docs/RESEARCH.md`),
  so they are out of reach until a later decision revisits this. Distribution is
  TestFlight only. There is no Play Store.
- `kya_core` is ported to `KyaCore` against **frozen goldens**. The Dart code in
  `legacy/` (719 passing tests) is the behavioural oracle. Expected values are copied
  from it, not recomputed. The only exceptions are tests that depend on the seeded
  RNG, because Dart's `Random` sequence is not reproducible in Swift. `legacy/` is deleted
  once `KyaCore` passes the same goldens.
- The seed JSON format is unchanged. It moved to repo-root `seed/`, and `imageAsset`
  becomes `images/<recipe id>.webp`, relative to `seed/`.
- The product decisions (ADR 005 to 008) and the recommender design are unchanged.
- The local gate is `scripts/check.sh`: swift format lint, `swift build` with warnings
  as errors, and `swift test` with ≥90% coverage. CI runs on a GitHub macOS runner.
- The team needs Swift, not Dart, from here on.
