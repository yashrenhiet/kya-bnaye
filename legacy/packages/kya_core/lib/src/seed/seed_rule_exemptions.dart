import 'package:meta/meta.dart';

/// Deliberate, reviewed exceptions to individual seed-data rules.
///
/// The validator has no "warning" level: a rule either holds or the seed
/// tests fail. When a rule is knowingly broken for a good reason, the
/// ingredient id is listed here, so the exception is explicit and shows
/// up in code review.
@immutable
class SeedRuleExemptions {
  /// Creates exemptions; the defaults are the ones the shipped seed needs.
  const SeedRuleExemptions({this.buyFrom = const {'coconut'}});

  /// Ingredient ids exempt from I6 (sabzi/fruit → sabziwala, dairy →
  /// dairy). Coconut is a fruit, but households buy it from the kirana
  /// or a coconut seller as often as from the sabziwala.
  final Set<String> buyFrom;
}
