-- Phase 3: archiving an inspiration.
--
-- An inspiration can be archived whether or not it is completed — the two are
-- independent axes, so this is a new column rather than a third state on
-- is_completed.
--
-- Run in the Supabase SQL Editor, before the app build that writes is_archived
-- ships. Old builds keep working: they never send the column and the default
-- fills it in.

ALTER TABLE inspirations
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
