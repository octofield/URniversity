import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../models/review.dart';
import '../providers/reviews_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_body.dart';
import 'review_screen.dart';

// Every review done, newest first. Each opens to the numbers as they stood and
// what was written — the point of keeping them is reading them back a month on
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final reviews = ref.watch(reviewsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.reviews)),
      body: ResponsiveBody(
        child: reviews.isEmpty
            ? EmptyState(icon: Icons.auto_graph_outlined, message: s.reviewsEmpty)
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _ReviewTile(review: reviews[i]),
              ),
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  final Review review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final fmt = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final stats = review.stats;
    final goals = ref.watch(semesterGoalsProvider);
    final rate = stats.rate;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(reviewTitle(review.period, s)),
        subtitle: Text(
          '${reviewRange(review.periodStart, review.periodEnd, fmt, s)}'
          '${rate == null ? '' : '$kDotSeparator${(rate * 100).round()}%'}',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stats.total > 0) Text(s.reviewDoneOf(stats.done, stats.total), style: theme.textTheme.bodyMedium),
          if (stats.streak > 0) Text(s.reviewStreak(stats.streak), style: theme.textTheme.bodySmall),
          for (final (label, text) in [
            (s.reviewWentWell, review.wentWell),
            (s.reviewStuck, review.stuck),
            (s.reviewNextFocus, review.nextFocus),
          ])
            if (text != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
              Text(text, style: theme.textTheme.bodyMedium),
            ],
          if (review.focusTargetIds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(s.reviewFocusTitle, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final id in review.focusTargetIds)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    // The target may have been deleted since; the review still stands
                    label: Text(goals.where((g) => g.id == id).firstOrNull?.title ?? s.reviewDeleted),
                  ),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () async {
                if (await confirmDelete(context, s)) {
                  ref.read(reviewsProvider.notifier).remove(review.id);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
