# 開發路線圖

> 這份文件記錄**接下來要做什麼、為什麼是這個順序**。
> 資料結構請見 [data_dictionary.md](./data_dictionary.md) 與 [data_flow_diagram.md](./data_flow_diagram.md)；功能行為請見
> [system_design.md](./system_design.md)；測試方法請見 [testing.md](./testing.md)。

## 目標

最終目標是把 App 發給同學實際使用，但**目前的階段是你自己先用**
（2026-09-12 的排序調整即由此而來）。

順序的判準有四條，由上而下：

1. **會不會弄丟別人的資料、把別人鎖在門外** → 最優先，沒有商量
2. **你自己現在想不想用** → 這是你的專案，這條合理，但代價要寫下來
3. **新使用者第一次打開會不會直接關掉** → 廣發給同學之前必須解決
4. **有沒有前置依賴** → 有依賴的排在被依賴的後面

⚠️ 判準 2 排在 3 前面是刻意的選擇，不是疏漏。它的具體代價寫在
[Phase 3](#phase-3新手留存)：**Phase 3 完成之前不要廣發給同學。**

---

## 進度

| 階段 | 內容 | 狀態 |
|---|---|---|
| [Phase 0](#phase-0可靠度) | 密碼重設、訪客合併、列 id 碰撞、信件管道 | ✅ 程式碼完成／網域與信件管道設定完成／⏳ 手動驗證待跑 |
| [Phase 0.5](#phase-05驗證地基) | 自動化測試 + 手動 P0 清單 | ⏳ 自動測試完成（78 → 135）／手動待跑 |
| [Phase 1](#phase-1通知) | ① 通知功能 | ✅ 程式碼完成／⏳ 實機驗證待跑 |
| [Phase 2](#phase-2android-widget) | ② Android widget | ✅ 程式碼完成／⏳ 實機驗證待跑 |
| [Phase 3](#phase-3新手留存) | ⑩ 新手教學與模板、⑨ 靈感歸檔 | ✅ 程式碼完成／⏳ SQL 待執行、手動驗證待跑 |
| [Phase 4](#phase-4回顧系統) | ⑥ 回顧系統（引導式週回顧） | ✅ 程式碼完成／⏳ SQL 待執行、手動驗證待跑 |
| [Phase 5](#phase-5課表) | ③ 課表（含台大課程目錄） | 📋 已規劃 |
| [Phase 5B](#phase-5b連結-ntu-cool) | 連結 NTU COOL，作業自動變任務 | 📋 已規劃（開工前先驗證可行性） |
| [Phase 6](#phase-6學分與-gpa) | ④ 學分與 GPA 追蹤 | 📋 已規劃 |
| [Phase 7](#phase-7朋友系統) | ⑤ 朋友系統 | 📋 已規劃 |
| — | [⑦ 時事功能](#已捨棄與延後) | ❌ 已捨棄 |
| — | [⑧ 養寵物](#已捨棄與延後) | ⏸ 延後 |

---

## Phase 0：可靠度

**為什麼第一**：發給同學之前，這三件事任何一件出錯都會直接毀掉對方的資料或帳號。

| 項目 | 先前的狀況 |
|---|---|
| 密碼重設 | **完全不存在**。忘記密碼＝帳號永久鎖死 |
| 訪客合併順序 | **與外鍵順序完全相反**。任務先於它指向的目標寫入，每一筆有連結的資料都被拒絕並遺失 |
| 列 id | 裸的毫秒時間戳。同一毫秒建立的多列共用 id，互相覆蓋 |
| 信件管道 | Resend 沙箱寄不到別人信箱；Supabase 2/hr 上限靜默擋信 |

**產出**：`reset_password_screen.dart`、`password_recovery_provider.dart`、
`SyncedListNotifier.mergeOrder()`、`newRowId()`、`supabase/email-templates/`、
[auth-email-setup.md](./auth-email-setup.md)

**未完成**（2026-09-12）：網域與信件管道已設定完成，信寄得出去，重設流程本身正常。
測試過程中發現的三件事（F-1 已結、F-2 已修、F-3 已緩解）記在
[test-plans/2026-09-05-phase0-reliability.md](./test-plans/2026-09-05-phase0-reliability.md)
的「發現的問題」。

剩下的只有**手動驗證**：該計畫的 52 個 P0 案例一個都還沒跑過。

---

## Phase 0.5：驗證地基

**為什麼在新功能之前**：238 個手動測試案例從未執行過。在沒驗證的地基上疊新功能，
之後出問題會分不清是新功能壞的還是舊的。

**已完成**：78 → 135 個自動測試，新增 widget 測試層（見 [testing.md](./testing.md) §2.6）。

**待你執行**：[test-plans/2026-09-12-manual-checklist.md](./test-plans/2026-09-12-manual-checklist.md)
的 P0 層，52 個案例，其中 **41 個現在就能跑**（不需要網域、不需要實機）。

**完成判準**：P0 全部通過。P1、P2 可以往後放，但 P0 沒跑完就發給同學，等於
拿別人的資料賭那三個 bug 真的修好了。

---

## Phase 1：通知

**內容**：① 通知功能

**⚠️ 這一項是你指定提前的**（原本排在 Phase 2）。理由與 Phase 2 相同：
**你自己要先用**。

**代價**（2026-09-12 記錄）：原本的理由是「通知需要有東西可通知」——模板讓新使用者
一開始就有截止日與循環任務，通知才有意義。現在順序反過來，表示通知只會用**你自己
手動建立的資料**驗證過。等 Phase 3 的模板產生一批資料之後，要回頭再測一次通知
（尤其是「一次產生很多筆截止日」會不會造成通知轟炸）。

**決定**：**本機通知**，Android + iOS。每一則提醒都從裝置上已有的資料算出來，
沒有伺服器、沒有 FCM。三種提醒各自可獨立開關：任務到期前、每日摘要、學期目標截止
（**不做逾期提醒**——容易變成騷擾，之後真的需要再補）。

**產出**：`core/notification_constants.dart`（常數集中一處）、
`core/notification_schedule.dart`（**純函式**排程計算，可完整單元測試）、
`services/notification_service.dart`（唯一碰 platform channel 的地方）、
`providers/notification_provider.dart`、`screens/notification_settings_screen.dart`、
`utils/semester_helpers.dart` 新增 `semesterStart()` / `semesterEnd()`。
文件：data_dictionary.md D13、data_flow_diagram.md 1-F、system_design.md UC13 與 §3-K。

**追加**（2026-09-13）：任務提醒移除內文的到期時間，改為兩顆動作按鈕——
「標示為已完成」**不開 App** 直接寫入（背景 isolate），「重新安排時間」跳進該任務的編輯頁。
見 [test-plans/2026-09-13-notification-actions.md](./test-plans/2026-09-13-notification-actions.md)。

**未完成**：實機驗證。[test-plans/2026-09-13-notifications.md](./test-plans/2026-09-13-notifications.md)
的 27 個案例，其中案例 9–19 **只能實機驗**（通知是否真的送達、App 關掉後還在不在、
重開機後還在不在）。自動測試涵蓋的是「什麼時候該響」，不是「真的響了沒有」。

---

## Phase 2：Android widget

**內容**：② Android widget

**⚠️ 這一項是你指定提前的**（原本排在 Phase 5，先前已提前到 Phase 3，
2026-09-12 再提前到 Phase 2），理由都是「我自己要先用」。

**做出來的東西**：中等尺寸（約 4×2）小工具。左上切換「任務／目標／願景」，
任務模式再切「本日／本週／本月」，右上依目標或願景篩選（挑選器**依學期分組、可滑動**）。
勾選任務完成**不開 App**，與通知共用同一套背景寫入。

**核心設計**：`buildWidgetSnapshot()`（`core/widget_snapshot.dart`）是**純函式**，
決定「該顯示哪些列」；原生 Kotlin 只認得 `WidgetRow`，**完全不知道「任務」「目標」
「篩選」是什麼**。四種畫面（任務／目標／願景／篩選挑選器）共用同一個 `ListView`。
所以整個功能的規則都能單元測試，只有「原生端有沒有畫對」需要實機。

**產出**：`core/widget_snapshot.dart`、`services/home_widget_service.dart`、
`services/home_widget_background.dart`、`services/background_task_writer.dart`
（從通知抽出來共用）、`providers/home_widget_provider.dart`，
以及原生的 `TaskWidgetProvider.kt` / `WidgetListService.kt` / `WidgetActionReceiver.kt` 與 layout。
文件：data_dictionary.md D15、data_flow_diagram.md 1-G、system_design.md UC14 與 §3-M。

**V1 的取捨**（都寫進文件了）：篩選是單選；**沒有定時的雲端輪詢**
（在另一台裝置改了資料而這台 App 完全沒開過，小工具會是舊的）；只做一種尺寸；
願景不依學期分組（它跨學期、沒有單一歸屬）。

**未完成**：實機驗證。
[test-plans/2026-09-13-home-widget.md](./test-plans/2026-09-13-home-widget.md) 的 35 個案例，
其中案例 20–26（勾選完成）與 27–30（點列開啟）**只能實機驗**。

---

## Phase 3：新手留存

**內容**：⑩ 新手使用教學與模板、⑨ 靈感歸檔

**原本排在 Phase 1，2026-09-12 因為「我自己要先用」而移到這裡。**

**代價**：同學第一次打開看到的是四個空白分頁。沒有任何東西告訴他「學期目標」
跟「未來願景」差在哪、該從哪裡開始——這是留存率最大的漏洞，而它現在要等到
Phase 3 才補。

所以這條要記住：**在 Phase 3 完成之前把 App 發給同學，就要接受開場是空白畫面。**
如果只是給你自己和幾個會當面被你教的人用，這個代價可以接受；
要廣發之前，Phase 3 必須先做完。

**為什麼兩個一起做**：靈感歸檔是小改動（`inspirations` 加一個狀態欄位），
而模板需要**批次建立資料**——那正好是 Phase 0 修掉的 id 碰撞最會發作的場景。
兩個一起做可以共用一次測試計畫。

**預期會碰到**：

| 面向 | 影響 |
|---|---|
| 資料 | `inspirations` 新增歸檔欄位（data_dictionary.md D4、data_flow_diagram.md 要同步）；模板本身可能不需要新資料表，直接批次呼叫既有的 `addGoal`／`add` |
| 行為 | system_design.md 新增使用案例（首次使用引導、套用模板、歸檔靈感）；§2 輸入輸出格式 |
| l10n | 四個檔案（`app_strings.dart` + 三個實作）。模板內容本身要不要在地化是個待決定的問題 |
| 測試 | 新測試計畫；模板的批次建立適合寫成單元測試（驗證 N 筆資料的 id 全不相同）。**做完要回頭重測 Phase 1 的通知**（見上方代價） |

**已決定**（2026-09-25 開工前問過）：模板是**一鍵建立一整組目標**（寫進使用者自己的真實資料，
之後可任意編輯／刪除，不是唯讀範例）；新手教學是**逐步導覽（coach mark）**，不是一次性說明頁。

**產出**（2026-09-25）：`core/goal_templates.dart`（三個範本，內容走 l10n）、
`widgets/goal_template_sheet.dart`（`applyGoalTemplate()` + 挑選 sheet）、
`widgets/coach_mark.dart`（聚光燈導覽元件）、`providers/onboarding_provider.dart`、
`supabase/inspiration_archive.sql`。
文件：data_dictionary.md D4／D22、data_flow_diagram.md Diagram 1-B／1-C、
system_design.md §2-L／§3-N／§3-O／UC15／UC16。
自動測試 395 → 417。

**導覽重做**（2026-09-25，同日）：第一版只有 5 步、只指向導覽列與新增鈕，你評為太粗糙。
改成**每個分頁一章、第一次進到該分頁才播放**，而且是**親手操作**：光圈打在真的＋上、跟進真的
sheet 逐欄標示，使用者按下「新增」才前進（關掉沒存就倒回）。設定頁有常駐的「新手指南」可重播
任何一章。新增 `screens/home_tour.dart`（四章內容）、`widgets/tour_guide_sheet.dart`；
`coach_mark.dart` 改寫為錨點＋路由感知的引擎；D22 由 `onboarding_seen`（bool）改為
`onboarding_done`（每章一個 id）。卡片位置為響應式（手機上下、寬螢幕貼在目標旁邊）。自動測試 417 → 444。
**代價**：重播章節時新增的內容會真的存下來（指南頁有註明）；鍵盤、返回手勢、螢幕報讀
這幾類行為只能實機驗（見測試計畫）。

**未完成**：[test-plans/2026-09-25-phase3-onboarding-chapters.md](./test-plans/2026-09-25-phase3-onboarding-chapters.md)
的手動案例（導覽）；以及 [test-plans/2026-09-25-phase3-onboarding-templates.md](./test-plans/2026-09-25-phase3-onboarding-templates.md)
的手動案例 21–24、27–33（封存、範本、通知），其中：
- **前置作業 P1**：`supabase/inspiration_archive.sql` 要在 Supabase SQL 編輯器手動跑過，
  否則登入帳號封存靈感會寫入失敗。
- 案例 31–33 就是上面那筆**通知的欠款**（範本產生一批資料後回頭重測 Phase 1）。

---

## Phase 4–7 的共同決定（2026-09-25）

這一段與以下各階段由 2026-09-25 的詳細規劃整理而來，參考了下方「參考資料」的網路資源。
執行順序：**4 → 5 → 5B → 6 → 7**。

| 決定 | 選擇 |
|---|---|
| Phase 4 回顧形式 | **引導式週回顧**（數據 → 三個提問 → 規劃下週），每次存成一筆紀錄；月底、學期末用同一流程 |
| Phase 5／6 資料 | **一門課一筆**（`courses`）＋底下的上課時段（`course_sessions`）；匯入一次，課表與 GPA 都有 |
| Phase 7 分享 | **三個分項開關**（規劃圖／達成率／課表，對所有朋友一致，預設全關）＋**邀請連結／QR code** |
| NTU COOL | **列入，延伸階段 5B** |

**研究後修正的兩個關鍵設計**（與先前計劃不同之處）：

1. **5B 不能用存取權杖**：NTU COOL 不開放學生建立 Canvas 個人 Access Token（設定頁沒有「已核准的整合」）。
   改用 Canvas 為每位使用者提供的**個人行事曆訂閱網址（.ics）**——不需登入、不需權杖，內含作業截止日。
2. **Phase 7 不改核心資料表的 RLS**：先前計劃要 `DROP` 並重寫 tasks／semester_goals 等表的 SELECT 政策，但那些政策
   從未進版控、名稱未知，是整份計劃風險最高的一步。改成朋友只能透過幾個 **security definer RPC** 讀取「對方開啟分享」
   的資料，而且只回傳需要的欄位（例如分享達成率時**不回傳任務標題**）。核心表維持「只能讀自己的」。

**研究後修正的兩個關鍵設計**（與先前計劃不同之處）：

1. **5B 不能用存取權杖**：NTU COOL 不開放學生建立 Canvas 個人 Access Token（設定頁沒有「已核准的整合」）。
   改用 Canvas 為每位使用者提供的**個人行事曆訂閱網址（.ics）**——不需登入、不需權杖，內含作業截止日。
2. **Phase 7 不改核心資料表的 RLS**：先前計劃要 `DROP` 並重寫 tasks／semester_goals 等表的 SELECT 政策，但那些政策
   從未進版控、名稱未知，是整份計劃風險最高的一步。改成朋友只能透過幾個 **security definer RPC** 讀取「對方開啟分享」
   的資料，而且只回傳需要的欄位（例如分享達成率時**不回傳任務標題**）。核心表維持「只能讀自己的」。

### 共同紀律（每階段都適用）

- 新的清單型 Provider 繼承 `providers/synced_list_notifier.dart` 的 `SyncedListNotifier<T>`；新增欄位要同步
  `core/input_limits.dart` 與 `supabase/input_length_limits.sql`（`SheetTextField` 必填 `maxLength`）。
- 每張新表：新增 `supabase/<table>.sql`（CREATE TABLE＋RLS＋CHECK，仿 `supabase/feedback_table.sql`），
  `user_id` 為 **text**（data_dictionary D0／D1 已確認），owner 政策 `auth.uid()::text = user_id`。
  你手動在 SQL 編輯器執行；**執行前先到 Dashboard 核對既有表的型別**。
- 訪客模式：新 local key 加進 `guest_provider.dart` 的 `_dataKeys`；`sync_provider.dart` 的載入序列（:70-78、:107-115）
  與合併序列（:94-99，**父先於子**）都要加。
- l10n 四檔同步（`grep -c "@override" src/lib/l10n/strings_*.dart` 三者一致），用 `l10n-extract` skill。
- 文件同一次改完：data_dictionary／data_flow_diagram（持久化資料）、system_design（畫面、演算法、UC、Mermaid）、
  testing.md、roadmap.md；每階段一份 `docs/test-plans/YYYY-MM-DD-phaseN-*.md`。
- 新增的每個畫面：若會被新手導覽介紹，放 `TourAnchor`，並在 `screens/home_tour.dart` 補步驟（引擎：`widgets/coach_mark.dart`）。
- 純函式優先（放 `core/`），畫面只做組裝——這是既有 `history_stats.dart`、`notification_schedule.dart`、
  `widget_snapshot.dart` 可以完整單元測試的原因，新功能照做。

### 風險與需要你確認的事

1. **台大課程網的抓取方式**要在 Phase 5 動工時對照網站現況；腳本每學期手動跑一次、低頻率，避免對學校伺服器造成負擔。
2. **5B 的前提**（COOL 有行事曆訂閱、未登入可下載）若不成立，5B 整段取消，不影響其他階段。
3. **非台大學校**：沒有節次表與課程目錄，課表以時間軸手動新增、GPA 用同一套等第（文件註明各校可能不同）。
4. 上課提醒與既有提醒共享通知上限（iOS 最多 64 則待送），計劃中課程提醒只排未來 7 天、最多 20 則。
5. Phase 7 的邀請連結網域用現有的 `urniversity.netlify.app`；若之後換網域，App Link 與 assetlinks 要一起改。

### 參考資料

- 台大〈等第制成績定義與等第績分表〉與〈GPA 單向轉換為百分制對照表〉：aca.ntu.edu.tw（教務處註冊組）
- 台大節次代號與上課時間：cge.ntu.edu.tw 課程節次代號對照表
- Sunsama Weekly Review（help.sunsama.com/docs/weekly-review）；Habitify 熱度圖（beyondtime.ai 評測）
- 學生課表 App 做法：下一堂一眼可見、小工具、可調提醒（Timetable Widget、Smart Timetable）
- NTU COOL 不支援個人 Access Token：github.com/huan131513/ntucool-deadline-tracker；Canvas 行事曆訂閱：github.com/0104venn-ctrl/canvas-planner
- Supabase RLS 與 security definer 函式、效能建議：supabase.com/docs/guides/database/postgres/row-level-security、RLS Performance and Best Practices
- Strava 分項隱私控制：support.strava.com Privacy Controls

---

## Phase 4：回顧系統

**為什麼排這裡**：回顧需要累積幾週的資料才有東西可回顧；排在通知、widget 與新手導覽之後，使用者已經用了一段時間。
**形式（2026-09-25 決定）**：引導式週回顧——數據 → 三個提問 → 規劃下週，每次存成一筆紀錄。

**產出（2026-09-25）**：`core/review_stats.dart`（純函式）、`models/review.dart`、`providers/reviews_provider.dart`、
`screens/review_screen.dart`、`screens/reviews_screen.dart`、`widgets/review_prompt.dart`（回顧卡＋本週專注）、
`widgets/review_heatmap.dart`、`supabase/reviews_table.sql`；通知新增第四種「每週回顧」。
文件：data_dictionary D23、D11、D13；data_flow_diagram Diagram 1-H；system_design §2-M、§3-P、UC17。
自動測試 444 → 473。

**與計劃不同之處**：
- 提醒的星期**固定為週日**，只能調時刻——回顧卡從週日 18:00 出現，讓使用者另選星期會讓通知和卡片對不上。
- 學期回顧的時段以 `semesterEnd()` 推算（包含寒暑假），要等 Phase 5 的 `catalog_terms` 才知道真正的最後上課日。
- 回顧卡在 App 開著時跨過週日 18:00 不會自己跳出來，要等下一次畫面更新（例如切換分頁或重新打開）；
  20:00 的通知會把人帶進去，所以不另外加計時器。

**未完成**：`supabase/reviews_table.sql` 要在 SQL 編輯器手動執行；手動案例見
[test-plans/2026-09-25-phase4-review.md](./test-plans/2026-09-25-phase4-review.md)。


**目標**：每週花 3 分鐘，看見這週做了什麼、想一下、把下週安排好。參考 Sunsama 的 Weekly Review（本週回顧 → 反思 → 未完成的挪走 → 設定下週目標）與 Habitify 的熱度圖。

### 4.1 使用流程（UC17）

1. **提醒**：週日 20:00 通知「本週回顧・3 分鐘」（可在通知設定關閉或改時間）；同時「任務」分頁頂端出現一張回顧卡，
   **從週日 18:00 顯示到週二結束**，完成後消失。月初前三天出現「上月回顧」，學期最後兩週到下學期第一週出現「學期回顧」。
2. **① 這週的數字**（全部自動算，不用填）
   - 完成 23／30・77%，較上週 ↑13%（`totalsBetween`、`rateBetween`）
   - 連續全勤 4 天（`allDoneStreak`）、最順的一天（`bestWeekday`）
   - **近 12 週熱度圖**（每天一格，顏色深淺＝完成率；新增的純函式 `dailyRates`）
   - 每個頂層學期目標這週的推進：完成了幾個里程碑、做了幾個掛在它底下的任務（新增 `targetProgressBetween`）
   - 本週寫了幾篇日記（`JournalNotifier.isWrittenByUser`）
   - Phase 6 上線後，學期回顧多一行本學期 GPA
3. **② 想一想**：三格，各 ≤500 字、都可留空——「做得好的」「卡住的」「下週最重要的一件事」。
   每格下方有一行灰字的引導範例（例如「哪件事比預期順利？為什麼？」），降低空白頁壓力。
4. **③ 安排下週**
   - 列出**這週到期但沒完成的非循環任務**，預設全勾，按「挪到下週」→ 截止日各 +7 天（保留時刻）；也可以逐一取消勾選。
   - 從本學期頂層目標選 **最多 3 個「下週專注」**。
5. 按「完成回顧」→ 存成一筆 review → 回到任務頁，SnackBar「回顧已存」。
6. **下週專注的回饋**：任務頁完成度卡下方出現一列「本週專注：多益 800・專題」chip，點了套用該目標的篩選（重用既有 `taskTargetFilterProvider`）。
7. **回顧紀錄**：「我的」頁新增「回顧」區塊（日記區上方），列出歷次回顧（時間軸）；點開看當時的數字快照與三段文字；可刪除（`confirmDelete`）。完成度頁（`TaskHistoryScreen`）頂端也放「回顧紀錄」入口。

### 4.2 資料

新表 `reviews`（`supabase/reviews_table.sql`，data_dictionary **D23**）：

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | text PK | `newRowId()` |
| `user_id` | text | |
| `period` | text | `week`／`month`／`semester`（CHECK） |
| `period_start`、`period_end` | date | 週一～週日；月初～月底；學期起訖 |
| `went_well`、`stuck`、`next_focus` | text | 各 ≤500（CHECK，`InputLimits.body`） |
| `focus_target_ids` | text[] | ≤3，**不是外鍵**（目標被刪就在顯示時略過） |
| `stats` | jsonb | 當下的數字快照（完成數、總數、完成率、連續天數、各目標推進、日記數）——之後任務被改，歷史回顧不跟著變 |
| `created_at` | timestamptz | |

唯一性：同一使用者同一 `period`＋`period_start` 只能一筆（UNIQUE）；重做回顧＝更新同一筆。

### 4.3 程式

- `core/review_stats.dart`（純函式）：`dailyRates(tasks, from, to)`、`targetProgressBetween(goals, tasks, from, to)`、
  `reviewWindow(period, now, semesterSettings)`（回傳該顯示哪一種回顧與它的起訖）、`carryOverCandidates(tasks, from, to)`、
  `buildReviewStats(...)`（組 `stats` 快照）。
- `models/review.dart`、`providers/reviews_provider.dart`（`ReviewsNotifier extends SyncedListNotifier<Review>`，
  `localKey: 'guest_reviews'`，依 `period_start` 新到舊）；`dueReviewProvider`（把 `reviewWindow` 與既有紀錄比對，決定要不要顯示回顧卡）。
- `screens/review_screen.dart`（三步驟，`PageView`＋底部「上一步／下一步」，每步可獨立捲動）；`widgets/review_heatmap.dart`；
  `screens/reviews_screen.dart`（紀錄列表）。
- 通知：`NotificationKind.weeklyReview`（`models/notification_settings.dart` 加 `weeklyReviewEnabled`、`weeklyReviewWeekday`、
  `weeklyReviewMinuteOfDay`）、`notification_schedule.dart` 新 builder（id 基底 700000，只排未來 2 次）、
  `notification_service.dart` 新 channel；`notification_settings_screen.dart` 加一列。通知 payload 點開直接進 `ReviewScreen`
  （重用既有 `pendingOpenProvider` 路徑）。
- 挪到下週：`TasksNotifier.update(task.copyWith(dueTime: +7 天))`，一次批次。

### 4.4 導覽

「我的」章加一站：指向「回顧」區塊（`info`）。第一次出現回顧卡時不額外導覽——卡片本身寫清楚「3 分鐘回顧這週」。

### 4.5 測試

- 單元：`review_stats_test.dart`——週界（週一 00:00 起）、跨月週、`dailyRates` 無任務日回 null、`carryOverCandidates` 排除循環任務與已完成、
  `reviewWindow` 在週日 17:59／18:00、週二 23:59／週三 00:00 的邊界、學期回顧窗。
- Widget：回顧卡只在窗內出現、完成後消失；三步驟走完寫入一筆且 `stats` 有值；「挪到下週」只動勾選的任務；
  下週專注 chip 出現且點了套用篩選；同一週重做是更新不是新增。
- 通知排程：`notification_schedule_test.dart` 加「每週回顧只排兩次、關閉後不排」。

### 完成判準

- `reviews_table.sql` 已執行；登入帳號完成一次週回顧、重新整理後紀錄仍在。
- 自動測試全綠、零回歸；文件（D23、DFD、system_design §2／§3／UC17）同步。
- 手動：真的在週日晚上收到通知並從通知進入回顧；訪客做的回顧在合併帳號後保留。

---

## Phase 5：課表

**為什麼排這裡**：獨立的新資料表，不依賴前面任何一階段；但它**被** Phase 6 與 Phase 7 依賴，所以不能更晚。
**資料（2026-09-25 決定）**：一門課一筆＋底下的上課時段，匯入一次，課表與 GPA 都有。


**目標**：打開 App 就知道**下一堂是什麼、在哪、幾點**；加課只要搜尋課名點一下。參考學生課表 App 的共通做法：
下一堂課一眼可見、首頁小工具、上課前 5–60 分鐘可調提醒、畫面不要塞滿整張大表。

### 5.1 使用流程（UC18）

1. **任務頁「今天的課」**：當天有課時，完成度卡上方出現一列時間軸 chip——「10:20 微積分・新數102」；
   **正在上的課加粗、下一堂標「下一堂」**，已經上完的變淡。沒課的日子不顯示這列（不佔空間）。
2. **完整課表**：目標頁頁首新增 📅 → `TimetableScreen`：
   - 週一～週五欄（有週末的課才多出六、日）；左側時間軸——學校是台大時顯示**節次**（「3｜10:20」），其他學校顯示整點。
   - 色塊依課程顏色；目前時刻一條紅線；頁首顯示「第 5 週」（由開學日推算，見 5.3）。
   - 點空白格：以該星期與時段開「新增課程」；點色塊：開課程詳情 sheet（編輯、刪除、看所有時段）。
   - 上方學期切換重用 `selectedSemesterProvider` 與既有學期挑選器。
3. **新增課程的兩種方式**：
   - **搜尋台大課程**（預設入口）：輸入課名／老師／課號／流水號，結果顯示「一34 三34・4 學分・王老師・新數102」；
     與已有課程**衝堂**會標紅字「與 微積分 衝堂」（仍可加）。點選 → 一次建立課程與所有時段。
   - **手動新增**：課名、老師（選填）、學分、顏色、上課時段清單（每列：星期＋節次範圍〔台大〕或起訖時間＋教室，可加多列）。
4. **上課提醒**：通知設定新增「上課前提醒」（關／5／10／15／30 分鐘，預設 10），只在該學期的上課週內（開學日～第 N 週），寒暑假不響。
5. **桌面小工具**：新增「課表」分頁，顯示今天剩下的課（全部上完則顯示明天的課）。

### 5.2 資料

| 表 | 欄位 |
|---|---|
| `courses`（D24） | `id`、`user_id`、`semester`（`114-1`）、`title`（≤100）、`course_code`、`serial_no`、`teacher`（≤50）、`credits` numeric(3,1) ≥0、`grade` text（Phase 6）、`counts_in_gpa` bool 預設 true、`color` int、`catalog_id`（來源，非外鍵）、`created_at` |
| `course_sessions`（D25） | `id`、`user_id`、`course_id` → `courses(id)` **ON DELETE CASCADE**、`weekday` 1–7、`start_minute` 0–1439、`end_minute`（> start，≤1440）、`location`（≤50） |
| `course_catalog`（D26，公開唯讀） | `id`（`課號_學期_流水號`）、`school`、`semester`、`serial_no`、`course_code`、`title`、`teacher`、`credits`、`department`、`required`（必／選／通識）、`sessions` jsonb、`time_text`（原始「一34(新數102)」字串，供顯示） |
| `catalog_terms`（D27，公開唯讀） | `school`、`semester`、`first_day` date、`weeks` int——由離線腳本依台大行事曆寫入，決定「第幾週」與提醒期間 |

- `course_catalog`／`catalog_terms`：RLS 只開 `SELECT TO anon, authenticated`；寫入只經 Dashboard／service role。
  `course_catalog` 對 `title`、`teacher` 建 `pg_trgm` GIN 索引（`ilike` 搜尋上萬筆仍即時）。
- **非台大學校**沒有 `catalog_terms`：第一次開課表時問一次「這學期哪天開學？」，存到 `user_settings.term_start_dates`（jsonb，D8-B 加欄位）；`weeks` 預設 18。
- 刪除課程：進回收桶——`TrashItemType.course`，`item_data` 內含該課所有時段，還原時一起建回（`trash_item.dart` 的四處分支照既有模式）。

### 5.3 程式

- `core/period_tables.dart`：**台大節次表**（官方：0 07:10–08:00、1 08:10–09:00、2 09:10–10:00、3 10:20–11:10、4 11:20–12:10、
  5 12:20–13:10、6 13:20–14:10、7 14:20–15:10、8 15:30–16:20、9 16:30–17:20、10 17:30–18:20、A 18:25–19:15、B 19:20–20:10、
  C 20:15–21:05、D 21:10–22:00），以學校名稱為 key；`periodsFor(school)`、`periodLabelAt(school, minute)`。
- `core/timetable.dart`（純函式）：`sessionsOn(date, courses, sessions, term)`、`currentAndNext(now, ...)`、`conflicts(newSessions, existing)`、
  `weekOfTerm(date, term)`、`gridLayout(sessions, ...)`（分鐘→座標，週末欄是否出現、時間軸起訖）、`parseNtuTime('一34(新數102) 三34')`（App 端也保留一份，供手動貼上）。
- Model／Provider：`models/course.dart`、`models/course_session.dart`、`providers/courses_provider.dart`（兩個 `SyncedListNotifier`；
  合併序列 **courses 先於 sessions**；sessions 的 `sanitizeForRestore` 丟棄課程已不存在的時段）；
  `providers/course_catalog_provider.dart`（`FutureProvider.family` 搜尋，不繼承 SyncedListNotifier，訪客也能查）；`termProvider(semester)`。
- 畫面：`screens/timetable_screen.dart`、`widgets/timetable_grid.dart`（`Stack`＋`Positioned`，**不用 `IntrinsicHeight`**——既有教訓）、
  `widgets/today_classes_strip.dart`（任務頁）、`widgets/course_sheet.dart`（手動新增／編輯，狀態宣告在 builder 外）、
  `widgets/catalog_search_sheet.dart`（輸入 300ms debounce）。
- 通知：`NotificationKind.classStart`、id 基底 800000；**只排未來 7 天、最多 20 則**，與既有總上限 48 分配（iOS 最多 64 則待送通知）。
- 小工具：`core/widget_snapshot.dart` 加 `WidgetMode.classes` 與 view `classes_today`；Kotlin 端 `TaskWidgetProvider.kt` 多一個分頁標籤（兩個 layout 同步）。
- **離線腳本** `scripts/ntu_catalog/`（Python）：抓台大課程網公開查詢結果 → 解析時間教室字串為 `sessions` → 依 `InputLimits` 截斷 →
  寫 `course_catalog` 與 `catalog_terms`（service role key 只放在你本機的 `.env`，不進 repo）。附 `pytest` 測解析器、`README.md` 寫每學期操作步驟。
  **每學期手動跑一次、低頻率**；確切的網址與欄位在動工當下對照網站現況確認。

### 5.4 導覽

學期章加兩站：指向頁首 📅（`open` → 課表頁，`close` 指向格線＋「回去」）。任務章在「今天的課」出現時（`when` 有課）加一站 `info`。

### 5.5 測試

- 單元：節次表與官方表逐節比對；`parseNtuTime` 各種格式（單節、多節、多天、無教室、節次含 A–D）；`conflicts`；`weekOfTerm` 邊界；
  `currentAndNext` 在上課中、下課間、當天全結束；`gridLayout` 週末欄出現與否；上課提醒只在上課週內、不超過 20 則。
- Widget：從搜尋結果加課 → 課與時段都建立、衝堂提示；手動新增多時段；刪課進回收桶並能連時段一起還原；「今天的課」依時間標示下一堂。
- 腳本：`pytest` 用存下來的網頁片段當 fixture。

### 完成判準

- 四個 `.sql` 已執行；腳本已上傳當學期台大資料；登入帳號搜尋「微積分」能加課，重整後課表仍在。
- 真機：上課前 10 分鐘收到提醒；小工具「課表」分頁顯示今天的課。
- 自動測試全綠；文件（D24–D27、D8-B、DFD 新圖「課表」、system_design §1-B 新邊、§2、§3 時間軸與衝堂演算法、UC18）同步。

---

## Phase 5B：連結 NTU COOL

**為什麼排這裡**：2026-09-25 新增的延伸階段。只依賴既有的任務，和 Phase 5 同屬「學期與課」的情境，所以緊接在後。


**目標**：作業截止日不用自己抄。原理：NTU COOL（Canvas）行事曆的「行事曆訂閱」網址（.ics），內含你所有課的作業與截止時間；貼一次網址，之後自動同步。

### 5B.0 開工前的驗證（不通過就整段取消）

1. 用你的帳號在 NTU COOL「行事曆」頁找「行事曆訂閱／Calendar Feed」，確認有此功能且未登入也能下載 .ics。
2. 確認 feed 內作業事件的 `UID` 格式（Canvas 通常為 `event-assignment-<id>`）、`DTSTART` 即截止時間、`SUMMARY` 帶課名。
3. 確認 `cool.ntu.edu.tw` 的 .ics 回應沒有 CORS 標頭（預期沒有）→ Web 版需要代理。

### 5B.1 使用流程（UC19）

1. 設定 → 「連結 NTU COOL」：三步驟圖文說明（到 COOL → 行事曆 → 複製訂閱網址）＋一個貼上欄位。
2. 貼上後立即試抓：「找到 12 個作業，其中 9 個還沒到期」→ 按「開始同步」。
3. 同步規則：
   - 每個作業成為一個任務：標題＝作業名，內容＝「課名・COOL 連結」，截止時間＝作業截止。
   - 任務 id 固定為 `cool_<作業id>`：重複同步**不會重複建立**；截止時間或標題在 COOL 改了會更新（使用者已勾完成的不動）。
   - **永不刪除**：COOL 上移除的作業留在 App 裡。使用者自己刪掉的作業記在本機 `cool_dismissed`，之後不再建回。
   - 時機：開 App、下拉重新整理、距上次同步超過 30 分鐘時；設定頁有「立即同步」與上次同步時間。
4. 因為變成一般任務：截止前提醒、小工具、回顧統計全部自動適用。
5. 失效處理：網址失效（404／403）→ 任務頁頂端一條提示「NTU COOL 連結失效，請重新貼上」。
6. 「中斷連結」：刪除網址與同步狀態；已匯入的任務保留（可選「一併刪除未完成的 COOL 任務」）。

### 5B.2 資料與安全

- **訂閱網址等同密碼**（任何人拿到都能看到你的行事曆）：只存在**裝置本機**（`cool_feed_url`，D28），不上雲、不進訪客清單；
  畫面上只顯示遮蔽後的網址。換裝置要重貼一次——安全優先的刻意取捨。
- 本機另存 `cool_last_sync`、`cool_dismissed`（StringList）。
- Web 版：新增 Supabase Edge Function `cool-ics-proxy`，**只允許** `https://cool.ntu.edu.tw/feeds/calendars/*.ics`，不記錄網址、不快取內容；手機版直接用 `http` 抓。

### 5B.3 程式

- `core/ics_parser.dart`（純函式、無新套件）：處理行折疊（RFC 5545 folding）、`VEVENT` 的 `UID`／`SUMMARY`／`DTSTART`（含 `TZID` 與 UTC `Z`）／`URL`／`DESCRIPTION`，
  跳脫字元 `\,` `\;` `\n`。
- `core/cool_sync.dart`（純函式）：`planCoolSync(events, existingTasks, dismissed, now)` → 要新增／要更新的清單。
- `services/cool_feed_service.dart`（抓取，web 走 proxy）、`providers/cool_sync_provider.dart`、`screens/cool_link_screen.dart`。
- `TasksNotifier` 加 `upsertExternal(Task)`（用指定 id 新增或更新）；`remove()` 對 `cool_` 開頭的 id 同時寫入 `cool_dismissed`。

### 5B.4 測試

- 單元：`ics_parser_test.dart`（折疊行、TZID 與 UTC、跳脫字元、非作業事件）；`cool_sync_test.dart`（新增、截止改期、已完成不動、被刪不重建、重跑冪等）。
- Widget：貼錯網址的驗證訊息；試抓結果顯示數量；中斷連結。
- 手動：真的 NTU COOL 帳號走一次（案例寫在測試計畫）。

### 完成判準

- 5B.0 三項驗證通過並記錄；真實帳號同步後作業以任務出現、重複同步不重複、改期會更新。
- Web 版經代理可同步；代理拒絕非 COOL 網址（測試計畫中實測）。

---

## Phase 6：學分與 GPA

**為什麼在課表之後**：學分與成績掛在課程上——先有 Phase 5 的 `courses`，成績直接填在那門課上，不必重打課名。


**目標**：期末填完成績，GPA、累積學分、畢業進度自動出來；還能反推「剩下的課要拿多少才達標」。
等第與績分依**台大官方〈等第制成績定義與等第績分表〉**。

### 6.1 使用流程（UC20）

1. **填成績**：課程詳情 sheet 新增一排等第 chip：A+ A A- B+ B B- C+ C C- F X，另有「通過／不通過／停修」。
   「通過／不通過／停修」自動不計入 GPA；另有「不計入 GPA」開關（例如服務學習）。
2. **成績頁**（`TimetableScreen` 上方切換「課表｜成績」）：
   - 頂部三格：**本學期 GPA**、**累積 GPA**、**已修學分／畢業學分**（進度條）。
   - 每學期 GPA 折線（看得出趨勢）；依學期分組的課程清單（課名、學分、等第）。
   - **百分制換算**：GPA 旁顯示官方換算的百分制分數（例如 3.80 → 85.67），申請獎學金常用。
   - **目標 GPA 試算**：輸入目標累積 GPA → 「本學期尚未給分的 16 學分，平均需 3.9 以上」；做不到則顯示「即使全拿 A+ 最高到 3.72」。
3. 畢業學分：成績頁第一次開啟時問「畢業需要幾學分」（預設 128，存 `user_settings.graduation_credits`）；
   身分「學士班／研究所」決定及格線（學士 C-、研究所 B-，官方表註明），存 `user_settings.degree_level`。
4. 學期回顧（Phase 4）的數字多一行該學期 GPA；朋友分享（Phase 7）**不包含成績**。

### 6.2 資料

- 沿用 `courses.grade`、`courses.counts_in_gpa`、`courses.credits`（Phase 5 已建欄位）；`grade` CHECK 限定合法值。
- `user_settings` 加 `graduation_credits` int、`degree_level` text（D8-B）。**沒有新表。**

### 6.3 程式

- `core/grade_scale.dart`：`kNtuGradePoints = {A+:4.3, A:4.0, A-:3.7, B+:3.3, B:3.0, B-:2.7, C+:2.3, C:2.0, C-:1.7, F:0, X:0}`、
  `gpaToPercent(gpa)`（官方換算表的分段線性規則，並以官方表數個點做測試）、`isPassing(grade, degreeLevel)`。
- `core/gpa_stats.dart`（純函式）：`semesterGpa`、`cumulativeGpa`（學分加權；F／X 計入分母；通過制與不計入者排除）、
  `earnedCredits`（只算及格）、`requiredAverage(target, courses)`（反推，含不可能時的上限）。沒有任何成績時回 `null`（沿用 `rateBetween` 慣例）。
- 畫面：`screens/grades_view.dart`（成績頁內容）、`widgets/gpa_trend_chart.dart`、`widgets/grade_chips.dart`。

### 6.4 測試

- 單元：官方績分逐一；加權平均；F／X 計入、通過制排除、停修排除；研究生 B- 及格；百分制換算對官方表抽 10 點；反推（可達、不可達、無未給分學分）。
- Widget：填成績後三格即時更新；目標試算文案兩種情況；非台大學校仍可用（相同等第表，文件註明各校可能不同）。

### 完成判準

- 自動測試全綠；官方表數值全數吻合；D8-B、system_design §3 GPA 演算法與 UC20 同步。
- 手動：用你自己的真實成績算一次，與校務系統上的 GPA 比對一致。

---

## Phase 7：朋友系統

**你的定義**：「可以自訂分享自己的規劃圖、任務達成率；如果有加課表功能可以看課表」

**為什麼排最後**：「看課表」依賴 Phase 5；而且這是第一個**多使用者**功能——放在所有單人功能穩定之後，風險最低。
**分享（2026-09-25 決定）**：三個分項開關（預設全關）＋邀請連結／QR code。


**目標**：安全地讓同學看到你**願意分享**的東西，並找出**共同空堂**約討論。參考 Strava 的分項隱私（每項內容可設為「朋友可見／只有自己」）。

### 7.1 使用流程（UC21、UC22）

1. 「我的」頁頁首新增 👥 → `FriendsScreen`（訪客：顯示「建立帳號後才能加朋友」並接到既有的登入入口）。
2. **加朋友**：「我的邀請」卡顯示 **QR code** 與「複製邀請連結」（`https://urniversity.netlify.app/invite/<code>`）。
   對方用手機相機掃或點連結 → 開啟 App（已安裝）或網頁版 → 顯示「○○ 想加你為朋友」→ 按「接受」。雙向確認，雙方都同意才成立。
3. **分享設定**（同頁三個開關，預設全關）：
   - 規劃圖（願景與學期目標的關聯，**不含任務標題**）
   - 任務達成率（每日／每週完成比例與連續天數，**不含任務內容**）
   - 課表（課名與時段，**不含成績**）
4. **朋友頁**：點朋友 → 只顯示對方開啟的項目（分頁）；對方全關時顯示「○○ 目前沒有分享內容」。
5. **共同空堂**：兩人都分享課表時，朋友頁多一個「共同空堂」：列出這週兩人都沒課的時段（例如「週三 13:20–15:10」），可一鍵「約這個時間」→ 在自己的任務建立一個有截止時間的任務。
6. 管理：待回覆邀請（接受／婉拒）、已送出（取消）、朋友清單（解除好友——雙方立即失去讀取權）。
   有新邀請時，「我的」分頁圖示出現紅點（開 App 時檢查；沒有推播伺服器）。

### 7.2 資料與安全（核心表 RLS 不動）

- `user_settings` 加：`friend_code`（UNIQUE，8 碼、去除易混字元 0/O/1/I）、`share_graph`、`share_rates`、`share_timetable`（bool，預設 false）。
- 新表 `friendships`（D29）：`id`、`requester_id`、`addressee_id`、`status`（`pending`／`accepted`）、`created_at`；
  UNIQUE（requester, addressee）；RLS：只能讀、刪自己參與的列，**不能直接 INSERT／UPDATE**（全部經 RPC）。
- **Security definer RPC**（`supabase/friends.sql`，全部 `set search_path = public`，檢查 `auth.uid()`）：
  - `my_friend_code()`：沒有就產生（碰撞重試），回傳。
  - `request_friend(code)`：找不到／是自己／已是朋友 → 回錯誤碼；對方已向我送過 → 直接成立；否則建立 pending。未回覆的邀請上限 20。
  - `respond_friend(id, accept)`：只有收到的一方能呼叫。
  - `friend_list()`：朋友與邀請，連同對方的暱稱、頭像、三個分享開關。
  - `friend_rates(friend, from, to)`：對方開啟 `share_rates` 才回傳；只回任務的**計算欄位**（id、due_time、recurrence、completed_dates、created_at、is_completed），**不回標題與內容**，App 端用既有 `history_stats.dart` 算。
  - `friend_graph(friend)`：開啟 `share_graph` 才回傳願景與頂層目標（標題、分類、完成狀態、連結）＋每個目標底下的任務**數量**。
  - `friend_timetable(friend, semester)`：開啟 `share_timetable` 才回傳課程（課名、顏色）與時段。
- 索引：`friendships(requester_id)`、`friendships(addressee_id)`。
- 所有 RPC 與政策放進新檔 `supabase/friends.sql` 並**從此開始進版控**（不回填舊表政策）。

### 7.3 程式

- 深層連結：`app_links`（已在 pubspec）處理 `/invite/<code>`；Android 在 `AndroidManifest.xml` 加 `https://urniversity.netlify.app/invite` 的 App Link（`autoVerify`），
  Netlify 放 `/.well-known/assetlinks.json`；Web 版以路徑直接處理。新增套件 **`qr_flutter`**（只產生 QR，不需要掃描器——手機相機就能掃）。
- `providers/friends_provider.dart`（**不繼承** SyncedListNotifier：資料全來自 RPC，只在登入時可用）；
  `friendRatesProvider(friendId)`、`friendGraphProvider(friendId)`、`friendTimetableProvider((friendId, semester))`（`FutureProvider.family`）。
- 關聯圖重用：把 `overview_graph_screen.dart` 在 `build` 內（~:108-130）建立 nodes／edges 的程式抽成純函式 `buildGraph(futureGoals, semesterGoals, taskCounts, ...)`，
  自己的圖與朋友的唯讀圖共用；`_layoutGraph`（:896）本來就是純函式。
- 課表格線重用 `widgets/timetable_grid.dart`（唯讀模式）；`core/timetable.dart` 加 `commonFreeSlots(mine, theirs, periods, from, to)`。
- 畫面：`screens/friends_screen.dart`、`screens/friend_screen.dart`、`widgets/invite_card.dart`、`screens/invite_accept_screen.dart`。

### 7.4 測試

- 單元：`commonFreeSlots`（節次對齊、跨中午、完全重疊、無交集）；邀請碼字元集；`buildGraph` 抽出後與原本結果一致（既有關聯圖測試照跑）。
- Widget：訪客看到登入提示；三個開關；朋友頁只顯示對方開啟的分頁；邀請連結開啟接受畫面。
- **必須手動、兩個真實帳號**：分享開關關閉時 RPC 回空、開啟後可讀、成為朋友前讀不到、解除好友立即讀不到、直接 `select` 他人資料被 RLS 擋下、
  `friend_rates` 回應中**沒有**任務標題。每條都用第二個帳號的 session 直接呼叫 Supabase 驗證，不是推論。

### 完成判準

- `friends.sql` 已執行；上列兩帳號案例全數實測通過並記錄——**這是唯一一個自動測試綠燈不足以宣告完成的階段**。
- Android 點邀請連結會開 App（App Link 驗證通過）；網頁版可接受邀請。
- 文件：D8-A／D29、DFD 新圖「朋友（經 RPC 的唯讀資料流）」、system_design §1-B、§3（邀請狀態機 Mermaid、共同空堂演算法）、UC21–22。

---

## 已捨棄與延後

| 項目 | 決定 | 理由 |
|---|---|---|
| ⑦ 時事功能 | ❌ **捨棄** | 與「大學生活管理」的主軸無關。而且需要外部資料源、內容篩選與長期維運，成本遠高於它帶來的價值 |
| ⑧ 養寵物 | ⏸ **延後**，不排入目前的階段 | 這是黏著度功能。在核心功能還沒被同學實際驗證之前做，是本末倒置——沒人會為了養寵物而留在一個會弄丟資料的 App |

⑧ 如果之後要做，合理的時機是 Phase 4（回顧系統）之後：那時已經有足夠的
行為資料可以餵給養成機制。

---

## 修改這份文件的規則

順序不是不能改——Phase 1 與 Phase 2 都是你指定提前的。但改的時候要**寫下代價**：
提前一項就是延後另一項，把那句話留在文件裡，下次才不會忘記當初為什麼這樣排。

### 變更紀錄

| 日期 | 改動 | 理由 | 代價 |
|---|---|---|---|
| 2026-09-12 | ② Android widget：Phase 5 → 3 | 我自己要先用 | ⑥ 回顧往後挪 |
| 2026-09-12 | ① 通知 → Phase 1、② widget → Phase 2、⑩⑨ 新手留存 → Phase 3 | 我自己要先用 | 通知只會用手動建立的資料驗證過，Phase 3 後要回頭重測；Phase 3 完成前發給同學，開場是空白畫面 |
| 2026-09-25 | Phase 3 程式碼完成（同日把導覽改為分頁章節＋親手操作） | — | 重播導覽時新增的內容會真的存下來；靈感封存要先手動跑一次 SQL 才能在登入帳號下使用 |
| 2026-09-25 | Phase 4–7 詳細規劃；新增 Phase 5B（NTU COOL） | 讓課表之後的作業截止日不必手抄 | 5B 依賴 NTU COOL 的行事曆訂閱，若不可行整段取消；Phase 7 改用 RPC 而不動核心表 RLS，朋友看不到任務標題 |
