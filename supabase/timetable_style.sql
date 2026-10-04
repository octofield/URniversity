-- How the timetable is drawn (system_design.md §3-S, data_dictionary.md D8-B).
--
-- Stored as the style's name (standard, solid, outline, paper, agenda).
-- Capped by length rather than by a list of names, so a later build can add a
-- style without another migration; a name the app does not know falls back
-- to standard.
--
-- Run in the Supabase SQL Editor. Until it has run, only the timetable style
-- fails to sync (and the app says so) — the app reads and writes this column
-- on its own, so the other settings are unaffected. Old builds never send the
-- column and leave it NULL.

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS timetable_style text;

ALTER TABLE user_settings
  DROP CONSTRAINT IF EXISTS user_settings_timetable_style_len;
ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_timetable_style_len CHECK (char_length(timetable_style) <= 20);
