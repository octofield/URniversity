# URniversity

## 開發文件導覽（docs/）

除了下方依課程進度撰寫的歷史報告（Proposal / Prototype / Final Report）之外，`docs/` 資料夾
還維護一組**持續更新的技術文件**，供開發者（包含未來的你）在新增或修改功能前查閱。這組文件
彼此有依賴關係，建議依序閱讀：

| 文件 | 說明 | 什麼時候該看／該改 |
|---|---|---|
| [docs/DFD.md](docs/DFD.md) | 資料流程圖：畫面、Provider、Supabase 資料表／本機儲存之間的資料如何流動 | 想知道「這筆資料從哪裡來、寫到哪裡去」時查閱；新增/修改資料表欄位、Provider 讀寫邏輯、SharedPreferences key 時必須同步更新 |
| [docs/DD.md](docs/DD.md) | 資料字典：每個 Supabase 資料表／本機儲存 key 的完整欄位定義、型別、必填、列舉值 | 想知道「這個欄位的格式與規則」時查閱；異動同上，需與 DFD.md 一起更新 |
| [docs/system_design.md](docs/system_design.md) | 系統設計：畫面導覽架構、各功能輸入輸出格式、核心演算法處理過程、使用者操作步驟、程式流程圖 | 想知道「這個功能怎麼運作、使用者怎麼操作」時查閱；修改導覽流程、輸入輸出格式，或任何文件中列出的演算法邏輯時必須同步更新（含重畫流程圖） |
| [docs/testing.md](docs/testing.md) | 測試方法：本專案採用的各類測試（平台、單元、系統、接受度、Alpha、Beta、黑箱、白箱、極限值、效能）定義與具體做法 | 執行任何測試前查閱，依此挑選適用的測試類型與案例依據 |
| [docs/test-plans/](docs/test-plans/) | 測試計畫存放處，`TEMPLATE.md` 為範本 | **每次**執行測試（新功能或迴歸測試）前，複製範本填寫測試計畫，測試後補上實際結果，存成 `YYYY-MM-DD-主題.md` |

這些文件的維護規則同時寫在專案根目錄的 `CLAUDE.md`，供 AI 協作工具（Claude Code）在讀寫程式
碼時自動遵循，確保文件不會隨著程式碼演進而過時。

---

## Proposal Report

### Motivation and Goals
After becoming a college student, I've been using various apps to manage my life. For example, I use `Calendar` to manage schedule and `Google Tasks` to manage things to do. However, I find it kind of disorganized, as every feature I need is scattered, and I need to switch between apps and pay extra attention. Furthermore, I don't have an app to draw up my future plans and visualize them, making it harder to organize my life.  
  
Therefore, I would like to develop an app named URniversity, managing to keep track of students' lives in college. I hope people can use this app to form a better imagination about the future, or at least organize their daily or semester lives.  
  
One sentence to summarize, "To know where you are and where to go in your college."

### Competitive Analysis
#### 1. Notion
**Strengths**: Flexible, database relations, collaborative  
**Weaknesses**: High learning curve  

#### 2. TodoList
**Strengths**: Strongest for daily task management  
**Weaknesses**: No academic information, no long-term linkage  

#### 3. MyStudyLife
**Strengths**: Schedules, exam tracking, almost everything in daily needs  
**Weaknesses**: Not support career planning, inspirations, or personal growth  
  
#### Overall
**Structure**: 3-layer structure (Today / Semester / Future) provides immediate value  
**Inspiration**: Merges innovative ideas with solid goals  
**Growth**: Users can see their evolution from freshman to graduate.  

### Expected Features
There are three main layers called future, semester, and today.  
  
Three layers can be used independently. However, there are linking relations between every layer.
  
#### Today: Tasks and inspiration, what to do in a day
- Task list (Add / Finish / Delete)
- Task label and Inspiration Record (Link to semester or future goals)
- Today's summarization (How many tasks are completed this day)
- Concentration time record

#### Semester: Some targets and achievements in a semester
- Daily tasks that are linked to a target
- Future goals
- Visualize the advancement of all targets

#### Future: Major goals in the future such as exchanging, interning, competition, certification, performance, and so on
- Subgoals
- Start and end semester
- Schedule visualization with timeline
- Categorization
- Every semester target and daily task that are linked to the goal

#### (supplementary) Diary: Growth record and retrospect
- Retro on a daily / weekly / monthly, or even a semesterly basis

### Used Tech
#### Frontend
- Flutter : Use Dart to develop Android, iOS, and even Windows, Linux apps.
- Dart : Language used to develop Flutter.
- Riverpod : A package used to manage status across components.
- Flutter Material Design 3 : Built-in UI component library in flutter.

#### Backend
- Supabase : Provide PostgreSQL, user authentication, realtime, and file storage.

#### Other
- Git + Github : Version control.
- Figma : Prototype design.
- Postman : API testing and development tool.

### Prototype Validation Goals
- Flutter environment setup
- Basic UI structure
- Available Today / Semester / Future pages
- Add tasks to today and goals future
- Due date setting
- Future goals categorization
- Linkage between tasks and goals
- Adjustable subgoals

---

## Prototype Report

### Progress
I have done Basic UI structure, available Today / Semester / Future pages, add tasks to today and goals future, due date setting, future goals categorization. To make it better, linkage and visualization are necessary.

### Difficulties
Nothing big bruh

### Next
- Editable tasks and goals
- Semester default setting
- Linkage between tasks / targets / goals
- Advancement visualization
- Better subgoals (more detail)
- Supabase connection
- UI improvement to make it convenient
- Default template for future goals
- Diary system and retro system
- Cross-platform and cross-device usage
- Maybe exam and GPA tracking

---

## Final Report

### Project Explanation
My project **URniversity** is an app aiming to manage college lives. There is a clear three-layer structure, which consists of **Tasks**, **Targets**, and **Goals**.
- Tasks: Manage everyday life. Create tasks with period and priority supporting. Cassify tasks using different views and separate targets or goals.
- Targets: Define semester targets. What to achieve during this semester, GPA, project, club activities, or so on? Users can link tasks to targets to make such targets feasible.
- Goals: Imagine future goals, such as exchange, internship, certification. What goals to accompish after growing up? Moreover, users can link both tasks and targets to goals to make these goals more practical and touchable. 

Here are also some supplementary systems:
- Diary: Record users' lives.
- Inspiration: Catch every inspirations so that users can take advantage of them more properly.
- Feedback: Should users encounter any issues or have any advice, they can tell me directly and anonymously.  

With these features, I believe college students can form a better future blueprint. I hope the app can help not only myself but also other students in need.

### Usage
Go to https://urniversity.netlify.app and start exploring my **URniversity** project.  
Users can login as a guest, with email, or using Google account.  
Currently no Android / iOS version, only web version available.

### Next
- Android / iOS / Windows version support
- Different designs among different screen widths
- Widgets on distinct devices
- Better UI experience (More smooth interactions, generalized button positions)
- Visualization of a future goal
- Retro system
- Notification system
- GPA tracking
- Inspiration archive