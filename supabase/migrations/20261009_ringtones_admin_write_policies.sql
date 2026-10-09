-- ApniPost Admin — ringtones write policies
--
-- Apply this in the Supabase SQL Editor (or `supabase db query --linked -f`).
-- Does NOT drop or weaken the existing SELECT policy: the Android app reads
-- ringtones and stays read-only, since app users never carry
-- app_metadata.role = 'admin' (only the service role can set it).
-- Admin condition uses JWT app_metadata.role == 'admin'.

ALTER TABLE public.ringtones ENABLE ROW LEVEL SECURITY;

-- INSERT (admin upload)
DROP POLICY IF EXISTS "Admins can insert ringtones" ON public.ringtones;
CREATE POLICY "Admins can insert ringtones"
ON public.ringtones
FOR INSERT
TO authenticated
WITH CHECK (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- UPDATE (edit title / category)
DROP POLICY IF EXISTS "Admins can update ringtones" ON public.ringtones;
CREATE POLICY "Admins can update ringtones"
ON public.ringtones
FOR UPDATE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
)
WITH CHECK (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

-- DELETE (the admin panel then removes the R2 object via `ringtone-r2`)
DROP POLICY IF EXISTS "Admins can delete ringtones" ON public.ringtones;
CREATE POLICY "Admins can delete ringtones"
ON public.ringtones
FOR DELETE
TO authenticated
USING (
  (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
);

CREATE INDEX IF NOT EXISTS ringtones_created_at_idx
  ON public.ringtones (created_at DESC);
