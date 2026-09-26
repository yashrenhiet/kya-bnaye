# ADR 002: Riverpod for state management

**Status:** Accepted — 2026-09-26

## Context
The app needs a state-management approach that (a) keeps business logic out of widgets,
(b) is trivially testable without an emulator, and (c) supports swapping a data source
(Drift now, cloud sync in v2) without rewriting controllers.

## Decision
Use **Riverpod** (`flutter_riverpod`) for all app-level state: providers for repositories
(implementing `kya_core` ports), `Notifier`/`AsyncNotifier` for screen-level controllers.

## Alternatives considered
- **Provider + ChangeNotifier** — Riverpod's predecessor; lacks compile-time provider
  safety and makes overriding dependencies in tests more awkward.
- **Bloc/Cubit** — mature and testable, but more ceremony (events + states) than this
  app's screens need; most screens here map cleanly to "load → show → mutate" without
  needing an explicit event-sourcing layer.
- **Plain `setState` / `InheritedWidget`** — rejected: doesn't scale past M0's placeholder
  screens and couples business logic to `BuildContext`.

## Consequences
- Every controller can be unit-tested with a `ProviderContainer` and fake repositories,
  no widget pump required (see `AGENTS.md` §6).
- No `BuildContext` needed to read app state outside the widget tree.
- Code-generation (`riverpod_generator`) is deliberately **not** adopted yet — plain
  `Provider`/`NotifierProvider` declarations are enough for this app's size and avoid a
  `build_runner` step in CI. Revisit only if boilerplate becomes a real problem.
