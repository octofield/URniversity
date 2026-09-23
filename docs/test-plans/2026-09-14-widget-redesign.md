# 測試計畫：桌面小工具改版（版面、即時切換、完成動畫）

> 測試方法定義請見 [../testing.md](../testing.md)；使用案例與流程圖請見
> [../system_design.md](../system_design.md)（UC14、§3-M）；資料細節請見 [../data_dictionary.md](../data_dictionary.md)（D15）。
> 前一版的案例與已修問題見 [2026-09-13-home-widget.md](2026-09-13-home-widget.md)。

## 基本資訊

- 日期：2026-09-14
- 測試人員：（開發者本人）
- 變更／功能範圍：實機試用後的三點回饋
  1. 版面參考 Google Tasks（依 Claude Design 設計稿）：兩排標題、**+** 依分頁新增、App 同款方框、
     沒副標的列上下置中、不再出現 `null`、跟隨系統深淺色
  2. 切換分頁／期間／篩選改由原生端處理，**不再經過 Dart 背景引擎**
  3. 勾選完成的動畫（框的轉場＋刪除線），寫入失敗時取回勾選
- 對應章節：UC14、§3-M、data_dictionary.md D15、data_flow_diagram.md 1-G

## 採用的測試類型

- [x] 單元測試（`widget_snapshot_test.dart` 26、`widget_action_test.dart` 9）
- [x] 迴歸測試（既有案例全綠）
- [x] 系統測試（模擬器實機）
- [x] 邊界測試（無副標、寫入失敗、Android 11 以下退回）
- [ ] 跨裝置測試（只有一台 API 37 模擬器；Android 11 以下的 `ImageView` 版面未實機驗）

## 自動化測試

| # | 指令 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|
| A1 | `cd src && flutter analyze` | `No issues found!` | No issues found | ☑ 是 |
| A2 | `cd src && flutter test` | 全綠（227 → 228） | 228/228 | ☑ 是 |
| A3 | `cd src && flutter build apk --debug` | 建置成功（新增 `layout-v31`、animated-vector） | 建置成功 | ☑ 是 |
| A4 | 反向驗證：拿掉 `_withAncestors()` 的上層展開 | 篩選相關測試轉紅 | 3 個轉紅，還原後全綠 | ☑ 是 |
| A5 | 反向驗證：`untickInSnapshot()` 不比對 action、全部取回 | 取回勾選的測試轉紅 | 1 個轉紅，還原後全綠 | ☑ 是 |

## 測試案例

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 系統 | 看任務分頁 | 與設計稿一致：第一排「任務 目標 願景」＋右側 + 膠囊；第二排「本日 本週 本月」＋最右「篩選 ▾」 | 一致（截圖確認） | ☑ 是 |
| 2 | 邊界 | 沒有時間的任務 | 標題**上下置中**，**沒有 `null`** | | ☐ 是 ☐ 否 |
| 3 | 系統 | 系統切換深色模式 | 小工具換成深色版配色 | `cmd uimode night yes` 後為深棕底、金色強調（截圖確認） | ☑ 是 |
| 4 | 系統 | ⚠️ 點「目標」「願景」「本週」「篩選」 | **點下去立即切換**；logcat 裡**沒有** `HomeWidgetBackgroundWorker` | 點擊後 0.4 秒截圖已切換，worker 0 筆（修 F-5 後） | ☑ 是 |
| 5 | 系統 | 目標／願景分頁 | 第二排整排隱藏 | 隱藏（截圖確認） | ☑ 是 |
| 6 | 系統 | 篩選挑選器 | 目前選中的那一列是強調色；學期標頭是小字灰色 | 「全部」與篩選鈕為強調色；此帳號無目標，學期標頭未驗 | ☐ 是 ☐ 否 |
| 7 | 系統 | 三個分頁各按一次 + | 分別開出新增任務／學期目標／願景的 sheet | | ☐ 是 ☐ 否 |
| 8 | 系統 | ⚠️ 勾選一個任務 | 框**當下**播放填滿＋打勾動畫、標題加刪除線變淡；幾秒後該列消失 | | ☐ 是 ☐ 否 |
| 9 | 系統 | 承上 → App 內查該任務 | 已完成 | | ☐ 是 ☐ 否 |
| 10 | 邊界 | ⚠️ **關網路**勾選 | 先打勾，寫入失敗後**勾選被取回**；下次開 App 跳同步失敗 | | ☐ 是 ☐ 否 |
| 11 | 邊界 | 願景分頁中已完成的願景 | 顯示已勾的框但**點了不會變**、標題沒有刪除線 | | ☐ 是 ☐ 否 |
| 12 | 迴歸 | 點列本體 | 仍開 App 進編輯 sheet／詳情頁 | | ☐ 是 ☐ 否 |

