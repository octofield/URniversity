import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb, protected, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

// The last write that failed to reach Supabase. The UI watches this to surface
// a message; writes used to fail silently, leaving the screen showing success
// while nothing had been saved
final syncErrorProvider = StateProvider<Object?>((ref) => null);

// One failed sync and where it happened ("courses upsert", "user_settings
// term_starts"). "Sync failed" alone could not be traced when it came and went
const kSyncLogSize = 20;

class SyncFailure {
  final DateTime at;
  final String where;
  final Object error;

  const SyncFailure(this.at, this.where, this.error);
}

// The last [kSyncLogSize] failures, newest first, for the developer-mode sync
// log. Memory only: it is for reporting what just happened
final syncLogProvider = StateProvider<List<SyncFailure>>((ref) => const []);

// Records a failed write for the UI to pick up. Free function so the providers
// that do not extend [SyncedListNotifier] can report the same way.
//
// Also logs at the source rather than in the UI: a failure during sign-in
// happens before HomeScreen is mounted, so nothing would ever display it
void reportSyncError(Ref ref, Object error, {String where = ''}) =>
    _report(ref.read(syncLogProvider.notifier), ref.read(syncErrorProvider.notifier), error, where);

// The same, from a widget
void reportSyncErrorFromWidget(WidgetRef ref, Object error, {String where = ''}) =>
    _report(ref.read(syncLogProvider.notifier), ref.read(syncErrorProvider.notifier), error, where);

void _report(StateController<List<SyncFailure>> log, StateController<Object?> current, Object error, String where) {
  final failure = SyncFailure(DateTime.now(), where, error);
  debugPrint('[sync] ${describeSyncError(failure)}');
  log.state = [failure, ...log.state.take(kSyncLogSize - 1)];
  current.state = failure;
  _upload(failure);
}

// Also sent to the admin backend's error list (sync_error_reports, D37), so a
// failure that comes and goes on someone's phone can be seen without them.
// Signed-in accounts only, ten a launch at most, and not the network kind —
// that one cannot be sent either, and says nothing about the app
const kMaxErrorUploads = 10;
var _uploaded = 0;

// Who is signed in, and how a report travels. Replaceable so tests can check
// the rules above without reaching Supabase
@visibleForTesting
String? Function() errorReportUser = () => Supabase.instance.client.auth.currentUser?.id;
@visibleForTesting
Future<void> Function(Map<String, dynamic> row) errorReportSender =
    (row) => Supabase.instance.client.from('sync_error_reports').insert(row);
@visibleForTesting
void resetErrorUploads() => _uploaded = 0;

void _upload(SyncFailure failure) {
  final uid = errorReportUser();
  if (uid == null || _uploaded >= kMaxErrorUploads || isTransientSyncError(failure.error)) return;
  _uploaded++;
  final error = failure.error;
  final message = describeSyncError(error);
  errorReportSender({
    'user_id': uid,
    'where': failure.where.length > 100 ? failure.where.substring(0, 100) : failure.where,
    'code': error is PostgrestException ? error.code : null,
    'message': message.length > 500 ? message.substring(0, 500) : message,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
  }).catchError((Object e) {
    // Not reported as a sync failure: that would upload again, and nothing of
    // the user's is lost when a report does not arrive (hard rule 2 exception)
    debugPrint('[sync] error report not sent: $e');
  });
}

