# 測試方法（Testing Methods）

本文件定義 **URniversity** 採用的測試分類與各類測試在本專案中的具體做法，供開發者在撰寫或
執行測試前查閱，確保測試案例有一致的依據、不會遺漏關鍵情境。

測試案例的**依據來源**：
- 功能行為、操作步驟 → [system_design.md](./system_design.md) 第 2、4 節（輸入輸出格式、使用案例）
- 內部邏輯分支 → [system_design.md](./system_design.md) 第 3、5 節（處理過程、程式流程圖）
- 資料格式與邊界 → [data_dictionary.md](./data_dictionary.md)（欄位型別、必填、預設值、列舉值）
- 資料流向是否正確 → [data_flow_diagram.md](./data_flow_diagram.md)（哪個處理程序該讀寫哪個資料儲存）

> **維護規則**：每一次執行測試（不論是新功能測試或迴歸測試），都必須先依
> [test-plans/TEMPLATE.md](./test-plans/TEMPLATE.md) 撰寫一份測試計畫，說明測試範圍、採用的
> 測試類型與案例、預期結果，測試完成後記錄實際結果。詳見專案根目錄 `CLAUDE.md`。

## 現況說明

本專案目前**沒有自動化 CI 流程**，但**已有可執行的自動測試**（`src/test/`，269 個案例，
`flutter test` 全綠）。`flutter create` 產生的預設計數器範例 `widget_test.dart` 已刪除。

自動測試分兩層：**單元測試**涵蓋不依賴 Supabase／SharedPreferences 的純函式（§2.1）；
**Widget 測試**在訪客模式下驅動真實畫面（§2.6）。訪客模式的寫入走
`persistLocally()` 就返回，不會連上 Supabase，所以整個畫面樹可以在沒有網路、
沒有 stub 的情況下跑起來。

其餘部分仍以「依測試計畫手動執行 + 記錄結果」為主。累積的手動案例依風險分層在
[test-plans/2026-09-12-manual-checklist.md](./test-plans/2026-09-12-manual-checklist.md)
（P0 擋住發布／P1 自動測試只涵蓋一半／P2 日常已驗證），不確定先測哪些時從那裡開始。**雲端持久化、信件送達、
視覺外觀（字距／權重／顏色）、實機平台行為（deep link、旋轉、launcher widget）
這四類無法自動化**，會長期留在手動清單裡。

**實機測試環境**：手動測試（尤其是觸控拖曳與 Android 專屬行為）需要把 app 跑到實體手機上。
環境建置方式、可遠端 hot reload 的作法，以及已知的連線陷阱，見
[dev-remote-testing.md](./dev-remote-testing.md)。

---

## 1. 測試分類總覽

早期版本列了 10 種類型，但那份清單混用了四種不同的分類軸——**範圍**（單元／系統）、
**觀點**（黑箱／白箱）、**階段**（Alpha／Beta）、**面向**（平台／效能／極限值）。
結果是同一次手動走查同時算「系統測試＋黑箱測試＋Alpha 測試」，勾三個框卻沒有增加任何資訊，
而且其中四種（單元、接受度、Beta、效能）從未真正執行過。

現行清單只保留**對應到實際不同活動**的五種：

| 類型 | 目的 | 依據 | 執行方式 |
|---|---|---|---|
| 單元測試 | 驗證純函式的輸入輸出與邊界 | system_design.md §3 | `flutter test`（已建立，見 §2.1） |
| 系統測試 | 驗證跨畫面／跨 Provider／跨資料層的完整流程 | system_design.md §4 使用案例 | 手動走查 |
| 迴歸測試 | 確認已修好的問題沒有復發、既有功能沒被破壞 | 過往測試計畫的「發現的問題」欄 | 手動，每次變更後 |
| 跨裝置測試 | 響應式斷點、觸控 vs 滑鼠的行為差異 | system_design.md §3-F | 手動，實機＋多視窗寬度 |
| 邊界測試 | 極端值與無效輸入 | data_dictionary.md 欄位規則 | 單元測試優先，其餘手動 |

**黑箱／白箱**不再列為獨立類型，而是描述**測試案例怎麼設計出來的**：
黑箱＝只看 system_design.md §2 的輸入輸出規格；白箱＝照 §5 流程圖覆蓋每個分支。
在測試計畫中直接於案例的「測試類型」欄註明即可（例如「系統／白箱」）。

**Alpha／Beta** 是發佈階段而非測試類型，改記錄在測試計畫的「測試人員」欄。

