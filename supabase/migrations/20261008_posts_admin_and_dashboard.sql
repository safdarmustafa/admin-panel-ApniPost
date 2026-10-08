-- ApniPost Admin — content library policies + dashboard stats
--
-- Apply this in the Supabase SQL Editor (or `supabase db query --linked -f`).
-- Does NOT drop or weaken existing policies ("Public can read posts" for anon
-- and "Admins can insert posts" stay as they are).
-- Admin condition uses JWT app_metadata.role == 'admin'.

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- SELECT — the existing read policy only covers `anon`, so signed-in admins
-- (role `authenticated`) currently see zero posts.
DROP POLICY IF EXISTS "Admins can read posts" ON public.posts;
CREATE POLICY "Admins can read posts"
ON public.posts
FOR SELECT
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- UPDATE (move a post to another category)
DROP POLICY IF EXISTS "Admins can update posts" ON public.posts;
CREATE POLICY "Admins can update posts"
ON public.posts
FOR UPDATE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
)
WITH CHECK (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- DELETE (removes the post from the app; the R2 file is left in storage)
DROP POLICY IF EXISTS "Admins can delete posts" ON public.posts;
CREATE POLICY "Admins can delete posts"
ON public.posts
FOR DELETE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

CREATE INDEX IF NOT EXISTS posts_created_at_idx ON public.posts (created_at DESC);
CREATE INDEX IF NOT EXISTS posts_category_idx ON public.posts (category);

-- Dashboard aggregates. SECURITY DEFINER so it can count `users` and
-- `subscriptions` (which have no client policies); it returns totals only,
-- never names or phone numbers, and refuses non-admin callers.
CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
  -- Days are bucketed in India time, where the app's users are.
  today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') <> 'admin' THEN
    RAISE EXCEPTION 'admin access required' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'generated_at', now(),

    'posts_total', (SELECT count(*) FROM posts),
    'posts_images', (SELECT count(*) FROM posts WHERE media_type = 'image'),
    'posts_videos', (SELECT count(*) FROM posts WHERE media_type = 'video'),
    'posts_gifs', (SELECT count(*) FROM posts WHERE media_type = 'gif'),
    'posts_last_7d',
      (SELECT count(*) FROM posts WHERE created_at >= now() - interval '7 days'),
    'posts_prev_7d',
      (SELECT count(*) FROM posts
        WHERE created_at >= now() - interval '14 days'
          AND created_at < now() - interval '7 days'),

    'posts_by_day', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('day', d.day, 'count', d.n)
                                ORDER BY d.day), '[]'::jsonb)
      FROM (
        SELECT g.day::date AS day, count(p.id) AS n
        FROM generate_series(today - 29, today, interval '1 day') AS g(day)
        LEFT JOIN posts p
          ON (p.created_at AT TIME ZONE 'Asia/Kolkata')::date = g.day::date
        GROUP BY g.day
      ) d
    ),

    'categories', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
               'name', c.name,
               'show_on_home', c.show_on_home,
               'count', coalesce(s.n, 0),
               'last_upload', s.last_upload
             ) ORDER BY coalesce(s.n, 0) DESC, c.display_order), '[]'::jsonb)
      FROM categories c
      LEFT JOIN (
        SELECT category, count(*) AS n, max(created_at) AS last_upload
        FROM posts GROUP BY category
      ) s ON s.category = c.name
    ),

    -- Posts whose `category` text matches no row in `categories`
    -- (e.g. the category was renamed or deleted).
    'orphan_categories', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('name', o.category, 'count', o.n)
                                ORDER BY o.n DESC), '[]'::jsonb)
      FROM (
        SELECT p.category, count(*) AS n
        FROM posts p
        WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE c.name = p.category)
        GROUP BY p.category
      ) o
    ),

    'users_total', (SELECT count(*) FROM users),
    'users_last_7d',
      (SELECT count(*) FROM users WHERE created_at >= now() - interval '7 days'),
    'users_prev_7d',
      (SELECT count(*) FROM users
        WHERE created_at >= now() - interval '14 days'
          AND created_at < now() - interval '7 days'),
    'users_by_day', (
      SELECT coalesce(jsonb_agg(jsonb_build_object('day', d.day, 'count', d.n)
                                ORDER BY d.day), '[]'::jsonb)
      FROM (
        SELECT g.day::date AS day, count(u.id) AS n
        FROM generate_series(today - 29, today, interval '1 day') AS g(day)
        -- users.created_at is `timestamp without time zone`, stored as UTC.
        LEFT JOIN users u
          ON (u.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::date
             = g.day::date
        GROUP BY g.day
      ) d
    ),

    'subs_active', (SELECT count(*) FROM subscriptions WHERE status = 'active'),
    'subs_active_monthly',
      (SELECT count(*) FROM subscriptions
        WHERE status = 'active' AND plan_type = 'monthly'),
    'subs_active_trial',
      (SELECT count(*) FROM subscriptions
        WHERE status = 'active' AND plan_type = 'trial'),
    'subs_pending', (SELECT count(*) FROM subscriptions WHERE status = 'pending'),
    -- `amount` and `end_date` are not populated; renewals use next_billing_date.
    'subs_renewing_7d',
      (SELECT count(*) FROM subscriptions
        WHERE status = 'active'
          AND next_billing_date BETWEEN (now() AT TIME ZONE 'UTC')
                                    AND (now() AT TIME ZONE 'UTC') + interval '7 days')
  ) INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
