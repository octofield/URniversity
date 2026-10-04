import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/review_stats.dart' show termAt;
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart' show suggestedFirstDay;
import '../l10n/app_strings.dart';
import '../providers/courses_provider.dart';
import '../providers/semester_goals_provider.dart' show generateSemesters;
import '../providers/settings_provider.dart';
import '../utils/semester_helpers.dart';

// A semester's first day of classes and teaching weeks (D30), asked for from
// the timetable and from Settings alike, so the two edit one value. Starts
// from the date in force — the user's own, else their school's
// (effectiveTermsProvider), else the first Monday of the term's starting
// month; saving makes it the user's own
Future<void> editTermStart(BuildContext context, WidgetRef ref, String semester) async {
  final s = ref.read(stringsProvider);
  final current = ref.read(effectiveTermsProvider)[semester];
  final initial = current?.firstDay ?? suggestedFirstDay(semesterStart(semester, ref.read(semesterSettingsProvider)));
  final result = await showDialog<TermInfo>(
    context: context,
    builder: (_) => _TermDialog(initial: initial, weeks: current?.weeks ?? TermInfo.defaultWeeks, s: s),
  );
  if (result != null) await ref.read(termsProvider.notifier).set(semester, result);
}

// Settings' list (2026-10-04): last, this and next term, and any other the
// user has set, oldest first. Regular terms only — a break has no classes
List<String> termsForSettings(DateTime now, SemesterSettings settings, Iterable<String> own) {
  final regular = generateSemesters(settings).where((t) => RegExp(r'^\d+-\d+$').hasMatch(t)).toList();
  final i = regular.indexOf(termAt(now, settings));
  final near = i < 0 ? <String>[] : regular.sublist((i - 1).clamp(0, regular.length), (i + 2).clamp(0, regular.length));
  final listed = {...near, ...own.where(regular.contains)};
  return regular.where(listed.contains).toList();
}

// Settings › 開學日與週次: every listed term with its first day and weeks,
// marked when the date is the school's; a tap opens the timetable's dialog
Future<void> showTermStartsDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _TermStartsDialog(),
    );

class _TermStartsDialog extends ConsumerWidget {
  const _TermStartsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(semesterSettingsProvider);
    final own = ref.watch(termsProvider);
    final terms = ref.watch(effectiveTermsProvider);
    final fmt = ref.watch(settingsProvider);
    final semesters = termsForSettings(ref.watch(effectiveNowProvider), settings, own.keys);
    return AlertDialog(
      title: Text(s.termStartsSetting),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final semester in semesters)
              ListTile(
                title: Text(formatSemester(semester, settings, s)),
                subtitle: Text(
                  switch (terms[semester]) {
                    null => s.setFirstDay,
                    final term when own[semester] == null =>
                      s.termFromSchool(s.termStartSummary(formatDate(term.firstDay, fmt, s), term.weeks)),
                    final term => s.termStartSummary(formatDate(term.firstDay, fmt, s), term.weeks),
                  },
                  style: TextStyle(color: terms[semester] == null ? AppColors.textTertiary : null),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => editTermStart(context, ref, semester),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

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
