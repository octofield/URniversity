import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trash_item.dart';
import 'synced_list_notifier.dart';
import '../models/task.dart';
import '../models/semester_goal.dart';
import '../models/future_goal.dart';

class TrashNotifier extends StateNotifier<List<TrashItem>> {
  TrashNotifier(this.ref) : super([]);

  final Ref ref;

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

  // Sign-out only: drops local state and forgets the user. Do NOT use this for
  // the Empty Trash button — it leaves the cloud rows in place and nulls
  // _userId, which silently disables every later write in the session
  void clear() {
    _userId = null;
    state = [];
  }

  // Empty Trash: deletes the user rows for real and keeps _userId, so snapshots
  // taken later in the same session still reach Supabase
  Future<void> emptyAll() async {
    if (state.isEmpty) return;
    state = [];
    if (_userId == null) return;
    try {
      await _db.from('trash_items').delete().eq('user_id', _userId!);
    } catch (e) {
      reportSyncError(ref, e);
    }
  }

  void _insertRow(TrashItem item) {
    if (_userId == null) return;
    _db.from('trash_items')
        .insert({...item.toRow(), 'user_id': _userId})
        .catchError((Object e) => reportSyncError(ref, e));
  }

  void _deleteRow(String trashId) {
    if (_userId == null) return;
    _db.from('trash_items').delete().eq('id', trashId).catchError((Object e) => reportSyncError(ref, e));
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
  (ref) => TrashNotifier(ref),
);
