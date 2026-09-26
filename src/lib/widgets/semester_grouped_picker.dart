import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart' show compareSemesters;
import '../providers/settings_provider.dart' show SemesterSettings;
import '../utils/semester_helpers.dart';

// The link pickers for targets and visions: grouped by semester, oldest first,
// opening on the current semester so earlier ones are a scroll up and later
// ones a scroll down.

// One linkable row. [semester] is null for a vision with no start semester
class SemesterPickerItem {
  final String id;
  final String title;
  final String? semester;
  final String? parentId;
  final int sortOrder;

  const SemesterPickerItem({
    required this.id,
    required this.title,
    required this.semester,
    required this.parentId,
    required this.sortOrder,
  });
}

class SemesterGroup {
  // Null is the "no semester" group, which always comes last
  final String? semester;
  final List<({SemesterPickerItem item, int depth})> rows;

  const SemesterGroup(this.semester, this.rows);
}

// Within a group rows follow sortOrder, so the newest sits on top, with
// children indented under their parent. A child whose parent landed in another
// semester starts its own branch here rather than disappearing
List<SemesterGroup> groupBySemester(List<SemesterPickerItem> items) {
  final bySemester = <String?, List<SemesterPickerItem>>{};
  for (final item in items) {
    (bySemester[item.semester] ??= []).add(item);
  }
  final dated = bySemester.keys.whereType<String>().toList()..sort(compareSemesters);
  return [
    for (final semester in [...dated, if (bySemester.containsKey(null)) null])
      SemesterGroup(semester, _asTree(bySemester[semester]!)),
  ];
}

List<({SemesterPickerItem item, int depth})> _asTree(List<SemesterPickerItem> group) {
  final ids = {for (final item in group) item.id};
  final rows = <({SemesterPickerItem item, int depth})>[];

  void add(Iterable<SemesterPickerItem> level, int depth) {
    final sorted = level.toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final item in sorted) {
      rows.add((item: item, depth: depth));
      add(group.where((child) => child.parentId == item.id), depth + 1);
    }
  }

  add(group.where((item) => item.parentId == null || !ids.contains(item.parentId)), 0);
  return rows;
}

// The group to open on: the current semester, else the nearest one after it,
// else the latest one there is
int startGroupIndex(List<SemesterGroup> groups, String currentSemester) {
  var lastDated = 0;
  for (var i = 0; i < groups.length; i++) {
    final semester = groups[i].semester;
    if (semester == null) continue;
    if (compareSemesters(semester, currentSemester) >= 0) return i;
    lastDated = i;
  }
  return lastDated;
}

Future<void> showSemesterGroupedPicker({
  required BuildContext context,
  required String title,
  required List<SemesterPickerItem> items,
  required String? currentId,
  required String currentSemester,
  required SemesterSettings settings,
  required AppStrings s,
  required ValueChanged<String?> onSelect,
}) {
  return showDialog(
    context: context,
    builder: (_) => _SemesterGroupedPicker(
      title: title,
      groups: groupBySemester(items),
      currentId: currentId,
      currentSemester: currentSemester,
      settings: settings,
      s: s,
      onSelect: onSelect,
    ),
  );
}

class _SemesterGroupedPicker extends StatefulWidget {
  final String title;
  final List<SemesterGroup> groups;
  final String? currentId;
  final String currentSemester;
  final SemesterSettings settings;
  final AppStrings s;
  final ValueChanged<String?> onSelect;

  const _SemesterGroupedPicker({
    required this.title,
    required this.groups,
    required this.currentId,
    required this.currentSemester,
    required this.settings,
    required this.s,
    required this.onSelect,
  });

  @override
  State<_SemesterGroupedPicker> createState() => _SemesterGroupedPickerState();
}

class _SemesterGroupedPickerState extends State<_SemesterGroupedPicker> {
  final _startKey = GlobalKey();
  late final int _startIndex = startGroupIndex(widget.groups, widget.currentSemester);
  // Index of the one group being shown; null shows every group
  int? _filter;

  @override
  void initState() {
    super.initState();
    _scrollToStart();
  }

