# 測試方法（Testing Methods）

本文件定義 **URniversity** 採用的測試分類與各類測試在本專案中的具體做法，供開發者在撰寫或
執行測試前查閱，確保測試案例有一致的依據、不會遺漏關鍵情境。

測試案例的**依據來源**：
- 功能行為、操作步驟 → [system_design.md](./system_design.md) 第 2、4 節（輸入輸出格式、使用案例）
- 內部邏輯分支 → [system_design.md](./system_design.md) 第 3、5 節（處理過程、程式流程圖）
- 資料格式與邊界 → [DD.md](./DD.md)（欄位型別、必填、預設值、列舉值）
- 資料流向是否正確 → [DFD.md](./DFD.md)（哪個處理程序該讀寫哪個資料儲存）

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
| 邊界測試 | 極端值與無效輸入 | DD.md 欄位規則 | 單元測試優先，其餘手動 |

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
| `test/sync_retry_test.dart` | `isTransientSyncError()` 的分類、`runWithRetry()` 的重試次數與退避 |
| `test/restore_sanitize_test.dart` | `sanitizeForRestore()` 清掉指向已刪除列的懸空外鍵 |
| `test/merge_order_test.dart` | `mergeOrder()` 的拓撲排序：父先於子、懸空 parent 視為根、循環不會無窮迴圈 |
| `test/trash_snapshot_test.dart` | `remove()` 回傳整棵子樹（目標／願景／任務），還原後父子關係完整 |
| `test/auth_link_error_test.dart` | 失效的驗證連結分類：query string／fragment／Android custom scheme 三種形式，以及 PKCE 跨裝置與一般登入錯誤的區分 |
| `test/notification_schedule_test.dart` | 通知排程的產生規則（system_design.md §3-K）：三種提醒的觸發與排除條件、循環任務逐日展開、視野與則數上限、id 不碰撞、payload 帶對日期 |
| `test/notification_action_test.dart` | 通知動作依賴的純邏輯（§3-L）：`Task.toggledOn()` 與 `isCompletedOn()` 互為反函式、payload 編解碼、畸形輸入回 null 不拋例外、動作結果的成功／失敗記錄 |
| `test/widget_snapshot_test.dart` | 桌面小工具要顯示什麼（§3-M）：六份預算好的頁面、三個期間互不影響、day/week/month 的範圍與去重、任務列 `filters` 含祖先 id（含循環 parent 不卡死）、篩選挑選器的分組與排序、序列化（無副標為 null） |
| `test/row_id_test.dart` | `newRowId()` 在**每個平台**都做得出 id、亂數後綴在 32 位元內。⚠️ 這份要**另外在 Chrome 跑一次**（`flutter test --platform chrome test/row_id_test.dart`）：網頁上 `<<` 只有 32 位元，`1 << 32` 會變成 0，VM 上的測試完全抓不到 |
| `test/row_id_source_test.dart` | 防呆：`newRowId()` 的亂數上限必須是字面值 `0x100000000`，**原始碼裡不得再出現 `<< 32`**（比對前先去掉註解行）。VM 專用，因為 `1 << 32` 在 VM 上是對的，只有讀原始碼才擋得住這個回歸 |
| `test/category_palette_test.dart` | 分類顏色盤：24 色不重複、內建六色仍排在最前且順序不變（既有分類不會因為擴充而改色） |
| `test/recent_picks_test.dart` | 任務表單的建議（§3-A）：最近用過的排序與去重、上限、已刪除的目標不出現、`suggestedDueDate()` 未過→今天／已過→明天／跨月 |
| `test/new_item_order_test.dart` | 新增置頂（§3-C）：任務／學期目標／願景新增後排在同層最上面；拖曳過的任務在之後新增時位置不變；子任務、子願景、不同學期只跟自己那一層比 |
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
| 意見回饋冷卻 | 第 299／300 秒 | 299 秒內拒絕；滿 300 秒可送出 |
| 目標／願景樹深度 | 深度 1／5 層 | 遞迴刪除與 `isAncestor` 在深層仍正確 |

### 2.6 Widget 測試（Widget Testing）

工具：`flutter test`，測試檔置於 `src/test/widget/`，共用基礎建設在
`src/test/helpers/pump_app.dart`。

| 測試檔 | 覆蓋範圍 | 退役的手動案例 |
|---|---|---|
| `test/widget/responsive_test.dart` | 13 個單欄畫面在 767／768px 的斷點切換與限寬值（420／640），四個分頁不得使用 `ResponsiveBody` | `2026-08-23-style-and-responsive.md` 23–38 |
| `test/widget/password_reset_test.dart` | 忘記密碼入口與預填、新密碼的不一致／長度驗證、`_AuthGate` 的 recovery 優先序、關閉後離開 recovery、失效連結的提示（含訪客在首頁時也看得到）、三語在地化 | `2026-09-05-phase0-reliability.md` 7、8、10、14、15、17 |
| `test/widget/goal_link_visibility_test.dart` | 「只有頂層目標能連結願景」在新增／編輯表單、詳情頁、願景選單四處一致 | `2026-08-23-known-issues.md` 20–25、28 |
| `test/widget/today_smoke_test.dart` | `showTaskSheet`／`showAddInspirationSheet` 的新增與編輯、視角切換、篩選橫幅、已完成區塊 | `2026-08-23-known-issues.md` 30、31、33、34、35 |
| `test/widget/settings_dialogs_test.dart` | 語言／日期格式／預設視角／學期制四個對話框，回收桶清空確認 | `2026-08-23-style-and-responsive.md` 19、21 |
| `test/widget/notification_settings_test.dart` | 通知設定畫面：總開關關閉時三個分項不可動、不支援平台顯示提示並鎖住開關、提前時間選擇寫得回去 | —（新功能） |
| `test/widget/completion_effect_test.dart` | 完成動畫：勾選後放大**再回到原大小**（殘留 bug 的回歸測試）；設定為關閉時完全不縮放 |
| `test/widget/link_color_bar_test.dart` | 色條：兩個連結顏色不同時上下分色、相同時合併、單一連結一色、沒有連結仍保留寬度 |
| `test/widget/notification_reschedule_test.dart` | 「重新安排時間」會打開**該任務**的編輯 sheet；冷啟動時資料還沒到會等待而不是放棄 | —（新功能） |

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

---

## 3. 測試計畫撰寫規定

每次測試前，複製 [test-plans/TEMPLATE.md](./test-plans/TEMPLATE.md) 到
`docs/test-plans/`，以 `YYYY-MM-DD-主題.md` 命名（例如 `2026-07-20-task-recurrence.md`），
填寫測試範圍、採用的測試類型（可勾選本文件 §1 分類）、測試案例與預期結果；測試執行後補上
實際結果與是否通過。測試計畫需保留在版本控制中，作為之後迴歸測試與問題追蹤的依據。
