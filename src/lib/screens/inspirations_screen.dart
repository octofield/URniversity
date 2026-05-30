import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/inspiration.dart';
import '../providers/inspirations_provider.dart';
import '../providers/settings_provider.dart';
class InspirationsScreen extends ConsumerWidget {
  const InspirationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final all = ref.watch(inspirationsProvider);
    final active = all.where((i) => !i.isCompleted).toList();
    final done = all.where((i) => i.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.allInspirations)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, AppSpacing.md,
          AppSpacing.pageHorizontal, AppSpacing.xl,
        ),
        children: [
          if (active.isNotEmpty) ...[
            Text(s.pending, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            ...active.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InspirationCard(item: item),
            )),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (done.isNotEmpty) ...[
            Text(s.completed, style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textTertiary,
            )),
            const SizedBox(height: AppSpacing.sm),
            ...done.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _InspirationCard(item: item),
            )),
          ],
          if (all.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(s.noInspirations, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _InspirationCard extends ConsumerWidget {
  final Inspiration item;
  const _InspirationCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.isCompleted,
            activeColor: AppColors.primary,
            onChanged: (_) => ref.read(inspirationsProvider.notifier).toggleCompleted(item.id),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _showEditSheet(context, ref, item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                        color: item.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                      ),
                    ),
                    if (item.content != null)
                      Text(
                        item.content!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              if (await _confirmDelete(context, s)) {
                ref.read(inspirationsProvider.notifier).remove(item.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, dynamic s) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text('${s.delete}？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(s.delete),
            ),
          ],
        ),
      ) ??
      false;
}

void _showEditSheet(BuildContext context, WidgetRef ref, Inspiration item) {
  final titleCtrl = TextEditingController(text: item.title);
  final contentCtrl = TextEditingController(text: item.content ?? '');
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(s.inspirations, style: Theme.of(sheetCtx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: titleCtrl, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: s.titleField)),
            const SizedBox(height: 12),
            TextField(controller: contentCtrl, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: s.inspirationDetails)),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  ref.read(inspirationsProvider.notifier).update(item.copyWith(title: title, content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim()));
                  Navigator.pop(sheetCtx);
                },
                child: Text(s.save),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
