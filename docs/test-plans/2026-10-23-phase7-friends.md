# 測試計畫：Phase 7-1 朋友系統——邀請、朋友清單、分享開關、朋友的課表與共同空堂

> 測試方法定義請見 [../testing.md](../testing.md)；流程與規則請見
> [../system_design.md](../system_design.md) §1、§2-P、§3-V、UC23、UC24；資料細節請見
> [../data_dictionary.md](../data_dictionary.md) D8-C、D40，與 [../data_flow_diagram.md](../data_flow_diagram.md) 1-K。

## 基本資訊

- 日期：2026-10-23
- 測試人員：（自動化部分由 Claude 執行；兩帳號與實機部分待填）
- 變更範圍：
  - SQL：`supabase/friends.sql`（`user_settings` 四欄、`friendships` 表、六個 RPC）
  - 純函式：`core/friend_code.dart`、`core/friend_failure.dart`、`core/timetable.dart`（`commonFreeSlots`、`nextSlotStart`）
  - 資料：`models/friend.dart`、`providers/friends_provider.dart`
  - 畫面：`screens/friends_screen.dart`、`screens/friend_screen.dart`、`screens/invite_accept_screen.dart`、`widgets/invite_card.dart`、`widgets/guest_login_prompt.dart`
  - 既有畫面：「我的」頁首 👥、「我的」分頁紅點（`home_screen.dart`）、課表元件可唯讀（`timetable_grid.dart`、`timetable_agenda.dart`）
  - 路由與深層連結：`/friends`、`/invite/:code`、`AndroidManifest.xml` App Link、`web/.well-known/assetlinks.json`
- 範圍外（7-2）：達成率、規劃圖。
- **這是唯一一個自動測試綠燈不足以宣告完成的階段**：權限只能用兩個真實帳號直接呼叫 Supabase 驗證（M1）。

## 採用的測試類型

- [x] 單元測試
- [x] 系統測試
- [x] 迴歸測試（全部既有測試）
- [ ] 跨裝置測試（待手動：兩支手機、手機＋網頁）
- [x] 邊界測試（易混字元、整段連結、跨中午、完全重疊、沒有交集、週末、太短的空檔、訪客、功能關閉）

## 測試案例

### 自動化（已執行）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 單元 | 邀請碼字元集；`normalizeFriendCode` 收到小寫、空白、`-`、整段邀請連結；含 0/O/1/I 的碼 | 如預期（先寫，實作前無法編譯；實作後通過） | ☑ 是 |
| 2 | 單元 | `friendFailureFrom`：RPC 回 `not_found`／`self`／`already`／`limit`／`not_allowed`、網路錯誤、其他 | 如預期 | ☑ 是 |
| 3 | 單元 | `commonFreeSlots`：台大節次、一人週三 10:20–12:10、另一人週三 15:30–17:20 | 如預期（拿掉「修到整節」會轉紅） | ☑ 是 |
| 4 | 單元 | 完全重疊（兩人整天都有課）；兩人都沒課；沒有節次表；週六有一人有課；空檔只有 30 分鐘 | 如預期；另加「不含整節的空檔」案例，抓到修整的退路寫錯（會變出 50 分鐘的假空檔），已修正 | ☑ 是 |
| 5 | 單元 | `nextSlotStart`：週三 13:20 的空堂，現在是週三 12:00、週三 14:00、週日 | 如預期 | ☑ 是 |
| 6 | 系統 | 假 `FriendsSource`：訪客開朋友頁；功能關閉 | 如預期；功能關閉時，遠端設定讀到之前會先讀一次清單（預設全開），所以只驗畫面不驗呼叫次數 | ☑ 是 |
| 7 | 系統 | 朋友頁有待回覆、已送出、朋友各一 | 如預期 | ☑ 是 |
| 8 | 系統 | 輸入 `abcd-2345`、貼整段連結、輸入 `OOOO1111`；source 回 `already` | 如預期（拿掉 normalize 會轉紅） | ☑ 是 |
| 9 | 系統 | 分享設定三個開關 | 如預期（拿掉退回會轉紅） | ☑ 是 |
| 10 | 系統 | 朋友頁：對方只開課表；全關；我沒開課表；兩人都開 | 如預期（分頁不看對方開關會轉紅） | ☑ 是 |
| 11 | 系統 | 共同空堂按「約這個時間」 | 如預期 | ☑ 是 |
| 12 | 系統 | 有一則 incoming 邀請；沒有 | 如預期（條件反過來會轉紅） | ☑ 是 |
| 13 | 系統 | 唯讀課表（朋友的）點課程與空白處 | 如預期（朋友的課表傳入點擊會轉紅） | ☑ 是 |
| 14 | 系統 | 路由：未登入開 `/invite/ABCD2345`；登入後開；開 `/friends` | 如預期 | ☑ 是 |
| 15 | 系統 | 接受畫面：自己的碼；找不到的碼；別人的碼按「送出邀請」 | 如預期 | ☑ 是 |
| 16 | 系統 | 朋友頁與朋友詳情在 360／768／1280 寬 | 如預期 | ☑ 是 |
| 17 | 迴歸 | `flutter analyze`、`flutter test`、l10n 數量 | 沒有問題；938 通過；768／768／768 | ☑ 是 |
| 18 | 系統 | `flutter build web --release`、`flutter build apk --debug` | 都成功；`assetlinks.json` 在 `build/web/.well-known/` | ☑ 是 |

