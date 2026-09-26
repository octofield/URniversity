-- The app style a user picked (system_design.md §3-R, data_dictionary.md D8-B).
--
-- Stored as the style's name (linen, modern, midnight, sage, ocean, sakura,
-- mono). Capped by length rather than by a list of names, so a later build can
-- add a style without another migration; a name the app does not know falls
-- back to linen.
--
-- Run in the Supabase SQL Editor. Until it has run, only the style fails to
-- sync (and the app says so) — the app reads and writes this column on its
-- own, so language, date format and the other settings are unaffected. Old
-- builds never send the column and leave it NULL.

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS app_style text;

ALTER TABLE user_settings
  DROP CONSTRAINT IF EXISTS user_settings_app_style_len;
ALTER TABLE user_settings
  ADD CONSTRAINT user_settings_app_style_len CHECK (char_length(app_style) <= 20);
