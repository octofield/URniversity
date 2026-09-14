import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/notification_constants.dart';
import '../core/notification_payload.dart';
import 'background_task_writer.dart';

// Handles "mark as done" from the notification shade.
//
// On Android this ALWAYS runs in a separate Flutter engine, whether or not the
// app is alive — ActionBroadcastReceiver does not check for a running app
// before spawning one. So there are no providers here, no Riverpod, and no UI
// to report a failure through.
//
// The write itself lives in background_task_writer.dart because the home screen
// widget's tick box needs exactly the same thing, including the same deferred
// failure reporting.
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

  await toggleTaskFromBackground(payload);
}