---

## 2. 各測試類型詳述

### 2.1 單元測試（Unit Testing）

工具：`flutter test`，測試檔置於 `src/test/`。

| 測試檔 | 覆蓋範圍 |
|---|---|
| `test/recurrence_test.dart` | 五種循環規則（不循環／每日／每週／每月／每 N 天），含星期複選、每月日期複選、`kLastDayOfMonth` 的閏年與月長邊界、`interval = 0` 的防護，以及 `taskCompletionStatsOn()` 的統計 |
| `test/semester_test.dart` | `generateSemesters()`／`compareSemesters()`／`currentSemester()`／`formatSemester()`／`breakName()`，含 2／3／4 學期制與假期 token 排序 |
| `test/task_model_test.dart` | `Task` 的 JSON 往返、`copyWith` 的 sentinel 行為（含可清空 `content`）、`isCompletedOn()` 的循環／非循環分流 |
| `test/category_reorder_test.dart` | 分類拖曳排序的 `orderBetween()` 與寫回順序 |
| `test/sync_retry_test.dart` | `isTransientSyncError()` 的分類（含回前景時 token 更新失敗的 `AuthRetryableFetchException`）、`runWithRetry()` 的重試次數與退避 |
| `test/restore_sanitize_test.dart` | `sanitizeForRestore()` 清掉指向已刪除列的懸空外鍵 |
| `test/merge_order_test.dart` | `mergeOrder()` 的拓撲排序：父先於子、懸空 parent 視為根、循環不會無窮迴圈 |
| `test/trash_snapshot_test.dart` | `remove()` 回傳整棵子樹（目標／願景／任務），還原後父子關係完整 |
| `test/auth_link_error_test.dart` | 失效的驗證連結分類：query string／fragment／Android custom scheme 三種形式，以及 PKCE 跨裝置與一般登入錯誤的區分 |
| `test/notification_schedule_test.dart` | 通知排程的產生規則（system_design.md §3-K）：三種提醒的觸發與排除條件、循環任務逐日展開、視野與則數上限、id 不碰撞、payload 帶對日期 |
| `test/notification_schedule_test.dart`（Phase 4 追加） | 每週回顧提醒：兩個週日、帶 `open_review`、已回顧的週不排、跟著時刻與開關、marker 不會被當成任務 payload、設定 JSON 來回。基準設定 `allOn` 關掉回顧提醒，因為其他案例是「關掉別種以隔離一種」寫成的 |
| `test/notification_schedule_test.dart`（第十一批追加） | 沒設時間的重複任務（§3-K）：在設定的時刻排、不套提前量、當天時刻已過就從明天起、跳過已完成那天、跟著任務提醒開關；設定 JSON 來回與舊資料缺 key 時的預設 |
| `test/notification_action_test.dart` | 通知動作依賴的純邏輯（§3-L）：`Task.toggledOn()` 與 `isCompletedOn()` 互為反函式、payload 編解碼、畸形輸入回 null 不拋例外、動作結果的成功／失敗記錄 |
| `test/widget_snapshot_test.dart` | 桌面小工具要顯示什麼（§3-M）：六份預算好的頁面、三個期間互不影響、day/week/month 的範圍與去重、任務列 `filters` 含祖先 id（含循環 parent 不卡死）、篩選挑選器的分組與排序、序列化（無副標為 null） |
| `test/row_id_test.dart` | `newRowId()` 在**每個平台**都做得出 id、亂數後綴在 32 位元內。⚠️ 這份要**另外在 Chrome 跑一次**（`flutter test --platform chrome test/row_id_test.dart`）：網頁上 `<<` 只有 32 位元，`1 << 32` 會變成 0，VM 上的測試完全抓不到 |
| `test/current_occurrence_test.dart` | 「全部任務」裡一列代表哪一次（§3-A `currentOccurrence()`）：今天符合規則→今天、否則往前找最近一次、規則還沒開始→往後找、非循環→截止日、兩者皆無→null；每週／每月／每 N 天各一例 |
| `test/date_rollover_test.dart` | 跨午夜（§3-A）：`untilNextDay()` 算到隔天零點；`rollOverTo()` 只在選取日還停在舊的今天時才跟著換日，使用者自己翻到的日期不動 |
| `test/me_stats_test.dart` | 「我的」頁的連續寫日記天數：從今天往回數、自動補齊的那天中斷連續、今天還沒寫不算中斷、完全沒寫回 0 |
| `test/notification_persistence_source_test.dart` | 防呆：通知要留到任務完成（§3-K）。`apply()` 只取消 pending、原始碼裡不得再出現 `cancelAll()`；`autoCancel: false`；`cancelForTask()` 走 `getActiveNotifications()`。`notification_service.dart` 碰 platform channel，測試環境沒有通道，只能讀原始碼把關 |
| `test/review_stats_test.dart` | 回顧的規則（§3-P）：週一～週日、月底、學期判斷；回顧卡時段的四個邊界（週日 17:59／18:00、週二 23:59／週三）；學期＞月＞週一次一張；做過的不再出現；熱度圖沒排任務是 null；可延後任務排除循環與已完成；目標子樹的里程碑與任務；本週專注的起訖與新舊；快照 JSON 來回與缺鍵 |
| `test/history_stats_test.dart` | 完成度頁的數字（§2-H）：連續達成的三種邊界（今天未完成、昨天未完成、空白日）、區間加總、最強星期幾取平均而非最忙、分類排序與排除無分類、逾期排序含循環任務 |
| `test/sign_in_failure_test.dart` | 登入錯誤的分類（§2-A）：帳號不存在與密碼錯誤同屬一種說法、信箱未驗證、嘗試過多、連線失敗、其他；有碼與只有訊息兩種來源都涵蓋 |
| `test/account_delete_auth_test.dart` | 刪除帳號要哪一種身分證明（UC12）：有密碼就輸入密碼（即使也連結了 Google）、只有 Google 才跳出去重新登入 |
| `test/task_sort_test.dart` | 任務排序（§3-A）：五種順序、沒有截止時間／沒有連結目標排最後、已刪除的目標視為未連結、同鍵值時退回自動順序 |
| `test/goal_category_test.dart` | 沒有分類的目標（§2-C、§3-J）：`primaryCategoryOf()` 回 null、中性色與中性圖示、有分類時不受影響 |
| `test/goal_sort_test.dart` | 目標與願景的排序（§3-C）：手動＝拖曳順序、A–Z 不分大小寫、依願景／依學期時沒有值的排最後、未完成優先、同鍵值時退回手動順序 |
| `test/category_inherit_test.dart` | 連結願景時帶入分類（UC4）：沒有分類才帶入、已有分類不覆蓋、取消連結不清掉 |
| `test/notification_cancel_test.dart` | 完成時該收掉哪幾則通知（§3-K）：只收該任務的、沒有 payload 的摘要不動、沒有 id 的跳過 |
| `test/fab_position_test.dart` | 新增鈕的位置（D18）：比例值往返、讀不懂＝沒移動過、比 1 大的值夾回畫面內 |
| `test/app_version_test.dart` | 版本號（§5-Z）：格式 `alpha-X.Y.Z`，且 `pubspec.yaml` 帶同樣的數字 |
| `test/row_id_source_test.dart` | 防呆：`newRowId()` 的亂數上限必須是字面值 `0x100000000`，**原始碼裡不得再出現 `<< 32`**（比對前先去掉註解行）。VM 專用，因為 `1 << 32` 在 VM 上是對的，只有讀原始碼才擋得住這個回歸 |
| `test/category_palette_test.dart` | 分類顏色盤：24 色不重複、內建六色仍排在最前且順序不變（既有分類不會因為擴充而改色）；頭像 24 個且前十個的位置不變（`avatar_index` 是存在雲端的索引） |
| `test/recent_picks_test.dart` | 任務表單的建議（§3-A）：最近用過的排序與去重、上限、已刪除的目標不出現、`suggestedDueDate()` 未過→今天／已過→明天／跨月 |
| `test/new_item_order_test.dart` | 新增置頂（§3-C）：任務／學期目標／願景新增後排在同層最上面；拖曳過的任務在之後新增時位置不變；第一筆任務從零開始；子願景、不同學期只跟自己那一層比 |
| `test/semester_grouped_picker_test.dart` | 連結選擇器（§3-C）：學期由早到晚、假期 token 夾在前後學期之間、未設定學期放最後、組內新的在上且子項縮排、父項在別學期時子項仍顯示、開啟位置（當前 → 之後最近 → 最晚） |
| `test/widget_action_test.dart` | 小工具動作 URI 的形狀（含 + 按鈕的 `new`）。Kotlin 有一半是手寫組出來的，改名只會表現成「點了沒反應」，所以逐一釘住。另測寫入失敗時 `untickInSnapshot()` 只取回該列的勾選 |

