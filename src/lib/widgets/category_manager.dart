import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../providers/categories_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/category_helpers.dart';

// One row in a category management list: swatch+icon, label, then (for
// custom categories) delete, then color picker, icon picker, and finally a
// single-line drag handle for reordering. Shared by the in-context dialog on
// the Future page and the full Category Settings screen.
Widget categoryManageTile({
  required BuildContext context,
  required WidgetRef ref,
  required CategoryEntry entry,
  required AppStrings s,
  bool selected = false,
  VoidCallback? onTap,
}) {
  final isBuiltIn = ref.read(categoriesProvider.notifier).isBuiltIn(entry.id);

  return ListTile(
    key: ValueKey(entry.id),
    leading: Icon(entry.icon, color: entry.color),
    title: Text(catLabel(entry.id, s)),
    selected: selected,
    selectedColor: AppColors.primary,
    onTap: onTap,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isBuiltIn)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(categoriesProvider.notifier).remove(entry.id),
          ),
        GestureDetector(
          onTap: () => _pickColor(context, ref, entry),
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.color,
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
        IconButton(
          icon: Icon(entry.icon, size: 18, color: AppColors.textSecondary),
          tooltip: s.pickIcon,
          visualDensity: VisualDensity.compact,
          onPressed: () => _pickIcon(context, ref, entry),
        ),
        const Icon(Icons.horizontal_rule, color: AppColors.textTertiary),
      ],
    ),
  );
}

Future<void> _pickColor(BuildContext context, WidgetRef ref, CategoryEntry entry) async {
  final s = ref.read(stringsProvider);
  final picked = await showDialog<Color>(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.pickColor),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final c in categoryColorPresets)
              GestureDetector(
                onTap: () => Navigator.pop(dlgCtx, c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    border: Border.all(
                      color: c.toARGB32() == entry.color.toARGB32()
                          ? AppColors.textPrimary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlgCtx),
          child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
        ),
      ],
    ),
  );
  if (picked != null) {
    ref.read(categoriesProvider.notifier).updateStyle(entry.id, color: picked);
  }
}

Future<void> _pickIcon(BuildContext context, WidgetRef ref, CategoryEntry entry) async {
  final s = ref.read(stringsProvider);
  final picked = await showDialog<IconData>(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.pickIcon),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final icon in categoryIconPresets)
              GestureDetector(
                onTap: () => Navigator.pop(dlgCtx, icon),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: icon == entry.icon
                        ? entry.color.withValues(alpha: 0.2)
                        : AppColors.surfaceVariant,
                    border: Border.all(
                      color: icon == entry.icon
                          ? entry.color
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, size: 18, color: entry.color),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlgCtx),
          child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
        ),
      ],
    ),
  );
  if (picked != null) {
    ref.read(categoriesProvider.notifier).updateStyle(entry.id, icon: picked);
  }
}

// Text field + add button row for creating a new custom category.
class CategoryAddRow extends StatefulWidget {
  const CategoryAddRow({super.key});

  @override
  State<CategoryAddRow> createState() => _CategoryAddRowState();
}

class _CategoryAddRowState extends State<CategoryAddRow> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(stringsProvider);
        void submit() {
          final name = _ctrl.text.trim();
          if (name.isEmpty) return;
          ref.read(categoriesProvider.notifier).add(name);
          _ctrl.clear();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(hintText: s.categoryName),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => submit(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                onPressed: submit,
              ),
            ],
          ),
        );
      },
    );
  }
}
