/// Closed-enum recipe metadata used by both rankers
/// (`docs/design/RECOMMENDER.md` sections 3–5). No free text: seed-data
/// validators (milestone M2) reject anything that doesn't map to these
/// enums, so the taste profile can never fragment over spelling drift.
library;

import 'package:kya_core/src/domain/tag_key.dart';

/// Implemented by every tag enum so user-facing text can show a human
/// [label] ("Indo-Chinese") instead of the Dart identifier
/// (`indoChinese`). `name` stays the stable persistence/`TagKey` value;
/// [label] is display-only and free to change.
abstract interface class TagLabelled {
  /// Display text for explanations and chips, e.g. "South Indian",
  /// "dry sabzi". Proper nouns are capitalised; everything else is lower
  /// case so it reads naturally mid-sentence.
  String get label;
}

enum Region implements TagLabelled {
  north('North Indian'),
  south('South Indian'),
  east('East Indian'),
  west('West Indian'),
  gujarati('Gujarati'),
  punjabi('Punjabi'),
  indoChinese('Indo-Chinese'),
  continental('Continental'),
  street('street food');

  const Region(this.label);

  @override
  final String label;
}

enum DishType implements TagLabelled {
  dal('dal'),
  curry('curry'),
  drySabzi('dry sabzi'),
  rice('rice'),
  bread('bread'),
  breakfast('breakfast'),
  snack('snacks'),
  sweet('sweets'),
  onePot('one-pot meals');

  const DishType(this.label);

  @override
  final String label;
}

enum Flavour implements TagLabelled {
  spicy('spicy'),
  tangy('tangy'),
  sweet('sweet'),
  savoury('savoury'),
  mild('mild');

  const Flavour(this.label);

  @override
  final String label;
}

enum Heaviness implements TagLabelled {
  light('light meals'),
  medium('medium-weight meals'),
  heavy('hearty meals');

  const Heaviness(this.label);

  @override
  final String label;
}

/// Tag-only in v1 — diet *filtering* (veg/Jain/etc.) is deferred to v2
/// (ADR/decision D3). This still lets the taste profile learn "you tend to
/// pick paneer dishes" today.
enum Protein implements TagLabelled {
  paneer('paneer'),
  dalLegume('dal and legumes'),
  egg('egg'),
  chicken('chicken'),
  mutton('mutton'),
  fish('fish'),
  vegOnly('veg');

  const Protein(this.label);

  @override
  final String label;
}

/// Human label for a [TagKey], looked up from the matching tag enum.
///
/// [TagKey.value] is a plain `.name` string, so an unknown value (e.g. from
/// a newer backup) falls back to that raw string rather than throwing.
extension TagKeyLabel on TagKey {
  String get label {
    final label = switch (dimension) {
      TagDimension.region => Region.values.asNameMap()[value]?.label,
      TagDimension.dishType => DishType.values.asNameMap()[value]?.label,
      TagDimension.flavour => Flavour.values.asNameMap()[value]?.label,
      TagDimension.heaviness => Heaviness.values.asNameMap()[value]?.label,
      TagDimension.protein => Protein.values.asNameMap()[value]?.label,
    };
    return label ?? value;
  }
}

enum MealType { breakfast, lunch, dinner, snack }

/// What a recipe's starch base is — used for the "rice after rice" rotation
/// penalty (`docs/design/RECOMMENDER.md` section 5).
enum DishBase { rice, roti, bread, none }
