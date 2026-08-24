import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/semester_goal.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/drag_reorder.dart';
import '../widgets/empty_state.dart';
import '../widgets/hover_lift.dart';
import 'overview_graph_screen.dart';
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

// Width cap for the drag feedback card so it matches the list column
const _contentMaxWidth = 600.0;

class SemesterScreen extends ConsumerStatefulWidget {
  const SemesterScreen({super.key});

  @override
  ConsumerState<SemesterScreen> createState() => _SemesterScreenState();
}

class _SemesterScreenState extends ConsumerState<SemesterScreen> {
  String? _draggingId;
  String? _hoveredId;
  DropZone _hoverZone = DropZone.before;
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
    final screenWidth = MediaQuery.of(context).size.width;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: (screenWidth > _contentMaxWidth ? _contentMaxWidth : screenWidth) -
            AppSpacing.pageHorizontal * 2,
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
        // details.offset is the pointer thanks to pointerDragAnchorStrategy
        final zone = dropZoneFor(box, details.offset, canNest: true);
        if (_hoveredId != goalId || _hoverZone != zone) {
          setState(() {
            _hoveredId = goalId;
            _hoverZone = zone;
          });
        }
      },
      onLeave: (_) {
        if (_hoveredId == goalId) setState(() => _hoveredId = null);
      },
      onAcceptWithDetails: (details) {
        switch (_hoverZone) {
          case DropZone.before:
            final prev =
                siblingIndex > 0 ? siblings[siblingIndex - 1].sortOrder : null;
            notifier.reparent(
                details.data, parentId, orderBetween(prev, goal.sortOrder));
          case DropZone.after:
            final next = siblingIndex < siblings.length - 1
                ? siblings[siblingIndex + 1].sortOrder
                : null;
            notifier.reparent(
                details.data, parentId, orderBetween(goal.sortOrder, next));
          case DropZone.into:
            final childOrders = ref
                .read(semesterGoalsProvider)
                .where((g) => g.parentId == goalId)
                .map((g) => g.sortOrder);
            notifier.reparent(
                details.data, goalId, orderAfterLast(childOrders));
        }
        setState(() => _hoveredId = null);
      },
      builder: (ctx, candidates, _) {
        _rowCtxs[goalId] = ctx;
        final isHovered = _hoveredId == goalId && candidates.isNotEmpty;
        final showBeforeLine = isHovered && _hoverZone == DropZone.before;
        final showAfterLine = isHovered && _hoverZone == DropZone.after;
        final showChildBg = isHovered && _hoverZone == DropZone.into;
        final tile = _SemGoalCardTile(goal: goal, depth: depth);
        final fading = Opacity(
            opacity: 0.3, child: _SemGoalCardTile(goal: goal, depth: depth));
        final feedback = _feedbackCard(goal);

        Widget draggable;
        if (kIsWeb) {
          draggable = Draggable<String>(
            data: goalId,
            dragAnchorStrategy: pointerDragAnchorStrategy,
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
            dragAnchorStrategy: pointerDragAnchorStrategy,
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
              if (showBeforeLine)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: AppColors.primary),
                ),
              if (showAfterLine)
                Positioned(
                  bottom: 0,
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

    return HoverLift(
      child: Container(
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
    // Layout follows screen width, not platform, so narrow web windows get the mobile UI
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isWide = width >= AppBreakpoints.wide;

    final goalsList = groups.isEmpty
        ? EmptyState(
            icon: Icons.school_outlined,
            message: s.noTargets,
            actionLabel: s.addTarget,
            onAction: () => showSemesterGoalSheet(context, ref),
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
          );

    final content = Column(
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
            children: [
              if (!isDesktop) ...[
                IconButton(
                  icon: const Icon(Icons.menu),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(s.targets,
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.hub_outlined),
                tooltip: s.overview,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OverviewGraphScreen()),
                ),
              ),
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
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main block: goal group list
                    Expanded(flex: 2, child: goalsList),
                    // Secondary block: semester progress overview
                    const Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            0, 0, AppSpacing.pageHorizontal, AppSpacing.xl),
                        child: _SemesterOverviewCard(),
                      ),
                    ),
                  ],
                )
              : goalsList,
        ),
      ],
    );

    if (isDesktop) {
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Two-column cap: roomier on wide screens so side gaps stay balanced
            constraints: BoxConstraints(maxWidth: isWide ? 1100 : 900),
            child: content,
          ),
        ),
      );
    }

    return SafeArea(child: content);
  }
}

