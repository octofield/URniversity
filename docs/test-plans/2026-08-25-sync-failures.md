# 測試計畫：兩個同步失敗的診斷與修正

> 測試方法定義請見 [../testing.md](../testing.md)；使用案例與流程圖請見
> [../system_design.md](../system_design.md)；資料細節請見 [../DD.md](../DD.md)。

## 基本資訊

- 日期：2026-08-25
- 測試人員：（開發者本人）
- 變更／功能範圍：實機出現兩個「同步失敗」SnackBar，診斷後是**三個互不相關**的問題：
  1. `user_categories` 結構性不相容（SQL migration，程式碼未改）
  2. PGRST303 —— Supabase 平台的 PostgREST bug（加上有限度的重試緩解）
  3. `restore()` 沒有清掉失效的參照——父節點那條由 `9e7d6a6` 的 A-3 變成可觸發，
     跨表連結那條（見 3-B）則是全表稽核才發現
- 對應章節／使用案例：§3-I、UC6、UC11、DD.md D6／D7

> ⚠️ **前提澄清**：問題 1 與 2 都不是重構造成的。階段 3 把 `catchError((_) {})` 換成會顯示的
> 錯誤，才讓它們現形。問題 3 則確實是 A-3 引入的，而 A-3 已隨 `9e7d6a6` 出去了——
> 那個 commit 單獨存在時帶著這個可觸發的 bug。

## 採用的測試類型

- [x] 單元測試（新增 22 案例，總數 47 → 69）
- [x] 系統測試
- [x] 迴歸測試
- [x] 邊界測試
- [ ] 跨裝置測試（本次改動與版面無關）

## 自動化測試

| # | 指令 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|
| A1 | `cd src && flutter analyze` | `No issues found!` | No issues found | ☑ 是 ☐ 否 |
| A2 | `cd src && flutter test` | 69 個案例全綠 | 69/69 通過 | ☑ 是 ☐ 否 |
| A3 | 逐欄探測 `user_categories` | migration 後 `name`／`order_index` 回 42703，`ordered_list`／`styles` 存在 | 如預期 | ☑ 是 ☐ 否 |

新增的兩個測試檔涵蓋：

| 檔案 | 覆蓋範圍 |
|---|---|
| `test/sync_retry_test.dart`（10） | `isTransientSyncError()` 的分類（PGRST301/303、連線例外 vs 23502/23503/42P10/42703/42501）、`runWithRetry()` 的成功／重試成功／用盡放棄／不重試 schema 錯誤／可調 maxAttempts |
| `test/restore_sanitize_test.dart`（12） | `sanitizeForRestore()` 對孤兒／有父／頂層的父節點處理、`restore()` 實際寫進 state 的結果、以及**失效的跨表連結**（`tasks.linked_target_id`／`linked_goal_id`、`semester_goals.future_goal_id`）是否被清掉 |

---

## 問題 1：分類寫入（SQL migration）

**根因**：`name` 是 NOT NULL 無預設值，且主鍵是複合鍵 `(user_id, name)` 讓
`onConflict: 'user_id'` 無效（42P10）。`user_categories` 當時 **0 列**——從來沒寫成功過。

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 系統 | 設定 → 分類設定 → 改一個分類的顏色 | 不跳同步失敗 | 通過 | ☑ 是 ☐ 否 |
| 2 | 系統 | 改一個分類的圖示 | 同上 | 通過 | ☑ 是 ☐ 否 |
| 3 | 系統 | 新增一個自訂分類 | 同上 | 通過 | ☑ 是 ☐ 否 |
| 4 | 系統 | 拖曳調整分類順序 | 同上 | 通過 | ☑ 是 ☐ 否 |
| 5 | 系統 | 完全關掉 App 再開 → 分類設定 | 上面四項變更**全都還在**（先前只存在記憶體） | 通過 | ☑ 是 ☐ 否 |
| 6 | 邊界 | Dashboard 查 `select count(*) from user_categories` | **不再是 0** | | ☐ 是 ☐ 否 |
| 7 | 迴歸 | 全 App 走一遍看分類顏色／圖示 | 目標卡片、願景卡片、關聯圖的顏色都正確 | | ☐ 是 ☐ 否 |

## 問題 2：PGRST303 與重試

**根因**：PostgREST 上游 bug（PR #5159），拒絕簽發後 100–220ms 內使用的 token。
修正版平台級推送自 2026-08-24 起。**不是裝置時鐘問題**（伺服器 `date` 標頭與手機時間相符）。

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 8 | 系統 | 登入後立刻連續操作 5 分鐘 | 不再看到 PGRST303 的 SnackBar | 通過 | ☑ 是 ☐ 否 |
| 9 | 系統 | 若仍偶發 PGRST303 | console 出現 `[sync] attempt N failed, retrying in ...ms`，**重試後自行恢復**，SnackBar 不跳 | | ☐ 是 ☐ 否 |
| 10 | 邊界 | ⚠️ **關掉網路**改一個分類顏色 | **仍然要跳同步失敗**（約 1 秒後，用盡 3 次重試），UI 不卡住 | | ☐ 是 ☐ 否 |
| 11 | 邊界 | 承上，恢復網路再改一次 | 正常寫入，不跳失敗 | | ☐ 是 ☐ 否 |
| 12 | 邊界 | 關掉網路啟動 App | 載入失敗會重試 4 次後才報錯（比寫入多一次，因為 `load()` 失敗會停掉整個 session 的寫入） | | ☐ 是 ☐ 否 |
| 13 | 迴歸 | debug 建置的 SnackBar | 顯示 `同步失敗… — code=… \| … \| details=… \| hint=…`，維持 10 秒 | 通過 | ☑ 是 ☐ 否 |

