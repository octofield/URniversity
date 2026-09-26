import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_styles.dart';

// The Material theme for a style (system_design.md §3-R). Built after
// AppColors.use(p), so the AppColors and AppRadius reads below are that style's.
//
// Material's own components (dialogs, pickers, menus, snack bars) take their
// colours from the ColorScheme, so the scheme is seeded from the style and then
// pinned to its exact neutrals — otherwise a dark style would still get light
// dialogs, and a light one Material's tinted greys instead of its own paper
ThemeData buildAppTheme(StylePalette p) {
  final base = ThemeData(brightness: p.brightness, useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: p.brightness,
  ).copyWith(
    primary: p.primary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: p.primaryLight,
    onPrimaryContainer: p.textPrimary,
    secondaryContainer: p.primaryLight,
    onSecondaryContainer: p.textPrimary,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: p.surfaceVariant,
    outline: p.border,
    outlineVariant: p.border,
    error: p.error,
    errorContainer: p.errorLight,
  );
  // Chinese characters fall through the Latin font to the style's own Chinese
  // typeface. Only its regular and bold files are asked for, so a style costs
  // two downloads the first time and nothing after; heavier weights set at a
  // call site are drawn bold from the regular file
  final cjkRegular = GoogleFonts.getFont(p.cjkFontFamily, fontWeight: FontWeight.w400).fontFamily!;
  final cjkBold = GoogleFonts.getFont(p.cjkFontFamily, fontWeight: FontWeight.w700).fontFamily!;
  TextStyle withCjk(TextStyle style) => style.copyWith(
        fontFamilyFallback: [(style.fontWeight?.value ?? 400) >= 600 ? cjkBold : cjkRegular],
      );
  TextStyle font(TextStyle style) => withCjk(GoogleFonts.getFont(p.fontFamily, textStyle: style));
  final latin = GoogleFonts.getTextTheme(p.fontFamily, base.textTheme)
      .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

  return ThemeData(
    brightness: p.brightness,
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: TextTheme(
      displayLarge: withCjk(latin.displayLarge!),
      displayMedium: withCjk(latin.displayMedium!),
      displaySmall: withCjk(latin.displaySmall!),
      headlineLarge: withCjk(latin.headlineLarge!),
      headlineMedium: withCjk(latin.headlineMedium!),
      headlineSmall: withCjk(latin.headlineSmall!),
      titleLarge: withCjk(latin.titleLarge!),
      titleMedium: withCjk(latin.titleMedium!),
      titleSmall: withCjk(latin.titleSmall!),
      bodyLarge: withCjk(latin.bodyLarge!),
      bodyMedium: withCjk(latin.bodyMedium!),
      bodySmall: withCjk(latin.bodySmall!),
      labelLarge: withCjk(latin.labelLarge!),
      labelMedium: withCjk(latin.labelMedium!),
      labelSmall: withCjk(latin.labelSmall!),
    ),
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.surface,
    dividerTheme: DividerThemeData(color: AppColors.border),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
    popupMenuTheme: PopupMenuThemeData(color: AppColors.surface),
    datePickerTheme: DatePickerThemeData(backgroundColor: AppColors.surface),
    timePickerTheme: TimePickerThemeData(backgroundColor: AppColors.surface),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.borderFocus, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(AppSpacing.inputPadding),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    // One page transition per platform family (system_design.md §3-Q): Android
    // follows the back gesture as it is dragged, iOS keeps its edge swipe, and
    // everything else gets Material 3's fade-forwards
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    // Modal bottom sheets stay centered with a width cap on wide screens
    bottomSheetTheme: const BottomSheetThemeData(
      constraints: BoxConstraints(maxWidth: 640),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      indicatorColor: AppColors.primaryLight,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => font(TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textSecondary,
        )),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryLight,
      selectedIconTheme: const IconThemeData(size: 28),
      unselectedIconTheme: const IconThemeData(size: 28),
      selectedLabelTextStyle: font(TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      )),
      unselectedLabelTextStyle: font(TextStyle(
        fontSize: 16,
        color: AppColors.textSecondary,
      )),
    ),
  );
}
