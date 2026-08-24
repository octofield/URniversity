import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester_goal.dart';
import 'synced_list_notifier.dart';
import 'settings_provider.dart';

String currentSemester(SemesterSettings settings) {
  final now = DateTime.now();
  final rocYear = now.year - 1911;

  String result = '${rocYear - 1}-1';
  DateTime resultStart = DateTime(2000);

  for (int ay = rocYear - 1; ay <= rocYear + 1; ay++) {
    int yearOffset = 0;
    for (int t = 0; t < settings.startMonths.length; t++) {
      if (t > 0 && settings.startMonths[t] <= settings.startMonths[t - 1]) yearOffset++;
      final semStart = DateTime(ay + 1911 + yearOffset, settings.startMonths[t]);
      if (!semStart.isAfter(now) && semStart.isAfter(resultStart)) {
        resultStart = semStart;
        result = '$ay-${t + 1}';
      }
    }
  }

  return result;
}

// Interleaves each semester with the break immediately following it
// ("Y-1", "Y-B1", "Y-2", "Y-B2", ...); the break after the last semester
// ("Y-B{n}") is always the long break before next year's semester 1 restarts.
List<String> generateSemesters(SemesterSettings settings) {
  final curSem = currentSemester(settings);
  final curYear = int.parse(curSem.split('-')[0]);
  final n = settings.startMonths.length;
  final sems = <String>[];
  for (var ay = curYear - 4; ay <= curYear + 3; ay++) {
    for (var t = 1; t <= n; t++) {
      sems.add('$ay-$t');
      sems.add('$ay-B$t');
    }
  }
  return sems;
}

final currentSemesterProvider = Provider<String>((ref) {
  final settings = ref.watch(semesterSettingsProvider);
  return currentSemester(settings);
});

final selectedSemesterProvider = StateProvider<String>(
  (ref) => ref.read(currentSemesterProvider),
);

class SemesterGoalsNotifier extends SyncedListNotifier<SemesterGoal> {
  SemesterGoalsNotifier(super.ref)
      : super(
          table: 'semester_goals',
          localKey: 'guest_sem_goals',
          orderColumn: 'sort_order',
        );

  @override
  SemesterGoal fromJson(Map<String, dynamic> json) => SemesterGoal.fromJson(json);

  @override
  Map<String, dynamic> toJson(SemesterGoal item) => item.toJson();

  @override
  String idOf(SemesterGoal item) => item.id;

  void addGoal(
    String title,
    String semester, {
    String? parentId,
    List<String> categories = const [],
    String? futureGoalId,
    String? notes,
  }) {
    final maxOrder = state
        .where((g) => g.parentId == parentId && g.semester == semester)
        .fold(0, (prev, g) => g.sortOrder > prev ? g.sortOrder : prev);
    final goal = SemesterGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      parentId: parentId,
      title: title,
      semester: semester,
      categories: categories.isEmpty ? ['other'] : categories,
      futureGoalId: futureGoalId,
      notes: notes,
      sortOrder: maxOrder + 1000,
    );
    state = [...state, goal];
    upsert(goal);
  }

  void updateGoal(
    String goalId, {
    required String title,
    required String semester,
    required List<String> categories,
    String? futureGoalId,
    String? notes,
  }) {
    final old = state.where((g) => g.id == goalId).firstOrNull;
    if (old == null) return;

    // Moving to another semester puts the goal last in that semester's list;
    // sortOrder is only meaningful within one (parentId, semester) group
    final movedSemester = old.semester != semester;
    final newSortOrder = movedSemester
        ? state
                .where((g) => g.parentId == old.parentId && g.semester == semester)
                .fold(0, (prev, g) => g.sortOrder > prev ? g.sortOrder : prev) +
            1000
        : old.sortOrder;
    // Descendants follow their parent so the whole subtree stays in one semester
    final subtree = movedSemester
        ? getWithDescendants(goalId).map((g) => g.id).toSet()
        : <String>{};

    state = [
      for (final g in state)
        if (g.id == goalId)
          SemesterGoal(
            id: g.id,
            parentId: g.parentId,
            title: title,
            semester: semester,
            categories: categories.isEmpty ? ['other'] : categories,
            futureGoalId: futureGoalId,
            notes: notes,
            isDone: g.isDone,
            sortOrder: newSortOrder,
          )
        else if (subtree.contains(g.id))
          g.copyWith(semester: semester)
        else
          g,
    ];
    for (final g in state.where((g) => g.id == goalId || subtree.contains(g.id))) {
      upsert(g);
    }
  }

  void toggleDone(String goalId) {
    state = [
      for (final g in state)
        if (g.id == goalId) g.copyWith(isDone: !g.isDone) else g,
    ];
    final updated = state.where((g) => g.id == goalId).firstOrNull;
    if (updated != null) upsert(updated);
  }

  List<SemesterGoal> getWithDescendants(String goalId) {
    final result = <SemesterGoal>[];
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
  List<SemesterGoal> remove(String goalId) {
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
          // Becoming a milestone drops the vision link: only top-level goals
          // carry one, and leaving it set would make it unreachable from the UI
          g.copyWith(
            parentId: newParentId,
            sortOrder: newSortOrder,
            futureGoalId: newParentId == null ? g.futureGoalId : null,
          )
        else g,
    ];
    final updated = state.where((g) => g.id == draggedId).firstOrNull;
    if (updated != null) upsert(updated);
  }

  // Only top-level goals carry a vision link; a milestone takes its context from
  // its parent. Enforced here so no caller can route around it
  void linkFutureGoal(String goalId, String? futureGoalId) {
    if (futureGoalId != null) {
      final goal = state.where((g) => g.id == goalId).firstOrNull;
      if (goal == null || goal.parentId != null) return;
    }
    state = [
      for (final g in state)
        if (g.id == goalId) g.copyWith(futureGoalId: futureGoalId) else g,
    ];
    final updated = state.where((g) => g.id == goalId).firstOrNull;
    if (updated != null) upsert(updated);
  }

}

final semesterGoalsProvider =
    StateNotifierProvider<SemesterGoalsNotifier, List<SemesterGoal>>(
  (ref) => SemesterGoalsNotifier(ref),
);
