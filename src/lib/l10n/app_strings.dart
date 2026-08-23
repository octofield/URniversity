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
  String get addSubtask;
  String get taskNotes;
  String get priority;
  String get priorityLow;
  String get priorityMed;
  String get priorityHigh;
  String get dueTime;

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
  // Weekly/monthly summaries. When no day is chosen the rule falls back to the
  // task's creation date, and these render that fallback identically to an
  // explicit choice so the two read the same
  String repeatWeeklyOn(String days);
  String repeatMonthlyOn(String days);
  String monthDayShort(int day);
  String repeatEveryNDaysShort(int n);
  String get repeatMonthLastDay;

  String get inspirations;
  String get noInspirations;
  String get addInspiration;
  String get inspirationDetails;

  // Me page
  String get me;
  String get usernameLabel;
  String get accountSettings;
  String get journal;
  String get noJournal;
  String get addJournal;
  String get editJournal;
  String get journalContent;

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
  String get categoryName;
  String get linkedFutureGoal;
  String get selectFutureGoal;
  String get noLink;
  String get more;
  String get pickColor;
  String get pickIcon;
  String get categorySettings;
  String get winterBreak;
  String get summerBreak;
  String get springBreak;
  String get autumnBreak;

  // Desktop sidebars
  String get progressOverview;
  String get filters;

  // Today greeting header
  String greetingMorning(String name);
  String greetingAfternoon(String name);
  String greetingEvening(String name);
  String todayStatus(int total, int done);
  String get allDoneToday;

  // Overview graph
  String get overview;
  String get unlinked;
  String get overviewEmpty;

  // Me page desktop column header
  String get profile;

  // Task completion history
  String get taskHistory;
  String get historyDaily;
  String get historyWeekly;
  String get historyMonthly;
  String historyAverage(int percent);
  String get historyNoData;
  String get historyTapHint;

  // Semester system settings
  String get semesterSettings;
  String get semesterCount;
  String get twoSemesters;
  String get threeSemesters;
  String get fourSemesters;
  String get semesterStartMonth;

  // Goal detail screen
  String get linkedTasks;
  String get linkedTargets;

  // Trash
  String get trash;
  String get restore;
  String get emptyTrash;
  String get noTrash;
  String get markDone;
  String get markUndone;

  String get dailyTasks;
  String get weeklyTasks;
  String get allTasks;
  String get defaultTaskView;
  String get createdAtLabel;
  String get completedTasks;
  String get delete;
  String weekdayShort(int weekday);

  String get addLinkedTask;
  String get addLinkedTarget;
  String get addLinkedGoal;
  String get selectTask;
  String get reset;

  // Me page — profile fields
  String get school;
  String get department;
  String get grade;

  // Inspirations full page
  String get allInspirations;
  String get completed;
  String get pending;

  // Journal full page & editor
  String get allJournals;
  String get writeJournal;

  // Journal day counter & developer mode
  String get showJournalDayCounter;
  String get versionLabel;
  String get developerMode;
  String get devTimeOverride;

  // Account actions
  String get logout;
  String get deleteAccount;
  String get exitGuestMode;
  String get feedbackTitle;
  String get feedbackBug;
  String get feedbackSuggestion;
  String get feedbackAnonymousNote;
  String get feedbackBugHint;
  String get feedbackSuggestionHint;
  String get feedbackSubmit;
  String get feedbackErrorMinLength;
  String get feedbackErrorCooldown;
  String get feedbackErrorFailed;

  // Auth screens
  String get login;
  String get register;
  String get createAccount;
  String get registerHeadline;
  String get emailLabel;
  String get passwordLabel;
  String get passwordLabelWithHint;
  String get confirmPasswordLabel;
  String get orDivider;
  String get signInWithGoogle;
  String get noAccountYet;
  String get haveAccountAlready;
  String get backToGuestMode;
  String get tryAsGuest;
  String get passwordMismatch;
  String get passwordTooShort;
  String get checkVerificationEmail;

  // Profile setup & editing
  String get setupProfileTitle;
  String get setupProfileSubtitle;
  String get pickAvatar;
  String get avatar;
  String get done;
  String get confirm;
  String get guest;
  String get loginMethod;
  String gradeLabel(int grade);
  String pickerSearchHint(String field);
  String pickerCustomInput(String field);
  String get pickerOther;

  // Guest data merge
  String get loginOrCreateAccount;
  String get mergeGuestDataQuestion;
  String get discardGuestData;
  String get mergeGuestData;

  // Account action confirmations
  String get exitGuestConfirm;
  String get exitAction;
  String get logoutConfirm;
  String deleteAccountConfirmEmail(String email);
  String get deleteAccountConfirmPassword;
  String get emailMismatch;
  String get confirmDeleteAction;

  // Trash
  String get emptyTrashConfirm;
  String deletedOn(String date);
  String get permanentDelete;

  // Shared phrasing — the punctuation itself differs per locale, so these
  // cannot be assembled from their parts at the call site
  String get deleteConfirm;
  String createdAtValue(String value);
  String percentSuffix(int percent);
  String dateWithWeekday(String date, String weekday);
  String dateLongDate(int month, int day);

  // Shown when a write did not reach Supabase
  String get syncFailed;
}
