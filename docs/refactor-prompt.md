# 程式碼品質改進 Prompt（分五階段）

> 對象：URniversity（Flutter + Riverpod + Supabase），程式碼在 `src/lib/`
> （63 個 Dart 檔、15,264 行，統計基準 2026-08-22）。
>
> 這份文件**自帶調查依據**——下面「現況調查」一節的每個數字都經過實測。
> 執行時可直接把整份丟給 AI，或只丟其中一個階段。

---

## 現況調查（2026-08-22 實測）

### 需要做的

| 項目 | 實測結果 |
|---|---|
| **刪除確認對話框重複** | 逐字相同的 `_confirmDelete` 出現在 **8 個檔**：`future_goal_detail_screen.dart:507`、`future_screen.dart:26`、`inspirations_screen.dart:125`、`journals_screen.dart:126`、`me_screen.dart:1140`、`semester_goal_detail_screen.dart:608`、`semester_screen.dart:879`、`today_screen.dart:1579` |
| **新增／編輯表單成對重複** | `today_screen.dart` 的 `showAddTaskSheet`(1964–2130) 與 `_showEditTaskSheet`(2131–2317) 近乎逐行相同；`future_screen.dart` 967 vs 1093；`semester_goal_detail_screen.dart` 767 vs 880。**約 350 行 × 3 組** |
| **Provider 樣板重複** | `future_goals`、`inspirations`、`journal`、`profile`、`semester_goals`、`tasks` 六支各自重複 `_userId` / `_db` / `_localKey` / `_isGuest` / `load` / `loadGuest` / `_persistLocally` / `clear` / `mergeToUser` / `_upsert` / `_delete`。**約 60 行 × 6** |
| **`showModalBottomSheet` 未收斂** | 10 個呼叫點，只有 6 個用了既有的 `widgets/sheet_body.dart` |
| **顯示名稱推導重複** | `isGuest ? '訪客' : (googleName ?? user?.email ?? '')` 出現在 `journal_edit_screen.dart:86`、`me_screen.dart:175 / 744 / 852` |
| **排版寫法三套並存** | `core/theme/app_text_styles.dart`（79 行、9 個樣式）**全專案零引用**；107 處 `Theme.of(context).textTheme.*`；59 處 inline `TextStyle(`（含 23 處裸 `fontSize:`） |
| **硬編 UI 中文字串** | 約 90 處。`me_screen`(24)、`settings_screen`(14)、`today_screen`(11)、`register_screen`(11)、`login_screen`(10)、`setup_profile_screen`(5)、`trash_screen`(3)… |
| **未套用響應式的畫面** | 9 個已套用，**8 個沒有**：`register`、`setup_profile`、`category_settings`、`journal_edit`、`journals`、`task_history`、`trash`、`inspirations` |
| **靜默吞掉錯誤** | 17 處 `catchError((_) {})` + 11 處 `catch (_) {}`，集中在 provider 層。Supabase 寫入失敗時 UI 顯示成功、雲端沒存到 |
| **失去型別檢查** | **17 處 `dynamic` 宣告分佈在 8 個檔**（階段 1 加上 `avoid_dynamic_calls` 後才抓到，肉眼只找得到其中 2 處）：`settings_screen`(8)、`me_screen`(3)、`future_goal_detail_screen`(1)、`future_screen`(1)、`inspirations_screen`(1)、`semester_goal_detail_screen`(1)、`trash_screen`(1)。連帶產生 48 個 `avoid_dynamic_calls` 告警 |
| **lint 形同虛設** | `src/analysis_options.yaml` 只 include `flutter_lints` 預設，`rules:` 底下全是註解 |
| **死碼** | `app_text_styles.dart` 整檔；`l10n/strings.dart` 只剩一行過期註解；4 個未使用 l10n key（`clearTime`、`editUsername`、`addCategory`、`goalDetail`） |
| **不該進版控的檔** | `src/android/.kotlin/errors/*.log` 未被 gitignore；`src/.flutter-plugins-dependencies` 已列在 `src/.gitignore` 卻仍被追蹤 |

### 判定為「不用做」的

