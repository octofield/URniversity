import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';

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
  Icons.science_outlined,
  Icons.calculate_outlined,
  Icons.brush_outlined,
  Icons.theater_comedy_outlined,
  Icons.headphones_outlined,
  Icons.videogame_asset_outlined,
  Icons.directions_run_outlined,
  Icons.pedal_bike_outlined,
  Icons.restaurant_outlined,
  Icons.local_cafe_outlined,
  Icons.pets_outlined,
  Icons.eco_outlined,
  Icons.public_outlined,
  Icons.groups_outlined,
  Icons.handshake_outlined,
  Icons.volunteer_activism_outlined,
  Icons.lightbulb_outline,
  Icons.psychology_outlined,
  Icons.auto_stories_outlined,
  Icons.edit_note_outlined,
  Icons.attach_money_outlined,
  Icons.shopping_bag_outlined,
  Icons.medical_services_outlined,
  Icons.self_improvement_outlined,
  Icons.bedtime_outlined,
  Icons.celebration_outlined,
  Icons.map_outlined,
  Icons.directions_car_outlined,
  Icons.train_outlined,
  Icons.rocket_launch_outlined,
  Icons.military_tech_outlined,
  Icons.workspace_premium_outlined,
  Icons.gavel_outlined,
  Icons.build_outlined,
  Icons.construction_outlined,
  Icons.terminal_outlined,
  Icons.storage_outlined,
  Icons.cloud_outlined,
];

// The colours a category can be given, by hue family. The first six are the
// built-in category colours, so an existing category never changes colour just
// because the list grew. Saturation is kept in the same warm range as those —
// a screen full of these has to sit next to the linen background all day.
const List<Color> categoryColorPresets = [
  // Built-ins, in their original order
  AppColors.categoryExchange,
  AppColors.categoryIntern,
  AppColors.categoryCompetition,
  AppColors.categoryCert,
  AppColors.categoryPerformance,
  AppColors.categoryOther,
  // Red / orange
  Color(0xFFE85D75),
  Color(0xFFC0432F),
  Color(0xFFC4622D),
  Color(0xFFE08A3C),
  // Yellow / green
  Color(0xFFD9A520),
  Color(0xFF8C9A2B),
  Color(0xFF3D7A3D),
  Color(0xFF2E9E8E),
  // Cyan / blue
  Color(0xFF2B8C8C),
  Color(0xFF3A6EA5),
  Color(0xFF2F5C8F),
  Color(0xFF5B8FC9),
  // Purple / pink
  Color(0xFF6B5CA5),
  Color(0xFF8E6BB5),
  Color(0xFFB05C9B),
  Color(0xFFD98BA8),
  // Neutrals
  Color(0xFF8A7A66),
  Color(0xFF5A5148),
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

// The colour a task takes from the target it is linked to, null when it is not
// linked to one. The task list, the weekly grid and the widget snapshot all go
// through here so they can never drift apart
Color? taskLinkColor(List<CategoryEntry> cats, SemesterGoal? linkedTarget) =>
    linkedTarget == null
        ? null
        : resolveCatColor(cats, primaryCategoryOf(linkedTarget.categories));

// The category a row takes its colour and icon from, or null when it has none.
// Picking a category is optional, so an empty list must not be dressed up as
// "other" — that is a real category the user may be using for something else
String? primaryCategoryOf(List<String> categories) =>
    categories.isEmpty ? null : categories.first;

// What an uncategorized row looks like: present, but saying nothing
const Color noCategoryColor = AppColors.textTertiary;
const IconData noCategoryIcon = Icons.label_outline;

// Live color/icon for a category — checks the user's current customizations
// first (including recolored/re-iconed built-ins), falling back to the
// built-in default for a not-yet-customized or orphaned id.
Color resolveCatColor(List<CategoryEntry> cats, String? id) => id == null
    ? noCategoryColor
    : cats.where((c) => c.id == id).firstOrNull?.color ?? defaultCatColor(id);

IconData resolveCatIcon(List<CategoryEntry> cats, String? id) => id == null
    ? noCategoryIcon
    : cats.where((c) => c.id == id).firstOrNull?.icon ?? defaultCatIcon(id);

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
