# ADR 006: Offline-first, no accounts in v1

**Status:** Accepted — 2026-09-26

## Context
The core value of the app (pantry tracking, recommendations, shopping list) is entirely
single-device, single-household data with no inherent need for a server. Several
researched prior-art apps (FridgeCheck, chef-it) require sign-in and a network round trip
even for the basic "what can I cook" flow, which adds latency, a failure mode (no
connectivity in a kitchen with poor wifi), and — in chef-it's and Pantry's case — an LLM
API key shipped inside the client.

## Decision
v1 requires **no login, no account, and no network connection** for any core feature.
All data lives on-device (Drift, per ADR 003). The only network use in v1 is fully
optional and user-initiated: downloading seed recipe photos at first run.

## Alternatives considered
- **Account + cloud sync from day one** — would solve multi-device/family sharing
  immediately, but adds a backend to build and operate before there's any evidence the
  core recommendation loop is even useful. Deferred to v2 (household sync, `AGENTS.md`
  Decision D-log v2 scope).
- **Anonymous cloud backup (no login, just a device-generated id)** — rejected for v1 as
  unnecessary complexity; the JSON export/import backup (feature F7) covers the "don't
  lose my data" need without standing up any server.

## Consequences
- No auth flow, no JWT/keychain handling, no backend to operate or pay for in v1.
- Any future AI feature (v2) must go through a backend proxy with quotas — **never** an
  API key embedded in the client — per the explicit anti-pattern called out from
  FridgeCheck/chef-it in `docs/RESEARCH.md`.
- Data loss risk (single device, no cloud) is mitigated by the JSON backup/restore
  feature (F7), not by a server.
