-- Length caps on every free-text column the user types into.
-- The numbers mirror src/lib/core/input_limits.dart; change both together, or the
-- database rejects what the app lets through (PostgREST error 23514).
--
-- Run in the Supabase SQL Editor, after the app build that enforces the same
-- caps has shipped.

-- 1. Pre-check: every row that would break a cap. Must return 0 rows, or the
--    ALTER TABLE statements below fail as a whole and change nothing
SELECT 'tasks.title' AS col, id FROM tasks WHERE char_length(title) > 100
UNION ALL SELECT 'tasks.content', id FROM tasks WHERE char_length(content) > 500
UNION ALL SELECT 'semester_goals.title', id FROM semester_goals WHERE char_length(title) > 100
UNION ALL SELECT 'semester_goals.notes', id FROM semester_goals WHERE char_length(notes) > 500
UNION ALL SELECT 'future_goals.title', id FROM future_goals WHERE char_length(title) > 100
UNION ALL SELECT 'future_goals.notes', id FROM future_goals WHERE char_length(notes) > 500
UNION ALL SELECT 'inspirations.title', id FROM inspirations WHERE char_length(title) > 100
UNION ALL SELECT 'inspirations.content', id FROM inspirations WHERE char_length(content) > 500
UNION ALL SELECT 'journals.content', id FROM journals WHERE char_length(content) > 5000
UNION ALL SELECT 'user_settings.username', user_id::text FROM user_settings WHERE char_length(username) > 30
UNION ALL SELECT 'user_settings.school', user_id::text FROM user_settings WHERE char_length(school) > 50
UNION ALL SELECT 'user_settings.department', user_id::text FROM user_settings WHERE char_length(department) > 50;

-- 2. The caps. A NULL passes a CHECK, so optional columns stay optional
ALTER TABLE tasks
  ADD CONSTRAINT tasks_title_len CHECK (char_length(title) <= 100),
  ADD CONSTRAINT tasks_content_len CHECK (char_length(content) <= 500);

ALTER TABLE semester_goals
  ADD CONSTRAINT semester_goals_title_len CHECK (char_length(title) <= 100),
  ADD CONSTRAINT semester_goals_notes_len CHECK (char_length(notes) <= 500);

ALTER TABLE future_goals
  ADD CONSTRAINT future_goals_title_len CHECK (char_length(title) <= 100),
  ADD CONSTRAINT future_goals_notes_len CHECK (char_length(notes) <= 500);

ALTER TABLE inspirations
  ADD CONSTRAINT inspirations_title_len CHECK (char_length(title) <= 100),
  ADD CONSTRAINT inspirations_content_len CHECK (char_length(content) <= 500);

ALTER TABLE journals
  ADD CONSTRAINT journals_content_len CHECK (char_length(content) <= 5000);

ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_username_len CHECK (char_length(username) <= 30),
  ADD CONSTRAINT user_settings_school_len CHECK (char_length(school) <= 50),
  ADD CONSTRAINT user_settings_department_len CHECK (char_length(department) <= 50);

-- 3. Tables created after this file declare their caps in their own CREATE
--    TABLE, so there is nothing to retrofit. Listed here so this stays the one
--    place that names every cap:
--    reviews.went_well / stuck / next_focus  <= 500   (reviews_table.sql)
--    courses.title <= 100, teacher <= 50, course_code / serial_no <= 20
--                                                     (courses.sql)
