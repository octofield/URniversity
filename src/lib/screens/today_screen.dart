import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/task.dart';
import '../models/inspiration.dart';
import '../providers/tasks_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/concentration_provider.dart';
import '../providers/date_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/future_goals_provider.dart';
import 'settings_screen.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final selectedDate = ref.watch(dateProvider);
    final dateFormat = ref.watch(settingsProvider);
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.pageTop,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(dateProvider.notifier).prev(),
                ),
                Text(
                  formatDate(selectedDate, dateFormat),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(dateProvider.notifier).next(),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      ref.read(dateProvider.notifier).setDate(picked);
                    }
                  },
                ),
                if (!isToday)
                  TextButton(
                    onPressed: () => ref.read(dateProvider.notifier).goToToday(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                    child: Text(s.backToToday),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const _SummaryCard(),
            const SizedBox(height: AppSpacing.lg),
            const _TasksSection(),
            const SizedBox(height: AppSpacing.lg),
            const _InspirationsSection(),
            const SizedBox(height: AppSpacing.lg),
            const _ConcentrationSection(),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksProvider);
    final completed = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;
    final allDone = total > 0 && completed == total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone ? Icons.check_circle : Icons.check_circle_outline,
                color: allDone ? AppColors.primary : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                s.tasksCompleted(completed, total),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: completed / total,
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

class _TasksSection extends ConsumerWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final tasks = ref.watch(tasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.tasks, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: tasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 20,
                  ),
                  child: Text(
                    s.noTasks,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final task in tasks) ...[
                      _TaskTile(task: task),
                      const Divider(height: 1, indent: 56),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final targets = ref.watch(semesterGoalsProvider);
    final goals = ref.watch(futureGoalsProvider);

    final linkedTarget = task.linkedTargetId != null
        ? targets.where((g) => g.id == task.linkedTargetId).firstOrNull
        : null;
    final linkedGoal = task.linkedGoalId != null
        ? goals.where((g) => g.id == task.linkedGoalId).firstOrNull
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (_) => ref.read(tasksProvider.notifier).toggle(task.id),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted ? AppColors.textTertiary : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.content != null)
            Text(task.content!, style: Theme.of(context).textTheme.bodySmall),
          if (task.dueTime != null)
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: _dueColor(task.dueTime!)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _formatDueTime(task.dueTime!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _dueColor(task.dueTime!),
                  ),
                ),
                if (task.recurrence != null && !task.recurrence!.isNone) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.repeat, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    _recurrenceShort(task.recurrence!, s),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            )
          else if (task.recurrence != null && !task.recurrence!.isNone)
            Row(
              children: [
                Icon(Icons.repeat, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  _recurrenceShort(task.recurrence!, s),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          if (linkedTarget != null)
            Text(
              '→ ${linkedTarget.title}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (linkedGoal != null)
            Text(
              '⭐ ${linkedGoal.title}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.priority > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              decoration: BoxDecoration(
                color: task.priority == 3 ? AppColors.errorLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                task.priority == 3 ? s.priorityHigh : s.priorityMed,
                style: TextStyle(
                  fontSize: 11,
                  color: task.priority == 3 ? AppColors.error : AppColors.warning,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(tasksProvider.notifier).remove(task.id),
          ),
        ],
      ),
      onTap: () => _showEditTaskSheet(context, ref, task),
    );
  }
}

class _InspirationsSection extends ConsumerWidget {
  const _InspirationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final inspirations = ref.watch(inspirationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.inspirations, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              for (final inspiration in inspirations) ...[
                _InspirationCard(inspiration: inspiration),
                const Divider(height: 1, indent: AppSpacing.md),
              ],
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                leading: const Icon(Icons.add, color: AppColors.primary),
                title: Text(
                  s.addInspiration,
                  style: const TextStyle(color: AppColors.primary),
                ),
                onTap: () => _showAddInspirationSheet(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InspirationCard extends ConsumerWidget {
  final Inspiration inspiration;
  const _InspirationCard({required this.inspiration});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      title: Text(inspiration.title),
      subtitle: inspiration.content != null ? Text(inspiration.content!) : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () =>
            ref.read(inspirationsProvider.notifier).remove(inspiration.id),
      ),
    );
  }
}