選擇標準：**只測不依賴 Supabase／SharedPreferences 的純函式**，或在沒有設定
`user_id` 的狀態下操作 Provider（此時 `upsert()`／`deleteRow()` 會直接返回）。
`_taskAppliesTo()` 等私有函式透過公開的 `taskCompletionStatsOn()` 間接覆蓋。

尚未涵蓋、之後可補：`isAncestor()`／`reparent()` 的循環參照防護、`computedGrade()`、
`dropZoneFor()` 的 1/4-1/2-1/4 命中判定。

### 2.2 系統測試（System Testing）

依 system_design.md §4 的使用案例逐條走查，驗證跨畫面、跨 Provider、跨資料層
（Supabase／SharedPreferences）串接後的完整行為，例如：

- 新增循環任務 → 切換今日頁不同日期 → 確認只在符合規則的日期出現。
- 建立子目標並拖曳搬移 → 確認 `sort_order` 與 `parent_id` 同步寫回 Supabase。
- 刪除任務／目標 → 回收桶還原 → 確認資料與子節點關聯完整還原。
- 訪客模式操作一輪 → 登入並選擇「整合進帳號」→ 確認雲端資料與訪客時一致。

### 2.3 迴歸測試（Regression Testing）

每次變更後執行，重點是**過往修好的問題不能復發**。作法：翻閱既有測試計畫的「發現的問題」與
「備註」欄，把每一條轉成一個迴歸案例。歷次測試計畫中標記為「迴歸」的案例即為此類。