| 項目 | 為什麼不做 |
|---|---|
| **顏色抽離** | 已經很好——404 處走 `AppColors`，裸色只剩 `Colors.white`(12)、`Colors.grey`(2)、`Colors.transparent`(21)。後者語意正確，本來就該是裸的 |
| **「所有」間距／字級數值抽離** | 59 處裸 `EdgeInsets`、72 處裸 `SizedBox` 數字，其中大多是一次性的視覺微調（`SizedBox(height: 2)`、`Icon(size: 15)`）。把只用一次的東西抽成常數只是多一層 indirection，直接違反 CLAUDE.md §2「No abstractions for single-use code」。**只抽重複 ≥ 3 次且有語意的** |
| **`core/taiwan_universities.dart` 的 141 個中文字串** | 那是學校／系所**資料**不是 UI 文案，翻譯也不會變 |
| **未使用的 widget／provider／model** | 查過了，沒有。`HoverLift`、`EmptyState`、`drag_reorder.dart`、`sheet_body.dart` 都有實際引用 |

### 不在本文件範圍（已知問題，建議另開）

1. `TrashNotifier.clear()` 只重設記憶體並把 `_userId` 設為 null，導致該 session 後續所有刪除
   靜默失敗，重載後資料會回來——這是 bug 不是品質問題
2. 目標／願景刪除只把根節點寫進回收桶，子孫永久遺失（任務那側已修）
3. `core/config.dart` 把 Supabase anon key 硬編成 `defaultValue`（雖是 publishable key，
   仍建議一律走 `--dart-define`）
4. `today_screen.dart` 2448 行，已到該拆檔的規模
5. `pubspec.yaml` 的 `description` 仍是 `"A new Flutter project."`

---

## 全域規則（每階段都適用）

1. **不准跑 `dart format`**。排版一律手改，只動你自己新增／修改的行。
   （先前誤跑造成三個畫面檔約 1000 行純排版噪音，已裁示保留現狀不再更動。）
2. **不要順手改隔壁的程式碼**（CLAUDE.md §3 Surgical Changes）。
   每一行改動都要能追溯到本階段目標。
3. **不要為只用一次的東西建抽象**（CLAUDE.md §2）。重複 < 3 次就不要抽常數、不要開 helper。
4. 註解一律英文、首字大寫、句尾不加句號；K&R 大括號；`lowerCamelCase`。
5. 改到持久化欄位或資料流 → 同步更新 `docs/DD.md`、`docs/DFD.md`。
   改到導覽、輸入輸出格式或演算法 → 同步更新 `docs/system_design.md`（含重畫 Mermaid 圖）。
6. **每階段結束都必須通過驗收才進下一階段**，每階段自成一個 commit。
   收尾執行 `cd src && flutter analyze && flutter test`，並在回報中貼出實際輸出。
   基準線：**40 個測試全綠、僅 2 個既有的 `onReorder` deprecation info**。

> ⚠️ **執行前**：如果 `flutter analyze` 失敗在
> `Building with plugins requires symlink support`，那是 `PUB_CACHE` 環境變數殘留成空字串。
> 完整重啟 VS Code，或改用外部 PowerShell 視窗跑 flutter 指令。

---

## 階段 1：清理死碼 + 收緊 lint

**目標**：先把工具準備好，讓後面四個階段的問題能被自動抓出來，而不是靠肉眼。

1. 刪除 `src/lib/core/theme/app_text_styles.dart`。
   （79 行、9 個樣式，`grep -rn "AppTextStyles" src/lib` 只會命中它自己。）
2. 刪除 `src/lib/l10n/strings.dart`（只剩一行「已被 l10n 系統取代」的註解）。
3. 移除 4 個未使用的 l10n key，**四個檔案都要動**
   （`app_strings.dart` 宣告 + `strings_zh_tw` / `strings_en` / `strings_jp` 三份實作）：
   `clearTime`、`editUsername`、`addCategory`、`goalDetail`。
4. 版控雜訊：
   - 根目錄 `.gitignore` 加入 `.kotlin/`
   - 執行 `git rm --cached src/.flutter-plugins-dependencies`
     （該檔已列在 `src/.gitignore` 卻仍被追蹤，每次建置只產生 `date_created` 時間戳噪音）
5. `src/analysis_options.yaml` 的 `linter.rules:` 加入：
   ```yaml
   rules:
     avoid_dynamic_calls: true
     prefer_const_constructors: true
     prefer_const_literals_to_create_immutables: true
     unnecessary_parenthesis: true
     unawaited_futures: true
     require_trailing_commas: false   # Conflicts with existing formatting, off on purpose
   ```
6. 跑 `flutter analyze`，把新規則報出的問題**分類列出**（**不要現在修**）。
   若 `avoid_dynamic_calls` 或 `unawaited_futures` 噴出超過 50 個，回報數量並先降為 warning，
   留到階段 3、4 處理。

**驗收**
- `flutter test` 40/40
- 新規則報出的問題已分類列出，且**尚未動手修**
- `grep -rn "AppTextStyles\|clearTime\|editUsername\|addCategory\|goalDetail" src/lib` 無結果