class _ConcentrationSection extends ConsumerWidget {
  const _ConcentrationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final state = ref.watch(concentrationProvider);
    final notifier = ref.read(concentrationProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.concentration, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 32,
                color: state.isRunning ? AppColors.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.concentrationToday(
                          _formatDuration(state.totalToday + state.elapsed)),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (state.isRunning)
                      Text(
                        s.concentrationSession(_formatDuration(state.elapsed)),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: state.isRunning ? notifier.stop : notifier.start,
                child: Text(state.isRunning ? s.stop : s.start),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Date+time picker (clock style) ──────────────────────────────────────────

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
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// ─── Recurrence helpers ───────────────────────────────────────────────────────

String _recurrenceLabel(RecurrenceType type, AppStrings s) {
  switch (type) {
    case RecurrenceType.none:       return s.repeatNone;
    case RecurrenceType.daily:      return s.repeatDaily;
    case RecurrenceType.weekly:     return s.repeatWeekly;
    case RecurrenceType.monthly:    return s.repeatMonthly;
    case RecurrenceType.everyNDays: return s.repeatEveryNDays;
  }
}

String _recurrenceShort(RecurrenceRule rule, AppStrings s) {
  switch (rule.type) {
    case RecurrenceType.none:       return '';
    case RecurrenceType.daily:      return s.repeatDaily;
    case RecurrenceType.weekly:     return s.repeatWeekly;
    case RecurrenceType.monthly:    return s.repeatMonthly;
    case RecurrenceType.everyNDays: return '${rule.interval}${s.repeatInterval}';
  }
}

Future<RecurrenceRule?> _showRecurrencePicker(
  BuildContext context, AppStrings s, RecurrenceRule? current) async {
  var type = current?.type ?? RecurrenceType.none;
  var interval = current?.interval ?? 2;
  final intervalCtrl = TextEditingController(text: '$interval');

  return showDialog<RecurrenceRule>(
    context: context,
    builder: (dlgCtx) => StatefulBuilder(
      builder: (dlgCtx, setState) => AlertDialog(
        title: Text(s.repeat),
        content: Column(
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
            if (type == RecurrenceType.everyNDays)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: intervalCtrl,
                  decoration: InputDecoration(labelText: s.repeatInterval),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => interval = int.tryParse(v) ?? interval,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dlgCtx,
              RecurrenceRule(type: type, interval: interval),
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
  BuildContext context, WidgetRef ref, AppStrings s,
  String? currentId, ValueChanged<String?> onSelect,
) {
  final targets = ref.read(semesterGoalsProvider);
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectTarget),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(s.noLink),
              selected: currentId == null,
              selectedColor: AppColors.primary,
              onTap: () { onSelect(null); Navigator.pop(dlgCtx); },
            ),
            for (final g in targets)
              ListTile(
                title: Text(g.title),
                subtitle: Text(g.semester),
                selected: g.id == currentId,
                selectedColor: AppColors.primary,
                onTap: () { onSelect(g.id); Navigator.pop(dlgCtx); },
              ),
          ],
        ),
      ),
      actions: [TextButton(
        onPressed: () => Navigator.pop(dlgCtx),
        child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
      )],
    ),
  );
}

void _showGoalSelectorForTask(
  BuildContext context, WidgetRef ref, AppStrings s,
  String? currentId, ValueChanged<String?> onSelect,
) {
  final goals = ref.read(futureGoalsProvider);
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectFutureGoal),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(s.noLink),
              selected: currentId == null,
              selectedColor: AppColors.primary,
              onTap: () { onSelect(null); Navigator.pop(dlgCtx); },
            ),
            for (final g in goals)
              ListTile(
                title: Text(g.title),
                selected: g.id == currentId,
                selectedColor: AppColors.primary,
                onTap: () { onSelect(g.id); Navigator.pop(dlgCtx); },
              ),
          ],
        ),
      ),
      actions: [TextButton(
        onPressed: () => Navigator.pop(dlgCtx),
        child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
      )],
    ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: active ? AppColors.primary : AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClear != null && active)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16,
                  color: AppColors.textTertiary),
            ),
        ],
      ),
    ),
  );
}

// ─── Add task sheet ───────────────────────────────────────────────────────────

