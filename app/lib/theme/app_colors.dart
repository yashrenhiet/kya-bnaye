import 'package:flutter/material.dart';

/// Brand seed colour and semantic (domain-meaning) colours.
///
/// FIRST DRAFT — presented for review, not a final sign-off. See the PR
/// description / AGENTS.md section 0 (UX/Product Designer standards) for the
/// rationale and alternatives considered:
///
/// - **Seed: Turmeric Gold** (`#E7A33E`). Fed into Material 3's
///   [ColorScheme.fromSeed], which generates a full, contrast-aware tonal
///   palette (including a dark theme) from one colour — this is what keeps
///   WCAG 2.2 AA contrast correct "for free" instead of hand-picking dozens
///   of hex values. Warm amber/turmeric was chosen over a cold blue/teal
///   because the brief explicitly asks for "a warm Indian kitchen, not a
///   generic productivity app" (AGENTS.md section 0).
/// - **Semantic colours are kept separate from the generated scheme**
///   (below) because "Ready now" / "Out of stock" / "Want this" carry a
///   specific domain meaning that must stay stable even if the generated
///   tonal palette shifts — see [AppSemanticColors].
///
/// Alternatives considered (open to revisiting before M6, when the swipe
/// card is actually designed):
/// 1. Chili red (`#C1440E`) as the seed — rejected as a primary because a
///    whole app tinted red reads as "alert", not "appetising".
/// 2. Curry-leaf green as the seed — kept instead as the semantic "success /
///    want this" colour, since green-for-positive is a near-universal
///    convention and shouldn't also be the brand's dominant colour.
abstract final class AppColors {
  /// Turmeric gold — the single seed for [ColorScheme.fromSeed].
  static const Color seed = Color(0xFFE7A33E);
}

/// Domain-meaning colours that must stay recognisable regardless of light/
/// dark mode or future re-seeding of the generated [ColorScheme].
///
/// Exposed as a [ThemeExtension] (not static constants) so widgets read them
/// via `Theme.of(context).extension<AppSemanticColors>()!` — the idiomatic
/// Flutter way to add app-specific theme data, and the only way this stays
/// swappable per-theme (e.g. a future high-contrast theme) without touching
/// every call site.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.stockPlenty,
    required this.stockLow,
    required this.stockOut,
    required this.wantThis,
    required this.notToday,
  });

  /// "Plenty" pantry level and "Ready now" recipe badge.
  final Color stockPlenty;

  /// "Low" pantry level and "Missing 1–2" recipe badge.
  final Color stockLow;

  /// "Out" pantry level.
  final Color stockOut;

  /// Right-swipe / "Want this" affordance.
  final Color wantThis;

  /// Left-swipe / "Not today" affordance. Deliberately neutral, not red —
  /// a left swipe is a *soft* signal (see docs/design/RECOMMENDER.md
  /// section 2), so the colour must not read as an alarming rejection.
  final Color notToday;

  static const light = AppSemanticColors(
    stockPlenty: Color(0xFF4C7A4C),
    stockLow: Color(0xFFC9820B),
    stockOut: Color(0xFFB3261E),
    wantThis: Color(0xFF4C7A4C),
    notToday: Color(0xFF79747E),
  );

  static const dark = AppSemanticColors(
    stockPlenty: Color(0xFF8FBF8F),
    stockLow: Color(0xFFE3A84C),
    stockOut: Color(0xFFE46962),
    wantThis: Color(0xFF8FBF8F),
    notToday: Color(0xFFCAC4D0),
  );

  @override
  AppSemanticColors copyWith({
    Color? stockPlenty,
    Color? stockLow,
    Color? stockOut,
    Color? wantThis,
    Color? notToday,
  }) {
    return AppSemanticColors(
      stockPlenty: stockPlenty ?? this.stockPlenty,
      stockLow: stockLow ?? this.stockLow,
      stockOut: stockOut ?? this.stockOut,
      wantThis: wantThis ?? this.wantThis,
      notToday: notToday ?? this.notToday,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      stockPlenty: Color.lerp(stockPlenty, other.stockPlenty, t)!,
      stockLow: Color.lerp(stockLow, other.stockLow, t)!,
      stockOut: Color.lerp(stockOut, other.stockOut, t)!,
      wantThis: Color.lerp(wantThis, other.wantThis, t)!,
      notToday: Color.lerp(notToday, other.notToday, t)!,
    );
  }
}
