import 'package:flutter/material.dart';

/// Spacing scale used across the app instead of hardcoded magic numbers.
///
/// Values follow the 4/8/12/16/24(/32) scale called out in `AGENTS.md`
/// section 0 (UX/Product Designer standards). Pick the smallest value that
/// reads correctly — most inter-element gaps should be [md] or [base].
abstract final class AppSpacing {
  /// 4dp — the smallest hairline gap, e.g. between an icon and its label.
  static const double xs = 4;

  /// 8dp — tight spacing within a compact group (e.g. chip padding).
  static const double sm = 8;

  /// 12dp — default spacing between related elements inside a card.
  static const double md = 12;

  /// 16dp — the default page/card margin. Use this when unsure.
  static const double base = 16;

  /// 24dp — spacing between distinct sections on a screen.
  static const double lg = 24;

  /// 32dp — large separation, e.g. above a primary call-to-action.
  static const double xl = 32;
}

/// Corner radius scale, kept alongside spacing so cards/sheets/chips share a
/// consistent, soft-edged look rather than every widget inventing its own.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}
