import 'package:kya_core/src/catalog/ingredient_normalizer.dart';
import 'package:kya_core/src/domain/domain.dart';
import 'package:kya_core/src/seed/seed_coverage_rules.dart';
import 'package:kya_core/src/seed/seed_coverage_targets.dart';
import 'package:kya_core/src/seed/seed_issue.dart';
import 'package:kya_core/src/seed/seed_manifest.dart';
import 'package:kya_core/src/seed/seed_recipe_rules.dart';
import 'package:kya_core/src/seed/seed_rule_exemptions.dart';

/// Checks a decoded [SeedBundle] against the seed-data rules in
/// `docs/design/SEED_GUIDE.md`: ingredient rules I1–I7, recipe rules
/// R1–R11 and, when targets are given, catalogue coverage.
///
/// I8 (rows sorted by id within each fragment) needs fragment boundaries,
/// which a [SeedBundle] no longer has, so the asset test checks it.
class SeedValidator {
  /// Creates a validator. Stateless.
  const SeedValidator();

  /// Format shared by ingredient and recipe ids.
  static final RegExp idPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Prefix reserved for ingredients users create at runtime.
  static const String userIdPrefix = 'user_';

  /// Allowed number of staple-role ingredients (I7), inclusive.
  static const int minStaples = 12;

  /// See [minStaples].
  static const int maxStaples = 25;

  /// Upper bound for `shelfLifeDays` (I5), inclusive; the lower is 1.
  static const int maxShelfLifeDays = 3650;

  static const Set<IngredientCategory> _perishableCategories = {
    IngredientCategory.sabzi,
    IngredientCategory.fruit,
    IngredientCategory.dairy,
  };
  static const Set<String> _perishableIds = {
    'eggs',
    'chicken',
    'mutton',
    'fish',
    'prawns',
  };
  static const Set<IngredientCategory> _stapleCategories = {
    IngredientCategory.masala,
    IngredientCategory.oilGhee,
    IngredientCategory.grains,
    IngredientCategory.other,
  };

  /// Returns every broken rule in [bundle]; empty means valid. Never
  /// throws for bad data and never stops at the first issue.
  ///
  /// [assetExists] answers whether an asset path such as
  /// `assets/seed/images/poha.webp` is bundled (R9); it is injected so
  /// this package stays free of `dart:io`. Coverage is only checked when
  /// [coverage] is given. [exemptions] lists reviewed rule exceptions.
  List<SeedIssue> validate(
    SeedBundle bundle, {
    required bool Function(String path) assetExists,
    SeedCoverageTargets? coverage,
    SeedRuleExemptions exemptions = const SeedRuleExemptions(),
  }) {
    final issues = <SeedIssue>[];
    _checkIngredients(bundle.ingredients, exemptions, issues.add);
    checkRecipeRules(bundle, assetExists, issues.add);
    if (coverage != null) checkCoverage(bundle, coverage, issues.add);
    return issues;
  }

