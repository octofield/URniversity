import 'app_strings.dart';

class StringsJp implements AppStrings {
  const StringsJp();

  @override String get appName => 'URniversity';
  @override String get settings => '設定';
  @override String get backToToday => '今日に戻る';
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
  @override String get dueTime => '期限';

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
  @override String repeatWeeklyOn(String days) => '毎週$days';
  @override String repeatMonthlyOn(String days) => '毎月$days';
  @override String monthDayShort(int day) => '$day日';
  @override String repeatEveryNDaysShort(int n) => '$n日ごと';
  @override String get repeatMonthLastDay => '月末';

  @override String get inspirations => 'インスピレーション';
  @override String get noInspirations => 'インスピレーションがありません。＋ をタップして記録';
  @override String get addInspiration => 'インスピレーションを追加';
  @override String get inspirationDetails => '詳細（任意）';

  @override String get me => 'マイ';
  @override String get usernameLabel => 'ユーザー名';
  @override String get accountSettings => 'アカウント設定';
  @override String get journal => '日記';
  @override String get noJournal => '日記がありません';
  @override String get addJournal => '日記を追加';
  @override String get editJournal => '日記を編集';
  @override String get journalContent => '内容';

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
  @override String get categoryName => 'カテゴリ名';
  @override String get linkedFutureGoal => '連結ゴール';
  @override String get selectFutureGoal => 'ゴールを選択';
  @override String get noLink => 'リンクなし';
  @override String get more => 'もっと';
  @override String get pickColor => '色を選ぶ';
  @override String get pickIcon => 'アイコンを選ぶ';
  @override String get categorySettings => 'カテゴリ設定';
  @override String get winterBreak => '冬休み';
  @override String get summerBreak => '夏休み';
  @override String get springBreak => '春休み';
  @override String get autumnBreak => '秋休み';
  @override String get progressOverview => '進捗まとめ';
  @override String get filters => '絞り込み';
  @override String get anySemester => '学期を問わない';
  @override String get deleteAccountWhatGoes => '次のデータもすべて削除されます：';
  @override String get deleteAccountReauthHint =>
      '誤操作を防ぐため、削除の前に Google でもう一度ログインします。';
  @override String get deleteAccountReauthGoogle => 'Google で再認証';
  @override String get deleteAccountVerified =>
      '認証が完了しました。削除するとアカウントと上記のデータは元に戻せません。';
  @override String get signInBadCredentials => 'メールアドレスまたはパスワードが違います';
  @override String get signInEmailNotConfirmed => 'このメールはまだ確認されていません。届いたリンクを開いてください';
  @override String get signInTooManyTries => '試行回数が多すぎます。数分おいてからお試しください';
  @override String get signInNetwork => 'サーバーに接続できません。通信環境をご確認ください';
  @override String get signInUnknown => 'ログインできませんでした。しばらくしてからお試しください';
  @override String get sortBy => '並び替え';
  @override String minutesLater(int minutes) => '$minutes 分後';
  @override String hoursLater(int hours) => '$hours 時間後';
  @override String get sortManual => '手動（ドラッグ）';
  @override String get sortCreated => '追加日時';
  @override String get sortTitle => 'A–Z';
  @override String get sortTarget => '目標ごと';
  @override String get sortDue => '締切順';
  @override String get sortVision => 'ビジョンごと';
  @override String get sortUndoneFirst => '未完了を先に';
  @override String get sortStartSemester => '開始学期順';
  @override String get sortEndSemester => '終了学期順';
  @override String get sortRearrange => '順番を並べ替える';
  @override String greetingMorning(String name) => name.isEmpty ? 'おはよう 👋' : 'おはよう、$name 👋';
  @override String greetingAfternoon(String name) => name.isEmpty ? 'こんにちは 👋' : 'こんにちは、$name 👋';
  @override String greetingEvening(String name) => name.isEmpty ? 'こんばんは 👋' : 'こんばんは、$name 👋';
  @override String todayStatus(int total, int done) => total == 0 ? '今日の予定はまだありません' : '今日は $total 件中 $done 件完了';
  @override String get allDoneToday => '今日は全部完了！';
  @override String get overview => '関連マップ';
  @override String get unlinked => '未リンク';
  @override String get overviewEmpty => '目標も長期目標もまだありません';
  @override String targetsSummary(int count, int done, int total) =>
      '目標 $count 件、マイルストーン $done/$total 完了';
  @override String visionsSummary(int count, int done, int total) =>
      'ビジョン $count 件、サブ $done/$total 完了';
  @override String get profile => 'プロフィール';
  @override String get taskHistory => '完了率の履歴';
  @override String get historyDaily => '日別';
  @override String get historyWeekly => '週別';
  @override String get historyMonthly => '月別';
  @override String get historyNoData => 'データなし';
  @override String get historyTapHint => 'バーをタップして詳細を表示';
  @override String get historyAverageLabel => '平均完了率';
  @override String historyVsPrevious(String delta) => '前期比 $delta';
  @override String get historyStreak => '連続達成';
  @override String get historyStreakSub => 'すべて終えた日';
  @override String get historyCompletedTasks => '完了タスク';
  @override String get historyBestWeekday => '一番強い曜日';
  @override String get historyByCategory => 'カテゴリ別の完了率';
  @override String historyCategoryBehind(String name, int left) =>
      '「$name」が一番遅れています（あと $left 件）';
  @override String get historyStale => '一番長く残っているタスク';
  @override String historyOverdue(int days) => '$days 日遅れ';
  @override String get historyNothingStale => '遅れているタスクはありません';
  @override String get graphLegend => '凡例';
  @override String get graphLegendTaskCount => '数字＝ぶら下がるタスク';
  @override String get graphLegendDimmed => '薄い色＝ほかの学期';
  @override String get graphFilterUnfinished => '未完了';
  @override String get graphOpen => '開く';
  @override String graphViewTasks(int count) => 'タスク $count 件を見る';
  @override String get graphNextDue => '直近の締切';

