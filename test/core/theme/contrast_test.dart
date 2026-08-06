import 'dart:math' as math;

import 'package:apix_example_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrast floor for body text, WCAG 2.1 AA.
const double _aaNormalText = 4.5;

/// Contrast floor for large or bold text (>= 18pt, or 14pt bold), WCAG AA.
const double _aaLargeText = 3.0;

/// Relative luminance per WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) {
    final s = v; // already 0..1
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Contrast ratio between two opaque colours, 1.0 (identical) to 21.0.
double _ratio(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Guards the readability of every text/background pair the app renders.
///
/// Written after a real defect: the palette was designed against a light
/// surface, the app shipped with `ThemeMode.system`, and on a dark-mode phone
/// the section labels and the unselected cache chips were barely legible —
/// navy text on an almost-black background. Nothing failed; it just could not
/// be read. The dark theme has since been removed, and the app is light-only.
///
/// Colours are read from the **resolved** `ColorScheme`, not from
/// `ApixColors`, so a change to either the palette or the scheme wiring is
/// caught. Writing a colour straight into a widget bypasses this test — which
/// is precisely how the bug got in.
void main() {
  /// The pairs the screens actually put on top of each other.
  ///
  /// Keep in sync with the widgets — a pair that stops being rendered should
  /// leave this list, and a new one should join it.
  List<({String what, Color fg, Color bg, double floor})> pairsFor(
    ThemeData theme,
  ) {
    final s = theme.colorScheme;
    return [
      // StatusBar: the message line and the metrics line.
      (
        what: 'status message',
        fg: s.onSurface,
        bg: s.surfaceContainerHighest,
        floor: _aaNormalText,
      ),
      (
        what: 'status metrics',
        fg: s.onSurfaceVariant,
        bg: s.surfaceContainerHighest,
        floor: _aaNormalText,
      ),
      (
        what: 'status metrics (error)',
        fg: s.error,
        bg: s.surfaceContainerHighest,
        floor: _aaNormalText,
      ),
      // Section headings on the page background.
      (
        what: 'section label',
        fg: s.onSurfaceVariant,
        bg: theme.scaffoldBackgroundColor,
        floor: _aaNormalText,
      ),
      // Cache strategy chips, both states.
      (
        what: 'unselected strategy chip',
        fg: s.onSurfaceVariant,
        bg: s.surfaceContainerHighest,
        floor: _aaLargeText,
      ),
      (
        what: 'selected strategy chip',
        fg: ApixColors.onSparkOrange,
        bg: ApixColors.sparkOrange,
        floor: _aaLargeText,
      ),
      // App bar title.
      (
        what: 'app bar title',
        fg: ApixColors.white,
        bg: theme.appBarTheme.backgroundColor ?? s.surface,
        floor: _aaLargeText,
      ),
    ];
  }

  group('light theme', () {
    final pairs = pairsFor(AppTheme.light);

    test('the pair list is not empty', () {
      // Guards the guard: an empty list would make every test below vanish
      // and the group would still report green.
      expect(pairs, isNotEmpty);
    });

    for (final pair in pairs) {
      test('${pair.what} meets ${pair.floor}:1', () {
        final ratio = _ratio(pair.fg, pair.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(pair.floor),
          reason:
              '${pair.what} sits at ${ratio.toStringAsFixed(2)}:1, below the '
              '${pair.floor}:1 WCAG AA floor. Adjust the ColorScheme rather '
              'than the widget: a colour hardcoded in one widget is how this '
              'broke the first time.',
        );
      });
    }
  });

  test('the app renders on the light surface it was designed for', () {
    // The palette assumes a light background throughout. If a dark theme is
    // ever reintroduced, every pair above has to be re-measured against it —
    // auditing one surface says nothing about the other.
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.light.scaffoldBackgroundColor, ApixColors.lightGray);
  });
}
