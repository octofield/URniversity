# 測試計畫：Phase 2 桌面小工具

> 測試方法定義請見 [../testing.md](../testing.md)；使用案例與流程圖請見
> [../system_design.md](../system_design.md)（UC14、§3-M）；
> 資料細節請見 [../DD.md](../DD.md)（D15、D14）。

## 基本資訊

- 日期：2026-09-13
- 測試人員：（開發者本人）
- 變更／功能範圍：[roadmap.md](../roadmap.md) Phase 2「② Android widget」。
  - 中等尺寸（約 4×2）小工具，左上切換「任務／目標／願景」，任務模式再切「本日／本週／本月」
  - 右上依目標或願景篩選，挑選器**依學期分組、可滑動**
  - 勾選任務完成**與通知共用同一套背景寫入**（`toggleTaskFromBackground()` + D14）
  - 顯示內容由純函式 `buildWidgetSnapshot()` 決定，原生 Kotlin 只負責渲染
- 對應章節／使用案例：UC14（新增）、§3-M（新增）、DD.md D15（新增）、D14（補寫入者）、DFD.md 1-G（新增）

## 採用的測試類型

- [x] 單元測試（新增 34 案例：`widget_snapshot_test.dart` 27 + `widget_action_test.dart` 7）
- [x] 迴歸測試（既有 193 案例必須全綠）
- [x] 邊界測試（期間範圍、空清單、已結束的學期、畸形狀態）
- [ ] 跨裝置測試（**原生小工具只能實機驗**，見案例 1 起）

## 自動化測試

| # | 指令 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|
| A1 | `cd src && flutter analyze` | `No issues found!` | No issues found | ☑ 是 |
| A2 | `cd src && flutter test` | 227 案例全綠（193 → 227） | 227/227 | ☑ 是 |
| A3 | `cd src && flutter build apk --debug` | 建置成功（新增原生 Kotlin 與 layout） | 建置成功 | ☑ 是 |
| A4 | 反向驗證：把「本週」的範圍改成 8 天 | 期間測試轉紅 | 27 個裡紅了 1 個 | ☑ 是 |

> **原生小工具的畫面完全測不到**——它跑在 launcher 的行程裡。因應方式是把「該顯示什麼」
> 全部推進 `buildWidgetSnapshot()` 測到滿，讓實機只需要驗「原生端有沒有把那些列畫對」。

## 測試案例

### 安裝與顯示

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 系統 | 長按桌面 → 小工具 → URniversity → 放上桌面 | 出現小工具，顯示今天的任務 | | ☐ 是 ☐ 否 |
| 2 | 邊界 | 今天沒有任何任務時 | 顯示「尚無任務」而不是空白一片 | | ☐ 是 ☐ 否 |
| 3 | 系統 | 有連結目標／願景的任務 | 左側有該分類顏色的色條 | | ☐ 是 ☐ 否 |
| 4 | 跨裝置 | 拉伸小工具大小 | 版面不破，列數跟著增減 | | ☐ 是 ☐ 否 |
| 5 | 迴歸 | 切成英文／日文 → 回桌面 | 列的內容跟著換語言（標籤本身維持中文，那是原生資源） | | ☐ 是 ☐ 否 |

### 模式與期間切換

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 6 | 系統 | 點「目標」 | 列出頂層學期目標，副標是學期 + 子目標完成數 | | ☐ 是 ☐ 否 |
| 7 | 系統 | 點「願景」 | 列出頂層願景，副標是子願景完成數 | | ☐ 是 ☐ 否 |
| 8 | 系統 | 目標／願景模式下 | **期間那一列與篩選鈕隱藏**（對它們沒有意義） | | ☐ 是 ☐ 否 |
| 9 | 系統 | 回到「任務」→ 點「本週」 | 列出未來七天內的任務，非今天的列副標帶日期 | | ☐ 是 ☐ 否 |
| 10 | 邊界 | ⚠️ 建一個**每日循環**任務 → 切「本月」 | 它**只佔一列**，不是每天一列 | | ☐ 是 ☐ 否 |
| 11 | 邊界 | 承上，把今天那次勾掉 | 副標變成**明天**的日期（最近一次未完成） | | ☐ 是 ☐ 否 |
| 12 | 迴歸 | 切換後**回到桌面再進來** | 停在剛才選的模式與期間（狀態有存） | | ☐ 是 ☐ 否 |

