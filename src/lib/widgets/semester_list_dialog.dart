import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../providers/settings_provider.dart' show SemesterSettings;
import '../utils/semester_helpers.dart';

// The flat "pick a semester" list, opened from the targets page, the target
// sheet and the visions page's filter.
//
// It opens on the CURRENT semester rather than at the top: the list runs from
// the first year to the last, so starting at the top meant scrolling past
// years the user has already finished before reaching the one they are in.
// Earlier semesters are still one scroll up.
class SemesterListDialog extends StatefulWidget {
  final String title;
  final List<String> semesters;
  // The one marked as chosen; null when the filter is "any semester"
  final String? selected;
  // The one to show at the top when the dialog opens
  final String openAt;
  final SemesterSettings settings;
  final AppStrings s;
  final ValueChanged<String?> onSelect;
  // When set, a first row that clears the choice (the visions page's filter)
  final String? anyLabel;

  const SemesterListDialog({
    super.key,
    required this.title,
    required this.semesters,
    required this.selected,
    required this.openAt,
    required this.settings,
    required this.s,
    required this.onSelect,
    this.anyLabel,
  });

  // Fixed row height, so the opening offset is arithmetic rather than a guess
  static const double rowHeight = 48;

  @override
  State<SemesterListDialog> createState() => _SemesterListDialogState();
}

class _SemesterListDialogState extends State<SemesterListDialog> {
  late final ScrollController _ctrl = ScrollController(
    initialScrollOffset: _openOffset(),
  );

  double _openOffset() {
    final index = widget.semesters.indexOf(widget.openAt);
    if (index < 0) return 0;
    // The "any semester" row sits above the first semester
    final rows = index + (widget.anyLabel == null ? 0 : 1);
    return rows * SemesterListDialog.rowHeight;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _row(String label, {required bool selected, required VoidCallback onTap}) =>
      ListTile(
        title: Text(label),
        selected: selected,
        selectedColor: AppColors.primary,
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        // Fixed rather than shrink-wrapped: the list has to be able to scroll
        // for the opening offset to mean anything
        height: 320,
        child: ListView.builder(
          controller: _ctrl,
          itemExtent: SemesterListDialog.rowHeight,
          itemCount: widget.semesters.length + (widget.anyLabel == null ? 0 : 1),
          itemBuilder: (_, i) {
            if (widget.anyLabel != null && i == 0) {
              return _row(
                widget.anyLabel!,
                selected: widget.selected == null,
                onTap: () {
                  widget.onSelect(null);
                  Navigator.pop(context);
                },
              );
            }
            final sem = widget.semesters[i - (widget.anyLabel == null ? 0 : 1)];
            return _row(
              formatSemester(sem, widget.settings, widget.s),
              selected: sem == widget.selected,
              onTap: () {
                widget.onSelect(sem);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
