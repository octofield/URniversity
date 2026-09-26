import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_styles.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../providers/app_style_provider.dart';
import '../providers/settings_provider.dart';
import 'sheet_body.dart';

String appStyleName(AppStyle style, AppStrings s) => switch (style) {
      AppStyle.linen => s.styleLinen,
      AppStyle.modern => s.styleModern,
      AppStyle.midnight => s.styleMidnight,
      AppStyle.sage => s.styleSage,
      AppStyle.ocean => s.styleOcean,
      AppStyle.sakura => s.styleSakura,
      AppStyle.mono => s.styleMono,
    };

// The settings line under "Style": the choice, which may be random
String appStyleChoiceName(String choice, AppStrings s) =>
    choice == kRandomStyle ? s.styleRandom : appStyleName(appStyleFromName(choice), s);

String _cjkName(String family, AppStrings s) => switch (family) {
      kCjkKai => s.cjkKai,
      kCjkSerif => s.cjkSerif,
      _ => s.cjkSans,
    };

String _styleDescription(AppStyle style, AppStrings s) => switch (style) {
      AppStyle.linen => s.styleLinenDesc,
      AppStyle.modern => s.styleModernDesc,
      AppStyle.midnight => s.styleMidnightDesc,
      AppStyle.sage => s.styleSageDesc,
      AppStyle.ocean => s.styleOceanDesc,
      AppStyle.sakura => s.styleSakuraDesc,
      AppStyle.mono => s.styleMonoDesc,
    };

// The style picker (system_design.md §3-R): a grid of small previews, each
// drawn in its own style rather than described. Picking one applies it at once
// and the sheet stays open, so styles can be compared on the real app behind it
void showStylePicker(BuildContext context) {
  showAppSheet(
    context,
    builder: (_) => SheetBody(
      child: Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(stringsProvider);
          // The choice, not the style in use: in random mode the style drawn
          // for this launch must not look like the one picked
          final choice = ref.watch(appStyleChoiceProvider);
          final notifier = ref.read(appStyleProvider.notifier);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.appStyle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  // The sheet is capped at 640, so three across is the most
                  // that keeps each preview legible
                  final columns = constraints.maxWidth >= 520 ? 3 : 2;
                  const gap = AppSpacing.sm;
                  final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: width,
                        child: _RandomCard(
                          name: s.styleRandom,
                          description: s.styleRandomDesc,
                          selected: choice == kRandomStyle,
                          onTap: () => notifier.setRandom(),
                        ),
                      ),
                      for (final style in AppStyle.values)
                        SizedBox(
                          width: width,
                          child: _StyleCard(
                            name: appStyleName(style, s),
                            description: _styleDescription(style, s),
                            fonts: '${kStylePalettes[style]!.fontFamily}$kDotSeparator'
                                '${_cjkName(kStylePalettes[style]!.cjkFontFamily, s)}',
                            palette: kStylePalettes[style]!,
                            selected: choice == style.name,
                            onTap: () => notifier.set(style),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _StyleCard extends StatelessWidget {
  final String name;
  final String description;
  // Latin and Chinese typefaces, named rather than drawn: showing the Chinese
  // one would download all three families just to open this sheet
  final String fonts;
  final StylePalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.name,
    required this.description,
    required this.fonts,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final theme = Theme.of(context).textTheme;
    // Drawn in the card's own style, whatever the app is wearing
    TextStyle? inStyle(TextStyle? base) =>
        base == null ? null : GoogleFonts.getFont(p.fontFamily, textStyle: base);

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: scaled(context, AppMotion.quick),
          curve: AppMotion.moveCurve,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: BorderRadius.circular(p.radius),
            border: Border.all(
              color: selected ? AppColors.primary : p.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniScreen(palette: p),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: inStyle(theme.titleSmall)?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, size: 18, color: p.primary),
                ],
              ),
              Text(
                description,
                style: inStyle(theme.bodySmall)?.copyWith(color: p.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                fonts,
                style: inStyle(theme.labelSmall)?.copyWith(color: p.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A thumbnail of the task page in a given style: a card with a ticked and an
// open task, and the primary button under it
class _MiniScreen extends StatelessWidget {
  final StylePalette palette;

  const _MiniScreen({required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final r = p.radius * 0.6;

    Widget line(double widthFactor, Color color) => FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 5,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        );

    Widget task({required bool done}) => Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: done ? p.primary : null,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: done ? p.primary : p.textTertiary, width: 1.2),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: line(done ? 0.55 : 0.8, done ? p.textTertiary : p.textPrimary)),
          ],
        );

    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: p.surfaceVariant,
          borderRadius: BorderRadius.circular(r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(r),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [task(done: true), task(done: false), task(done: false)],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: p.primaryLight, shape: BoxShape.circle),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(r),
                  ),
                  child: Container(
                    width: 22,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// "Random": a strip of every style's ground and accent, since it could be any
// of them. Drawn in the app's current style around the strip
class _RandomCard extends StatelessWidget {
  final String name;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RandomCard({
    required this.name,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: scaled(context, AppMotion.quick),
          curve: AppMotion.moveCurve,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.35,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Row(
                        children: [
                          for (final p in kStylePalettes.values)
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(flex: 3, child: ColoredBox(color: p.background)),
                                  Expanded(flex: 2, child: ColoredBox(color: p.primary)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.shuffle, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                ],
              ),
              Text(
                description,
                style: theme.bodySmall?.copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