## 問題 3：還原子節點（⚠️ 順序很重要）

**根因**：`restore()` 沒有父節點檢查，但 `system_design.md` UC6 一直宣稱有。
A-3 讓子節點也進回收桶之後才變成可觸發。

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 14 | 系統 | 建父目標 + 2 個子目標 → 刪除父目標 → 回收桶 | 三個都在回收桶 | | ☐ 是 ☐ 否 |
| 15 | 邊界 | ⚠️ **先還原一個子目標**（不要先還原父目標） | 不跳同步失敗；子目標**掛回頂層**顯示 | | ☐ 是 ☐ 否 |
| 16 | 系統 | 承上 → 重開 App | 該子目標仍在（證明真的寫進雲端，沒撞外鍵） | | ☐ 是 ☐ 否 |
| 17 | 系統 | 再還原父目標與另一個子目標 | 都正常；第二個子目標同樣掛回頂層 | | ☐ 是 ☐ 否 |
| 18 | 迴歸 | 改成**先還原父目標**再還原子目標 | 子目標的父子關係**保留**（父節點還在，不觸發掛回頂層） | | ☐ 是 ☐ 否 |
| 19 | 迴歸 | 願景做一次同樣的流程 | 行為一致 | | ☐ 是 ☐ 否 |
| 20 | 迴歸 | 任務：刪除有子任務的任務 → 先還原子任務 | 子任務掛回頂層，不跳失敗 | | ☐ 是 ☐ 否 |


## 問題 3-B：失效的跨表連結（全表稽核揪出來的）

**根因**：回收桶快照保留刪除當下的所有 id。`ON DELETE SET NULL` 只改寫**當下還存在**的列，
碰不到回收桶。所以「先刪任務、之後才刪它連結的目標」會讓快照留著失效的 id，還原時撞 23503。

| # | 類型 | 操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 21 | 邊界 | 任務連結目標 G → **先刪任務** → **再刪目標 G** → 還原任務 | 不跳同步失敗；任務的目標連結被清空 | | ☐ 是 ☐ 否 |
| 22 | 系統 | 承上 → 重開 App | 任務仍在（證明真的寫進雲端） | | ☐ 是 ☐ 否 |
| 23 | 迴歸 | 任務連結目標 G → 先刪任務 → **G 仍在** → 還原任務 | 連結**保留**（不該被誤清） | | ☐ 是 ☐ 否 |
| 24 | 邊界 | 任務連結願景 V → 先刪任務 → 再刪 V → 還原任務 | 願景連結被清空，不跳失敗 | | ☐ 是 ☐ 否 |
| 25 | 邊界 | 目標連結願景 V → 先刪目標 → 再刪 V → 還原目標 | 願景連結被清空，不跳失敗 | | ☐ 是 ☐ 否 |
| 26 | 迴歸 | 一般還原（沒有任何東西被後刪） | 所有連結原封不動 | | ☐ 是 ☐ 否 |

## 發現的問題

（記錄測試中發現的 bug 或行為不符預期之處）

## 結論

- [ ] 全部案例通過，可視為完成
- [ ] 部分未通過，需修正後重測（列出待修項目）

## 備註

1. **案例 10 是最重要的迴歸**：確認重試有上限、不會把失敗吞掉。重試的價值在於救回暫時性
   失敗，但**絕不能讓真正的失敗變成靜默** —— 那正是這整串問題的起點。
2. **案例 15 的順序不能改**。先還原父節點就測不到這個 bug。
3. **全表稽核已完成**（2026-08-25）：9 張表、60 個欄位逐欄探測，全部存在（無 42703）；
   用一段把 payload 寫進 CTE 的查詢比對「NOT NULL 且無預設值」欄位，**回傳空結果**；
   主鍵全部是單欄且與 upsert 的衝突目標吻合（`user_categories`／`user_settings` 是
   `user_id`，其餘是 `id`），**沒有第二個 42P10**。
   稽核順帶揪出兩個問題，都已在本次修掉：
   - `DD.md` 把 `tasks.linked_target_id`／`linked_goal_id` 寫成「邏輯 FK」，實際是真實外鍵
   - `sanitizeForRestore()` 原本只處理 `parent_id`，漏了這三個連結欄位（見案例 21–26）
4. **舊備註（保留備查）**：`user_categories` 的問題藏了不知道多久，
   建議在 Dashboard 跑一次（唯讀），比對每張表的 `toJson()` 有無漏掉 NOT NULL 且無預設值的欄位：
   ```sql
   select c.table_name, c.column_name, c.is_nullable, c.column_default
   from information_schema.columns c
   where c.table_schema = 'public'
     and c.table_name in ('tasks','journals','inspirations','trash_items','user_settings','profiles')
     and c.is_nullable = 'NO' and c.column_default is null
   order by 1, c.ordinal_position;

   select conrelid::regclass::text as tbl, conname, pg_get_constraintdef(oid)
   from pg_constraint
   where conrelid::regclass::text in ('tasks','journals','inspirations','trash_items','user_settings','profiles')
   order by 1, 2;
   ```
5. **教訓已寫進 `docs/DD.md` D7**：靜默 catch 讓一個壞掉的寫入路徑，在文件裡被記載成
   「已修好」長達數月。