## 發現的問題

### F-3　沒有副標的列顯示 `null`（2026-09-14，**已修**）

**原因**：Kotlin 的 `JSONObject.optString(key)` 遇到 JSON null **回傳字串 `"null"`**，
不是空字串也不是 null。副標、`tap`、`check_action` 全中，後兩者還會變成指向
`Uri.parse("null")` 的點擊。

**修法**：所有字串欄位改走 `WidgetData.str()`（先 `isNull(key)` 再讀）。

### F-4　切換要等一秒多（2026-09-14，**已修**）

**原因**：每次點擊都走 WorkManager → 啟動 Flutter 背景引擎 → 查 Supabase 5 張表 →
算 snapshot → 寫回 → 重畫。只是換一份清單卻要碰網路。

**修法**：Dart 一次算好六份頁面；`WidgetActionReceiver` 直接寫 `widget_state` 並重畫。

### F-5　狀態有換、畫面卻停在第一次畫的樣子（2026-09-14，**已修**）

改版後點「任務」：`widget_state` 確實寫成 `tasks`，系統裡存的 `RemoteViews` 物件也換了，
但桌面上**永遠顯示安裝當下的那一頁**——重開 launcher 也一樣，只有重開機才會跳到最新狀態。
連 App 在前景推送的更新也一樣看不到。

**log** 每次都是：

```
AppWidgetServiceImpl: Trying to notify widget update deferred for id: 3
```

**原因**（`AppWidgetServiceImpl.java`）：清單若是用舊的 `setRemoteAdapter(Intent)` +
`RemoteViewsService` 餵資料（`isLegacyListRemoteViews()`），系統**不直接把新畫面交給 launcher**，
只通知它「有更新、自己來拿」（`updateAppWidgetDeferred`）。這台 API 37 的 Pixel launcher
收到了通知，卻從來沒有真的套用。

**修法**：Android 12+ 改用 `RemoteViews.RemoteCollectionItems`，列直接包在同一次
`updateAppWidget` 裡送出，不再經過 service。Android 11 以下維持 service（那裡沒有這個延後機制）。
列的畫法抽成 `WidgetRowViews.build()`，兩條路共用。

**驗證**：點「目標」→ 0.4 秒後截圖已是目標頁；再點「任務」→ 已切回；logcat 不再出現 deferred，
也沒有 `HomeWidgetBackgroundWorker`。

## 結論

- [ ] 全部案例通過，可視為完成
- [ ] 部分未通過，需修正後重測（列出待修項目）

## 備註

1. 案例 4 的量法：`adb logcat -c` → 點擊 → `adb logcat -d | grep -E "WidgetAction|HomeWidgetBackground"`。
2. 版面的寬高與設計稿不同是正常的：小工具的實際大小由桌面格數決定，設計稿是 360×272 的示意。
3. 字型是系統 `sans-serif-medium`，不是 App 的 Nunito：`RemoteViews` 讀不到 `google_fonts`
   在執行時下載的字型。要一致得把 Nunito 打包進 `res/font`，這次沒做。
