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

本專案目前**沒有自動化 CI 流程**，但**已有可執行的單元測試**（`src/test/`，40 個案例，
`flutter test` 全綠）。`flutter create` 產生的預設計數器範例 `widget_test.dart` 已刪除。

單元測試只涵蓋不依賴 Supabase／SharedPreferences 的純函式；其餘部分仍以「依測試計畫手動執行
+ 記錄結果」為主。

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

工具：`flutter test`，測試檔置於 `src/test/`。**已建立 40 個案例，全部通過。**

| 測試檔 | 覆蓋範圍 |
|---|---|
| `test/recurrence_test.dart` | 五種循環規則（不循環／每日／每週／每月／每 N 天），含星期複選、每月日期複選、`kLastDayOfMonth` 的閏年與月長邊界、`interval = 0` 的防護，以及 `taskCompletionStatsOn()` 的統計 |
| `test/semester_test.dart` | `generateSemesters()`／`compareSemesters()`／`currentSemester()`／`formatSemester()`／`breakName()`，含 2／3／4 學期制與假期 token 排序 |
| `test/task_model_test.dart` | `Task` 的 JSON 往返、`copyWith` 的 sentinel 行為（含可清空 `content`）、`isCompletedOn()` 的循環／非循環分流 |

選擇標準：**只測不依賴 Supabase／SharedPreferences 的純函式**。
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
| 響應式斷點 | 767／768／1199／1200px | 767→手機；768、1199→桌面（收合）；1200→桌面（展開） |
| 循環「每 N 天」間隔 | 0／1 | 0 被夾為 1（不得崩潰）；1 等同每日 |
| 每月循環日期 | 31 號遇到 2 月 | 該月不出現；「最後一天」則落在 28／29 號 |
| 年級推進 `computedGrade` | 推進後 < 1 或 > 7 | `clamp(1, 7)` |
| 學期制度 | `semester_count` = 2／4 | 上下限皆需正確產生對應數量的起始月欄位 |
| 意見回饋長度 | 9／10／1000／1001 字 | 9 字禁止送出；1001 字截斷為 1000 |
| 意見回饋冷卻 | 第 299／300 秒 | 299 秒內拒絕；滿 300 秒可送出 |
| 目標／願景樹深度 | 深度 1／5 層 | 遞迴刪除與 `isAncestor` 在深層仍正確 |

---

## 3. 測試計畫撰寫規定

每次測試前，複製 [test-plans/TEMPLATE.md](./test-plans/TEMPLATE.md) 到
`docs/test-plans/`，以 `YYYY-MM-DD-主題.md` 命名（例如 `2026-07-20-task-recurrence.md`），
填寫測試範圍、採用的測試類型（可勾選本文件 §1 分類）、測試案例與預期結果；測試執行後補上
實際結果與是否通過。測試計畫需保留在版本控制中，作為之後迴歸測試與問題追蹤的依據。
