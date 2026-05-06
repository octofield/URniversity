import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart';
import '../providers/future_goals_provider.dart';
import '../providers/settings_provider.dart';

class FutureScreen extends ConsumerStatefulWidget {
  const FutureScreen({super.key});

  @override
  ConsumerState<FutureScreen> createState() => _FutureScreenState();
}

class _FutureScreenState extends ConsumerState<FutureScreen> {
  FutureCategory? _filter; // null = show all

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final goals = ref.watch(futureGoalsProvider);
    final filtered = _filter == null
        ? goals
        : goals.where((g) => g.category == _filter).toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.future,
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
          // Category filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: s.catAll,
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final cat in FutureCategory.values)
                  _FilterChip(
                    label: _catLabel(cat, s),
                    selected: _filter == cat,
                    onTap: () => setState(() => _filter = _filter == cat ? null : cat),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(s.noGoals,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).disabledColor,
                        )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _GoalCard(goal: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final FutureGoal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final notifier = ref.read(futureGoalsProvider.notifier);
    final total = goal.subgoals.length;
    final done = goal.completedCount;
    final progress = total > 0 ? done / total : 0.0;
    final catColor = _catColor(goal.category, context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_catIcon(goal.category), color: catColor, size: 20),
        ),
        title: Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goal.startTime != null || goal.endTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  [
                    if (goal.startTime != null) goal.startTime!,
                    if (goal.startTime != null && goal.endTime != null) '→',
                    if (goal.endTime != null) goal.endTime!,
                  ].join(' '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            if (total > 0) ...[
              const SizedBox(height: 2),
              Text(s.goalProgress(done, total),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
            ],
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
          if (goal.subgoals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                s.subgoals,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
          for (final sg in goal.subgoals)
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              value: sg.isDone,
              onChanged: (_) => notifier.toggleSubgoal(goal.id, sg.id),
              title: Text(
                sg.title,
                style: TextStyle(
                  decoration: sg.isDone ? TextDecoration.lineThrough : null,
                  color: sg.isDone ? Theme.of(context).disabledColor : null,
                ),
              ),
              secondary: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => notifier.removeSubgoal(goal.id, sg.id),
              ),
            ),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.add,
                size: 20, color: Theme.of(context).colorScheme.primary),
            title: Text(s.addSubgoal,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14)),
            onTap: () => _showAddSubgoalDialog(context, ref, goal.id),
          ),
        ],
      ),
    );
  }
}

void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
  final titleCtrl = TextEditingController();
  final startCtrl = TextEditingController();
  final endCtrl = TextEditingController();
  final s = ref.read(stringsProvider);
  var selectedCategory = FutureCategory.other;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) => Padding(
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
              controller: titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.titleField),
            ),
            const SizedBox(height: 12),
            // Category selector
            Text(s.category,
                style: Theme.of(sheetCtx).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cat in FutureCategory.values)
                  ChoiceChip(
                    label: Text(_catLabel(cat, s)),
                    selected: selectedCategory == cat,
                    onSelected: (_) => setState(() => selectedCategory = cat),
                    avatar: Icon(_catIcon(cat), size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    decoration: InputDecoration(labelText: s.startTime),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    decoration: InputDecoration(labelText: s.endTime),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  ref.read(futureGoalsProvider.notifier).addGoal(
                    title: titleCtrl.text.trim(),
                    category: selectedCategory,
                    startTime: startCtrl.text.trim().isEmpty
                        ? null
                        : startCtrl.text.trim(),
                    endTime: endCtrl.text.trim().isEmpty
                        ? null
                        : endCtrl.text.trim(),
                  );
                  Navigator.pop(sheetCtx);
                },
                child: Text(s.add),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showAddSubgoalDialog(BuildContext context, WidgetRef ref, String goalId) {
  final ctrl = TextEditingController();
  final s = ref.read(stringsProvider);

  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.addSubgoal),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: s.titleField),
        onSubmitted: (_) {
          if (ctrl.text.trim().isEmpty) return;
          ref.read(futureGoalsProvider.notifier).addSubgoal(goalId, ctrl.text.trim());
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
            ref.read(futureGoalsProvider.notifier).addSubgoal(goalId, ctrl.text.trim());
            Navigator.pop(dlgCtx);
          },
          child: Text(s.add),
        ),
      ],
    ),
  );
}

String _catLabel(FutureCategory cat, AppStrings s) {
  switch (cat) {
    case FutureCategory.exchange:      return s.catExchange;
    case FutureCategory.intern:        return s.catIntern;
    case FutureCategory.competition:   return s.catCompetition;
    case FutureCategory.certification: return s.catCertification;
    case FutureCategory.performance:   return s.catPerformance;
    case FutureCategory.other:         return s.catOther;
  }
}

IconData _catIcon(FutureCategory cat) {
  switch (cat) {
    case FutureCategory.exchange:      return Icons.flight_outlined;
    case FutureCategory.intern:        return Icons.work_outline;
    case FutureCategory.competition:   return Icons.emoji_events_outlined;
    case FutureCategory.certification: return Icons.card_membership_outlined;
    case FutureCategory.performance:   return Icons.mic_outlined;
    case FutureCategory.other:         return Icons.star_outline;
  }
}

Color _catColor(FutureCategory cat, BuildContext context) {
  switch (cat) {
    case FutureCategory.exchange:      return Colors.blue;
    case FutureCategory.intern:        return Colors.teal;
    case FutureCategory.competition:   return Colors.orange;
    case FutureCategory.certification: return Colors.purple;
    case FutureCategory.performance:   return Colors.pink;
    case FutureCategory.other:         return Theme.of(context).colorScheme.primary;
  }
}
