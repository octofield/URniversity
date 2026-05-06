import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/inspiration.dart';
import '../providers/tasks_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/concentration_provider.dart';
import '../providers/date_provider.dart';
import '../providers/settings_provider.dart';
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
        padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(s.backToToday),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const _SummaryCard(),
            const SizedBox(height: 24),
            const _TasksSection(),
            const SizedBox(height: 24),
            const _InspirationsSection(),
            const SizedBox(height: 24),
            const _ConcentrationSection(),
            const SizedBox(height: 32),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allDone ? Icons.check_circle : Icons.check_circle_outline,
                  color: allDone ? Theme.of(context).colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(
                  s.tasksCompleted(completed, total),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: completed / total),
            ],
          ],
        ),
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
        const SizedBox(height: 8),
        Card(
          child: tasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Text(
                    s.noTasks,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).disabledColor,
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (_) => ref.read(tasksProvider.notifier).toggle(task.id),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          color: task.isCompleted ? Theme.of(context).disabledColor : null,
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
                const SizedBox(width: 4),
                Text(
                  _formatDueTime(task.dueTime!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _dueColor(task.dueTime!),
                  ),
                ),
              ],
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.priority > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: task.priority == 3 ? Colors.red[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                task.priority == 3 ? s.priorityHigh : s.priorityMed,
                style: TextStyle(
                  fontSize: 11,
                  color: task.priority == 3 ? Colors.red[700] : Colors.orange[700],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => ref.read(tasksProvider.notifier).remove(task.id),
          ),
        ],
      ),
    );
  }
}

class _InspirationsSection extends ConsumerWidget {
  const _InspirationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final inspirations = ref.watch(inspirationsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context)
        .colorScheme
        .secondaryContainer
        .withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.inspirations, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          color: cardColor,
          child: Column(
            children: [
              for (final inspiration in inspirations) ...[
                _InspirationCard(inspiration: inspiration),
                const Divider(height: 1, indent: 16),
              ],
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(Icons.add, color: primary),
                title: Text(s.addInspiration, style: TextStyle(color: primary)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 32,
                  color: state.isRunning
                      ? Theme.of(context).colorScheme.primary
                      : null,
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
                          s.concentrationSession(
                              _formatDuration(state.elapsed)),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
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
        ),
      ],
    );
  }
}

// Public so HomeScreen FAB can call it
void showAddTaskSheet(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      var priority = 1;
      DateTime? dueTime;

      return StatefulBuilder(
        builder: (sheetContext, setState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.addTask,
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s.titleField),
                onSubmitted: (_) => _submitTask(sheetContext, ref,
                    titleController, contentController, priority, dueTime),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s.taskNotes),
              ),
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final result = await showDialog<DateTime>(
                    context: sheetContext,
                    builder: (_) => _DateTimePickerDialog(
                      initial: dueTime ?? DateTime.now(),
                    ),
                  );
                  if (result != null) setState(() => dueTime = result);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: dueTime != null
                            ? Theme.of(sheetContext).colorScheme.primary
                            : Theme.of(sheetContext).disabledColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dueTime != null ? _formatDueTime(dueTime!) : s.dueTime,
                        style: TextStyle(
                          color: dueTime != null
                              ? Theme.of(sheetContext).colorScheme.primary
                              : null,
                        ),
                      ),
                      const Spacer(),
                      if (dueTime != null)
                        GestureDetector(
                          onTap: () => setState(() => dueTime = null),
                          child: Icon(Icons.close,
                              size: 18,
                              color: Theme.of(sheetContext).disabledColor),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(s.priority,
                      style: Theme.of(sheetContext).textTheme.bodyMedium),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _submitTask(sheetContext, ref,
                      titleController, contentController, priority, dueTime),
                  child: Text(s.add),
                ),
              ),
            ],
          ),
        ),
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
    DateTime? dueTime) {
  final title = titleCtrl.text.trim();
  if (title.isEmpty) return;
  ref.read(tasksProvider.notifier).add(
    title,
    content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
    priority: priority,
    dueTime: dueTime,
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
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.addInspiration,
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
                Navigator.pop(sheetContext);
              },
              child: Text(s.add),
            ),
          ),
        ],
      ),
    ),
  );
}

// Combined date + time picker dialog
class _DateTimePickerDialog extends StatefulWidget {
  final DateTime initial;
  const _DateTimePickerDialog({required this.initial});

  @override
  State<_DateTimePickerDialog> createState() => _DateTimePickerDialogState();
}

class _DateTimePickerDialogState extends State<_DateTimePickerDialog> {
  late DateTime _date;
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _date = widget.initial;
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CalendarDatePicker(
            initialDate: _date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (d) => setState(() => _date = d),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeWheel(
                  controller: _hourCtrl,
                  count: 24,
                  onChanged: (v) => _hour = v,
                ),
                const Text(
                  ' : ',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                _TimeWheel(
                  controller: _minuteCtrl,
                  count: 60,
                  onChanged: (v) => _minute = v,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancelButtonLabel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  DateTime(_date.year, _date.month, _date.day, _hour, _minute),
                ),
                child: Text(loc.okButtonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int count;
  final void Function(int) onChanged;

  const _TimeWheel({
    required this.controller,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 120,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40,
        perspective: 0.003,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (ctx, i) => Center(
            child: Text(
              i.toString().padLeft(2, '0'),
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
          ),
          childCount: count,
        ),
      ),
    );
  }
}

Color? _dueColor(DateTime dueTime) {
  final now = DateTime.now();
  if (dueTime.isBefore(now)) return Colors.red[600];
  if (dueTime.difference(now).inHours < 24) return Colors.orange[700];
  return null;
}

String _formatDueTime(DateTime dt) {
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final hasTime = !(dt.hour == 0 && dt.minute == 0);
  if (hasTime) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }
  return '$mm/$dd';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '${h}h ${m}m' : '$m:$s';
}
