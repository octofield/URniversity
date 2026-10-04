# 測試計畫：課表樣式、user_settings 讀取錯誤、後台入口移到側邊欄

> 測試方法定義請見 [../testing.md](../testing.md)；流程與規則請見
> [../system_design.md](../system_design.md) §1-B、§2-O、§3-I、§3-S、UC21；資料細節請見
> [../data_dictionary.md](../data_dictionary.md) D8-B、D39。

## 基本資訊

- 日期：2026-10-04
- 測試人員：（自動化部分由 Claude 執行；手動部分待填）
- 變更範圍：
  - 錯誤：`providers/synced_list_notifier.dart`（`postgrestCode()`、`readWithRetry()`）、`sync_provider.dart`、`profile_provider.dart`、`categories_provider.dart`、`courses_provider.dart`（單列讀取改經 `readWithRetry`）
  - 課表樣式：`providers/timetable_style_provider.dart`（新）、`widgets/timetable_grid.dart`、`widgets/timetable_agenda.dart`（新）、`screens/timetable_screen.dart`、`sync_provider.dart`、`supabase/timetable_style.sql`（新）
  - 後台入口：`screens/home_screen.dart`（抽屜、rail，`_RailEntry`）、`screens/settings_screen.dart`（移除）、l10n 移除 `adminEntryHint`
- 錯誤來源：後台「最近的錯誤」2026-09-28 至 10-04 共 10 筆，全部是 `user_settings … load` 的 `code=401 | {"code":"PGRST303",…,"message":"JWT issued at future"}`，網頁與 Android 都有

## 採用的測試類型

- [x] 單元測試
- [x] 系統測試
- [x] 迴歸測試（全部既有測試）
- [ ] 跨裝置測試（待手動）
- [x] 邊界測試（沒有內嵌代碼的 401、不認得的樣式名稱、淺色課程色上的字、窄寬度與深色風格）

## 測試案例

### 自動化（已執行）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 單元 | `.maybeSingle()` 形式的例外：`code: '401'`、訊息是含 `PGRST303`／`PGRST301`／`42501` 的 JSON；以及純文字的 401 | 讀回代碼；303、301 會重試；42501 與純文字 401 不重試 | 如預期（改回只看 `error.code` 會轉紅） | ☑ 是 |
| 2 | 單元 | `readWithRetry`：第一次丟出上述 401、第二次成功 | 呼叫兩次並回傳那一列 | 如預期 | ☑ 是 |
| 3 | 系統 | 管理員：手機抽屜點「後台」；1280 與 900 寬的 rail | 打開後台；rail 有文字項目／圖示 | 如預期 | ☑ 是 |
| 4 | 系統 | 非管理員開抽屜；管理員開設定頁 | 抽屜沒有後台；設定頁也沒有 | 如預期 | ☑ 是 |
| 5 | 跨裝置 | 五種樣式 × Linen／Midnight × 360／768／1280 | 沒有例外、沒有溢出；格線樣式畫出兩個微積分方塊，時間軸不畫格線 | 30 組都如預期 | ☑ 是 |
| 6 | 系統 | AppBar 調色盤選「時間軸」 | 畫成時間軸；本機 `timetable_style` = `agenda` | 如預期 | ☑ 是 |
| 7 | 系統 | 時間軸：週四 10:30、週四兩堂課；點週一、週二 | 開在週四、依時間排、微積分「上課中」；週一一堂且沒有上課中；週二「這天沒有課」 | 如預期 | ☑ 是 |
| 8 | 系統 | 時間軸 `allDays`；時間軸樣式按匯出 | 列出週一與週四、不列週二、沒有上課中；擷取當下是整週，之後回到單日 | 如預期 | ☑ 是 |
| 9 | 邊界 | 色塊樣式：深藍課程、淺黃課程 | 深藍上白字、淺黃上近黑字 | 第一版用 `estimateBrightnessForColor`，淺黃上是白字（約 2.9:1）→ 改成取 WCAG 對比較高者後如預期 | ☑ 是 |
| 10 | 邊界 | 不認得的樣式名稱、null、`paper` | standard、standard、paper | 如預期 | ☑ 是 |
| 11 | 迴歸 | `flutter analyze`、`flutter test`、l10n 數量 | 沒有問題；全部通過；三個語言檔相同 | 沒有問題；807 通過；692／692／692 | ☑ 是 |
| 12 | 系統 | `flutter build web --release`、`flutter build apk --debug` | 都成功 | 都成功 | ☑ 是 |

### 手動（待執行）

先在 Supabase 跑 `supabase/timetable_style.sql`。

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| M1 | 跨裝置 | App 放在背景一段時間後再打開（網頁與 Android） | 後台「最近的錯誤」不再出現 `user_settings … load` 的 PGRST303 | | ☐ 是 ☐ 否 |
| M2 | 跨裝置 | 五種樣式在手機與桌面、亮色與 Midnight 各看一次，並各匯出一張 | 都清楚可讀；匯出與畫面同樣式，時間軸匯出整週 | | ☐ 是 ☐ 否 |
| M3 | 跨裝置 | 在手機選「紙本」，到網頁登入同帳號 | 網頁也是紙本 | | ☐ 是 ☐ 否 |
| M4 | 系統 | 管理員與一般帳號各開側邊欄（手機抽屜、桌面 rail） | 只有管理員看到「後台」，且與「課表」對齊 | | ☐ 是 ☐ 否 |

## 發現的問題

- postgrest-dart 處理 `.maybeSingle()` 的錯誤時，在自己的 `try` 裡重新丟出，外層 `catch` 只保留 HTTP 狀態與 JSON 原文，`PGRST303` 因此從未被判為可重試；加上這些單列讀取本來就沒有經過 `runWithRetry`。兩者都已修正（見 system_design.md §3-I）。
- 色塊樣式第一版在加深後的淺色課程上放白字，對比約 2.9:1；改用 WCAG 對比挑字色。

## 結論

- [ ] 全部案例通過，可視為完成
- [x] 自動化全部通過；手動 M1–M4 待使用者執行
