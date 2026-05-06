abstract class AppStrings {
  String get appName;
  String get settings;
  String get backToToday;
  String get add;
  String get titleField;
  String get language;
  String get langZhTw;
  String get langEn;
  String get langJp;

  String tasksCompleted(int completed, int total);
  String get tasks;
  String get noTasks;
  String get addTask;
  String get taskNotes;
  String get priority;
  String get priorityLow;
  String get priorityMed;
  String get priorityHigh;
  String get dueTime;
  String get clearTime;

  String get inspirations;
  String get noInspirations;
  String get addInspiration;
  String get inspirationDetails;

  String get concentration;
  String concentrationToday(String t);
  String concentrationSession(String t);
  String get start;
  String get stop;

  String get semester;
  String get future;

  String get dateFormat;
  String get fmtMmddWeekday;
  String get fmtMmdd;
  String get fmtYyyymmdd;
  String get fmtLongDate;

  // Semester goals
  String get addGoal;
  String get noGoals;
  String goalProgress(int done, int total);
  String get milestones;
  String get addMilestone;

  // Future goals
  String get category;
  String get catAll;
  String get catExchange;
  String get catIntern;
  String get catCompetition;
  String get catCertification;
  String get catPerformance;
  String get catOther;
  String get startTime;
  String get endTime;
  String get subgoals;
  String get addSubgoal;
}