class _SemesterOverviewCard extends ConsumerWidget {
  const _SemesterOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final selectedSem = ref.watch(selectedSemesterProvider);
    final allGoals = ref.watch(semesterGoalsProvider);
    final cats = ref.watch(categoriesProvider);
    final topLevel = allGoals
        .where((g) => g.semester == selectedSem && g.parentId == null)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    var done = 0;
    var total = 0;
    final rows = <({SemesterGoal goal, int done, int total})>[];
    for (final p in topLevel) {
      final children = allGoals.where((g) => g.parentId == p.id).toList();
      final d = children.where((c) => c.isDone).length;
      rows.add((goal: p, done: d, total: children.length));
      done += d;
      total += children.length;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.progressOverview,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (topLevel.isEmpty)
            Text(s.noTargets,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ))
          else ...[
            if (total > 0) ...[
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: done / total),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            color: done == total
                                ? AppColors.success
                                : AppColors.primary,
                            backgroundColor: AppColors.surfaceVariant,
                          ),
                          Center(
                            child: Text(
                              '${(value * 100).round()}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(s.goalProgress(done, total),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(r.goal.title,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (r.total > 0)
                          Text(s.goalProgress(r.done, r.total),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: AppColors.textSecondary,
                              )),
                      ],
                    ),
                    if (r.total > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: r.done / r.total,
                          minHeight: 4,
                          color: resolveCatColor(cats, r.goal.categories.isNotEmpty
                              ? r.goal.categories.first
                              : 'other'),
                          backgroundColor: AppColors.surfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
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
    final settings = ref.read(semesterSettingsProvider);
    final currentSem = ref.read(selectedSemesterProvider);
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: Text(s.semester),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _semesters.length,
            itemBuilder: (_, i) {
              final sem = _semesters[i];
              return ListTile(
                title: Text(formatSemester(sem, settings, s)),
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
                        child: Text(formatSemester(sem, settings, s)),
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
    final cats = ref.watch(categoriesProvider);
    final children = allGoals.where((g) => g.parentId == goal.id).toList();
    final notifier = ref.read(semesterGoalsProvider.notifier);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final primaryCat =
        goal.categories.isNotEmpty ? goal.categories.first : 'other';
    final catC = resolveCatColor(cats, primaryCat);
    final linkedVision = goal.futureGoalId != null
        ? ref
            .watch(futureGoalsProvider)
            .where((g) => g.id == goal.futureGoalId)
            .firstOrNull
        : null;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SemesterGoalDetailScreen(goalId: goal.id),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category color bar; softer on child rows
            Container(
              width: goalCatBarWidth,
              color: catC.withValues(alpha: depth == 0 ? 1.0 : 0.45),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md - goalCatBarWidth + depth * 16.0,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => notifier.toggleDone(goal.id),
                      behavior: HitTestBehavior.opaque,
                      child: Tooltip(
                        message: goal.isDone ? s.markUndone : s.markDone,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: catC.withValues(
                                alpha: goal.isDone ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                              goal.isDone
                                  ? Icons.check
                                  : resolveCatIcon(cats, primaryCat),
                              color: catC,
                              size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goal.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                decoration: goal.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color:
                                    goal.isDone ? AppColors.textTertiary : null,
                              ),
                              // Clamped like the vision card so a long title
                              // can't make rows different heights
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (linkedVision != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    linkedVision.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.primary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (goal.notes != null)
                            Text(
                              goal.notes!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: done / total),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, _) => LinearProgressIndicator(
                                  value: v,
                                  minHeight: 4,
                                  color: catC,
                                  backgroundColor: AppColors.surfaceVariant,
                                ),
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
                              showSemesterGoalSheet(context, ref, existing: goal),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            if (await confirmDelete(context, s)) {
                              // Snapshot the whole subtree, not just the root
                              final removed = notifier.remove(goal.id);
                              final trash = ref.read(trashProvider.notifier);
                              for (final g in removed) {
                                trash.addSemesterGoal(g);
                              }
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
            ),
          ],
        ),
      ),
    );
  }
}

