# 測試計畫：啟動快取＋範本帶願景

> 測試方法定義請見 [../testing.md](../testing.md)；使用案例與流程圖請見
> [../system_design.md](../system_design.md) §3-N、UC15；資料細節請見
> [../data_dictionary.md](../data_dictionary.md) D24、D11，[../data_flow_diagram.md](../data_flow_diagram.md) Diagram 1-A。

## 基本資訊

- 日期：2026-09-26
- 測試人員：（自動化部分由 Claude 執行；手動部分待填）
- 變更範圍：
  - `providers/synced_list_notifier.dart`（`cache_*` 讀寫）、`providers/sync_provider.dart`（登出刪 `cache_owner`）
  - `core/goal_templates.dart`（`TemplateVision`、新增四個範本）、`widgets/goal_template_sheet.dart`（先建願景並連結）
  - `providers/future_goals_provider.dart`（`addGoal` 回傳 id）、`screens/future_screen.dart`（✨ 入口）
- 對應章節：data_dictionary D24；system_design §3-N、UC15

## 採用的測試類型

- [x] 單元測試（快取讀寫、範本結構與字數）
- [x] 系統測試（願景頁 ✨ 套用）
- [x] 迴歸測試（既有 476 個案例）
- [ ] 跨裝置測試（待手動：實機啟動速度）
- [x] 邊界測試（別的帳號的快取、沒有網路、三語字數上限）

## 測試案例

### 自動化（已執行，`flutter test`：484 passed）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 邊界 | `cache_owner = u1` 且有 `cache_tasks`，沒有網路時 `load('u1')` | 清單顯示快取的任務 | 如預期（拿掉讀快取那行會轉紅） | ☑ 是 |
| 2 | 邊界 | 同上，但 `load('u2')` | 清單是空的 | 如預期 | ☑ 是 |
| 3 | 單元 | 登入狀態下改動清單 → `clear()` | 改動寫進 `cache_tasks` 且 `cache_owner = u1`；`clear()` 後 key 消失 | 如預期 | ☑ 是 |
| 4 | 單元 | 訪客模式新增任務 | 不寫任何 `cache_*` | 如預期 | ☑ 是 |
| 5 | 單元 | 七個範本逐一套用 | 各產生 1 個願景（起始學期＝目前學期）；頂層目標連到它，里程碑的 `futureGoalId` 是 null | 如預期 | ☑ 是 |
| 6 | 單元 | 套用研究所＋證照 | 沒分類的目標與里程碑沿用願景的 `other`；證照的競賽目標保留 `competition` | 如預期 | ☑ 是 |
| 7 | 單元 | 每個範本的目標、任務數 | 等於 `goalCount`／`taskCount`；連套兩次 id 不碰撞 | 如預期 | ☑ 是 |
| 8 | 邊界 | 三種語言的所有範本標題 | 都不是空的，也不超過 `InputLimits.title`（100） | 如預期 | ☑ 是 |
| 9 | 系統 | 願景頁點 ✨ → 套用第一個 | 願景出現在願景頁 | 如預期 | ☑ 是 |

### 待手動執行（實機，`flutter run --release`）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 10 | 跨裝置 | 登入後正常使用 → 完全關閉 App → 重新開啟 | splash 結束時任務頁就有資料，不會先空白 | | ☐ 是 ☐ 否 |
| 11 | 系統 | 登出 → 用另一個帳號登入 | 不會閃出前一個帳號的資料 | | ☐ 是 ☐ 否 |
| 12 | 系統 | 開飛航模式 → 開 App | 看得到上次的資料，並出現同步錯誤提示 | | ☐ 是 ☐ 否 |
| 13 | 系統 | 在願景頁套用「研究所推甄／考研」 | 願景頁出現願景；目標頁出現兩個已連到它的目標與里程碑；任務頁出現兩個任務 | | ☐ 是 ☐ 否 |
| 14 | 跨裝置 | 手機寬度打開範本清單（7 個） | 可以捲動到最後一個，不會溢出 | | ☐ 是 ☐ 否 |

## 發現的問題

1. **（既有行為，未變）** 第一次載入失敗時 `_userId` 會設回 null，在下一次載入成功之前的修改不會寫到雲端。
   以前失敗時畫面是空的，所以很少有人會去改；現在畫面有快取資料，比較可能有人改到。
   錯誤提示仍會出現，這次沒有修改這個行為。
2. 快取寫在 SharedPreferences，沒有加密，與訪客資料（D11）和登入 session 相同；登出時會刪除。

## 結論

- [x] 自動化案例 1–9 全部通過；`flutter test` 484 passed、`flutter analyze` 乾淨、三份 l10n 各 499 個 `@override`。
- [ ] 手動案例 10–14 待執行。
