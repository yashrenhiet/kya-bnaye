/// kya_core — the pure-Dart brain of kya-bnaye.
///
/// This package holds domain models, the ingredient normalizer, the
/// Kitchen/Craving recommendation engines, the shopping-list builder and the
/// backup codec. It has **zero Flutter imports** by design: see
/// `AGENTS.md` section 5.3 for the dependency rule this package exists to
/// protect. UI code (in `app/`) depends on this package; this package never
/// depends on UI code or on any concrete data store.
///
/// Domain models, the recommender and the seed-data validators land here in
/// milestone M1 (see `AGENTS.md` section 7). This file is intentionally a
/// stub until then.
library;

/// Semantic version of the `kya_core` public API surface.
///
/// Bumped whenever a breaking change is made to an exported type, so the
/// `app` package's pinned constraint in the workspace can be reasoned about
/// even though both packages are developed together in one repo.
const String kyaCorePackageVersion = '0.1.0';
