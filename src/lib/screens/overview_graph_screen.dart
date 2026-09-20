import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/ui_symbols.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/home_tab_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/hover_lift.dart';
import 'future_goal_detail_screen.dart';
import 'semester_goal_detail_screen.dart';

// Node box sizes and layout spacing
const _futureNodeW = 190.0;
const _futureNodeH = 56.0;
const _semNodeW = 170.0;
const _semNodeH = 52.0;
const _hGap = 20.0;
const _rowH = 104.0; // Max node height plus vertical gap between layers
const _ringStep = 140.0; // Minimum radius increase between radial rings
const _framePad = 16.0;
const _compGap = 32.0;

class OverviewGraphScreen extends ConsumerStatefulWidget {
  const OverviewGraphScreen({super.key});

  @override
  ConsumerState<OverviewGraphScreen> createState() =>
      _OverviewGraphScreenState();
}

// What the graph is showing. "All" is everything; the rest answer a question
// the user came with — what am I doing this semester, what is still open, what
// have I not connected to anything yet
enum _GraphFilter { all, currentSemester, unfinished, unlinked }

class _OverviewGraphScreenState extends ConsumerState<OverviewGraphScreen>
    with SingleTickerProviderStateMixin {
  bool _radial = false;
  _GraphFilter _filter = _GraphFilter.all;
  // The node whose summary card is open; tapping the canvas closes it
  String? _selectedId;
  late final AnimationController _particleCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final allFutures = ref.watch(futureGoalsProvider);
    final allSemesters = ref.watch(semesterGoalsProvider);
    final tasks = ref.watch(tasksProvider);
    final semSettings = ref.watch(semesterSettingsProvider);
    final cats = ref.watch(categoriesProvider);

    // The filter narrows the semester goals; a vision stays as long as one of
    // the remaining goals still hangs off it, so the tree never loses its roots
    final thisSemester = currentSemester(semSettings);
    final semesters = switch (_filter) {
      _GraphFilter.currentSemester =>
        allSemesters.where((g) => g.semester == thisSemester).toList(),
      _GraphFilter.unfinished => allSemesters.where((g) => !g.isDone).toList(),
      _GraphFilter.unlinked => allSemesters
          .where((g) => g.parentId == null && g.futureGoalId == null)
          .toList(),
      _GraphFilter.all => allSemesters,
    };
    final keptVisionIds = {for (final g in semesters) g.futureGoalId};
    final futures = switch (_filter) {
      _GraphFilter.all => allFutures,
      _GraphFilter.unlinked => const <FutureGoal>[],
      _GraphFilter.unfinished => allFutures
          .where((g) => !g.isDone || keptVisionIds.contains(g.id))
          .toList(),
      _GraphFilter.currentSemester =>
        allFutures.where((g) => keptVisionIds.contains(g.id)).toList(),
    };

    // Linked task counts shown as node badges
    final taskCounts = <String, int>{};
    for (final t in tasks) {
      if (t.linkedTargetId != null) {
        taskCounts[t.linkedTargetId!] = (taskCounts[t.linkedTargetId!] ?? 0) + 1;
      }
    }

    // Deterministic node order keeps the layout stable between visits
    final nodes = <_GraphNode>[
      for (final g in [...futures]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        _GraphNode.future(g),
      for (final g in [...semesters]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        _GraphNode.semester(g),
    ];
    final futureIds = {for (final g in futures) g.id};
    final semIds = {for (final g in semesters) g.id};
    final edges = <_GraphEdge>[
      for (final g in futures)
        if (g.parentId != null && futureIds.contains(g.parentId))
          _GraphEdge(from: g.parentId!, to: g.id),
      for (final g in semesters) ...[
        if (g.parentId != null && semIds.contains(g.parentId))
          _GraphEdge(from: g.parentId!, to: g.id),
        if (g.futureGoalId != null && futureIds.contains(g.futureGoalId))
          _GraphEdge(from: g.futureGoalId!, to: g.id, isLink: true),
      ],
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            Text(s.overview),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.account_tree_outlined, size: 18)),
                ButtonSegment(
                    value: true, icon: Icon(Icons.hub_outlined, size: 18)),
              ],
              selected: {_radial},
              onSelectionChanged: (v) => setState(() => _radial = v.first),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(
            current: _filter,
            s: s,
            onSelect: (f) => setState(() {
              _filter = f;
              _selectedId = null;
            }),
          ),
          Expanded(
            child: Stack(
              children: [
                nodes.isEmpty
          ? EmptyState(icon: Icons.hub_outlined, message: s.overviewEmpty)
          : LayoutBuilder(
              builder: (context, constraints) {
                final layout = _layoutGraph(
                  nodes: nodes,
                  edges: edges,
                  targetWidth: max(
                      600.0, constraints.maxWidth - AppSpacing.pageHorizontal * 2),
                  radial: _radial,
                );
                return InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(240),
                  minScale: 0.3,
                  maxScale: 2.5,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SizedBox(
                      width: layout.size.width,
                      height: layout.size.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final rect in layout.componentRects)
                            Positioned.fromRect(
                              rect: rect,
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.surface.withValues(alpha: 0.6),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(color: AppColors.border),
                                ),
                              ),
                            ),
                          if (layout.unlinkedRect != null) ...[
                            Positioned.fromRect(
                              rect: layout.unlinkedRect!,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(color: AppColors.border),
                                ),
                              ),
                            ),
                            Positioned(
                              left: layout.unlinkedRect!.left + _framePad,
                              top: layout.unlinkedRect!.top + 10,
                              child: Text(
                                s.unlinked,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _EdgePainter(
                                edges: edges,
                                byId: layout.byId,
                                radial: _radial,
                                particles: _particleCtrl,
                              ),
                            ),
                          ),
                          for (final node in layout.nodes)
                            Positioned(
                              left: node.x,
                              top: node.y,
                              child: _NodeCard(
                                node: node,
                                taskCount: taskCounts[node.id] ?? 0,
                                selected: node.id == _selectedId,
                                onTap: () => setState(() => _selectedId =
                                    node.id == _selectedId ? null : node.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
                if (nodes.isNotEmpty)
                  Positioned(
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    child: _Legend(s: s),
                  ),
              ],
            ),
          ),
          if (_selectedId != null)
            _SummaryCard(
              key: ValueKey(_selectedId),
              nodeId: _selectedId!,
              futures: allFutures,
              semesters: allSemesters,
              tasks: tasks,
              cats: cats,
              settings: semSettings,
              s: s,
              onClose: () => setState(() => _selectedId = null),
            ),
        ],
      ),
    );
  }
}

