part of 'today_screen.dart';

// Everything the task sheet needs: the sheet itself, the pickers it opens,
// and the small formatters its rows share with the task card.

Future<DateTime?> _showDateTimePicker(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: (ctx, child) =>
        MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// ─── Recurrence helpers ───────────────────────────────────────────────────────

String _recurrenceLabel(RecurrenceType type, AppStrings s) {
  switch (type) {
    case RecurrenceType.none:
      return s.repeatNone;
    case RecurrenceType.daily:
      return s.repeatDaily;
    case RecurrenceType.weekly:
      return s.repeatWeekly;
    case RecurrenceType.monthly:
      return s.repeatMonthly;
    case RecurrenceType.everyNDays:
      return s.repeatEveryNDays;
  }
}

// createdAt is needed because weekly/monthly with nothing selected fall back to
// the task's creation date, and that fallback has to be visible to the user
String _recurrenceShort(RecurrenceRule rule, AppStrings s, DateTime createdAt) {
  switch (rule.type) {
    case RecurrenceType.none:
      return '';
    case RecurrenceType.daily:
      return s.repeatDaily;
    case RecurrenceType.weekly:
      // Falling back to the creation weekday renders exactly like an explicit
      // pick, so "每週四" means the same thing either way
      final weekdays =
          rule.weekdays.isEmpty ? [createdAt.weekday] : rule.weekdays;
      return s.repeatWeeklyOn(
          [for (final d in weekdays) s.weekdayShort(d)].join(' '));
    case RecurrenceType.monthly:
      final monthDays =
          rule.monthDays.isEmpty ? [createdAt.day] : rule.monthDays;
      return s.repeatMonthlyOn([
        for (final d in monthDays)
          d == kLastDayOfMonth ? s.repeatMonthLastDay : s.monthDayShort(d),
      ].join(' '));
    case RecurrenceType.everyNDays:
      return s.repeatEveryNDaysShort(rule.safeInterval);
  }
}

Future<RecurrenceRule?> _showRecurrencePicker(
  BuildContext context,
  AppStrings s,
  RecurrenceRule? current,
) async {
  var type = current?.type ?? RecurrenceType.none;
  var interval = current?.interval ?? 2;
  final weekdays = {...?current?.weekdays};
  final monthDays = {...?current?.monthDays};
  final intervalCtrl = TextEditingController(text: '$interval');

  return showDialog<RecurrenceRule>(
    context: context,
    builder: (dlgCtx) => StatefulBuilder(
      builder: (dlgCtx, setState) => AlertDialog(
        title: Text(s.repeat),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final t in RecurrenceType.values)
                      ChoiceChip(
                        label: Text(_recurrenceLabel(t, s)),
                        selected: type == t,
                        onSelected: (_) => setState(() => type = t),
                      ),
                  ],
                ),
                if (type == RecurrenceType.weekly)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          FilterChip(
                            label: Text(s.weekdayShort(d)),
                            selected: weekdays.contains(d),
                            onSelected: (_) => setState(() {
                              if (weekdays.contains(d)) {
                                weekdays.remove(d);
                              } else {
                                weekdays.add(d);
                              }
                            }),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ),
                if (type == RecurrenceType.monthly) ...[
                  // 31 chips would make the dialog very tall, so the day grid
                  // scrolls on its own. A nested vertical scroller needs an
                  // explicit height — the outer one passes unbounded height
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 120,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (var d = 1; d <= 31; d++)
                              FilterChip(
                                label: Text('$d'),
                                selected: monthDays.contains(d),
                                onSelected: (_) => setState(() {
                                  if (monthDays.contains(d)) {
                                    monthDays.remove(d);
                                  } else {
                                    monthDays.add(d);
                                  }
                                }),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Pinned outside the scroller so it's always reachable
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: FilterChip(
                      label: Text(s.repeatMonthLastDay),
                      selected: monthDays.contains(kLastDayOfMonth),
                      onSelected: (_) => setState(() {
                        if (monthDays.contains(kLastDayOfMonth)) {
                          monthDays.remove(kLastDayOfMonth);
                        } else {
                          monthDays.add(kLastDayOfMonth);
                        }
                      }),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                if (type == RecurrenceType.everyNDays)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: intervalCtrl,
                      decoration: InputDecoration(labelText: s.repeatInterval),
                      keyboardType: TextInputType.number,
                      // Digits only: a 0 or a negative value would break the
                      // modulo in _recurringAppliesTo
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed >= 1) interval = parsed;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dlgCtx,
              RecurrenceRule(
                type: type,
                // Re-clamped here too: the field can still be left empty or
                // mid-edit when OK is tapped
                interval: interval >= 1 ? interval : 1,
                weekdays: type == RecurrenceType.weekly ? (weekdays.toList()..sort()) : const [],
                monthDays: type == RecurrenceType.monthly ? (monthDays.toList()..sort()) : const [],
              ),
            ),
            child: Text(MaterialLocalizations.of(dlgCtx).okButtonLabel),
          ),
        ],
      ),
    ),
  );
}

// ─── Target / Goal selectors ──────────────────────────────────────────────────

