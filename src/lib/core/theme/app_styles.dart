import 'package:flutter/material.dart';

// The looks a user can pick (system_design.md §3-R). A style is colours, a
// typeface and a corner radius together — changing only the colour of a
// rounded, friendly layout does not make it modern, and changing only the font
// does not make it calm.
//
// Category and avatar colours are not here: they are the user's own data and
// keep their meaning whatever the style.
enum AppStyle { linen, modern, midnight, sage, ocean, sakura, mono }

// Stored as the enum's name; anything unknown (a newer build's style, a typo
// in the database) falls back to the original look
AppStyle appStyleFromName(String? name) =>
    AppStyle.values.where((s) => s.name == name).firstOrNull ?? AppStyle.linen;

// The Chinese typefaces a style can pair with. Google Fonts names; they are
// large (several MB per weight), so only the regular and bold files are ever
// fetched, on first use, and cached from then on
const kCjkSans = 'Noto Sans TC'; // 思源黑體
const kCjkSerif = 'Noto Serif TC'; // 思源宋體
const kCjkKai = 'LXGW WenKai TC'; // 霞鶩文楷

class StylePalette {
  final Brightness brightness;
  final String fontFamily;
  // Drawn for Chinese characters, which the Latin fontFamily has no glyphs for
  final String cjkFontFamily;

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;

  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color error;
  final Color errorLight;

  // The card radius; the others are scaled from it (AppRadius)
  final double radius;

  const StylePalette({
    this.brightness = Brightness.light,
    required this.fontFamily,
    required this.cjkFontFamily,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    this.success = const Color(0xFF10B981),
    this.successLight = const Color(0xFFD1FAE5),
    this.warning = const Color(0xFFF59E0B),
    this.warningLight = const Color(0xFFFEF3C7),
    this.error = const Color(0xFFEF4444),
    this.errorLight = const Color(0xFFFEE2E2),
    required this.radius,
  });
}

const kStylePalettes = <AppStyle, StylePalette>{
  // The original: warm linen and caramel, a paper-planner feel
  AppStyle.linen: StylePalette(
    fontFamily: 'Nunito',
    cjkFontFamily: kCjkKai,
    background: Color(0xFFF8F4EF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEDE5D8),
    primary: Color(0xFFA07850),
    primaryLight: Color(0xFFF2EAE0),
    primaryDark: Color(0xFF7A5A38),
    textPrimary: Color(0xFF2A1E12),
    textSecondary: Color(0xFF6B5843),
    textTertiary: Color(0xFFB09A84),
    border: Color(0xFFDDD0C0),
    radius: 16,
  ),
  // Cool slate neutrals with one indigo accent, the productivity-tool look
  AppStyle.modern: StylePalette(
    fontFamily: 'Inter',
    cjkFontFamily: kCjkSans,
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5F9),
    primary: Color(0xFF4F46E5),
    primaryLight: Color(0xFFEEF2FF),
    primaryDark: Color(0xFF3730A3),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    radius: 12,
  ),
  // Charcoal rather than black, periwinkle accent; easy on the eyes at night
  AppStyle.midnight: StylePalette(
    brightness: Brightness.dark,
    fontFamily: 'Manrope',
    cjkFontFamily: kCjkSans,
    background: Color(0xFF0F1115),
    surface: Color(0xFF181B21),
    surfaceVariant: Color(0xFF232730),
    primary: Color(0xFF7383F5),
    primaryLight: Color(0xFF262B45),
    primaryDark: Color(0xFF5A6AE0),
    textPrimary: Color(0xFFE8EAED),
    textSecondary: Color(0xFFA9AFBB),
    textTertiary: Color(0xFF6B7280),
    border: Color(0xFF2E333D),
    success: Color(0xFF34D399),
    successLight: Color(0xFF0F2E26),
    warning: Color(0xFFFBBF24),
    warningLight: Color(0xFF332A0F),
    error: Color(0xFFF87171),
    errorLight: Color(0xFF3A1A1A),
    radius: 14,
  ),
  // Muted green on a pale leaf ground, quiet and natural
  AppStyle.sage: StylePalette(
    fontFamily: 'DM Sans',
    cjkFontFamily: kCjkSerif,
    background: Color(0xFFF4F6F1),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE6ECE3),
    primary: Color(0xFF4F7A5A),
    primaryLight: Color(0xFFE3ECE2),
    primaryDark: Color(0xFF3A5C43),
    textPrimary: Color(0xFF1F2A22),
    textSecondary: Color(0xFF536357),
    textTertiary: Color(0xFF94A297),
    border: Color(0xFFD5DED2),
    radius: 18,
  ),
  // Deep teal on a cool, airy ground, for focus
  AppStyle.ocean: StylePalette(
    fontFamily: 'Plus Jakarta Sans',
    cjkFontFamily: kCjkSans,
    background: Color(0xFFF2F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE3EEF3),
    primary: Color(0xFF0E7490),
    primaryLight: Color(0xFFDDF1F6),
    primaryDark: Color(0xFF0B5A70),
    textPrimary: Color(0xFF0B2530),
    textSecondary: Color(0xFF47626E),
    textTertiary: Color(0xFF8AA1AB),
    border: Color(0xFFD3E3EA),
    radius: 16,
  ),
  // Soft rose, a rounded typeface and the roundest corners
  AppStyle.sakura: StylePalette(
    fontFamily: 'Quicksand',
    cjkFontFamily: kCjkKai,
    background: Color(0xFFFFF7F8),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFFBE9EC),
    primary: Color(0xFFD6617A),
    primaryLight: Color(0xFFFCE7EB),
    primaryDark: Color(0xFFB04860),
    textPrimary: Color(0xFF3A2328),
    textSecondary: Color(0xFF7A5A61),
    textTertiary: Color(0xFFB4969D),
    border: Color(0xFFF2D6DC),
    radius: 20,
  ),
  // Black and white, a grotesque typeface and sharp corners: editorial
  AppStyle.mono: StylePalette(
    fontFamily: 'Space Grotesk',
    cjkFontFamily: kCjkSerif,
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF0F0F0),
    primary: Color(0xFF18181B),
    primaryLight: Color(0xFFEDEDED),
    primaryDark: Color(0xFF000000),
    textPrimary: Color(0xFF09090B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFFA1A1AA),
    border: Color(0xFFE4E4E7),
    radius: 8,
  ),
};
