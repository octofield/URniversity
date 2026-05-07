import 'package:flutter/material.dart';

class AppColors {
  // Background layers (warm linen tones)
  static const background     = Color(0xFFF8F4EF); // Page background — warm off-white
  static const surface        = Color(0xFFFFFFFF); // Cards, input fields
  static const surfaceVariant = Color(0xFFEDE5D8); // Secondary cards, disabled state

  // Primary (warm caramel brown — linen family)
  static const primary        = Color(0xFFA07850); // Main CTA color
  static const primaryLight   = Color(0xFFF2EAE0); // Tag backgrounds, chip selected
  static const primaryDark    = Color(0xFF7A5A38); // Pressed state

  // Text hierarchy (warm brown tones)
  static const textPrimary    = Color(0xFF2A1E12); // Main text
  static const textSecondary  = Color(0xFF6B5843); // Descriptions, secondary info
  static const textTertiary   = Color(0xFFB09A84); // Placeholders, hints
  static const textOnPrimary  = Color(0xFFFFFFFF); // Text on primary-colored background

  // Semantic colors
  static const success        = Color(0xFF10B981);
  static const successLight   = Color(0xFFD1FAE5);
  static const warning        = Color(0xFFF59E0B);
  static const warningLight   = Color(0xFFFEF3C7);
  static const error          = Color(0xFFEF4444);
  static const errorLight     = Color(0xFFFEE2E2);

  // Borders
  static const border         = Color(0xFFDDD0C0); // Default border
  static const borderFocus    = Color(0xFFA07850); // Focused border (same as primary)

  // Category colors (Future Goal categories)
  static const categoryExchange    = Color(0xFF4A90C4); // Exchange: soft blue
  static const categoryIntern      = Color(0xFF7B5CB8); // Intern: soft purple
  static const categoryCompetition = Color(0xFFE8980A); // Competition: warm amber
  static const categoryCert        = Color(0xFF1A9E6E); // Certification: forest green
  static const categoryPerformance = Color(0xFFD05090); // Performance: soft pink
  static const categoryOther       = Color(0xFF7A6A5A); // Other: warm gray-brown
}