最低限度：`flutter test` 全綠，且手動走查當次變更所影響的使用案例。

### 2.4 跨裝置測試（Cross-Device Testing）

| 面向 | 測試方式 | 重點 |
|---|---|---|
| 響應式斷點 | 拖曳視窗寬度跨越 767／768／1199／1200px | 版面切換是否正確（見 system_design.md §5-E） |
| 觸控 vs 滑鼠 | 實機 Android + 桌面瀏覽器各走一次 | ⚠️ 拖曳在程式碼中以 `kIsWeb` 分成 `Draggable`（滑鼠）與 `LongPressDraggable`（觸控）兩條路徑，**網頁版測不到手機實際使用的那條** |
| Android 專屬 | 實機安裝 | 權限、系統導覽列遮擋、虛擬鍵盤遮擋輸入框 |

實機環境建置見 [dev-remote-testing.md](./dev-remote-testing.md)。

### 2.5 邊界測試（Boundary Testing）

能寫成單元測試的一律優先寫（見 §2.1），其餘手動：

| 項目 | 邊界值 | 預期行為 |
|---|---|---|
| 響應式斷點 | 767／768／1199／1200px | 767→手機；768、1199→桌面（收合）；1200→桌面（展開）。767／768 已由 `test/widget/responsive_test.dart` 自動涵蓋 |
| 循環「每 N 天」間隔 | 0／1 | 0 被夾為 1（不得崩潰）；1 等同每日 |
| 每月循環日期 | 31 號遇到 2 月 | 該月不出現；「最後一天」則落在 28／29 號 |
| 年級推進 `computedGrade` | 推進後 < 1 或 > 7 | `clamp(1, 7)` |
| 學期制度 | `semester_count` = 2／4 | 上下限皆需正確產生對應數量的起始月欄位 |
| 意見回饋長度 | 9／10／1000／1001 字 | 9 字禁止送出；1001 字截斷為 1000 |
| 輸入字數上限（§2-K） | 上限 × 0.8 − 1／× 0.8／上限／上限 + 1 | 80% 之前不顯示計數器、到 80% 出現、到上限變紅、超過的字打不進去；資料庫 CHECK 擋下 101 字的標題（`23514`） |
| 意見回饋冷卻 | 第 299／300 秒 | 299 秒內拒絕；滿 300 秒可送出 |
| 目標／願景樹深度 | 深度 1／5 層 | 遞迴刪除與 `isAncestor` 在深層仍正確 |

### 2.6 Widget 測試（Widget Testing）

工具：`flutter test`，測試檔置於 `src/test/widget/`，共用基礎建設在
`src/test/helpers/pump_app.dart`。

