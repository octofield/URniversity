import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/ui_symbols.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/category_manager.dart';
import '../widgets/drag_reorder.dart';
import '../widgets/empty_state.dart';
import '../widgets/link_color_bar.dart';
import '../widgets/sheet_body.dart';
import '../widgets/hover_lift.dart';
import '../widgets/page_header.dart';
import '../widgets/sheet_fields.dart';
import 'future_goal_detail_screen.dart';
import 'overview_graph_screen.dart';
import 'settings_screen.dart';

class _FutGroup {
  final FutureGoal parent;
  final List<FutureGoal> children;
  const _FutGroup({required this.parent, required this.children});
}

List<_FutGroup> _buildFutGroups(List<FutureGoal> topLevel, List<FutureGoal> all) {
  return [
    for (final p in topLevel)
      _FutGroup(
        parent: p,
        children: all.where((g) => g.parentId == p.id).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      ),
  ];
}

// Width cap for the drag feedback card so it matches the list column
const _contentMaxWidth = 600.0;

class FutureScreen extends ConsumerStatefulWidget {
  const FutureScreen({super.key});

  @override
  ConsumerState<FutureScreen> createState() => _FutureScreenState();
}

class _FutureScreenState extends ConsumerState<FutureScreen> {
  String? _catFilter;
  String? _semFilter;
  String? _draggingId;
  String? _hoveredId;
  DropZone _hoverZone = DropZone.before;
  final _rowCtxs = <String, BuildContext>{};

