import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/future_goal.dart';

// Width of the category-color bar on the left edge of target/goal cards
const double goalCatBarWidth = 6.0;

// Fixed choice set for the icon picker. Every codepoint reconstructed from
// stored data (CategoryEntry.fromJson) always comes from this list, so
// Flutter's icon tree-shaker — which only keeps glyphs it can see referenced
// as literal Icons.xxx constants — never strips a glyph a user has picked.
const List<IconData> categoryIconPresets = [
  Icons.flight_outlined,
  Icons.work_outline,
  Icons.emoji_events_outlined,
  Icons.card_membership_outlined,
  Icons.mic_outlined,
  Icons.star_outline,
  Icons.school_outlined,
  Icons.menu_book_outlined,
  Icons.code_outlined,
  Icons.language_outlined,
  Icons.sports_soccer_outlined,
  Icons.music_note_outlined,
  Icons.favorite_outline,
  Icons.home_outlined,
  Icons.fitness_center_outlined,
  Icons.palette_outlined,
  Icons.camera_alt_outlined,
  Icons.savings_outlined,
  Icons.computer_outlined,
  Icons.label_outline,
];

const List<Color> categoryColorPresets = [
  AppColors.categoryExchange,
  AppColors.categoryIntern,
  AppColors.categoryCompetition,
  AppColors.categoryCert,
  AppColors.categoryPerformance,
  AppColors.categoryOther,
  Color(0xFFE85D75),
  Color(0xFF2E9E8E),
  Color(0xFF6B5CA5),
  Color(0xFFC4622D),
  Color(0xFF3D7A3D),
  Color(0xFF3A6EA5),
];

// Default color/icon used to seed a newly created category, and as a fallback
// when a category id no longer exists in the user's current list.
Color defaultCatColor(String cat) {
  switch (cat) {
    case FutureCategories.exchange:      return AppColors.categoryExchange;
    case FutureCategories.intern:        return AppColors.categoryIntern;
    case FutureCategories.competition:   return AppColors.categoryCompetition;
    case FutureCategories.certification: return AppColors.categoryCert;
    case FutureCategories.performance:   return AppColors.categoryPerformance;
    default:                             return AppColors.categoryOther;
  }
}

IconData defaultCatIcon(String cat) {
  const icons = <String, IconData>{
    FutureCategories.exchange:      Icons.flight_outlined,
    FutureCategories.intern:        Icons.work_outline,
    FutureCategories.competition:   Icons.emoji_events_outlined,
    FutureCategories.certification: Icons.card_membership_outlined,
    FutureCategories.performance:   Icons.mic_outlined,
    FutureCategories.other:         Icons.star_outline,
  };
  return icons[cat] ?? Icons.label_outline;
}

// Live color/icon for a category — checks the user's current customizations
// first (including recolored/re-iconed built-ins), falling back to the
// built-in default for a not-yet-customized or orphaned id.
Color resolveCatColor(List<CategoryEntry> cats, String id) =>
    cats.where((c) => c.id == id).firstOrNull?.color ?? defaultCatColor(id);

IconData resolveCatIcon(List<CategoryEntry> cats, String id) =>
    cats.where((c) => c.id == id).firstOrNull?.icon ?? defaultCatIcon(id);

String catLabel(String cat, AppStrings s) {
  switch (cat) {
    case FutureCategories.exchange:      return s.catExchange;
    case FutureCategories.intern:        return s.catIntern;
    case FutureCategories.competition:   return s.catCompetition;
    case FutureCategories.certification: return s.catCertification;
    case FutureCategories.performance:   return s.catPerformance;
    case FutureCategories.other:         return s.catOther;
    default:                             return cat;
  }
}
