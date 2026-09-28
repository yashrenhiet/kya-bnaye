import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

void main() {
  group('TagKey', () {
    test('each factory pairs the value with its own dimension', () {
      expect(TagKey.region('south').dimension, TagDimension.region);
      expect(TagKey.dishType('dal').dimension, TagDimension.dishType);
      expect(TagKey.flavour('spicy').dimension, TagDimension.flavour);
      expect(TagKey.heaviness('light').dimension, TagDimension.heaviness);
      expect(TagKey.protein('egg').dimension, TagDimension.protein);
      expect(TagKey.region('south').value, 'south');
    });

    test('same dimension and value are equal with equal hashCodes', () {
      final a = TagKey.flavour('spicy');
      final b = TagKey.flavour('spicy');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('the same value in different dimensions is not equal', () {
      expect(TagKey.flavour('sweet'), isNot(equals(TagKey.dishType('sweet'))));
      expect(TagKey.dishType('rice'), isNot(equals(TagKey.region('rice'))));
    });

    test('values are compared exactly (case-sensitive)', () {
      expect(TagKey.region('South'), isNot(equals(TagKey.region('south'))));
    });

    test('works as a Map key across separately built instances', () {
      final affinity = <TagKey, double>{TagKey.protein('paneer'): 0.8};

      expect(affinity[TagKey.protein('paneer')], 0.8);
      expect(affinity[TagKey.protein('egg')], isNull);
    });

    test('toString renders as dimension:value', () {
      expect(TagKey.heaviness('heavy').toString(), 'heaviness:heavy');
      expect(TagKey.dishType('onePot').toString(), 'dishType:onePot');
    });
  });

  group('TagKey.label', () {
    test('maps every enum value of every dimension to its human label', () {
      for (final r in Region.values) {
        expect(TagKey.region(r.name).label, r.label);
      }
      for (final d in DishType.values) {
        expect(TagKey.dishType(d.name).label, d.label);
      }
      for (final f in Flavour.values) {
        expect(TagKey.flavour(f.name).label, f.label);
      }
      for (final h in Heaviness.values) {
        expect(TagKey.heaviness(h.name).label, h.label);
      }
      for (final p in Protein.values) {
        expect(TagKey.protein(p.name).label, p.label);
      }
    });

    test('uses spec wording, never a camelCase enum name', () {
      expect(TagKey.region('indoChinese').label, 'Indo-Chinese');
      expect(TagKey.region('south').label, 'South Indian');
      expect(TagKey.region('gujarati').label, 'Gujarati');
      expect(TagKey.dishType('drySabzi').label, 'dry sabzi');
    });

    test('every label is non-empty and has no camelCase hump', () {
      final labels = <String>[
        for (final values in <List<TagLabelled>>[
          Region.values,
          DishType.values,
          Flavour.values,
          Heaviness.values,
          Protein.values,
        ])
          for (final tag in values) tag.label,
      ];
      for (final label in labels) {
        expect(label.trim(), isNotEmpty);
        expect(label, isNot(matches(RegExp('[a-z][A-Z]'))), reason: label);
      }
    });

    test('an unknown value falls back to the raw string', () {
      expect(TagKey.region('martian').label, 'martian');
    });
  });
}