// PostgrestException.toString() drops details and hint, which are usually the
// only parts that say which column or policy rejected the write
String describeSyncError(Object error) {
  if (error is SyncFailure) {
    final inner = describeSyncError(error.error);
    return error.where.isEmpty ? inner : '${error.where}: $inner';
  }
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
// later. PGRST301 covers a token that expired mid-flight.
//
// AuthRetryableFetchException is what the client throws when the access token
// expired while the app sat in the background and refreshing it failed because
// the network had not woken up yet. It is the first write after a resume that
// hits this, and it succeeds once the connection is back
bool isTransientSyncError(Object error) {
  if (error is PostgrestException) {
    return const {'PGRST301', 'PGRST303'}.contains(postgrestCode(error));
  }
  return error is SocketException ||
      error is TimeoutException ||
      error is ClientException ||
      error is AuthRetryableFetchException;
}

// The code PostgREST gave. A .maybeSingle() query loses it: postgrest-dart
// rethrows inside its own try, and the catch there keeps only the HTTP status
// (code=401) with PostgREST's JSON as the message — which is why the "JWT
// issued at future" of every user_settings load (reported 2026-09-28 to
// 10-04) was never retried. Read back from the message when that happens
String? postgrestCode(PostgrestException error) {
  final code = error.code;
  if (code != null && !RegExp(r'^\d+$').hasMatch(code)) return code;
  try {
    final body = jsonDecode(error.message);
    if (body is Map && body['code'] is String) return body['code'] as String;
  } catch (_) {
    // Parse fallback: a plain-text message has no code inside
  }
  return code;
}

// Runs a write, retrying transient failures with doubling, jittered delays.
// Fixed delays were reported as not enough for the PostgREST clock bug, and a
// network waking from sleep needs seconds rather than the ~1 s three quick
// attempts used to cover, so five attempts span roughly six seconds. The
// jitter keeps every pending write from retrying in step
Future<void> runWithRetry(
  Future<void> Function() write, {
  int maxAttempts = 5,
}) async {
  final jitter = Random();
  for (var attempt = 1; ; attempt++) {
    try {
      await write();
      return;
    } catch (e) {
      if (attempt >= maxAttempts || !isTransientSyncError(e)) rethrow;
      final backoff = 400 * (1 << (attempt - 1)) + jitter.nextInt(200);
      debugPrint('[sync] attempt $attempt failed, retrying in ${backoff}ms '
          '- ${describeSyncError(e)}');
      await Future<void>.delayed(Duration(milliseconds: backoff));
    }
  }
}

// A read with the same retries as a write: the first query after waking meets
// an expired or not-yet-valid token as often as a write does
Future<T> readWithRetry<T>(Future<T> Function() read, {int maxAttempts = 5}) async {
  late T result;
  await runWithRetry(() async => result = await read(), maxAttempts: maxAttempts);
  return result;
}

// Row ids are generated on the client. A bare millisecond timestamp collides
// for anything created in a loop — and `id` is the primary key, so the second
// upsert silently overwrites the first. The random suffix keeps ids roughly
// time-ordered while making a collision negligible
//
// The range is a literal, not `1 << 32`: on the web ints are JavaScript numbers
// and shifts work on 32 bits, so that expression is 0 there and nextInt(0)
// throws — every add failed in the browser (test/row_id_test.dart)
final _idRandom = Random();
const _idSuffixRange = 0x100000000;
String newRowId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${_idRandom.nextInt(_idSuffixRange)}';

// Which account the cache_* rows belong to (D24)
const kCacheOwnerKey = 'cache_owner';

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
  }) : super([]) {
    addListener(_writeCache, fireImmediately: false);
  }

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

  // The three trips to the server, apart so a test can stand in for it
  @protected
  Future<List<Map<String, dynamic>>> fetchRows(String userId) async {
    final rows = await db.from(table).select().eq('user_id', userId).order(orderColumn, ascending: orderAscending);
    return [for (final r in rows as List<dynamic>) r as Map<String, dynamic>];
  }

  @protected
  Future<void> sendUpsert(Map<String, dynamic> row) async => await db.from(table).upsert(row);

  @protected
  Future<void> sendDelete(String id) async => await db.from(table).delete().eq('id', id);

  // Rows written here that the server has not confirmed (2026-10-04): the
  // version sent, null for a delete. A refetch or a pushed change lays these
  // over what the server says, so a write still on its way — or one that
  // failed, offline — is never undone by a newer view of the account
  final Map<String, _PendingWrite<T>> _pending = {};
  int _writes = 0;
  // Writes confirmed while a fetch was out: the rows it returns may predate
  // them, so they are laid over it as well. Emptied once no fetch is out
  final Map<String, _PendingWrite<T>> _landed = {};
  int _fetching = 0;

  void _send(String id, T? item, String op) {
    final userId = _userId;
    if (userId == null) return;
    final write = _PendingWrite<T>(item, ++_writes);
    _pending[id] = write;
    final send = item == null ? () => sendDelete(id) : () => sendUpsert({...toJson(item), 'user_id': userId});
    unawaited(runWithRetry(send).then((_) {
      if (!identical(_pending[id], write)) return;
      _pending.remove(id);
      if (_fetching > 0) _landed[id] = write;
    }).catchError((Object e) {
      write.failed = true;
      reportSyncError(e, op);
    }));
  }

  // The server's rows with this device's own writes on top: unconfirmed ones,
  // and ones confirmed after the rows were asked for
  List<T> _withPending(List<T> server) {
    final mine = {..._landed, ..._pending};
    final out = [
      for (final row in server)
        if (!mine.containsKey(idOf(row))) row else if (mine[idOf(row)]!.item case final T local) local,
    ];
    final present = {for (final row in out) idOf(row)};
    for (final MapEntry(:key, :value) in mine.entries) {
      if (value.item case final T local when !present.contains(key)) out.add(local);
    }
    return out;
  }

  // The account's rows, counted as out so writes landing meanwhile are kept
  Future<List<T>> _fetch(String userId) async {
    _fetching++;
    try {
      return [for (final r in await fetchRows(userId)) fromJson(r)];
    } finally {
      _fetching--;
    }
  }

  void _settled() {
    if (_fetching == 0) _landed.clear();
  }

  // What other devices wrote since: asked for on coming back to the app
  // (system_design.md §3-I). Writes that failed here are sent again first.
  // True once the rows came back
  Future<bool> refresh() async {
    final userId = _userId;
    if (userId == null || isGuest) return false;
    for (final MapEntry(:key, :value) in {..._pending}.entries) {
      if (value.failed) _send(key, value.item, value.item == null ? 'delete' : 'upsert');
    }
    try {
      late List<T> server;
      await runWithRetry(() async => server = await _fetch(userId));
      // Signed out, or into another account, while asking
      if (_userId != userId) return false;
      state = _withPending(server);
      _settled();
      await afterLoad();
      return true;
    } catch (e) {
      reportSyncError(e, 'refresh');
      return false;
    }
  }

  // A change another device made, pushed by Supabase Realtime: a whole row
  // for an insert or update, only the id for a delete. A row with a write of
  // this device's still unconfirmed keeps that version
  void applyRemote({Map<String, dynamic>? row, String? deletedId}) {
    if (_userId == null || isGuest) return;
    if (row != null) {
      final T item;
      try {
        item = fromJson(row);
      } catch (e) {
        // Parse fallback: a row from a newer build's schema is left for the
        // next refetch rather than breaking the list
        debugPrint('[sync] $table push unreadable - $e');
        return;
      }
      final id = idOf(item);
      if (_pending.containsKey(id)) return;
      final i = state.indexWhere((r) => idOf(r) == id);
      state = i < 0 ? [...state, item] : ([...state]..[i] = item);
    } else if (deletedId != null && !_pending.containsKey(deletedId)) {
      if (state.any((r) => idOf(r) == deletedId)) {
        state = state.where((r) => idOf(r) != deletedId).toList();
      }
    }
  }

  // Named with the table and what was being done, for the sync log
  void reportSyncError(Object error, [String op = '']) => _report(
        ref.read(syncLogProvider.notifier),
        ref.read(syncErrorProvider.notifier),
        error,
        op.isEmpty ? table : '$table $op',
      );

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    await _readCache(userId);
    try {
      // Retried harder than a single write: a failed load nulls _userId below,
      // which silently disables every write for the rest of the session
      await runWithRetry(() async {
        state = _withPending(await _fetch(userId));
        _settled();
      }, maxAttempts: 6);
      await afterLoad();
    } catch (e) {
      // Leaving _userId null lets a later load() retry instead of no-oping
      _userId = null;
      reportSyncError(e, 'load');
    }
  }

  // Forces a fetch even though the user has not changed.
  //
  // load() no-ops when _userId already matches, which is right for ordinary
  // startup but wrong after the notification's background isolate wrote to the
  // row store behind this isolate's back — the in-memory list would stay stale
  Future<void> reload() async {
    final userId = _userId;
    if (userId == null) return;
    if (userId == 'guest') {
      await loadGuest();
      return;
    }
    _userId = null;
    await load(userId);
    // A failed refetch leaves the list stale but still this user's own. Unlike a
    // failed first load there is no later load() coming to recover, so without
    // this every write for the rest of the session would be silently dropped
    _userId ??= userId;
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

  // A signed-in account's last-seen rows, so the next launch draws them at once
  // and the query only refreshes them — the way an offline-first app opens
  // (data_dictionary.md D24). Kept apart from guest_* so neither overwrites the
  // other, and tagged with its owner so another account never sees them
  String get cacheKey => 'cache_$table';

  Future<void> _readCache(String userId) async {
    final p = await SharedPreferences.getInstance();
    if (p.getString(kCacheOwnerKey) != userId) return;
    final json = p.getString(cacheKey);
    // Something written meanwhile is newer than the cache
    if (json == null || state.isNotEmpty || _userId != userId) return;
    try {
      state = (jsonDecode(json) as List)
          .map((j) => fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Parse fallback: a cache from an older build is simply skipped, the
      // query below fills the list anyway
      debugPrint('[sync] $cacheKey unreadable - $e');
    }
  }

  void _writeCache(List<T> rows) {
    final owner = _userId;
    if (owner == null || isGuest) return;
    SharedPreferences.getInstance().then((p) {
      p.setString(kCacheOwnerKey, owner);
      p.setString(cacheKey, jsonEncode(rows.map(toJson).toList()));
    });
  }

  void clear() {
    _userId = null;
    _pending.clear();
    _landed.clear();
    state = [];
    SharedPreferences.getInstance().then((p) => p.remove(cacheKey));
  }

  // Self-referencing parent id, for the tree-shaped tables. Used to order the
  // merge; null means this table has no parent column
  String? parentIdOf(T item) => null;

  // Rows are merged one at a time and parent_id is a real foreign key, so a
  // child sent before its parent is rejected and that row is lost. Roots first,
  // then each level below them. Anything whose parent is not in the set (a
  // dangling id) is treated as a root so it still gets merged
  List<T> mergeOrder() {
    final ids = {for (final item in state) idOf(item)};
    final pending = [...state];
    final ordered = <T>[];
    final placed = <String>{};

    while (pending.isNotEmpty) {
      final ready = pending.where((item) {
        final parent = parentIdOf(item);
        return parent == null || !ids.contains(parent) || placed.contains(parent);
      }).toList();
      // A parent cycle would loop forever; ship the rest in their current order
      // and let the database reject whatever it cannot resolve
      if (ready.isEmpty) return [...ordered, ...pending];
      for (final item in ready) {
        ordered.add(item);
        placed.add(idOf(item));
      }
      pending.removeWhere((item) => placed.contains(idOf(item)));
    }
    return ordered;
  }

  Future<void> mergeToUser(String userId) async {
    _userId = userId;
    for (final item in mergeOrder()) {
      try {
        await db.from(table).upsert({...toJson(item), 'user_id': userId});
      } catch (e) {
        reportSyncError(e, 'merge');
      }
    }
  }

  void upsert(T item) {
    if (isGuest) {
      persistLocally();
      return;
    }
    _send(idOf(item), item, 'upsert');
  }

  void deleteRow(String id) {
    if (isGuest) {
      persistLocally();
      return;
    }
    _send(id, null, 'delete');
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

class _PendingWrite<T> {
  final T? item;
  final int version;
  bool failed = false;
  _PendingWrite(this.item, this.version);
}
