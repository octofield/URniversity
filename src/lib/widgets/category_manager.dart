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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
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
            const SizedBox(height: AppSpacing.md),
            _HexColorField(
              initial: entry.color,
              onSubmit: (c) => Navigator.pop(dlgCtx, c),
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
      // Height-capped and scrollable: the preset list is long enough to
      // overflow a plain Wrap
      content: SizedBox(
        width: 280,
        height: 320,
        child: SingleChildScrollView(
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

// Hex entry for colors outside the preset swatches. Storage already accepts any
// 32-bit color (CategoryEntry stores color.toARGB32()), so this is UI-only
class _HexColorField extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onSubmit;
  const _HexColorField({required this.initial, required this.onSubmit});

  @override
  State<_HexColorField> createState() => _HexColorFieldState();
}

class _HexColorFieldState extends State<_HexColorField> {
  late final TextEditingController _ctrl = TextEditingController(
    text: '#${(widget.initial.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Accepts "#RRGGBB" or "RRGGBB"; alpha is always forced opaque
  Color? _parse(String raw) {
    final hex = raw.trim().replaceFirst('#', '');
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  void _submit() {
    final parsed = _parse(_ctrl.text);
    if (parsed == null) {
      setState(() => _error = 'RRGGBB');
      return;
    }
    widget.onSubmit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: 'Hex',
              hintText: '#RRGGBB',
              isDense: true,
              errorText: _error,
            ),
            autocorrect: false,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, color: AppColors.primary),
          onPressed: _submit,
        ),
      ],
    );
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

        // Pinned to the bottom of the screen, so it needs the system nav bar
        // inset or the add button sits under it
        return SafeArea(
          top: false,
          child: Padding(
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
          ),
        );
      },
    );
  }
}