### 篩選

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 13 | 系統 | 點右上的篩選鈕 | 清單換成挑選器，**可以滑動** | | ☐ 是 ☐ 否 |
| 14 | 系統 | 看挑選器的內容 | 第一列是「全部」；目標**依學期分組**、有學期標頭；願景另起一區、不分組 | | ☐ 是 ☐ 否 |
| 15 | 邊界 | 點學期標頭那一列 | **沒有反應**（標頭是標籤不是選項） | | ☐ 是 ☐ 否 |
| 16 | 系統 | 選一個目標 | 回到任務清單，只剩連結該目標的任務；右上顯示該目標名稱 | | ☐ 是 ☐ 否 |
| 17 | 邊界 | ⚠️ 選一個**有子目標**的目標，且任務是掛在子目標下 | 那些任務**也要出現**（篩選會展開子目標） | | ☐ 是 ☐ 否 |
| 18 | 系統 | 再開挑選器 → 點「全部」 | 篩選清除，右上變回「篩選」 | | ☐ 是 ☐ 否 |
| 19 | 邊界 | 有**已結束學期**的目標時開挑選器 | 那個學期**不出現** | | ☐ 是 ☐ 否 |

### 勾選完成（**核心**）

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 20 | 系統 | ⚠️ **把 App 完全滑掉**，在小工具上勾選一個任務 | **App 不會跳出來**；該列消失或打勾 | | ☐ 是 ☐ 否 |
| 21 | 系統 | 承上 → 去 Supabase Dashboard 查該列 | 真的變成已完成 | | ☐ 是 ☐ 否 |
| 22 | 系統 | 承上 → 開 App | 任務顯示為已完成（主 isolate 有重載） | | ☐ 是 ☐ 否 |
| 23 | 邊界 | ⚠️ **關掉網路**勾選 | **下次開 App 要跳出同步失敗提示** | | ☐ 是 ☐ 否 |
| 24 | 系統 | **訪客模式**下勾選 → 開 App | 已完成（訪客走本機 `guest_tasks`） | | ☐ 是 ☐ 否 |
| 25 | 邊界 | ⚠️ **循環任務**勾掉今天那次 | 只有今天被標記；明天那次照常出現 | | ☐ 是 ☐ 否 |
| 26 | 邊界 | **App 在前景**時從小工具勾選 | 一樣不開新畫面；回到 App 後**畫面也要更新** | | ☐ 是 ☐ 否 |

### 點列開啟

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 27 | 系統 | ⚠️ **App 完全滑掉**時點一列任務的本體（不是勾選框） | App 開啟 → 跳出**該任務**的編輯 sheet | | ☐ 是 ☐ 否 |
| 28 | 系統 | 目標模式點一列 | 開 App 進**該學期目標**的詳情頁 | | ☐ 是 ☐ 否 |
| 29 | 系統 | 願景模式點一列 | 開 App 進**該願景**的詳情頁 | | ☐ 是 ☐ 否 |
| 30 | 邊界 | 點一列，但該項目**已被刪除** | 不崩潰（等不到就不導航） | | ☐ 是 ☐ 否 |

### 即時同步

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 31 | 系統 | App 開著新增一個今天到期的任務 → 回桌面 | 小工具**已經有那筆** | | ☐ 是 ☐ 否 |
| 32 | 系統 | App 內把一個任務標記完成 → 回桌面 | 小工具上該筆消失 | | ☐ 是 ☐ 否 |
| 33 | 迴歸 | 改一個分類的顏色 → 回桌面 | 色條跟著換 | | ☐ 是 ☐ 否 |