  @override String get semesterSettings => '学期設定';
  @override String get semesterCount => '学期制';
  @override String get twoSemesters => '二学期制';
  @override String get threeSemesters => '三学期制';
  @override String get fourSemesters => '四学期制';
  @override String get semesterStartMonth => '開始月';

  @override String get linkedTasks => '関連タスク';
  @override String get linkedTargets => '関連する学期目標';

  @override String get trash => 'ゴミ箱';
  @override String get restore => '元に戻す';
  @override String get emptyTrash => 'ゴミ箱を空にする';
  @override String get noTrash => 'ゴミ箱は空です';
  @override String get markDone => '完了にする';
  @override String get markUndone => '未完了に戻す';

  @override String get dailyTasks => '今日';
  @override String get weeklyTasks => '今週';
  @override String get allTasks => 'すべてのタスク';
  @override String get defaultTaskView => 'デフォルトのタスクビュー';
  @override String get createdAtLabel => '作成日時';
  @override String get completedTasks => '完了したタスク';
  @override String tasksWithCount(int count) => 'タスク（$count）';
  @override String completedTasksWithCount(int count) => '完了したタスク（$count）';
  @override String get noSemester => '学期未設定';
  @override String journalStreakDays(int days) => '連続 $days 日';
  @override String get completionEffect => 'タスク完了の演出';
  @override String get effectOff => 'オフ';
  @override String get effectBasic => '基本';
  @override String get effectCelebrate => '基本＋紙吹雪';
  @override String get delete => '削除';
  @override String weekdayShort(int weekday) {
    const names = ['月', '火', '水', '木', '金', '土', '日'];
    return names[weekday - 1];
  }
  @override String get addLinkedTask => 'タスクをリンク';
  @override String get addLinkedTarget => 'ターゲットをリンク';
  @override String get addLinkedGoal => 'ゴールをリンク';
  @override String get selectTask => 'タスクを選択';
  @override String get reset => 'リセット';
  @override String get school => '学校';
  @override String get department => '学部・学科';
  @override String get grade => '学年';
  @override String get allInspirations => 'すべてのインスピレーション';
  @override String get completed => '完了';
  @override String get pending => '進行中';
  @override String get allJournals => 'すべての日記';
  @override String get writeJournal => '日記を書く';
  @override String get showJournalDayCounter => '日記の日数を表示';
  @override String get versionLabel => 'バージョン';
  @override String get developerMode => '開発者モード';
  @override String get devTimeOverride => 'カスタム日付';
  @override String get logout => 'ログアウト';
  @override String get deleteAccount => 'アカウント削除';
  @override String get exitGuestMode => 'ゲストモード終了';
  @override String get feedbackTitle => 'フィードバック・バグ報告';
  @override String get feedbackBug => 'バグ報告';
  @override String get feedbackSuggestion => '機能提案';
  @override String get feedbackAnonymousNote => 'フィードバックは匿名です。個人情報は収集されません。';
  @override String get feedbackBugHint => '問題の内容を説明してください…';
  @override String get feedbackSuggestionHint => '追加してほしい機能を説明してください…';
  @override String get feedbackSubmit => '送信';
  @override String get feedbackErrorMinLength => '10文字以上入力してください';
  @override String get feedbackErrorCooldown => '5分後に再度送信してください';
  @override String get feedbackErrorFailed => '送信に失敗しました。後でもう一度お試しください。';

  @override String get login => 'ログイン';
  @override String get register => '新規登録';
  @override String get createAccount => 'アカウント作成';
  @override String get registerHeadline => 'URniversity をはじめる';
  @override String get emailLabel => 'メールアドレス';
  @override String get passwordLabel => 'パスワード';
  @override String get passwordLabelWithHint => 'パスワード（6文字以上）';
  @override String get confirmPasswordLabel => 'パスワード（確認）';
  @override String get orDivider => 'または';
  @override String get signInWithGoogle => 'Google でログイン';
  @override String get signUpWithGoogle => 'Google で登録';
  @override String get appTagline => '大学生活をひとつの場所に';
  @override String get registerTagline => 'どの端末でも同じ進み具合が見られます';
  @override String get authBulletTasks => '今日やることが一目で分かる';
  @override String get authBulletTargets => '学期ごとの目標とマイルストーン';
  @override String get authBulletVisions => '行きたい場所を、見えるかたちに';
  @override String get noAccountYet => 'アカウントをお持ちでない方';
  @override String get haveAccountAlready => 'すでにアカウントをお持ちの方';
  @override String get backToGuestMode => 'ゲストモードに戻る';
  @override String get tryAsGuest => 'ゲストとして試す';
  @override String get passwordMismatch => 'パスワードが一致しません';
  @override String get passwordTooShort => 'パスワードは6文字以上必要です';
  @override String get checkVerificationEmail => '確認メールをご確認ください。完了後にログインできます';

