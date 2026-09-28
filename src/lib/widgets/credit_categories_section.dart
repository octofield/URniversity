import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/credit_categories.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/course.dart';
import '../providers/course_catalog_provider.dart';
import '../providers/courses_provider.dart';
import '../providers/grade_settings_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/synced_list_notifier.dart' show reportSyncErrorFromWidget;

String _credits(double c) => c == c.roundToDouble() ? c.toInt().toString() : c.toStringAsFixed(1);

// Files [courses] that have no category yet: by their catalog row where they
// came from one, as an elective otherwise
Future<void> fileCourses(WidgetRef ref, List<Course> courses) async {
  final settings = ref.read(gradeSettingsProvider);
  final ids = [for (final c in courses) if (c.catalogId != null) c.catalogId!];
  var rows = const <CatalogCourse>[];
  try {
    rows = await ref.read(catalogSourceProvider).byIds(ids);
  } catch (e) {
    reportSyncErrorFromWidget(ref, e, where: 'course_catalog read');
  }
  final byId = {for (final r in rows) r.id: r};
  final notifier = ref.read(coursesProvider.notifier);
  for (final c in courses) {
    final row = byId[c.catalogId];
    final category = classifyCourse(
      kind: row?.kind,
      requiredFor: row?.requiredFor ?? const [],
      catalogDepartment: settings.catalogDepartment,
    );
    notifier.update(c.copyWith(category: category.name));
  }
}

String categoryName(CreditCategory? category, AppStrings s) => switch (category) {
      CreditCategory.required => s.categoryRequired,
      CreditCategory.elective => s.categoryElective,
      CreditCategory.general => s.categoryGeneral,
      CreditCategory.excluded => s.categoryExcluded,
      null => s.categoryUnfiled,
    };

// Credits by category on the grades page (UC20, system_design.md §3-T). Off by
// default and marked as a beta: the numbers are the school's published ones,
// which may not be the rules a given student is held to
class CreditCategoriesSection extends ConsumerWidget {
  const CreditCategoriesSection({super.key});

