import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/period_tables.dart';
import '../core/review_stats.dart' show termAt;
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../l10n/app_strings.dart';
import '../providers/course_catalog_provider.dart';
import '../providers/courses_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/semester_helpers.dart';
import '../widgets/catalog_search_sheet.dart';
import '../widgets/course_sheet.dart';
import '../widgets/grades_view.dart';
import '../widgets/responsive_body.dart';
import '../widgets/sheet_body.dart';
import '../widgets/timetable_grid.dart';

// The timetable and the grades (UC18, UC20). One screen with two views,
// because a grade is entered on the course it belongs to
class TimetableScreen extends ConsumerStatefulWidget {
  // Opens on the grades view instead of the week
  final bool grades;
  const TimetableScreen({super.key, this.grades = false});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  late bool _grades = widget.grades;
  // The semester the week shows; starts on the one running today
  late String _semester = termAt(ref.read(effectiveNowProvider), ref.read(semesterSettingsProvider));

  List<String> get _semesters {
    // Regular terms only (no breaks), newest last, and always the one showing
    final all = generateSemesters(ref.read(semesterSettingsProvider))
        .where((t) => RegExp(r'^\d+-\d+$').hasMatch(t))
        .toList();
    if (!all.contains(_semester)) all.add(_semester);
    return all;
  }

  void _step(int delta) {
    final list = _semesters;
    final i = list.indexOf(_semester) + delta;
    if (i < 0 || i >= list.length) return;
    setState(() => _semester = list[i]);
  }

  Future<void> _editTerm(AppStrings s) async {
    final terms = ref.read(termsProvider);
    final settings = ref.read(semesterSettingsProvider);
    final current = terms[_semester];
    final initial = current?.firstDay ?? suggestedFirstDay(semesterStart(_semester, settings));
    final result = await showDialog<TermInfo>(
      context: context,
      builder: (_) => _TermDialog(initial: initial, weeks: current?.weeks ?? TermInfo.defaultWeeks, s: s),
    );
    if (result != null) await ref.read(termsProvider.notifier).set(_semester, result);
  }

  void _add(AppStrings s) {
    final mySchool = ref.read(profileProvider)?.school;
    showAppSheet(
      context,
      builder: (sheetCtx) => SheetBody(
        // ListTiles draw their ink on the nearest Material, which the sheet's
        // own coloured box would otherwise hide
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // One search per school with a catalog for this semester, the
              // user's own first. Offered to everyone: a cross-registered
              // course is still in the other school's catalog. Unreachable
              // (offline) leaves adding by hand, which always works
              Consumer(builder: (_, ref, _) {
                final schools = ref.watch(catalogSchoolsProvider);
                if (schools.isLoading) return const LinearProgressIndicator();
                final here = [
                  for (final school in schools.valueOrNull ?? const <CatalogSchool>[])
                    if (school.semesters.contains(_semester)) school,
                ]..sort((a, b) => (b.name == mySchool ? 1 : 0) - (a.name == mySchool ? 1 : 0));
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final school in here)
                      ListTile(
                        leading: const Icon(Icons.search),
                        title: Text(s.searchSchoolCourses(school.shortName)),
                        subtitle: Text(school.name),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          showCatalogSearch(context, school: school, semester: _semester);
                        },
                      ),
                  ],
                );
              }),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(s.addManually),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showCourseSheet(context, semester: _semester);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final settings = ref.watch(semesterSettingsProvider);
    final now = ref.watch(effectiveNowProvider);
    final clock = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, clock.hour, clock.minute);
    final courses = ref.watch(coursesProvider).where((c) => c.semester == _semester).toList();
    final term = ref.watch(termsProvider)[_semester];
    final periods = periodsFor(ref.watch(profileProvider)?.school);
    final isCurrent = _semester == termAt(now, settings);

    final String? weekLabel;
    if (term == null) {
      weekLabel = null;
    } else {
      final w = weekOfTerm(today, term.firstDay);
      weekLabel = w < 1
          ? s.timetableBeforeTerm
          : w > term.weeks
              ? s.timetableAfterTerm
              : s.timetableWeek(w);
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0, AppSpacing.pageHorizontal, AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _step(-1),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  formatSemester(_semester, settings, s),
                  textAlign: TextAlign.center,
                  style: theme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _step(1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(s.timetable), icon: const Icon(Icons.calendar_view_week_outlined)),
              ButtonSegment(value: true, label: Text(s.grades), icon: const Icon(Icons.school_outlined)),
            ],
            selected: {_grades},
            onSelectionChanged: (v) => setState(() => _grades = v.first),
          ),
        ],
      ),
    );

    final week = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0, AppSpacing.pageHorizontal, 96),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ActionChip(
            avatar: Icon(term == null ? Icons.event_outlined : Icons.event_available_outlined, size: 18),
            label: Text(weekLabel ?? s.setFirstDay),
            onPressed: () => _editTerm(s),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(s.noCoursesYet, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
        TimetableGrid(
          courses: courses,
          periods: periods,
          s: s,
          now: isCurrent ? today : null,
          onTapCourse: (c) => showCourseSheet(context, semester: _semester, existing: c),
          onTapEmpty: (weekday, minute) =>
              showCourseSheet(context, semester: _semester, weekday: weekday, startMinute: minute),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(_grades ? s.grades : s.timetable)),
      floatingActionButton: _grades
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(s),
              icon: const Icon(Icons.add),
              label: Text(s.addCourse),
            ),
      body: ResponsiveBody(
        // The week needs more room than a list does
        maxWidth: 960,
        child: Column(
          children: [
            header,
            Expanded(child: _grades ? GradesView(semester: _semester) : week),
          ],
        ),
      ),
    );
  }
}

// First day of classes and how many weeks of teaching
class _TermDialog extends StatefulWidget {
  final DateTime initial;
  final int weeks;
  final AppStrings s;

  const _TermDialog({required this.initial, required this.weeks, required this.s});

  @override
  State<_TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<_TermDialog> {
  late DateTime _day = widget.initial;
  late final _weeks = TextEditingController(text: '${widget.weeks}');

  @override
  void dispose() {
    _weeks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final loc = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(s.firstDayTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.firstDayHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(loc.formatFullDate(_day)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(_day.year - 1),
                lastDate: DateTime(_day.year + 1, 12, 31),
              );
              if (picked != null) setState(() => _day = picked);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _weeks,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            decoration: InputDecoration(labelText: s.teachingWeeks),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancelButtonLabel)),
        FilledButton(
          onPressed: () {
            final weeks = (int.tryParse(_weeks.text) ?? TermInfo.defaultWeeks).clamp(1, 30);
            Navigator.pop(context, TermInfo(_day, weeks));
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}
