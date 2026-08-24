import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/future_goal.dart';
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

  void addGoal({
    String? parentId,
    required String title,
    List<String> categories = const [FutureCategories.other],
    String? startSemester,
    String? endSemester,
    String? notes,
  }) {
    final maxOrder = state
        .where((g) => g.parentId == parentId)
        .fold(0, (prev, g) => g.sortOrder > prev ? g.sortOrder : prev);
    final goal = FutureGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      parentId: parentId,
      title: title,
      categories: categories,
      startSemester: startSemester,
      endSemester: endSemester,
      notes: notes,
      sortOrder: maxOrder + 1000,
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
