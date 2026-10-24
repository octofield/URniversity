-- Phase 7: friends (docs/data_dictionary.md D8-C, D40; system_design.md §3-V).
--
-- Every content table keeps each user to their own rows, and that does not
-- change here: a friend reads nothing directly. What a friend may see comes
-- only from the SECURITY DEFINER functions below, each of which checks that
-- the two are friends AND that the owner has switched that kind of sharing on,
-- and hands back only the columns needed (a timetable without grades, credits,
-- teachers or rooms).
--
-- friendships has no INSERT or UPDATE policy: a request and an answer go
-- through request_friend() / respond_friend(), which apply the rules. Either
-- side can delete a row they are in (cancel, decline, unfriend), and the other
-- loses access at once.
--
-- Run in the Supabase SQL Editor. Safe to run again. Until it runs, only the
-- friends page fails; nothing else in the app reads these.
--
-- user_settings.user_id is uuid in some databases and text in others, so every
-- comparison with it casts both sides to text (see admin.sql), and rows are
-- inserted with auth.uid() itself, which either column type accepts.

-- ── Share switches and the invite code (D8-C) ───────────────────────────────

ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS friend_code text,
  ADD COLUMN IF NOT EXISTS share_graph boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS share_rates boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS share_timetable boolean NOT NULL DEFAULT false;

-- Eight characters with 0, O, 1 and I left out, so a code read aloud or off a
-- screen cannot be mistyped. Mirrors kFriendCodeAlphabet (core/friend_code.dart)
ALTER TABLE user_settings DROP CONSTRAINT IF EXISTS user_settings_friend_code_check;
ALTER TABLE user_settings ADD CONSTRAINT user_settings_friend_code_check
  CHECK (friend_code ~ '^[A-HJ-NP-Z2-9]{8}$');
CREATE UNIQUE INDEX IF NOT EXISTS user_settings_friend_code_idx ON user_settings (friend_code);

-- ── Who is friends with whom (D40) ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS friendships (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id text NOT NULL,
  addressee_id text NOT NULL,
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  CHECK (requester_id <> addressee_id)
);
-- One row per pair, whichever of the two asked
CREATE UNIQUE INDEX IF NOT EXISTS friendships_pair_idx
  ON friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
CREATE INDEX IF NOT EXISTS friendships_requester_idx ON friendships (requester_id);
CREATE INDEX IF NOT EXISTS friendships_addressee_idx ON friendships (addressee_id);

ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "friendships_read_own" ON friendships;
CREATE POLICY "friendships_read_own" ON friendships FOR SELECT TO authenticated
  USING (auth.uid()::text IN (requester_id, addressee_id));
DROP POLICY IF EXISTS "friendships_delete_own" ON friendships;
CREATE POLICY "friendships_delete_own" ON friendships FOR DELETE TO authenticated
  USING (auth.uid()::text IN (requester_id, addressee_id));

-- ── Helpers ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION _require_user() RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  RETURN auth.uid()::text;
END;
$$;

CREATE OR REPLACE FUNCTION _are_friends(a text, b text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM friendships
    WHERE status = 'accepted'
      AND least(requester_id, addressee_id) = least(a, b)
      AND greatest(requester_id, addressee_id) = greatest(a, b));
$$;

-- ── The functions the app calls ─────────────────────────────────────────────

-- The caller's invite code, made the first time it is asked for. The settings
-- row may not exist yet; a clash with someone else's code tries again
CREATE OR REPLACE FUNCTION my_friend_code() RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  me text := _require_user();
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  existing text;
BEGIN
  SELECT friend_code INTO existing FROM user_settings WHERE user_id::text = me;
  IF existing IS NOT NULL THEN RETURN existing; END IF;
  FOR attempt IN 1..10 LOOP
    code := '';
    FOR i IN 1..8 LOOP
      code := code || substr(alphabet, 1 + floor(random() * 32)::int, 1);
    END LOOP;
    BEGIN
      INSERT INTO user_settings (user_id, friend_code) VALUES (auth.uid(), code)
      ON CONFLICT (user_id) DO UPDATE SET friend_code = coalesce(user_settings.friend_code, EXCLUDED.friend_code);
      SELECT friend_code INTO existing FROM user_settings WHERE user_id::text = me;
      RETURN existing;
    EXCEPTION WHEN unique_violation THEN
      -- Someone else holds this code: draw another
      NULL;
    END;
  END LOOP;
  RAISE EXCEPTION 'could not make a code' USING ERRCODE = 'P0001';
END;
$$;

