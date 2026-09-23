# 測試計畫：Phase 1 通知功能

> 測試方法定義請見 [../testing.md](../testing.md)；使用案例與流程圖請見
> [../system_design.md](../system_design.md)（UC13、§3-K）；資料細節請見 [../data_dictionary.md](../data_dictionary.md)（D13）。

## 基本資訊

- 日期：2026-09-13
- 測試人員：（開發者本人）
- 變更／功能範圍：[roadmap.md](../roadmap.md) Phase 1「① 通知功能」。
  **本機通知，不含推播**——每一則提醒都從裝置上已有的資料算出來，沒有伺服器、沒有 FCM。
  - 三種提醒：任務到期前、每日摘要、學期目標截止，**各自可獨立開關**
  - 排程計算做成純函式（`core/notification_schedule.dart`），與平台層完全分離
  - 所有通知常數集中在 `core/notification_constants.dart`
  - 新增 `semesterStart()` / `semesterEnd()`，並讓 `currentSemester()` 改用前者
- 對應章節／使用案例：UC13（新增）、§3-D（擴充）、§3-K（新增）、data_dictionary.md D13（新增）、data_flow_diagram.md 1-F（新增）

## 採用的測試類型

- [x] 單元測試（新增 20 案例：`test/notification_schedule_test.dart`）
- [x] Widget 測試（新增 6 案例：`test/widget/notification_settings_test.dart`）
- [x] 迴歸測試（既有 148 案例必須全綠，特別是 16 個 semester 案例——`currentSemester()` 被改寫了）
- [x] 邊界測試（視野邊界、則數上限、提前 0 分鐘）
- [ ] 跨裝置測試（**實機才驗得到**，見下方案例 9 起）

## 自動化測試

| # | 指令 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|
| A1 | `cd src && flutter analyze` | `No issues found!` | No issues found | ☑ 是 |
| A2 | `cd src && flutter test` | 174 案例全綠（148 → 174） | 174/174 | ☑ 是 |
| A3 | 反向驗證：把 `NotificationSettings.isOn()` 的 `!enabled` 改掉 | 排程測試轉紅 | 20 個裡紅了 2 個 | ☑ 是 |

> ⚠️ A3 第一次做的時候**沒有紅**，因為 `buildNotificationSchedule()` 開頭另有一個
> `if (!settings.enabled) return const []`，和 `isOn()` 在做同一件事，其中一個永遠不會被執行到。
> 已把 early return 拿掉，讓 `isOn()` 成為唯一的判斷點，再驗一次才正確轉紅。

## 測試案例

### 基本設定（模擬器或實機都可以）

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 系統 | 設定頁 → 有「通知」入口 → 點進去 | 三種提醒都列出來，總開關預設**關閉** | | ☐ 是 ☐ 否 |
| 2 | 系統 | 打開總開關 | 跳出系統權限請求 | | ☐ 是 ☐ 否 |
| 3 | 邊界 | ⚠️ 權限**選擇拒絕** | 開關**自動彈回關閉**並顯示提示——不能宣稱已開啟卻永遠不響 | | ☐ 是 ☐ 否 |
| 4 | 系統 | 重新打開並允許 | 開關維持開啟，三個分項變成可動 | | ☐ 是 ☐ 否 |
| 5 | 迴歸 | 關掉總開關 | 三個分項一律變灰不可動 | | ☐ 是 ☐ 否 |
| 6 | 系統 | 逐一調整提前分鐘／摘要時間／提前天數 | 值有保留，顯示正確 | | ☐ 是 ☐ 否 |
| 7 | 系統 | **完全關掉 App 再開** → 回到通知設定 | 所有設定都還在（D13 存在 SharedPreferences） | | ☐ 是 ☐ 否 |
| 8 | 邊界 | **訪客模式**下設定通知 → 重開 App | 設定仍在（這正是不放 `user_settings` 的原因） | | ☐ 是 ☐ 否 |

### 實際送達（**只能實機驗證**）

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 9 | 跨裝置 | 建一個 **5 分鐘後**到期的任務，提前時間設「準時」 | 5 分鐘後收到通知，標題是任務名稱、內文是「HH:MM 到期」 | | ☐ 是 ☐ 否 |
| 10 | 跨裝置 | ⚠️ **把 App 完全關掉**再等 | 仍然收得到（排程在作業系統，不靠 App 活著） | | ☐ 是 ☐ 否 |
| 11 | 跨裝置 | ⚠️ **重開機**後等一則已排定的提醒 | 仍然收得到（靠 `RECEIVE_BOOT_COMPLETED` 與 BootReceiver） | | ☐ 是 ☐ 否 |
| 12 | 系統 | 承案例 9，在通知響之前**把任務標記完成** | **不會收到**那則通知（資料一變就整批重排） | | ☐ 是 ☐ 否 |
| 13 | 系統 | 承案例 9，在通知響之前**刪除任務** | 同樣不會收到 | | ☐ 是 ☐ 否 |
| 14 | 邊界 | 把摘要時間設成 **3 分鐘後**，且當天有任務 | 收到「今天有 N 件事要做」，N 與今日頁一致 | | ☐ 是 ☐ 否 |
| 15 | 邊界 | ⚠️ 承上，把當天任務**全部完成或刪光**再等 | **完全不會收到摘要**（空的日子整則跳過） | | ☐ 是 ☐ 否 |
| 16 | 邊界 | 只關掉「每日摘要」，留著任務提醒 | 摘要不響，任務提醒照常 | | ☐ 是 ☐ 否 |
| 17 | 跨裝置 | Android 系統設定 → App → 通知 | 看得到**三個獨立頻道**，可以只靜音其中一個 | | ☐ 是 ☐ 否 |
| 18 | 邊界 | 建立每日循環任務（設時間）→ 看排程 | 連續幾天都會響；當天標記完成後，**只有那天**不響 | | ☐ 是 ☐ 否 |
| 19 | 邊界 | ⚠️ 建 20 個每日循環任務 | 不崩潰；則數被 `maxScheduled`（48）擋住 | | ☐ 是 ☐ 否 |

