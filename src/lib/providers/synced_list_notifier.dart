import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

// The last write that failed to reach Supabase. The UI watches this to surface
// a message; writes used to fail silently, leaving the screen showing success
// while nothing had been saved
final syncErrorProvider = StateProvider<Object?>((ref) => null);

// Records a failed write for the UI to pick up. Free function so the providers
// that do not extend [SyncedListNotifier] can report the same way.
//
// Also logs at the source rather than in the UI: a failure during sign-in
// happens before HomeScreen is mounted, so nothing would ever display it
void reportSyncError(Ref ref, Object error) {
  debugPrint('[sync] ${describeSyncError(error)}');
  ref.read(syncErrorProvider.notifier).state = error;
}

// PostgrestException.toString() drops details and hint, which are usually the
// only parts that say which column or policy rejected the write
String describeSyncError(Object error) {
  if (error is! PostgrestException) return error.toString();
  final parts = <String>[
    if (error.code != null) 'code=${error.code}',
    error.message,
    if (error.details != null) 'details=${error.details}',
    if (error.hint != null) 'hint=${error.hint}',
  ];
  return parts.join(' | ');
}

// Errors worth trying again. Everything else is a schema or policy problem that
// will fail identically on the next attempt, so retrying only delays the report.
//
// PGRST303 is the one that prompted this: a PostgREST bug rejects tokens used
// within a few hundred ms of being issued, so the same write succeeds a moment
// later. PGRST301 covers a token that expired mid-flight
bool isTransientSyncError(Object error) {
  if (error is PostgrestException) {
    return const {'PGRST301', 'PGRST303'}.contains(error.code);
  }
  return error is SocketException ||
      error is TimeoutException ||
      error is ClientException;
}

// Runs a write, retrying transient failures with growing, jittered delays.
// Fixed delays were reported as not enough for the PostgREST clock bug, so the
// gap widens and carries jitter to avoid every pending write retrying in step.
Future<void> runWithRetry(
  Future<void> Function() write, {
  int maxAttempts = 3,
}) async {
  final jitter = Random();
  for (var attempt = 1; ; attempt++) {
    try {
      await write();
      return;
    } catch (e) {
      if (attempt >= maxAttempts || !isTransientSyncError(e)) rethrow;
      final backoff = 200 * attempt + jitter.nextInt(200);
      debugPrint('[sync] attempt $attempt failed, retrying in ${backoff}ms '
          '- ${describeSyncError(e)}');
      await Future<void>.delayed(Duration(milliseconds: backoff));
    }
  }
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
      // Retried harder than a single write: a failed load nulls _userId below,
      // which silently disables every write for the rest of the session
      await runWithRetry(() async {
        final rows = await db
            .from(table)
            .select()
            .eq('user_id', userId)
            .order(orderColumn, ascending: orderAscending);
        state = (rows as List<dynamic>)
            .map((r) => fromJson(r as Map<String, dynamic>))
            .toList();
      }, maxAttempts: 4);
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
    final row = {...toJson(item), 'user_id': _userId};
    unawaited(
      runWithRetry(() => db.from(table).upsert(row))
          .catchError((Object e) => reportSyncError(e)),
    );
  }

  void deleteRow(String id) {
    if (isGuest) {
      persistLocally();
      return;
    }
    if (_userId == null) return;
    unawaited(
      runWithRetry(() => db.from(table).delete().eq('id', id))
          .catchError((Object e) => reportSyncError(e)),
    );
  }

  // A trashed row keeps whatever ids it held when it was deleted, and those
  // rows can be deleted in the meantime. Restoring it then inserts a dangling
  // reference and a real foreign key rejects the whole write. Subclasses drop
  // the references that no longer resolve
  T sanitizeForRestore(T item) => item;

  void restore(T item) {
    final clean = sanitizeForRestore(item);
    state = [...state, clean];
    upsert(clean);
  }
}
