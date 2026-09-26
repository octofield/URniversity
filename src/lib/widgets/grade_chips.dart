import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/grade_scale.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../providers/settings_provider.dart';

String gradeName(String? grade, AppStrings s) => switch (grade) {
      null => s.gradeNone,
      kGradePass => s.gradePass,
      kGradeFail => s.gradeFail,
      kGradeWithdrawn => s.gradeWithdrawn,
      _ => grade,
    };

// A course's grade (UC20): the eleven letters, then pass / fail / withdrawn,
// and whether it counts towards the GPA. Tapping the chosen grade again clears
// it back to "not graded yet"
class GradeChips extends ConsumerWidget {
  final String? grade;
  final bool countsInGpa;
  final ValueChanged<String?> onGrade;
  final ValueChanged<bool> onCountsInGpa;

  const GradeChips({
    super.key,
    required this.grade,
    required this.countsInGpa,
    required this.onGrade,
    required this.onCountsInGpa,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;

    Widget chip(String value) => ChoiceChip(
          label: Text(gradeName(value, s)),
          selected: grade == value,
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
          onSelected: (on) => onGrade(on ? value : null),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.courseGradeLabel, style: theme.titleSmall),
            const SizedBox(width: AppSpacing.sm),
            Text(gradeName(grade, s), style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [for (final g in kGradePoints.keys) chip(g)],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [for (final g in kGradeMarkers) chip(g)],
        ),
        // Pass/fail and withdrawn never count; the switch is for letter-graded
        // courses kept out by rule, such as service learning
        if (isLetterGrade(grade) || grade == null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(s.countsInGpaLabel),
            value: countsInGpa,
            activeThumbColor: AppColors.primary,
            onChanged: onCountsInGpa,
          ),
      ],
    );
  }
}