  // After the frame, because the header has no size to scroll to before it
  void _scrollToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _startKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx);
    });
  }

  String _label(SemesterGroup group) => group.semester == null
      ? widget.s.noSemester
      : formatSemester(group.semester!, widget.settings, widget.s);

  void _select(String? id) {
    widget.onSelect(id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final groups = widget.groups;
    final visible = _filter == null ? [for (var i = 0; i < groups.length; i++) i] : [_filter!];

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        // Fixed rather than shrink-wrapped: the list must scroll for the start
        // semester to be placed at the top
        height: min(420, MediaQuery.of(context).size.height * 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(s.catAll),
                    selected: _filter == null,
                    onSelected: (_) {
                      setState(() => _filter = null);
                      _scrollToStart();
                    },
                  ),
                  for (var i = 0; i < groups.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(_label(groups[i])),
                        selected: _filter == i,
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.md),
            // A Column rather than a lazy ListView: the start header has to be
            // built for ensureVisible to find it, and these lists are short
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(s.noLink),
                      selected: widget.currentId == null,
                      selectedColor: AppColors.primary,
                      onTap: () => _select(null),
                    ),
                    for (final i in visible) ...[
                      Padding(
                        key: i == _startIndex ? _startKey : null,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          _label(groups[i]),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                      for (final row in groups[i].rows)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(
                            left: AppSpacing.md + row.depth * 20.0,
                            right: AppSpacing.md,
                          ),
                          title: Text(row.item.title),
                          selected: row.item.id == widget.currentId,
                          selectedColor: AppColors.primary,
                          onTap: () => _select(row.item.id),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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

// The multi-select twin of the picker above: same grouping, same opening
// position, but the rows are checkboxes and the dialog stays open while they
// are ticked. Used for filtering a task list by target.
class SemesterGroupedFilterDialog extends StatefulWidget {
  final String title;
  final String emptyLabel;
  final String resetLabel;
  final List<SemesterPickerItem> items;
  final Set<String> selectedIds;
  final String currentSemester;
  final SemesterSettings settings;
  final AppStrings s;
  final void Function(String id, bool selected) onToggle;
  final VoidCallback onReset;

  const SemesterGroupedFilterDialog({
    super.key,
    required this.title,
    required this.emptyLabel,
    required this.resetLabel,
    required this.items,
    required this.selectedIds,
    required this.currentSemester,
    required this.settings,
    required this.s,
    required this.onToggle,
    required this.onReset,
  });

  @override
  State<SemesterGroupedFilterDialog> createState() => _SemesterGroupedFilterDialogState();
}

class _SemesterGroupedFilterDialogState extends State<SemesterGroupedFilterDialog> {
  final _startKey = GlobalKey();
  int? _filter;

  @override
  void initState() {
    super.initState();
    _scrollToStart();
  }

  void _scrollToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _startKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx);
    });
  }

  String _label(SemesterGroup group) => group.semester == null
      ? widget.s.noSemester
      : formatSemester(group.semester!, widget.settings, widget.s);

  @override
  Widget build(BuildContext context) {
    final groups = groupBySemester(widget.items);
    final startIndex = startGroupIndex(groups, widget.currentSemester);
    final visible = _filter == null ? [for (var i = 0; i < groups.length; i++) i] : [_filter!];

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: min(420, MediaQuery.of(context).size.height * 0.6),
        child: groups.isEmpty
            ? Center(
                child: Text(widget.emptyLabel,
                    style: TextStyle(color: AppColors.textTertiary)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: Text(widget.s.catAll),
                          selected: _filter == null,
                          onSelected: (_) {
                            setState(() => _filter = null);
                            _scrollToStart();
                          },
                        ),
                        for (var i = 0; i < groups.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                            child: ChoiceChip(
                              label: Text(_label(groups[i])),
                              selected: _filter == i,
                              onSelected: (_) => setState(() => _filter = i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: AppSpacing.md),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final i in visible) ...[
                            Padding(
                              key: i == startIndex ? _startKey : null,
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.sm,
                                AppSpacing.md,
                                AppSpacing.xs,
                              ),
                              child: Text(
                                _label(groups[i]),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ),
                            for (final row in groups[i].rows)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.only(
                                  left: AppSpacing.sm + row.depth * 20.0,
                                  right: AppSpacing.md,
                                ),
                                value: widget.selectedIds.contains(row.item.id),
                                title: Text(row.item.title),
                                onChanged: (on) => widget.onToggle(row.item.id, on ?? false),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: widget.onReset, child: Text(widget.resetLabel)),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}
