import 'app_strings.dart';

class StringsZhTw implements AppStrings {
  const StringsZhTw();

  @override String get appName => 'URniversity';
  @override String get settings => '設定';
  @override String get backToToday => '今天';
  @override String get add => '新增';
  @override String get titleField => '標題';
  @override String get language => '語言';
  @override String get langZhTw => '繁體中文';
  @override String get langEn => 'English';
  @override String get langJp => '日本語';

  @override String tasksCompleted(int c, int t) => '$c / $t 任務已完成';
  @override String get tasks => '任務';
  @override String get noTasks => '尚無任務';
  @override String get addTask => '新增任務';
  @override String get taskNotes => '備註（選填）';
  @override String get priority => '優先度：';
  @override String get priorityLow => '低';
  @override String get priorityMed => '中';
  @override String get priorityHigh => '高';
  @override String get dueTime => '截止時間';
  @override String get clearTime => '清除';

  @override String get linkedTarget => '連結目標';
  @override String get selectTarget => '選擇目標';
  @override String get linkedGoal => '連結願景';
  @override String get repeat => '重複';
  @override String get repeatNone => '不重複';
  @override String get repeatDaily => '每天';
  @override String get repeatWeekly => '每週';
  @override String get repeatMonthly => '每月';
  @override String get repeatEveryNDays => '每隔幾天';
  @override String get repeatInterval => '間隔（天）';

  @override String get inspirations => '靈感';
  @override String get noInspirations => '尚無靈感，點 + 記錄';
  @override String get addInspiration => '新增靈感';
  @override String get inspirationDetails => '詳細（選填）';

  @override String get concentration => '專注';
  @override String concentrationToday(String t) => '今日：$t';
  @override String concentrationSession(String t) => '本次：$t';
  @override String get start => '開始';
  @override String get stop => '停止';

  @override String get semester => '學期';
  @override String get future => '未來';
  @override String get targets => '目標';
  @override String get goals => '願景';

  @override String get dateFormat => '日期格式';
  @override String get fmtMmddWeekday => 'MM/dd（星期）';
  @override String get fmtMmdd => 'MM/dd';
  @override String get fmtYyyymmdd => 'yyyy/MM/dd';
  @override String get fmtLongDate => 'MMMM d';

  @override String get addTarget => '新增目標';
  @override String get noTargets => '尚無目標';
  @override String get editTarget => '編輯目標';
  @override String goalProgress(int done, int total) => '$done / $total 完成';
  @override String get milestones => '子目標';
  @override String get addMilestone => '新增子目標';
  @override String get backToCurrentSem => '本學期';
  @override String get goalNotes => '備註（選填）';

  @override String get addGoal => '新增願景';
  @override String get noGoals => '尚無願景';
  @override String get editGoal => '編輯願景';
  @override String get category => '分類';
  @override String get catAll => '全部';
  @override String get catExchange => '交換';
  @override String get catIntern => '實習';
  @override String get catCompetition => '競賽';
  @override String get catCertification => '證照';
  @override String get catPerformance => '表演';
  @override String get catOther => '其他';
  @override String get startSemester => '開始學期';
  @override String get endSemester => '結束學期';
  @override String get subgoals => '子願景';
  @override String get addSubgoal => '新增子願景';
  @override String get editTask => '編輯任務';
  @override String get save => '儲存';
  @override String get addCategory => '新增分類';
  @override String get categoryName => '分類名稱';
  @override String get linkedFutureGoal => '連結的願景';
  @override String get selectFutureGoal => '選擇願景';
  @override String get noLink => '無連結';
  @override String get more => '更多';

  @override String get semesterSettings => '學期設定';
  @override String get semesterCount => '學期制';
  @override String get twoSemesters => '兩學期制';
  @override String get threeSemesters => '三學期制';
  @override String get fourSemesters => '四學期制';
  @override String get semesterStartMonth => '開始月份';

  @override String get trash => '垃圾桶';
  @override String get restore => '復原';
  @override String get emptyTrash => '清空垃圾桶';
  @override String get noTrash => '垃圾桶是空的';
  @override String get markDone => '標記完成';
  @override String get markUndone => '取消完成';
}
