import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

void main() {
  const chole = DishTags(
    region: Region.punjabi,
    dishType: DishType.curry,
    flavours: {Flavour.spicy, Flavour.tangy},
    heaviness: Heaviness.heavy,
    protein: Protein.dalLegume,
  );

  group('DishTags', () {
    group('allKeys', () {
      test('emits one key per scalar dimension plus one per flavour', () {
        expect(
          chole.allKeys,
          unorderedEquals(<TagKey>[
            TagKey.region('punjabi'),
            TagKey.dishType('curry'),
            TagKey.flavour('spicy'),
            TagKey.flavour('tangy'),
            TagKey.heaviness('heavy'),
            TagKey.protein('dalLegume'),
          ]),
        );
      });

      test('covers every TagDimension exactly once when one flavour', () {
        const idli = DishTags(
          region: Region.south,
          dishType: DishType.breakfast,
          flavours: {Flavour.mild},
          heaviness: Heaviness.light,
          protein: Protein.vegOnly,
        );

        expect(
          idli.allKeys.map((k) => k.dimension),
          unorderedEquals(TagDimension.values),
        );
      });

      test('omits the flavour dimension entirely when no flavours', () {
        const plain = DishTags(
          region: Region.east,
          dishType: DishType.rice,
          flavours: {},
          heaviness: Heaviness.light,
          protein: Protein.vegOnly,
        );

        final keys = plain.allKeys;

        expect(keys, hasLength(4));
        expect(keys.where((k) => k.dimension == TagDimension.flavour), isEmpty);
      });

      test('uses enum names verbatim, including camelCase values', () {
        const momo = DishTags(
          region: Region.indoChinese,
          dishType: DishType.drySabzi,
          flavours: {Flavour.savoury},
          heaviness: Heaviness.medium,
          protein: Protein.vegOnly,
        );

        expect(momo.allKeys, contains(TagKey.region('indoChinese')));
        expect(momo.allKeys, contains(TagKey.dishType('drySabzi')));
      });

      test('never produces duplicate keys', () {
        const everything = DishTags(
          region: Region.street,
          dishType: DishType.snack,
          flavours: {...Flavour.values},
          heaviness: Heaviness.medium,
          protein: Protein.paneer,
        );

        final keys = everything.allKeys;

        expect(keys.toSet(), hasLength(keys.length));
        expect(keys, hasLength(4 + Flavour.values.length));
      });

      test('"sweet" flavour and "sweet" dishType are distinct keys', () {
        const kheer = DishTags(
          region: Region.north,
          dishType: DishType.sweet,
          flavours: {Flavour.sweet},
          heaviness: Heaviness.medium,
          protein: Protein.vegOnly,
        );

        final sweetKeys = kheer.allKeys.where((k) => k.value == 'sweet');

        expect(sweetKeys, hasLength(2));
        expect(sweetKeys.toSet(), hasLength(2));
      });
    });

    group('equality', () {
      test('ignores flavour set iteration order', () {
        const reordered = DishTags(
          region: Region.punjabi,
          dishType: DishType.curry,
          flavours: {Flavour.tangy, Flavour.spicy},
          heaviness: Heaviness.heavy,
          protein: Protein.dalLegume,
        );

        expect(reordered, isNot(same(chole)));
        expect(reordered, equals(chole));
        expect(reordered.hashCode, chole.hashCode);
      });

      test('a flavour subset or superset is not equal', () {
        const subset = DishTags(
          region: Region.punjabi,
          dishType: DishType.curry,
          flavours: {Flavour.spicy},
          heaviness: Heaviness.heavy,
          protein: Protein.dalLegume,
        );
        const superset = DishTags(
          region: Region.punjabi,
          dishType: DishType.curry,
          flavours: {Flavour.spicy, Flavour.tangy, Flavour.savoury},
          heaviness: Heaviness.heavy,
          protein: Protein.dalLegume,
        );

        expect(subset, isNot(equals(chole)));
        expect(superset, isNot(equals(chole)));
      });

      test('differs when any scalar dimension differs', () {
        DishTags vary({
          Region region = Region.punjabi,
          DishType dishType = DishType.curry,
          Heaviness heaviness = Heaviness.heavy,
          Protein protein = Protein.dalLegume,
        }) => DishTags(
          region: region,
          dishType: dishType,
          flavours: const {Flavour.spicy, Flavour.tangy},
          heaviness: heaviness,
          protein: protein,
        );

        expect(vary(), equals(chole));
        expect(vary(region: Region.north), isNot(equals(chole)));
        expect(vary(dishType: DishType.dal), isNot(equals(chole)));
        expect(vary(heaviness: Heaviness.light), isNot(equals(chole)));
        expect(vary(protein: Protein.paneer), isNot(equals(chole)));
      });
    });
  });
}
