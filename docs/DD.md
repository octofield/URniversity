# 資料字典（Data Dictionary, DD）

本文件列出 **URniversity** 所有持久化資料儲存（Supabase 資料表、裝置本機 SharedPreferences）
的欄位定義，是 [DFD.md](./DFD.md) 中每個資料儲存代號（D1～D11）的詳細展開。

> **維護規則**：修改資料模型（`src/lib/models/*.dart`）、Supabase 欄位，或 SharedPreferences
> key 時，都必須同步更新本文件與 `DFD.md`。詳見專案根目錄 `CLAUDE.md`。

## 使用說明

- 「型別」欄位以 PostgreSQL 型別描述雲端資料表欄位；SharedPreferences 只有字串／布林／
  JSON 字串三種型式，另行標註。
- 「對應 Dart 型別」指 `src/lib/models/` 中負責序列化／反序列化該筆資料的類別與欄位。
- 所有 Supabase 資料表都以 `user_id`（對應 `auth.users.id`）區分使用者資料，並在應用層
  （Provider 的 `_upsert()` / `load()`）加上 `.eq('user_id', userId)` 過濾，**未在資料庫層看到
  Row Level Security 設定的原始碼**，新增資料表時請確認後端已設定對應的 RLS 規則。
- id 欄位在本專案一律由前端產生（多為 `DateTime.now().millisecondsSinceEpoch.toString()`），
  不是資料庫自動遞增或 UUID。

---

## D1. `tasks`（任務）

對應 Dart 型別：`Task`（`src/lib/models/task.dart`）
讀寫處理程序：`TasksNotifier`（`src/lib/providers/tasks_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 前端產生的時間戳記字串 |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 在寫入時附加，不在 `Task.toJson()` 內 |
| `title` | text | ✓ | — | 任務標題 |
| `content` | text | ✗ | `null` | 備註內容 |
| `due_time` | timestamptz | ✗ | `null` | 截止時間；非循環任務靠此欄位判斷「屬於哪一天」 |
| `priority` | int | ✓ | `1` | 1=低、2=中、3=高 |
| `is_completed` | bool | ✓ | `false` | **僅供非循環任務使用**；循環任務的完成狀態改看 `completed_dates` |
| `created_at` | timestamptz | ✓ | — | 建立時間；循環任務用來計算「哪些日期符合循環規則」的起算點 |
| `recurrence_type` | text | ✗ | `null` | 列舉：`daily` / `weekly` / `monthly` / `everyNDays`；`null` 代表不循環 |
| `recurrence_interval` | int | ✗ | `null` | 僅 `recurrence_type = everyNDays` 時有意義，代表間隔天數 |
| `linked_target_id` | text（邏輯 FK → `semester_goals.id`） | ✗ | `null` | 連結的學期目標 |
| `linked_goal_id` | text（邏輯 FK → `future_goals.id`） | ✗ | `null` | 連結的未來願景 |
| `completed_dates` | text（JSON 字串，`List<String>`） | ✗ | `null` | 僅循環任務使用；陣列內為 `"yyyy-MM-dd"` 字串，記錄哪些日期已完成 |

**特別說明：**
- 「一個任務屬於哪一天」的判斷邏輯集中在 `src/lib/providers/tasks_provider.dart` 的
  `_taskAppliesTo()`（私有函式）。若需要新的「依日期查詢任務完成狀況」的功能，請優先呼叫
  同檔案中已公開的 `taskCompletionStatsOn()`，不要重新複寫一份判斷邏輯。
- `is_completed` 與 `completed_dates` 是互斥的兩套完成狀態記錄，讀取完成狀態一律呼叫
  `Task.isCompletedOn(date)`，不要直接讀 `is_completed`。

---

## D2. `semester_goals`（學期目標／Target）

對應 Dart 型別：`SemesterGoal`（`src/lib/models/semester_goal.dart`）
讀寫處理程序：`SemesterGoalsNotifier`（`src/lib/providers/semester_goals_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 前端產生的時間戳記字串 |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 附加 |
| `parent_id` | text（自我參照 FK → 本表 `id`） | ✗ | `null` | 子目標的父節點；`null` 代表頂層目標 |
| `title` | text | ✓ | — | 目標標題 |
| `semester` | text | ✓ | — | 學期字串，格式 `"{民國年}-{學期序}"`，例如 `"114-1"`；產生規則見 `semester_goals_provider.dart` 的 `currentSemester()` |
| `category` | text（**JSON 字串**，內容是 `List<String>`） | ✓ | `'["other"]'` | ⚠️ **欄位名為單數，實際存的是分類「陣列」的 JSON 字串**（用 `jsonEncode`/`jsonDecode` 手動轉換），與 D3 `future_goals.categories` 的存法不同，修改時請特別留意，勿混用 |
| `future_goal_id` | text（邏輯 FK → `future_goals.id`） | ✗ | `null` | 連結的未來願景（跨層關聯，也是關聯圖頁面畫虛線箭頭的資料來源） |
| `notes` | text | ✗ | `null` | 備註 |
| `is_done` | bool | ✓ | `false` | 是否完成 |
| `sort_order` | int | ✓ | `0` | 同層（同 `parent_id` 且同 `semester`）手動排序用；新增時取同層最大值 `+1000` |

