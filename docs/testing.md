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

本專案目前**沒有自動化 CI 流程**，`src/test/widget_test.dart` 是 `flutter create` 產生的預設
計數器範例測試，與本專案實際功能無關（也會直接測試失敗），尚未被實際功能測試取代。在建立
真正的自動化測試前，測試以「依測試計畫手動執行 + 記錄結果」為主，本文件所列方法同時適用於
手動與未來自動化測試。

---

## 1. 測試分類總覽

| 類型 | 目的 | 依據 | 執行方式（現況） |
|---|---|---|---|
| 平台測試 | 確認跨瀏覽器／跨裝置寬度行為一致 | system_design.md §1-B、§3-F | 手動，多瀏覽器＋多視窗寬度 |
| 單元測試 | 驗證單一函式的輸入輸出正確 | system_design.md §3 | `flutter test`（待補齊案例） |
| 系統測試 | 驗證跨畫面／跨 Provider／跨資料層的完整流程 | system_design.md §4 使用案例 | 手動走查 |
| 接受度測試 | 確認成品符合原始企劃目標 | README.md「Expected Features」、docs/report.md | 手動，對照需求清單 |
| Alpha 測試 | 開發者本人於發佈前自我測試 | 全部文件 | 手動，開發者本人 |
| Beta 測試 | 小範圍外部使用者試用並回報 | 使用者實際操作 + App 內建意見回饋 | App 內「意見回饋」功能收集（D9 `feedbacks`） |
| 黑箱測試 | 只依輸入輸出規格測試，不管內部實作 | system_design.md §2 | 手動或未來的 widget/integration test |
| 白箱測試 | 依內部邏輯分支設計測試案例 | system_design.md §3、§5 流程圖 | `flutter test` 單元測試 |
| 極限值測試 | 針對邊界值與極端輸入驗證 | DD.md 欄位規則 + system_design.md §2 | 手動或單元測試 |
| 效能測試 | 大量資料／複雜運算下是否維持可用效能 | system_design.md §3-G 等演算法 | 手動觀察 + Flutter DevTools |

---

## 2. 各測試類型詳述

### 2.1 平台測試（Cross-Platform Testing）

目前僅發行 Web 版本（見 README.md）。測試矩陣：

| 平台 | 瀏覽器／環境 | 重點 |
|---|---|---|
| 桌面瀏覽器 | Chrome、Edge、Firefox | 版面、拖曳排序、滑鼠 hover 效果、鍵盤操作 |
| 桌面瀏覽器（Safari／macOS，若有裝置可測） | Safari | 日期選擇器、字型渲染差異 |
| 行動瀏覽器 | Chrome (Android)、Safari (iOS) | 觸控拖曳、虛擬鍵盤是否遮擋輸入框、`LongPressDraggable` 是否正常觸發 |
| 視窗寬度（跨平台共同） | 767 / 768 / 1199 / 1200px | 響應式斷點切換是否正確（見 §2.9 極限值測試） |

原生 Android／iOS／Windows 版本尚未發行（見 README.md「Next」），待正式支援後本節需擴充
實機測試矩陣（不同螢幕密度、系統手勢衝突、通知權限等）。

### 2.2 單元測試（Unit Testing）

工具：`flutter test`，測試檔置於 `src/test/`，建議路徑鏡射 `src/lib/` 結構（例如
`src/test/providers/tasks_provider_test.dart`）。

優先覆蓋 system_design.md §3 列出的**純邏輯函式**（不依賴 Supabase／SharedPreferences，容易
隔離測試）：

| 函式 | 檔案 | 建議測試重點 |
|---|---|---|
| `_taskAppliesTo()` / `Task.isCompletedOn()` | `tasks_provider.dart` / `task.dart` | 四種循環規則各自的邊界（見 §5-B 流程圖） |
| `taskCompletionStatsOn()` | `tasks_provider.dart` | 無任務回傳 `null`、有任務時 done/total 正確 |
| `currentSemester()` / `generateSemesters()` / `compareSemesters()` | `semester_goals_provider.dart` / `future_goal.dart` | 跨年度學期、不同 `startMonths` 設定 |
| `computedGrade()` / `academicYear()` | `settings_provider.dart` | 跨學年推進、`clamp(1,7)` 邊界 |
| `isAncestor()` / `reparent()` | `semester_goals_provider.dart` / `future_goals_provider.dart` | 循環參照防護（見 §5-C 流程圖） |
| `Model.fromJson()` / `toJson()` 往返 | `src/lib/models/*.dart` | 序列化後再反序列化應與原值相等，特別注意 `semester_goals.category`（JSON 字串）與 `future_goals.categories`（原生陣列）兩種不同存法（見 DD.md） |

### 2.3 系統測試（System / Integration Testing）

依 system_design.md §4 的使用案例（UC1～UC10）逐條走查，驗證跨畫面、跨 Provider、跨資料層
（Supabase／SharedPreferences）串接後的完整行為，例如：

- 新增循環任務 → 切換今日頁不同日期 → 確認只在符合規則的日期出現。
- 建立子目標並拖曳搬移 → 確認 `sort_order` 與 `parent_id` 同步寫回 Supabase（可用 Supabase
  後台或 Network 面板核對）。
- 刪除目標 → 回收桶還原 → 確認資料與子節點關聯完整還原。
- 訪客模式操作一輪 → 登入並選擇「整合進帳號」→ 確認雲端資料與訪客時一致，且本機 `guest_*`
  key 已清除（見 DFD.md Diagram 1-A）。

### 2.4 接受度測試（Acceptance Testing / UAT）