### 學期目標截止（需要調整系統時間或學期設定才驗得到）

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 20 | 系統 | 把「提前天數」調到能涵蓋目前日期的值，留 2 個未完成的頂層學期目標 | 收到一則「還有 2 個目標沒完成」，**不是兩則** | | ☐ 是 ☐ 否 |
| 21 | 邊界 | 承上，加一個**子目標** | 數字**不變**（子目標不重複計算） | | ☐ 是 ☐ 否 |
| 22 | 邊界 | 把該學期目標全部標記完成 | 完全不發那一則 | | ☐ 是 ☐ 否 |

### 迴歸（`currentSemester()` 被改寫了）

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 23 | 迴歸 | 學期頁的預設學期 | 與改版前相同 | | ☐ 是 ☐ 否 |
| 24 | 迴歸 | 設定 → 學期設定改成 3／4 學期制 → 回學期頁 | 學期選單與目前學期都正確 | | ☐ 是 ☐ 否 |
| 25 | 迴歸 | 新增學期目標時的學期下拉選單 | 選項與順序都與改版前相同（假期排在對應學期之後） | | ☐ 是 ☐ 否 |

### 平台

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 26 | 跨裝置 | **Web 版**進設定 → 通知 | 顯示「這個平台不支援通知」，總開關鎖住 | | ☐ 是 ☐ 否 |
| 27 | 迴歸 | `cd src && flutter build apk --debug` | 建置成功（新增了三個外掛） | ✅ 建置成功（需先修 F-1，見下） | ☑ 是 |

## 發現的問題

### F-1　APK 建置失敗：需要 core library desugaring（2026-09-13，**已修**）

第一次 `flutter build apk --debug` 直接失敗：

```
Execution failed for task ':app:checkDebugAarMetadata'.
  1. Dependency ':flutter_local_notifications' requires core library desugaring
     for :app.
```

`flutter_local_notifications` 用 `java.time` 排程，而那是 API 26 才有的。
外掛的 minSdk 是 24，所以它要求呼叫端開啟 desugaring 來補齊舊裝置上缺的類別。
專案的 `android/app/build.gradle.kts` 先前**沒有 `dependencies` 區塊**，也沒開 desugaring。

**修法**（`android/app/build.gradle.kts`）：

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    ...
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

版本刻意與外掛自己建置時用的 `2.1.4` 對齊（見其 `android/build.gradle`）。

### F-2　Kotlin Gradle Plugin 的未來相容性警告（2026-09-13，**未處理**）

每次建置都會印，**目前不影響建置**：

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
         flutter_timezone, shared_preferences_android
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

兩件不同的事：

1. **App 自己套用 KGP**（`id("kotlin-android")`）——可以照
   [Flutter 的遷移指南](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
   改成 Built-in Kotlin。這是獨立於通知功能的建置設定變更。
2. **外掛套用 KGP**（`flutter_timezone`、`shared_preferences_android`）——**我們改不了**，
   要等外掛作者更新。`shared_preferences_android` 是本來就在用的，不是這次帶進來的。

**刻意不在這次一起處理**：這是未來版本的 Flutter 才會失敗，現在動建置設定會讓這次的變更
難以判斷是通知功能壞的還是建置設定壞的。等升 Flutter 之前再單獨做一次並完整重測。

## 結論

- [ ] 全部案例通過，可視為完成
- [ ] 部分未通過，需修正後重測（列出待修項目）

## 備註

1. **案例 3 是這份計畫最重要的一項**。權限被拒絕卻讓開關留在「開啟」，
   會讓使用者以為提醒已經設好，然後錯過所有事情——比沒有通知功能更糟。
2. **案例 10、11 是本機通知的全部價值所在**。如果 App 要活著才收得到通知，
   那這個功能等於沒做。
3. 刻意**不用精確鬧鐘**（`SCHEDULE_EXACT_ALARM`）：Android 14+ 只開放給鬧鐘與行事曆類 App，
   為了提醒準時到秒而冒著上架被拒的風險並不划算。所以通知可能會晚幾分鐘，**這是預期行為**。
4. 目前沒有「逾期提醒」。當初評估容易變成騷擾，如果實際用下來覺得需要再補。
