import '../core/notification_constants.dart';

// The three kinds of reminder, each switchable on its own. Keeping them as one
// enum lets the schedule builder and the settings screen iterate instead of
// repeating the same three branches
enum NotificationKind { taskDue, dailySummary, goalDeadline }

class NotificationSettings {
  // Master switch. Turning this off has to stop everything even if the
  // individual kinds are still on, because it is what the OS permission maps to
  final bool enabled;

  final bool taskDueEnabled;
  // How long before dueTime to fire. 0 means at the due time itself
  final int taskLeadMinutes;

  final bool dailySummaryEnabled;
  // Minutes since midnight
  final int summaryMinuteOfDay;

  final bool goalDeadlineEnabled;
  // How many days before the semester ends to warn about unfinished goals
  final int goalLeadDays;

  const NotificationSettings({
    this.enabled = false,
    this.taskDueEnabled = true,
    this.taskLeadMinutes = NotificationConstants.defaultTaskLeadMinutes,
    this.dailySummaryEnabled = true,
    this.summaryMinuteOfDay = NotificationConstants.defaultSummaryMinuteOfDay,
    this.goalDeadlineEnabled = true,
    this.goalLeadDays = NotificationConstants.defaultGoalLeadDays,
  });

  // Off by default: the app has to ask for the OS permission before anything
  // can fire, and asking on first launch before the user has any data is the
  // fastest way to get permanently denied
  static const initial = NotificationSettings();

  bool isOn(NotificationKind kind) {
    if (!enabled) return false;
    return switch (kind) {
      NotificationKind.taskDue => taskDueEnabled,
      NotificationKind.dailySummary => dailySummaryEnabled,
      NotificationKind.goalDeadline => goalDeadlineEnabled,
    };
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? taskDueEnabled,
    int? taskLeadMinutes,
    bool? dailySummaryEnabled,
    int? summaryMinuteOfDay,
    bool? goalDeadlineEnabled,
    int? goalLeadDays,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        taskDueEnabled: taskDueEnabled ?? this.taskDueEnabled,
        taskLeadMinutes: taskLeadMinutes ?? this.taskLeadMinutes,
        dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
        summaryMinuteOfDay: summaryMinuteOfDay ?? this.summaryMinuteOfDay,
        goalDeadlineEnabled: goalDeadlineEnabled ?? this.goalDeadlineEnabled,
        goalLeadDays: goalLeadDays ?? this.goalLeadDays,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'task_due_enabled': taskDueEnabled,
        'task_lead_minutes': taskLeadMinutes,
        'daily_summary_enabled': dailySummaryEnabled,
        'summary_minute_of_day': summaryMinuteOfDay,
        'goal_deadline_enabled': goalDeadlineEnabled,
        'goal_lead_days': goalLeadDays,
      };

  // Every field falls back to its default: a payload written by an older build
  // is missing the newer keys, and losing the whole settings object over one
  // absent field would silently turn notifications off
  factory NotificationSettings.fromJson(Map<String, dynamic> j) =>
      NotificationSettings(
        enabled: j['enabled'] as bool? ?? false,
        taskDueEnabled: j['task_due_enabled'] as bool? ?? true,
        taskLeadMinutes: j['task_lead_minutes'] as int? ??
            NotificationConstants.defaultTaskLeadMinutes,
        dailySummaryEnabled: j['daily_summary_enabled'] as bool? ?? true,
        summaryMinuteOfDay: j['summary_minute_of_day'] as int? ??
            NotificationConstants.defaultSummaryMinuteOfDay,
        goalDeadlineEnabled: j['goal_deadline_enabled'] as bool? ?? true,
        goalLeadDays:
            j['goal_lead_days'] as int? ?? NotificationConstants.defaultGoalLeadDays,
      );
}