---

## 階段 2：把硬編 UI 字串抽進 l10n

**目標**：切換語言時不再看到寫死的中文。

**範圍**（約 90 處）：
`screens/auth/login_screen.dart`(10)、`screens/auth/register_screen.dart`(11)、
`screens/me_screen.dart`(24)、`screens/settings_screen.dart`(14)、
`screens/today_screen.dart`(11)、`screens/setup_profile_screen.dart`(5)、
`screens/trash_screen.dart`(3)、`screens/task_history_screen.dart`(3)、
`providers/settings_provider.dart`(2)、`providers/journal_provider.dart`(1)

**明確排除**
- `core/taiwan_universities.dart` 的 141 個字串——那是資料不是文案
- `providers/journal_provider.dart` 的 `_kForgotToWrite`——它被寫進 Supabase 的 `journals.content`
  欄位，是**持久化資料**不是 UI 標籤。在地化會讓舊列維持中文、新列變英文
- 純符號佔位字元 `'—'`、`'→'`、`'⭐'`、`'·'`、`'–'`——不需要翻譯，但因為出現超過 10 次，
  **要抽成具名常數**（例如 `kEmptyValue = '—'`）

**作法**
1. 逐檔掃出中文字面量，在 `l10n/app_strings.dart` 加對應 getter／method，
   命名沿用既有慣例（畫面前綴 + 語意，如 `authEmailLabel`、`accountDeleteConfirm`）。
2. 三個實作檔 `strings_zh_tw.dart` / `strings_en.dart` / `strings_jp.dart` **同步加**，
   數量必須完全一致。
3. `providers/settings_provider.dart` 的 `formatDate()` 藏了**兩個**硬編陣列：中文星期
   `['一'...'日']` 與英文月份 `['January'...]`。兩者都不隨語言變，所以英文模式會顯示中文星期。
   `AppStrings.weekdayShort(int)` 已存在且 zh_tw 版與那份陣列**完全相同**，可直接改用。
   `formatDate` 需要新增 `AppStrings s` 參數（5 個呼叫點，全都拿得到 `s`）。
   ⚠️ 月份在地化會改變**中文模式**現有顯示（`August 22` → `8月22日`），動手前先確認。

4. `me_screen.dart:151` 的 `['一','二',...,'七']` **不是**星期陣列，是 `_gradeLabel`
   （年級數字轉中文）。改成 `AppStrings.gradeLabel(int)`：中文維持一～七，英日用阿拉伯數字。

5. 全形標點在英文模式會露餡：`'${s.delete}？'`（8 處）顯示成 `Delete？`、
   `'${s.createdAtLabel}：...'` 顯示成 `Created：`、task_history 的 `（50%）`。
   這些**不能在呼叫端組字**，標點本身就要隨語言變，必須整句進 l10n。

**驗收**
- 三語 override 數量相同：`grep -c "@override" src/lib/l10n/strings_*.dart` 三者一致
- `grep -rn "'[^']*[一-龥][^']*'" src/lib/screens src/lib/widgets src/lib/providers`
  只剩符號常數與註解
- 實機切到 English／日本語，走過**登入、註冊、設定、個人資料、回收桶**五個畫面，全無中文殘留
- `flutter test` 40/40

---

## 階段 3：模板化（UI 元件 + Provider 基底）

**目標**：消掉最大宗的重複，同時順手讓靜默失敗變得看得見。

本階段動到 guest 持久化路徑，是五個階段裡風險最高的，**子項目請照順序做**。

### 3-1 刪除確認對話框（8 處 → 1 處）

在 `src/lib/widgets/` 新增 `confirm_dialog.dart`：

```dart
/// Shows the shared destructive-action confirmation. Returns false when dismissed
Future<bool> confirmDelete(BuildContext context, AppStrings s, {String? message}) async { ... }
```

替換前述 8 處。其中 `inspirations_screen.dart:125` 與 `me_screen.dart:1140` 目前參數型別是
`dynamic s`，**必須改成 `AppStrings s`**。

順帶把另外 15 處 `dynamic` 宣告一併改成正確型別，讓階段 1 加的 `avoid_dynamic_calls`
從 48 個告警歸零：

