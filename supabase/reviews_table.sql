-- Phase 4: guided reviews (docs/data_dictionary.md D23).
--
-- One row per finished review. `stats` is the numbers as they stood when the
-- review was done, so editing a task later does not rewrite what a past review
-- said. `focus_target_ids` is deliberately not a foreign key: a target deleted
-- since is skipped when shown, rather than blocking the delete or the review.
--
-- Run in the Supabase SQL Editor before shipping the build that writes reviews.
-- The text caps mirror InputLimits.body in src/lib/core/input_limits.dart.
--
-- ⚠️ Check first that `user_id` on the existing tables really is text: the app
-- compares it with auth.uid()::text, as the owner policy below does.

CREATE TABLE IF NOT EXISTS reviews (
  id                text PRIMARY KEY,
  user_id           text NOT NULL,
  period            text NOT NULL CHECK (period IN ('week', 'month', 'semester')),
  period_start      date NOT NULL,
  period_end        date NOT NULL CHECK (period_end >= period_start),
  went_well         text CHECK (char_length(went_well) <= 500),
  stuck             text CHECK (char_length(stuck) <= 500),
  next_focus        text CHECK (char_length(next_focus) <= 500),
  focus_target_ids  text[] NOT NULL DEFAULT '{}' CHECK (cardinality(focus_target_ids) <= 3),
  stats             jsonb NOT NULL DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now(),
  -- Doing a week over replaces it; the app relies on this to upsert
  UNIQUE (user_id, period, period_start)
);

CREATE INDEX IF NOT EXISTS reviews_user_idx ON reviews (user_id, period_start DESC);

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reviews_owner_all" ON reviews
  FOR ALL TO authenticated
  USING (auth.uid()::text = user_id)
  WITH CHECK (auth.uid()::text = user_id);
