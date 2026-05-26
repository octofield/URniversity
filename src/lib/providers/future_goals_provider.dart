import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/future_goal.dart';

class FutureGoalsNotifier extends StateNotifier<List<FutureGoal>> {
  FutureGoalsNotifier() : super([]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await _db.from('future_goals').select().eq('user_id', userId);
      state = (rows as List<dynamic>)
          .map((r) => FutureGoal.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _userId = null;
    }
  }

  void clear() {
    _userId = null;
    state = [];
  }

  void _upsert(FutureGoal goal) {
    if (_userId == null) return;
    _db.from('future_goals')
        .upsert({...goal.toJson(), 'user_id': _userId})
        .catchError((_) {});
  }

  void _delete(String id) {
    if (_userId == null) return;
    _db.from('future_goals').delete().eq('id', id).catchError((_) {});
  }

  void addGoal({
    String? parentId,
    required String title,
    List<String> categories = const [FutureCategories.other],
    String? startSemester,
    String? endSemester,
    String? notes,
  }) {
    final goal = FutureGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      parentId: parentId,
      title: title,
      categories: categories,
      startSemester: startSemester,
      endSemester: endSemester,
      notes: notes,
    );
    state = [...state, goal];
    _upsert(goal);
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

  void remove(String goalId) {
    final toRemove = getWithDescendants(goalId).map((g) => g.id).toSet();
    state = state.where((g) => !toRemove.contains(g.id)).toList();
    for (final id in toRemove) {
      _delete(id);
    }
  }

  void restore(FutureGoal goal) {
    if (!state.any((g) => g.id == goal.id)) {
      final parentExists =
          goal.parentId == null || state.any((g) => g.id == goal.parentId);
      final restored = parentExists ? goal : goal.copyWith(parentId: null);
      state = [...state, restored];
      _upsert(restored);
    }
  }
}

final futureGoalsProvider =
    StateNotifierProvider<FutureGoalsNotifier, List<FutureGoal>>(
  (ref) => FutureGoalsNotifier(),
);