### 手動（待執行；需先執行 `supabase/friends.sql`）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| M1 | 跨裝置 | 兩個測試帳號跑 `python scripts/friends_check/check.py`（見檔頭說明） | 每一條都印 PASS：成為朋友前讀不到、直接 select 他人資料 0 列、直接寫 friendships 被擋、開關關閉回空、開啟後讀得到且沒有成績／學分／老師／教室、解除後立即讀不到、錯誤碼正確 | | ☐ 是 ☐ 否 |
| M2 | 跨裝置 | 手機 A 開朋友頁的 QR，手機 B 用相機掃 | B 打開 App（已安裝）或網頁，顯示 A 的名字，按「送出邀請」 | | ☐ 是 ☐ 否 |
| M3 | 跨裝置 | A 回到 App（或下拉同步） | 「我的」分頁有紅點；朋友頁待回覆有 B；接受後雙方朋友區都有對方 | | ☐ 是 ☐ 否 |
| M4 | 跨裝置 | A 開「課表」分享，B 也開；B 點 A | B 看到 A 的課表（沒有教室與學分）與共同空堂；按「約這個時間」任務出現在 B 的清單 | | ☐ 是 ☐ 否 |
| M5 | 跨裝置 | A 解除好友 | B 下拉後朋友清單沒有 A，點舊頁面讀不到 | | ☐ 是 ☐ 否 |
| M6 | 系統 | Android：`adb shell pm get-app-links com.octofield.urniversity`；在 LINE 或訊息裡點邀請連結 | 網域顯示 verified；連結直接開 App 的接受畫面 | | ☐ 是 ☐ 否 |

## 發現的問題

- `commonFreeSlots` 修到整節時，空檔裡找不到結束的節次會退回第一節的結束，生出不存在的空堂；案例 4 的新邊界抓到後改成「沒有就不列」。
- roadmap 原文的「掃碼後接受」與 `request_friend` 建 pending 矛盾，改成碼的主人接受才成立（system_design.md §2-P、§3-V）。
- 不能自動驗證的：SQL 本身（權限、錯誤碼、欄位）只有 M1 的兩帳號腳本能證明；App Link 的驗證只有實機（M6）。

## 結論

- [ ] 全部案例通過，可視為完成
- [x] 自動化全部通過；`supabase/friends.sql` 待執行，手動 M1–M6 待使用者執行（M1 通過前不算完成）
