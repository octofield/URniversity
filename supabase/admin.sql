-- The admin backend at /admin (docs/data_dictionary.md D34–D37,
-- system_design.md §2-O).
--
-- Every table keeps each user to their own rows (RLS), so numbers across all
-- users can only come from SECURITY DEFINER functions. Each one checks
-- is_admin() before anything else. None of them reads anyone's tasks,
-- journals or other content: counts, dates and account details only.
--
-- Run in the Supabase SQL Editor. Safe to run again. Then make yourself an
-- admin (your id is under Authentication → Users):
--   INSERT INTO admins (user_id) VALUES ('<your user id>');

-- ── Who is an admin ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admins (
  user_id  text PRIMARY KEY,
  added_at timestamptz NOT NULL DEFAULT now()
);
-- No policies: nobody reads or writes it through the API; is_admin() does
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text);
$$;
GRANT EXECUTE ON FUNCTION is_admin() TO anon, authenticated;

CREATE OR REPLACE FUNCTION _require_admin() RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'not an admin' USING ERRCODE = '42501';
  END IF;
END;
$$;

-- ── Remote settings: feature switches, announcement, maintenance (D35) ─────

CREATE TABLE IF NOT EXISTS app_config (
  id           integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  -- {"timetable": false, …}: a missing key is on
  flags        jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- {"id", "text" (≤ 200), "level": "info" | "warning", "starts_at", "ends_at"}
  announcement jsonb,
  -- {"enabled": bool, "message" (≤ 200)}
  maintenance  jsonb NOT NULL DEFAULT '{"enabled": false}'::jsonb,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   text,
  CHECK (announcement IS NULL OR char_length(coalesce(announcement->>'text', '')) <= 200),
  CHECK (char_length(coalesce(maintenance->>'message', '')) <= 200)
);
INSERT INTO app_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
-- Read by everyone, guests too: the switches and the maintenance screen apply
-- before anyone signs in
DROP POLICY IF EXISTS "app_config_read" ON app_config;
CREATE POLICY "app_config_read" ON app_config FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "app_config_admin_write" ON app_config;
CREATE POLICY "app_config_admin_write" ON app_config FOR UPDATE TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

-- ── Activity: one row per signed-in user per day they opened the app (D36) ─

CREATE TABLE IF NOT EXISTS user_activity (
  user_id text NOT NULL,
  day     date NOT NULL,
  PRIMARY KEY (user_id, day)
);
ALTER TABLE user_activity ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_activity_own" ON user_activity;
-- Insert and read back one's own (the upsert needs both); nobody else's
CREATE POLICY "user_activity_own" ON user_activity FOR ALL TO authenticated
  USING (auth.uid()::text = user_id) WITH CHECK (auth.uid()::text = user_id);

-- ── Sync failures the app reports (D37) ────────────────────────────────────

CREATE TABLE IF NOT EXISTS sync_error_reports (
  id          bigserial PRIMARY KEY,
  user_id     text NOT NULL,
  at          timestamptz NOT NULL DEFAULT now(),
  "where"     text NOT NULL DEFAULT '' CHECK (char_length("where") <= 100),
  code        text CHECK (char_length(code) <= 20),
  message     text NOT NULL DEFAULT '' CHECK (char_length(message) <= 500),
  platform    text CHECK (char_length(platform) <= 20),
  app_version text CHECK (char_length(app_version) <= 20)
);
CREATE INDEX IF NOT EXISTS sync_error_reports_at_idx ON sync_error_reports (at DESC);
ALTER TABLE sync_error_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "sync_error_reports_insert_own" ON sync_error_reports;
CREATE POLICY "sync_error_reports_insert_own" ON sync_error_reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid()::text = user_id);
DROP POLICY IF EXISTS "sync_error_reports_admin_read" ON sync_error_reports;
CREATE POLICY "sync_error_reports_admin_read" ON sync_error_reports FOR SELECT TO authenticated
  USING (is_admin());

-- ── Numbers ─────────────────────────────────────────────────────────────────

-- When a row was made. Row ids begin with the millisecond it was created
-- ("1790499036894_123456"), which covers the tables without a created_at
CREATE OR REPLACE FUNCTION _row_time(id text) RETURNS timestamptz
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN id ~ '^\d{13}' THEN to_timestamp(left(id, 13)::bigint / 1000.0) END;
$$;

-- Everything the overview, usage and settings tabs show, in one call
CREATE OR REPLACE FUNCTION admin_stats() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  since date := current_date - 29;
  result jsonb;
  feature jsonb := '{}'::jsonb;
  t text;
