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
}
