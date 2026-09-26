# 測試計畫：風格延伸（圖示、啟動畫面、小工具、中文字體、隨機）

> 測試方法定義請見 [../testing.md](../testing.md)；流程與規則請見
> [../system_design.md](../system_design.md) §3-R；資料細節請見 [../data_dictionary.md](../data_dictionary.md) D26、D15、D8-B。

## 基本資訊

- 日期：2026-09-26
- 測試人員：（自動化部分由 Claude 執行；手動部分待填）
- 變更範圍：
  - 素材產生：`scripts/style_assets/`（`generate.py`、`palettes.json`），產出 res 下各風格的圖示、啟動 logo、小工具 drawable 與顏色、`LaunchTheme.<Style>`
  - Android：`AndroidManifest.xml`（7 個 alias）、`MainActivity.kt`（`urniversity/style` 通道）、`WidgetStyle.kt`、`TaskWidgetProvider.kt`、`WidgetListService.kt`、兩個小工具 layout 加 `widget_root`
  - Dart：`app_styles.dart`（`cjkFontFamily`）、`app_theme.dart`（中文 fallback）、`app_style_provider.dart`（隨機）、`services/style_channel.dart`、`home_widget_service.dart`、`style_picker_sheet.dart`、`main.dart`
- 對應章節：system_design.md §3-R

## 採用的測試類型

- [x] 單元測試（隨機抽選、素材一致性、字體 fallback）
- [x] 系統測試（整個 App 選風格與隨機，攔截平台通道）
- [x] 迴歸測試（既有 584 個案例）
- [ ] 跨裝置測試（待手動：實機圖示、啟動畫面、小工具）
- [x] 邊界測試（預抽無效或重複、不認得的名稱、只有一個 alias 預設啟用）

## 測試案例

### 自動化（已執行，`flutter test`：599 passed；`flutter build apk --debug` 成功）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 單元 | `palettes.json` 對 `kStylePalettes` | 每個色值與亮暗一致（改一個色值會轉紅） | 如預期 | ☑ 是 |
| 2 | 單元 | `widget_style_colors.xml` | 6 個風格 × 6 個 role 的色值等於調色盤 | 如預期 | ☑ 是 |
| 3 | 單元 | 各風格素材 | 5 個密度的圖示、舊版圖示、啟動 logo，以及 7 種小工具 drawable 都在 | 如預期 | ☑ 是 |
| 4 | 單元 | manifest、`launch_styles.xml`、Kotlin | 每個風格都有 alias、LaunchTheme、`WidgetStyle` 分支、`MainActivity` 主題；只有暖棕預設啟用；`STYLES` 與 `AppStyle` 同序 | 如預期 | ☑ 是 |
| 5 | 單元 | `pickStyle` 排除某個風格 × 50 次 | 從不抽到被排除的 | 如預期 | ☑ 是 |
| 6 | 單元 | 隨機模式連續 50 次冷啟動 | 從不與上次相同；七種都出現 | 如預期 | ☑ 是 |
| 7 | 單元 | 冷啟動兩次 | 第二次穿的是第一次預抽的 next | 如預期 | ☑ 是 |
| 8 | 邊界 | next 缺少、與 last 相同、不認得 | 重抽，而且不等於 last | 如預期（拿掉「不重複」的條件會轉紅） | ☑ 是 |
| 9 | 單元 | 從「現代」點隨機；雲端傳來 `mono`、`random` | 立刻換成不同風格並存 `random`；兩個雲端選擇都套用 | 如預期 | ☑ 是 |
| 10 | 系統 | 手動選海洋 | 送出 `setIcon:ocean`、`setSplash:ocean`；小工具收到 `ocean` | 如預期 | ☑ 是 |
| 11 | 系統 | 設定 › 風格 › 隨機 | 選擇變成 random、風格變了；沒有 `setIcon`，`setSplash` 一次 | 如預期 | ☑ 是 |
| 12 | 單元 | `buildAppTheme` 七種風格 | 每個文字樣式都以該風格中文字體的一般檔為 fallback；粗體標籤用 `_700` | 如預期 | ☑ 是 |
| 13 | 建置 | `flutter build apk --debug`，檢查合併後的 manifest | 能編譯；`MainActivity` 沒有 LAUNCHER，7 個 alias 只有暖棕啟用 | 如預期 | ☑ 是 |

### 待手動執行（Android 實機）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 14 | 跨裝置 | 設定 › 風格 › 海洋 → 回桌面 | 幾秒內圖示變成海洋色；App 沒有被關掉 | | ☐ 是 ☐ 否 |
| 15 | 跨裝置 | 接著關掉 App 再開（Android 13+） | 系統啟動畫面是海洋色，進去後也是海洋 | | ☐ 是 ☐ 否 |
| 16 | 跨裝置 | 桌面小工具 | 立刻換成海洋的底色、新增鈕、勾選框、文字色；換回暖棕後又跟著系統深淺色 | | ☐ 是 ☐ 否 |
| 17 | 跨裝置 | 選隨機 → 完全關閉再開三次 | 每次風格不同、不與上次重複；Android 13+ 啟動畫面和進去後一致；圖示不變 | | ☐ 是 ☐ 否 |
| 18 | 跨裝置 | 七種風格的中文 | 暖棕、櫻花是文楷；現代、午夜、海洋是黑體；抹茶、極簡是宋體；第一次會先用系統字體，數秒後換上；離線時不出錯 | | ☐ 是 ☐ 否 |
| 19 | 迴歸 | 換過圖示後：點通知、點小工具的列與新增鈕、Google 登入回跳 | 都能正常開啟 App | | ☐ 是 ☐ 否 |
| 20 | 迴歸 | `flutter run` 到實機 | 仍能正常啟動與附加除錯（`tools:node="remove"` 的做法） | | ☐ 是 ☐ 否 |
| 21 | 跨裝置 | 七種風格的圖示放在桌面上看 | 圖示清楚、和風格一致 | | ☐ 是 ☐ 否 |

## 發現的問題

1. **（已修，設計調整）`activity-alias` 沒有 `theme` 屬性**：原本打算讓 Android 12 以下的啟動畫面跟著 alias 走，實際上做不到。
   改成只在 Android 13+ 經 `setSplashScreenTheme` 跟著風格；更舊的版本維持暖棕。
2. **（已修）`flutter run` 只在 `<activity>` 裡找啟動點**：把 LAUNCHER 移到 alias 會讓它找不到。
   保留在原始碼 manifest 並標 `tools:node="remove"`，合併後的 manifest 已確認只剩 alias。
3. **（已修）`RemoteViews` 沒有 `setCompoundButtonDrawable`**：改用 `setIcon(..., "setButtonIcon", Icon)`（Android 12+）。
4. **（設計取捨）不含 iOS**：換圖示要改 Xcode 專案設定，這台 Windows 無法驗證；iOS 的啟動畫面是固定的。

## 結論

- [x] 自動化案例 1–13 全部通過；`flutter test` 599 passed、`flutter analyze` 乾淨、三份 l10n 各 521 個 `@override`、debug APK 建置成功。
- [ ] 手動案例 14–21 待執行。