// Which slice of the graph to draw
class _FilterChips extends StatelessWidget {
  final _GraphFilter current;
  final AppStrings s;
  final ValueChanged<_GraphFilter> onSelect;

  const _FilterChips({
    required this.current,
    required this.s,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {
      _GraphFilter.all: s.catAll,
      _GraphFilter.currentSemester: s.backToCurrentSem,
      _GraphFilter.unfinished: s.graphFilterUnfinished,
      _GraphFilter.unlinked: s.unlinked,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            ChoiceChip(
              label: Text(entry.value),
              selected: current == entry.key,
              onSelected: (_) => onSelect(entry.key),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

// What the shapes on the canvas mean. Small enough to leave on screen: the
// first question about this page was always "what is the number for?"
class _Legend extends StatelessWidget {
  final AppStrings s;

  const _Legend({required this.s});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.graphLegend,
            style: style?.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
              ),
              const SizedBox(width: 4),
              Text(s.goals, style: style),
              const SizedBox(width: 10),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 4),
              Text(s.targets, style: style),
            ],
          ),
          const SizedBox(height: 2),
          Text(s.graphLegendTaskCount, style: style),
          Text(s.graphLegendDimmed, style: style),
        ],
      ),
    );
  }
}

// What a tapped node actually amounts to: how far along it is, what hangs off
// it, and when the next thing is due. Tapping a node used to leave the page
// immediately, which made the graph something you passed through
class _SummaryCard extends ConsumerWidget {
  final String nodeId;
  final List<FutureGoal> futures;
  final List<SemesterGoal> semesters;
  final List<Task> tasks;
  final List<CategoryEntry> cats;
  final SemesterSettings settings;
  final AppStrings s;
  final VoidCallback onClose;

