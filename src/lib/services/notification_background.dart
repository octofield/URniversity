import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/notification_constants.dart';
import '../core/notification_payload.dart';
import '../models/task.dart';

// Handles "mark as done" from the notification shade.
//
// On Android this ALWAYS runs in a separate Flutter engine, whether or not the
// app is alive — ActionBroadcastReceiver does not check for a running app
// before spawning one. So there are no providers here, no Riverpod, and no UI
// to report a failure through.
//
// That last point is why every outcome is written to
// NotificationConstants.actionLogKey: the main isolate reads it on its next
// launch or resume, reloads so the screen is not stale, and surfaces failures
// through the ordinary reportSyncError path. A failure is deferred here, never
// swallowed (CLAUDE.md §9 rule 2).
@pragma('vm:entry-point')
Future<void> handleNotificationActionInBackground(
    NotificationResponse response) async {
  // The background engine has no plugins registered until this is called
  DartPluginRegistrant.ensureInitialized();
  await applyDoneAction(response);
}

// Separated from the entry point so it can be driven directly. The entry point
// itself can only ever be exercised on a device.
Future<void> applyDoneAction(NotificationResponse response) async {
  if (response.actionId != NotificationConstants.actionDoneId) return;

  final payload = TaskNotificationPayload.decode(response.payload);
  if (payload == null) {
    debugPrint('[notifications] unusable payload: ${response.payload}');
    return;
  }

  String? error;
  try {
    final prefs = await SharedPreferences.getInstance();
    // This isolate has its own cache, and it was built after the main isolate
    // last wrote. Without the reload it can read a stale guest task list
    await prefs.reload();

    if (prefs.getBool('is_guest_mode') ?? false) {
      await _toggleGuestTask(prefs, payload);
    } else {
      await _toggleCloudTask(payload);
    }
  } catch (e) {
    error = e.toString();
    debugPrint('[notifications] background write failed: $e');
  }

  await _record(NotificationActionRecord(taskId: payload.taskId, error: error));
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
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  final db = Supabase.instance.client;
  if (db.auth.currentUser == null) {
    throw StateError('no signed-in session in the background isolate');
  }

  final row = await db
      .from('tasks')
      .select()
      .eq('id', payload.taskId)
      .maybeSingle();
  if (row == null) throw StateError('task ${payload.taskId} not found');

  final updated = Task.fromJson(row).toggledOn(payload.date);
  await db.from('tasks').update(updated.toJson()).eq('id', payload.taskId);
}

Future<void> _record(NotificationActionRecord record) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final existing = NotificationActionRecord.decodeList(
      prefs.getString(NotificationConstants.actionLogKey));
  await prefs.setString(
    NotificationConstants.actionLogKey,
    NotificationActionRecord.encodeList([...existing, record]),
  );
}
