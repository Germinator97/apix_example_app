import 'package:flutter/material.dart';

/// Apix brand colors.
abstract class ApixColors {
  /// Deep Navy - Primary background
  static const deepNavy = Color(0xFF1E3A5F);

  /// Border Blue - Secondary/border
  static const borderBlue = Color(0xFF3D5A80);

  /// Spark Orange - Accent color
  static const sparkOrange = Color(0xFFF89C35);

  /// Foreground to use **on** [sparkOrange].
  ///
  /// Not white: white on this orange lands at 2.14:1, well under the 3:1 WCAG
  /// AA floor even for large text — the accent is far too bright to carry it.
  /// Navy gets ~5.7:1 and keeps the brand colour untouched.
  static const onSparkOrange = deepNavy;

  /// Slate Gray - Text secondary.
  ///
  /// Read it through `Theme.of(context).colorScheme.onSurfaceVariant` rather
  /// than directly: hardcoding foreground colours in widgets is what made the
  /// app unreadable on a dark surface before.
  static const slateGray = Color(0xFF4A5568);

  /// Light Gray - Background
  static const lightGray = Color(0xFFF7FAFC);

  /// White
  static const white = Color(0xFFFFFFFF);
}

/// Apix app theme configuration.
class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ApixColors.deepNavy,
        primary: ApixColors.deepNavy,
        secondary: ApixColors.sparkOrange,
        surface: ApixColors.white,
        onPrimary: ApixColors.white,
        onSecondary: ApixColors.onSparkOrange,
        onSurfaceVariant: ApixColors.slateGray,
      ),
      // The palette was designed for a light background; wiring it explicitly
      // instead of relying on the Material default.
      scaffoldBackgroundColor: ApixColors.lightGray,
      appBarTheme: const AppBarTheme(
        backgroundColor: ApixColors.deepNavy,
        foregroundColor: ApixColors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ApixColors.sparkOrange,
        foregroundColor: ApixColors.onSparkOrange,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ApixColors.deepNavy,
          foregroundColor: ApixColors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ApixColors.sparkOrange,
          foregroundColor: ApixColors.onSparkOrange,
        ),
      ),
      cardTheme: CardThemeData(
        color: ApixColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: ApixColors.borderBlue.withValues(alpha: 0.2),
    );
  }
}