| 測試檔 | 覆蓋範圍 | 退役的手動案例 |
|---|---|---|
| `test/widget/responsive_test.dart` | 單欄畫面在 767／768px 的斷點切換與限寬值（420／640），四個分頁不得使用 `ResponsiveBody`；登入／註冊改為在 768 切成雙欄（`AuthLayout`） | `2026-08-23-style-and-responsive.md` 23–38 |
| `test/widget/password_reset_test.dart` | 忘記密碼入口與預填、新密碼的不一致／長度驗證、`_AuthGate` 的 recovery 優先序、關閉後離開 recovery、失效連結的提示（含訪客在首頁時也看得到）、三語在地化 | `2026-09-05-phase0-reliability.md` 7、8、10、14、15、17 |
| `test/widget/goal_link_visibility_test.dart` | 「只有頂層目標能連結願景」在新增／編輯表單、詳情頁、願景選單四處一致 | `2026-08-23-known-issues.md` 20–25、28 |
| `test/widget/today_smoke_test.dart` | `showTaskSheet`／`showAddInspirationSheet` 的新增與編輯、視角切換、篩選橫幅、已完成區塊 | `2026-08-23-known-issues.md` 30、31、33、34、35 |
| `test/widget/inspirations_archive_test.dart` | 靈感封存的三段分區、預設收合、封存與完成互不影響 | `2026-09-25-phase3-onboarding-templates.md` 1–4 |
| `test/goal_template_test.dart` | 範本批次建立的筆數、父子連結、分類繼承、**連續套用兩次不碰撞 id**；每個範本一個願景、只有頂層目標連到它、沒分類的目標沿用願景分類、三語標題都不超過字數上限 | `2026-09-25-phase3-onboarding-templates.md` 5–9、`2026-09-26-startup-cache-and-vision-templates.md` 5–8 |
| `test/widget/goal_template_sheet_test.dart` | 目標頁與願景頁的 ✨ 入口、套用後的寫入與 SnackBar、套用的資料可正常刪除 | `2026-09-25-phase3-onboarding-templates.md` 10–12、`2026-09-26-startup-cache-and-vision-templates.md` 9 |
| `test/synced_list_cache_test.dart` | 登入帳號的清單快取（D24）：同一帳號沒網路也看得到上次的資料、別的帳號讀不到、變動寫回、`clear()` 刪除、訪客不寫 | `2026-09-26-startup-cache-and-vision-templates.md` 1–4 |
| `test/widget/review_flow_test.dart` | 引導式回顧（UC17）：週日晚上出現回顧卡、週三不出現；三步走完存一筆且卡片消失；延後只動勾選的任務（+7 天保留時刻）；專注目標出現在任務頁並套用篩選；最多 3 個；同一週重做是更新；回顧紀錄的列表與刪除 | `2026-09-25-phase4-review.md` 1–12 |
| `test/widget/coach_mark_test.dart` | 導覽引擎：`info` 步驟連光圈內也擋住、桌面 rail 的光圈位置、轉向後重新對位、`HomeScreen` 被換掉時遮罩跟著收掉且**不**算看過、✕ 算看過 | `2026-09-25-phase3-onboarding-chapters.md` 1–6 |
| `test/widget/home_tour_test.dart` | 親手操作的章節：**光圈外點不到、光圈內點得到**、跟進真的 sheet 逐欄標示、**存了才前進、關掉沒存就倒回**、選擇器打開時導覽讓開、先跳過這步不留資料、上一步不跨越已完成的動作、每個分頁只播一次、任務章的課表卡一站在檢視切換之前、沒建目標就跳過里程碑段、日記鈕先捲進畫面、有別的頁面在上面時等它關掉才開始、指南頁重播 | `2026-09-25-phase3-onboarding-chapters.md` 7–22 |
| `test/widget/settings_dialogs_test.dart` | 語言／日期格式／預設視角／學期制四個對話框，回收桶清空確認 | `2026-08-23-style-and-responsive.md` 19、21 |
| `test/widget/notification_settings_test.dart` | 通知設定畫面：總開關關閉時三個分項不可動、不支援平台顯示提示並鎖住開關、提前時間選擇寫得回去 | —（新功能） |
| `test/widget/completion_effect_test.dart` | 完成效果：勾選框**先下壓、再微彈、最後回到原大小**（殘留 bug 的回歸測試）；設定為關閉時完全不縮放；只有當天最後一筆會在 `Overlay` 上放彩帶並自行清掉；系統要求減少動態時什麼都不動 | `2026-09-26-motion-redesign.md` 9–11 |
| `test/widget/animated_rows_test.dart` | 清單列的進出（§3-Q）：第一次顯示不播動畫、移除的列先停留再收合、離場中的列點不到、新列展開、留下的列 state 不變、立刻加回的列不會遺失、減少動態時直接消失 | `2026-09-26-motion-redesign.md` 1–4 |
| `test/widget/task_tick_motion_test.dart` | 打勾整段：刪除線正在畫、停留期間仍是全高、之後離開並出現在已完成區；「沒有任務」等最後一列離開才展開；從已完成區取消勾會回來；減少動態時立刻消失 | `2026-09-26-motion-redesign.md` 5–8 |
| `test/widget/haptics_test.dart` | 觸覺回饋（D25）：打勾 light、最後一筆 medium、取消勾 selection；關閉時不震；完成效果關閉不影響震動；開關會記住 | `2026-09-26-motion-redesign.md` 12–14 |
| `test/app_styles_test.dart` | 七種風格的 WCAG 對比（本文、次要、提示、白字對主色、主色對底色、淡主色上的文字）、邊框可見、亮暗與底色一致、圓角範圍；不認得的名稱退回暖棕 | `2026-09-26-app-styles.md` 1–3 |
| `test/timetable_test.dart` | 課表規則（§3-S）：台大與清大節次逐節對照官方表、依學校找節次表、衝堂、第幾週與上課週、開學日建議、今天的課與狀態、格線範圍 | `2026-09-26-phase5-timetable.md` 1–6 |
| `test/gpa_test.dart` | 成績（§3-T）：績分表、學士／研究所及格線、百分制對照印出的官方表 22 點（改成無條件捨去會轉紅）、加權、F/X 計入、通過制與停修排除、未知不是 0、學期與累積、已修學分、目標試算四種結果 | `2026-09-26-phase6-gpa.md` 1–6 |
| `test/widget/timetable_screen_test.dart` | 課表與成績畫面：手動新增落在格線、沒課名不存、搜尋目錄加入含所有時段並標衝堂、每校一個搜尋入口且自己的學校排第一、這學期沒目錄的學校不出現、只查那所學校、讀不到目錄仍可手動新增、刪課進回收桶連時段還原、設定開學日、成績頁三格與百分制與試算、手機寬度不溢出、任務頁「今天的課」只有今天的、上課週外不出現、**入口**：手機 360 課表卡在完成度卡右邊同一列、桌面 1280 在它下方、抽屜／展開的 rail／收合的 rail（900）都能進課表 | `2026-09-26-phase5-timetable.md` 7–13、`2026-09-26-phase6-gpa.md` 7、`2026-09-26-timetable-entry.md` 1–3、`2026-09-26-multi-school-catalog.md` 5–6 |
| `test/period_tables_test.dart` | `scripts/catalog/schools.json` 與 `kSchoolPeriods` 同名、逐節一致（改一邊沒改另一邊會轉紅） | `2026-09-26-multi-school-catalog.md` 4 |
| `scripts/catalog/tests/`（Python，`python -m pytest scripts/catalog`） | 共同：節次轉時段（連續合併、斷開拆分、依表的順序、沒有的節次丟掉）、id 帶學校與學期、同 key 合併授課對象、截斷與最多 20 段、學期格式、每校都有模組與節次表；台大：存下的 NOL 頁 18 欄對應、多授課對象合一、沒流水號的 id、時間欄各種格式（含只有第 10 節）；清大：7 筆真實資料的單／多教室、多老師、HTML 實體、空時間、跨到晚上的連續節次、停開與暑修略過、沒有的學期不寫 | `2026-09-26-multi-school-catalog.md` 1–3 |
| `test/style_assets_test.dart` | `palettes.json` 與 `kStylePalettes` 一致（改了 Dart 沒重跑腳本會轉紅）；小工具色值等於調色盤；每個風格的圖示、啟動 logo、小工具 drawable 都在；manifest 有每個 alias、只有暖棕預設啟用；Kotlin 的風格清單與 `AppStyle` 同序 | `2026-09-26-style-extensions.md` 1–4 |
| `test/app_style_random_test.dart` | 隨機：排除上一個；連續 50 次冷啟動不重複且七種都出現；預抽的下次會被採用；預抽無效或重複時重抽；固定風格照穿；選隨機立刻換並記住；雲端的選擇會套用 | `2026-09-26-style-extensions.md` 5–9 |
| `test/widget/app_style_test.dart` | 設定頁列出七種並套用、深色主題生效、仍停在設定頁；畫面上的東西跟著換，連不依賴任何東西的 const widget 也會重畫（拿掉整棵樹重建會轉紅）；切換時舊畫面淡出；下次開啟記得；七種風格各跑四個分頁＋新增任務 sheet 沒有例外；手動選風格會送出 `setIcon`／`setSplash` 並寫給小工具，隨機只送 `setSplash` 不換圖示 | `2026-09-26-app-styles.md` 4–9、`2026-09-26-style-extensions.md` 10–11 |
| `test/widget/motion_test.dart` | 分頁切換會淡入、各平台的頁面轉場、目標卡展開成詳情頁再縮回、新增鈕按下（含觸控）會縮小 | `2026-09-26-motion-redesign.md` 15–18 |
| `test/widget/auth_layout_test.dart` | 登入／註冊頁的外殼（§2-A）：標語與每一個入口都在、註冊頁同一套外殼、矮螢幕仍可捲動 |
| `test/widget/semester_dialog_test.dart` | 學期清單（§2-C）：開啟時停在當前學期、更早的往上捲得到、篩選版的「不限學期」在最上面 |
| `test/widget/vision_filters_test.dart` | 願景頁的篩選（§2-C、§2-I）：分類排在學期上方、選一個分類會過濾清單、「更多分類」對話框只能挑不能改 |
| `test/widget/task_sort_ui_test.dart` | 排序選單（§2-B）：選 A–Z 後順序改變且拖曳停用，改回手動後拖曳恢復 |
| `test/widget/goal_card_test.dart` | 目標卡的顏色（§2-C、§3-J）：沒有分類＝色條無色、圖示方塊空著；有分類＝自己的顏色與圖示；沒有分類但連了願景＝願景的顏色 |
| `test/widget/stats_pages_test.dart` | 兩張改版頁面（§2-G、§2-H）：完成度頁出現摘要／分類／逾期三區且逾期天數正確、空資料時說「沒有逾期」；關聯圖有圖例與篩選 chip、點節點開摘要卡而不離開頁面、「未連結」只留沒連願景的目標 |
| `test/widget/task_row_layout_test.dart` | 兩行標題的任務列（§2-B）：連結目標那行仍在自己的列內，不被下一列蓋掉。舊的 `IntrinsicHeight` 量錯高度就會轉紅 |
| `test/widget/page_header_test.dart` | 四個主頁面的三條線按鈕在同一個位置（§3-E-B） |
| `test/widget/swipe_switch_test.dart` | 左右快滑切換（UC6-B）：今日頁三種檢視、目標頁換學期、慢速拖曳不切換 |
| `test/widget/sheet_dismiss_test.dart` | 往下拉關閉 sheet（§2-B）：拉得夠遠會關、只拉一點不會 |
| `test/widget/target_filter_dialog_test.dart` | 目標篩選對話框（§2-D）：每個學期都有 chip 與標頭、chip 只留該學期、列是可複選的勾選列且勾了不關閉、有重置 |
| `test/widget/link_color_bar_test.dart` | 色條：兩個連結顏色不同時上下分色、相同時合併、單一連結一色、沒有連結仍保留寬度 |
| `test/widget/notification_reschedule_test.dart` | 「重新安排時間」會打開**該任務**的編輯 sheet；冷啟動時資料還沒到會等待而不是放棄 | —（新功能） |
| `test/widget/sort_mode_test.dart` | 調整順序模式（§2-B、UC5-B）：出現把手且改用立即拖曳的 `Draggable`、點列不打開、從別種排序進入會先切回手動、「完成」恢復長按拖曳；目標頁與願景頁的排序 sheet 會重排卡片並停用拖曳 | —（新功能） |
| `test/widget/input_limits_test.dart` | 字數上限與全文顯示（§2-K、§2-B）：標題停在 100 字且出現計數器、遠低於上限時不顯示計數器、長標題不截斷；新增子目標時預先帶入父目標分類（UC4） | —（新功能） |

