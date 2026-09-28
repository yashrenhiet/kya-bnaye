/// Checks the real bundled seed data in `seed/` (read with
/// `dart:io`) against `SeedCodec`, `SeedValidator` and the file-level
/// rules a `SeedBundle` cannot see: I8 row order, images and credits.
library;

import 'dart:convert';
import 'dart:io';

import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

/// Largest allowed recipe photo (`docs/design/SEED_GUIDE.md` section 8).
const int maxImageBytes = 60 * 1024;

/// A typical first-run pantry besides the assumed staples.
const firstRunPantry = {
  'onion',
  'tomato',
  'potato',
  'ginger',
  'garlic',
  'green_chilli',
  'curd',
  'milk',
  'wheat_flour',
  'rice',
  'toor_dal',
};

void main() {
  late Directory seedDir;
  late Directory appDir;
  late SeedManifest manifest;
  late Map<String, Object?> jsonByPath;
  late SeedBundle bundle;

  setUpAll(() {
    seedDir = _findSeedDir();
    appDir = seedDir.parent;
    const codec = SeedCodec();
    manifest = codec.decodeManifest(_readJson(seedDir, SeedCodec.manifestFile));
    jsonByPath = {
      for (final path in manifest.allFiles) path: _readJson(seedDir, path),
    };
    bundle = codec.decode(manifest, jsonByPath);
  });

  test('SeedValidator reports no issues', () {
    bool exists(String path) => File('${appDir.path}/$path').existsSync();
    const validator = SeedValidator();
    final issues = validator.validate(
      bundle,
      assetExists: exists,
      coverage: const SeedCoverageTargets(),
    );
    expect(
      issues,
      isEmpty,
      reason:
          '${issues.length} issue(s); first 30:\n'
          '${issues.take(30).join('\n')}',
    );
  });

  test('the manifest lists every fragment file on disk', () {
    final onDisk = [
      for (final entity in seedDir.listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.json'))
          entity.path.substring(seedDir.path.length + 1),
    ]..remove(SeedCodec.manifestFile);
    expect(onDisk, unorderedEquals(manifest.allFiles));
  });

  test('I8: ingredient rows are sorted by id within each fragment', () {
    final unsorted = <String>[];
    for (final path in manifest.ingredientFiles) {
      final root = jsonByPath[path]! as Map<String, Object?>;
      final ids = [
        for (final row in root['ingredients']! as List<Object?>)
          (row! as Map<String, Object?>)['id']! as String,
      ];
      for (var i = 1; i < ids.length; i++) {
        if (ids[i - 1].compareTo(ids[i]) > 0) {
          unsorted.add('$path: "${ids[i]}" comes after "${ids[i - 1]}"');
        }
      }
    }
    expect(unsorted, isEmpty);
  });

  group('IngredientNormalizer over the real catalogue', () {
    late IngredientNormalizer normalizer;

    setUpAll(() => normalizer = IngredientNormalizer(bundle.ingredients));

    test('every name and alias resolves to its own ingredient', () {
      final wrong = <String>[
        for (final i in bundle.ingredients)
          for (final text in [i.name, ...i.aliases])
            if (normalizer.find(text)?.id != i.id) '${i.id}: "$text"',
      ];
      expect(wrong, isEmpty);
    });

    test('resolves common Hindi names exactly, never by substring', () {
      const expected = {
        'aloo': 'potato',
        'Tamatar': 'tomato',
        'rice': 'rice',
        'chawal ka atta': 'rice_flour',
        'methi': 'fenugreek_leaves',
        'methi dana': 'fenugreek_seeds',
        'sitaphal': 'custard_apple',
        'chole': 'kabuli_chana',
        'cornstarch': 'cornflour',
      };
      expected.forEach((text, id) {
        expect(normalizer.find(text)?.id, id, reason: text);
      });
      for (final ambiguous in ['sarson', 'corn flour', 'flour']) {
        expect(normalizer.find(ambiguous), isNull, reason: ambiguous);
      }
    });
  });

  test('every image is referenced by a recipe and within budget', () {
    final imagesDir = Directory('${seedDir.path}/images');
    final referenced = {
      for (final r in bundle.recipes)
        if (r.imageAsset != null) _basename(r.imageAsset!),
    };
    final problems = <String>[];
    if (imagesDir.existsSync()) {
      for (final file in imagesDir.listSync().whereType<File>()) {
        final name = _basename(file.path);
        if (!name.endsWith('.webp')) {
          problems.add('$name is not a .webp file');
        } else if (!referenced.contains(name)) {
          problems.add('$name is not referenced by any recipe');
        }
        final bytes = file.lengthSync();
        if (bytes > maxImageBytes) {
          problems.add('$name is $bytes bytes (max $maxImageBytes)');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('IMAGE_CREDITS.md has exactly one row per recipe image', () {
    final credits = File('${seedDir.path}/IMAGE_CREDITS.md');
    expect(credits.existsSync(), isTrue, reason: 'missing ${credits.path}');
    final rows = _creditRows(credits.readAsLinesSync());
    for (final row in rows) {
      expect(row, hasLength(9), reason: 'credit row "${row.join(' | ')}"');
    }
    final credited = {for (final row in rows) _basename(row.first): row[1]};
    expect(credited, hasLength(rows.length), reason: 'duplicate file rows');
    final expected = {
      for (final r in bundle.recipes)
        if (r.imageAsset != null) _basename(r.imageAsset!): r.id,
    };
    expect(credited, expected);
  });

  test('a first-run pantry gives every meal type a Kitchen deck', () {
    final missing = firstRunPantry.difference({
      for (final i in bundle.ingredients) i.id,
    });
    expect(missing, isEmpty, reason: 'pantry ids missing from catalogue');
    final counts = kitchenCandidateCounts(
      bundle,
      atHome: firstRunPantry,
      now: DateTime.utc(2026, 9, 26, 12),
    );
    expect(counts.keys, unorderedEquals(MealType.values));
    final min = const SeedCoverageTargets().minKitchenCandidatesPerMealType;
    for (final MapEntry(key: meal, value: count) in counts.entries) {
      expect(count, greaterThanOrEqualTo(min), reason: meal.name);
    }
  });
}

/// Walks up from the working directory to the repo's `seed/`.
Directory _findSeedDir() {
  var dir = Directory.current.absolute;
  while (true) {
    final manifest = File('${dir.path}/seed/manifest.json');
    if (manifest.existsSync()) return manifest.parent;
    if (dir.parent.path == dir.path) {
      fail(
        'seed/manifest.json not found in '
        '${Directory.current.path} or any parent directory. The bundled '
        'seed data must exist for this test (see docs/design/SEED_GUIDE.md).',
      );
    }
    dir = dir.parent;
  }
}

Object? _readJson(Directory seedDir, String path) {
  final file = File('${seedDir.path}/$path');
  if (!file.existsSync()) fail('$path is listed but missing: ${file.path}');
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    fail('$path is not valid JSON: ${e.message}');
  }
}

/// Data rows of the first Markdown table (after its header and `|---|`
/// separator), split into trimmed cells with backticks removed.
List<List<String>> _creditRows(List<String> lines) {
  final table = lines.where((l) => l.trimLeft().startsWith('|')).skip(2);
  return [
    for (final line in table)
      line
          .trim()
          .replaceAll('`', '')
          .split('|')
          .map((c) => c.trim())
          .toList()
          .sublist(1)
        ..removeLast(),
  ];
}

String _basename(String path) => path.split('/').last;
