# URniversity

## Proposal Report

### Motivation and Goals
After becoming a college student, I've been using various apps to manage my life. For example, I use `Calendar` to manage schedule and `Google Tasks` to manage things to do. However, I find it kind of disorganized, as every feature I need is scattered, and I need to switch between apps and pay extra attention. Furthermore, I don't have an app to draw up my future plans and visualize them, making it harder to organize my life.

Therefore, I would like to develop an app called URniversity, managing to keep track of students' lives in college. I hope people can use this app to form a better imagination about the future, or at least organize their daily or semester lives.

### Expected Features
- Inspiration -> can record inspirations and develop further connections to future goals.
- Task -> can formulate periodic tasks or normal tasks and notify people to do them.
- Plan -> can plan what to do without a daily basis. E.g. study what subject / do what project / practice something.
- Note -> a diary system, can record what people have done in a day, and retrospect such memories.
- Future -> can organize future goals such as exchanging, interning, competition, certification, performance, and so on, and create relationships between major goals and minor goals.

### Used Tech
#### Frontend
- React Native (Expo) : Use TypeScript to develop Android and iOS apps.
- NativeWind : Provide UI development tools.
- Zustand : Manage shared application state across components.
- MMKV : A key-value local storage library.

#### Backend
- Supabase : Provide PostgreSQL, user authentication, real-time subscriptions, and file storage.
- Expo Notifications + OneSignal : Push notifications.

#### Other
- Git + Github : Version control.
- Figma : Prototype design.
- Postman : API testing and development tool.

### Schedule
W7 : Environment, usage scenario  
W8 : Task module  
W9 : Plan module  
W10 : Note module  
W11 : Inspiration module  
W12 : Future module and connections  
W13 : Dashboard and UI  
W14 : Test, debug  
W15 : Demo  

### Connections to the course
1. Tree structure  
In future module, there are hierarchical relationship between major and minor goals, which is applicable using tree structure.

2. Graph  
Connections between different modules form a graph, especially a directed graph.

3. Queue  
Tasks are sorted by deadline and priority using a Min-Heap.

4. Hash Map  
The Tag system in Inspiration module uses a Hash Map to implement.

---

## Prototype Report

### 目前進度
<!-- 完成了什麼 -->

### 遇到的困難
<!-- 遇到什麼問題、如何解決或打算如何解決 -->

### 下一步計畫
<!-- 接下來要做什麼 -->

### 與課程的關聯
<!-- 到目前為止，你的實作中哪些部分與課程內容有關？關係是什麼？ -->

---

## Final Report

### 專案說明
<!-- 完整描述你的專案做了什麼 -->

### 使用方式
<!-- 如何編譯、執行、使用你的程式 -->

### 與課程的關聯總結
<!-- 總結你的專題與進階程式設計及資料結構課程之間的關聯 -->