**可行的前提**：訪客模式下 `SyncedListNotifier.upsert()` 走完 `persistLocally()`
就返回，不碰 Supabase。Supabase 本身仍需初始化（多個 Provider 會讀
`Supabase.instance.client`），但以 `EmptyLocalStorage` + `detectSessionInUri: false`
初始化後不碰儲存也不連線。

**三個踩過的坑**：

1. **四個分頁沒有自己的 `Scaffold`**，還會呼叫 `Scaffold.of(context)`。要透過
   `pumpApp()`／`HomeScreen` 間接 pump，不能單獨 pump 分頁。
2. **`IndexedStack` 的非選中分頁是 offstage**，`find` 預設會跳過。要斷言全部四個
   分頁，必須加 `skipOffstage: false`，否則測試會安靜地只檢查到一個分頁。
3. **`pumpApp()` 之後才能種資料**。`App` 會 watch `syncProvider`，訪客模式下它呼叫
   `loadGuest()` 把每個 Provider 的 state 從 SharedPreferences 重新載入，
   pump 之前種的資料會被洗掉。
4. **新手導覽預設當作「已經看過」**（2026-09-25 新增）。章節是一片蓋住 `HomeScreen`
   的遮罩，光圈以外的點擊全部擋掉；`setUpTestSupabase()` 因此預設把 D22 `onboarding_done`
   設成全部四章，否則所有 `pumpApp()` 的測試都會變成在點導覽而不是在點畫面
   （當初一次弄紅 11 個）。要測導覽本身就傳 `setUpTestSupabase(seenTour: false)`。
   `pumpScreen()` 的 `MaterialApp` 也掛了 `tourRouteObserver`，導覽才看得到 sheet 的開關。
   這條與 `guest` 參數是同一個道理：**測試要先講清楚自己要的是哪一種起始狀態的使用者。**
