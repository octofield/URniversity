import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../utils/category_helpers.dart';

// The fields the four add/edit sheets are built from (task, target, vision,
// inspiration).
//
// Text fields use Material's floating label; the pickers and the category chips
// come from the 2026-09-18 design canvas. Having them all here is the point:
// a new kind of field is added once and every sheet gets it.

// Box padding and border, shared so the fields line up with each other
const EdgeInsets _boxPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);

BoxDecoration _boxDecoration({bool focused = false}) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: focused ? AppColors.borderFocus : AppColors.border),
    );

Widget _boxLabel(BuildContext context, String label) => Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
    );

// A plain text field, so every sheet spells its fields the same way
class SheetTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool autofocus;
  final int minLines;
  final int maxLines;
  final VoidCallback? onSubmitted;

  const SheetTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    // Material's floating label, not a label printed above the box: the
    // printed-label version shipped on 2026-09-20 and was asked back the next
    // day. The widget stays, so the four sheets keep one field to call
    return TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // A multi-line field sits a little lower than the title field
        isDense: maxLines > 1,
        contentPadding: maxLines > 1
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.inputPadding,
                vertical: AppSpacing.sm,
              )
            : null,
      ),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    );
  }
}

// The same box, but the value is picked from a dialog rather than typed
class SheetPickerBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const SheetPickerBox({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: _boxPadding,
        decoration: _boxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _boxLabel(context, label),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.expand_more, size: 18, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Category chips carrying their own colour, so the list reads the same way the
// cards do. Multi-select: picking none is allowed and means no category
class SheetCategoryChips extends StatelessWidget {
  final List<CategoryEntry> categories;
  final Set<String> selected;
  final AppStrings s;
  final void Function(String id) onToggle;

  const SheetCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.s,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final cat in categories)
          _CategoryChip(
            label: catLabel(cat.id, s),
            color: resolveCatColor(categories, cat.id),
            selected: selected.contains(cat.id),
            onTap: () => onToggle(cat.id),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
