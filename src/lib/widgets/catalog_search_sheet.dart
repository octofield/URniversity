import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input_limits.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../core/ui_symbols.dart';
import '../providers/course_catalog_provider.dart';
import '../providers/courses_provider.dart';
import '../providers/settings_provider.dart';
import 'sheet_body.dart';

// "Search NTHU courses" (UC18): one school's catalog. Type a title, teacher,
// course code or serial number, tap a result, and the course is on the
// timetable with all its meetings. A clash is pointed out but does not stop
// anyone
void showCatalogSearch(BuildContext context, {required CatalogSchool school, required String semester}) {
  showAppSheet(
    context,
    // Transparent Material: the result ListTiles need one for their ink
    builder: (_) => SheetBody(
      child: Material(type: MaterialType.transparency, child: _CatalogSearch(school: school, semester: semester)),
    ),
  );
}

class _CatalogSearch extends ConsumerStatefulWidget {
  final CatalogSchool school;
  final String semester;
  const _CatalogSearch({required this.school, required this.semester});

  @override
  ConsumerState<_CatalogSearch> createState() => _CatalogSearchState();
}

class _CatalogSearchState extends ConsumerState<_CatalogSearch> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _settled = '';

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
    ref.read(coursesProvider.notifier).add(
          semester: widget.semester,
          title: c.title,
          teacher: c.teacher,
          courseCode: c.courseCode,
          serialNo: c.serialNo,
          credits: c.credits ?? 0,
          catalogId: c.id,
          sessions: c.sessions,
        );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.courseAdded(c.title))));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final courses = ref.watch(coursesProvider).where((c) => c.semester == widget.semester).toList();
    final taken = {for (final c in courses) if (c.catalogId != null) c.catalogId};

    Widget body;
    if (_settled.length < 2) {
      body = _Hint(s.catalogTypeMore);
    } else {
      final results = ref.watch(
          catalogSearchProvider((school: widget.school.code, semester: widget.semester, query: _settled)));
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
                      final clash = clashingCourses(c.sessions, courses);
                      final added = taken.contains(c.id);
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
                            if (clash.isNotEmpty)
                              Text(
                                s.clashesWith(clash.map((x) => x.title).join('、')),
                                style: theme.bodySmall?.copyWith(color: AppColors.error),
                              ),
                          ],
                        ),
                        trailing: added
                            ? Text(s.catalogAdded, style: theme.labelMedium?.copyWith(color: AppColors.textTertiary))
                            : IconButton(
                                icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
                                tooltip: s.addCourse,
                                onPressed: () => _add(c),
                              ),
                        onTap: added ? null : () => _add(c),
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
        Text(s.searchSchoolCourses(widget.school.shortName), style: theme.titleLarge),
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
