import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../providers/reviews_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../screens/review_screen.dart';

// The card on the task page while a review is due (§3-P). It goes away by
// itself once that review is done or its window closes — no dismiss button to
// forget about
class ReviewPromptCard extends ConsumerWidget {
  const ReviewPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(dueReviewProvider);
    if (window == null) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final fmt = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_graph_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reviewTitle(window.period, s), style: theme.textTheme.titleMedium),
                  Text(
                    reviewRange(window.start, window.end, fmt, s),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(s.reviewCardBody, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReviewScreen(window: window)),
              ),
              child: Text(s.reviewStart),
            ),
          ],
        ),
      ),
    );
  }
}

// "Focus this week": the targets picked in the last weekly review. Tapping one
// narrows the task list to it, the same filter the filter dialog sets
class FocusChips extends ConsumerWidget {
  const FocusChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(activeFocusProvider);
    if (ids.isEmpty) return const SizedBox.shrink();
    final goals = ref.watch(semesterGoalsProvider);
    // A target deleted since the review simply drops out
    final targets = [
      for (final id in ids) ?goals.where((g) => g.id == id).firstOrNull,
    ];
    if (targets.isEmpty) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final filter = ref.watch(taskTargetFilterProvider);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            s.reviewFocusThisWeek,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
          ),
          for (final t in targets)
            FilterChip(
              visualDensity: VisualDensity.compact,
              label: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: filter.length == 1 && filter.contains(t.id),
              onSelected: (on) =>
                  ref.read(taskTargetFilterProvider.notifier).state = on ? {t.id} : const {},
            ),
        ],
      ),
    );
  }
}