  void _checkIngredients(
    List<Ingredient> ingredients,
    SeedRuleExemptions exemptions,
    void Function(SeedIssue) report,
  ) {
    final ids = <String>{};
    final nameOwners = <String, String>{};
    for (final i in ingredients) {
      final at = 'ingredients[${i.id}]';
      void issue(SeedIssueCode code, String field, String message) =>
          report(SeedIssue(code, '$at$field', message));

      if (!idPattern.hasMatch(i.id)) {
        issue(SeedIssueCode.i1IngredientId, '', 'id must match $idPattern');
      } else if (i.id.startsWith(userIdPrefix)) {
        issue(
          SeedIssueCode.i1IngredientId,
          '',
          'the "$userIdPrefix" id prefix is reserved for user ingredients',
        );
      }
      if (!ids.add(i.id)) {
        issue(SeedIssueCode.i1IngredientId, '', 'duplicate id');
      }
      _checkName(i, nameOwners, (m) {
        issue(SeedIssueCode.i2IngredientName, '.name', m);
      });
      for (var n = 0; n < i.aliases.length; n++) {
        final alias = i.aliases[n];
        final normalised = IngredientNormalizer.normalise(alias);
        if (normalised.isEmpty) {
          issue(SeedIssueCode.i4AliasFormat, '.aliases[$n]', 'blank alias');
        } else if (alias != normalised) {
          issue(
            SeedIssueCode.i4AliasFormat,
            '.aliases[$n]',
            'alias "$alias" must be lowercase, trimmed and single-spaced '
                '("$normalised")',
          );
        }
      }
      _checkShelfLife(i, (m) {
        issue(SeedIssueCode.i5ShelfLife, '.shelfLifeDays', m);
      });
      final expected = switch (i.category) {
        IngredientCategory.sabzi ||
        IngredientCategory.fruit => BuyFrom.sabziwala,
        IngredientCategory.dairy => BuyFrom.dairy,
        _ => null,
      };
      if (expected != null &&
          i.buyFrom != expected &&
          !exemptions.buyFrom.contains(i.id)) {
        issue(
          SeedIssueCode.i6BuyFrom,
          '.buyFrom',
          '${i.category.name} must be bought from ${expected.name}, '
              'not ${i.buyFrom.name}',
        );
      }
      if (i.role == IngredientRole.staple &&
          !_stapleCategories.contains(i.category)) {
        issue(
          SeedIssueCode.i7Staples,
          '.role',
          'a ${i.category.name} ingredient cannot be a staple (allowed: '
              '${_stapleCategories.map((c) => c.name).join(', ')})',
        );
      }
    }
    _checkAliasCollisions(ingredients, report);
    final staples = ingredients
        .where((i) => i.role == IngredientRole.staple)
        .length;
    if (staples < minStaples || staples > maxStaples) {
      report(
        SeedIssue(
          SeedIssueCode.i7Staples,
          'ingredients',
          '$staples staples; expected $minStaples–$maxStaples',
        ),
      );
    }
  }

  void _checkName(
    Ingredient i,
    Map<String, String> owners,
    void Function(String) report,
  ) {
    if (i.name.trim().isEmpty) {
      report('name is blank');
      return;
    }
    if (i.name != i.name.trim()) report('name has surrounding whitespace');
    final key = IngredientNormalizer.normalise(i.name);
    final owner = owners.putIfAbsent(key, () => i.id);
    if (owner != i.id) report('name "${i.name}" is also used by $owner');
  }

  void _checkShelfLife(Ingredient i, void Function(String) report) {
    final days = i.shelfLifeDays;
    if (days == null) {
      if (_perishableCategories.contains(i.category) ||
          _perishableIds.contains(i.id)) {
        report('required for a perishable ingredient');
      }
    } else if (days < 1 || days > maxShelfLifeDays) {
      report('$days is outside 1–$maxShelfLifeDays');
    }
  }

  /// I3. A key only collides when at least one side is an alias:
  /// name-vs-name clashes are already reported by I2.
  void _checkAliasCollisions(
    List<Ingredient> ingredients,
    void Function(SeedIssue) report,
  ) {
    // Normalised key -> owning ingredient id -> contributed by an alias.
    final owners = <String, Map<String, bool>>{};
    void claim(String key, String id, {required bool viaAlias}) {
      final byId = owners.putIfAbsent(key, () => {});
      byId[id] = (byId[id] ?? false) || viaAlias;
    }

    for (final i in ingredients) {
      final nameKey = IngredientNormalizer.normalise(i.name);
      final own = <String>{};
      if (nameKey.isNotEmpty) claim(nameKey, i.id, viaAlias: false);
      for (var n = 0; n < i.aliases.length; n++) {
        final key = IngredientNormalizer.normalise(i.aliases[n]);
        if (key.isEmpty) continue; // I4 reports blank aliases.
        final at = 'ingredients[${i.id}].aliases[$n]';
        if (key == nameKey) {
          report(
            SeedIssue(
              SeedIssueCode.i3AliasCollision,
              at,
              'alias "$key" repeats the ingredient name',
            ),
          );
        } else if (!own.add(key)) {
          report(
            SeedIssue(
              SeedIssueCode.i3AliasCollision,
              at,
              'alias "$key" is listed twice',
            ),
          );
        } else {
          claim(key, i.id, viaAlias: true);
        }
      }
    }
    for (final MapEntry(:key, value: byId) in owners.entries) {
      if (byId.length > 1 && byId.values.any((viaAlias) => viaAlias)) {
        final ids = byId.keys.toList()..sort();
        report(
          SeedIssue(
            SeedIssueCode.i3AliasCollision,
            'ingredients',
            '"$key" resolves to more than one ingredient: ${ids.join(', ')}',
          ),
        );
      }
    }
  }
}
