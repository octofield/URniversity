# 資料字典（Data Dictionary, DD）

本文件列出 **URniversity** 所有持久化資料儲存（Supabase 資料表、裝置本機 SharedPreferences）
的欄位定義，是 [data_flow_diagram.md](./data_flow_diagram.md) 中每個資料儲存代號（D1～D11）的詳細展開。

> **維護規則**：修改資料模型（`src/lib/models/*.dart`）、Supabase 欄位，或 SharedPreferences
> key 時，都必須同步更新本文件與 `data_flow_diagram.md`。詳見專案根目錄 `CLAUDE.md`。

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

## D0. 共通慣例

- **列 id 由前端產生**：`newRowId()`（`src/lib/providers/synced_list_notifier.dart`），
  格式為 `{毫秒時間戳}_{隨機數}`。⚠️ 2026-09-05 之前只有毫秒時間戳，
  同一毫秒建立的多列會共用 id 而互相覆蓋（id 是主鍵）。舊資料的 id 維持原樣，不需遷移。
- **寫入失敗一律經 `reportSyncError()`** 顯示，不得靜默吞掉（詳見 system_design.md §3-I）。
- **文字欄位有字數上限**（2026-09 第十一批起）：App 端集中在 `src/lib/core/input_limits.dart`
  的 `InputLimits`，資料庫端以 `CHECK (char_length(col) <= N)` 強制，定義在
  `supabase/input_length_limits.sql`（需在 Supabase SQL Editor 手動執行一次）。**兩邊的數字必須一致**，
  改一邊就要改另一邊，否則資料庫會拒絕 App 放行的內容（PostgREST `23514`，經 `reportSyncError` 顯示）。
  `NULL` 會通過 CHECK，所以選填欄位仍是選填。

  | 欄位 | 上限 | 資料庫 constraint |
  |---|---|---|
  | `tasks.title`、`semester_goals.title`、`future_goals.title`、`inspirations.title` | 100 | `{table}_title_len` |
  | `tasks.content`、`semester_goals.notes`、`future_goals.notes`、`inspirations.content` | 500 | `{table}_{col}_len` |
  | `journals.content` | 5000 | `journals_content_len` |
  | `user_settings.username` | 30 | `user_settings_username_len` |
  | `user_settings.school`、`user_settings.department` | 50 | `user_settings_{col}_len` |
  | 分類名稱（D7 `ordered_list` 與 D2 `category` 內的 JSON 字串） | 20 | **無**：存在 JSON 字串裡，資料庫無法逐一檢查，只有 App 端擋 |

## D1. `tasks`（任務）

