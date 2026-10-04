-- Realtime for the lists (system_design.md §3-I, data_flow_diagram.md 1-A).
--
-- While the app is open, each change to an account's own tasks, targets,
-- visions, inspirations, journals, reviews and courses is pushed to that
-- account's other devices. Supabase sends the changes of the tables in its
-- supabase_realtime publication; this adds the seven. Each device only
-- receives rows its RLS policies let it read (its own), so nothing new is
-- exposed.
--
-- Run in the Supabase SQL Editor. Safe to run again: a table already in the
-- publication is skipped. Until it has run nothing is pushed, and the app
-- still catches up whenever it is brought back to the front.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['tasks', 'semester_goals', 'future_goals', 'inspirations', 'journals', 'reviews', 'courses']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
