import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../providers/onboarding_provider.dart';
import '../providers/settings_provider.dart';
import 'sheet_body.dart';

// Every tour chapter with whether it has run, and a way to run it again. Each
// chapter plays once on its own, so this is the only road back to one
void showTourGuideSheet(BuildContext context, WidgetRef ref) {
  showAppSheet(
    context,
    builder: (sheetCtx) => Consumer(
      builder: (ctx, ref, _) {
        final s = ref.watch(stringsProvider);
        final done = ref.watch(onboardingProvider);
        // Same names as the tabs, since a chapter is a tab
        final names = [s.tasks, s.targets, s.goals, s.me];
        final theme = Theme.of(ctx);

        return SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.tourGuide, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < kTourChapters.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    done.contains(kTourChapters[i])
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: done.contains(kTourChapters[i])
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                  title: Text(names[i]),
                  subtitle: Text(
                    done.contains(kTourChapters[i]) ? s.tourChapterDone : s.tourChapterNew,
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () {
                      // Back to the home screen first: a chapter points at it,
                      // and HomeScreen will not start one under another page
                      Navigator.of(ctx).popUntil((route) => route.isFirst);
                      ref.read(tourReplayProvider.notifier).state = kTourChapters[i];
                    },
                    child: Text(
                      done.contains(kTourChapters[i]) ? s.tourReplay : s.tourStart,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.tourGuideNote,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        );
      },
    ),
  );
}
