import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/future_goal.dart';

class FutureGoalsNotifier extends StateNotifier<List<FutureGoal>> {
  FutureGoalsNotifier() : super([]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;
  static const _localKey = 'guest_future_goals';
  bool get _isGuest => _userId == 'guest';

  Future<void> loadGuest() async {
    _userId = 'guest';
    final p = await SharedPreferences.getInstance();
    final json = p.getString(_localKey);
    if (json != null) {
      state = (jsonDecode(json) as List)
          .map((j) => FutureGoal.fromJson(j as Map<String, dynamic>))
          .toList();
    } else {
      state = [];
    }
  }

  void _persistLocally() {
    SharedPreferences.getInstance().then((p) {
      p.setString(_localKey, jsonEncode(state.map((g) => g.toJson()).toList()));
    });
  }

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await _db.from('future_goals').select().eq('user_id', userId).order('sort_order');
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

  Future<void> mergeToUser(String userId) async {
    _userId = userId;
    for (final goal in state) {
      try {
        await _db.from('future_goals').upsert({...goal.toJson(), 'user_id': userId});
      } catch (_) {}
    }
  }

  void _upsert(FutureGoal goal) {
    if (_isGuest) { _persistLocally(); return; }
    if (_userId == null) return;
    _db.from('future_goals')
        .upsert({...goal.toJson(), 'user_id': _userId})
        .catchError((_) {});
  }

  void _delete(String id) {
    if (_isGuest) { _persistLocally(); return; }
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
            sortOrder: g.sortOrder,
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
