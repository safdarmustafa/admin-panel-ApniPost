# Cloudflare R2 upload secrets (Edge Function)

Used by Supabase Edge Function: `create-r2-upload-urls`

## Required secrets

Set these as Supabase Edge Function secrets (Dashboard → Edge Functions → Secrets,
or `supabase secrets set`).

```bash
R2_ACCOUNT_ID=<secret>
R2_ACCESS_KEY_ID=<secret>
R2_SECRET_ACCESS_KEY=<secret>
R2_BUCKET_NAME=apnipost-media
R2_PUBLIC_BASE_URL=https://media.apnipost.com
```

Never commit real secret values.

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided automatically to Edge
Functions by the Supabase runtime.

## Optional CORS secrets

Phase 4A allows local Flutter Web origins by default:

- `http://localhost:<port>`
- `http://127.0.0.1:<port>`

For production admin hosting, also set:

```bash
PRODUCTION_ADMIN_ORIGIN=https://your-admin-host.example
```

Or a comma-separated list:

```bash
ALLOWED_ADMIN_ORIGINS=https://admin.example,https://admin-staging.example
```

## Deploy (manual — do not auto-deploy from this phase)

```bash
supabase functions deploy create-r2-upload-urls
```

## Notes

- This function only generates short-lived **presigned PUT** URLs.
- It does **not** upload bytes.
- It does **not** insert `public.posts` rows.
- R2 bucket CORS is **not** configured in Phase 4A.
