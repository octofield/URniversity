import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/credit_categories.dart';
import '../core/input_limits.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../core/ui_symbols.dart';
import '../models/course.dart';
import '../providers/course_catalog_provider.dart';
import '../providers/courses_provider.dart';
import '../providers/grade_settings_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import 'course_sheet.dart';
import 'sheet_body.dart';

// "Add course" (UC18): the user's own school's catalog first, the others with
// a catalog this semester one chip away, and adding by hand at the bottom.
// Type a title, teacher, course code or serial number, tap a result, and the
// course is on the timetable with all its meetings. A clash is pointed out but
// does not stop anyone; an added course can be removed again from here.
// [schools] come ordered, the user's own first
void showCatalogSearch(BuildContext context, {required List<CatalogSchool> schools, required String semester}) {
  showAppSheet(
    context,
    // Transparent Material: the result ListTiles need one for their ink
    builder: (_) => SheetBody(
      child: Material(type: MaterialType.transparency, child: _CatalogSearch(schools: schools, semester: semester)),
    ),
  );
}

class _CatalogSearch extends ConsumerStatefulWidget {
  final List<CatalogSchool> schools;
  final String semester;
  const _CatalogSearch({required this.schools, required this.semester});

  @override
  ConsumerState<_CatalogSearch> createState() => _CatalogSearchState();
}

class _CatalogSearchState extends ConsumerState<_CatalogSearch> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _settled = '';
  late CatalogSchool _school = widget.schools.first;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  // One query per pause in typing, not per keystroke
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _settled = text.trim());
    });
  }

  void _add(CatalogCourse c) {
    final s = ref.read(stringsProvider);
    // Filed as it is added, only when the user has credits by category on
    final settings = ref.read(gradeSettingsProvider);
    final category = settings.categoriesEnabled
        ? classifyCourse(kind: c.kind, requiredFor: c.requiredFor, catalogDepartment: settings.catalogDepartment).name
        : null;
    ref.read(coursesProvider.notifier).add(
          semester: widget.semester,
          title: c.title,
          teacher: c.teacher,
          courseCode: c.courseCode,
          serialNo: c.serialNo,
          credits: c.credits ?? 0,
          catalogId: c.id,
          category: category,
          sessions: c.sessions,
        );
    // Replacing, not queueing: adding then removing at once would otherwise
    // hold the undo back behind "Added" for four seconds
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.courseAdded(c.title))));
  }

  // Into the trash with its meetings, as deleting from the timetable does.
  // No undo in a snack bar: that shows on the page behind this sheet, under
  // its barrier, out of reach. The row turns back into "add" instead
  void _remove(Course added) {
    final removed = ref.read(coursesProvider.notifier).remove(added.id);
    if (removed != null) ref.read(trashProvider.notifier).addCourse(removed);
  }

  // The sheet's own context is gone once it closes; the navigator's stays
  void _manual() {
    final navigator = Navigator.of(context);
    navigator.pop();
    showCourseSheet(navigator.context, semester: widget.semester);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final courses = ref.watch(coursesProvider).where((c) => c.semester == widget.semester).toList();
    final byCatalogId = {for (final c in courses) if (c.catalogId != null) c.catalogId!: c};

    Widget body;
    if (_settled.length < 2) {
      body = _Hint(s.catalogTypeMore);
    } else {
      final results = ref.watch(
          catalogSearchProvider((school: _school.code, semester: widget.semester, query: _settled)));
      body = results.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _Hint(s.catalogUnavailable),
        data: (list) => list.isEmpty
            ? _Hint(s.catalogEmpty)
            : Column(
                children: [
                  for (final c in list)
                    () {
                      final added = byCatalogId[c.id];
                      // Never against itself: once added, the course is one
                      // of [courses] and would otherwise clash with its own
                      // meetings
                      final clash = added != null
                          ? const <Course>[]
                          : clashingCourses(c.sessions, courses);
                      final meta = [
                        if (c.timeText != null && c.timeText!.isNotEmpty) c.timeText!,
                        if (c.credits != null) s.creditsCount(_credits(c.credits!)),
                        if (c.teacher != null && c.teacher!.isNotEmpty) c.teacher!,
                        if (c.serialNo != null && c.serialNo!.isNotEmpty) c.serialNo!,
                      ].join(kDotSeparator);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(meta, style: theme.bodySmall),
                            if (added != null)
                              Text(s.catalogAdded, style: theme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                            if (clash.isNotEmpty)
                              Text(
                                s.clashesWith(clash.map((x) => x.title).join('、')),
                                style: theme.bodySmall?.copyWith(color: AppColors.error),
                              ),
                          ],
                        ),
                        trailing: added != null
                            ? TextButton(onPressed: () => _remove(added), child: Text(s.catalogRemove))
                            : IconButton(
                                icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
                                tooltip: s.addCourse,
                                onPressed: () => _add(c),
                              ),
                        onTap: added != null ? null : () => _add(c),
                      );
                    }(),
                ],
              ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.searchSchoolCourses(_school.shortName), style: theme.titleLarge),
        if (widget.schools.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final school in widget.schools)
                ChoiceChip(
                  label: Text(school.shortName),
                  tooltip: school.name,
                  selected: school.code == _school.code,
                  onSelected: (_) => setState(() => _school = school),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _query,
          autofocus: true,
          maxLength: InputLimits.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: s.searchCourseHint,
            prefixIcon: const Icon(Icons.search),
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        body,
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _manual,
            icon: const Icon(Icons.edit_outlined),
            label: Text(s.addManually),
          ),
        ),
      ],
    );
  }

  static String _credits(double c) => c == c.roundToDouble() ? c.toInt().toString() : c.toString();
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
}
