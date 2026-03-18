import 'package:flutter/material.dart';

/// Apix brand colors.
abstract class ApixColors {
  /// Deep Navy - Primary background
  static const deepNavy = Color(0xFF1E3A5F);

  /// Border Blue - Secondary/border
  static const borderBlue = Color(0xFF3D5A80);

  /// Spark Orange - Accent color
  static const sparkOrange = Color(0xFFF89C35);

  /// Slate Gray - Text secondary
  static const slateGray = Color(0xFF4A5568);

  /// Light Gray - Background
  static const lightGray = Color(0xFFF7FAFC);

  /// White
  static const white = Color(0xFFFFFFFF);

  /// Dark background
  static const darkBg = Color(0xFF0D1117);
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
        onSecondary: ApixColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ApixColors.deepNavy,
        foregroundColor: ApixColors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ApixColors.sparkOrange,
        foregroundColor: ApixColors.white,
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
          foregroundColor: ApixColors.white,
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

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ApixColors.deepNavy,
        brightness: Brightness.dark,
        primary: ApixColors.borderBlue,
        secondary: ApixColors.sparkOrange,
        surface: ApixColors.darkBg,
        onPrimary: ApixColors.white,
        onSecondary: ApixColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ApixColors.darkBg,
        foregroundColor: ApixColors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ApixColors.sparkOrange,
        foregroundColor: ApixColors.white,
      ),
      cardTheme: CardThemeData(
        color: ApixColors.deepNavy,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