| 檔案 | 行 | 應有型別 |
|---|---|---|
| `settings_screen.dart` | 265、275、284、308、332、358、366、562 | `AppStrings` |
| `me_screen.dart` | 282（`profile`）、284（`s`）、286（`semSettings`） | `UserProfile?` / `AppStrings` / `SemesterSettings` |
| `future_goal_detail_screen.dart` | 481 | `AppStrings` |
| `future_screen.dart` | 928 | `AppStrings` |
| `semester_goal_detail_screen.dart` | 443 | `AppStrings` |
| `trash_screen.dart` | 50 | `AppStrings` |

### 3-2 收斂 `showModalBottomSheet`

10 個呼叫點中這 4 個沒用 `widgets/sheet_body.dart` 的 `SheetBody`：
`inspirations_screen.dart:148`、`me_screen.dart:557`、`me_screen.dart:1041`、
`today_screen.dart:2352`。

把 `backgroundColor: Colors.transparent` + `isScrollControlled` + padding 這組樣板收進一個
`showAppSheet(...)` helper，10 處全數改用。

### 3-3 顯示名稱推導（4 處 → 1 處）

`isGuest ? '訪客' : (googleName ?? user?.email ?? '')` 在 `journal_edit_screen.dart:86`、
`me_screen.dart:175 / 744 / 852` 重複。抽成單一 provider 或 `utils/` 函式
（訪客字串走階段 2 加的 l10n key）。

### 3-4 Provider 基底類別

六支 provider 各自重複約 60 行。抽成泛型基底：

```dart
abstract class SyncedListNotifier<T> extends StateNotifier<List<T>> {
  SyncedListNotifier({required this.table, required this.localKey}) : super([]);
  // Shared: _userId, _db, _isGuest, load, loadGuest, _persistLocally, clear,
  // mergeToUser, upsert, deleteRow
}
```

⚠️ **六支的差異點**（動手前先逐一確認，不要假設它們完全一樣）：
- `load()` 的 `.order()` 欄位不同：`inspirations` 用 `created_at` descending，
  `future_goals` 用 `sort_order`
- `tasks` 與 `semester_goals` 有樹狀結構的額外方法（`getWithDescendants` 等）
- **`profile_provider` 是單筆不是列表，形狀不同——本階段不要硬塞進基底**，
  先做五支列表型的

### 3-5 讓靜默錯誤現形（與 3-4 同時做）

17 處 `catchError((_) {})` 與 11 處 `catch (_) {}` 集中在 provider 層。收進基底後只剩一處，
改為：寫入失敗時記錄錯誤並透過一個 `syncErrorProvider` 曝露，讓 UI 至少能顯示 SnackBar。

**不要改變成功路徑的行為**——這一步只是讓失敗變得看得見，不是改寫同步策略。

### 3-6 新增／編輯表單合併（風險最高，**最後做**）

三組成對重複：

| 檔案 | 新增 | 編輯 |
|---|---|---|
| `today_screen.dart` | `showAddTaskSheet` (1964–2130) | `_showEditTaskSheet` (2131–2317) |
| `future_screen.dart` | 967 | 1093 |
| `semester_goal_detail_screen.dart` | 767 | 880 |

合併成 `showTaskSheet({Task? existing, String? parentTaskId})` 這種形式：`existing == null`
就是新增。

⚠️ **動手前必須先逐項列出兩者的差異**——標題文字、送出行為、是否顯示建立時間、
是否顯示刪除鈕、循環規則的預設值、controller 的初始值來源。
**不能假設「只有標題不同」**。列完差異、確認過再合併。

⚠️ 這些表單先前修過一個坑：`showModalBottomSheet` 的 `builder` 在**任何 MediaQuery 變動時
都會重跑**（鍵盤彈出、旋轉），所以表單狀態必須 hoist 到 `builder` 外面。合併時**不要把
狀態變數移回 `builder` 裡**，那會讓「點了沒反應」「要按好幾次」的 bug 復發。

**驗收**
- `flutter test` 40/40，`flutter analyze` 無新增問題
- `grep -rn "content: Text('\${s.delete}？')" src/lib/screens` 無結果
- `grep -rn "catchError((_) {})" src/lib/providers | wc -l` ≤ 1
- 手動走查：
  - 新增／編輯任務、目標、願景各一次
  - 刪除各一次，確認對話框仍出現
  - **開著鍵盤操作表單**，確認狀態不被重設
  - **訪客模式與登入模式各測一輪**（本階段動到 guest 持久化路徑，必測）
- 依 `docs/testing.md` 建立測試計畫 `docs/test-plans/YYYY-MM-DD-refactor-templates.md`

---

## 階段 4：風格統一

**目標**：把三套排版寫法收成一套，並只抽真正重複的數值。

