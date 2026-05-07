# URniversity

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

### 專案說明
<!-- 完整描述你的專案做了什麼 -->

### 使用方式
<!-- 如何編譯、執行、使用你的程式 -->