void _showTargetSelector(
  BuildContext context,
  WidgetRef ref,
  AppStrings s,
  String? currentId,
  ValueChanged<String?> onSelect,
) {
  final semSettings = ref.read(semesterSettingsProvider);
  showSemesterGroupedPicker(
    context: context,
    title: s.selectTarget,
    items: [
      for (final g in ref.read(semesterGoalsProvider))
        SemesterPickerItem(
          id: g.id,
          title: g.title,
          semester: g.semester,
          parentId: g.parentId,
          sortOrder: g.sortOrder,
        ),
    ],
    currentId: currentId,
    currentSemester: currentSemester(semSettings),
    settings: semSettings,
    s: s,
    onSelect: onSelect,
  );
}

void _showGoalSelectorForTask(
  BuildContext context,
  WidgetRef ref,
  AppStrings s,
  String? currentId,
  ValueChanged<String?> onSelect,
) {
  final semSettings = ref.read(semesterSettingsProvider);
  showSemesterGroupedPicker(
    context: context,
    title: s.selectFutureGoal,
    items: [
      for (final g in ref.read(futureGoalsProvider))
        SemesterPickerItem(
          id: g.id,
          title: g.title,
          semester: g.startSemester,
          parentId: g.parentId,
          sortOrder: g.sortOrder,
        ),
    ],
    currentId: currentId,
    currentSemester: currentSemester(semSettings),
    settings: semSettings,
    s: s,
    onSelect: onSelect,
  );
}

// ─── Link row widget (due time / recurrence / links) ─────────────────────────

Widget _linkRow({
  required IconData icon,
  required String label,
  required bool active,
  required VoidCallback onTap,
  VoidCallback? onClear,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(AppRadius.md),
    onTap: onTap,
    child: Container(
      // Midpoint of the original (16/12) and the too-tight first pass (8/6)
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: active ? AppColors.primary : AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: active ? AppColors.primary : AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClear != null && active)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
            ),
        ],
      ),
    ),
  );
}

// ─── Add task sheet ───────────────────────────────────────────────────────────

