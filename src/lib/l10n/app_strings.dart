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

  // Task linking & recurrence
  String get linkedTarget;
  String get selectTarget;
  String get linkedGoal;
  String get repeat;
  String get repeatNone;
  String get repeatDaily;
  String get repeatWeekly;
  String get repeatMonthly;
  String get repeatEveryNDays;
  String get repeatInterval;

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
  String get targets;    // nav label for semester tab
  String get goals;      // nav label for future tab

  String get dateFormat;
  String get fmtMmddWeekday;
  String get fmtMmdd;
  String get fmtYyyymmdd;
  String get fmtLongDate;

  // Semester targets
  String get addTarget;
  String get noTargets;
  String get editTarget;
  String goalProgress(int done, int total);
  String get milestones;
  String get addMilestone;
  String get backToCurrentSem;
  String get goalNotes;

  // Future goals
  String get addGoal;
  String get noGoals;
  String get editGoal;
  String get category;
  String get catAll;
  String get catExchange;
  String get catIntern;
  String get catCompetition;
  String get catCertification;
  String get catPerformance;
  String get catOther;
  String get startSemester;
  String get endSemester;
  String get subgoals;
  String get addSubgoal;
  String get editTask;
  String get save;
  String get addCategory;
  String get categoryName;
  String get linkedFutureGoal;
  String get selectFutureGoal;
  String get noLink;
  String get more;

  // Semester system settings
  String get semesterSettings;
  String get semesterCount;
  String get twoSemesters;
  String get threeSemesters;
  String get fourSemesters;
  String get semesterStartMonth;

  // Trash
  String get trash;
  String get restore;
  String get emptyTrash;
  String get noTrash;
  String get markDone;
  String get markUndone;
}