對照 `README.md`「Expected Features」與 `docs/report.md` 的原始企劃目標，確認實作內容符合
最初提出的三層架構（Today／Semester／Future）與輔助功能（Diary／Inspiration／Feedback）目標。
建議以清單方式逐項打勾，由專案負責人（或找目標使用者：大學生）實際操作後簽核。

### 2.5 Alpha 測試

由開發者本人在功能合併／發佈前執行，範圍涵蓋當次變更所影響的所有使用案例（回歸測試最低
限度：至少手動走一次 UC1、UC3、UC4、UC7，確認核心三層功能未被破壞）。目前設定頁版本號
顯示 `alpha-1.0`（`settings_screen.dart`），代表產品現階段仍處於 Alpha 階段。

### 2.6 Beta 測試

邀請小範圍外部使用者（同學／目標族群）實際使用一段時間，透過 App 內建的「意見回饋」功能
（設定頁 → 意見回饋，寫入 D9 `feedbacks`，見 DD.md／DFD.md）匿名收集問題回報（`type = bug`）
與建議（`type = suggestion`）。因為完全匿名且無讀取介面，目前需直接查詢 Supabase 後台的
`feedbacks` 資料表整理回饋內容，尚無 App 內管理畫面。

### 2.7 黑箱測試（Black-Box Testing）

只依 system_design.md §2 的輸入輸出規格設計案例，不管內部實作。常用等價分割：

| 輸入 | 有效等價類 | 無效等價類 |
|---|---|---|
| 任務標題 | 非空字串 | 空字串／純空白（trim 後為空） |
| 密碼（註冊） | ≥ 6 字元 | < 6 字元 |
| 確認密碼 | 與密碼相同 | 與密碼不同 |
| 意見回饋內容 | 10～1000 字 | < 10 字（禁止送出）／> 1000 字（前端自動截斷） |
| 學期起訖 | 結束學期 ≥ 起始學期 | 結束學期 < 起始學期（UI 會過濾掉不合法選項，理論上無法選出無效值，仍應測試） |

### 2.8 白箱測試（White-Box Testing）

依 system_design.md §5 的程式流程圖設計案例，目標是覆蓋每一個判斷分支（分支覆蓋）：

- §5-B 循環任務判斷：至少 8 條路徑（非循環×2 + 循環的 4 種規則×每種至少 1 適用 1 不適用）。
- §5-C 防循環搬移：`draggedId == newParentId`、`newParentId = null`、目標為子孫、目標為
  非子孫的一般節點，共 4 條路徑。
- §5-E 響應式決策：寬度落在 3 個區間各至少 1 案例（另見 §2.9 極限值測試，兩者案例可共用）。

### 2.9 極限值測試（Boundary Value Testing）

| 項目 | 邊界值 | 預期行為 |
|---|---|---|
| 響應式斷點 | 767px / 768px / 1199px / 1200px | 767→手機版；768→桌面版（收合）；1199→桌面版（收合）；1200→桌面版（展開），見 system_design.md §5-E |
| 任務優先度 | 1（低）/ 3（高） | 皆為合法值，UI 只能三選一 |
| 年級推進 `computedGrade` | 推進後 < 1 或 > 7 | `clamp(1, 7)`，不應出現 0 或 8 |
| 學期制度 | `semester_count` = 2 / 4 | 2（下限）與 4（上限）皆需正確產生對應數量的起始月輸入欄 |
| 意見回饋長度 | 9 字 / 10 字 / 1000 字 / 1001 字 | 9 字禁止送出；10 字可送出；1000 字可送出；1001 字被截斷為 1000 字 |
| 意見回饋冷卻 | 第 299 秒 / 第 300 秒（5 分鐘） | 299 秒內第二次送出應被拒絕；滿 300 秒後應可送出 |
| 目標／願景樹深度 | 深度 1（僅頂層）/ 深度較深（例如 5 層子目標） | 遞迴刪除、`isAncestor` 判斷在深層節點仍需正確 |
| 循環任務「每 N 天」間隔 | `interval` = 1 | 等同每日重複，需確認未被誤判為 `daily` 類型 |

### 2.10 效能測試（Performance Testing）

本專案為個人生活管理用途，非高流量系統，效能測試著重「單一使用者資料量變大時是否仍流暢」：

| 情境 | 測試方式 | 觀察指標 |
|---|---|---|
| 大量任務（例如 500 筆） | 灌入測試資料後開啟今日頁各檢視 | 清單捲動是否掉幀、篩選對話框開啟延遲 |
| 深且寬的目標／願景樹（例如 100+ 節點） | 開啟關聯圖（分層／放射模式） | 佈局計算時間、`CustomPainter` 重繪是否掉幀（Flutter DevTools Performance 分頁量測） |
| 長期使用的日記 | 累積 1 年以上日記後開啟「我的」頁 | `_fillMissingDays()` 補齊天數計算是否有感延遲 |
| 任務完成度歷史 | 開啟每日檢視（30 根長條）與每週/每月 | 長條圖繪製與互動（hover/tap 選取）反應速度 |
| 網路延遲 | 使用瀏覽器開發者工具模擬 Slow 3G | Supabase 讀寫失敗時 UI 是否卡死（多數寫入呼叫用 `catchError((_) {})` 靜默失敗，需確認畫面狀態仍可用，不會卡在載入中） |

---

## 3. 測試計畫撰寫規定

每次測試前，複製 [test-plans/TEMPLATE.md](./test-plans/TEMPLATE.md) 到
`docs/test-plans/`，以 `YYYY-MM-DD-主題.md` 命名（例如 `2026-07-20-task-recurrence.md`），
填寫測試範圍、採用的測試類型（可勾選本文件 §1 分類）、測試案例與預期結果；測試執行後補上
實際結果與是否通過。測試計畫需保留在版本控制中，作為之後迴歸測試與問題追蹤的依據。
