# 測試計畫：多校課程目錄（一支腳本控制學校與學期，接上清大）

> 測試方法定義請見 [../testing.md](../testing.md)；流程與規則請見
> [../system_design.md](../system_design.md) §2-N、§3-S、UC18；資料細節請見 [../data_dictionary.md](../data_dictionary.md) D29、D32。

## 基本資訊

- 日期：2026-09-26
- 測試人員：（自動化部分由 Claude 執行；手動部分待填）
- 變更範圍：
  - 腳本：`scripts/ntu_catalog/` → `scripts/catalog/`（`fetch_catalog.py`、`common.py`、`schools.json`、`schools/ntu.py`、`schools/nthu.py`、`tests/`）
  - SQL：`supabase/course_catalog.sql`（`sessions` 欄、`catalog_schools` 表、清掉舊 id）
  - App：`course_catalog_provider.dart`（學校清單、依學校搜尋、`sessions`）、`timetable_screen.dart`（每校一個搜尋入口）、
    `catalog_search_sheet.dart`、`period_tables.dart`（清大節次、`kSchoolPeriods`）、`timetable.dart`（刪掉 `parseNtuTime`）、l10n `searchSchoolCourses`
- 對應章節：system_design.md §2-N、§3-S、UC18

## 採用的測試類型

- [x] 單元測試（Python 腳本、Dart 節次表）
- [x] 系統測試（新增課程的學校入口、搜尋加入）
- [x] 迴歸測試（全部既有測試）
- [ ] 跨裝置測試（待手動）
- [x] 邊界測試（沒有目錄、別學期、停開、暑修、只有第 10 節、讀不懂的時間）

## 測試案例

### 自動化（已執行）

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 1 | 單元 | `tests/test_common.py`：節次轉時段、id、合併、截斷、學期格式、每校都有模組與表 | 如 §3-S | 29 個 Python 測試全過（pytest 未安裝，逐一呼叫） | ☑ 是 |
| 2 | 單元 | `tests/test_ntu.py`：原本 6 個＋從 Dart 移植的時間格式；新增「四10」 | 只有第 10 節，不是第 1 節 | 如預期（移植時發現舊的 Dart 版會讀成第 1 節） | ☑ 是 |
| 3 | 單元 | `tests/test_nthu.py`：7 筆真實資料＋停開、暑修、斷開節次、沒有的學期 | 單／多教室、多老師、HTML 實體、`T7T8T9Ta` 一段、停開與暑修略過、114-2 不寫並說明 | 如預期 | ☑ 是 |
| 4 | 單元 | `period_tables_test`：`schools.json` 對 `kSchoolPeriods` | 同名、逐節一致；把清大 n 節改成 13:05 會轉紅 | 如預期（已做變異測試） | ☑ 是 |
| 5 | 系統 | 「新增課程」：使用者是清大，目錄有台大、清大（這學期）、政大（別學期） | 清大排第一、台大第二、政大不出現；搜尋只查清大；加入後時段來自 `sessions` | 如預期；拿掉排序會轉紅 | ☑ 是 |
| 6 | 邊界 | 一個學校都讀不到 | 沒有搜尋入口，「手動新增」仍在 | 如預期 | ☑ 是 |
| 7 | 系統 | 真實來源 `--school=nthu,ntu --semesters=115-1 --dry-run` | 兩校都完整 | 清大 3,043／3,043；台大 16,032／16,032 → 12,044 門 | ☑ 是 |
| 8 | 邊界 | 報表的「讀不懂的時間」與範例 | 接近 0，且範例都確實沒有固定上課時間 | 清大 2 筆（只寫「中研院」、沒有時間代碼）；台大 13 筆（只寫「第1,2,3 週」這類週次，沒有星期與節次） | ☑ 是 |

### 待手動執行

| # | 測試類型 | 輸入／操作步驟 | 預期結果 | 實際結果 | 通過？ |
|---|---|---|---|---|---|
| 9 | 系統 | 執行新的 `course_catalog.sql`；`--school=ntu,nthu` 正式寫入 | 兩校各自寫入；`catalog_schools` 有兩列、各含 115-1 | | ☐ 是 ☐ 否 |
| 10 | 系統 | 同一學期再跑一次 | 筆數不變（覆蓋、不重複） | | ☐ 是 ☐ 否 |
| 11 | 系統 | App：台大帳號打開「新增課程」 | 「搜尋台大課程」第一、「搜尋清大課程」第二 | | ☐ 是 ☐ 否 |
| 12 | 跨裝置 | 搜尋清大「微積分」加入 | 格線位置與清大節次一致；課表左側節次標籤（清大帳號）正確 | | ☐ 是 ☐ 否 |

## 發現的問題

1. **（已修）台大只有第 10 節的課會被讀成第 1 節**：舊的 Dart 正規式第一個節次只收一個字元；移到 Python 時修正並加測試。
2. **（已修）data_flow_diagram 的 Diagram 1-I 有未代換的 `""" + N + """`**：上一次產生文件的腳本留下的，本次重畫該圖時一併清掉。
3. **（限制）清大開放資料只有當學期**：要別的學期時腳本不寫並說明。

## 結論

- [x] 自動化案例 1–8 全部通過。
- [ ] 手動案例 9–12 待使用者執行 SQL 與正式寫入後進行。