  @override String get setupProfileTitle => 'プロフィール設定';
  @override String get setupProfileSubtitle => '後でアカウント設定から変更できます';
  @override String get pickAvatar => 'アバターを選択';
  @override String get avatar => 'アバター';
  @override String get done => '完了';
  @override String get confirm => '確定';
  @override String get guest => 'ゲスト';
  @override String get loginMethod => 'ログイン方法';
  @override String gradeLabel(int grade) => '$grade';
  @override String pickerSearchHint(String field) => '$fieldを検索';
  @override String pickerCustomInput(String field) => '$fieldを入力';
  @override String get pickerOther => 'その他（自分で入力）';

  @override String get loginOrCreateAccount => 'ログイン / アカウント作成';
  @override String get mergeGuestDataQuestion => 'ログイン後、現在のゲストデータをどうしますか？';
  @override String get discardGuestData => '破棄する';
  @override String get mergeGuestData => 'アカウントに統合';

  @override String get exitGuestConfirm => 'ゲストモードを終了するとゲストデータはすべて削除され、元に戻せません。続行しますか？';
  @override String get exitAction => '終了';
  @override String get logoutConfirm => 'ログアウトしますか？';
  @override String get deleteAccountConfirmPassword =>
      'この操作は取り消せません。すべてのデータが完全に削除されます。\n確認のためパスワードを入力してください。';
  @override String get confirmDeleteAction => '削除を確認';

  @override String get emptyTrashConfirm => 'すべての項目が完全に削除され、元に戻せません。';
  @override String deletedOn(String date) => '$date 削除';
  @override String get permanentDelete => '完全に削除';

  @override String get deleteConfirm => '削除しますか？';
  @override String createdAtValue(String value) => '作成日時：$value';
  @override String percentSuffix(int percent) => '（$percent%）';
  @override String dateWithWeekday(String date, String weekday) => '$date（$weekday）';
  @override String dateLongDate(int month, int day) => '$month月$day日';

  @override String get syncFailed => '同期に失敗しました。変更が保存されていない可能性があります';

  @override String get forgotPassword => 'パスワードをお忘れですか？';
  @override String get resetPasswordHint => '登録に使用したメールアドレスを入力してください。再設定リンクをお送りします。';
  @override String get sendResetLink => '再設定リンクを送信';
  @override String get resetEmailSent => '再設定リンクを送信しました。メールをご確認ください';
  @override String get setNewPassword => '新しいパスワードを設定';
  @override String get newPasswordLabel => '新しいパスワード（6文字以上）';
  @override String get passwordUpdated => 'パスワードを更新しました';
  @override String get resetLinkInvalid => 'この再設定リンクは期限切れか使用済みです。もう一度送信してください（最新のメールのみ有効です）';
  @override String get resetLinkWrongDevice => '「パスワードをお忘れですか？」を押した端末とブラウザでリンクを開いてください';

  @override String get notifications => '通知';
  @override String get notifEnabled => '通知をオンにする';
  @override String get notifEnabledHint => 'オフにすると下の3つはすべて通知されません';
  @override String get notifTaskDue => 'タスクの期限通知';
  @override String get notifTaskLead => '通知タイミング';
  @override String get notifRecurringTime => '時刻なしの繰り返しタスク';
  @override String get notifDailySummary => '今日のまとめ';
  @override String get notifSummaryTime => 'まとめの時刻';
  @override String get notifGoalDeadline => '学期目標の締切通知';
  @override String get notifGoalLead => '何日前に通知';
  @override String get notifPermissionDenied => '通知の許可がブロックされています。端末の設定から有効にしてください';
  @override String get notifUnsupportedPlatform => 'このプラットフォームでは通知を表示できません。モバイルアプリをご利用ください';
  @override String notifLeadMinutes(int minutes) {
    if (minutes == 0) return '時間ちょうど';
    if (minutes < 60) return '$minutes 分前';
    if (minutes < 1440) return '${minutes ~/ 60} 時間前';
    return '1 日前';
  }
  @override String notifLeadDays(int days) => '$days 日前';
  @override String get notifActionDone => '完了にする';
  @override String get notifActionReschedule => '時間を変更';
  @override String notifActionFailed(String detail) => '通知から完了にした際に同期できませんでした：$detail';
  @override String get notifSummaryTitle => '今日の予定';
  @override String notifSummaryBody(int count) => '今日は $count 件あります';
  @override String get notifGoalTitle => '学期がもうすぐ終わります';
  @override String notifGoalBody(String semester, int count) =>
      '$semester に未完了の目標が $count 件あります';
}