### 迴歸

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 34 | 迴歸 | 今日頁的篩選對話框 | 與改版前完全相同（篩選函式被搬到 `tasks_provider` 了） | | ☐ 是 ☐ 否 |
| 35 | 迴歸 | 通知的「標示為已完成」與「重新安排時間」 | 都還正常（寫入邏輯被抽成共用模組了） | | ☐ 是 ☐ 否 |

## 發現的問題

### F-0　小工具不出現在桌面的挑選器裡（2026-09-13，**已修**）

裝好之後長按桌面 → 小工具，清單裡**完全找不到** URniversity。

**原因**：`TaskWidgetProvider` 被註冊成 `android:exported="false"`。
`APPWIDGET_UPDATE` 是**系統行程**廣播出來的，非 exported 的 receiver 系統看不到，
於是這個 provider 等同不存在——連挑選器都不會列出它。

**同時發現第二個**：`HomeWidgetBackgroundReceiver` 根本沒有註冊。
`home_widget` 套件自己的 manifest 只宣告權限，這個 receiver 要由 App 宣告；
少了它，模式／期間／篩選那些靜默動作會全部沒有反應（而且不會有錯誤）。

**修法**（`AndroidManifest.xml`）：

- `TaskWidgetProvider` → `android:exported="true"`
- 補上 `HomeWidgetBackgroundReceiver`（`exported="true"` + BACKGROUND intent-filter）
- `WidgetActionReceiver` 維持 `exported="false"`：它只透過本 App 建立的 PendingIntent 觸發，
  而 PendingIntent 是以建立者的身分送出的，不需要對外開放
- 順帶加上 `android:previewLayout`，讓挑選器裡看得到樣子而不是一塊空白

### F-0B　顯示「無法新增小工具」（2026-09-14，**已修**）

F-0 修好之後，小工具**出現在挑選器裡了**，但按下去顯示「無法新增小工具」。

**原因**：`RemoteViews` 只能 inflate **一份固定的 view 白名單**，而 layout 裡用了兩個
不在名單上的：

| 檔案 | 用了什麼 | 改成 |
|---|---|---|
| `widget_task_list.xml` | `<Space>`（標籤與篩選鈕之間的留白） | `<FrameLayout>` |
| `widget_row.xml` | `<View>`（分類色條） | `<FrameLayout>` |

`android.view.View` 與 `Space` **都不在**白名單上。Launcher 無法 inflate 整個 layout，
就直接拒絕新增——而且錯誤訊息只說「無法新增」，不會告訴你是哪一個 view 有問題。

白名單（`RemoteViews` 的 javadoc）：`FrameLayout` / `LinearLayout` / `RelativeLayout` /
`GridLayout` / `TextView` / `ImageView` / `Button` / `ImageButton` / `ProgressBar` /
`ListView` / `GridView` / `StackView` / `ViewFlipper` / `AdapterViewFlipper` /
`AnalogClock` / `Chronometer` / `ViewStub`。

**順帶修掉**：`empty_label` 與 `ListView` 原本都是 `match_parent`，在垂直 LinearLayout 裡
會互搶空間。改成 `0dp` + `layout_weight="1"`。

### F-1　`Uri.host` 會強制小寫（2026-09-13，**已修**）

動作 URI 原本用 `urniversity://toggleDone?...`，但 `Uri.host` 解析回來是
**`toggledone`**（全小寫），背景處理的 `case 'toggleDone'` 因此永遠不會命中——
勾選框會完全沒反應，而且**不會有任何錯誤訊息**。

由 `widget_action_test.dart` 抓到。host 已全部改成小寫（`toggle`），
並在 `WidgetAction` 與 system_design.md §3-M 註明原因。

這正是那份測試存在的理由：Kotlin 端有一半的 URI 是手寫組出來的，
名稱對不上只會表現成「點了沒反應」。

### F-2　切換後閃一下又回到任務頁、內容讀不出來（2026-09-14，**已修**）

點「目標」「願景」等切換按鈕，會等一下、閃一下，然後又回到任務頁。

**log**（`adb logcat`）每次點擊都是：