對應 Dart 型別：`Task`（`src/lib/models/task.dart`）
讀寫處理程序：`TasksNotifier`（`src/lib/providers/tasks_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 前端產生的時間戳記字串 |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 在寫入時附加，不在 `Task.toJson()` 內 |
| `title` | text | ✓ | — | 任務標題；≤ 100 字 |
| `content` | text | ✗ | `null` | 備註內容；≤ 500 字 |
| `due_time` | timestamptz | ✗ | `null` | 截止時間；非循環任務靠此欄位判斷「屬於哪一天」 |
| `priority` | int | ✓ | `1` | **保留欄位，App 已不再讀寫**。原本是 1=低、2=中、3=高，2026-09-20 移除優先度功能後新增的任務一律寫預設值 `1`；欄位留著不動 |
| `is_completed` | bool | ✓ | `false` | **僅供非循環任務使用**；循環任務的完成狀態改看 `completed_dates` |
| `created_at` | timestamptz | ✓ | — | 建立時間；循環任務用來計算「哪些日期符合循環規則」的起算點 |
| `recurrence_type` | text | ✗ | `null` | 列舉：`daily` / `weekly` / `monthly` / `everyNDays`；`null` 代表不循環 |
| `recurrence_interval` | int | ✗ | `null` | 僅 `recurrence_type = everyNDays` 時有意義，代表間隔天數 |
| `recurrence_weekdays` | int[] | ✗ | `null` | 僅 `recurrence_type = weekly` 時有意義；ISO 星期（週一=1 … 週日=7），可複選。`null`／空陣列代表沿用舊行為「與建立日同一個星期幾」 |
| `recurrence_month_days` | int[] | ✗ | `null` | 僅 `recurrence_type = monthly` 時有意義；日期 1–31，外加 **`32` 代表「該月最後一天」**（超出合法日數範圍的哨兵值，排序時自然落在最後）。`null`／空陣列代表沿用舊行為「與建立日同一個號數」 |
| `linked_target_id` | text（**真實外鍵** → `semester_goals.id` `ON DELETE SET NULL`） | ✗ | `null` | 連結的學期目標。目標被刪除時資料庫會自動清成 `null`——但只對**當下還存在**的任務列生效，回收桶裡的快照仍留著舊 id（見 §UC6 的還原處理） |
| `linked_goal_id` | text（**真實外鍵** → `future_goals.id` `ON DELETE SET NULL`） | ✗ | `null` | **保留欄位，App 已不再讀寫**。原本是「任務直接連結未來願景」，2026-09 移除該功能後只保留 `任務 → 學期目標 → 未來願景` 一條路徑；欄位與外鍵留著不動，舊資料也不清除 |
| `parent_task_id` | text（自我參照 FK → 本表 `id`） | ✗ | `null` | **保留欄位，App 已不再讀寫**。原本是子任務的父任務 id，2026-09 移除子任務功能後新增的任務一律寫 `null`；欄位留著不動 |
| `sort_order` | int | ✓ | `0` | 手動拖曳排序用；子任務移除後任務是單層清單，新增時取最小值 `−1000`（新的排最上面，可為負數） |
| `completed_dates` | text（JSON 字串，`List<String>`） | ✗ | `null` | 僅循環任務使用；陣列內為 `"yyyy-MM-dd"` 字串，記錄哪些日期已完成 |

**特別說明：**
- 這些欄位需在 Supabase 執行過一次性 migration：
  ```sql
  ALTER TABLE tasks ADD COLUMN IF NOT EXISTS sort_order int NOT NULL DEFAULT 0;
  ALTER TABLE tasks ADD COLUMN IF NOT EXISTS parent_task_id text;
  ALTER TABLE tasks ADD COLUMN IF NOT EXISTS recurrence_weekdays int[];
  ALTER TABLE tasks ADD COLUMN IF NOT EXISTS recurrence_month_days int[];
  ```
  ⚠️ `Task.toJson()` **只在 `monthDays` 非空時才輸出 `recurrence_month_days` 這個 key**。
  原因是 PostgREST 只要看到不存在的欄位就會拒絕整筆寫入——若無條件輸出，在 migration 執行前
  連「所有其他任務的儲存」都會一起失敗。這個條件輸出讓未使用該功能時完全不受影響。
- `recurrence_interval` 讀取時會被夾在 `>= 1`（`Task.fromJson`）：舊資料若存了 `0`，
  `_recurringAppliesTo()` 的 `%` 運算在手機上會拋 `IntegerDivisionByZeroException`，
  在 web（dart2js）上則得到 `NaN` 而靜默算錯。`RecurrenceRule.safeInterval` 是第二道防線。
- ⚠️ **既有資料的 `sort_order` 全部是 `0`**。排序邏輯（`filteredTasksProvider`）刻意設計成
  「`sort_order` 優先，相同時退回原本的自動分組排序」，所以在使用者第一次拖曳之前，畫面順序
  與改版前完全一致，不會因為 migration 而重排。
- ⚠️ 任務刪除**沒有回收桶快照**：`TasksNotifier.remove()` 直接硬刪該列（子任務移除後不再有連帶刪除）。
  `trash_provider.dart` 雖有 `addTask()`，但**全專案沒有任何地方呼叫它**，是未接線的死碼。
  這與 system_design.md UC6 的描述不符，屬既有落差，尚未處理。
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
| `title` | text | ✓ | — | 目標標題；≤ 100 字 |
| `semester` | text | ✓ | — | 學期字串，格式 `"{民國年}-{學期序}"`，例如 `"114-1"`；產生規則見 `semester_goals_provider.dart` 的 `currentSemester()` |
| `category` | text（**JSON 字串**，內容是 `List<String>`） | ✓ | `'[]'` | ⚠️ **欄位名為單數，實際存的是分類「陣列」的 JSON 字串**（用 `jsonEncode`/`jsonDecode` 手動轉換），與 D3 `future_goals.categories` 的存法不同，修改時請特別留意，勿混用。**空陣列＝沒有分類**（2026-09-20 起；在那之前空的會被寫成 `["other"]`）。畫面上**不畫任何顏色與圖示**；若該目標連結了有分類的願景，就顯示那個願景的顏色（見 system_design.md §3-J）。舊的單一字串值（例如 `'intern'`）仍能讀，會被當成一個元素 |
| `future_goal_id` | text（邏輯 FK → `future_goals.id`） | ✗ | `null` | 連結的未來願景（跨層關聯，也是關聯圖頁面畫虛線箭頭的資料來源）。⚠️ 這是**真實的外鍵** `semester_goals_future_goal_id_fkey → future_goals(id) ON DELETE SET NULL`（不是邏輯關聯），指向不存在的願景會被資料庫拒絕。另外 **僅頂層目標（`parent_id IS NULL`）可有值**；`linkFutureGoal()` 會擋下對子目標的連結，`reparent()` 把目標拖成子目標時會清成 `null` |
| `notes` | text | ✗ | `null` | 備註；≤ 500 字 |
| `is_done` | bool | ✓ | `false` | 是否完成 |
| `sort_order` | int | ✓ | `0` | 同層（同 `parent_id` 且同 `semester`）手動排序用；新增時取同層最小值 `−1000`（新的排最上面，可為負數） |

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
| `title` | text | ✓ | — | 願景標題；≤ 100 字 |
| `categories` | text[]（**Postgres 陣列，非 JSON 字串**） | ✓ | `['other']` | ⚠️ 與 D2 `semester_goals.category` 的存法不同（那邊是 JSON 字串），這裡是原生陣列，由 Supabase client 直接序列化 |
| `start_semester` | text | ✗ | `null` | 起始學期，格式同 D2 的 `semester`（`"YYY-N"`） |
| `end_semester` | text | ✗ | `null` | 結束學期，格式同上 |
| `notes` | text | ✗ | `null` | 備註；≤ 500 字 |
| `is_done` | bool | ✓ | `false` | 是否完成 |
| `sort_order` | int | ✓ | `0` | 同層（同 `parent_id`）手動排序用；新增時取同層最小值 `−1000`（新的排最上面，可為負數） |

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
| `title` | text | ✓ | — | 靈感標題；≤ 100 字 |
| `content` | text | ✗ | `null` | 詳細內容；≤ 500 字 |
| `is_completed` | bool | ✓ | `false` | 是否已被實現／處理 |
| `is_archived` | bool | ✓ | `false` | 是否已封存（Phase 3）；與 `is_completed` 是**獨立的兩軸**，還沒完成的點子也能封存 |
| `created_at` | timestamptz | ✓ | — | 建立時間；讀取時依此欄位新到舊排序 |

**特別說明**：

- 封存只影響顯示位置，不影響 `is_completed`。Today 頁靈感區塊、「我的」頁靈感區塊與其計數
  都只算 `!is_completed && !is_archived`；已封存的筆數只出現在 `InspirationsScreen` 的
  「已封存」區塊（預設收合）。
- 欄位以 `ADD COLUMN IF NOT EXISTS ... DEFAULT false` 加入（`supabase/inspiration_archive.sql`），
  `fromJson` 對缺欄位的舊資料退回 `false`，所以舊版 App 與新欄位可以並存。

---

## D5. `journals`（日記）

對應 Dart 型別：`Journal`（`src/lib/models/journal.dart`）
讀寫處理程序：`JournalNotifier`（`src/lib/providers/journal_provider.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `id` | text (PK) | ✓ | — | 一般手動新增：時間戳記字串；自動補齊：`"auto_{yyyyMMdd}"` |
| `user_id` | text (FK → auth.users.id) | ✓ | — | 由 Provider 附加 |
| `date` | text | ✓ | — | 日期，格式 `"yyyy-MM-dd"`（僅日期，無時間） |
| `content` | text | ✗ | `null` | 日記內容，≤ 5000 字；自動補齊的條目固定內容為 `"好像忘記什麼了……"` |
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

