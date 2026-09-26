/// kya_core — the pure-Dart brain of kya-bnaye.
///
/// Domain models, the ingredient normalizer, the Kitchen/Craving
/// recommendation engines, the shopping-list builder and the backup codec
/// live here. **Zero Flutter imports** by design: see `AGENTS.md` section
/// 5.3 for the dependency rule this package exists to protect. UI code (in
/// `app/`) depends on this package; this package never depends on UI code
/// or on any concrete data store — see `ports/repositories.dart`.
library;

export 'package:kya_core/src/backup/backup_codec.dart';
export 'package:kya_core/src/catalog/ingredient_normalizer.dart';
export 'package:kya_core/src/domain/domain.dart';
export 'package:kya_core/src/ports/repositories.dart';
export 'package:kya_core/src/recommend/recommend.dart';
export 'package:kya_core/src/shopping/shopping_list_builder.dart';

/// Semantic version of the `kya_core` public API surface.
///
/// Bumped whenever a breaking change is made to an exported type, so the
/// `app` package's pinned constraint in the workspace can be reasoned about
/// even though both packages are developed together in one repo.
const String kyaCorePackageVersion = '0.1.0';
