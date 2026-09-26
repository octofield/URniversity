import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/theme/app_styles.dart';
import 'package:urniversity/core/theme/app_theme.dart';

// Every style has to be readable, not just pretty (system_design.md §3-R). The
// thresholds are WCAG's: 7:1 for body text (AAA), 4.5:1 for secondary text
// (AA), 3:1 for text on a filled button and large text; placeholders only have
// to be findable
void main() {
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
  }

  for (final entry in kStylePalettes.entries) {
    final name = entry.key.name;
    final p = entry.value;

    group(name, () {
      test('body text reads at AAA on the page and on cards', () {
        expect(contrast(p.textPrimary, p.background), greaterThanOrEqualTo(7), reason: 'on background');
        expect(contrast(p.textPrimary, p.surface), greaterThanOrEqualTo(7), reason: 'on surface');
      });

      test('secondary text reads at AA', () {
        expect(contrast(p.textSecondary, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textSecondary, p.surface), greaterThanOrEqualTo(4.5));
      });

      test('placeholders are faint but findable', () {
        expect(contrast(p.textTertiary, p.surface), greaterThanOrEqualTo(2.5));
      });

      test('white text on the primary colour works for buttons', () {
        expect(contrast(Colors.white, p.primary), greaterThanOrEqualTo(3));
      });

      test('the primary colour stands out from the page', () {
        expect(contrast(p.primary, p.background), greaterThanOrEqualTo(3));
      });

      test('text on a primary-tinted chip still reads', () {
        expect(contrast(p.textPrimary, p.primaryLight), greaterThanOrEqualTo(7));
      });

      test('cards are told apart from the page by their border', () {
        expect(p.border, isNot(p.surface));
        expect(contrast(p.border, p.surface), greaterThan(1.1));
      });

      test('brightness matches the ground it is drawn on', () {
        final dark = p.background.computeLuminance() < 0.2;
        expect(p.brightness, dark ? Brightness.dark : Brightness.light);
      });

      test('a friendly corner, never a pill or a hard square', () {
        expect(p.radius, inInclusiveRange(6, 24));
      });
    });
  }

  // Chinese falls through the Latin face to the style's own Chinese one, in
  // the regular or the bold file by the text's weight (google_fonts names each
  // loaded file "<Family>_<variant>")
  testWidgets('every text style carries its Chinese typeface as fallback', (tester) async {
    for (final entry in kStylePalettes.entries) {
      final p = entry.value;
      final theme = buildAppTheme(p);
      final family = p.cjkFontFamily.replaceAll(' ', '');
      final t = theme.textTheme;
      for (final style in [t.displayLarge, t.headlineSmall, t.titleLarge, t.titleMedium, t.bodyMedium, t.labelSmall]) {
        expect(style!.fontFamilyFallback, isNotNull, reason: entry.key.name);
        expect(style.fontFamilyFallback!.single, startsWith(family), reason: entry.key.name);
        expect(style.fontFamilyFallback!.single, endsWith('regular'), reason: entry.key.name);
      }
      // The rail's selected label is bold, and gets the bold file
      final bold = theme.navigationRailTheme.selectedLabelTextStyle!;
      expect(bold.fontFamilyFallback!.single, '${family}_700', reason: entry.key.name);
    }
  });

  test('a name nobody knows falls back to the original look', () {
    expect(appStyleFromName('modern'), AppStyle.modern);
    expect(appStyleFromName('neon'), AppStyle.linen);
    expect(appStyleFromName(null), AppStyle.linen);
  });

  test('every style has a palette', () {
    expect(kStylePalettes.keys, containsAll(AppStyle.values));
  });
}
