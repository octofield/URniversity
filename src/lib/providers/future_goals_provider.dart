import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/future_goal.dart';
import 'sort_prefs.dart';
import 'synced_list_notifier.dart';

class FutureGoalsNotifier extends SyncedListNotifier<FutureGoal> {
  FutureGoalsNotifier(super.ref)
      : super(
          table: 'future_goals',
          localKey: 'guest_future_goals',
          orderColumn: 'sort_order',
        );

  @override
  FutureGoal fromJson(Map<String, dynamic> json) => FutureGoal.fromJson(json);

  @override
  Map<String, dynamic> toJson(FutureGoal item) => item.toJson();

  @override
  String idOf(FutureGoal item) => item.id;

  @override
  String? parentIdOf(FutureGoal item) => item.parentId;

  // Restoring a child while its parent is still deleted would leave parentId
  // pointing at a row the foreign key can no longer resolve, so it goes back to
  // the top level instead (see system_design.md UC6)
  @override
  FutureGoal sanitizeForRestore(FutureGoal item) {
    final parent = item.parentId;
    if (parent == null || state.any((x) => x.id == parent)) return item;
    return item.copyWith(parentId: null);
  }

  void addGoal({
    String? parentId,
    required String title,
    List<String> categories = const [FutureCategories.other],
    String? startSemester,
    String? endSemester,
    String? notes,
  }) {
    // Newest first: one step before the smallest in its group, so a new vision
    // lands on top without moving anything the user has dragged
    final minOrder = state
        .where((g) => g.parentId == parentId)
        .fold(0, (prev, g) => g.sortOrder < prev ? g.sortOrder : prev);
    final goal = FutureGoal(
      id: newRowId(),
      parentId: parentId,
      title: title,
      categories: categories,
      startSemester: startSemester,
      endSemester: endSemester,
      notes: notes,
      sortOrder: minOrder - 1000,
    );
    state = [...state, goal];
    upsert(goal);
  }

  void updateGoal(
    String goalId, {
    required String title,
    required List<String> categories,
    String? startSemester,
    String? endSemester,
    String? notes,
  }) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          FutureGoal(
            id: g.id,
            parentId: g.parentId,
            title: title,
            categories: categories,
            startSemester: startSemester,
            endSemester: endSemester,
            notes: notes,
            isDone: g.isDone,
            sortOrder: g.sortOrder,
          )
        else
          g,
    ];
    final updated = state.where((g) => g.id == goalId).firstOrNull;
    if (updated != null) upsert(updated);
  }

  void toggleDone(String goalId) {
    state = [
      for (final g in state)
        if (g.id == goalId) g.copyWith(isDone: !g.isDone) else g,
    ];
    final updated = state.where((g) => g.id == goalId).firstOrNull;
    if (updated != null) upsert(updated);
  }

  List<FutureGoal> getWithDescendants(String goalId) {
    final result = <FutureGoal>[];
    void collect(String id) {
      final goal = state.where((g) => g.id == id).firstOrNull;
      if (goal == null) return;
      result.add(goal);
      for (final child in state.where((g) => g.parentId == id)) {
        collect(child.id);
      }
    }
    collect(goalId);
    return result;
  }

  // Returns every goal actually removed (the goal plus its whole subtree) so the
  // caller can snapshot all of them to the trash. Snapshotting only the root
  // lost every descendant permanently
  List<FutureGoal> remove(String goalId) {
    final removed = getWithDescendants(goalId);
    if (removed.isEmpty) return const [];
    final removedIds = removed.map((g) => g.id).toSet();
    state = state.where((g) => !removedIds.contains(g.id)).toList();
    for (final id in removedIds) {
      deleteRow(id);
    }
    return removed;
  }

  bool isAncestor(String potentialAncestorId, String targetId) {
    String? current = targetId;
    while (current != null) {
      final goal = state.where((g) => g.id == current).firstOrNull;
      if (goal == null) return false;
      if (goal.parentId == potentialAncestorId) return true;
      current = goal.parentId;
    }
    return false;
  }

  void reparent(String draggedId, String? newParentId, int newSortOrder) {
    if (draggedId == newParentId) return;
    if (newParentId != null && isAncestor(draggedId, newParentId)) return;
    state = [
      for (final g in state)
        if (g.id == draggedId)
          g.copyWith(parentId: newParentId, sortOrder: newSortOrder)
        else g,
    ];
    final updated = state.where((g) => g.id == draggedId).firstOrNull;
    if (updated != null) upsert(updated);
  }

}

final futureGoalsProvider =
    StateNotifierProvider<FutureGoalsNotifier, List<FutureGoal>>(
  (ref) => FutureGoalsNotifier(ref),
);

// How the visions page is ordered. Manual is the drag order; the rest switch
// dragging off, the same way the task list does
enum VisionSort { manual, title, startSemester, endSemester }

final visionSortProvider =
    StateNotifierProvider<EnumPrefNotifier<VisionSort>, VisionSort>(
  (ref) => EnumPrefNotifier('vision_sort', VisionSort.values, VisionSort.manual),
);

// Whether the visions page shows drag handles. Memory only, like the task one
final visionSortModeProvider = StateProvider<bool>((ref) => false);

// Orders one level of the tree. Ties keep the drag order, and a vision with no
// semester set goes after every one that has one
List<FutureGoal> applyVisionSort(List<FutureGoal> siblings, VisionSort sort) {
  final byOrder = [...siblings]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  if (sort == VisionSort.manual) return byOrder;

  final index = {for (var i = 0; i < byOrder.length; i++) byOrder[i].id: i};

  int bySemester(String? a, String? b) {
    if (a == null || b == null) {
      if (a == null && b == null) return 0;
      return a == null ? 1 : -1;
    }
    return compareSemesters(a, b);
  }

  int compare(FutureGoal a, FutureGoal b) => switch (sort) {
        VisionSort.title =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        VisionSort.startSemester => bySemester(a.startSemester, b.startSemester),
        VisionSort.endSemester => bySemester(a.endSemester, b.endSemester),
        VisionSort.manual => 0,
      };

  return byOrder
    ..sort((a, b) {
      final byKey = compare(a, b);
      return byKey != 0 ? byKey : index[a.id]!.compareTo(index[b.id]!);
    });
}