// Public so HomeScreen FAB can call it
void showAddTaskSheet(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      var priority = 1;
      DateTime? dueTime;
      RecurrenceRule? recurrence;
      String? linkedTargetId;
      String? linkedGoalId;

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

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(s.addTask,
                      style: Theme.of(sheetCtx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: s.titleField),
                    onSubmitted: (_) => _submitTask(sheetCtx, ref,
                        titleController, contentController, priority,
                        dueTime, recurrence, linkedTargetId, linkedGoalId),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: s.taskNotes,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _linkRow(
                    icon: Icons.calendar_today_outlined,
                    label: dueTime != null
                        ? _formatDueTime(dueTime!)
                        : s.dueTime,
                    active: dueTime != null,
                    onTap: () async {
                      final result = await _showDateTimePicker(
                          sheetCtx, dueTime ?? DateTime.now());
                      if (result != null) setState(() => dueTime = result);
                    },
                    onClear: () => setState(() => dueTime = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.repeat,
                    label: (recurrence == null || recurrence!.isNone)
                        ? s.repeatNone
                        : _recurrenceShort(recurrence!, s),
                    active: recurrence != null && !recurrence!.isNone,
                    onTap: () async {
                      final result =
                          await _showRecurrencePicker(sheetCtx, s, recurrence);
                      if (result != null) setState(() => recurrence = result);
                    },
                    onClear: () => setState(
                        () => recurrence = const RecurrenceRule(
                            type: RecurrenceType.none)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.flag_outlined,
                    label: linkedTarget != null
                        ? '${linkedTarget.title} · ${linkedTarget.semester}'
                        : s.linkedTarget,
                    active: linkedTarget != null,
                    onTap: () => _showTargetSelector(
                        sheetCtx, ref, s, linkedTargetId,
                        (id) => setState(() => linkedTargetId = id)),
                    onClear: () => setState(() => linkedTargetId = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.stars_outlined,
                    label: linkedGoal != null
                        ? linkedGoal.title
                        : s.linkedGoal,
                    active: linkedGoal != null,
                    onTap: () => _showGoalSelectorForTask(
                        sheetCtx, ref, s, linkedGoalId,
                        (id) => setState(() => linkedGoalId = id)),
                    onClear: () => setState(() => linkedGoalId = null),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(s.priority,
                          style: Theme.of(sheetCtx).textTheme.bodyMedium),
                      const SizedBox(width: 12),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 1, label: Text(s.priorityLow)),
                          ButtonSegment(value: 2, label: Text(s.priorityMed)),
                          ButtonSegment(value: 3, label: Text(s.priorityHigh)),
                        ],
                        selected: {priority},
                        onSelectionChanged: (v) =>
                            setState(() => priority = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _submitTask(sheetCtx, ref,
                          titleController, contentController, priority,
                          dueTime, recurrence, linkedTargetId, linkedGoalId),
                      child: Text(s.add),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showEditTaskSheet(BuildContext context, WidgetRef ref, Task task) {
  final titleController = TextEditingController(text: task.title);
  final contentController = TextEditingController(text: task.content ?? '');
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      var priority = task.priority;
      DateTime? dueTime = task.dueTime;
      RecurrenceRule? recurrence = task.recurrence;
      String? linkedTargetId = task.linkedTargetId;
      String? linkedGoalId = task.linkedGoalId;

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

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(s.editTask,
                      style: Theme.of(sheetCtx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: s.titleField),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: s.taskNotes,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _linkRow(
                    icon: Icons.calendar_today_outlined,
                    label: dueTime != null
                        ? _formatDueTime(dueTime!)
                        : s.dueTime,
                    active: dueTime != null,
                    onTap: () async {
                      final result = await _showDateTimePicker(
                          sheetCtx, dueTime ?? DateTime.now());
                      if (result != null) setState(() => dueTime = result);
                    },
                    onClear: () => setState(() => dueTime = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.repeat,
                    label: (recurrence == null || recurrence!.isNone)
                        ? s.repeatNone
                        : _recurrenceShort(recurrence!, s),
                    active: recurrence != null && !recurrence!.isNone,
                    onTap: () async {
                      final result =
                          await _showRecurrencePicker(sheetCtx, s, recurrence);
                      if (result != null) setState(() => recurrence = result);
                    },
                    onClear: () => setState(
                        () => recurrence = const RecurrenceRule(
                            type: RecurrenceType.none)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.flag_outlined,
                    label: linkedTarget != null
                        ? '${linkedTarget.title} · ${linkedTarget.semester}'
                        : s.linkedTarget,
                    active: linkedTarget != null,
                    onTap: () => _showTargetSelector(
                        sheetCtx, ref, s, linkedTargetId,
                        (id) => setState(() => linkedTargetId = id)),
                    onClear: () => setState(() => linkedTargetId = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.stars_outlined,
                    label: linkedGoal != null
                        ? linkedGoal.title
                        : s.linkedGoal,
                    active: linkedGoal != null,
                    onTap: () => _showGoalSelectorForTask(
                        sheetCtx, ref, s, linkedGoalId,
                        (id) => setState(() => linkedGoalId = id)),
                    onClear: () => setState(() => linkedGoalId = null),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(s.priority,
                          style: Theme.of(sheetCtx).textTheme.bodyMedium),
                      const SizedBox(width: 12),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 1, label: Text(s.priorityLow)),
                          ButtonSegment(value: 2, label: Text(s.priorityMed)),
                          ButtonSegment(value: 3, label: Text(s.priorityHigh)),
                        ],
                        selected: {priority},
                        onSelectionChanged: (v) =>
                            setState(() => priority = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;
                        ref.read(tasksProvider.notifier).update(Task(
                          id: task.id,
                          title: title,
                          content: contentController.text.trim().isEmpty
                              ? null
                              : contentController.text.trim(),
                          priority: priority,
                          dueTime: dueTime,
                          isCompleted: task.isCompleted,
                          createdAt: task.createdAt,
                          recurrence: recurrence,
                          linkedTargetId: linkedTargetId,
                          linkedGoalId: linkedGoalId,
                        ));
                        Navigator.pop(sheetCtx);
                      },
                      child: Text(s.save),
                    ),
                  ),
                ],
              ),
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
  String? linkedGoalId,
) {
  final title = titleCtrl.text.trim();
  if (title.isEmpty) return;
  ref.read(tasksProvider.notifier).add(
    title,
    content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
    priority: priority,
    dueTime: dueTime,
    recurrence: recurrence,
    linkedTargetId: linkedTargetId,
    linkedGoalId: linkedGoalId,
  );
  Navigator.pop(context);
}

void _showAddInspirationSheet(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.pageHorizontal,
        right: AppSpacing.pageHorizontal,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(s.addInspiration,
              style: Theme.of(sheetCtx).textTheme.titleLarge),
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
                ref.read(inspirationsProvider.notifier).add(
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

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '${h}h ${m}m' : '$m:$s';
}
