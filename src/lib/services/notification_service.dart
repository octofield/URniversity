import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/notification_cancel.dart';
import '../core/notification_constants.dart';
import '../core/notification_schedule.dart';
import '../models/notification_settings.dart';
import 'notification_background.dart';

// The only part of the feature that talks to the platform. Everything about
// *what* to schedule lives in core/notification_schedule.dart as a pure
// function, so this file stays thin enough to be reviewed by eye — it can
// never be covered by a widget test.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Action labels are localized, but this file has no BuildContext. The caller
  // sets them before the first schedule; English is only ever seen if a
  // notification somehow fires before the app has built once
  String doneLabel = 'Mark as done';
  String rescheduleLabel = 'Reschedule';

  // Called when the user taps the notification or the "reschedule" button,
  // both of which bring the app forward and so run on the main isolate
  void Function(NotificationResponse response)? onForegroundResponse;

  // flutter_local_notifications has no web implementation worth using here, and
  // the desktop targets exist only because `flutter create` made the folders
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Returns whether the platform side is usable. Reports failure instead of
  // throwing: there is no platform channel under flutter test, and a device
  // that cannot name its own time zone should lose reminders, not the app
  Future<bool> _ensureReady() async {
    if (_ready) return true;
    if (!isSupported) return false;

    try {
      // zonedSchedule needs a real tz location. A fixed UTC offset would drift
      // by an hour across a DST change and fire everything at the wrong time
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));

      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permissions are requested explicitly from the settings screen
          // instead, so the prompt appears when the user just asked for them
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            // iOS binds buttons to a category, not to the notification, so the
            // set has to be registered up front
            notificationCategories: [
              DarwinNotificationCategory(
                NotificationConstants.taskCategoryId,
                actions: [
                  DarwinNotificationAction.plain(
                    NotificationConstants.actionDoneId,
                    doneLabel,
                  ),
                  DarwinNotificationAction.plain(
                    NotificationConstants.actionRescheduleId,
                    rescheduleLabel,
                    options: {DarwinNotificationActionOption.foreground},
                  ),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: (r) => onForegroundResponse?.call(r),
        onDidReceiveBackgroundNotificationResponse:
            handleNotificationActionInBackground,
      );
      _ready = true;
    } catch (e) {
      debugPrint('[notifications] unavailable: $e');
      return false;
    }
    return true;
  }

  // Returns whether notifications may actually be shown. A denied permission is
  // reported rather than swallowed: the settings screen turns the master switch
  // back off, otherwise the UI would claim reminders are on while nothing fires
  Future<bool> requestPermission() async {
    if (!await _ensureReady()) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  // Replaces every pending notification with the given list.
  //
  // Cancel-then-reschedule rather than a diff: the schedule is rebuilt on any
  // data change, and working out which of dozens of pending ids to keep would
  // be far more code than simply re-registering them
  Future<void> apply(List<ScheduledNotification> scheduled) async {
    if (!await _ensureReady()) return;
    // Only what has not fired yet. cancelAll() also takes down the reminders
    // already sitting in the shade, so any data change — including ticking off
    // an unrelated task — made a reminder the user was looking at disappear
    for (final pending in await _plugin.pendingNotificationRequests()) {
      await _plugin.cancel(id: pending.id);
    }

    for (final n in scheduled) {
      final when = tz.TZDateTime.from(n.when, tz.local);
      // A notification whose moment passed while we were rescheduling would
      // throw, and one failure must not drop the rest of the list
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;

      try {
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          scheduledDate: when,
          payload: n.payload,
          notificationDetails: _detailsFor(n.kind),
          // Inexact on purpose: SCHEDULE_EXACT_ALARM is restricted to alarm and
          // calendar apps on Android 14+, and a reminder that lands a few
          // minutes late is worth more than one the Play Store rejects
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('[notifications] could not schedule ${n.id}: $e');
      }
    }
  }

  Future<void> cancelAll() async {
    if (!await _ensureReady()) return;
    await _plugin.cancelAll();
  }

  // Takes down a reminder that has already been shown, now that its task is
  // done. Matched on the payload rather than the id: ids are handed out
  // positionally when the schedule is built, so the one on screen cannot be
  // recomputed from the task alone
  Future<void> cancelForTask(String taskId) async {
    if (!await _ensureReady()) return;
    try {
      final shown = await _plugin.getActiveNotifications();
      for (final id in notificationIdsForTask(
        [for (final n in shown) (id: n.id, payload: n.payload)],
        taskId,
      )) {
        await _plugin.cancel(id: id);
      }
    } catch (e) {
      // Reading active notifications is unsupported on older Androids; the
      // reminder simply stays until the user swipes it
      debugPrint('[notifications] could not take down the reminder: $e');
    }
  }

  NotificationDetails _detailsFor(NotificationKind kind) {
    final (id, name) = switch (kind) {
      NotificationKind.taskDue => (NotificationConstants.taskChannelId, 'Task reminders'),
      NotificationKind.dailySummary =>
        (NotificationConstants.summaryChannelId, 'Daily summary'),
      NotificationKind.goalDeadline =>
        (NotificationConstants.goalChannelId, 'Goal deadlines'),
      NotificationKind.weeklyReview =>
        (NotificationConstants.reviewChannelId, 'Weekly review'),
    };
    // Only a task reminder has a single row to act on, so only it gets buttons
    final isTask = kind == NotificationKind.taskDue;

    // One channel per kind so the user can silence just one of them from the
    // system settings, which is what Android users expect to be able to do
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        // Tapping it opens the app but leaves the reminder in place: it stands
        // for work still to do, so it goes away when the task does
        autoCancel: false,
        actions: isTask
            ? [
                AndroidNotificationAction(
                  NotificationConstants.actionDoneId,
                  doneLabel,
                  // No UI: this is the whole point — tick it off from the shade
                  // without the app appearing. Android always routes this to a
                  // separate engine, which is what notification_background.dart
                  // is for
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  NotificationConstants.actionRescheduleId,
                  rescheduleLabel,
                  // Must bring the app forward: it opens the task's edit sheet
                  showsUserInterface: true,
                  // Kept on screen: moving a task's time does not do the task
                  cancelNotification: false,
                ),
              ]
            : const <AndroidNotificationAction>[],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: isTask ? NotificationConstants.taskCategoryId : null,
      ),
    );
  }

  // The response that opened a cold-started app, if any. The foreground
  // callback never fires for that case because nothing was listening yet
  Future<NotificationResponse?> launchResponse() async {
    if (!await _ensureReady()) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse;
  }
}