BEGIN
  PERFORM _require_admin();

  -- Per content table: rows, users with any, rows made on each of 30 days
  FOREACH t IN ARRAY ARRAY['tasks', 'semester_goals', 'future_goals', 'journals', 'inspirations', 'courses', 'reviews']
  LOOP
    EXECUTE format($q$
      SELECT jsonb_build_object(
        'total', (SELECT count(*) FROM %1$I),
        'users', (SELECT count(DISTINCT user_id) FROM %1$I),
        'daily', (SELECT coalesce(jsonb_object_agg(d, n), '{}'::jsonb) FROM (
                    SELECT _row_time(id::text)::date AS d, count(*) AS n FROM %1$I
                    WHERE _row_time(id::text) >= %2$L GROUP BY 1) x)
      )$q$, t, since)
    INTO result;
    feature := feature || jsonb_build_object(t, result);
  END LOOP;

  RETURN jsonb_build_object(
    'users', jsonb_build_object(
      'total', (SELECT count(*) FROM auth.users),
      'today', (SELECT count(*) FROM auth.users WHERE created_at::date = current_date),
      'daily', (SELECT coalesce(jsonb_object_agg(d, n), '{}'::jsonb) FROM (
                  SELECT created_at::date AS d, count(*) AS n FROM auth.users
                  WHERE created_at::date >= since GROUP BY 1) x),
      'schools', (SELECT coalesce(jsonb_agg(jsonb_build_object('name', school, 'count', n)), '[]'::jsonb) FROM (
                  SELECT school, count(*) AS n FROM user_settings
                  WHERE school IS NOT NULL AND school <> '' GROUP BY school ORDER BY n DESC LIMIT 10) x)
    ),
    'active', jsonb_build_object(
      'dau', (SELECT count(DISTINCT user_id) FROM user_activity WHERE day = current_date),
      'wau', (SELECT count(DISTINCT user_id) FROM user_activity WHERE day > current_date - 7),
      'mau', (SELECT count(DISTINCT user_id) FROM user_activity WHERE day > current_date - 30),
      'daily', (SELECT coalesce(jsonb_object_agg(day, n), '{}'::jsonb) FROM (
                  SELECT day, count(*) AS n FROM user_activity WHERE day >= since GROUP BY day) x)
    ),
    'features', feature,
    'settings', jsonb_build_object(
      'styles', (SELECT coalesce(jsonb_object_agg(k, n), '{}'::jsonb) FROM (
                  SELECT coalesce(app_style, 'linen') AS k, count(*) AS n FROM user_settings GROUP BY 1) x),
      'languages', (SELECT coalesce(jsonb_object_agg(k, n), '{}'::jsonb) FROM (
                  SELECT coalesce(language, 'zh_tw') AS k, count(*) AS n FROM user_settings GROUP BY 1) x),
      'credit_categories', (SELECT count(*) FROM user_settings WHERE credit_categories_enabled)
    ),
    'errors', jsonb_build_object(
      'groups', (SELECT coalesce(jsonb_agg(jsonb_build_object('where', w, 'code', c, 'count', n)), '[]'::jsonb) FROM (
                  SELECT "where" AS w, code AS c, count(*) AS n FROM sync_error_reports
                  WHERE at > now() - interval '7 days' GROUP BY 1, 2 ORDER BY n DESC LIMIT 30) x),
      'recent', (SELECT coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) FROM (
                  SELECT at, "where", code, message, platform, app_version FROM sync_error_reports
                  ORDER BY at DESC LIMIT 50) x)
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION admin_stats() TO authenticated;

-- ── Accounts ────────────────────────────────────────────────────────────────

-- Accounts, newest first, 50 a page. Only what identifies an account and how
-- it is doing — never what the user wrote
CREATE OR REPLACE FUNCTION admin_list_users(search text DEFAULT '', page integer DEFAULT 0)
RETURNS TABLE (
  user_id text, email text, created_at timestamptz, last_sign_in_at timestamptz,
  disabled boolean, username text, school text, department text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _require_admin();
  RETURN QUERY
    SELECT u.id::text, u.email::text, u.created_at, u.last_sign_in_at,
           coalesce(u.banned_until > now(), false), s.username, s.school, s.department
    FROM auth.users u
    -- Both sides as text: user_settings.user_id is uuid in some databases and
    -- text in others (a uuid = text comparison fails with 42883)
    LEFT JOIN user_settings s ON s.user_id::text = u.id::text
    WHERE search = ''
       OR u.email ILIKE '%' || search || '%'
       OR s.username ILIKE '%' || search || '%'
       OR s.school ILIKE '%' || search || '%'
    ORDER BY u.created_at DESC
    LIMIT 50 OFFSET greatest(page, 0) * 50;
END;
$$;
GRANT EXECUTE ON FUNCTION admin_list_users(text, integer) TO authenticated;

-- Disabling bans the account from signing in or refreshing its token; a
-- session already open lasts until its access token expires (an hour at most).
-- An admin cannot disable themselves
CREATE OR REPLACE FUNCTION admin_set_user_disabled(target text, disabled boolean) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _require_admin();
  IF target = auth.uid()::text THEN
    RAISE EXCEPTION 'cannot disable yourself' USING ERRCODE = '42501';
  END IF;
  UPDATE auth.users
     SET banned_until = CASE WHEN disabled THEN 'infinity'::timestamptz ELSE NULL END
   WHERE id::text = target;
END;
$$;
GRANT EXECUTE ON FUNCTION admin_set_user_disabled(text, boolean) TO authenticated;

-- The helpers are for the functions above, not for calling directly
REVOKE EXECUTE ON FUNCTION _require_admin() FROM PUBLIC, anon, authenticated;
