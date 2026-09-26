-- Phase 5 and 6: courses, their weekly meetings and grades
-- (docs/data_dictionary.md D27, D8-B).
--
-- A course's meetings are a jsonb array on the course row rather than a table
-- of their own: the app writes in the background without waiting, and two rows
-- (a course and its meetings) could arrive in either order — a meeting before
-- its course would be rejected by the foreign key and silently lost. One row is
-- one write. Each meeting is {weekday 1–7, start_minute, end_minute, location}.
--
-- Run in the Supabase SQL Editor before shipping the build that has the
-- timetable. The caps mirror InputLimits in src/lib/core/input_limits.dart.
--
-- ⚠️ Check first that `user_id` on the existing tables really is text.

CREATE TABLE IF NOT EXISTS courses (
  id             text PRIMARY KEY,
  user_id        text NOT NULL,
  semester       text NOT NULL CHECK (char_length(semester) <= 10),
  title          text NOT NULL CHECK (char_length(title) <= 100),
  teacher        text CHECK (char_length(teacher) <= 50),
  course_code    text CHECK (char_length(course_code) <= 20),
  serial_no      text CHECK (char_length(serial_no) <= 20),
  credits        numeric(3, 1) NOT NULL DEFAULT 0 CHECK (credits >= 0 AND credits <= 30),
  -- Phase 6. A letter grade, or a pass / fail / withdrawn marker
  grade          text CHECK (grade IN ('A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'F', 'X',
                                       'pass', 'fail', 'withdrawn')),
  counts_in_gpa  boolean NOT NULL DEFAULT true,
  color          bigint NOT NULL,
  catalog_id     text CHECK (char_length(catalog_id) <= 60),
  sessions       jsonb NOT NULL DEFAULT '[]'
                 CHECK (jsonb_typeof(sessions) = 'array' AND jsonb_array_length(sessions) <= 20),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS courses_user_idx ON courses (user_id, semester);

ALTER TABLE courses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "courses_owner_all" ON courses;
CREATE POLICY "courses_owner_all" ON courses
  FOR ALL TO authenticated
  USING (auth.uid()::text = user_id)
  WITH CHECK (auth.uid()::text = user_id);

-- The first day of classes per semester, {"115-1": {"first_day": "2026-09-07",
-- "weeks": 16}}. Read and written on its own, so until this runs only these
-- dates fail to sync and every other setting carries on
ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS term_starts jsonb;

-- Phase 6: how many credits the degree needs, and which pass mark applies
ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS graduation_credits integer CHECK (graduation_credits BETWEEN 1 AND 400),
  ADD COLUMN IF NOT EXISTS degree_level text CHECK (degree_level IN ('bachelor', 'graduate'));

-- A deleted course goes to the trash like a task. If trash_items limits
-- item_type with a CHECK, it has to allow 'course' too. This re-creates the
-- constraint under the name Postgres gives an inline CHECK; if yours has a
-- different name (see Table Editor → trash_items → Constraints), drop that one
-- as well, or deleting a course will fail to reach the trash
ALTER TABLE trash_items DROP CONSTRAINT IF EXISTS trash_items_item_type_check;
ALTER TABLE trash_items ADD CONSTRAINT trash_items_item_type_check
  CHECK (item_type IN ('task', 'semester_goal', 'future_goal', 'course'));
