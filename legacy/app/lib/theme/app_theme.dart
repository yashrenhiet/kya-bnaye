import 'package:flutter/material.dart';

import 'package:kyabnaye/theme/app_colors.dart';

/// Builds the app's [ThemeData] for light and dark mode.
///
/// Both themes are generated from a single seed colour ([AppColors.seed])
/// via Material 3's [ColorScheme.fromSeed], plus the [AppSemanticColors]
/// extension for domain-specific meaning (stock levels, swipe actions).
/// See `app_colors.dart` for the rationale.
abstract final class AppTheme {
  static ThemeData light() => _build(brightness: Brightness.light);

  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final semanticColors = brightness == Brightness.light
        ? AppSemanticColors.light
        : AppSemanticColors.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      extensions: [semanticColors],
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
      ),
    );
  }
}