**特別說明：**
- 子目標樹狀結構透過 `parent_id` 自我參照；刪除父節點（`remove()`）會遞迴刪除所有子孫，
  刪除前會先呼叫 `trash_provider.addSemesterGoal()` 做軟刪除備份。
- 搬移節點（`reparent()`）前會用 `isAncestor()` 檢查目標父節點是否為自己的子孫，避免產生循環。

---

## D3. `future_goals`（未來願景／Goal）

對應 Dart 型別：`FutureGoal`（`src/lib/models/future_goal.dart`）
讀寫處理程序：`FutureGoalsNotifier`（`src/lib/providers/future_goals_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 前端產生的時間戳記字串 |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 附加 |
| `parent_id` | text（自我參照 FK → 本表 `id`） | ✗ | `null` | 子願景的父節點；`null` 代表頂層願景 |
| `title` | text | ✓ | — | 願景標題 |
| `categories` | text[]（**Postgres 陣列，非 JSON 字串**） | ✓ | `['other']` | ⚠️ 與 D2 `semester_goals.category` 的存法不同（那邊是 JSON 字串），這裡是原生陣列，由 Supabase client 直接序列化 |
| `start_semester` | text | ✗ | `null` | 起始學期，格式同 D2 的 `semester`（`"YYY-N"`） |
| `end_semester` | text | ✗ | `null` | 結束學期，格式同上 |
| `notes` | text | ✗ | `null` | 備註 |
| `is_done` | bool | ✓ | `false` | 是否完成 |
| `sort_order` | int | ✓ | `0` | 同層（同 `parent_id`）手動排序用；新增時取同層最大值 `+1000` |

**特別說明：**
- 分類常數定義於 `FutureCategories`（同檔案）：`exchange` / `intern` / `competition` /
  `certification` / `performance` / `other` 為內建分類，使用者可另外自訂（見 D7）。
- 子願景樹狀結構、刪除遞迴、`reparent()` 循環檢查邏輯與 D2 相同模式，各自獨立實作（兩份程式碼
  結構相同但不是共用函式，修改其中一邊的行為時記得同步檢查另一邊是否也要改）。

---

## D4. `inspirations`（靈感）

對應 Dart 型別：`Inspiration`（`src/lib/models/inspiration.dart`）
讀寫處理程序：`InspirationsNotifier`（`src/lib/providers/inspirations_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 前端產生的時間戳記字串 |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 附加 |
| `title` | text | ✓ | — | 靈感標題 |
| `content` | text | ✗ | `null` | 詳細內容 |
| `is_completed` | bool | ✓ | `false` | 是否已被實現／處理 |
| `created_at` | timestamptz | ✓ | — | 建立時間；讀取時依此欄位新到舊排序 |

---

## D5. `journals`（日記）

對應 Dart 型別：`Journal`（`src/lib/models/journal.dart`）
讀寫處理程序：`JournalNotifier`（`src/lib/providers/journal_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 一般手動新增：時間戳記字串；自動補齊：`"auto_{yyyyMMdd}"` |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 附加 |
| `date` | text | ✓ | — | 日期，格式 `"yyyy-MM-dd"`（僅日期，無時間） |
| `content` | text | ✗ | `null` | 日記內容；自動補齊的條目固定內容為 `"好像忘記什麼了……"` |
| `created_at` | timestamptz | ✓ | — | 建立時間 |

**特別說明：**
- `_fillMissingDays()` 會在每次載入後，自動為「最早日記日期」到「今天」之間空缺的每一天
  補一筆 `id` 以 `auto_` 開頭的日記並寫回資料庫。判斷「這篇日記是否為自動產生」請一律檢查
  `id.startsWith('auto_')`，不要用 `content` 內容字串比對（`mergeToUser()` 已採用此判斷方式）。
- 訪客資料合併登入帳號時（`mergeToUser`），只搬移非 `auto_` 開頭的日記，登入後會依新資料重新
  跑一次 `_fillMissingDays()` 補齊。

---

## D6. `trash_items`（回收桶）

對應 Dart 型別：`TrashItem`（`src/lib/models/trash_item.dart`）
讀寫處理程序：`TrashNotifier`（`src/lib/providers/trash_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 格式 `"trash_{原始id}_{刪除時的毫秒時間戳}"` |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 附加 |
| `deleted_at` | timestamptz | ✓ | — | 刪除時間 |
| `item_type` | text | ✓ | — | 列舉：`task` / `semester_goal` / `future_goal` |
| `item_data` | jsonb | ✓ | — | 被刪除項目當下的完整快照，內容為對應 Model 的 `toJson()` 結果 |

