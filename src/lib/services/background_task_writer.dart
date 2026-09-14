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
  await ensureBackgroundSupabase();
  final db = Supabase.instance.client;
  if (db.auth.currentUser == null) {
    throw StateError('no signed-in session in the background isolate');
  }

  final row =
      await db.from('tasks').select().eq('id', payload.taskId).maybeSingle();
  if (row == null) throw StateError('task ${payload.taskId} not found');

  final updated = Task.fromJson(row).toggledOn(payload.date);
  await db.from('tasks').update(updated.toJson()).eq('id', payload.taskId);
}

// initialize() is idempotent, so callers do not have to track whether some
// other background entry point already ran
Future<void> ensureBackgroundSupabase() => Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

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