  // Switching on fills in what can be guessed, so the first look shows numbers
  void _enable(WidgetRef ref, bool on, CatalogSchool? school) {
    final settings = ref.read(gradeSettingsProvider);
    final profile = ref.read(profileProvider);
    ref.read(gradeSettingsProvider.notifier).set(settings.copyWith(
          categoriesEnabled: on,
          entryYear: () => settings.entryYear ?? entryYearFrom(profile?.grade, profile?.gradeSetYear),
          requirementDepartment: () => settings.requirementDepartment ?? profile?.department,
          catalogDepartment: () =>
              settings.catalogDepartment ?? guessCatalogDepartment(profile?.department, school?.audiences ?? const []),
        ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final settings = ref.watch(gradeSettingsProvider);
    final profile = ref.watch(profileProvider);
    final school = (ref.watch(catalogSchoolsProvider).valueOrNull ?? const <CatalogSchool>[])
        .where((x) => x.name == profile?.school)
        .firstOrNull;

    final toggle = SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: settings.categoriesEnabled,
      onChanged: (on) => _enable(ref, on, school),
      title: Row(
        children: [
          Flexible(child: Text(s.creditCategories, style: theme.titleMedium)),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(s.creditCategoriesBeta, style: theme.labelSmall?.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      subtitle: Text(s.creditCategoriesHint, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
    );
    if (!settings.categoriesEnabled) return toggle;

    // The school's published numbers for this entry year and department, when
    // it publishes any; otherwise the user's own
    final requirements = school == null || settings.entryYear == null
        ? const <DegreeRequirement>[]
        : ref.watch(degreeRequirementsProvider((school: school.code, entryYear: settings.entryYear!))).valueOrNull ??
            const <DegreeRequirement>[];
    final requirement =
        requirements.where((r) => r.department == settings.requirementDepartment).firstOrNull;
    final needRequired = requirement?.required ?? settings.requiredCredits;
    final needGeneral = requirement?.general ?? settings.generalCredits;
    final needElective = requirement?.elective ?? settings.electiveCredits;
    final needTotal = requirement?.total ?? settings.graduationCredits;

    final courses = ref.watch(coursesProvider);
    final earned = creditsByCategory(courses, settings.level);
    final counted = (earned[CreditCategory.required] ?? 0) +
        (earned[CreditCategory.general] ?? 0) +
        (earned[CreditCategory.elective] ?? 0) +
        (earned[null] ?? 0);
    final unfiled = courses.where((c) => c.category == null).toList();
    final nowYear = academicYear(ref.watch(effectiveNowProvider), ref.watch(semesterSettingsProvider)) - 1911;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toggle,
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Bar(label: s.categoryRequired, earned: earned[CreditCategory.required] ?? 0, need: needRequired, s: s),
              _Bar(label: s.categoryGeneral, earned: earned[CreditCategory.general] ?? 0, need: needGeneral, s: s),
              _Bar(label: s.categoryElective, earned: earned[CreditCategory.elective] ?? 0, need: needElective, s: s),
              const Divider(),
              _Bar(label: s.creditsTotal, earned: counted, need: needTotal, s: s),
              if (unfiled.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(s.unfiledCourses(unfiled.length),
                          style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ),
                    TextButton(onPressed: () => fileCourses(ref, unfiled), child: Text(s.fileAutomatically)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Where the numbers come from: entry year, department, and the
        // department's name in the catalog
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Picker<int>(
              label: s.entryYear,
              value: settings.entryYear,
              options: [for (var y = nowYear; y > nowYear - 7; y--) y],
              text: (y) => '$y',
              onChanged: (y) => ref.read(gradeSettingsProvider.notifier).set(settings.copyWith(entryYear: () => y)),
            ),
            if (requirements.isNotEmpty)
              _Picker<String>(
                label: s.requirementDepartment,
                value: requirement?.department,
                options: [for (final r in requirements) r.department],
                text: (d) => d,
                onChanged: (d) =>
                    ref.read(gradeSettingsProvider.notifier).set(settings.copyWith(requirementDepartment: () => d)),
              ),
            if (school != null && school.audiences.isNotEmpty)
              _Picker<String>(
                label: s.catalogDepartment,
                hint: s.catalogDepartmentHint,
                value: school.audiences.contains(settings.catalogDepartment) ? settings.catalogDepartment : null,
                options: school.audiences,
                text: (d) => d,
                onChanged: (d) =>
                    ref.read(gradeSettingsProvider.notifier).set(settings.copyWith(catalogDepartment: () => d)),
              ),
          ],
        ),
        if (requirement != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(s.requirementsFrom(settings.entryYear!, requirement.department),
                style: theme.bodySmall?.copyWith(color: AppColors.textTertiary)),
          )
        else
          _ManualThresholds(settings: settings, s: s),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double earned;
  final int? need;
  final AppStrings s;

  const _Bar({required this.label, required this.earned, required this.need, required this.s});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.labelLarge)),
              Text(
                need == null ? _credits(earned) : s.creditsOf(_credits(earned), need!),
                style: theme.labelLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if (need != null && need! > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: (earned / need!).clamp(0.0, 1.0),
                minHeight: 6,
                color: earned >= need! ? AppColors.success : AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final T? value;
  final List<T> options;
  final String Function(T) text;
  final ValueChanged<T> onChanged;

  const _Picker({
    required this.label,
    this.hint,
    required this.value,
    required this.options,
    required this.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: DropdownButtonFormField<T>(
          initialValue: options.contains(value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, helperText: hint, isDense: true),
          items: [
            for (final o in options) DropdownMenuItem(value: o, child: Text(text(o), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
}

// The three numbers by hand, for a department whose school publishes none
class _ManualThresholds extends ConsumerStatefulWidget {
  final GradeSettings settings;
  final AppStrings s;

  const _ManualThresholds({required this.settings, required this.s});

  @override
  ConsumerState<_ManualThresholds> createState() => _ManualThresholdsState();
}

class _ManualThresholdsState extends ConsumerState<_ManualThresholds> {
  late final _required = TextEditingController(text: widget.settings.requiredCredits?.toString() ?? '');
  late final _general = TextEditingController(text: widget.settings.generalCredits?.toString() ?? '');
  late final _elective = TextEditingController(text: widget.settings.electiveCredits?.toString() ?? '');

  @override
  void dispose() {
    _required.dispose();
    _general.dispose();
    _elective.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController controller) => Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          decoration: InputDecoration(labelText: label, isDense: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    int? read(TextEditingController c) => int.tryParse(c.text)?.clamp(0, 400);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.requirementsManual, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _field(s.categoryRequired, _required),
              const SizedBox(width: AppSpacing.sm),
              _field(s.categoryGeneral, _general),
              const SizedBox(width: AppSpacing.sm),
              _field(s.categoryElective, _elective),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => ref.read(gradeSettingsProvider.notifier).set(ref.read(gradeSettingsProvider).copyWith(
                      requiredCredits: () => read(_required),
                      generalCredits: () => read(_general),
                      electiveCredits: () => read(_elective),
                    )),
                child: Text(s.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
