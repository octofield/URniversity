import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/future_goal.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/hover_lift.dart';
import 'future_goal_detail_screen.dart';
import 'overview_graph_screen.dart';
import 'settings_screen.dart';

class _FutGroup {
  final FutureGoal parent;
  final List<FutureGoal> children;
  const _FutGroup({required this.parent, required this.children});
}

List<_FutGroup> _buildFutGroups(
    List<FutureGoal> topLevel, List<FutureGoal> all) {
  return [
    for (final p in topLevel)
      _FutGroup(
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
  bool _hoverAbove = false;
  final _rowCtxs = <String, BuildContext>{};

  Widget _endGapZone(List<_FutGroup> groups) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => _draggingId != null,
      onAcceptWithDetails: (details) {
        final lastOrder =
            groups.isNotEmpty ? groups.last.parent.sortOrder : 0;
        ref
            .read(futureGoalsProvider.notifier)
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

  Widget _feedbackCard(FutureGoal goal) {
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
          final allGoals = ref.read(futureGoalsProvider);
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
        final tile = _FutureGoalCardRow(goal: goal, depth: depth);
        final fading = Opacity(
            opacity: 0.3,
            child: _FutureGoalCardRow(goal: goal, depth: depth));
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
      String parentId, List<FutureGoal> all, int depth) {
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
      _FutGroup group,
      List<FutureGoal> allGoals,
      int groupIdx,
      List<_FutGroup> groups) {
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
          width: double.maxFinite,
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
                  title: Text(sem),
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
    final addCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => Consumer(
        builder: (_, cRef, _) {
          final cats = cRef.watch(categoriesProvider);
          return AlertDialog(
            title: Text(s.category),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 300,
                    child: ReorderableListView.builder(
                      itemCount: cats.length,
                      onReorder: (o, n) =>
                          cRef.read(categoriesProvider.notifier).reorder(o, n),
                      itemBuilder: (_, i) {
                        final cat = cats[i];
                        final isBuiltIn = cRef
                            .read(categoriesProvider.notifier)
                            .isBuiltIn(cat);
                        return ListTile(
                          key: ValueKey(cat),
                          leading: Icon(catIcon(cat), color: catColor(cat)),
                          title: Text(catLabel(cat, s)),
                          selected: _catFilter == cat,
                          selectedColor: AppColors.primary,
                          trailing: isBuiltIn
                              ? const Icon(Icons.drag_handle,
                                  color: AppColors.textTertiary)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18),
                                      onPressed: () {
                                        cRef
                                            .read(categoriesProvider.notifier)
                                            .remove(cat);
                                        if (_catFilter == cat) {
                                          setState(() => _catFilter = null);
                                        }
                                      },
                                    ),
                                    const Icon(Icons.drag_handle,
                                        color: AppColors.textTertiary),
                                  ],
                                ),
                          onTap: () {
                            setState(() =>
                                _catFilter = _catFilter == cat ? null : cat);
                            Navigator.pop(dlgCtx);
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addCtrl,
                          decoration:
                              InputDecoration(hintText: s.categoryName),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (name) {
                            final trimmed = name.trim();
                            if (trimmed.isEmpty) return;
                            cRef
                                .read(categoriesProvider.notifier)
                                .add(trimmed);
                            addCtrl.clear();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.primary),
                        onPressed: () {
                          final name = addCtrl.text.trim();
                          if (name.isEmpty) return;
                          cRef.read(categoriesProvider.notifier).add(name);
                          addCtrl.clear();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(
                    MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
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

    int countFor(String cat) => allGoals
        .where((g) => g.parentId == null && g.categories.contains(cat))
        .length;

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
          Text(s.semester,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _FilterChip(
                label: s.catAll,
                selected: _semFilter == null,
                onTap: () => setState(() => _semFilter = null),
              ),
              for (final sem in semChips)
                _FilterChip(
                  label: sem,
                  selected: _semFilter == sem,
                  onTap: () => setState(
                      () => _semFilter = _semFilter == sem ? null : sem),
                ),
              ActionChip(
                avatar: const Icon(Icons.expand_more, size: 16),
                label: Text(s.more),
                onPressed: () => _showMoreSemesters(context, settings),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(s.category,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              )),
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
                  label: '${catLabel(cat, s)} (${countFor(cat)})',
                  selected: _catFilter == cat,
                  color: catColor(cat),
                  onTap: () => setState(
                      () => _catFilter = _catFilter == cat ? null : cat),
                ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 16),
                label: Text(s.more),
                onPressed: () => _showMoreCategories(context),
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
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final groups = _buildFutGroups(filtered, allGoals);
    // Layout follows screen width, not platform, so narrow web windows get the mobile UI
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isWide = width >= AppBreakpoints.wide;

    final goalsList = filtered.isEmpty
        ? EmptyState(
            icon: Icons.flag_outlined,
            message: s.noGoals,
            actionLabel: s.addGoal,
            onAction: () => showAddFutureGoalSheet(context, ref),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.pageTop,
            AppSpacing.pageHorizontal,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Text(s.goals,
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
        // Mobile keeps the chip rows; desktop moves the filters into the sidebar
        if (!isDesktop) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal, vertical: 4),
            child: _AdaptiveChipRow(
              allChip: _FilterChip(
                label: s.catAll,
                selected: _semFilter == null,
                onTap: () => setState(() => _semFilter = null),
              ),
              chips: [
                for (final sem in semChips)
                  _FilterChip(
                    label: sem,
                    selected: _semFilter == sem,
                    onTap: () => setState(
                        () => _semFilter = _semFilter == sem ? null : sem),
                  ),
              ],
              trailing: ActionChip(
                avatar: const Icon(Icons.expand_more, size: 16),
                label: Text(s.more),
                onPressed: () => _showMoreSemesters(context, settings),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal, vertical: 4),
            child: _AdaptiveChipRow(
              allChip: _FilterChip(
                label: s.catAll,
                selected: _catFilter == null,
                onTap: () => setState(() => _catFilter = null),
              ),
              chips: [
                for (final cat in cats)
                  _FilterChip(
                    label: catLabel(cat, s),
                    selected: _catFilter == cat,
                    color: catColor(cat),
                    onTap: () => setState(
                        () => _catFilter = _catFilter == cat ? null : cat),
                  ),
              ],
              trailing: ActionChip(
                avatar: const Icon(Icons.tune, size: 16),
                label: Text(s.more),
                onPressed: () => _showMoreCategories(context),
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
                            0, 0, AppSpacing.pageHorizontal, AppSpacing.xl),
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

  const _AdaptiveChipRow({
    required this.allChip,
    required this.chips,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        allChip,
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final chip in chips) ...[
                  chip,
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
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

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: color?.withValues(alpha: 0.08),
      selectedColor: color?.withValues(alpha: 0.25),
      checkmarkColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _FutureGoalCardRow extends ConsumerWidget {
  final FutureGoal goal;
  final int depth;
  const _FutureGoalCardRow({required this.goal, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allGoals = ref.watch(futureGoalsProvider);
    final children = allGoals.where((g) => g.parentId == goal.id).toList();
    final notifier = ref.read(futureGoalsProvider.notifier);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final progress = total > 0 ? done / total : 0.0;
    final primaryCat = goal.categories.isNotEmpty
        ? goal.categories.first
        : FutureCategories.other;
    final catC = catColor(primaryCat);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FutureGoalDetailScreen(goalId: goal.id),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category color bar; softer on child rows
            Container(
              width: 4,
              color: catC.withValues(alpha: depth == 0 ? 1.0 : 0.45),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md - 4 + depth * 16.0,
                  AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
                ),
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
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (goal.startSemester != null ||
                              goal.endSemester != null)
                            Text(
                              [
                                if (goal.startSemester != null)
                                  goal.startSemester!,
                                if (goal.startSemester != null &&
                                    goal.endSemester != null)
                                  '→',
                                if (goal.endSemester != null)
                                  goal.endSemester!,
                              ].join(' '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          if (goal.notes != null)
                            Text(goal.notes!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          if (total > 0) ...[
                            const SizedBox(height: 4),
                            Text(s.goalProgress(done, total),
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: progress),
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
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          showEditFutureGoalSheet(context, ref, goal),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        ref.read(trashProvider.notifier).addFutureGoal(goal);
                        notifier.remove(goal.id);
                      },
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 13, color: AppColors.textTertiary),
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

Widget _sheetDragHandle() => Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
    );

Widget _semesterDropdown({
  required String? value,
  required List<String> semesters,
  required String label,
  required String? minSemester,
  required void Function(String?) onChanged,
}) {
  final valid = minSemester == null
      ? semesters
      : semesters.where((s) => compareSemesters(s, minSemester) >= 0).toList();

  return DropdownButtonFormField<String?>(
    initialValue: value,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: [
      const DropdownMenuItem(value: null, child: Text('—')),
      for (final sem in valid)
        DropdownMenuItem(value: sem, child: Text(sem)),
    ],
    onChanged: onChanged,
  );
}

Widget _categoryChipsMulti(
  BuildContext context,
  dynamic s,
  List<String> allCats,
  List<String> selected,
  void Function(String) onToggle,
) {
  return Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final cat in allCats)
        FilterChip(
          label: Text(catLabel(cat, s)),
          selected: selected.contains(cat),
          onSelected: (_) => onToggle(cat),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 2),
        ),
    ],
  );
}

void showAddFutureGoalSheet(BuildContext context, WidgetRef ref,
    {String? defaultSemester, String? parentId}) {
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final s = ref.read(stringsProvider);
  final settings = ref.read(semesterSettingsProvider);
  final cats = ref.read(categoriesProvider);
  final semesters = generateSemesters(settings);

  var selectedCategories = <String>[];
  String? startSemester = defaultSemester ?? currentSemester(settings);
  String? endSemester;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            top: AppSpacing.lg,
            bottom:
                MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetDragHandle(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                parentId != null ? s.addSubgoal : s.addGoal,
                style: Theme.of(sheetCtx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s.titleField),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s.goalNotes,
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(s.category,
                  style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  )),
              const SizedBox(height: AppSpacing.xs),
              _categoryChipsMulti(sheetCtx, s, cats, selectedCategories,
                  (cat) => setState(() {
                    if (selectedCategories.contains(cat)) {
                      selectedCategories.remove(cat);
                    } else {
                      selectedCategories.add(cat);
                    }
                  })),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _semesterDropdown(
                      value: startSemester,
                      semesters: semesters,
                      label: s.startSemester,
                      minSemester: null,
                      onChanged: (v) => setState(() {
                        startSemester = v;
                        if (endSemester != null &&
                            startSemester != null &&
                            compareSemesters(endSemester!, startSemester!) <
                                0) {
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
                    ref.read(futureGoalsProvider.notifier).addGoal(
                      parentId: parentId,
                      title: titleCtrl.text.trim(),
                      categories: selectedCategories.isEmpty
                          ? [FutureCategories.other]
                          : selectedCategories,
                      startSemester: startSemester,
                      endSemester: endSemester,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(s.add),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void showEditFutureGoalSheet(
    BuildContext context, WidgetRef ref, FutureGoal goal) {
  final titleCtrl = TextEditingController(text: goal.title);
  final notesCtrl = TextEditingController(text: goal.notes ?? '');
  final s = ref.read(stringsProvider);
  final settings = ref.read(semesterSettingsProvider);
  final cats = ref.read(categoriesProvider);
  final semesters = generateSemesters(settings);

  var selectedCategories = List<String>.from(goal.categories);
  String? startSemester = goal.startSemester;
  String? endSemester = goal.endSemester;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            top: AppSpacing.lg,
            bottom:
                MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetDragHandle(),
              const SizedBox(height: AppSpacing.lg),
              Text(s.editGoal,
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s.titleField),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s.goalNotes,
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(s.category,
                  style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  )),
              const SizedBox(height: AppSpacing.xs),
              _categoryChipsMulti(sheetCtx, s, cats, selectedCategories,
                  (cat) => setState(() {
                    if (selectedCategories.contains(cat)) {
                      selectedCategories.remove(cat);
                    } else {
                      selectedCategories.add(cat);
                    }
                  })),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _semesterDropdown(
                      value: startSemester,
                      semesters: semesters,
                      label: s.startSemester,
                      minSemester: null,
                      onChanged: (v) => setState(() {
                        startSemester = v;
                        if (endSemester != null &&
                            startSemester != null &&
                            compareSemesters(endSemester!, startSemester!) <
                                0) {
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
                    ref.read(futureGoalsProvider.notifier).updateGoal(
                      goal.id,
                      title: titleCtrl.text.trim(),
                      categories: selectedCategories.isEmpty
                          ? [FutureCategories.other]
                          : selectedCategories,
                      startSemester: startSemester,
                      endSemester: endSemester,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(s.save),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
