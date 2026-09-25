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
  String get anySemester;
  String get deleteAccountWhatGoes;
  String get deleteAccountReauthHint;
  String get deleteAccountReauthGoogle;
  String get deleteAccountVerified;
  String get signInBadCredentials;
  String get signInEmailNotConfirmed;
  String get signInTooManyTries;
  String get signInNetwork;
  String get signInUnknown;
  String get sortBy;
  String minutesLater(int minutes);
  String hoursLater(int hours);
  String get sortManual;
  String get sortCreated;
  String get sortTitle;
  String get sortTarget;
  String get sortDue;
  String get sortVision;
  String get sortUndoneFirst;
  String get sortStartSemester;
  String get sortEndSemester;
  // The row in the sort sheet that turns on the drag handles
  String get sortRearrange;

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
  String targetsSummary(int count, int done, int total);
  String visionsSummary(int count, int done, int total);

  // Me page desktop column header
  String get profile;

  // Task completion history
  String get taskHistory;
  String get historyDaily;
  String get historyWeekly;
  String get historyMonthly;
  String get historyNoData;
  String get historyTapHint;
  String get historyAverageLabel;
  String historyVsPrevious(String delta);
  String get historyStreak;
  String get historyStreakSub;
  String get historyCompletedTasks;
  String get historyBestWeekday;
  String get historyByCategory;
  String historyCategoryBehind(String name, int left);
  String get historyStale;
  String historyOverdue(int days);
  String get historyNothingStale;
  String get graphLegend;
  String get graphLegendTaskCount;
  String get graphLegendDimmed;
  String get graphFilterUnfinished;
  String get graphOpen;
  String graphViewTasks(int count);
  String get graphNextDue;

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
  String tasksWithCount(int count);
  String completedTasksWithCount(int count);
  String get noSemester;
  String journalStreakDays(int days);
  String get completionEffect;
  String get effectOff;
  String get effectBasic;
  String get effectCelebrate;
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
  String get archived;
  String get archive;
  String get unarchive;


  // Tour chapters (Phase 3)
  String get tourGotIt;
  String get tourTryIt;
  String get tourSkipStep;
  String get tourBack;
  String get tourCloseChapter;
  String get tourFinish;
  String get tourGoBack;
  String get tourRetry;
  String get tourSaved;
  String get tourSubmitBody;
  String get tourGuide;
  String get tourGuideSubtitle;
  String get tourGuideNote;
  String get tourChapterDone;
  String get tourChapterNew;
  String get tourReplay;
  String get tourStart;
  String get tourTaskAddTitle;
  String get tourTaskAddBody;
  String get tourTaskTitleBody;
  String get tourTaskDueBody;
  String get tourTaskRepeatBody;
  String get tourTaskLinkBody;
  String get tourTaskSubmitBody;
  String get tourViewTitle;
  String get tourViewBody;
  String get tourSummaryTitle;
  String get tourSummaryBody;
  String get tourHistoryBody;
  String get tourInspAddTitle;
  String get tourInspAddBody;
  String get tourInspTitleBody;
  String get tourNextTargetTitle;
  String get tourNextTargetBody;
  String get tourTemplatesTitle;
  String get tourTemplatesBody;
  String get tourTargetAddTitle;
  String get tourTargetAddBody;
  String get tourTargetTitleBody;
  String get tourTargetCategoryBody;
  String get tourTargetSemesterBody;
  String get tourTargetVisionBody;
  String get tourMilestoneOpenTitle;
  String get tourMilestoneOpenBody;
  String get tourMilestoneAddTitle;
  String get tourMilestoneAddBody;
  String get tourMilestoneTitleBody;
  String get tourMilestoneListBody;
  String get tourPickerTitle;
  String get tourPickerBody;
  String get tourNextGoalTitle;
  String get tourNextGoalBody;
  String get tourVisionAddTitle;
  String get tourVisionAddBody;
  String get tourVisionTitleBody;
  String get tourVisionCategoryBody;
  String get tourVisionSemestersBody;
  String get tourVisionOpenTitle;
  String get tourVisionOpenBody;
  String get tourVisionLinkedBody;
  String get tourFiltersTitle;
  String get tourFiltersBody;
  String get tourNextMeTitle;
  String get tourNextMeBody;
  String get tourMeSummaryTitle;
  String get tourMeSummaryBody;
  String get tourJournalAddTitle;
  String get tourJournalAddBody;
  String get tourJournalContentBody;
  String get tourInspOpenTitle;
  String get tourInspOpenBody;
  String get tourInspListBody;
  String get tourJournalsTitle;
  String get tourJournalsBody;
  String get tourReplayTitle;
  String get tourReplayBody;

  // Goal templates (Phase 3)
  String get goalTemplates;
  String get applyTemplate;
  String templateContents(int goals, int tasks);
  String templateApplied(int goals, int tasks);

  String get tplFreshman;
  String get tplFreshmanDesc;
  String get tplFreshmanG1;
  String get tplFreshmanG1M1;
  String get tplFreshmanG1M2;
  String get tplFreshmanG1T1;
  String get tplFreshmanG2;
  String get tplFreshmanG2M1;
  String get tplFreshmanG2M2;
  String get tplFreshmanG2T1;

  String get tplExchange;
  String get tplExchangeDesc;
  String get tplExchangeG1;
  String get tplExchangeG1M1;
  String get tplExchangeG1M2;
  String get tplExchangeG1T1;
  String get tplExchangeG2;
  String get tplExchangeG2M1;
  String get tplExchangeG2M2;
  String get tplExchangeG2T1;

  String get tplIntern;
  String get tplInternDesc;
  String get tplInternG1;
  String get tplInternG1M1;
  String get tplInternG1M2;
  String get tplInternG1T1;
  String get tplInternG2;
  String get tplInternG2M1;
  String get tplInternG2M2;
  String get tplInternG2T1;

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
  String get signUpWithGoogle;
  String get appTagline;
  String get registerTagline;
  String get authBulletTasks;
  String get authBulletTargets;
  String get authBulletVisions;
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
  String get deleteAccountConfirmPassword;
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

  // Password reset
  String get forgotPassword;
  String get resetPasswordHint;
  String get sendResetLink;
  String get resetEmailSent;
  String get setNewPassword;
  String get newPasswordLabel;
  String get passwordUpdated;

  // Shown when a write did not reach Supabase
  String get syncFailed;

  // Shown when a password-reset link does not work. Only the newest email is
  // valid, and PKCE ties the link to the device that requested it
  String get resetLinkInvalid;
  String get resetLinkWrongDevice;

  // ── Notifications (Phase 1) ───────────────────────────────────────────────
  String get notifications;
  String get notifEnabled;
  String get notifEnabledHint;
  String get notifTaskDue;
  String get notifTaskLead;
  // When a repeating task with no due time is reminded about
  String get notifRecurringTime;
  String get notifDailySummary;
  String get notifSummaryTime;
  String get notifGoalDeadline;
  String get notifGoalLead;
  String get notifPermissionDenied;
  String get notifUnsupportedPlatform;
  // Label for a lead time: 0 means "on time", otherwise minutes/hours/a day
  String notifLeadMinutes(int minutes);
  String notifLeadDays(int days);
  // Notification bodies and action buttons
  String get notifActionDone;
  String get notifActionReschedule;
  String notifActionFailed(String detail);
  String get notifSummaryTitle;
  String notifSummaryBody(int count);
  String get notifGoalTitle;
  String notifGoalBody(String semester, int count);
}
