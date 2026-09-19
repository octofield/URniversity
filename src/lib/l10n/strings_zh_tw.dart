import 'app_strings.dart';

class StringsZhTw implements AppStrings {
  const StringsZhTw();

  @override String get appName => 'URniversity';
  @override String get settings => '設定';
  @override String get backToToday => '回到今天';
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
  @override String get dueTime => '截止時間';

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
  @override String repeatWeeklyOn(String days) => '每週$days';
  @override String repeatMonthlyOn(String days) => '每月$days';
  @override String monthDayShort(int day) => '$day號';
  @override String repeatEveryNDaysShort(int n) => '每 $n 天';
  @override String get repeatMonthLastDay => '最後一天';

  @override String get inspirations => '靈感';
  @override String get noInspirations => '尚無靈感，點 + 記錄';
  @override String get addInspiration => '新增靈感';
  @override String get inspirationDetails => '詳細（選填）';

  @override String get me => '我的';
  @override String get usernameLabel => '使用者名稱';
  @override String get accountSettings => '帳號設定';
  @override String get journal => '日記';
  @override String get noJournal => '尚無日記';
  @override String get addJournal => '新增日記';
  @override String get editJournal => '編輯日記';
  @override String get journalContent => '內容';

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
  @override String get categoryName => '分類名稱';
  @override String get linkedFutureGoal => '連結的願景';
  @override String get selectFutureGoal => '選擇願景';
  @override String get noLink => '無連結';
  @override String get more => '更多';
  @override String get pickColor => '選擇顏色';
  @override String get pickIcon => '選擇圖示';
  @override String get categorySettings => '分類設定';
  @override String get winterBreak => '寒假';
  @override String get summerBreak => '暑假';
  @override String get springBreak => '春假';
  @override String get autumnBreak => '秋假';
  @override String get progressOverview => '進度總覽';
  @override String get filters => '篩選';
  @override String greetingMorning(String name) => name.isEmpty ? '早安 👋' : '早安，$name 👋';
  @override String greetingAfternoon(String name) => name.isEmpty ? '午安 👋' : '午安，$name 👋';
  @override String greetingEvening(String name) => name.isEmpty ? '晚安 👋' : '晚安，$name 👋';
  @override String todayStatus(int total, int done) => total == 0 ? '今天還沒有安排任務' : '今天有 $total 件事，完成了 $done 件';
  @override String get allDoneToday => '今天全部完成！';
  @override String get overview => '關聯圖';
  @override String get unlinked => '未連結';
  @override String get overviewEmpty => '還沒有任何目標或願景';
  @override String get profile => '個人資料';
  @override String get taskHistory => '完成度歷史';
  @override String get historyDaily => '每日';
  @override String get historyWeekly => '每週';
  @override String get historyMonthly => '每月';
  @override String get historyNoData => '無資料';
  @override String get historyTapHint => '點擊長條查看詳情';
  @override String get historyAverageLabel => '平均完成率';
  @override String historyVsPrevious(String delta) => '較上一期 $delta';
  @override String get historyStreak => '連續達成';
  @override String get historyStreakSub => '全部做完的日子';
  @override String get historyCompletedTasks => '完成任務';
  @override String get historyBestWeekday => '最強的一天';
  @override String get historyByCategory => '各分類的完成率';
  @override String historyCategoryBehind(String name, int left) =>
      '「$name」落後最多，還有 $left 件沒做';
  @override String get historyStale => '拖最久的任務';
  @override String historyOverdue(int days) => '逾期 $days 天';
  @override String get historyNothingStale => '沒有逾期的任務';
  @override String get graphLegend => '圖例';
  @override String get graphLegendTaskCount => '數字＝底下的任務';
  @override String get graphLegendDimmed => '淡色＝其他學期';
  @override String get graphFilterUnfinished => '未完成';
  @override String get graphOpen => '打開';
  @override String graphViewTasks(int count) => '看 $count 個任務';
  @override String get graphNextDue => '最近截止';

  @override String get semesterSettings => '學期設定';
  @override String get semesterCount => '學期制';
  @override String get twoSemesters => '兩學期制';
  @override String get threeSemesters => '三學期制';
  @override String get fourSemesters => '四學期制';
  @override String get semesterStartMonth => '開始月份';

