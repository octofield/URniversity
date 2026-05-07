import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/trash_item.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/trash_provider.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final items = ref.watch(trashProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.trash),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmEmptyTrash(context, ref, s),
              child: Text(s.emptyTrash,
                  style: const TextStyle(color: AppColors.error)),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Text(s.noTrash,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textTertiary,
                  )),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
                vertical: AppSpacing.md,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _TrashTile(item: items[i]),
            ),
    );
  }

  void _confirmEmptyTrash(BuildContext context, WidgetRef ref, dynamic s) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(s.emptyTrash),
        content: const Text('所有項目將被永久刪除，無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              ref.read(trashProvider.notifier).clear();
              Navigator.pop(dlgCtx);
            },
            child: Text(s.emptyTrash,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _TrashTile extends ConsumerWidget {
  final TrashItem item;
  const _TrashTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final icon = switch (item.type) {
      TrashItemType.task => Icons.check_box_outline_blank,
      TrashItemType.semesterGoal => Icons.school_outlined,
      TrashItemType.futureGoal => Icons.flag_outlined,
    };

    final mm = item.deletedAt.month.toString().padLeft(2, '0');
    final dd = item.deletedAt.day.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(item.title),
        subtitle: Text('$mm/$dd 刪除',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            )),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore, color: AppColors.primary),
              tooltip: s.restore,
              onPressed: () {
                final popped = ref.read(trashProvider.notifier).pop(item.id);
                if (popped == null) return;
                switch (popped.type) {
                  case TrashItemType.task:
                    ref.read(tasksProvider.notifier).restore(popped.task!);
                  case TrashItemType.semesterGoal:
                    ref.read(semesterGoalsProvider.notifier).restore(popped.semesterGoal!);
                  case TrashItemType.futureGoal:
                    ref.read(futureGoalsProvider.notifier).restore(popped.futureGoal!);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppColors.error),
              tooltip: '永久刪除',
              onPressed: () =>
                  ref.read(trashProvider.notifier).permanentDelete(item.id),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      ),
    );
  }
}
