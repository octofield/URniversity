import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/semester_goal.dart';
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

List<String> generateSemesters(SemesterSettings settings) {
  final curSem = currentSemester(settings);
  final curYear = int.parse(curSem.split('-')[0]);
  final n = settings.startMonths.length;
  final sems = <String>[];
  for (var ay = curYear - 4; ay <= curYear + 3; ay++) {
    for (var t = 1; t <= n; t++) {
      sems.add('$ay-$t');
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

class SemesterGoalsNotifier extends StateNotifier<List<SemesterGoal>> {
  SemesterGoalsNotifier() : super([]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await _db.from('semester_goals').select().eq('user_id', userId).order('sort_order');
      state = (rows as List<dynamic>)
          .map((r) => SemesterGoal.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _userId = null;
    }
  }

  void clear() {
    _userId = null;
    state = [];
  }

  void _upsert(SemesterGoal goal) {
    if (_userId == null) return;
    _db.from('semester_goals')
        .upsert({...goal.toJson(), 'user_id': _userId})
        .catchError((_) {});
  }

  void _delete(String id) {
    if (_userId == null) return;
    _db.from('semester_goals').delete().eq('id', id).catchError((_) {});
  }

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
    _upsert(goal);
  }

  void updateGoal(
    String goalId, {
    required String title,
    required List<String> categories,
    String? futureGoalId,
    String? notes,
  }) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          SemesterGoal(
            id: g.id,
            parentId: g.parentId,
            title: title,
            semester: g.semester,
            categories: categories.isEmpty ? ['other'] : categories,
            futureGoalId: futureGoalId,
            notes: notes,
            isDone: g.isDone,
          )
        else
          g,
    ];
    final updated = state.where((g) => g.id == goalId).firstOrNull;
    if (updated != null) _upsert(updated);
  }

  void toggleDone(String goalId) {
    state = [
      for (final g in state)
        if (g.id == goalId) g.copyWith(isDone: !g.isDone) else g,
    ];
    final updated = state.where((g) => g.id == goalId).firstOrNull;
    if (updated != null) _upsert(updated);
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

  void remove(String goalId) {
    final toRemove = getWithDescendants(goalId).map((g) => g.id).toSet();
    state = state.where((g) => !toRemove.contains(g.id)).toList();
    for (final id in toRemove) {
      _delete(id);
    }
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
    if (updated != null) _upsert(updated);
  }

  void linkFutureGoal(String goalId, String? futureGoalId) {
    state = [
      for (final g in state)
        if (g.id == goalId) g.copyWith(futureGoalId: futureGoalId) else g,
    ];
    final updated = state.where((g) => g.id == goalId).firstOrNull;
    if (updated != null) _upsert(updated);
  }

  void restore(SemesterGoal goal) {
    if (!state.any((g) => g.id == goal.id)) {
      final parentExists =
          goal.parentId == null || state.any((g) => g.id == goal.parentId);
      final restored = parentExists ? goal : goal.copyWith(parentId: null);
      state = [...state, restored];
      _upsert(restored);
    }
  }
}

final semesterGoalsProvider =
    StateNotifierProvider<SemesterGoalsNotifier, List<SemesterGoal>>(
  (ref) => SemesterGoalsNotifier(),
);
