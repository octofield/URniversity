import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input_limits.dart';
import '../core/period_tables.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/course.dart';
import '../providers/courses_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart' show categoryColorPresets;
import 'confirm_dialog.dart';
import 'grade_chips.dart';
import 'sheet_body.dart';
import 'sheet_fields.dart';

String formatMinute(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

// Adding a course by hand, or editing one (system_design.md UC18). A tap on an
// empty cell of the grid opens it with that day and hour already filled in
void showCourseSheet(
  BuildContext context, {
  required String semester,
  Course? existing,
  int? weekday,
  int? startMinute,
}) {
  showAppSheet(
    context,
    // The sheet's state lives in _CourseForm's State, not in this builder,
    // which reruns on every keyboard change (CLAUDE.md §9 rule 3)
    builder: (_) => SheetBody(
      // The grade switch is a ListTile, which needs a Material under it
      child: Material(
        type: MaterialType.transparency,
        child: _CourseForm(
          semester: semester,
          existing: existing,
          weekday: weekday,
          startMinute: startMinute,
        ),
      ),
    ),
  );
}

class _MeetingDraft {
  int weekday;
  int start;
  int end;
  final TextEditingController room;

  _MeetingDraft(this.weekday, this.start, this.end, String? location)
      : room = TextEditingController(text: location ?? '');

  CourseSession toSession() {
    final text = room.text.trim();
    return CourseSession(
      weekday: weekday,
      startMinute: start,
      endMinute: end,
      location: text.isEmpty ? null : text,
    );
  }
}

class _CourseForm extends ConsumerStatefulWidget {
  final String semester;
  final Course? existing;
  final int? weekday;
  final int? startMinute;

  const _CourseForm({required this.semester, this.existing, this.weekday, this.startMinute});

  @override
  ConsumerState<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends ConsumerState<_CourseForm> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _teacher = TextEditingController(text: widget.existing?.teacher ?? '');
  late final _credits = TextEditingController(
    text: widget.existing == null ? '' : _creditsText(widget.existing!.credits),
  );
  late int _color = widget.existing?.color ?? ref.read(coursesProvider.notifier).nextColor(widget.semester);
  late String? _grade = widget.existing?.grade;
  late bool _countsInGpa = widget.existing?.countsInGpa ?? true;
  late final List<_MeetingDraft> _meetings = widget.existing != null
      ? [
          for (final m in widget.existing!.sessions)
            _MeetingDraft(m.weekday, m.startMinute, m.endMinute, m.location),
        ]
      : [_defaultMeeting(widget.weekday ?? DateTime.monday, widget.startMinute)];
  bool _showErrors = false;

  static String _creditsText(double c) => c == c.roundToDouble() ? c.toInt().toString() : c.toString();

  List<ClassPeriod>? get _periods => periodsFor(ref.read(profileProvider)?.school);

  // A new meeting: the period starting at the tapped hour at NTU, otherwise
  // that hour to the next
  _MeetingDraft _defaultMeeting(int weekday, int? start) {
    final periods = _periods;
    if (periods != null) {
      final p = start == null
          ? periods[1]
          : periods.firstWhere((p) => p.start >= start, orElse: () => periods.last);
      return _MeetingDraft(weekday, p.start, p.end, null);
    }
    final s = start ?? 9 * 60;
    return _MeetingDraft(weekday, s, s + 50, null);
  }

  @override
  void dispose() {
    _title.dispose();
    _teacher.dispose();
    _credits.dispose();
    for (final m in _meetings) {
      m.room.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && _meetings.every((m) => m.end > m.start);

  void _save() {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    final notifier = ref.read(coursesProvider.notifier);
    final credits = double.tryParse(_credits.text.trim()) ?? 0;
    final teacher = _teacher.text.trim();
    final sessions = [for (final m in _meetings) m.toSession()];
    final existing = widget.existing;
    if (existing == null) {
      notifier.add(
        semester: widget.semester,
        title: _title.text.trim(),
        teacher: teacher.isEmpty ? null : teacher,
        credits: credits,
        color: _color,
        sessions: sessions,
      );
    } else {
      notifier.update(existing.copyWith(
        title: _title.text.trim(),
        teacher: () => teacher.isEmpty ? null : teacher,
        credits: credits,
        color: _color,
        sessions: sessions,
        grade: () => _grade,
        countsInGpa: _countsInGpa,
      ));
    }
    Navigator.pop(context);
  }

  Future<void> _delete(AppStrings s) async {
    if (!await confirmDelete(context, s)) return;
    final removed = ref.read(coursesProvider.notifier).remove(widget.existing!.id);
    if (removed != null) ref.read(trashProvider.notifier).addCourse(removed);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final isEdit = widget.existing != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(isEdit ? s.editCourse : s.addCourse, style: theme.titleLarge)),
            if (isEdit)
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: s.delete,
                onPressed: () => _delete(s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SheetTextField(
          label: s.courseTitle,
          controller: _title,
          maxLength: InputLimits.title,
          autofocus: !isEdit,
        ),
        if (_showErrors && _title.text.trim().isEmpty)
          Text(s.courseTitleRequired, style: theme.bodySmall?.copyWith(color: AppColors.error)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SheetTextField(label: s.courseTeacher, controller: _teacher, maxLength: InputLimits.teacher),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _credits,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d?)?')),
                ],
                decoration: InputDecoration(labelText: s.courseCredits, counterText: ''),
                maxLength: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(s.courseMeetings, style: theme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < _meetings.length; i++)
          _MeetingRow(
            key: ObjectKey(_meetings[i]),
            draft: _meetings[i],
            periods: _periods,
            s: s,
            invalid: _showErrors && _meetings[i].end <= _meetings[i].start,
            onChanged: () => setState(() {}),
            onRemove: _meetings.length == 1
                ? null
                : () => setState(() => _meetings.removeAt(i).room.dispose()),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(s.addMeeting),
            onPressed: () => setState(() {
              final last = _meetings.lastOrNull;
              _meetings.add(_defaultMeeting(
                last == null ? DateTime.monday : (last.weekday % 7) + 1,
                last?.start,
              ));
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(s.courseColor, style: theme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final c in categoryColorPresets.take(16))
              GestureDetector(
                onTap: () => setState(() => _color = c.toARGB32()),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == c.toARGB32() ? AppColors.textPrimary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Grades only mean something once the course exists (Phase 6)
        if (isEdit) ...[
          const SizedBox(height: AppSpacing.md),
          GradeChips(
            grade: _grade,
            countsInGpa: _countsInGpa,
            onGrade: (g) => setState(() => _grade = g),
            onCountsInGpa: (v) => setState(() => _countsInGpa = v),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _save, child: Text(isEdit ? s.save : s.addCourse)),
        ),
      ],
    );
  }
}

class _MeetingRow extends StatelessWidget {
  final _MeetingDraft draft;
  final List<ClassPeriod>? periods;
  final AppStrings s;
  final bool invalid;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _MeetingRow({
    super.key,
    required this.draft,
    required this.periods,
    required this.s,
    required this.invalid,
    required this.onChanged,
    required this.onRemove,
  });

  Future<void> _pickTime(BuildContext context, {required bool start}) async {
    final m = start ? draft.start : draft.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    if (start) {
      // Keeps the length when the start moves, so one change is usually enough
      final length = draft.end - draft.start;
      draft.start = value;
      draft.end = (value + (length > 0 ? length : 50)).clamp(value + 5, 24 * 60);
    } else {
      draft.end = value;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final periods = this.periods;

    Widget timeBox(String label, int minute, VoidCallback onTap) => SheetPickerBox(
          label: label,
          value: formatMinute(minute),
          onTap: onTap,
        );

    Widget periodBox(String label, bool start) {
      final current = periods!.where((p) => start ? p.start == draft.start : p.end == draft.end).firstOrNull;
      return InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ClassPeriod>(
            isDense: true,
            isExpanded: true,
            value: current,
            hint: Text(formatMinute(start ? draft.start : draft.end)),
            items: [
              for (final p in periods)
                DropdownMenuItem(value: p, child: Text('${p.label}｜${formatMinute(start ? p.start : p.end)}')),
            ],
            onChanged: (p) {
              if (p == null) return;
              if (start) {
                draft.start = p.start;
                if (draft.end <= draft.start) draft.end = p.end;
              } else {
                draft.end = p.end;
              }
              onChanged();
            },
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: invalid ? AppColors.error : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        ChoiceChip(
                          label: Text(s.weekdayShort(d)),
                          selected: draft.weekday == d,
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                          onSelected: (_) {
                            draft.weekday = d;
                            onChanged();
                          },
                        ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: periods != null
                      ? periodBox(s.meetingStart, true)
                      : timeBox(s.meetingStart, draft.start, () => _pickTime(context, start: true)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: periods != null
                      ? periodBox(s.meetingEnd, false)
                      : timeBox(s.meetingEnd, draft.end, () => _pickTime(context, start: false)),
                ),
              ],
            ),
            if (invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(s.meetingInvalid, style: theme.bodySmall?.copyWith(color: AppColors.error)),
              ),
            const SizedBox(height: AppSpacing.sm),
            SheetTextField(label: s.meetingRoom, controller: draft.room, maxLength: InputLimits.location),
          ],
        ),
      ),
    );
  }
}