  Widget _endGapZone(List<_FutGroup> groups) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => _draggingId != null,
      onAcceptWithDetails: (details) {
        final lastOrder = groups.isNotEmpty ? groups.last.parent.sortOrder : 0;
        ref.read(futureGoalsProvider.notifier).reparent(details.data, null, lastOrder + 1000);
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

  Widget _feedbackCard(FutureGoal goal) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width:
            (screenWidth > _contentMaxWidth ? _contentMaxWidth : screenWidth) -
            AppSpacing.pageHorizontal * 2,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: _FutureGoalCardRow(goal: goal),
      ),
    );
  }

  Widget _buildDraggableRow(
    FutureGoal goal, {
    int depth = 0,
    String? parentId,
    List<FutureGoal> siblings = const [],
    int siblingIndex = 0,
  }) {
    final goalId = goal.id;
    final notifier = ref.read(futureGoalsProvider.notifier);

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
                .read(futureGoalsProvider)
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
        final tile = _FutureGoalCardRow(goal: goal, depth: depth);
        final fading = Opacity(
          opacity: 0.3,
          child: _FutureGoalCardRow(goal: goal, depth: depth),
        );
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

  List<Widget> _buildDescendantRows(String parentId, List<FutureGoal> all, int depth) {
    final children = all.where((g) => g.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (children.isEmpty) return [];
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(const Divider(height: 1, thickness: 1, color: AppColors.border));
      result.add(
        _buildDraggableRow(
          children[i],
          depth: depth,
          parentId: parentId,
          siblings: children,
          siblingIndex: i,
        ),
      );
      result.addAll(_buildDescendantRows(children[i].id, all, depth + 1));
    }
    return result;
  }

  Widget _buildGroupCard(
    _FutGroup group,
    List<FutureGoal> allGoals,
    int groupIdx,
    List<_FutGroup> groups,
  ) {
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
            _buildDraggableRow(
              parent,
              depth: 0,
              parentId: null,
              siblings: rootItems,
              siblingIndex: groupIdx,
            ),
            ..._buildDescendantRows(parent.id, allGoals, 1),
          ],
        ),
      ),
    );
  }

  List<String> _semesterChips(SemesterSettings settings) {
    final all = generateSemesters(settings);
    final cur = currentSemester(settings);
    final idx = all.indexOf(cur);
    return idx >= 0 ? all.sublist(idx) : all;
  }

  void _showMoreSemesters(BuildContext context, SemesterSettings settings) {
    final s = ref.read(stringsProvider);
    final all = generateSemesters(settings);

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(s.semester),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(s.catAll),
                selected: _semFilter == null,
                selectedColor: AppColors.primary,
                onTap: () {
                  setState(() => _semFilter = null);
                  Navigator.pop(dlgCtx);
                },
              ),
              for (final sem in all)
                ListTile(
                  title: Text(formatSemester(sem, settings, s)),
                  selected: sem == _semFilter,
                  selectedColor: AppColors.primary,
                  onTap: () {
                    setState(() => _semFilter = sem);
                    Navigator.pop(dlgCtx);
                  },
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
  }

  void _showMoreCategories(BuildContext context) {
    final s = ref.read(stringsProvider);

    showDialog(
      context: context,
      builder: (dlgCtx) => Consumer(
        builder: (_, cRef, _) {
          final cats = cRef.watch(categoriesProvider);
          return AlertDialog(
            title: Text(s.category),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 300,
                    child: ReorderableListView.builder(
                      itemCount: cats.length,
                      onReorderItem: (o, n) => cRef.read(categoriesProvider.notifier).reorder(o, n),
                      itemBuilder: (tileCtx, i) => categoryManageTile(
                        context: tileCtx,
                        ref: cRef,
                        entry: cats[i],
                        s: s,
                        selected: _catFilter == cats[i].id,
                        onTap: () {
                          setState(() => _catFilter = _catFilter == cats[i].id ? null : cats[i].id);
                          Navigator.pop(dlgCtx);
                        },
                      ),
                    ),
                  ),
                  const Divider(),
                  const CategoryAddRow(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSidebar() {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(semesterSettingsProvider);
    final allGoals = ref.watch(futureGoalsProvider);
    final cats = ref.watch(categoriesProvider);
    final semChips = _semesterChips(settings);

    int countFor(String cat) =>
        allGoals.where((g) => g.parentId == null && g.categories.contains(cat)).length;

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
          Text(s.filters, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.category,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _FilterChip(
                label: s.catAll,
                selected: _catFilter == null,
                onTap: () => setState(() => _catFilter = null),
              ),
              for (final cat in cats)
                _FilterChip(
                  label: '${catLabel(cat.id, s)} (${countFor(cat.id)})',
                  selected: _catFilter == cat.id,
                  color: cat.color,
                  onTap: () => setState(() => _catFilter = _catFilter == cat.id ? null : cat.id),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 16),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.more)),
                onPressed: () => _showMoreCategories(context),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            s.semester,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _FilterChip(
                label: s.anySemester,
                selected: _semFilter == null,
                onTap: () => setState(() => _semFilter = null),
              ),
              for (final sem in semChips)
                _FilterChip(
                  label: formatSemester(sem, settings, s),
                  selected: _semFilter == sem,
                  onTap: () => setState(() => _semFilter = _semFilter == sem ? null : sem),
                ),
              ActionChip(
                avatar: const Icon(Icons.expand_more, size: 16),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.more)),
                onPressed: () => _showMoreSemesters(context, settings),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(semesterSettingsProvider);
    final allGoals = ref.watch(futureGoalsProvider);
    final cats = ref.watch(categoriesProvider);
    final semChips = _semesterChips(settings);

    final filtered = allGoals.where((g) {
      if (g.parentId != null) return false;
      final semOk = _semFilter == null || g.startSemester == _semFilter;
      final catOk = _catFilter == null || g.categories.contains(_catFilter);
      return semOk && catOk;
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final groups = _buildFutGroups(filtered, allGoals);
    final subVisions = [for (final g in groups) ...g.children];
    final subTotal = subVisions.length;
    final subDone = subVisions.where((g) => g.isDone).length;
    // Layout follows screen width, not platform, so narrow web windows get the mobile UI
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isWide = width >= AppBreakpoints.wide;

    final goalsList = filtered.isEmpty
        ? EmptyState(
            icon: Icons.flag_outlined,
            message: s.noGoals,
            actionLabel: s.addGoal,
            onAction: () => showFutureGoalSheet(context, ref),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              0,
              AppSpacing.pageHorizontal,
              80,
            ),
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
          title: s.goals,
          subtitle: Text(
            s.visionsSummary(filtered.length, subDone, subTotal),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          actions: [
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
        // Mobile keeps the chip rows; desktop moves the filters into the sidebar
        if (!isDesktop) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 4),
            child: _AdaptiveChipRow(
              allChip: _FilterChip(
                label: s.catAll,
                selected: _catFilter == null,
                onTap: () => setState(() => _catFilter = null),
              ),
              chips: [
                for (final cat in cats)
                  _FilterChip(
                    label: catLabel(cat.id, s),
                    selected: _catFilter == cat.id,
                    color: cat.color,
                    onTap: () => setState(() => _catFilter = _catFilter == cat.id ? null : cat.id),
                  ),
              ],
              trailing: ActionChip(
                avatar: const Icon(Icons.tune, size: 16),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.more)),
                onPressed: () => _showMoreCategories(context),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal, vertical: 4),
            child: _AdaptiveChipRow(
              allChip: _FilterChip(
                label: s.anySemester,
                selected: _semFilter == null,
                onTap: () => setState(() => _semFilter = null),
              ),
              chips: [
                for (final sem in semChips)
                  _FilterChip(
                    label: formatSemester(sem, settings, s),
                    selected: _semFilter == sem,
                    onTap: () => setState(() => _semFilter = _semFilter == sem ? null : sem),
                  ),
              ],
              trailing: ActionChip(
                avatar: const Icon(Icons.expand_more, size: 16),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.more)),
                onPressed: () => _showMoreSemesters(context, settings),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main block: goal group list
                    Expanded(flex: 2, child: goalsList),
                    // Secondary block: filters with per-category counts
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          0,
                          0,
                          AppSpacing.pageHorizontal,
                          AppSpacing.xl,
                        ),
                        child: _buildFilterSidebar(),
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

class _AdaptiveChipRow extends StatelessWidget {
  final Widget allChip;
  final List<Widget> chips;
  final Widget trailing;

  const _AdaptiveChipRow({required this.allChip, required this.chips, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        allChip,
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.9, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final chip in chips) ...[chip, const SizedBox(width: AppSpacing.xs)],
                  // Trailing spacer so the last chip can fully scroll clear of the fade
                  const SizedBox(width: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        trailing,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    // The canvas's pill: an outline that fills with the app's own tint when it
    // is the one in force. A category's own colour would compete with the
    // cards' colour bars, which is what actually tells them apart
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
          maxLines: 1,
        ),
      ),
    );
  }
}

// Design A (2026-09-16 canvas), matching the targets page: a 38px icon box and
// sub-visions as a light checklist inside their parent's card
const double _iconBoxSize = 38.0;
const double _childIndent =
    goalCatBarWidth + AppSpacing.sm + _iconBoxSize + AppSpacing.sm;

class _FutureGoalCardRow extends ConsumerWidget {
  final FutureGoal goal;
  final int depth;
  const _FutureGoalCardRow({required this.goal, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allGoals = ref.watch(futureGoalsProvider);
    final cats = ref.watch(categoriesProvider);
    final semSettings = ref.watch(semesterSettingsProvider);
    final children = allGoals.where((g) => g.parentId == goal.id).toList();
    final notifier = ref.read(futureGoalsProvider.notifier);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final progress = total > 0 ? done / total : 0.0;
    final primaryCat = primaryCategoryOf(goal.categories);
    // A vision with no category shows no colour and no icon at all
    final catC = categoryColorOrNull(cats, primaryCat);
    final catIcon = categoryIconOrNull(cats, primaryCat);

    void openDetail() => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FutureGoalDetailScreen(goalId: goal.id)),
        );

    Future<void> deleteGoal() async {
      // Confirm before deleting, matching the goal cards —
      // this was deleting immediately with no prompt
      if (await confirmDelete(context, s)) {
        // Snapshot the whole subtree, not just the root
        final removed = notifier.remove(goal.id);
        final trash = ref.read(trashProvider.notifier);
        for (final g in removed) {
          trash.addFutureGoal(g);
        }
      }
    }

    final hasSubContent = goal.startSemester != null ||
        goal.endSemester != null ||
        goal.notes != null ||
        total > 0;

    final span = [
      if (goal.startSemester != null)
        formatSemester(goal.startSemester!, semSettings, s),
      if (goal.startSemester != null && goal.endSemester != null) kArrow,
      if (goal.endSemester != null)
        formatSemester(goal.endSemester!, semSettings, s),
    ].join(' ');

    if (depth > 0) {
      return InkWell(
        onTap: openDetail,
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
                      border:
                          Border.all(color: catC ?? AppColors.border, width: 2),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
      onTap: openDetail,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                goalCatBarWidth + AppSpacing.sm, 12, AppSpacing.sm, 12),
            child: Row(
              // Same as the targets card: nothing under the title means the
              // icon box and the title share a centre line
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
                        color: (catC ?? AppColors.textTertiary)
                            .withValues(alpha: goal.isDone ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
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
                      Text(
                        goal.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: goal.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: goal.isDone ? AppColors.textTertiary : null,
                            ),
                        // Two lines like the goal card, for the same reason
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (span.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            span,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
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
                        Text(
                          s.goalProgress(done, total),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          showFutureGoalSheet(context, ref, existing: goal),
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


Widget _semesterDropdown({
  required String? value,
  required List<String> semesters,
  required String label,
  required String? minSemester,
  required void Function(String?) onChanged,
  required SemesterSettings settings,
  required AppStrings s,
}) {
  final valid = minSemester == null
      ? semesters
      : semesters.where((sem) => compareSemesters(sem, minSemester) >= 0).toList();

  return DropdownButtonFormField<String?>(
    initialValue: value,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: [
      const DropdownMenuItem(value: null, child: Text(kEmptyValue)),
      for (final sem in valid)
        DropdownMenuItem(value: sem, child: Text(formatSemester(sem, settings, s))),
    ],
    onChanged: onChanged,
  );
}

// One sheet for both modes: [existing] null means add, non-null means edit
void showFutureGoalSheet(
  BuildContext context,
  WidgetRef ref, {
  FutureGoal? existing,
  String? defaultSemester,
  String? parentId,
}) {
  final isEdit = existing != null;
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final s = ref.read(stringsProvider);
  final settings = ref.read(semesterSettingsProvider);
  final cats = ref.read(categoriesProvider);
  final semesters = generateSemesters(settings);

  var selectedCategories = isEdit ? List<String>.from(existing.categories) : <String>[];
  String? startSemester =
      isEdit ? existing.startSemester : (defaultSemester ?? currentSemester(settings));
  String? endSemester = existing?.endSemester;

  showAppSheet(
    context,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) => SheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit
                  ? s.editGoal
                  : (parentId != null ? s.addSubgoal : s.addGoal),
              style: Theme.of(sheetCtx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            SheetTextField(
              label: s.titleField,
              controller: titleCtrl,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            // One short line at rest, growing to three
            SheetTextField(
              label: s.goalNotes,
              controller: notesCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.category,
              style: Theme.of(
                sheetCtx,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            SheetCategoryChips(
              categories: cats,
              selected: selectedCategories.toSet(),
              s: s,
              onToggle: (cat) => setState(() {
                if (selectedCategories.contains(cat)) {
                  selectedCategories.remove(cat);
                } else {
                  selectedCategories.add(cat);
                }
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _semesterDropdown(
                    value: startSemester,
                    semesters: semesters,
                    label: s.startSemester,
                    minSemester: null,
                    settings: settings,
                    s: s,
                    onChanged: (v) => setState(() {
                      startSemester = v;
                      if (endSemester != null &&
                          startSemester != null &&
                          compareSemesters(endSemester!, startSemester!) < 0) {
                        endSemester = null;
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _semesterDropdown(
                    value: endSemester,
                    semesters: semesters,
                    label: s.endSemester,
                    minSemester: startSemester,
                    settings: settings,
                    s: s,
                    onChanged: (v) => setState(() => endSemester = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  final notifier = ref.read(futureGoalsProvider.notifier);
                  final categories = selectedCategories.isEmpty
                      ? [FutureCategories.other]
                      : selectedCategories;
                  if (isEdit) {
                    notifier.updateGoal(
                      existing.id,
                      title: titleCtrl.text.trim(),
                      categories: categories,
                      startSemester: startSemester,
                      endSemester: endSemester,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    Navigator.pop(sheetCtx);
                    return;
                  }
                  notifier
                      .addGoal(
                        parentId: parentId,
                        title: titleCtrl.text.trim(),
                        categories: categories,
                        startSemester: startSemester,
                        endSemester: endSemester,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );
                  Navigator.pop(sheetCtx);
                },
                child: Text(isEdit ? s.save : s.add),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