**特別說明：**
- 只有登入使用者才有回收桶持久化；**訪客模式沒有 `guest_trash` 這個本機 key**，訪客刪除的
  項目只存在記憶體中，重新整理頁面即消失、無法還原。
- 還原（`pop()`）時依 `item_type` 呼叫對應 Provider 的 `restore()`，若原本的 `parent_id` 已不存在
  （父節點也被刪除或找不到），會自動改為頂層節點（`parent_id = null`），避免還原出斷鏈的孤兒節點。

---

## D7. `user_categories`（使用者自訂分類）

讀寫處理程序：`CategoriesNotifier`（`src/lib/providers/categories_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `user_id` | text (PK, FK → auth.users.id) | ✓ | — | 一個使用者一列（`onConflict: 'user_id'`） |
| `ordered_list` | text[] | ✓ | 內建分類清單 `FutureCategories.builtIns` | 使用者可見的分類 id 陣列，含內建與自訂分類，陣列順序即畫面顯示順序 |

**特別說明：**
- 內建分類（`exchange` / `intern` / `competition` / `certification` / `performance` / `other`）
  無法被使用者刪除（`isBuiltIn()` 擋掉），但可以被拖曳排序。
- **訪客模式沒有本機持久化**：`reset()` 會讓分類清單還原成僅剩內建分類，訪客新增的自訂分類
  只存在記憶體中。

---

## D8. `user_settings`（個人資料 + App 設定，共用一張表）

這張表由兩個處理程序共用，各自負責不同欄位：

### 8-A 個人資料欄位（`profile_provider.dart` 負責）

對應 Dart 型別：`UserProfile`（`src/lib/models/user_profile.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `user_id` | text (PK, FK → auth.users.id) | ✓ | — | 一個使用者一列 |
| `username` | text | ✗ | `null` | 暱稱；Google 登入使用者若未設定，`sync_provider` 會自動帶入 Google 帳號名稱（僅限第一次、且 `username` 為空時） |
| `school` | text | ✗ | `null` | 學校名稱，來源見 `universities_provider`（唯讀靜態資料，非本表） |
| `department` | text | ✗ | `null` | 系所名稱 |
| `grade` | int | ✗ | `null` | 設定當下的年級（1～7） |
| `grade_set_year` | int | ✗ | `null` | 設定 `grade` 當下的學年度（民國年），用來讓年級隨學年自動推進，見 `settings_provider.dart` 的 `computedGrade()` |
| `avatar_index` | int | ✗ | `null` | 內建頭像索引（對應 `AppAvatars.presets`）；`null` 代表改用 Google 大頭貼或姓名縮寫 |

### 8-B App 設定欄位（`sync_provider.dart` 負責讀寫，`settings_provider.dart` 負責記憶體狀態）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `language` | text | ✗ | `zh_tw` | 列舉：`zh_tw` / `en` / `jp` |
| `date_format` | text | ✗ | `mmddWeekday` | 列舉：`mmddWeekday` / `mmdd` / `yyyymmdd` / `longDate` |
| `semester_count` | int | ✗ | `2` | 每學年分幾學期（2／3／4） |
| `semester_start_months` | int[] | ✗ | `[8, 2]` | 各學期起始月份，陣列長度需等於 `semester_count` |
| `default_task_view` | int | ✗ | `0` | 任務頁預設檢視：0=全部、1=每日、2=每週 |
| `show_day_counter` | bool | ✗ | `true` | 日記是否顯示「第 N 天」徽章 |

**特別說明：**
- 兩個處理程序各自只夾帶自己負責的欄位做 `upsert`，不會整列覆寫，因此可以放心獨立修改，但新增
  欄位時務必同時更新 8-A 或 8-B 對應的 `toRow()` / `_saveSettings()`，並在此同步補上欄位說明。
- **App 設定（8-B）在訪客模式下完全不持久化**（`_saveSettings()` 開頭直接 `return`），只有
  個人資料（8-A）在訪客模式下會寫入本機 `guest_profile`（見 D10）。

---

## D9. `feedbacks`（匿名意見回饋）

讀寫處理程序：`_FeedbackDialogState._submit()`（`src/lib/screens/settings_screen.dart`，設定頁「意見回饋」）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `type` | text | ✓ | — | 列舉：`bug`（回報問題）／`suggestion`（建議） |
| `message` | text | ✓ | — | 內容，前端限制 10～1000 字（少於 10 字禁止送出，超過 1000 字被截斷） |

