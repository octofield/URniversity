import 'app_strings.dart';

class StringsJp implements AppStrings {
  const StringsJp();

  @override String get appName => 'URniversity';
  @override String get settings => '設定';
  @override String get backToToday => '今日';
  @override String get add => '追加';
  @override String get titleField => 'タイトル';
  @override String get language => '言語';
  @override String get langZhTw => '繁體中文';
  @override String get langEn => 'English';
  @override String get langJp => '日本語';

  @override String tasksCompleted(int c, int t) => '$c / $t タスク完了';
  @override String get tasks => 'タスク';
  @override String get noTasks => 'タスクがありません。＋ をタップして追加';
  @override String get addTask => 'タスクを追加';
  @override String get taskNotes => 'メモ（任意）';
  @override String get priority => '優先度：';
  @override String get priorityLow => '低';
  @override String get priorityMed => '中';
  @override String get priorityHigh => '高';
  @override String get dueTime => '期限';
  @override String get clearTime => 'クリア';

  @override String get linkedTarget => '連結ターゲット';
  @override String get selectTarget => 'ターゲットを選択';
  @override String get linkedGoal => '連結ゴール';
  @override String get repeat => '繰り返し';
  @override String get repeatNone => '繰り返しなし';
  @override String get repeatDaily => '毎日';
  @override String get repeatWeekly => '毎週';
  @override String get repeatMonthly => '毎月';
  @override String get repeatEveryNDays => 'N日ごと';
  @override String get repeatInterval => '間隔（日）';

  @override String get inspirations => 'インスピレーション';
  @override String get noInspirations => 'インスピレーションがありません。＋ をタップして記録';
  @override String get addInspiration => 'インスピレーションを追加';
  @override String get inspirationDetails => '詳細（任意）';

  @override String get concentration => '集中';
  @override String concentrationToday(String t) => '今日：$t';
  @override String concentrationSession(String t) => 'セッション：$t';
  @override String get start => '開始';
  @override String get stop => '停止';

  @override String get semester => '学期';
  @override String get future => '未来';
  @override String get targets => 'ターゲット';
  @override String get goals => 'ゴール';

  @override String get dateFormat => '日付形式';
  @override String get fmtMmddWeekday => 'MM/dd（曜日）';
  @override String get fmtMmdd => 'MM/dd';
  @override String get fmtYyyymmdd => 'yyyy/MM/dd';
  @override String get fmtLongDate => 'M月d日';

  @override String get addTarget => 'ターゲットを追加';
  @override String get noTargets => 'ターゲットがありません';
  @override String get editTarget => 'ターゲットを編集';
  @override String goalProgress(int done, int total) => '$done / $total 完了';
  @override String get milestones => 'マイルストーン';
  @override String get addMilestone => 'マイルストーンを追加';
  @override String get backToCurrentSem => '今学期';
  @override String get goalNotes => 'メモ（任意）';

  @override String get addGoal => 'ゴールを追加';
  @override String get noGoals => 'ゴールがありません';
  @override String get editGoal => 'ゴールを編集';
  @override String get category => 'カテゴリ';
  @override String get catAll => '全て';
  @override String get catExchange => '留学';
  @override String get catIntern => 'インターン';
  @override String get catCompetition => '競技';
  @override String get catCertification => '資格';
  @override String get catPerformance => '公演';
  @override String get catOther => 'その他';
  @override String get startSemester => '開始';
  @override String get endSemester => '終了';
  @override String get subgoals => 'サブ目標';
  @override String get addSubgoal => 'サブ目標を追加';
  @override String get editTask => 'タスクを編集';
  @override String get save => '保存';
  @override String get addCategory => 'カテゴリを追加';
  @override String get categoryName => 'カテゴリ名';
  @override String get linkedFutureGoal => '連結ゴール';
  @override String get selectFutureGoal => 'ゴールを選択';
  @override String get noLink => 'リンクなし';
  @override String get more => 'もっと';

  @override String get semesterSettings => '学期設定';
  @override String get semesterCount => '学期制';
  @override String get twoSemesters => '二学期制';
  @override String get threeSemesters => '三学期制';
  @override String get fourSemesters => '四学期制';
  @override String get semesterStartMonth => '開始月';
}