  const _SummaryCard({
    super.key,
    required this.nodeId,
    required this.futures,
    required this.semesters,
    required this.tasks,
    required this.cats,
    required this.settings,
    required this.s,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vision = futures.where((g) => g.id == nodeId).firstOrNull;
    final target = semesters.where((g) => g.id == nodeId).firstOrNull;
    if (vision == null && target == null) return const SizedBox.shrink();

    final isVision = vision != null;
    final title = isVision ? vision.title : target!.title;
    final colour = goalEffectiveColor(
          cats,
          isVision ? vision.categories : target!.categories,
          linkedVision: isVision
              ? null
              : futures.where((g) => g.id == target!.futureGoalId).firstOrNull,
        ) ??
        AppColors.border;

    // Children: sub-visions under a vision, milestones under a target
    final children = isVision
        ? futures.where((g) => g.parentId == nodeId).length
        : semesters.where((g) => g.parentId == nodeId).length;
    final childrenDone = isVision
        ? futures.where((g) => g.parentId == nodeId && g.isDone).length
        : semesters.where((g) => g.parentId == nodeId && g.isDone).length;

    // Tasks hang off targets only; a vision counts the tasks of every target
    // linked to it
    final targetIds = isVision
        ? semesters.where((g) => g.futureGoalId == nodeId).map((g) => g.id).toSet()
        : {nodeId};
    final linked = tasks.where((t) => targetIds.contains(t.linkedTargetId)).toList();
    final open = linked.where((t) => !t.isCompleted).toList();
    final nextDue = open
        .where((t) => t.dueTime != null)
        .map((t) => t.dueTime!)
        .fold<DateTime?>(null, (soonest, due) =>
            soonest == null || due.isBefore(soonest) ? due : soonest);

    final parentVision = !isVision && target!.futureGoalId != null
        ? futures.where((g) => g.id == target.futureGoalId).firstOrNull
        : null;
    final subtitle = [
      if (!isVision) formatSemester(target!.semester, settings, s),
      if (parentVision != null) '$kArrow ${parentVision.title}',
    ].join(kDotSeparator);

    final progress = children == 0 ? null : childrenDone / children;

    return Container(
      width: double.infinity,
      // Clears the Android navigation bar, which this card sits right above
      margin: EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0,
          AppSpacing.pageHorizontal,
          AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (progress != null)
                Text(
                  s.percentSuffix((progress * 100).round()),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: colour,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _MiniStat(
                label: isVision ? s.targets : s.milestones,
                value: children == 0
                    ? kEmptyValue
                    : s.goalProgress(childrenDone, children),
              ),
              _MiniStat(label: s.tasks, value: '${open.length}'),
              _MiniStat(
                label: s.graphNextDue,
                value: nextDue == null
                    ? kEmptyValue
                    : '${nextDue.month}/${nextDue.day}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isVision
                          ? FutureGoalDetailScreen(goalId: nodeId)
                          : SemesterGoalDetailScreen(goalId: nodeId),
                    ),
                  ),
                  child: Text(s.graphOpen),
                ),
              ),
              if (open.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Land on the task list already filtered to this branch
                      ref.read(taskTargetFilterProvider.notifier).state =
                          targetIds.whereType<String>().toSet();
                      ref.read(pendingTabProvider.notifier).state = 0;
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Text(s.graphViewTasks(open.length)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Graph model ──────────────────────────────────────────────────────────────

class _GraphNode {
  final String id;
  final FutureGoal? future;
  final SemesterGoal? semester;
  int layer = 0;
  double x = 0;
  double y = 0;

  _GraphNode.future(FutureGoal g)
      : id = g.id,
        future = g,
        semester = null;
  _GraphNode.semester(SemesterGoal g)
      : id = g.id,
        future = null,
        semester = g;

  bool get isFuture => future != null;
  double get width => isFuture ? _futureNodeW : _semNodeW;
  double get height => isFuture ? _futureNodeH : _semNodeH;
  Offset get center => Offset(x + width / 2, y + height / 2);
  String get title => future?.title ?? semester!.title;
  bool get isDone => future?.isDone ?? semester!.isDone;
  String get category {
    final cats = future?.categories ?? semester!.categories;
    return cats.isNotEmpty ? cats.first : FutureCategories.other;
  }
}

class _GraphEdge {
  final String from;
  final String to;
  final bool isLink; // Cross link from a future goal down to a semester goal

  const _GraphEdge({required this.from, required this.to, this.isLink = false});
}

class _GraphLayout {
  final Size size;
  final List<_GraphNode> nodes;
  final Map<String, _GraphNode> byId;
  final List<Rect> componentRects;
  final Rect? unlinkedRect;

  const _GraphLayout({
    required this.size,
    required this.nodes,
    required this.byId,
    required this.componentRects,
    required this.unlinkedRect,
  });
}

// ─── Layout algorithms ────────────────────────────────────────────────────────

class _UnionFind {
  final Map<String, String> _parent = {};

  String find(String x) {
    var root = x;
    while ((_parent[root] ?? root) != root) {
      root = _parent[root]!;
    }
    var cur = x;
    while (cur != root) {
      final next = _parent[cur]!;
      _parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(String a, String b) {
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) _parent[ra] = rb;
  }
}

// Longest-path layering: layer = max(parent layers) + 1, roots at 0
Map<String, int> _assignLayers(
    List<_GraphNode> cluster, Map<String, List<String>> incoming) {
  final layers = <String, int>{};
  final onStack = <String>{};

  int layerOf(String id) {
    final cached = layers[id];
    if (cached != null) return cached;
    if (!onStack.add(id)) return 0; // Cycle guard
    var layer = 0;
    for (final parent in incoming[id] ?? const <String>[]) {
      layer = max(layer, layerOf(parent) + 1);
    }
    onStack.remove(id);
    layers[id] = layer;
    return layer;
  }

  for (final n in cluster) {
    layerOf(n.id);
  }
  return layers;
}

// Barycenter heuristic: sort each layer by the average position of neighbors
void _reduceCrossings(
    List<List<_GraphNode>> byLayer, Map<String, List<String>> neighbors) {
  final pos = <String, double>{};
  void refresh(List<_GraphNode> layer) {
    for (var i = 0; i < layer.length; i++) {
      pos[layer[i].id] = i.toDouble();
    }
  }

  byLayer.forEach(refresh);

  for (var pass = 0; pass < 3; pass++) {
    for (final layer in byLayer) {
      final bary = <String, double>{};
      for (var i = 0; i < layer.length; i++) {
        final vals = [
          for (final m in neighbors[layer[i].id] ?? const <String>[]) pos[m],
        ].whereType<double>().toList();
        bary[layer[i].id] = vals.isEmpty
            ? i.toDouble()
            : vals.reduce((a, b) => a + b) / vals.length;
      }
      layer.sort((a, b) => bary[a.id]!.compareTo(bary[b.id]!));
      refresh(layer);
    }
  }
}

// Layered placement: goals on top, linked targets below, centered per layer
Size _placeLayered(
  List<_GraphNode> cluster,
  Map<String, List<String>> incoming,
  Map<String, List<String>> neighbors,
) {
  final layers = _assignLayers(cluster, incoming);
  final maxLayer = layers.values.fold(0, max);
  final byLayer = List.generate(maxLayer + 1, (_) => <_GraphNode>[]);
  for (final n in cluster) {
    n.layer = layers[n.id]!;
    byLayer[n.layer].add(n);
  }
  _reduceCrossings(byLayer, neighbors);

  double layerWidth(List<_GraphNode> layer) =>
      layer.fold(0.0, (w, n) => w + n.width) + _hGap * (layer.length - 1);
  final compW = byLayer.fold(0.0, (w, l) => max(w, layerWidth(l)));
  for (var li = 0; li < byLayer.length; li++) {
    var x = (compW - layerWidth(byLayer[li])) / 2;
    for (final n in byLayer[li]) {
      n.x = x;
      n.y = li * _rowH;
      x += n.width + _hGap;
    }
  }
  return Size(compW, maxLayer * _rowH + _futureNodeH);
}

// Radial placement: the root future goal sits in the middle, everything
// connected orbits it in BFS rings, branches kept angularly together
Size _placeRadial(
  List<_GraphNode> cluster,
  Map<String, List<String>> incoming,
  Map<String, List<String>> neighbors,
) {
  final byIdLocal = {for (final n in cluster) n.id: n};

  // Center: prefer a future-goal root, break ties by connection count
  var center = cluster.first;
  var bestScore = -1;
  for (final n in cluster) {
    final isRoot = n.isFuture && (incoming[n.id]?.isEmpty ?? true);
    final score = (isRoot ? 1000 : 0) + (neighbors[n.id]?.length ?? 0);
    if (score > bestScore) {
      bestScore = score;
      center = n;
    }
  }

  // BFS rings with parent tracking for angular grouping
  final dist = <String, int>{center.id: 0};
  final bfsParent = <String, String>{};
  final queue = <String>[center.id];
  var qi = 0;
  while (qi < queue.length) {
    final cur = queue[qi++];
    for (final nb in neighbors[cur] ?? const <String>[]) {
      if (!byIdLocal.containsKey(nb) || dist.containsKey(nb)) continue;
      dist[nb] = dist[cur]! + 1;
      bfsParent[nb] = cur;
      queue.add(nb);
    }
  }
  final maxD = dist.values.fold(0, max);
  final rings = List.generate(maxD + 1, (_) => <_GraphNode>[]);
  for (final n in cluster) {
    rings[dist[n.id] ?? maxD].add(n);
  }

  // Assign angles ring by ring; children sorted by their parent's angle
  final angle = <String, double>{center.id: 0};
  final radius = <int, double>{0: 0};
  for (var d = 1; d <= maxD; d++) {
    final ring = rings[d];
    final orderIdx = {for (var i = 0; i < ring.length; i++) ring[i].id: i};
    ring.sort((a, b) {
      final pa = angle[bfsParent[a.id]] ?? 0.0;
      final pb = angle[bfsParent[b.id]] ?? 0.0;
      final c = pa.compareTo(pb);
      return c != 0 ? c : orderIdx[a.id]!.compareTo(orderIdx[b.id]!);
    });
    final maxW = ring.fold(0.0, (w, n) => max(w, n.width));
    final need = ring.length * (maxW + _hGap) / (2 * pi);
    radius[d] = max(radius[d - 1]! + _ringStep, need);
    for (var i = 0; i < ring.length; i++) {
      angle[ring[i].id] = 2 * pi * i / ring.length - pi / 2;
    }
  }

  // Positions relative to the center, then shift into the positive quadrant
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final n in cluster) {
    final a = angle[n.id] ?? 0.0;
    final r = radius[dist[n.id] ?? 0] ?? 0.0;
    n.x = cos(a) * r - n.width / 2;
    n.y = sin(a) * r - n.height / 2;
    minX = min(minX, n.x);
    minY = min(minY, n.y);
    maxX = max(maxX, n.x + n.width);
    maxY = max(maxY, n.y + n.height);
  }
  for (final n in cluster) {
    n.x -= minX;
    n.y -= minY;
  }
  return Size(maxX - minX, maxY - minY);
}

_GraphLayout _layoutGraph({
  required List<_GraphNode> nodes,
  required List<_GraphEdge> edges,
  required double targetWidth,
  required bool radial,
}) {
  final byId = {for (final n in nodes) n.id: n};

  // 1. Connected components via union-find
  final uf = _UnionFind();
  for (final e in edges) {
    uf.union(e.from, e.to);
  }
  final components = <String, List<_GraphNode>>{};
  for (final n in nodes) {
    components.putIfAbsent(uf.find(n.id), () => []).add(n);
  }
  final clusters = components.values.where((c) => c.length > 1).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final isolated = [
    for (final c in components.values)
      if (c.length == 1) c.first,
  ];

  // 2. Adjacency maps
  final incoming = <String, List<String>>{};
  final neighbors = <String, List<String>>{};
  for (final e in edges) {
    incoming.putIfAbsent(e.to, () => []).add(e.from);
    neighbors.putIfAbsent(e.to, () => []).add(e.from);
    neighbors.putIfAbsent(e.from, () => []).add(e.to);
  }

  // 3. Place each cluster in local coordinates with the chosen algorithm
  final compSizes = <Size>[
    for (final cluster in clusters)
      radial
          ? _placeRadial(cluster, incoming, neighbors)
          : _placeLayered(cluster, incoming, neighbors),
  ];

  // 4. Shelf-pack cluster frames onto the canvas
  final componentRects = <Rect>[];
  var cursorX = 0.0, cursorY = 0.0, shelfH = 0.0, canvasW = 0.0;
  for (var i = 0; i < clusters.length; i++) {
    final frameW = compSizes[i].width + _framePad * 2;
    final frameH = compSizes[i].height + _framePad * 2;
    if (cursorX > 0 && cursorX + frameW > targetWidth) {
      cursorX = 0;
      cursorY += shelfH + _compGap;
      shelfH = 0;
    }
    final rect = Rect.fromLTWH(cursorX, cursorY, frameW, frameH);
    componentRects.add(rect);
    for (final n in clusters[i]) {
      n.x += rect.left + _framePad;
      n.y += rect.top + _framePad;
    }
    cursorX += frameW + _compGap;
    shelfH = max(shelfH, frameH);
    canvasW = max(canvasW, rect.right);
  }
  var totalH = clusters.isEmpty ? 0.0 : cursorY + shelfH;

  // 5. Isolated nodes wrap into their own section at the bottom
  Rect? unlinkedRect;
  if (isolated.isNotEmpty) {
    final startY = totalH + (clusters.isEmpty ? 0 : _compGap);
    var ux = _framePad;
    var uy = startY + _framePad + 22; // Room for the section label
    var rowMax = 0.0, maxRight = 0.0;
    for (final n in isolated) {
      if (ux > _framePad && ux + n.width + _framePad > targetWidth) {
        ux = _framePad;
        uy += rowMax + _hGap;
        rowMax = 0;
      }
      n.x = ux;
      n.y = uy;
      ux += n.width + _hGap;
      rowMax = max(rowMax, n.height);
      maxRight = max(maxRight, n.x + n.width + _framePad);
    }
    unlinkedRect = Rect.fromLTRB(0, startY, maxRight, uy + rowMax + _framePad);
    canvasW = max(canvasW, unlinkedRect.right);
    totalH = unlinkedRect.bottom;
  }

  return _GraphLayout(
    size: Size(max(canvasW, 300), max(totalH, 100)),
    nodes: nodes,
    byId: byId,
    componentRects: componentRects,
    unlinkedRect: unlinkedRect,
  );
}

// ─── Rendering ────────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  final List<_GraphEdge> edges;
  final Map<String, _GraphNode> byId;
  final bool radial;
  final Animation<double> particles;

  _EdgePainter({
    required this.edges,
    required this.byId,
    required this.radial,
    required this.particles,
  }) : super(repaint: particles);

  @override
  void paint(Canvas canvas, Size size) {
    final treePaint = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final linkPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final arrowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.75);
    final t = particles.value;

    for (final e in edges) {
      final from = byId[e.from];
      final to = byId[e.to];
      if (from == null || to == null) continue;

      Path path;
      if (radial) {
        // Center-to-center straight edges; node cards cover the endpoints
        final p0 = from.center;
        final p1 = to.center;
        path = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy);
      } else {
        final p0 = Offset(from.x + from.width / 2, from.y + from.height);
        final p1 = Offset(to.x + to.width / 2, to.y);
        final bend = (p1.dy - p0.dy) / 2;
        path = Path()
          ..moveTo(p0.dx, p0.dy)
          ..cubicTo(p0.dx, p0.dy + bend, p1.dx, p1.dy - bend, p1.dx, p1.dy);
        if (e.isLink) {
          final arrow = Path()
            ..moveTo(p1.dx - 4, p1.dy - 7)
            ..lineTo(p1.dx + 4, p1.dy - 7)
            ..lineTo(p1.dx, p1.dy)
            ..close();
          canvas.drawPath(arrow, arrowPaint);
        }
      }
      canvas.drawPath(e.isLink ? _dashed(path) : path,
          e.isLink ? linkPaint : treePaint);

      // Flowing particles from source to target along the edge
      final core = e.isLink ? AppColors.primary : AppColors.textSecondary;
      final glowPaint = Paint()..color = core.withValues(alpha: 0.25);
      final corePaint = Paint()..color = core.withValues(alpha: 0.9);
      for (final metric in path.computeMetrics()) {
        for (var i = 0; i < 2; i++) {
          final f = (t + i / 2) % 1.0;
          final pos = metric.getTangentForOffset(metric.length * f)?.position;
          if (pos == null) continue;
          canvas.drawCircle(pos, 3.2, glowPaint);
          canvas.drawCircle(pos, 1.7, corePaint);
        }
      }
    }
  }

  Path _dashed(Path source, {double dash = 6, double gap = 4}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        dest.addPath(
            metric.extractPath(d, min(d + dash, metric.length)), Offset.zero);
        d += dash + gap;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.edges != edges ||
      oldDelegate.byId != byId ||
      oldDelegate.radial != radial;
}

class _NodeCard extends ConsumerWidget {
  final _GraphNode node;
  final int taskCount;
  final bool selected;
  final VoidCallback onTap;

  const _NodeCard({
    required this.node,
    required this.taskCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final semSettings = ref.watch(semesterSettingsProvider);
    final s = ref.watch(stringsProvider);
    final catC = resolveCatColor(cats, node.category);
    final subtitle = node.isFuture
        ? [
            if (node.future!.startSemester != null)
              formatSemester(node.future!.startSemester!, semSettings, s),
            if (node.future!.startSemester != null &&
                node.future!.endSemester != null)
              kArrow,
            if (node.future!.endSemester != null)
              formatSemester(node.future!.endSemester!, semSettings, s),
          ].join(' ')
        : formatSemester(node.semester!.semester, semSettings, s);

    return SizedBox(
      width: node.width,
      height: node.height,
      child: HoverLift(
        radius: AppRadius.md,
        child: Material(
          color: node.isFuture
              ? Color.alphaBlend(
                  catC.withValues(alpha: 0.12), AppColors.surface)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : node.isFuture
                          ? catC.withValues(alpha: 0.7)
                          : AppColors.border,
                  width: selected ? 2 : (node.isFuture ? 1.5 : 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    resolveCatIcon(cats, node.category),
                    size: node.isFuture ? 18 : 15,
                    color: node.isDone ? AppColors.textTertiary : catC,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: node.isFuture ? 13.5 : 12.5,
                            fontWeight:
                                node.isFuture ? FontWeight.w700 : FontWeight.w600,
                            color: node.isDone
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                            decoration:
                                node.isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // Graph node labels are sized to the node box, not
                            // to the type scale
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (taskCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '$taskCount',
                        // Sized to the count badge, not to the type scale
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  if (node.isDone)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.check_circle,
                          size: 14, color: AppColors.success),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
