// Every constant the notification feature uses, in one place.
//
// The plugin keys each pending notification by a single int, and the three
// kinds are scheduled independently, so their id ranges have to be checked
// against each other — that is much easier when they sit side by side than
// when they are spread across the service, the schedule builder and the UI.
class NotificationConstants {
  // ── Channels (Android) ────────────────────────────────────────────────────
  // Changing an id after release creates a *new* channel and silently leaves
  // the user's old settings behind, so these are effectively permanent
  static const taskChannelId = 'task_reminders';
  static const summaryChannelId = 'daily_summary';
  static const goalChannelId = 'goal_deadlines';
  static const reviewChannelId = 'weekly_review';
  static const classChannelId = 'class_reminders';

  // ── Id ranges ─────────────────────────────────────────────────────────────
  // One task can produce several pending notifications (a recurring task fires
  // on many days), so each kind gets a block big enough not to reach the next
  static const summaryIdBase = 1000;
  static const taskIdBase = 100000;
  static const goalIdBase = 500000;
  static const reviewIdBase = 700000;
  static const classIdBase = 800000;

  // ── Defaults ──────────────────────────────────────────────────────────────
  static const defaultTaskLeadMinutes = 30;
  // Minutes since midnight. 8:00 is before most first periods
  static const defaultSummaryMinuteOfDay = 8 * 60;
  // When a repeating task with no due time is reminded about, on each day it
  // lands on. Minutes since midnight
  static const defaultRecurringMinuteOfDay = 8 * 60;
  static const defaultGoalLeadDays = 7;
  // Sunday 20:00: the week is over, the evening is not
  static const defaultReviewMinuteOfDay = 20 * 60;
  // Time to pack up and walk over
  static const defaultClassLeadMinutes = 10;

  // ── Choices offered in the settings screen ────────────────────────────────
  static const taskLeadMinuteOptions = [0, 5, 15, 30, 60, 120, 1440];
  static const goalLeadDayOptions = [1, 3, 7, 14, 30];
  static const classLeadMinuteOptions = [5, 10, 15, 30];

  // ── Scheduling limits ─────────────────────────────────────────────────────
  // A daily recurring task would otherwise generate an unbounded list, and
  // both platforms cap how many pending notifications they will hold (iOS at
  // 64). Rescheduling happens on every data change, so a short horizon stays
  // accurate; the cap is the backstop when a user has many recurring tasks
  static const scheduleHorizonDays = 14;
  static const maxScheduled = 48;
  // Classes repeat every week and could crowd out the rest: only the next
  // week of them, and at most this many
  static const classHorizonDays = 7;
  static const maxClassReminders = 20;

  // ── Action buttons ────────────────────────────────────────────────────────
  // Sent back as NotificationResponse.actionId. "done" is handled without
  // showing any UI, "reschedule" brings the app forward
  static const actionDoneId = 'task_done';
  static const actionRescheduleId = 'task_reschedule';
  // iOS binds buttons to a category rather than to the notification itself
  static const taskCategoryId = 'task_due_category';

  // What a weekly-review notification carries. No pipe, so it can never be
  // mistaken for a task payload ("{taskId}|{date}")
  static const reviewPayload = 'open_review';

  // ── Storage ───────────────────────────────────────────────────────────────
  // SharedPreferences, not user_settings: which device should buzz is a
  // per-device question, and app settings are not persisted at all in guest
  // mode (_saveSettings returns early), which would lose a guest's choices
  static const prefsKey = 'notification_settings';

  // What the background isolate leaves behind for the main isolate to pick up.
  // It has no UI to report a failed write through, so the outcome is written to
  // disk and surfaced on the next launch instead of being swallowed
  static const actionLogKey = 'notification_action_log';
}
