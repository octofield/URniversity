import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The last write that failed to reach Supabase. The UI watches this to surface
// a message; writes used to fail silently, leaving the screen showing success
// while nothing had been saved
final syncErrorProvider = StateProvider<Object?>((ref) => null);

// Records a failed write for the UI to pick up. Free function so the providers
// that do not extend [SyncedListNotifier] can report the same way
void reportSyncError(Ref ref, Object error) {
  ref.read(syncErrorProvider.notifier).state = error;
}

// Shared guest/Supabase plumbing for the list-shaped providers.
//
// Every list provider needs the same five things: load from Supabase, load from
// SharedPreferences in guest mode, mirror local state back to SharedPreferences,
// push a row upsert, and push a row delete. Only the table, the local key, the
// sort column and the JSON codec differ, so those are the subclass hooks.
abstract class SyncedListNotifier<T> extends StateNotifier<List<T>> {
  SyncedListNotifier(
    this.ref, {
    required this.table,
    required this.localKey,
    required this.orderColumn,
    this.orderAscending = true,
  }) : super([]);

  final Ref ref;
  final String table;
  final String localKey;
  final String orderColumn;
  final bool orderAscending;

  String? _userId;
  SupabaseClient get db => Supabase.instance.client;
  bool get isGuest => _userId == 'guest';

  // Subclass hooks
  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T item);
  String idOf(T item);

  // Runs after either load path, for subclasses that backfill rows
  Future<void> afterLoad() async {}

  void reportSyncError(Object error) => ref.read(syncErrorProvider.notifier).state = error;

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await db
          .from(table)
          .select()
          .eq('user_id', userId)
          .order(orderColumn, ascending: orderAscending);
      state = (rows as List<dynamic>)
          .map((r) => fromJson(r as Map<String, dynamic>))
          .toList();
      await afterLoad();
    } catch (e) {
      // Leaving _userId null lets a later load() retry instead of no-oping
      _userId = null;
      reportSyncError(e);
    }
  }

  Future<void> loadGuest() async {
    _userId = 'guest';
    final p = await SharedPreferences.getInstance();
    final json = p.getString(localKey);
    state = json == null
        ? []
        : (jsonDecode(json) as List)
            .map((j) => fromJson(j as Map<String, dynamic>))
            .toList();
    await afterLoad();
  }

  void persistLocally() {
    SharedPreferences.getInstance().then((p) {
      p.setString(localKey, jsonEncode(state.map(toJson).toList()));
    });
  }

  void clear() {
    _userId = null;
    state = [];
  }

  Future<void> mergeToUser(String userId) async {
    _userId = userId;
    for (final item in state) {
      try {
        await db.from(table).upsert({...toJson(item), 'user_id': userId});
      } catch (e) {
        reportSyncError(e);
      }
    }
  }

  void upsert(T item) {
    if (isGuest) {
      persistLocally();
      return;
    }
    if (_userId == null) return;
    db
        .from(table)
        .upsert({...toJson(item), 'user_id': _userId})
        .catchError((Object e) => reportSyncError(e));
  }

  void deleteRow(String id) {
    if (isGuest) {
      persistLocally();
      return;
    }
    if (_userId == null) return;
    db
        .from(table)
        .delete()
        .eq('id', id)
        .catchError((Object e) => reportSyncError(e));
  }

  void restore(T item) {
    state = [...state, item];
    upsert(item);
  }
}
