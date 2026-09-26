import 'package:flutter/material.dart';
import 'app_styles.dart';

// The colours of the style in use (system_design.md §3-R). Getters rather than
// constants so the whole app can change style at run time; App calls use() and
// then rebuilds every widget. Anything built from these cannot be `const`.
class AppColors {
  AppColors._();

  static StylePalette _p = kStylePalettes[AppStyle.linen]!;
  static StylePalette get palette => _p;

  // Only App (and tests) switch styles; everything else just reads
  static void use(StylePalette palette) => _p = palette;

  // Background layers
  static Color get background => _p.background; // Page background
  static Color get surface => _p.surface; // Cards, input fields
  static Color get surfaceVariant => _p.surfaceVariant; // Secondary cards, disabled state

  // Primary
  static Color get primary => _p.primary; // Main CTA color
  static Color get primaryLight => _p.primaryLight; // Tag backgrounds, chip selected
  static Color get primaryDark => _p.primaryDark; // Pressed state

  // Text hierarchy
  static Color get textPrimary => _p.textPrimary; // Main text
  static Color get textSecondary => _p.textSecondary; // Descriptions, secondary info
  static Color get textTertiary => _p.textTertiary; // Placeholders, hints
  // White in every style: it also sits on the category-coloured add buttons
  static const textOnPrimary = Color(0xFFFFFFFF);

  // Semantic colors
  static Color get success => _p.success;
  static Color get successLight => _p.successLight;
  static Color get warning => _p.warning;
  static Color get warningLight => _p.warningLight;
  static Color get error => _p.error;
  static Color get errorLight => _p.errorLight;

  // Borders
  static Color get border => _p.border; // Default border
  static Color get borderFocus => _p.primary; // Focused border (same as primary)

  // Category colors (Future Goal categories). The user's data, so the same in
  // every style
  static const categoryExchange    = Color(0xFF4A90C4); // Exchange: soft blue
  static const categoryIntern      = Color(0xFF7B5CB8); // Intern: soft purple
  static const categoryCompetition = Color(0xFFE8980A); // Competition: warm amber
  static const categoryCert        = Color(0xFF1A9E6E); // Certification: forest green
  static const categoryPerformance = Color(0xFFD05090); // Performance: soft pink
  static const categoryOther       = Color(0xFF7A6A5A); // Other: warm gray-brown
}
