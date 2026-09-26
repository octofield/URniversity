import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/gpa_stats.dart';
import '../core/grade_scale.dart';
import '../core/period_tables.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/course.dart';
import '../providers/courses_provider.dart';
import '../providers/grade_settings_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import 'course_sheet.dart';
import 'gpa_trend_chart.dart';
import 'grade_chips.dart' show gradeName;

String _two(double v) => v.toStringAsFixed(2);
String _credits(double c) => c == c.roundToDouble() ? c.toInt().toString() : c.toStringAsFixed(1);

// The grades page (UC20, system_design.md §3-T): this semester's GPA, the
// cumulative one with its percentage, credits towards graduation, the trend,
// what the rest of the courses must average for a target, and every graded
// course by semester
class GradesView extends ConsumerStatefulWidget {
  final String semester;
  const GradesView({super.key, required this.semester});

  @override
  ConsumerState<GradesView> createState() => _GradesViewState();
}

class _GradesViewState extends ConsumerState<GradesView> {
  final _target = TextEditingController();

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final courses = ref.watch(coursesProvider);
    final settings = ref.watch(gradeSettingsProvider);
    final confirmed = ref.read(gradeSettingsProvider.notifier).confirmed;
    final isNtu = ref.watch(profileProvider)?.school == kNtuSchool;

    final term = semesterGpa(courses, widget.semester);
    final total = cumulativeGpa(courses);
    final percent = total == null ? null : gpaToPercent(total);
    final earned = earnedCredits(courses, settings.level);
    final trend = gpaBySemester(courses);
    final target = double.tryParse(_target.text.trim());

    final bySemester = <String, List<Course>>{};
    for (final c in courses) {
      bySemester.putIfAbsent(c.semester, () => []).add(c);
    }
    final semesters = bySemester.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.sm, AppSpacing.pageHorizontal, 96),
      children: [
        if (!confirmed) ...[
          _DegreeSetup(settings: settings, s: s),
          const SizedBox(height: AppSpacing.md),
        ],
        LayoutBuilder(builder: (context, c) {
          final cards = [
            _Stat(label: s.semesterGpa, value: term == null ? kEmptyValue : _two(term)),
            _Stat(
              label: s.cumulativeGpa,
              value: total == null ? kEmptyValue : _two(total),
              note: percent == null ? null : s.percentEquivalent(_two(percent)),
            ),
            _Stat(
              label: s.creditsEarned,
              value: s.creditsOf(_credits(earned), settings.graduationCredits),
              progress: (earned / settings.graduationCredits).clamp(0.0, 1.0),
            ),
          ];
          // Three across when there is room; otherwise the credits card takes
          // the full width under the two GPAs
          if (c.maxWidth >= 520) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          }
          return Column(children: [
            Row(children: [
              Expanded(child: cards[0]),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: cards[1]),
            ]),
            const SizedBox(height: AppSpacing.sm),
            cards[2],
          ]);
        }),
        if (!isNtu) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(s.gradesOtherSchool, style: theme.bodySmall?.copyWith(color: AppColors.textTertiary)),
        ],
        if (trend.length >= 2) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(s.gpaTrend, style: theme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          GpaTrendChart(points: trend),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(s.targetGpa, style: theme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: TextField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-4](\.\d{0,2})?'))],
                decoration: const InputDecoration(hintText: '3.80', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: target == null
                    ? const SizedBox.shrink()
                    : Text(
                        switch (requiredAverage(target, courses)) {
                          TargetNeeds(:final average, :final credits) =>
                            s.targetNeeds(_credits(credits), _two(average)),
                          TargetOutOfReach(:final best) => s.targetOutOfReach(_two(best)),
                          TargetAlreadyMet() => s.targetMet,
                          TargetNoCourses() => s.targetNoCourses,
                        },
                        style: theme.bodyMedium,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (courses.isEmpty)
          Text(s.noGradesYet, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary))
        else
          for (final sem in semesters) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(child: Text(sem, style: theme.titleSmall)),
                  if (semesterGpa(courses, sem) case final g?)
                    Text('GPA ${_two(g)}', style: theme.labelLarge?.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
            for (final c in bySemester[sem]!)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(color: Color(c.color), borderRadius: BorderRadius.circular(2)),
                ),
                title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(s.creditsCount(_credits(c.credits))),
                trailing: Text(
                  gradeName(c.grade, s),
                  style: theme.titleSmall?.copyWith(
                    color: c.grade == null ? AppColors.textTertiary : AppColors.textPrimary,
                  ),
                ),
                onTap: () => showCourseSheet(context, semester: c.semester, existing: c),
              ),
          ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final double? progress;

  const _Stat({required this.label, required this.value, this.note, this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.labelMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: theme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (note != null) Text(note!, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Asked once, inline rather than in a dialog: how many credits to graduate,
// and which pass mark applies
class _DegreeSetup extends ConsumerStatefulWidget {
  final GradeSettings settings;
  final AppStrings s;

  const _DegreeSetup({required this.settings, required this.s});

  @override
  ConsumerState<_DegreeSetup> createState() => _DegreeSetupState();
}

class _DegreeSetupState extends ConsumerState<_DegreeSetup> {
  late final _credits = TextEditingController(text: '${widget.settings.graduationCredits}');
  late DegreeLevel _level = widget.settings.level;

  @override
  void dispose() {
    _credits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Material(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _credits,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              decoration: InputDecoration(labelText: s.graduationCredits),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(s.degreeLevel, style: Theme.of(context).textTheme.labelLarge),
            RadioGroup<DegreeLevel>(
              groupValue: _level,
              onChanged: (v) => setState(() => _level = v ?? _level),
              child: Column(
                children: [
                  RadioListTile(dense: true, value: DegreeLevel.bachelor, title: Text(s.degreeBachelor)),
                  RadioListTile(dense: true, value: DegreeLevel.graduate, title: Text(s.degreeGraduate)),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: () {
                  final credits = int.tryParse(_credits.text) ?? GradeSettings.defaultCredits;
                  ref.read(gradeSettingsProvider.notifier).set(GradeSettings(
                        graduationCredits: credits.clamp(1, 400),
                        level: _level,
                      ));
                  setState(() {});
                },
                child: Text(s.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