// Public so HomeScreen FAB can call it
// One sheet for both modes: [existing] null means add, non-null means edit.
// Keeping them apart meant every field change had to be made twice
void showTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  Task? existing,
  String? parentTaskId,
}) {
  final isEdit = existing != null;
  // When adding, the task does not exist yet, so the weekly/monthly fallback
  // preview is relative to now — which is what its createdAt will be on submit
  final labelCreatedAt = existing?.createdAt ?? DateTime.now();
  final titleController = TextEditingController(text: existing?.title ?? '');
  final contentController = TextEditingController(text: existing?.content ?? '');
  final s = ref.read(stringsProvider);
  final semSettings = ref.read(semesterSettingsProvider);
  // Sheet state must outlive the modal route builder: Flutter re-invokes that
  // builder whenever MediaQuery changes (e.g. the keyboard hides when a picker
  // dialog opens), which would otherwise reset every field to its default
  var priority = existing?.priority ?? 1;
  DateTime? dueTime = existing?.dueTime;
  RecurrenceRule? recurrence = existing?.recurrence;
  String? linkedTargetId = existing?.linkedTargetId;
  String? linkedGoalId = existing?.linkedGoalId;

  showAppSheet(
    context,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setState) {
          final targets = ref.read(semesterGoalsProvider);
          final goals = ref.read(futureGoalsProvider);
          final linkedTarget = linkedTargetId != null
              ? targets.where((g) => g.id == linkedTargetId).firstOrNull
              : null;
          final linkedGoal = linkedGoalId != null
              ? goals.where((g) => g.id == linkedGoalId).firstOrNull
              : null;

          return SheetBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEdit ? s.editTask : s.addTask,
                    style: Theme.of(sheetCtx).textTheme.titleLarge),
                if (isEdit) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    s.createdAtValue(_formatCreatedAt(existing.createdAt)),
                    style: Theme.of(
                      sheetCtx,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: s.titleField),
                  onSubmitted: isEdit
                      ? null
                      : (_) => _submitTask(
                            sheetCtx,
                            ref,
                            titleController,
                            contentController,
                            priority,
                            dueTime,
                            recurrence,
                            linkedTargetId,
                            linkedGoalId,
                            parentTaskId: parentTaskId,
                          ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: contentController,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  // One short line at rest, a little lower than the title field
                  decoration: InputDecoration(
                    labelText: s.taskNotes,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.inputPadding,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _linkRow(
                  icon: Icons.calendar_today_outlined,
                  label: dueTime != null ? _formatDueTime(dueTime!) : s.dueTime,
                  active: dueTime != null,
                  onTap: () async {
                    final result = await _showDateTimePicker(sheetCtx, dueTime ?? DateTime.now());
                    if (result != null) setState(() => dueTime = result);
                  },
                  onClear: () => setState(() => dueTime = null),
                ),
                const SizedBox(height: 2),
                _linkRow(
                  icon: Icons.repeat,
                  label: (recurrence == null || recurrence!.isNone)
                      ? s.repeatNone
                      : _recurrenceShort(recurrence!, s, labelCreatedAt),
                  active: recurrence != null && !recurrence!.isNone,
                  onTap: () async {
                    final result = await _showRecurrencePicker(sheetCtx, s, recurrence);
                    if (result != null) setState(() => recurrence = result);
                  },
                  onClear: () =>
                      setState(() => recurrence = const RecurrenceRule(type: RecurrenceType.none)),
                ),
                const SizedBox(height: 2),
                _linkRow(
                  icon: Icons.flag_outlined,
                  label: linkedTarget != null
                      ? '${linkedTarget.title}$kDotSeparator${formatSemester(linkedTarget.semester, semSettings, s)}'
                      : s.linkedTarget,
                  active: linkedTarget != null,
                  onTap: () => _showTargetSelector(
                    sheetCtx,
                    ref,
                    s,
                    linkedTargetId,
                    (id) => setState(() => linkedTargetId = id),
                  ),
                  onClear: () => setState(() => linkedTargetId = null),
                ),
                const SizedBox(height: 2),
                _linkRow(
                  icon: Icons.stars_outlined,
                  label: linkedGoal != null ? linkedGoal.title : s.linkedGoal,
                  active: linkedGoal != null,
                  onTap: () => _showGoalSelectorForTask(
                    sheetCtx,
                    ref,
                    s,
                    linkedGoalId,
                    (id) => setState(() => linkedGoalId = id),
                  ),
                  onClear: () => setState(() => linkedGoalId = null),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(s.priority, style: Theme.of(sheetCtx).textTheme.bodyMedium),
                    const SizedBox(width: 12),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 1, label: Text(s.priorityLow)),
                        ButtonSegment(value: 2, label: Text(s.priorityMed)),
                        ButtonSegment(value: 3, label: Text(s.priorityHigh)),
                      ],
                      selected: {priority},
                      style: const ButtonStyle(
                        visualDensity: VisualDensity(horizontal: -2, vertical: -4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onSelectionChanged: (v) => setState(() => priority = v.first),
                    ),
                  ],
                ),
                // Subtasks are one level deep, so only top-level tasks offer this
                if (isEdit && existing.parentTaskId == null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
                      label: Text(s.addSubtask),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        showTaskSheet(context, ref, parentTaskId: existing.id);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (!isEdit) {
                        _submitTask(
                          sheetCtx,
                          ref,
                          titleController,
                          contentController,
                          priority,
                          dueTime,
                          recurrence,
                          linkedTargetId,
                          linkedGoalId,
                          parentTaskId: parentTaskId,
                        );
                        return;
                      }
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      // copyWith, not a hand-built Task: every field has a
                      // default, so rebuilding by hand silently resets any
                      // field the author forgets to carry over
                      ref
                          .read(tasksProvider.notifier)
                          .update(
                            existing.copyWith(
                              title: title,
                              content: contentController.text.trim().isEmpty
                                  ? null
                                  : contentController.text.trim(),
                              priority: priority,
                              dueTime: dueTime,
                              recurrence: recurrence,
                              linkedTargetId: linkedTargetId,
                              linkedGoalId: linkedGoalId,
                            ),
                          );
                      Navigator.pop(sheetCtx);
                    },
                    child: Text(isEdit ? s.save : s.add),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _submitTask(
  BuildContext context,
  WidgetRef ref,
  TextEditingController titleCtrl,
  TextEditingController contentCtrl,
  int priority,
  DateTime? dueTime,
  RecurrenceRule? recurrence,
  String? linkedTargetId,
  String? linkedGoalId, {
  String? parentTaskId,
}) {
  final title = titleCtrl.text.trim();
  if (title.isEmpty) return;
  ref
      .read(tasksProvider.notifier)
      .add(
        title,
        content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
        priority: priority,
        dueTime: dueTime,
        recurrence: recurrence,
        linkedTargetId: linkedTargetId,
        linkedGoalId: linkedGoalId,
        parentTaskId: parentTaskId,
      );
  Navigator.pop(context);
}

void showAddInspirationSheet(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final s = ref.read(stringsProvider);

  showAppSheet(
    context,
    builder: (sheetCtx) => SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.addInspiration, style: Theme.of(sheetCtx).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.titleField),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.inspirationDetails),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                ref
                    .read(inspirationsProvider.notifier)
                    .add(
                      title,
                      content: contentController.text.trim().isEmpty
                          ? null
                          : contentController.text.trim(),
                    );
                Navigator.pop(sheetCtx);
              },
              child: Text(s.add),
            ),
          ),
        ],
      ),
    ),
  );
}

Color? _dueColor(DateTime dueTime) {
  final now = DateTime.now();
  if (dueTime.isBefore(now)) return AppColors.error;
  if (dueTime.difference(now).inHours < 24) return AppColors.warning;
  return null;
}

String _formatDueTime(DateTime dt) {
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$mm/$dd $hh:$min';
}

String _formatCreatedAt(DateTime dt) {
  final yyyy = dt.year;
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$yyyy/$mm/$dd $hh:$min';
}
