import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester_goal.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';

class SemesterScreen extends ConsumerWidget {
  const SemesterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final goals = ref.watch(semesterGoalsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.semester,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                FilledButton.icon(
                  onPressed: () => _showAddGoalSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(s.addGoal),
                ),
              ],
            ),
          ),
          Expanded(
            child: goals.isEmpty
                ? Center(
                    child: Text(s.noGoals,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).disabledColor,
                        )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: goals.length,
                    itemBuilder: (ctx, i) => _GoalCard(goal: goals[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final SemesterGoal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final notifier = ref.read(semesterGoalsProvider.notifier);
    final total = goal.milestones.length;
    final done = goal.completedCount;
    final progress = total > 0 ? done / total : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        title: Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(s.goalProgress(done, total),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => notifier.removeGoal(goal.id),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (goal.milestones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                s.milestones,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
          for (final m in goal.milestones)
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              value: m.isDone,
              onChanged: (_) => notifier.toggleMilestone(goal.id, m.id),
              title: Text(
                m.title,
                style: TextStyle(
                  decoration: m.isDone ? TextDecoration.lineThrough : null,
                  color: m.isDone ? Theme.of(context).disabledColor : null,
                ),
              ),
              secondary: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => notifier.removeMilestone(goal.id, m.id),
              ),
            ),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.add,
                size: 20, color: Theme.of(context).colorScheme.primary),
            title: Text(s.addMilestone,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14)),
            onTap: () => _showAddMilestoneDialog(context, ref, goal.id),
          ),
        ],
      ),
    );
  }
}

void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
  final ctrl = TextEditingController();
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.addGoal, style: Theme.of(sheetCtx).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.titleField),
            onSubmitted: (_) {
              if (ctrl.text.trim().isEmpty) return;
              ref.read(semesterGoalsProvider.notifier).addGoal(ctrl.text.trim());
              Navigator.pop(sheetCtx);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                ref.read(semesterGoalsProvider.notifier).addGoal(ctrl.text.trim());
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

void _showAddMilestoneDialog(BuildContext context, WidgetRef ref, String goalId) {
  final ctrl = TextEditingController();
  final s = ref.read(stringsProvider);

  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.addMilestone),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: s.titleField),
        onSubmitted: (_) {
          if (ctrl.text.trim().isEmpty) return;
          ref.read(semesterGoalsProvider.notifier).addMilestone(goalId, ctrl.text.trim());
          Navigator.pop(dlgCtx);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlgCtx),
          child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (ctrl.text.trim().isEmpty) return;
            ref.read(semesterGoalsProvider.notifier).addMilestone(goalId, ctrl.text.trim());
            Navigator.pop(dlgCtx);
          },
          child: Text(s.add),
        ),
      ],
    ),
  );
}
