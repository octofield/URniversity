import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trash_item.dart';
import '../models/task.dart';
import '../models/semester_goal.dart';
import '../models/future_goal.dart';

class TrashNotifier extends StateNotifier<List<TrashItem>> {
  TrashNotifier() : super([]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await _db.from('trash_items').select().eq('user_id', userId);
      state = (rows as List<dynamic>)
          .map((r) => TrashItem.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _userId = null;
    }
  }

  void clear() {
    _userId = null;
    state = [];
  }

  void _insertRow(TrashItem item) {
    if (_userId == null) return;
    _db.from('trash_items')
        .insert({...item.toRow(), 'user_id': _userId})
        .catchError((_) {});
  }

  void _deleteRow(String trashId) {
    if (_userId == null) return;
    _db.from('trash_items').delete().eq('id', trashId).catchError((_) {});
  }

  void addTask(Task task) {
    final item = TrashItem.fromTask(task);
    state = [item, ...state];
    _insertRow(item);
  }

  void addSemesterGoal(SemesterGoal goal) {
    final item = TrashItem.fromSemesterGoal(goal);
    state = [item, ...state];
    _insertRow(item);
  }

  void addFutureGoal(FutureGoal goal) {
    final item = TrashItem.fromFutureGoal(goal);
    state = [item, ...state];
    _insertRow(item);
  }

  TrashItem? pop(String trashId) {
    final item = state.where((i) => i.id == trashId).firstOrNull;
    if (item != null) {
      state = state.where((i) => i.id != trashId).toList();
      _deleteRow(trashId);
    }
    return item;
  }

  void permanentDelete(String trashId) {
    state = state.where((i) => i.id != trashId).toList();
    _deleteRow(trashId);
  }
}

final trashProvider = StateNotifierProvider<TrashNotifier, List<TrashItem>>(
  (ref) => TrashNotifier(),
);