  @override String get linkedTasks => '連結的任務';
  @override String get linkedTargets => '連結的學期目標';

  @override String get trash => '垃圾桶';
  @override String get restore => '復原';
  @override String get emptyTrash => '清空垃圾桶';
  @override String get noTrash => '垃圾桶是空的';
  @override String get markDone => '標記完成';
  @override String get markUndone => '取消完成';

  @override String get dailyTasks => '當日任務';
  @override String get weeklyTasks => '當週任務';
  @override String get allTasks => '所有任務';
  @override String get defaultTaskView => '預設任務視角';
  @override String get createdAtLabel => '建立時間';
  @override String get completedTasks => '已完成的任務';
  @override String tasksWithCount(int count) => '任務（$count）';
  @override String completedTasksWithCount(int count) => '已完成的任務（$count）';
  @override String get noSemester => '未設定學期';
  @override String journalStreakDays(int days) => '連續 $days 天';
  @override String get completionEffect => '完成任務的動畫';
  @override String get effectOff => '關閉';
  @override String get effectBasic => '基本';
  @override String get effectCelebrate => '基本＋彩帶';
  @override String get delete => '刪除';
  @override String weekdayShort(int weekday) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return names[weekday - 1];
  }
  @override String get addLinkedTask => '新增連結任務';
  @override String get addLinkedTarget => '新增連結目標';
  @override String get addLinkedGoal => '新增連結願景';
  @override String get selectTask => '選擇任務';
  @override String get reset => '重置';
  @override String get school => '學校';
  @override String get department => '系所';
  @override String get grade => '年級';
  @override String get allInspirations => '所有靈感';
  @override String get completed => '已完成';
  @override String get pending => '進行中';
  @override String get allJournals => '所有日記';
  @override String get writeJournal => '撰寫日記';
  @override String get showJournalDayCounter => '日記顯示天數';
  @override String get versionLabel => '版本';
  @override String get developerMode => '開發者模式';
  @override String get devTimeOverride => '自訂系統日期';
  @override String get logout => '登出';
  @override String get deleteAccount => '刪除帳號';
  @override String get exitGuestMode => '退出訪客模式';
  @override String get feedbackTitle => '回饋與問題回報';
  @override String get feedbackBug => '問題回報';
  @override String get feedbackSuggestion => '功能建議';
  @override String get feedbackAnonymousNote => '回饋為匿名，不會記錄任何個人資訊。';
  @override String get feedbackBugHint => '描述問題發生的情況…';
  @override String get feedbackSuggestionHint => '描述你希望加入的功能…';
  @override String get feedbackSubmit => '送出';
  @override String get feedbackErrorMinLength => '請至少輸入 10 個字元';
  @override String get feedbackErrorCooldown => '請等待 5 分鐘後再回報';
  @override String get feedbackErrorFailed => '送出失敗，請稍後再試';

  @override String get login => '登入';
  @override String get register => '註冊';
  @override String get createAccount => '建立帳號';
  @override String get registerHeadline => '開始使用 URniversity';
  @override String get emailLabel => '電子郵件';
  @override String get passwordLabel => '密碼';
  @override String get passwordLabelWithHint => '密碼（至少 6 字元）';
  @override String get confirmPasswordLabel => '確認密碼';
  @override String get orDivider => '或';
  @override String get signInWithGoogle => '使用 Google 登入';
  @override String get noAccountYet => '還沒有帳號？';
  @override String get haveAccountAlready => '已有帳號？';
  @override String get backToGuestMode => '返回訪客模式';
  @override String get tryAsGuest => '以訪客身份體驗';
  @override String get passwordMismatch => '兩次密碼不一致';
  @override String get passwordTooShort => '密碼至少 6 個字元';
  @override String get checkVerificationEmail => '請到信箱確認驗證信，完成後即可登入';

  @override String get setupProfileTitle => '設定個人資料';
  @override String get setupProfileSubtitle => '之後可在帳號設定中修改';
  @override String get pickAvatar => '選擇頭像';
  @override String get avatar => '頭像';
  @override String get done => '完成';
  @override String get confirm => '確定';
  @override String get guest => '訪客';
  @override String get loginMethod => '登入方式';
  @override String gradeLabel(int grade) {
    const labels = ['一', '二', '三', '四', '五', '六', '七'];
    final i = grade - 1;
    return i >= 0 && i < labels.length ? labels[i] : '$grade';
  }
  @override String pickerSearchHint(String field) => '搜尋$field';
  @override String pickerCustomInput(String field) => '輸入$field';
  @override String get pickerOther => '其他（自行輸入）';

  @override String get loginOrCreateAccount => '登入 / 建立帳號';
  @override String get mergeGuestDataQuestion => '登入後，目前的訪客資料要如何處理？';
  @override String get discardGuestData => '捨棄資料';
  @override String get mergeGuestData => '整合進帳號';

  @override String get exitGuestConfirm => '退出後所有訪客資料將會清除，無法復原。確定繼續？';
  @override String get exitAction => '退出';
  @override String get logoutConfirm => '確定要登出嗎？';
  @override String deleteAccountConfirmEmail(String email) =>
      '此操作無法還原，所有資料將永久刪除。\n請輸入你的信箱「$email」以確認。';
  @override String get deleteAccountConfirmPassword =>
      '此操作無法還原，所有資料將永久刪除。\n請輸入密碼以確認。';
  @override String get emailMismatch => '信箱不相符';
  @override String get confirmDeleteAction => '確認刪除';

  @override String get emptyTrashConfirm => '所有項目將被永久刪除，無法復原。';
  @override String deletedOn(String date) => '$date 刪除';
  @override String get permanentDelete => '永久刪除';

  @override String get deleteConfirm => '刪除？';
  @override String createdAtValue(String value) => '建立時間：$value';
  @override String percentSuffix(int percent) => '（$percent%）';
  @override String dateWithWeekday(String date, String weekday) => '$date（$weekday）';
  @override String dateLongDate(int month, int day) => '$month月$day日';

  @override String get syncFailed => '同步失敗，剛才的變更可能沒有存到雲端';

  @override String get forgotPassword => '忘記密碼？';
  @override String get resetPasswordHint => '輸入註冊時使用的電子郵件，我們會寄一封重設連結給你。';
  @override String get sendResetLink => '寄出重設連結';
  @override String get resetEmailSent => '重設連結已寄出，請到信箱查看';
  @override String get setNewPassword => '設定新密碼';
  @override String get newPasswordLabel => '新密碼（至少 6 字元）';
  @override String get passwordUpdated => '密碼已更新';
  @override String get resetLinkInvalid => '重設連結已失效或已被使用，請重新寄送一次（只有最新一封有效）';
  @override String get resetLinkWrongDevice => '請在按下「忘記密碼」的那個裝置與瀏覽器開啟連結';

  @override String get notifications => '通知';
  @override String get notifEnabled => '開啟通知';
  @override String get notifEnabledHint => '關閉後，下面三項都不會提醒';
  @override String get notifTaskDue => '任務到期提醒';
  @override String get notifTaskLead => '提前多久提醒';
  @override String get notifDailySummary => '每日摘要';
  @override String get notifSummaryTime => '摘要時間';
  @override String get notifGoalDeadline => '學期目標截止提醒';
  @override String get notifGoalLead => '提前幾天提醒';
  @override String get notifPermissionDenied => '系統擋下了通知權限，請到系統設定開啟';
  @override String get notifUnsupportedPlatform => '這個平台不支援通知，請用手機 App';
  @override String notifLeadMinutes(int minutes) {
    if (minutes == 0) return '準時';
    if (minutes < 60) return '$minutes 分鐘前';
    if (minutes < 1440) return '${minutes ~/ 60} 小時前';
    return '1 天前';
  }
  @override String notifLeadDays(int days) => '$days 天前';
  @override String get notifActionDone => '標示為已完成';
  @override String get notifActionReschedule => '重新安排時間';
  @override String notifActionFailed(String detail) => '從通知標示完成時同步失敗：$detail';
  @override String get notifSummaryTitle => '今天的安排';
  @override String notifSummaryBody(int count) => '今天有 $count 件事要做';
  @override String get notifGoalTitle => '學期快結束了';
  @override String notifGoalBody(String semester, int count) =>
      '$semester 還有 $count 個目標沒完成';
}
