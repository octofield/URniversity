-- Phase 5: schools' course catalogs (docs/data_dictionary.md D29, D32).
--
-- Filled once a semester by scripts/catalog/fetch_catalog.py with the service
-- role key, which bypasses RLS; everyone else — signed in or a guest — can
-- only read. Only what adding a course needs is kept. Each school writes its
-- times its own way ("三6,7 (基醫508)", "BMES醫環618 W2W3W4"); the script reads
-- them with that school's period table and stores ready sessions, so the app
-- carries no school's rules.
--
-- Run in the Supabase SQL Editor, then run the script. Safe to run again.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS course_catalog (
  -- "<school>_<semester>_<key>": the key is the school's own — NTU's serial
  -- number (or code_class_teacher when it has none), NTHU's course number
  id           text PRIMARY KEY,
  -- scripts/catalog/schools.json: "ntu", "nthu", …
  school       text NOT NULL,
  semester     text NOT NULL,
  serial_no    text,
  course_code  text,
  class_no     text,
  title        text NOT NULL,
  teacher      text,
  credits      numeric(3, 1),
  -- 必修 / 選修 / 必帶, as the school writes it for the first audience listed
  required     text,
  -- Every audience that lists the course, joined with "、"
  audience     text,
  -- The school's own wording, shown as is
  time_text    text,
  -- [{weekday, start_minute, end_minute, location}], the same shape as
  -- courses.sessions, copied there when a course is added
  sessions     jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- For a table made by the first version of this file
ALTER TABLE course_catalog ADD COLUMN IF NOT EXISTS sessions jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE course_catalog ALTER COLUMN school DROP DEFAULT;
ALTER TABLE course_catalog DROP CONSTRAINT IF EXISTS course_catalog_sessions_check;
ALTER TABLE course_catalog ADD CONSTRAINT course_catalog_sessions_check
  CHECK (jsonb_typeof(sessions) = 'array' AND jsonb_array_length(sessions) <= 20);
-- Rows from that version had ids without the school in front; the script
-- writes them again under the new ids
DELETE FROM course_catalog WHERE id NOT LIKE school || '\_%';

CREATE INDEX IF NOT EXISTS course_catalog_semester_idx ON course_catalog (school, semester);
-- ilike '%微積%' on ten thousand rows a semester, answered from an index
CREATE INDEX IF NOT EXISTS course_catalog_title_trgm ON course_catalog USING gin (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS course_catalog_teacher_trgm ON course_catalog USING gin (teacher gin_trgm_ops);

ALTER TABLE course_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "course_catalog_read" ON course_catalog;
CREATE POLICY "course_catalog_read" ON course_catalog
  FOR SELECT TO anon, authenticated
  USING (true);

-- The schools the app can search, and for which semesters. The script adds a
-- school's row after writing it, so a new school needs no new app build
CREATE TABLE IF NOT EXISTS catalog_schools (
  code        text PRIMARY KEY,
  -- As the app's school list writes it (taiwan_universities.dart), so the
  -- user's own school can come first
  name        text NOT NULL,
  short_name  text NOT NULL,
  semesters   text[] NOT NULL DEFAULT '{}',
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE catalog_schools ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "catalog_schools_read" ON catalog_schools;
CREATE POLICY "catalog_schools_read" ON catalog_schools
  FOR SELECT TO anon, authenticated
  USING (true);
