-- ApniPost Admin — categories write policies (Phase 3)
--
-- Apply this in the Supabase SQL Editor.
-- Does NOT drop or weaken existing SELECT policies.
-- Admin condition uses JWT app_metadata.role == 'admin'.

-- Ensure RLS remains enabled (no-op if already enabled).
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- INSERT
DROP POLICY IF EXISTS "Admins can insert categories" ON public.categories;
CREATE POLICY "Admins can insert categories"
ON public.categories
FOR INSERT
TO authenticated
WITH CHECK (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- UPDATE
DROP POLICY IF EXISTS "Admins can update categories" ON public.categories;
CREATE POLICY "Admins can update categories"
ON public.categories
FOR UPDATE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
)
WITH CHECK (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- DELETE
DROP POLICY IF EXISTS "Admins can delete categories" ON public.categories;
CREATE POLICY "Admins can delete categories"
ON public.categories
FOR DELETE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);
