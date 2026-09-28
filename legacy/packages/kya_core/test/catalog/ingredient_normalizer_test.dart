import 'package:kya_core/kya_core.dart';
import 'package:test/test.dart';

Ingredient _ingredient(
  String id,
  String name, {
  List<String> aliases = const [],
  IngredientRole role = IngredientRole.core,
}) => Ingredient(
  id: id,
  name: name,
  aliases: aliases,
  category: IngredientCategory.other,
  role: role,
  buyFrom: BuyFrom.kirana,
);

void main() {
  final potato = _ingredient('potato', 'Potato', aliases: ['aloo', 'batata']);
  final rice = _ingredient('rice', 'Rice', aliases: ['chawal']);
  final riceFlour = _ingredient(
    'rice_flour',
    'Rice Flour',
    aliases: ['chawal ka atta'],
  );
  final greenChilli = _ingredient(
    'green_chilli',
    'Green Chilli',
    aliases: ['hari mirch'],
  );

  late IngredientNormalizer normalizer;

  setUp(() {
    normalizer = IngredientNormalizer([potato, rice, riceFlour, greenChilli]);
  });

  group('IngredientNormalizer', () {
    group('find', () {
      test('resolves the display name', () {
        expect(normalizer.find('Potato'), same(potato));
      });

      test('resolves every alias to the same canonical ingredient', () {
        expect(normalizer.find('aloo'), same(potato));
        expect(normalizer.find('batata'), same(potato));
        expect(normalizer.find('hari mirch'), same(greenChilli));
      });

      test('is case-insensitive for names and aliases', () {
        expect(normalizer.find('POTATO'), same(potato));
        expect(normalizer.find('Aloo'), same(potato));
        expect(normalizer.find('HaRi MiRcH'), same(greenChilli));
      });

      test('ignores leading and trailing whitespace', () {
        expect(normalizer.find('  Potato '), same(potato));
        expect(normalizer.find('\taloo\n'), same(potato));
      });

      test('collapses runs of internal whitespace', () {
        expect(normalizer.find('green    chilli'), same(greenChilli));
        expect(normalizer.find('hari\t\nmirch'), same(greenChilli));
      });

      test('normalises aliases stored with odd casing/spacing', () {
        final messy = IngredientNormalizer([
          _ingredient('ginger', 'Ginger', aliases: ['  ADRAK  ', 'Sonth   ']),
        ]);

        expect(messy.find('adrak')?.id, 'ginger');
        expect(messy.find('sonth')?.id, 'ginger');
      });

      test('returns null for unknown text', () {
        expect(normalizer.find('paneer'), isNull);
      });

      test('returns null for empty or whitespace-only text', () {
        expect(normalizer.find(''), isNull);
        expect(normalizer.find('   '), isNull);
      });

      test('does not match on the raw canonical id, only name/alias', () {
        expect(normalizer.find('green_chilli'), isNull);
        expect(normalizer.byId('green_chilli'), same(greenChilli));
      });

      test('does not remove internal whitespace entirely', () {
        expect(normalizer.find('greenchilli'), isNull);
        expect(normalizer.find('harimirch'), isNull);
      });
    });

    group('exact matching, never substring', () {
      test('"rice" resolves to rice, not rice flour', () {
        expect(normalizer.find('rice'), same(rice));
        expect(normalizer.find('rice flour'), same(riceFlour));
      });

      test('"rice" is unknown when only rice flour is in the catalog', () {
        final onlyFlour = IngredientNormalizer([riceFlour]);

        expect(onlyFlour.find('rice'), isNull);
        expect(onlyFlour.find('flour'), isNull);
        expect(onlyFlour.contains('rice'), isFalse);
      });

      test('a superstring of a name does not match', () {
        final onlyRice = IngredientNormalizer([rice]);

        expect(onlyRice.find('rice flour'), isNull);
        expect(onlyRice.find('basmati rice'), isNull);
      });

      test('a prefix or fragment of an alias does not match', () {
        expect(normalizer.find('alo'), isNull);
        expect(normalizer.find('chawal ka'), isNull);
        expect(normalizer.find('mirch'), isNull);
      });

      test('an alias of one item never leaks into a longer alias', () {
        expect(normalizer.find('chawal'), same(rice));
        expect(normalizer.find('chawal ka atta'), same(riceFlour));
      });
    });

    group('alias collisions', () {
      test('throws StateError when two ingredients share an alias', () {
        expect(
          () => IngredientNormalizer([
            _ingredient('coriander', 'Coriander', aliases: ['dhania']),
            _ingredient(
              'coriander_seed',
              'Coriander Seed',
              aliases: ['dhania'],
            ),
          ]),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('dhania'),
                contains('coriander'),
                contains('coriander_seed'),
              ),
            ),
          ),
        );
      });

      test('detects collisions after case/whitespace normalisation', () {
        expect(
          () => IngredientNormalizer([
            _ingredient('a', 'A', aliases: ['Kala Namak']),
            _ingredient('b', 'B', aliases: ['  kala   NAMAK ']),
          ]),
          throwsStateError,
        );
      });

      test("throws when an alias equals another ingredient's name", () {
        expect(
          () => IngredientNormalizer([
            potato,
            _ingredient('sweet_potato', 'Sweet Potato', aliases: ['potato']),
          ]),
          throwsStateError,
        );
      });

      test('throws when two ingredients share a display name', () {
        expect(
          () => IngredientNormalizer([
            _ingredient('curd', 'Curd'),
            _ingredient('curd_2', 'curd'),
          ]),
          throwsStateError,
        );
      });

      test('a repeated alias within one ingredient is harmless', () {
        final n = IngredientNormalizer([
          _ingredient('onion', 'Onion', aliases: ['pyaaz', 'Pyaaz', 'pyaaz']),
        ]);

        expect(n.find('pyaaz')?.id, 'onion');
      });

      test('an alias equal to its own name is harmless', () {
        final n = IngredientNormalizer([
          _ingredient('onion', 'Onion', aliases: ['onion']),
        ]);

        expect(n.find('ONION')?.id, 'onion');
      });

      test('ignores blank aliases instead of matching blank input', () {
        final n = IngredientNormalizer([
          _ingredient('onion', 'Onion', aliases: ['   ', '']),
        ]);

        expect(n.find(''), isNull);
        expect(n.find('  '), isNull);
        expect(n.contains('  '), isFalse);
        expect(n.find('onion')?.id, 'onion');
      });
    });

    group('normalise', () {
      test('trims, lower-cases and collapses internal whitespace', () {
        expect(
          IngredientNormalizer.normalise('  Hari \t\n MIRCH '),
          'hari mirch',
        );
      });

      test('maps blank or whitespace-only text to the empty key', () {
        expect(IngredientNormalizer.normalise(''), '');
        expect(IngredientNormalizer.normalise(' \t\n'), '');
      });

      test('keeps punctuation and underscores untouched', () {
        expect(
          IngredientNormalizer.normalise('Black-Eyed_Peas'),
          'black-eyed_peas',
        );
      });

      test('equal keys are exactly the texts find treats as the same', () {
        final key = IngredientNormalizer.normalise('  CHAWAL   ka Atta');
        expect(key, 'chawal ka atta');
        expect(normalizer.find(key), same(riceFlour));
      });
    });

    group('contains', () {
      test('mirrors find for known and unknown text', () {
        expect(normalizer.contains(' ALOO '), isTrue);
        expect(normalizer.contains('Rice Flour'), isTrue);
        expect(normalizer.contains('rice atta'), isFalse);
        expect(normalizer.contains(''), isFalse);
      });
    });

    group('byId', () {
      test('returns the ingredient for a known id', () {
        expect(normalizer.byId('rice_flour'), same(riceFlour));
      });

      test('is exact and case-sensitive', () {
        expect(normalizer.byId('Rice'), isNull);
        expect(normalizer.byId('ric'), isNull);
        expect(normalizer.byId(' rice'), isNull);
      });

      test('does not resolve names or aliases', () {
        expect(normalizer.byId('aloo'), isNull);
        expect(normalizer.byId('Potato'), isNull);
      });
    });

    group('all', () {
      test('exposes every catalog ingredient once', () {
        expect(
          normalizer.all,
          unorderedEquals([potato, rice, riceFlour, greenChilli]),
        );
      });
    });

    group('empty catalog', () {
      test('finds nothing and exposes nothing', () {
        final empty = IngredientNormalizer(const []);

        expect(empty.find('rice'), isNull);
        expect(empty.contains(''), isFalse);
        expect(empty.byId('rice'), isNull);
        expect(empty.all, isEmpty);
      });
    });

    group('createUserIngredient', () {
      test('builds a user-created ingredient from trimmed text', () {
        final created = normalizer.createUserIngredient(
          '  Kasuri Methi ',
          category: IngredientCategory.masala,
          buyFrom: BuyFrom.kirana,
        );

        expect(created.id, 'user_kasuri_methi');
        expect(created.name, 'Kasuri Methi');
        expect(created.category, IngredientCategory.masala);
        expect(created.buyFrom, BuyFrom.kirana);
        expect(created.isUserCreated, isTrue);
        expect(created.aliases, isEmpty);
        expect(created.shelfLifeDays, isNull);
      });

      test('defaults role to core and honours an explicit role', () {
        final byDefault = normalizer.createUserIngredient(
          'Jaggery',
          category: IngredientCategory.packaged,
          buyFrom: BuyFrom.kirana,
        );
        final garnish = normalizer.createUserIngredient(
          'Microgreens',
          category: IngredientCategory.sabzi,
          buyFrom: BuyFrom.sabziwala,
          role: IngredientRole.optional,
        );

        expect(byDefault.role, IngredientRole.core);
        expect(garnish.role, IngredientRole.optional);
      });

      test('lower-cases and collapses whitespace into single underscores', () {
        final created = normalizer.createUserIngredient(
          'Black \t  Cardamom\nPods',
          category: IngredientCategory.masala,
          buyFrom: BuyFrom.kirana,
        );

        expect(created.id, 'user_black_cardamom_pods');
      });

      test('equivalent spellings produce the same id', () {
        Ingredient make(String text) => normalizer.createUserIngredient(
          text,
          category: IngredientCategory.other,
          buyFrom: BuyFrom.other,
        );

        expect(make('Kala Chana'), equals(make('  kala   CHANA ')));
      });

      test('the user_ prefix keeps ids from colliding with seed ids', () {
        final created = normalizer.createUserIngredient(
          'Potato',
          category: IngredientCategory.sabzi,
          buyFrom: BuyFrom.sabziwala,
        );

        expect(created.id, 'user_potato');
        expect(created, isNot(equals(potato)));
      });

      test('does not register the new ingredient in this normalizer', () {
        normalizer.createUserIngredient(
          'Kasuri Methi',
          category: IngredientCategory.masala,
          buyFrom: BuyFrom.kirana,
        );

        expect(normalizer.find('kasuri methi'), isNull);
        expect(normalizer.byId('user_kasuri_methi'), isNull);
        expect(normalizer.all, hasLength(4));
      });

      test('is findable once included in a rebuilt normalizer', () {
        final created = normalizer.createUserIngredient(
          'Kasuri Methi',
          category: IngredientCategory.masala,
          buyFrom: BuyFrom.kirana,
        );

        final rebuilt = IngredientNormalizer([...normalizer.all, created]);

        expect(rebuilt.find(' KASURI methi'), same(created));
        expect(rebuilt.byId('user_kasuri_methi'), same(created));
      });

      test('rejects blank text instead of creating a nameless ingredient', () {
        for (final blank in ['', '   ', '\t\n']) {
          expect(
            () => normalizer.createUserIngredient(
              blank,
              category: IngredientCategory.other,
              buyFrom: BuyFrom.other,
            ),
            throwsArgumentError,
            reason: 'input: ${blank.codeUnits}',
          );
        }
      });
    });
  });
}
