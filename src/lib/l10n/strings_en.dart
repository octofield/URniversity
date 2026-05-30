import 'app_strings.dart';

class StringsEn implements AppStrings {
  const StringsEn();

  @override String get appName => 'URniversity';
  @override String get settings => 'Settings';
  @override String get backToToday => 'Back to Today';
  @override String get add => 'Add';
  @override String get titleField => 'Title';
  @override String get language => 'Language';
  @override String get langZhTw => '繁體中文';
  @override String get langEn => 'English';
  @override String get langJp => '日本語';

  @override String tasksCompleted(int c, int t) => '$c / $t tasks completed';
  @override String get tasks => 'Tasks';
  @override String get noTasks => 'No tasks yet';
  @override String get addTask => 'Add Task';
  @override String get taskNotes => 'Notes (optional)';
  @override String get priority => 'Priority:';
  @override String get priorityLow => 'Low';
  @override String get priorityMed => 'Med';
  @override String get priorityHigh => 'High';
  @override String get dueTime => 'Due time';
  @override String get clearTime => 'Clear';

  @override String get linkedTarget => 'Linked Target';
  @override String get selectTarget => 'Select Target';
  @override String get linkedGoal => 'Linked Goal';
  @override String get repeat => 'Repeat';
  @override String get repeatNone => 'No repeat';
  @override String get repeatDaily => 'Daily';
  @override String get repeatWeekly => 'Weekly';
  @override String get repeatMonthly => 'Monthly';
  @override String get repeatEveryNDays => 'Every N days';
  @override String get repeatInterval => 'Interval (days)';

  @override String get inspirations => 'Inspirations';
  @override String get noInspirations => 'No inspirations yet. Tap + to record one.';
  @override String get addInspiration => 'Add Inspiration';
  @override String get inspirationDetails => 'Details (optional)';

  @override String get me => 'Me';
  @override String get usernameLabel => 'Username';
  @override String get accountSettings => 'Account Settings';
  @override String get editUsername => 'Edit Username';
  @override String get journal => 'Journal';
  @override String get noJournal => 'No journal entries yet';
  @override String get addJournal => 'New Entry';
  @override String get editJournal => 'Edit Entry';
  @override String get journalContent => 'Content';

  @override String get semester => 'Semester';
  @override String get future => 'Future';
  @override String get targets => 'Targets';
  @override String get goals => 'Goals';

  @override String get dateFormat => 'Date Format';
  @override String get fmtMmddWeekday => 'MM/dd (weekday)';
  @override String get fmtMmdd => 'MM/dd';
  @override String get fmtYyyymmdd => 'yyyy/MM/dd';
  @override String get fmtLongDate => 'MMMM d';

  @override String get addTarget => 'Add Target';
  @override String get noTargets => 'No targets yet';
  @override String get editTarget => 'Edit Target';
  @override String goalProgress(int done, int total) => '$done / $total done';
  @override String get milestones => 'Milestones';
  @override String get addMilestone => 'Add Milestone';
  @override String get backToCurrentSem => 'This Semester';
  @override String get goalNotes => 'Notes (optional)';

  @override String get addGoal => 'Add Goal';
  @override String get noGoals => 'No goals yet';
  @override String get editGoal => 'Edit Goal';
  @override String get category => 'Category';
  @override String get catAll => 'All';
  @override String get catExchange => 'Exchange';
  @override String get catIntern => 'Internship';
  @override String get catCompetition => 'Competition';
  @override String get catCertification => 'Certification';
  @override String get catPerformance => 'Performance';
  @override String get catOther => 'Other';
  @override String get startSemester => 'Start';
  @override String get endSemester => 'End';
  @override String get subgoals => 'Subgoals';
  @override String get addSubgoal => 'Add Subgoal';
  @override String get editTask => 'Edit Task';
  @override String get save => 'Save';
  @override String get addCategory => 'Add Category';
  @override String get categoryName => 'Category Name';
  @override String get linkedFutureGoal => 'Linked Goal';
  @override String get selectFutureGoal => 'Select Goal';
  @override String get noLink => 'No Link';
  @override String get more => 'More';

  @override String get semesterSettings => 'Semester Settings';
  @override String get semesterCount => 'Semester System';
  @override String get twoSemesters => 'Two-semester';
  @override String get threeSemesters => 'Three-semester';
  @override String get fourSemesters => 'Four-semester';
  @override String get semesterStartMonth => 'Start Month';

  @override String get goalDetail => 'Goal Details';
  @override String get linkedTasks => 'Linked Tasks';
  @override String get linkedTargets => 'Linked Semester Targets';

  @override String get trash => 'Trash';
  @override String get restore => 'Restore';
  @override String get emptyTrash => 'Empty Trash';
  @override String get noTrash => 'Trash is empty';
  @override String get markDone => 'Mark Done';
  @override String get markUndone => 'Unmark Done';

  @override String get dailyTasks => 'Today';
  @override String get weeklyTasks => 'This Week';
  @override String get allTasks => 'All Tasks';
  @override String get defaultTaskView => 'Default Task View';
  @override String get createdAtLabel => 'Created';
  @override String get completedTasks => 'Completed Tasks';
  @override String get delete => 'Delete';
  @override String weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }
  @override String get addLinkedTask => 'Link Task';
  @override String get addLinkedTarget => 'Link Target';
  @override String get addLinkedGoal => 'Link Goal';
  @override String get selectTask => 'Select Task';
  @override String get reset => 'Reset';
  @override String get school => 'School';
  @override String get department => 'Department';
  @override String get grade => 'Year';
  @override String get allInspirations => 'All Inspirations';
  @override String get completed => 'Completed';
  @override String get pending => 'Active';
  @override String get allJournals => 'All Journals';
  @override String get writeJournal => 'Write Journal';
  @override String get showJournalDayCounter => 'Journal Day Counter';
  @override String get versionLabel => 'Version';
  @override String get developerMode => 'Developer Mode';
  @override String get devTimeOverride => 'Custom Date';
  @override String get logout => 'Log Out';
  @override String get deleteAccount => 'Delete Account';
  @override String get exitGuestMode => 'Exit Guest Mode';
  @override String get feedbackTitle => 'Feedback & Bug Report';
  @override String get feedbackBug => 'Bug Report';
  @override String get feedbackSuggestion => 'Feature Suggestion';
  @override String get feedbackAnonymousNote => 'Feedback is anonymous. No personal information is collected.';
  @override String get feedbackBugHint => 'Describe what happened…';
  @override String get feedbackSuggestionHint => 'Describe the feature you\'d like to see…';
  @override String get feedbackSubmit => 'Submit';
  @override String get feedbackErrorMinLength => 'Please enter at least 10 characters';
  @override String get feedbackErrorCooldown => 'Please wait 5 minutes before submitting again';
  @override String get feedbackErrorFailed => 'Submission failed. Please try again later.';
}
