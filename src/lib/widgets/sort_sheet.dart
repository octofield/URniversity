import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../providers/sort_prefs.dart';
import 'sheet_body.dart';

// Which order a list is in, plus the way into rearranging it by hand. A sheet
// rather than a popup menu: the same control has to be reachable on a phone
// held one-handed. Shared by the tasks, targets and visions pages.
//
// "Rearrange" switches the list to the manual order first, because the drag
// handles write that order and it has to be the one on screen
void showSortSheet<E extends Enum>(
  BuildContext context, {
  required AppStrings s,
  required Map<E, String> labels,
  required StateNotifierProvider<EnumPrefNotifier<E>, E> sortProvider,
  required StateProvider<bool> sortModeProvider,
  required E manual,
}) {
  showAppSheet(
    context,
    builder: (sheetCtx) => Consumer(
      builder: (_, sheetRef, _) {
        final current = sheetRef.watch(sortProvider);
        return SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.sortBy, style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              // The sheet's own background is a DecoratedBox, so the tiles need
              // a Material of their own to paint their ink on
              Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in labels.entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        trailing: entry.key == current
                            ? Icon(Icons.check, color: AppColors.primary)
                            : null,
                        selected: entry.key == current,
                        selectedColor: AppColors.primary,
                        onTap: () {
                          sheetRef.read(sortProvider.notifier).set(entry.key);
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.drag_handle),
                      title: Text(s.sortRearrange),
                      onTap: () {
                        sheetRef.read(sortProvider.notifier).set(manual);
                        sheetRef.read(sortModeProvider.notifier).state = true;
                        Navigator.pop(sheetCtx);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// The header button that opens the sheet, or ends rearranging while the drag
// handles are showing. Tinted when the list is in anything but its manual order
class SortButton extends StatelessWidget {
  final AppStrings s;
  final bool isManual;
  final bool sortMode;
  final VoidCallback onOpen;
  final VoidCallback onDone;

  const SortButton({
    super.key,
    required this.s,
    required this.isManual,
    required this.sortMode,
    required this.onOpen,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    if (sortMode) {
      return TextButton(onPressed: onDone, child: Text(s.done));
    }
    return IconButton(
      icon: Icon(
        Icons.arrow_downward,
        color: isManual ? AppColors.textTertiary : AppColors.primary,
        size: 20,
      ),
      tooltip: s.sortBy,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onPressed: onOpen,
    );
  }
}

// The handle each row shows while rearranging. Dragging it starts at once —
// no long press — while the rest of the row still scrolls the list
class DragHandle<T extends Object> extends StatelessWidget {
  final T data;
  final Widget feedback;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const DragHandle({
    super.key,
    required this.data,
    required this.feedback,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<T>(
      data: data,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.md),
        child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
      ),
    );
  }
}