-- Whose code this is, for "Add ○○ as a friend?" before the request is sent.
-- Nothing back for an unknown code. Knowing the code is what lets one see the
-- name: it is what the owner hands out
CREATE OR REPLACE FUNCTION friend_code_owner(code text)
RETURNS TABLE (user_id text, name text, avatar_index integer, avatar_url text, is_self boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT s.user_id::text,
         coalesce(nullif(s.username, ''), u.raw_user_meta_data->>'full_name'),
         s.avatar_index,
         u.raw_user_meta_data->>'avatar_url',
         s.user_id::text = auth.uid()::text
  FROM user_settings s
  LEFT JOIN auth.users u ON u.id::text = s.user_id::text
  WHERE auth.uid() IS NOT NULL AND s.friend_code = upper(friend_code_owner.code);
$$;

-- Sends a request to the owner of [code]. If they had already asked the
-- caller, that is both saying yes and the two are friends at once. Errors
-- (the message is the code the app reads): not_found, self, already, limit
CREATE OR REPLACE FUNCTION request_friend(code text) RETURNS text
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  me text := _require_user();
  them text;
  pair friendships%ROWTYPE;
BEGIN
  SELECT s.user_id::text INTO them FROM user_settings s WHERE s.friend_code = upper(request_friend.code);
  IF them IS NULL THEN RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0001'; END IF;
  IF them = me THEN RAISE EXCEPTION 'self' USING ERRCODE = 'P0001'; END IF;

  SELECT * INTO pair FROM friendships f
  WHERE least(f.requester_id, f.addressee_id) = least(me, them)
    AND greatest(f.requester_id, f.addressee_id) = greatest(me, them);
  IF FOUND THEN
    IF pair.status = 'accepted' OR pair.requester_id = me THEN
      RAISE EXCEPTION 'already' USING ERRCODE = 'P0001';
    END IF;
    UPDATE friendships SET status = 'accepted' WHERE id = pair.id;
    RETURN 'accepted';
  END IF;

  -- Unanswered requests are capped, so a stolen session cannot spam everyone
  IF (SELECT count(*) FROM friendships WHERE requester_id = me AND status = 'pending') >= 20 THEN
    RAISE EXCEPTION 'limit' USING ERRCODE = 'P0001';
  END IF;

  BEGIN
    INSERT INTO friendships (requester_id, addressee_id) VALUES (me, them);
  EXCEPTION WHEN unique_violation THEN
    -- The other side asked at the same moment
    RAISE EXCEPTION 'already' USING ERRCODE = 'P0001';
  END;
  RETURN 'pending';
END;
$$;

-- Yes or no to a request made to the caller; no deletes the request. Only the
-- one asked may answer: not_allowed otherwise
CREATE OR REPLACE FUNCTION respond_friend(friendship uuid, accept boolean) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  me text := _require_user();
BEGIN
  IF accept THEN
    UPDATE friendships SET status = 'accepted'
    WHERE id = friendship AND addressee_id = me AND status = 'pending';
  ELSE
    DELETE FROM friendships
    WHERE id = friendship AND addressee_id = me AND status = 'pending';
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_allowed' USING ERRCODE = 'P0001'; END IF;
END;
$$;

-- Everyone the caller has a row with: friends, requests to them, requests
-- from them. The other side's name and picture, and — for friends only — which
-- kinds of sharing they have on
CREATE OR REPLACE FUNCTION friend_list()
RETURNS TABLE (
  friendship_id uuid, user_id text, status text, name text, avatar_index integer,
  avatar_url text, share_graph boolean, share_rates boolean, share_timetable boolean,
  created_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH mine AS (
    SELECT f.*, CASE WHEN f.requester_id = auth.uid()::text THEN f.addressee_id ELSE f.requester_id END AS other
    FROM friendships f
    WHERE auth.uid()::text IN (f.requester_id, f.addressee_id)
  )
  SELECT m.id,
         m.other,
         CASE WHEN m.status = 'accepted' THEN 'friend'
              WHEN m.requester_id = auth.uid()::text THEN 'outgoing'
              ELSE 'incoming' END,
         coalesce(nullif(s.username, ''), u.raw_user_meta_data->>'full_name'),
         s.avatar_index,
         u.raw_user_meta_data->>'avatar_url',
         m.status = 'accepted' AND coalesce(s.share_graph, false),
         m.status = 'accepted' AND coalesce(s.share_rates, false),
         m.status = 'accepted' AND coalesce(s.share_timetable, false),
         m.created_at
  FROM mine m
  LEFT JOIN user_settings s ON s.user_id::text = m.other
  LEFT JOIN auth.users u ON u.id::text = m.other
  ORDER BY m.created_at;
$$;

-- A friend's courses in [semester], when they share their timetable: name,
-- colour and meeting times. Never grades, credits, teachers or rooms. Null
-- when the two are not friends or the switch is off
CREATE OR REPLACE FUNCTION friend_timetable(friend text, semester text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  me text := _require_user();
BEGIN
  IF NOT _are_friends(me, friend) THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM user_settings WHERE user_id::text = friend AND share_timetable) THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'school', (SELECT school FROM user_settings WHERE user_id::text = friend),
    'courses', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'id', c.id,
                   'title', c.title,
                   'color', c.color,
                   'sessions', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                                   'weekday', x->'weekday',
                                   'start_minute', x->'start_minute',
                                   'end_minute', x->'end_minute')), '[]'::jsonb)
                                FROM jsonb_array_elements(c.sessions) x)
                 )), '[]'::jsonb)
                FROM courses c
                WHERE c.user_id::text = friend AND c.semester = friend_timetable.semester)
  );
END;
$$;

-- ── Who may call what ───────────────────────────────────────────────────────

REVOKE EXECUTE ON FUNCTION _require_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION _are_friends(text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION my_friend_code() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION friend_code_owner(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION request_friend(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION respond_friend(uuid, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION friend_list() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION friend_timetable(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION my_friend_code() TO authenticated;
GRANT EXECUTE ON FUNCTION friend_code_owner(text) TO authenticated;
GRANT EXECUTE ON FUNCTION request_friend(text) TO authenticated;
GRANT EXECUTE ON FUNCTION respond_friend(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION friend_list() TO authenticated;
GRANT EXECUTE ON FUNCTION friend_timetable(text, text) TO authenticated;
