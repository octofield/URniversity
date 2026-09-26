import 'app_colors.dart';

// Corner radii of the style in use (system_design.md §3-R). Each style sets its
// card radius; the rest keep the original proportions to it (16 → 6/8/12/16/24)
class AppRadius {
  AppRadius._();

  static double get _card => AppColors.palette.radius;

  static double get xs => _card * 0.375; // Small elements: badges, small chips
  static double get sm => _card * 0.5; // Inputs, small buttons
  static double get md => _card * 0.75; // Standard buttons
  static double get lg => _card; // Cards (most common)
  static double get xl => _card * 1.5; // Bottom sheet top corner
  static const full = 999.0; // Full-round: tags, avatars, icon buttons
}
