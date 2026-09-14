import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/notification_constants.dart';
import '../core/notification_payload.dart';
import '../models/task.dart';

// Marking a task done from outside the running app.
//
// Two entry points need this and both are in the same bind: the notification's
// "mark as done" button and the home screen widget's tick box. Android runs
// each of them in a separate Flutter engine, so neither has providers, and
// neither has any UI to report a failed write through.
//
// The answer is the same for both: do the write here, and record the outcome in
// NotificationConstants.actionLogKey for the main isolate to reconcile on its
// next launch or resume. A failure is deferred, never swallowed
// (CLAUDE.md §9 rule 2).

// Returns the error text when the write failed, null when it landed
Future<String?> toggleTaskFromBackground(TaskNotificationPayload payload) async {
  String? error;
  try {
    final prefs = await SharedPreferences.getInstance();
    // This engine has its own cache, built after the main isolate last wrote
    await prefs.reload();

    if (prefs.getBool('is_guest_mode') ?? false) {
      await _toggleGuestTask(prefs, payload);
    } else {
      await _toggleCloudTask(payload);
    }
  } catch (e) {
    error = e.toString();
    debugPrint('[background] task write failed: $e');
  }

  await recordBackgroundAction(
      NotificationActionRecord(taskId: payload.taskId, error: error));
  return error;
}

// Guest data never reaches Supabase, so the local mirror is the real thing here
Future<void> _toggleGuestTask(
    SharedPreferences prefs, TaskNotificationPayload payload) async {
  final raw = prefs.getString('guest_tasks');
  if (raw == null) throw StateError('no guest tasks stored');

  final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  final index = rows.indexWhere((r) => r['id'] == payload.taskId);
  if (index < 0) throw StateError('task ${payload.taskId} not found');

  final updated = Task.fromJson(rows[index]).toggledOn(payload.date);
  rows[index] = updated.toJson();
  await prefs.setString('guest_tasks', jsonEncode(rows));
}

// Read-then-write rather than a blind update: toggling is a flip, and for a
// recurring task it edits a list of dates that only the stored row knows
Future<void> _toggleCloudTask(TaskNotificationPayload payload) async {
  if (!await ensureBackgroundSupabase()) {
    throw StateError('no signed-in session in the background isolate');
  }
  final db = Supabase.instance.client;

  final row =
      await db.from('tasks').select().eq('id', payload.taskId).maybeSingle();
  if (row == null) throw StateError('task ${payload.taskId} not found');

  final updated = Task.fromJson(row).toggledOn(payload.date);
  await db.from('tasks').update(updated.toJson()).eq('id', payload.taskId);
}

// The key supabase_flutter persists the session under
final _persistSessionKey =
    'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token';

// Returns whether a signed-in session is available in this engine.
//
// Both background engines — the notification's and the widget's — are static
// and outlive a single tap, but Supabase.initialize() reads the persisted
// session only the first time it runs. An engine that first ran before the user
// signed in therefore stayed signed out for as long as the process lived, and
// every later tap reported "no signed-in session". So the session is re-read
// from disk on every call instead of trusting what initialize() found
Future<bool> ensureBackgroundSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  // The engine's cache predates whatever the app wrote since it last ran
  await prefs.reload();
  final persisted = prefs.getString(_persistSessionKey);
  if (persisted == null) return false;

  // Also refreshes an expired token. A failure throws, and both callers already
  // route that to the action log rather than dropping it
  final auth = Supabase.instance.client.auth;
  await auth.recoverSession(persisted);
  return auth.currentUser != null;
}

// The main isolate drains this on launch and on resume: every entry means
// "the stored rows changed underneath you, reload", and an entry carrying an
// error additionally means the user has not been told the write failed
Future<void> recordBackgroundAction(NotificationActionRecord record) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final existing = NotificationActionRecord.decodeList(
      prefs.getString(NotificationConstants.actionLogKey));
  await prefs.setString(
    NotificationConstants.actionLogKey,
    NotificationActionRecord.encodeList([...existing, record]),
  );
}
