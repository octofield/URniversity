# 測試計畫：把可自動化的手動案例改成自動測試

> 測試方法定義請見 [../testing.md](../testing.md)；使用案例與流程圖請見
> [../system_design.md](../system_design.md)；資料細節請見 [../DD.md](../DD.md)。

## 基本資訊

- 日期：2026-09-12
- 測試人員：（開發者本人）
- 變更／功能範圍：不改動任何產品程式碼，只新增測試。四份測試計畫累積了
  **129 個手動案例從未執行**，而目標是把 App 發給同學——這些案例每次改動都要
  重跑，靠人力不可持續。本次把其中可自動化的部分轉成 widget test 與單元測試。
- 對應章節／使用案例：§3-F（響應式斷點）、UC2-B（密碼重設）、UC4（目標連結願景）

## 採用的測試類型

- [x] 單元測試（新增 10 案例：`test/trash_snapshot_test.dart`）
- [x] Widget 測試（**本專案第一次**，新增 47 案例，總數 78 → 135）
- [x] 迴歸測試（既有 78 案例必須全綠）
- [x] 邊界測試（767／768px 斷點）
- [ ] 跨裝置測試（實機行為無法在 widget test 中重現）

## 測試案例

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 單元 | `flutter test test/widget/responsive_test.dart` | 16 案例全綠 | 16/16 | ☑ 是 |
| 2 | 單元 | `flutter test test/widget/password_reset_test.dart` | 10 案例全綠 | 10/10 | ☑ 是 |
| 3 | 單元 | `flutter test test/widget/goal_link_visibility_test.dart` | 7 案例全綠 | 7/7 | ☑ 是 |
| 4 | 單元 | `flutter test test/widget/today_smoke_test.dart` | 8 案例全綠 | 8/8 | ☑ 是 |
| 5 | 單元 | `flutter test test/widget/settings_dialogs_test.dart` | 6 案例全綠 | 6/6 | ☑ 是 |
| 6 | 單元 | `flutter test test/trash_snapshot_test.dart` | 10 案例全綠 | 10/10 | ☑ 是 |
| 7 | 迴歸 | `flutter test` | 135 案例全綠，既有 78 個都沒被影響 | 135/135 | ☑ 是 |
| 8 | 迴歸 | `flutter analyze` | `No issues found!` | No issues found | ☑ 是 |
| 9 | 白箱 | ⚠️ **反向驗證**：把 `ResponsiveBody` 的 `<` 改成 `<=` | 響應式測試由綠轉紅 | 16 個裡紅了 13 個；剩下 3 個綠的正好是不使用 `ResponsiveBody` 的分頁測試 | ☑ 是 |
| 10 | 白箱 | ⚠️ **反向驗證**：把 `showSemesterGoalSheet` 的 `if (isTopLevel)` 改成 `if (true)` | 目標連結測試由綠轉紅 | 7 個裡紅了 2 個（正好是兩個「子目標不該有連結列」的案例） | ☑ 是 |
| 11 | 邊界 | widget test 在 767px 與 768px 各斷言一次 | 767 無限寬、768 有限寬 | 13 個畫面全部符合 | ☑ 是 |
| 12 | 迴歸 | 確認測試不連網 | 不得有任何 Supabase 請求 | `EmptyLocalStorage` + `detectSessionInUri: false`，執行時只印出 init 完成 | ☑ 是 |

## 發現的問題

測試過程中撞到三個陷阱，都已寫進 [../testing.md](../testing.md) §2.6：

1. **四個分頁沒有自己的 `Scaffold`**，還會呼叫 `Scaffold.of(context)`。單獨 pump
   `FutureScreen` 會炸在 `No Material widget found`。必須透過 `HomeScreen` 間接 pump。
   前三個分頁單獨 pump 時碰巧沒踩到，差點讓錯誤的測法過關。
2. **`IndexedStack` 的非選中分頁是 offstage**，`find.byType` 預設會跳過。
   四個分頁的斷言看似通過，其實只檢查到當前那一個。加 `skipOffstage: false` 才正確。
3. **`pumpApp()` 之後才能種資料**。`App` 會 watch `syncProvider`，訪客模式下它呼叫
   `loadGuest()` 把每個 Provider 的 state 從 SharedPreferences 重新載入，pump 之前
   種的資料會被洗掉。第一次寫「已完成任務」的測試就是這樣失敗的。

另外修了一個**文件**問題：[../auth-email-setup.md](../auth-email-setup.md) 第 6 步
只說了貼 Message body，沒提 Subject heading 是 Dashboard 的獨立欄位——照原文做，
信件標題會一直是 Supabase 的英文預設值。已補上三個範本對應的主旨。

## 刻意不做的事

- **不用 golden test 測視覺**。沒有可信的基準圖時，測試紅了也分不出是真的跑版
  還是基準過期，維護成本高於價值。字距、權重、顏色（18 個案例）留在手動清單。
- **不測拖曳排序**（`2026-08-23-known-issues.md` 案例 32）。`dropZoneFor()` 的
  1/4-1/2-1/4 命中判定需要真實指標座標，widget test 給不出可信的驗證。

## 結論

- [x] 全部案例通過，可視為完成

手動清單從 **129 降到 105**：

| 狀態 | 數量 | 說明 |
|---|---|---|
| 完全退役 | 24 | 標示「已自動化」，不必再手動跑 |
| 部分退役 | 18 | 標示「部分自動化」，並寫明剩下要手動確認什麼 |
| 維持手動 | 87 | 雲端持久化、信件、視覺、實機 |

比事前估的樂觀值（~55 可自動化）低。差距在於**很多案例是複合的**：
同一列既要求「清單置中」（可自動化）又要求「FAB 仍在右下角」（不可），
只能算部分退役。退役掉的那 24 個都是「每次改動都要重跑」的那種——
響應式斷點、表單驗證、條件顯示。

**長期留在手動清單的四類**：雲端持久化（「重開 App 還在」）、信件實際送達、
視覺外觀、實機平台行為（deep link、旋轉、launcher widget）。