5. **打勾後的列會停留約 0.55 秒**（2026-09-26 新增，§3-Q）。刪除線、`AppMotion.hold`、收合都是
   controller 驅動，`pumpAndSettle()` 會等完；只 `pump()` 一次就斷言「列不見了」會失敗。
   反過來要測「還在」就刻意只 pump 到停留期間。要測減少動態，用
   `tester.platformDispatcher.accessibilityFeaturesTestValue`，並在 tearDown 清掉。
6. **`AppColors` 是全域狀態**（2026-09-26 新增，§3-R）。測試切換了風格，就要在 `tearDown`
   用 `AppColors.use(kStylePalettes[AppStyle.linen]!)` 換回來，否則下一個測試會在別的風格下跑，
   斷言顏色的測試就會莫名失敗。

**平台相關的坑**：`flutter test` 的 `defaultTargetPlatform` **預設回報 android**，
不是 host 平台。要測「不支援的平台」那條路徑必須用 `debugDefaultTargetPlatformOverride`，
而且**要在測試本體裡還原**（用 `try/finally`）——框架在 `addTearDown` 之前就會斷言
foundation 的 debug 變數已經復原。

**原生 widget 的畫面完全測不到**：桌面小工具是用 Kotlin 的 `RemoteViews` 畫的，跑在
launcher 的行程裡，`flutter test` 碰不到。因應方式與背景 isolate 相同——把「該顯示什麼」
全部推進 `buildWidgetSnapshot()` 這個純函式測到滿，讓只能實機驗的縮到「原生端有沒有把
那些列正確畫出來」。