```
supabase.supabase_flutter: INFO: Supabase is already initialized. Skipping reinitialization.
[widget] no signed-in session; leaving the widget as it is
```

App 裡明明有登入 session（`sb-…-auth-token` 存在）。

**原因**：`home_widget` 的 `HomeWidgetBackgroundWorker` 用的是**靜態** FlutterEngine，
會跨點擊重複使用；而 `Supabase.initialize()` **只有第一次**會從磁碟讀 session，
之後一律 `Skipping reinitialization`。那個引擎第一次跑的時候使用者**還沒登入**，
於是它在整個行程存活期間都卡在「未登入」——每次點擊都載不到資料、不存狀態、
widget 重畫回舊的任務頁。

**驗證**：`adb shell am force-stop` 清掉那個引擎後再模擬一次點擊，全新的引擎就讀得到
session、snapshot 也成功切到 `targets`。確定是「引擎卡在舊狀態」而非「讀不到 prefs」。

⚠️ **通知的背景引擎也有同樣的 bug**（`ActionBroadcastReceiver` 的 `engine` 也是 static），
「標示為已完成」在同樣情境下會一直寫入失敗。

**修法**：`ensureBackgroundSupabase()`（兩者共用）改成**每次呼叫都** `prefs.reload()`
並用磁碟上的 session 做 `recoverSession()`，回傳是否有登入；不再相信 `initialize()`
當初讀到的結果。一次修好小工具與通知兩條路徑。

「內容讀不出來」在修好後確認為**帳號本身沒有資料**：App 以完整資料推出的 snapshot
在 targets 模式同樣是 0 列，widget 正確顯示「尚無目標」（已截圖確認）。

## 結論

- [ ] 全部案例通過，可視為完成
- [ ] 部分未通過，需修正後重測（列出待修項目）

## 備註

1. **案例 23 是這份計畫最重要的一項**。它驗的是硬規則 2 在小工具這條路徑上有沒有被守住。
   與通知共用同一套機制，所以這條過了等於兩邊都過。
2. **案例 20 與 22 要一起看**。20 證明不開 App 也寫得進去，22 證明主 isolate 有發現資料被改過。
3. **如果小工具根本沒出現在挑選器裡**，先確認**裝上去的是不是新版**：
   `flutter install` **預設裝 release 版而且不會重新建置**——它會直接把
   `build/app/outputs/flutter-apk/app-release.apk` 那份舊檔裝上去（2026-09-14 實際踩到：
   裝上去的是 08-02、widget 還不存在時的版本）。用 `flutter install --debug` 或 `flutter run`。
   可以用 `adb shell dumpsys appwidget | grep urniversity` 確認系統有沒有登記到 provider。
   確認是新版之後仍然沒有，再查 `TaskWidgetProvider` 是不是 `exported="true"`（見 F-0）。
   **如果出現了但按下去說「無法新增」**，查 layout 有沒有用到 RemoteViews 白名單外的
   view（見 F-0B）——錯誤訊息不會告訴你是哪一個。
4. **如果勾選框或列完全沒反應**，依序查：
   (a) `AndroidManifest.xml` 有沒有註冊 `WidgetActionReceiver`、`WidgetListService`
       與 `HomeWidgetBackgroundReceiver`；
   (b) 模板 PendingIntent 是不是 `FLAG_MUTABLE`（`FLAG_IMMUTABLE` 會讓 fill-in intent 靜默失效）；
   (c) 動作 URI 的 host 是不是全小寫（見 F-1）。
5. **已知限制：沒有定時的雲端輪詢**。在另一台裝置改了資料，而這台的 App 完全沒開過、
   小工具也沒被點過，小工具會是舊的。這是 V1 刻意的取捨，不是 bug。
6. 小工具的**標籤文字是原生資源**（`widget_strings.xml`），固定中文，不跟著 App 語言切換。
   列的內容則是 Dart 產生的，會跟著切。這個不一致是刻意的：要讓標籤也切換，
   得在每次語言變更時重畫原生 RemoteViews，代價與收益不成比例。
