# ADR 003: Drift (SQLite) as the local data store

**Status:** Accepted — 2026-09-26 · **Implemented:** milestone M3

## Context
The app is offline-first (ADR 006) and needs relational queries: "ingredients expiring
within 3 days", "recipes joined to their ingredients", "shopping items grouped by vendor".
Prior art in `docs/RESEARCH.md` used everything from `UserDefaults` (chef-it, Pantry v1) to
a full SQLite schema (Grocy, Tandoor, Mealie).

## Decision
Use **Drift** (SQLite) as the single local data store for the `app/` package.

## Alternatives considered
- **Isar** — faster for pure key-value/object access, but its long-term maintenance
  status was uncertain at the time of this decision, and its query API is weaker for the
  relational joins this app actually needs (recipe ↔ ingredient, pantry ↔ shopping).
- **`UserDefaults`/`SharedPreferences` + manual JSON** — what several researched prior-art
  apps did. Rejected: no real querying, no migrations, and doesn't scale past a few dozen
  pantry items before every read means deserialising the whole blob.
- **sqflite directly (no ORM)** — Drift is built on top of sqlite3/sqflite and adds typed
  tables, generated DAOs, and migration tooling for free; hand-rolling the same on raw
  `sqflite` would just be re-implementing Drift, worse.

## Consequences
- Drift lives entirely behind the `kya_core` repository interfaces (ADR 004) — no Drift
  types leak into `kya_core` or into widgets.
- Migrations are testable in-memory (`NativeDatabase.memory()`), per `AGENTS.md` §6.
- Swapping to a synced backend in v2 means writing a new adapter that also implements the
  same ports; Drift can remain as the local cache layer underneath it.