**背景 isolate 測不到**：「標示為已完成」跑在另一個 FlutterEngine 裡，自動測試無法涵蓋。
因應方式是把它依賴的東西全部做成純函式（`Task.toggledOn()`、payload 編解碼、動作記錄的
序列化）並逐一測試，讓真正只能實機驗的部分縮到最小——剩下的就是「它有沒有被呼叫到」。

**不做的事**：不用 golden test 測視覺。沒有可信的基準圖時，測試紅了也分不出是真的
跑版還是基準過期，維護成本高於價值。字距／權重／顏色留在手動清單。

**但位置關係測得到**：不用 golden 不代表所有視覺問題都只能靠眼睛。新手導覽的高亮
（`SpotlightPainter.hole`）就是用 `tester.getCenter()` 取得目標元件的位置，直接斷言
「挖出來的洞包住那個元件」——文案全對但光圈打在別的地方，是這種功能最可能壞掉的方式，
而它是幾何問題，不是像素問題。同理可用於任何「A 必須對準 B」的版面規則。

**導覽的核心斷言都做過反向驗證**：把「光圈可穿透」關掉、把「關掉 sheet 視為已存」寫死、
拿掉遮罩 painter 外的 `IgnorePointer`，三種改法各自讓 `home_tour_test.dart` 轉紅
（8／1／8 個案例），證明這些測試真的會抓到這三種壞法。

---

## 3. 測試計畫撰寫規定

每次測試前，複製 [test-plans/TEMPLATE.md](./test-plans/TEMPLATE.md) 到
`docs/test-plans/`，以 `YYYY-MM-DD-主題.md` 命名（例如 `2026-07-20-task-recurrence.md`），
填寫測試範圍、採用的測試類型（可勾選本文件 §1 分類）、測試案例與預期結果；測試執行後補上
實際結果與是否通過。測試計畫需保留在版本控制中，作為之後迴歸測試與問題追蹤的依據。
