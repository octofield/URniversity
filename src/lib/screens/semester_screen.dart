import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../models/semester_goal.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/link_color_bar.dart';
import '../widgets/drag_reorder.dart';
import '../widgets/empty_state.dart';
import '../widgets/hover_lift.dart';
import '../widgets/page_header.dart';
import '../widgets/swipe_switcher.dart';
import '../widgets/semester_list_dialog.dart';
import '../widgets/sort_sheet.dart';
import 'overview_graph_screen.dart';
import 'semester_goal_detail_screen.dart';
import 'settings_screen.dart';

class _SemGroup {
  final SemesterGoal parent;
  final List<SemesterGoal> children;
  const _SemGroup({required this.parent, required this.children});
}

List<_SemGroup> _buildSemGroups(List<SemesterGoal> topLevel,
    List<SemesterGoal> all, List<SemesterGoal> Function(List<SemesterGoal>) order) {
  return [
    for (final p in topLevel)
      _SemGroup(
        parent: p,
        children: order(all.where((g) => g.parentId == p.id).toList()),
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

  // One semester further along the list, for the swipe on the card list. The
  // strip above follows through its own listener
  void _stepSemester(int delta) {
    final semesters = generateSemesters(ref.read(semesterSettingsProvider));
    final index = semesters.indexOf(ref.read(selectedSemesterProvider)) + delta;
    if (index < 0 || index >= semesters.length) return;
    ref.read(selectedSemesterProvider.notifier).state = semesters[index];
  }

  // One level of the tree in the order the page is sorted by
  List<SemesterGoal> _ordered(List<SemesterGoal> siblings) {
    final visions = ref.watch(futureGoalsProvider);
    return applyTargetSort(
      siblings,
      ref.watch(targetSortProvider),
      visionTitles: {for (final v in visions) v.id: v.title},
    );
  }

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
    // Same rule as the task list: dragging writes the manual order, so it is
    // off while the page shows any other
    if (ref.watch(targetSortProvider) != TargetSort.manual) {
      return _SemGoalCardTile(goal: goal, depth: depth);
    }
    final sortMode = ref.watch(targetSortModeProvider);

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
        final feedback = _feedbackCard(goal);
        final tile = _SemGoalCardTile(
          goal: goal,
          depth: depth,
          // Drags at once from the handle, no long press
          handle: sortMode
              ? DragHandle<String>(
                  data: goalId,
                  feedback: feedback,
                  onDragStarted: () => setState(() => _draggingId = goalId),
                  onDragEnd: () => setState(() {
                    _draggingId = null;
                    _hoveredId = null;
                  }),
                )
              : null,
        );
        final fading = Opacity(
            opacity: 0.3, child: _SemGoalCardTile(goal: goal, depth: depth));

        Widget draggable;
        if (sortMode) {
          draggable = tile;
        } else if (kIsWeb) {
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
    final children =
        _ordered(all.where((g) => g.parentId == parentId).toList());
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
    final topLevel = _ordered(allGoals
        .where((g) => g.semester == selectedSem && g.parentId == null)
        .toList());
    final groups = _buildSemGroups(topLevel, allGoals, _ordered);
    final sort = ref.watch(targetSortProvider);
    final sortMode = ref.watch(targetSortModeProvider);
    final semSettings = ref.watch(semesterSettingsProvider);
    // The header's own line: how much of this semester's plan is done
    final milestones = [for (final g in groups) ...g.children];
    final milestonesTotal = milestones.length;
    final milestonesDone = milestones.where((g) => g.isDone).length;
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
        PageHeader(
          title: s.targets,
          subtitle: Text(
            '${formatSemester(selectedSem, semSettings, s)}$kDotSeparator'
            '${s.targetsSummary(topLevel.length, milestonesDone, milestonesTotal)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          actions: [
            SortButton(
              s: s,
              isManual: sort == TargetSort.manual,
              sortMode: sortMode,
              onOpen: () => showSortSheet(
                context,
                s: s,
                labels: {
                  TargetSort.manual: s.sortManual,
                  TargetSort.title: s.sortTitle,
                  TargetSort.vision: s.sortVision,
                  TargetSort.undoneFirst: s.sortUndoneFirst,
                },
                sortProvider: targetSortProvider,
                sortModeProvider: targetSortModeProvider,
                manual: TargetSort.manual,
              ),
              onDone: () =>
                  ref.read(targetSortModeProvider.notifier).state = false,
            ),
            IconButton(
              icon: const Icon(Icons.hub_outlined),
              tooltip: s.overview,
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OverviewGraphScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
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
              : SwipeSwitcher(
                  // Off while rearranging, so a sideways handle drag does not
                  // change the semester instead
                  onNext: sortMode ? null : () => _stepSemester(1),
                  onPrevious: sortMode ? null : () => _stepSemester(-1),
                  child: goalsList,
                ),
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

    // One pill per category, summing the goals that carry it
    final byCat = <String?, ({int done, int total})>{};
    for (final r in rows) {
      final cat = primaryCategoryOf(r.goal.categories);
      final prev = byCat[cat] ?? (done: 0, total: 0);
      byCat[cat] = (done: prev.done + r.done, total: prev.total + r.total);
    }
    final progress = total > 0 ? done / total : 0.0;

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
            if (total > 0)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          s.percentSuffix((value * 100).round()),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: done == total ? AppColors.success : AppColors.primary,
                              ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            s.goalProgress(done, total),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        color: done == total ? AppColors.success : AppColors.primary,
                        backgroundColor: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final entry in byCat.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // The "no category" bucket has no colour to show
                            color: categoryColorOrNull(cats, entry.key),
                            border: categoryColorOrNull(cats, entry.key) == null
                                ? Border.all(color: AppColors.border)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${entry.value.done}/${entry.value.total}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
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
  List<String> _semesters = [];

  void _jumpTo(String sem) =>
      ref.read(selectedSemesterProvider.notifier).state = sem;

  // One step along the list, or nothing at all at either end
  void _step(int delta) {
    final idx = _semesters.indexOf(ref.read(selectedSemesterProvider)) + delta;
    if (idx < 0 || idx >= _semesters.length) return;
    _jumpTo(_semesters[idx]);
  }

  void _pickSemester(BuildContext ctx) {
    final s = ref.read(stringsProvider);
    final settings = ref.read(semesterSettingsProvider);
    showDialog(
      context: ctx,
      builder: (_) => SemesterListDialog(
        title: s.semester,
        semesters: _semesters,
        selected: ref.read(selectedSemesterProvider),
        openAt: currentSemester(settings),
        settings: settings,
        s: s,
        onSelect: (sem) => _jumpTo(sem!),
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
    final index = _semesters.indexOf(selected);

    // The design's switcher (2026-09-16 canvas): a step either way, the
    // semester itself in the middle opening the full list, and a way back to
    // the current one. The list below still swipes between semesters
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
            onPressed: index > 0 ? () => _step(-1) : null,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.full),
            onTap: () => _pickSemester(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatSemester(selected, settings, s),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                  ),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
            onPressed:
                index >= 0 && index < _semesters.length - 1 ? () => _step(1) : null,
          ),
          if (!isOnCurrentSem)
            TextButton(
              onPressed: () => _jumpTo(curSem),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(s.backToCurrentSem),
            ),
        ],
      ),
    );
  }
}

// Design A (2026-09-16 canvas): 38px icon box, milestones as a light
// checklist inside the card
const double _iconBoxSize = 38.0;

// Where a milestone row starts: bar + padding + icon box + gap
const double _childIndent =
    goalCatBarWidth + AppSpacing.sm + _iconBoxSize + AppSpacing.sm;

class _SemGoalCardTile extends ConsumerWidget {
  final SemesterGoal goal;
  final int depth;
  // Set while rearranging: shown instead of the row's buttons, and the row
  // stops opening the detail page so a stray tap does not leave sort mode
  final Widget? handle;

  const _SemGoalCardTile({required this.goal, this.depth = 0, this.handle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allGoals = ref.watch(semesterGoalsProvider);
    final cats = ref.watch(categoriesProvider);
    final children = allGoals.where((g) => g.parentId == goal.id).toList();
    final notifier = ref.read(semesterGoalsProvider.notifier);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final primaryCat = primaryCategoryOf(goal.categories);
    final linkedVision = goal.futureGoalId != null
        ? ref
            .watch(futureGoalsProvider)
            .where((g) => g.id == goal.futureGoalId)
            .firstOrNull
        : null;
    // A goal with no category of its own borrows the colour of the vision it
    // is linked to; with neither there is simply no colour to show
    final catC = goalEffectiveColor(cats, goal.categories,
        linkedVision: linkedVision);
    final catIcon = categoryIconOrNull(cats, primaryCat);
    final visionC = linkedVision == null
        ? null
        : categoryColorOrNull(cats, primaryCategoryOf(linkedVision.categories));

    // A card that is only a title has nothing to align the icon box against,
    // so the two sit on the same centre line instead of hanging from the top
    final hasSubContent = linkedVision != null || goal.notes != null || total > 0;

    void openDetail() => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SemesterGoalDetailScreen(goalId: goal.id),
          ),
        );

    Future<void> deleteGoal() async {
      if (await confirmDelete(context, s)) {
        // Snapshot the whole subtree, not just the root
        final removed = notifier.remove(goal.id);
        final trash = ref.read(trashProvider.notifier);
        for (final g in removed) {
          trash.addSemesterGoal(g);
        }
      }
    }

    // Milestones are a light checklist inside their parent's card (design A,
    // 2026-09-16): the full card treatment for every level buried the goal
    if (depth > 0) {
      return InkWell(
        onTap: handle != null ? null : openDetail,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              _childIndent + (depth - 1) * 16.0, 7, AppSpacing.sm, 7),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => notifier.toggleDone(goal.id),
                behavior: HitTestBehavior.opaque,
                child: Tooltip(
                  message: goal.isDone ? s.markUndone : s.markDone,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: goal.isDone
                          ? (catC ?? AppColors.primary)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(
                        color: catC ?? AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: goal.isDone
                        ? const Icon(Icons.check,
                            size: 12, color: AppColors.textOnPrimary)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  goal.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        decoration:
                            goal.isDone ? TextDecoration.lineThrough : null,
                        color: goal.isDone ? AppColors.textTertiary : null,
                      ),
                ),
              ),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    s.goalProgress(done, total),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ),
              handle ??
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: deleteGoal,
                  ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: handle != null ? null : openDetail,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                goalCatBarWidth + AppSpacing.sm, 12, AppSpacing.sm, 12),
            child: Row(
              crossAxisAlignment: hasSubContent
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => notifier.toggleDone(goal.id),
                  behavior: HitTestBehavior.opaque,
                  child: Tooltip(
                    message: goal.isDone ? s.markUndone : s.markDone,
                    child: Container(
                      width: _iconBoxSize,
                      height: _iconBoxSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (catC ?? AppColors.textTertiary).withValues(
                            alpha: goal.isDone ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      // No category means no icon at all — a stand-in glyph
                      // reads as a category the user cannot place
                      child: goal.isDone || catIcon != null
                          ? Icon(goal.isDone ? Icons.check : catIcon,
                              color: catC ?? AppColors.textSecondary, size: 20)
                          : null,
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: goal.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color:
                                    goal.isDone ? AppColors.textTertiary : null,
                              )),
                      if (linkedVision != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The vision's own colour, not the goal's: the
                              // two differing is what shows they are linked
                              // rather than the same thing
                              Icon(Icons.stars,
                                  size: 12,
                                  color: visionC ?? AppColors.textTertiary),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  linkedVision.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color:
                                            visionC ?? AppColors.textSecondary,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (goal.notes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            goal.notes!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (total > 0) ...[
                        const SizedBox(height: 9),
                        Text(s.goalProgress(done, total),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                )),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: done / total),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 4,
                              color: catC ?? AppColors.primary,
                              backgroundColor: AppColors.surfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                handle ?? Row(
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
                      onPressed: deleteGoal,
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 14, color: AppColors.textTertiary),
                  ],
                ),
              ],
            ),
          ),
          // The colour bar is painted over the left edge rather than being a
          // Row child: a ListTile-free column still measures itself correctly,
          // and there is no IntrinsicHeight to get the height wrong
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: LinkColorBar(width: goalCatBarWidth, top: catC),
          ),
        ],
      ),
    );
  }
}