**特別說明：**
- 這張表**完全匿名**：無論登入或訪客模式，都**不會**附加 `user_id`，也沒有對應的 Dart Model
  （直接組 `Map` 呼叫 `.insert()`），沒有讀取／編輯／刪除功能，是唯一「只寫不讀」的資料流。
- 送出間隔冷卻（5 分鐘）以 `_lastSubmitTime` 這個 **static 記憶體變數**（非資料庫、非
  SharedPreferences）記錄，App 重新啟動即重置，不算持久化資料，故未另編資料儲存代號。

## D10. `auth.users`（Supabase 內建驗證表）

由 Supabase Auth 完全代管，本專案不新增自訂欄位，只透過 `Supabase.instance.client.auth`
呼叫登入／登出／取得目前使用者（`currentUserProvider`）。支援登入方式：

- 訪客模式（不建立帳號，見 D11）
- Email + 密碼
- Google OAuth（`user.userMetadata['full_name']` / `['avatar_url']` 會被用來預填暱稱與頭像）

---

## D11. 裝置本機儲存 — `guest_*` 系列 key（訪客模式資料鏡像）

媒介：SharedPreferences，每個 key 存一段 **JSON 字串**。

| Key | 內容 | 對應 Dart 型別 | 對應雲端資料表（登入後行為相同的表） |
|---|---|---|---|
| `guest_tasks` | `List<Task>` 的 JSON | `Task` | D1 `tasks` |
| `guest_sem_goals` | `List<SemesterGoal>` 的 JSON | `SemesterGoal` | D2 `semester_goals` |
| `guest_future_goals` | `List<FutureGoal>` 的 JSON | `FutureGoal` | D3 `future_goals` |
| `guest_inspirations` | `List<Inspiration>` 的 JSON | `Inspiration` | D4 `inspirations` |
| `guest_journals` | `List<Journal>` 的 JSON | `Journal` | D5 `journals` |
| `guest_profile` | 單一 `UserProfile.toRow('guest')` 的 JSON | `UserProfile` | D8-A（僅個人資料部分） |

**特別說明：**
- 這六把 key 的清單同時定義在 `guest_provider.dart` 的 `_dataKeys`（登出訪客模式時會逐一清除）
  與各自 Provider 檔案中的 `_localKey` 常數，**新增/刪除訪客可用的資料類型時，兩處都要修改**。
- **沒有** `guest_trash`、`guest_categories`、`guest_settings` 這幾把 key——回收桶、自訂分類、
  App 設定在訪客模式下都只存在記憶體，不會寫入本機儲存（呼應 D6／D7／D8-B 的特別說明）。

## D12. 裝置本機儲存 — `is_guest_mode`

媒介：SharedPreferences，`bool` 值。

| Key | 型別 | 說明 |
|---|---|---|
| `is_guest_mode` | bool | 是否目前處於訪客模式；App 啟動時由 `preloadGuestMode()` 搶先讀取，避免登入畫面閃爍 |

---

## 列舉值與特殊格式總表

| 名稱 | 定義位置 | 可能值 |
|---|---|---|
| `RecurrenceType` | `src/lib/models/task.dart` | `none` / `daily` / `weekly` / `monthly` / `everyNDays` |
| `TrashItemType`（儲存為字串） | `src/lib/models/trash_item.dart` | `task` / `semester_goal` / `future_goal` |
| `FutureCategories`（內建分類） | `src/lib/models/future_goal.dart` | `exchange` / `intern` / `competition` / `certification` / `performance` / `other` |
| `DateDisplayFormat`（儲存為字串） | `src/lib/providers/settings_provider.dart` | `mmddWeekday` / `mmdd` / `yyyymmdd` / `longDate` |
| `AppLanguage`（儲存為字串） | `src/lib/providers/settings_provider.dart` | `zh_tw` / `en` / `jp` |
| 學期字串格式 | `semester_goals_provider.dart` / `future_goal.dart` | `"{民國年}-{學期序}"`，例如 `"114-1"`；比較大小請用 `compareSemesters()`，不要用字串或數字直接比較 |
| 日期字串格式（`Task.completedDates` / `Journal.date`） | 各自 Model | `"yyyy-MM-dd"`（月、日補零至 2 位） |

---

## 已知現況／技術債備註

- `src/lib/providers/custom_categories_provider.dart` 中的 `customCategoriesProvider` 目前
  沒有被任何畫面使用，是與 D7 `user_categories` 無關的死碼，維護時請勿誤以為它是分類系統的
  一部分。
- D2 `semester_goals.category`（單數欄名、JSON 字串陣列）與 D3 `future_goals.categories`
  （複數欄名、原生陣列）的存法不一致，是既有設計，非本次文件撰寫產生的錯誤——修改任一邊的
  序列化邏輯前，請先確認不會影響另一邊。
