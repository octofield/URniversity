import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/semester_goal.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../l10n/app_strings.dart';
import '../utils/category_helpers.dart';
import 'semester_goal_detail_screen.dart';
import 'settings_screen.dart';

class _SemGroup {
  final SemesterGoal parent;
  final List<SemesterGoal> children;
  const _SemGroup({required this.parent, required this.children});
}

List<_SemGroup> _buildSemGroups(
    List<SemesterGoal> topLevel, List<SemesterGoal> all) {
  return [
    for (final p in topLevel)
      _SemGroup(
        parent: p,
        children: all
            .where((g) => g.parentId == p.id)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      ),
  ];
}

class SemesterScreen extends ConsumerStatefulWidget {
  const SemesterScreen({super.key});

  @override
  ConsumerState<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends ConsumerState<SemesterScreen> {
  String? _draggingId;
  String? _hoveredId;
  bool _hoverAbove = false;
  final _rowCtxs = <String, BuildContext>{};

  Widget _endGapZone(List<_SemGroup> groups) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => _draggingId != null,
      onAcceptWithDetails: (details) {
        final lastOrder =
            groups.isNotEmpty ? groups.last.parent.sortOrder : 0;
        ref
            .read(semesterGoalsProvider.notifier)
            .reparent(details.data, null, lastOrder + 1000);
      },
      builder: (ctx, candidates, _) {
        final hovered = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: hovered ? 36 : 8,
          decoration: hovered
              ? BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                )
              : null,
        );
      },
    );
  }

  Widget _feedbackCard(SemesterGoal goal) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width:
            MediaQuery.of(context).size.width - AppSpacing.pageHorizontal * 2,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: _SemGoalCardTile(goal: goal),
      ),
    );
  }

  Widget _buildDraggableRow(
    SemesterGoal goal, {
    int depth = 0,
    String? parentId,
    List<SemesterGoal> siblings = const [],
    int siblingIndex = 0,
  }) {
    final goalId = goal.id;
    final notifier = ref.read(semesterGoalsProvider.notifier);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          _draggingId != null &&
          details.data != goalId &&
          !notifier.isAncestor(details.data, goalId),
      onMove: (details) {
        if (_draggingId == null || details.data == goalId) return;
        if (notifier.isAncestor(details.data, goalId)) return;
        final storedCtx = _rowCtxs[goalId];
        if (storedCtx == null) return;
        final box = storedCtx.findRenderObject() as RenderBox;
        final localY = box.globalToLocal(details.offset).dy;
        final above = localY < box.size.height * 0.2;
        if (_hoveredId != goalId || _hoverAbove != above) {
          setState(() {
            _hoveredId = goalId;
            _hoverAbove = above;
          });
        }
      },
      onLeave: (_) {
        if (_hoveredId == goalId) setState(() => _hoveredId = null);
      },
      onAcceptWithDetails: (details) {
        if (_hoverAbove) {
          final prevOrder =
              siblingIndex > 0 ? siblings[siblingIndex - 1].sortOrder : null;
          final nextOrder = goal.sortOrder;
          final newSortOrder = prevOrder == null
              ? nextOrder - 1000
              : ((prevOrder + nextOrder) / 2).round();
          notifier.reparent(details.data, parentId, newSortOrder);
        } else {
          final allGoals = ref.read(semesterGoalsProvider);
          final children =
              allGoals.where((g) => g.parentId == goalId).toList();
          final maxOrder = children.fold(
              0, (prev, c) => c.sortOrder > prev ? c.sortOrder : prev);
          notifier.reparent(details.data, goalId, maxOrder + 1000);
        }
        setState(() => _hoveredId = null);
      },
      builder: (ctx, candidates, _) {
        _rowCtxs[goalId] = ctx;
        final isHovered = _hoveredId == goalId && candidates.isNotEmpty;
        final showAboveLine = isHovered && _hoverAbove;
        final showChildBg = isHovered && !_hoverAbove;
        final tile = _SemGoalCardTile(goal: goal, depth: depth);
        final fading = Opacity(
            opacity: 0.3, child: _SemGoalCardTile(goal: goal, depth: depth));
        final feedback = _feedbackCard(goal);

        Widget draggable;
        if (kIsWeb) {
          draggable = Draggable<String>(
            data: goalId,
            onDragStarted: () => setState(() => _draggingId = goalId),
            onDragEnd: (_) => setState(() {
              _draggingId = null;
              _hoveredId = null;
            }),
            feedback: feedback,
            childWhenDragging: fading,
            child: tile,
          );
        } else {
          draggable = LongPressDraggable<String>(
            data: goalId,
            onDragStarted: () => setState(() => _draggingId = goalId),
            onDragEnd: (_) => setState(() {
              _draggingId = null;
              _hoveredId = null;
            }),
            feedback: feedback,
            childWhenDragging: fading,
            child: tile,
          );
        }

        return Container(
          color: showChildBg ? AppColors.primaryLight : null,
          child: Stack(
            children: [
              draggable,
              if (showAboveLine)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: AppColors.primary),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDescendantRows(
      String parentId, List<SemesterGoal> all, int depth) {
    final children = all
        .where((g) => g.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (children.isEmpty) return [];
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(
          const Divider(height: 1, thickness: 1, color: AppColors.border));
      result.add(_buildDraggableRow(children[i],
          depth: depth,
          parentId: parentId,
          siblings: children,
          siblingIndex: i));
      result.addAll(_buildDescendantRows(children[i].id, all, depth + 1));
    }
    return result;
  }

  Widget _buildGroupCard(
      _SemGroup group,
      List<SemesterGoal> allGoals,
      int groupIdx,
      List<_SemGroup> groups) {
    final parent = group.parent;
    final rootItems = groups.map((g) => g.parent).toList();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDraggableRow(parent,
              depth: 0,
              parentId: null,
              siblings: rootItems,
              siblingIndex: groupIdx),
          ..._buildDescendantRows(parent.id, allGoals, 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final selectedSem = ref.watch(selectedSemesterProvider);
    final allGoals = ref.watch(semesterGoalsProvider);
    final topLevel = allGoals
        .where((g) => g.semester == selectedSem && g.parentId == null)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final groups = _buildSemGroups(topLevel, allGoals);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.pageTop,
              AppSpacing.pageHorizontal,
              AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.appName,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const _SemesterPicker(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Text(s.noTargets,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textTertiary,
                        )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        0,
                        AppSpacing.pageHorizontal,
                        80),
                    itemCount: groups.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == groups.length) return _endGapZone(groups);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildGroupCard(groups[i], allGoals, i, groups),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SemesterPicker extends ConsumerStatefulWidget {
  const _SemesterPicker();

  @override
  ConsumerState<_SemesterPicker> createState() => _SemesterPickerState();
}

class _SemesterPickerState extends ConsumerState<_SemesterPicker> {
  late final PageController _ctrl;
  List<String> _semesters = [];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(semesterSettingsProvider);
    _semesters = generateSemesters(settings);
    final cur = ref.read(selectedSemesterProvider);
    final idx = _semesters.indexOf(cur);
    _ctrl = PageController(
      viewportFraction: 0.28,
      initialPage: idx >= 0 ? idx : _semesters.length ~/ 2,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _jumpTo(String sem) {
    final idx = _semesters.indexOf(sem);
    if (idx >= 0) {
      _ctrl.animateToPage(idx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    }
    ref.read(selectedSemesterProvider.notifier).state = sem;
  }

  void _pickSemester(BuildContext ctx) {
    final s = ref.read(stringsProvider);
    final currentSem = ref.read(selectedSemesterProvider);
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: Text(s.semester),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _semesters.length,
            itemBuilder: (_, i) {
              final sem = _semesters[i];
              return ListTile(
                title: Text(sem),
                selected: sem == currentSem,
                selectedColor: AppColors.primary,
                onTap: () {
                  _jumpTo(sem);
                  Navigator.pop(dlgCtx);
                },
              );
            },
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
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(semesterSettingsProvider);
    _semesters = generateSemesters(settings);
    final selected = ref.watch(selectedSemesterProvider);
    final curSem = currentSemester(settings);
    final s = ref.watch(stringsProvider);
    final isOnCurrentSem = selected == curSem;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _semesters.length,
            onPageChanged: (i) =>
                ref.read(selectedSemesterProvider.notifier).state =
                    _semesters[i],
            itemBuilder: (ctx, i) {
              final sem = _semesters[i];
              final isSelected = sem == selected;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isSelected
                    ? () => _pickSemester(ctx)
                    : () => _jumpTo(sem),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontSize: isSelected ? 17 : 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        child: Text(sem),
                      ),
                      if (isSelected)
                        const Icon(Icons.arrow_drop_down,
                            size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!isOnCurrentSem)
          TextButton(
            onPressed: () => _jumpTo(curSem),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: Text(s.backToCurrentSem),
          ),
      ],
    );
  }
}

class _SemGoalCardTile extends ConsumerWidget {
  final SemesterGoal goal;
  final int depth;

  const _SemGoalCardTile({required this.goal, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allGoals = ref.watch(semesterGoalsProvider);
    final children = allGoals.where((g) => g.parentId == goal.id).toList();
    final notifier = ref.read(semesterGoalsProvider.notifier);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final primaryCat =
        goal.categories.isNotEmpty ? goal.categories.first : 'other';
    final catC = catColor(primaryCat);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SemesterGoalDetailScreen(goalId: goal.id),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.md + depth * 16.0, 6, AppSpacing.md, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: catC.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(catIcon(primaryCat), color: catC, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (goal.notes != null)
                    Text(
                      goal.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (total > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(s.goalProgress(done, total),
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: done / total,
                        minHeight: 4,
                        color: catC,
                        backgroundColor: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      showEditSemesterGoalSheet(context, ref, goal),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    if (await _confirmDelete(context, s)) {
                      ref.read(trashProvider.notifier).addSemesterGoal(goal);
                      notifier.remove(goal.id);
                    }
                  },
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, AppStrings s) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text('${s.delete}？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
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
