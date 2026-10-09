-- ApniPost Admin — ringtone categories
--
-- Apply this in the Supabase SQL Editor (or `supabase db query --linked -f`)
-- AFTER 20261009_ringtones_admin_write_policies.sql.
--
-- Separate from `public.categories` (posts) so ringtone categories never show
-- up on the app's post screens. The Android Ringtones screen reads this table
-- for its chips (name, hindi_name, display_order); the admin panel manages it.
-- Admin condition uses JWT app_metadata.role == 'admin'.

CREATE TABLE IF NOT EXISTS public.ringtone_categories (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL UNIQUE
                CHECK (
                  length(trim(name)) > 0
                  AND lower(trim(name)) NOT IN ('all', 'सभी')
                ),
  hindi_name    text CHECK (hindi_name IS NULL OR length(trim(hindi_name)) > 0),
  display_order int  NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- "Ganesha" and "ganesha" must not both exist.
CREATE UNIQUE INDEX IF NOT EXISTS ringtone_categories_name_lower_idx
  ON public.ringtone_categories (lower(name));

-- Seed the current categories with their Hindi labels.
INSERT INTO public.ringtone_categories (name, hindi_name, display_order)
VALUES
  ('Durga',        'दुर्गा',  0),
  ('Ganesha',      'गणेश',   1),
  ('Funny',        'मज़ेदार', 2),
  ('Love',         'प्यार',   3),
  ('Instrumental', 'धुन',    4)
ON CONFLICT (name) DO NOTHING;

-- Any other category already used by a ringtone, so the foreign key below
-- can be added safely.
INSERT INTO public.ringtone_categories (name, display_order)
SELECT DISTINCT r.category, 100
FROM public.ringtones r
WHERE NOT EXISTS (
  SELECT 1 FROM public.ringtone_categories c
  WHERE lower(c.name) = lower(r.category)
);

-- Every ringtone must use a known category.
-- ON UPDATE CASCADE: renaming a category renames it on its ringtones too.
-- ON DELETE RESTRICT: a category that still has ringtones cannot be deleted.
ALTER TABLE public.ringtones
  DROP CONSTRAINT IF EXISTS ringtones_category_fkey;
ALTER TABLE public.ringtones
  ADD CONSTRAINT ringtones_category_fkey
  FOREIGN KEY (category) REFERENCES public.ringtone_categories (name)
  ON UPDATE CASCADE
  ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS ringtones_category_idx
  ON public.ringtones (category);

ALTER TABLE public.ringtone_categories ENABLE ROW LEVEL SECURITY;

-- SELECT — the Android app (anon) and the admin panel both read categories.
DROP POLICY IF EXISTS "Anyone can read ringtone categories"
  ON public.ringtone_categories;
CREATE POLICY "Anyone can read ringtone categories"
ON public.ringtone_categories
FOR SELECT
TO anon, authenticated
USING (true);

-- INSERT
DROP POLICY IF EXISTS "Admins can insert ringtone categories"
  ON public.ringtone_categories;
CREATE POLICY "Admins can insert ringtone categories"
ON public.ringtone_categories
FOR INSERT
TO authenticated
WITH CHECK (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- UPDATE
DROP POLICY IF EXISTS "Admins can update ringtone categories"
  ON public.ringtone_categories;
CREATE POLICY "Admins can update ringtone categories"
ON public.ringtone_categories
FOR UPDATE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
)
WITH CHECK (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- DELETE
DROP POLICY IF EXISTS "Admins can delete ringtone categories"
  ON public.ringtone_categories;
CREATE POLICY "Admins can delete ringtone categories"
ON public.ringtone_categories
FOR DELETE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);