對應 Dart 型別：`CategoryEntry`（`src/lib/models/category.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `user_id` | text (PK, FK → auth.users.id) | ✓ | — | 一個使用者一列（`onConflict: 'user_id'`） |
| `ordered_list` | text[] | ✓ | 內建分類清單 `FutureCategories.builtIns` | 使用者可見的分類 id 陣列，含內建與自訂分類，陣列順序即畫面顯示順序 |
| `styles` | jsonb | ✗ | `null` | `{ id: { color: int(ARGB), icon: int(codePoint) } }`，每個分類（含內建）目前自訂的顯示顏色與圖示；沒有出現在這個 map 裡的 id 使用 `defaultCatColor()`/`defaultCatIcon()` 的內建預設值 |

**特別說明：**
- 這張表經過兩次 migration 才變成現在的形狀。第一次補上 `ordered_list`／`styles`：
  ```sql
  ALTER TABLE user_categories ADD COLUMN IF NOT EXISTS ordered_list text[] NOT NULL DEFAULT '{}';
  ALTER TABLE user_categories ADD COLUMN IF NOT EXISTS styles jsonb;
  ```
  ⚠️ **這次 migration 並沒有真的修好寫入**——當時本文件寫著「這個狀況已排除」，但那是
  未經驗證的宣稱：`_persist()` 的 `.catchError((_) {})` 讓失敗完全看不見，沒有任何辦法確認。
  2026-08-24 把靜默 catch 改成會顯示的錯誤之後才發現，**這張表當時是 0 列，從來沒有成功
  寫入過一次**。真正的原因是「一個分類一列」舊設計留下的兩個欄位：
  - `name` 是 `NOT NULL` 且無預設值 → INSERT 必然違反約束
  - 主鍵是複合鍵 `(user_id, name)`，`user_id` 單獨沒有唯一索引 →
    程式碼的 `onConflict: 'user_id'` 在 Postgres 端無效（42P10）

  第二次 migration 清掉這兩個死欄位並改用單欄主鍵，形狀才與程式碼一致：
  ```sql
  ALTER TABLE user_categories DROP CONSTRAINT user_categories_pkey;
  ALTER TABLE user_categories DROP COLUMN name;
  ALTER TABLE user_categories DROP COLUMN order_index;
  ALTER TABLE user_categories ADD CONSTRAINT user_categories_pkey PRIMARY KEY (user_id);
  ```
- **教訓**：靜默 catch 讓一個壞了不知道多久的寫入路徑，在文件裡被記載成「已修好」。
  現在寫入失敗一律經由 `reportSyncError()` 顯示（見 D0）。
- 圖示只會是 `src/lib/utils/category_helpers.dart` 裡 `categoryIconPresets`（固定常數清單）中的
  其中一個，而不是任意 `IconData`——因為這些 codepoint 也會被寫在挑選圖示的網格 UI 裡當成
  literal `Icons.xxx`，Flutter 的圖示 tree-shaking 才不會把使用者選到的字型砍掉。
- 內建分類（`exchange` / `intern` / `competition` / `certification` / `performance` / `other`）
  無法被使用者刪除（`isBuiltIn()` 擋掉），但可以被拖曳排序、改色、改圖示。
  改色時可挑 `categoryColorPresets` 的 **24 個預設色**（依色系排列，前六個是內建分類原本的顏色，順序固定所以既有分類不會因為清單擴充而變色），也可以直接輸入 HEX。
- **訪客模式沒有本機持久化**：`reset()` 會讓分類清單還原成僅剩內建分類（含其預設顏色/圖示），
  訪客新增或自訂的內容只存在記憶體中。

---

## D8. `user_settings`（個人資料 + App 設定，共用一張表）

這張表由兩個處理程序共用，各自負責不同欄位：

### 8-A 個人資料欄位（`profile_provider.dart` 負責）

對應 Dart 型別：`UserProfile`（`src/lib/models/user_profile.dart`）

| 欄位 | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `user_id` | text (PK, FK → auth.users.id) | ✓ | — | 一個使用者一列 |
| `username` | text | ✗ | `null` | 暱稱，≤ 30 字；Google 登入使用者若未設定，`sync_provider` 會自動帶入 Google 帳號名稱（僅限第一次、且 `username` 為空時） |
| `school` | text | ✗ | `null` | 學校名稱，≤ 50 字；來源見 `universities_provider`（唯讀靜態資料，非本表） |
| `department` | text | ✗ | `null` | 系所名稱；≤ 50 字 |
| `grade` | int | ✗ | `null` | 設定當下的年級（1～7） |
| `grade_set_year` | int | ✗ | `null` | 設定 `grade` 當下的學年度（民國年），用來讓年級隨學年自動推進，見 `settings_provider.dart` 的 `computedGrade()` |
| `avatar_index` | int | ✗ | `null` | 內建頭像索引（對應 `AppAvatars.presets`，目前 **0–23**）；`null` 代表改用 Google 大頭貼或姓名縮寫。**presets 的順序即是這個索引的意義，既有項目不得調換或刪除**，只能往後追加 |

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

## D13. 裝置本機儲存 — `notification_settings`（Phase 1 通知設定）

媒介：SharedPreferences，存一段 **JSON 字串**。
對應 Dart 型別：`NotificationSettings`（`src/lib/models/notification_settings.dart`）
讀寫處理程序：`NotificationSettingsNotifier`（`src/lib/providers/notification_provider.dart`）

| 欄位（JSON key） | 型別 | 必填 | 預設值 | 說明 |
|---|---|---|---|---|
| `enabled` | bool | ✗ | `false` | 總開關。**預設關閉**：要先向系統要到通知權限才有意義，而在使用者還沒有任何資料時就跳權限請求最容易被永久拒絕 |
| `task_due_enabled` | bool | ✗ | `true` | 任務到期提醒 |
| `task_lead_minutes` | int | ✗ | `30` | 提前幾分鐘提醒；`0` = 準時。可選值見 `NotificationConstants.taskLeadMinuteOptions` |
| `recurring_minute_of_day` | int | ✗ | `480` | **沒設截止時間的重複任務**在它落到的每一天的提醒時刻，以「當日第幾分鐘」儲存（480 = 08:00）。不套用 `task_lead_minutes`（那是「截止前多久」，這種任務沒有截止時刻）；由 `task_due_enabled` 一起控制。2026-09 第十一批新增，舊版寫入的 JSON 缺這個 key 時退回預設 |
| `daily_summary_enabled` | bool | ✗ | `true` | 每日摘要 |
| `summary_minute_of_day` | int | ✗ | `480` | 摘要時間，以「當日第幾分鐘」儲存（480 = 08:00） |
| `goal_deadline_enabled` | bool | ✗ | `true` | 學期目標截止提醒 |
| `goal_lead_days` | int | ✗ | `7` | 學期結束前幾天提醒。可選值見 `NotificationConstants.goalLeadDayOptions` |

**特別說明：**

- **為什麼放本機而不是 `user_settings`（D8-B）**：兩個理由。其一，「哪一台裝置該震動」
  本來就是**每台裝置各自的問題**，同步到雲端反而會讓手機的設定影響到網頁版。
  其二，D8-B 在**訪客模式下完全不持久化**（`_saveSettings()` 開頭直接 return），
  放那裡會讓訪客每次重開 App 都要重設一次。
- **每個欄位在 `fromJson` 都有各自的預設值**。舊版寫入的 JSON 缺少新欄位時，
  只會退回該欄位的預設，不會整組設定失效——那等於靜默關掉通知。
- 通知**不產生任何持久化資料**。排程是從 D1 `tasks` 與 D2 `semester_goals` **推導**出來的
  （`buildNotificationSchedule()`），存在作業系統的待送佇列裡，不寫回任何資料表。
  資料一變就整批重算重排，所以沒有會過期的快取。
- 這把 key **不在** `_GuestModeNotifier._dataKeys` 裡：退出訪客模式時清掉的是訪客的**資料**，
  通知偏好屬於這台裝置，不該被一起清掉。

---

## D14. 裝置本機儲存 — `notification_action_log`（通知動作的暫存結果）

媒介：SharedPreferences，存一段 **JSON 陣列字串**。
寫入處理程序（**兩個，都在背景 isolate**）：
`applyDoneAction()`（`src/lib/services/notification_background.dart`，通知的「標示為已完成」）與
`applyWidgetAction()`（`src/lib/services/home_widget_background.dart`，桌面小工具的勾選框）。
兩者都經由 `toggleTaskFromBackground()`（`src/lib/services/background_task_writer.dart`）寫入。
讀取處理程序：`drainNotificationActions()`（`src/lib/providers/notification_action_provider.dart`，主 isolate）

| 欄位（JSON key） | 型別 | 必填 | 說明 |
|---|---|---|---|
| `task_id` | string | ✓ | 被動到的任務 id |
| `error` | string | ✗ | 有這個欄位就代表**寫入失敗**，內容是錯誤描述；沒有代表成功 |

**這把 key 存在的唯一理由**：使用者在通知上按「標示為已完成」時，Android **一律**另開一個
FlutterEngine 來處理（`ActionBroadcastReceiver.java:83-89`，不檢查主 App 是否活著）。
那個 isolate **沒有任何 UI**，所以失敗沒有地方可以顯示。

把結果寫進這裡，主 isolate 在下次啟動或回到前景時讀走，就能做兩件事：

1. **重載資料**——背景已經改過 D1 `tasks`（或訪客的 `guest_tasks`），主 isolate 的記憶體狀態
   一定是舊的，不重載畫面會一直顯示任務未完成
2. **把失敗浮現出來**——透過既有的 `reportSyncError()` 顯示 SnackBar

⚠️ 這是 **CLAUDE.md §9 硬規則 2**（絕不靜默吞掉寫入錯誤）在沒有 UI 的情境下的作法：
失敗被**延後**顯示，不是被吞掉。

⚠️ **SharedPreferences 每個 isolate 各自快取**。主 isolate 讀這把 key 之前必須先呼叫
`prefs.reload()`，否則讀到的是自己那份還沒有這筆記錄的舊快取。讀完即清空。

> **名稱沿用**：這把 key 叫 `notification_action_log` 是因為通知先做。小工具後來也需要
> 完全相同的東西（背景寫入、沒有 UI 可回報失敗），所以**共用同一把 key 與同一套流程**，
> 而不是再開一份幾乎一樣的機制。記錄的內容（`task_id` + 選擇性的 `error`）與來源無關。

---

## D15. 裝置本機儲存 — `HomeWidgetPreferences`（桌面小工具）

媒介：SharedPreferences，**注意這是 `home_widget` 套件自己的檔案**（檔名
`HomeWidgetPreferences`），與 App 其他 key 所在的預設檔**不是同一個**。
只能透過 `HomeWidget.saveWidgetData()` / `getWidgetData()` 存取。

寫入處理程序：`HomeWidgetService.push()`（`src/lib/services/home_widget_service.dart`）
讀取處理程序：原生的 `TaskWidgetProvider` / `WidgetListFactory`（Kotlin），以及背景 isolate

| Key | 型別 | 說明 |
|---|---|---|
| `widget_snapshot` | JSON 字串 | `buildWidgetSnapshot()` 的完整輸出（見下表）。**原生端勾選時會先改這份**，把該列的 `check` 標成 `checked` |
| `widget_state` | JSON 字串 | **原生端寫入**（`WidgetData.writeState()`）：`mode`（`tasks` / `targets` / `goals` / `filterPicker`）/ `period`（`all` / `day` / `week` / `month`）/ `filter_id`（null＝不篩選）。使用者在小工具上的選擇，App 重開後沿用。Dart 不讀也不寫 |
| `widget_language` | text | 語言代碼（`zhTw` / `en` / `jp`）。**背景 isolate 需要它才能用正確語言重建 snapshot**——App 設定在訪客模式完全不持久化，雲端那份背景也未必讀得到 |

`widget_snapshot` 的結構：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `views` | object | `tasks_all` / `tasks_day` / `tasks_week` / `tasks_month` / `targets` / `goals` / `filter_picker` → 各自的列陣列。**所有頁一次算好**，切換時原生端直接換 |
| `views.*[]` | object | 一列：`title`、`subtitle`（無副標為 **JSON null**）、`color`（ARGB）、`check`（`none` / `unchecked` / `checked`）、`tap`、`check_action`、`header`、`filters` |
| `views.*[].filters` | text[] | 只有任務列有內容：它連結的目標／願景**連同所有祖先**的 id。原生端篩選只比對「含不含選中的 id」 |
| `empty` | object | `tasks` / `targets` / `goals` / `filter_picker` → 空清單文案 |
| `filter_default` | text | 沒有篩選時篩選鈕的文字 |
| `filter_labels` | object | 每個目標與願景的 id → 標題，篩選鈕顯示目前選中者的名稱用 |

⚠️ Kotlin 的 `JSONObject.optString()` 遇到 JSON null 會回傳**字串 `"null"`**，所以原生端
一律用 `WidgetData.str()` 讀字串欄位。

**特別說明：**

- **snapshot 是推導出來的，不是資料來源**。內容全部由 D1 `tasks`、D2 `semester_goals`、
  D3 `future_goals`、D7 `user_categories`（或訪客的本機鏡像）算出來，資料一變就整份重寫。
  它存在的唯一理由是**原生端讀不到那些來源**——Kotlin 不能查 Supabase，也不該懂業務規則。
- **原生端只渲染 `rows`**，完全不知道「任務」「目標」「篩選」是什麼。新增一種列的樣式
  不需要改 Kotlin。
- `widget_state` **只有原生端寫**。`widget_snapshot` 則有三個寫入者：App（P10）、背景引擎
  （勾選後重算，或寫入失敗時用 `untickInSnapshot()` 取回勾選）、原生端（勾選當下先標成已勾）。
  原生端一律 `commit()` 完才轉交 Dart，所以 Dart 的結果永遠在後面蓋上去，沒有加鎖。

---

## 列舉值與特殊格式總表

| 名稱 | 定義位置 | 可能值 |
|---|---|---|
| `RecurrenceType` | `src/lib/models/task.dart` | `none` / `daily` / `weekly` / `monthly` / `everyNDays` |
| `TrashItemType`（儲存為字串） | `src/lib/models/trash_item.dart` | `task` / `semester_goal` / `future_goal` |
| `FutureCategories`（內建分類） | `src/lib/models/future_goal.dart` | `exchange` / `intern` / `competition` / `certification` / `performance` / `other` |
| `NotificationKind` | `src/lib/models/notification_settings.dart` | `taskDue` / `dailySummary` / `goalDeadline` |
| `TaskSort`（儲存為字串，D19） | `src/lib/providers/tasks_provider.dart` | `manual` / `created` / `title` / `target` / `due` |
| `TargetSort`（儲存為字串，D20） | `src/lib/providers/semester_goals_provider.dart` | `manual` / `title` / `vision` / `undoneFirst` |
| `VisionSort`（儲存為字串，D21） | `src/lib/providers/future_goals_provider.dart` | `manual` / `title` / `startSemester` / `endSemester` |
| 通知 payload 格式 | `src/lib/core/notification_payload.dart` | `"{task_id}\|{yyyy-MM-dd}"`；日期是**該次提醒對應的那一天**，循環任務靠它決定勾掉哪一天 |
| `DateDisplayFormat`（儲存為字串） | `src/lib/providers/settings_provider.dart` | `mmddWeekday` / `mmdd` / `yyyymmdd` / `longDate` |
| `AppLanguage`（儲存為字串） | `src/lib/providers/settings_provider.dart` | `zh_tw` / `en` / `jp` |
| 學期字串格式 | `semester_goals_provider.dart` / `future_goal.dart` | 一般學期：`"{民國年}-{學期序}"`，例如 `"114-1"`；假期：`"{民國年}-B{學期序}"`，例如 `"114-B1"` 代表「第 1 學期後面那個假期」（見下方假期字串格式）。比較大小一律用 `compareSemesters()`，不要用字串或數字直接比較 |
| 假期字串格式 | `future_goal.dart` (`compareSemesters`/`isBreakToken`) / `semester_helpers.dart` (`breakName`/`formatSemester`) | `"{民國年}-B{k}"`，k = 1..該年學期數，第 k 個假期緊接在第 k 個學期之後，`k = 學期數` 永遠是「暑假」（下學年第 1 學期開學前的長假）。⚠️ 假期名稱是依「目前的學期制度（`SemesterSettings.count`）」動態算出來的位置對應名稱，不是存在 token 裡——如果使用者事後把兩/三/四學期制切換掉，舊資料裡已選的假期字串顯示名稱可能會跟著改變（例如 `"114-B1"` 在二學期制是寒假、在四學期制變成秋假）。這是已知、刻意接受的簡化，非 bug。 |
| 日期字串格式（`Task.completedDates` / `Journal.date`） | 各自 Model | `"yyyy-MM-dd"`（月、日補零至 2 位） |

---

## 已知現況／技術債備註

- `src/lib/providers/custom_categories_provider.dart` 中的 `customCategoriesProvider` 目前
  沒有被任何畫面使用，是與 D7 `user_categories` 無關的死碼，維護時請勿誤以為它是分類系統的
  一部分。
- D2 `semester_goals.category`（單數欄名、JSON 字串陣列）與 D3 `future_goals.categories`
  （複數欄名、原生陣列）的存法不一致，是既有設計，非本次文件撰寫產生的錯誤——修改任一邊的
  序列化邏輯前，請先確認不會影響另一邊。

---

## D16. 裝置本機儲存 — `recent_picks`（任務表單的建議）

媒介：SharedPreferences，存一段 **JSON 字串**。

寫入處理程序：`RecentPicksNotifier`（`src/lib/providers/recent_picks_provider.dart`），
由任務 sheet 送出與學期目標 sheet 送出時呼叫
讀取處理程序：任務 sheet 的建議 chip

| 欄位 | 型別 | 說明 |
|---|---|---|
| `targets` | text[] | 最近用過的學期目標 id，**新的在最前面**、不重複、最多 8 筆。「用過」＝任務連結了它，或新增／編輯了該目標本身 |
| `times` | text[] | 最近用過的截止時間，`HH:mm`，同樣新的在前、最多 8 筆 |

**特別說明：**

- **純粹是方便，不是資料**：只記 id 與時分，內容都在 D1／D2；整段刪掉只會少了建議。
  因此**不上雲**，訪客模式一樣能用。
- 目標可能已被刪除，所以讀取時會過濾掉查不到的 id（`resolveRecent()`），只顯示前 3 筆。
- 時間套用到「今天」，**若該時刻已經過了就改成明天**（`suggestedDueDate()`）。

---

## D19. 裝置本機儲存 — `task_sort`（任務排序）

媒介：SharedPreferences，`String`（`manual` / `created` / `title` / `target` / `due`，預設 `manual`）。

寫入／讀取處理程序：`taskSortProvider`，型別是通用的 `EnumPrefNotifier<TaskSort>`
（`src/lib/providers/sort_prefs.dart`；定義在 `tasks_provider.dart`）

任務清單目前照哪種順序排（見 system_design.md §3-A）。與 D13／D17／D18 一樣是**這台裝置的
偏好**，不上雲。讀到不認得的值就退回 `manual`。

「調整順序」模式（顯示拖曳把手）**不持久化**：`taskSortModeProvider` 只存在記憶體，App 重開一律是關閉。

---

## D20. 裝置本機儲存 — `target_sort`（目標排序）

媒介：SharedPreferences，`String`（`manual` / `title` / `vision` / `undoneFirst`，預設 `manual`）。

寫入／讀取處理程序：`targetSortProvider`（`EnumPrefNotifier<TargetSort>`，定義在
`src/lib/providers/semester_goals_provider.dart`）

目標頁的排序方式，規則同 D19：本機偏好、不上雲、不認得的值退回 `manual`。排序只改變**顯示順序**，
不寫回 D2 的 `sort_order`；只有 `manual` 時可以拖曳（拖曳才會寫 `sort_order`）。
「調整順序」模式同樣只存記憶體（`targetSortModeProvider`）。

---

## D21. 裝置本機儲存 — `vision_sort`（願景排序）

媒介：SharedPreferences，`String`（`manual` / `title` / `startSemester` / `endSemester`，預設 `manual`）。

寫入／讀取處理程序：`visionSortProvider`（`EnumPrefNotifier<VisionSort>`，定義在
`src/lib/providers/future_goals_provider.dart`）

願景頁的排序方式，規則同 D20。「調整順序」模式只存記憶體（`visionSortModeProvider`）。

---

## D18. 裝置本機儲存 — `fab_pos_main` / `fab_pos_inspiration`（新增鈕的位置）

媒介：SharedPreferences，`String`，格式 `"{x},{y}"`，兩個值都是 **0–1 的比例**。

寫入／讀取處理程序：`FabPositionNotifier`（`src/lib/providers/fab_position_provider.dart`）

兩顆浮動新增鈕（主鈕與靈感鈕）被拖到哪裡。存比例而不是像素：同一支手機轉向、平板與桌面視窗
讀回同一個值都不會讓按鈕跑到畫面外；讀回來的值一律夾在 0–1 之間。預設值是
`1,1`（右下）與 `0,1`（左下）。與 D13／D17 一樣是**這台裝置的體感設定**，不上雲。

---

## D17. 裝置本機儲存 — `task_completion_effect`

媒介：SharedPreferences，`String`（`off` / `basic` / `celebrate`，預設 `celebrate`）。

寫入／讀取處理程序：`CompletionEffectNotifier`（`src/lib/providers/settings_provider.dart`）

勾選任務時的動畫強度。與通知設定（D13）一樣是**這台裝置的體感設定**，不進 D8 `user_settings`，
所以換裝置不會帶著走，也不需要動 Supabase 結構。

---

## D22. 裝置本機儲存 — `onboarding_done`（新手導覽章節）

媒介：SharedPreferences，`List<String>`（StringList；預設空清單，即「一章都還沒看過」）。
可能的值是 `kTourChapters` 的章節 id：`today`、`semester`、`future`、`me`，
依序對應四個分頁（`src/lib/providers/onboarding_provider.dart`）。

寫入／讀取處理程序：`onboardingProvider`（`StateNotifier<Set<String>>`）；
與 D12 `is_guest_mode` 一樣，`main()` 會先 `preloadOnboarding()` 讀進一個 library 私有
變數，Notifier 才有正確的初始值——否則 `HomeScreen` 的第一次 build 會對已經看過的人
再開一次章節。

哪幾章新手導覽已經跑過（system_design.md UC16）。某一章在清單裡，切到那個分頁就不再自動
播放；走完或按 ✕「略過這章」都會 `markDone(id)`（先改記憶體狀態再寫磁碟）。
設定頁的「新手指南」可以重播任何一章，重播**不會**把它移出清單。

**2026-09-25 取代先前的 `onboarding_seen`（bool）**：那把 key 只存在於從未出貨的程式碼中，
所以直接替換、沒有遷移。

**為什麼不上雲、也不進訪客資料清單**：

- 不進 D8 `user_settings`：它描述的是**這台裝置**，不是這個人。在手機上看過導覽，
  換到桌面版應該還是要看一次（版面完全不同）。性質同 D13／D17／D18。
- 不在 `guest_provider.dart` 的 `_dataKeys`（那份清單是「離開訪客模式要清掉的使用者資料」）：
  訪客轉正式帳號的當下，這個人**剛剛才用完 App**，再放一次導覽是倒退。
  所以合併帳號不會重播導覽——這是刻意的。