1. **59 處 inline `TextStyle(`（含 23 處裸 `fontSize:`）改用 `Theme.of(context).textTheme.*`**。
   對照表（依現有 107 處的使用頻率推得，**不要自創新級距**）：

   | 現有 `fontSize` | 改用 |
   |---|---|
   | 11–12 | `bodySmall` |
   | 13–15 | `bodyMedium` |
   | 16 | `titleMedium` |
   | 20 | `titleLarge` |
   | 24+ | `headlineSmall` |

   需要改粗細／顏色時用 `.copyWith(...)`，不要退回 inline `TextStyle`。

   ⚠️ 逐處目視比對字級是否真的等價。**不等價就保留 inline，並加一行英文註解說明為什麼**。

2. **裸數值只抽重複 ≥ 3 次且有語意的**。先跑統計、列出候選清單，確認後再動手。
   一次性的 `SizedBox(height: 2)`、`Icon(size: 15)` **一律保持原樣**。

3. 裸 `Colors.white`(12) / `Colors.grey`(2) 改用 `AppColors.textOnPrimary` /
   `AppColors.textTertiary`。
   `Colors.transparent`(21) **保持不動**——那是語意正確的用法，不該進 `AppColors`。

**驗收**
- `flutter test` 40/40
- `grep -rn "fontSize: [0-9]" src/lib/screens src/lib/widgets` 只剩有註解說明的例外
- 實機目視今日／學期／未來三個主要畫面，字級無視覺改變

---

## 階段 5：補齊 8 個畫面的響應式

**目標**：寬螢幕上不再有整條拉滿的畫面。

**必讀 `docs/system_design.md` §3-F**，模式與數值已經定死了，**照抄，不要自創**：

> 寬度 < 768 維持鋪滿寬度的單欄版面；≥ 768 用 `Center` + `ConstrainedBox` 限制最大寬度並置中。
> 登入類 420，其餘 640。分頁列表類（有底部導覽／側邊欄）才用 `isWide ? 1100 : 900`。

**逐檔**（全部屬於「單欄表單／列表類」）：

| 檔案 | maxWidth | 參照現有實作 |
|---|---|---|
| `screens/auth/register_screen.dart` | 420 | `auth/login_screen.dart:72-95`（與 login 成對，特別不一致） |
| `screens/setup_profile_screen.dart` | 420 | 同上 |
| `screens/category_settings_screen.dart` | 640 | `settings_screen.dart:44-70` |
| `screens/journals_screen.dart` | 640 | 同上 |
| `screens/journal_edit_screen.dart` | 640 | 同上 |
| `screens/task_history_screen.dart` | 640 | 同上。⚠️ 內部 CustomPainter 有自己的寬度計算（`task_history_screen.dart:313-324`），別破壞 |
| `screens/trash_screen.dart` | 640 | 同上 |
| `screens/inspirations_screen.dart` | 640 | 同上 |

作法一律是：抽出既有 body 成一個 `content` 變數，然後

```dart
final isDesktop = MediaQuery.of(context).size.width >= AppBreakpoints.desktop;
...
body: isDesktop
    ? Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: content,
        ),
      )
    : content,
```

**不要重複 data watch、不要另開 Widget class**——§3-F 明文要求「共用同一份資料 watch
與同一批子元件」。

**文件同步**：`docs/system_design.md` §3-F 的畫面清單目前只列了 4 個單欄畫面
（`LoginScreen`、`SettingsScreen`、`SemesterGoalDetailScreen`、`FutureGoalDetailScreen`），
要把這 8 個補進去。

**驗收**
- `flutter test` 40/40
- 桌面瀏覽器把視窗從 400px 拉到 1920px，逐一走過 8 個畫面：
  768px 前後切換正確、無溢出、無閃爍
- 手機實機走過 8 個畫面確認無回歸
- 測試計畫 `docs/test-plans/YYYY-MM-DD-responsive-batch.md`

---

## 抽查指令（驗證本文件的數字是否仍成立）

```bash
cd src/lib
grep -rn "AppTextStyles" .                                     # 只該命中 app_text_styles.dart 自己
grep -rn "content: Text('\${s.delete}？')" screens | wc -l      # 應為 8
grep -rn "catchError((_) {})" providers | wc -l                # 應為 17
grep -rn "AppBreakpoints" screens | awk -F: '{print $1}' | sort -u | wc -l   # 應為 9
grep -rno "fontSize: [0-9]\+" screens widgets | wc -l          # 應為 23
grep -rn "showModalBottomSheet" screens | wc -l                # 應為 10
grep -rn "SheetBody(" screens | wc -l                          # 應為 6
```
