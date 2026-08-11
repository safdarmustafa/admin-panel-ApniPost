# ApniPost Admin — Backend Requirements

This Flutter Web admin project started from a clean Flutter scaffold.  
**No ApniPost Android app source, Supabase schema, or Cloudflare R2 setup was found in this repository.**

Do not invent production table names or columns. Wire repositories only after the owner confirms the existing backend.

## Safe frontend configuration

Pass public values at build/run time (never commit secrets):

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Frontend may only use the Supabase **URL** and **anon/public key**.

Never put in this Flutter app:

- Supabase service-role key
- Cloudflare R2 access key / secret key
- Admin passwords or private API keys

## Required backend information

Provide the following from the **existing** ApniPost production backend.

### 1. Supabase project

- Project URL
- Anon/public key
- Confirmation that the admin panel uses the same project as the Android app

### 2. Admin authorization (IMPLEMENTED)

V1 admin authorization:

```
Supabase Auth user → JWT → app_metadata.role == "admin"
```

Rules:

- Authorized only when `app_metadata.role` is exactly `"admin"`
- Does **not** use `user_metadata`
- Does **not** use `public.users`
- Does **not** use email allowlists
- Fail closed for missing metadata/role/any other role

To make a real Supabase account an admin, set JWT app metadata via a
**trusted server-side / Dashboard** path (never from this Flutter Web app):

```bash
# Example using Supabase Admin API / service role (server only):
# PATCH auth user app_metadata to include { "role": "admin" }
```

Or in the Supabase Dashboard:

1. Authentication → Users → select the admin user
2. Set App Metadata JSON to include `"role": "admin"`
3. User must refresh session / re-login so the JWT includes the claim

Do **not** put the service-role key in this Flutter app.

### 3. Categories (IMPLEMENTED — Phase 3)

Existing table: `public.categories`

- `id`, `name`, `display_order`, `created_at`, `show_on_home`

Posts relationship: `posts.category` stores the **category name** (text), not a UUID.

Admin write RLS SQL:

`supabase/migrations/20260811_categories_admin_write_policies.sql`

Apply that file in the Supabase SQL Editor before create/edit/delete will succeed.

### 4. Content / media

Existing table name and columns for:

- id
- category relationship (`category_id` or equivalent)
- media URL
- media type (`image` / `video` / `gif` or equivalent)
- active/status (if any)
- created/updated timestamps
- duplicate fingerprint/hash (if any)

Confirm there are **not** separate required image/video/gif tables unless Android already depends on them.

### 5. Cloudflare R2 (Phase 4A + 4B)

Edge Function: `create-r2-upload-urls` (presigned PUT URLs)

Flutter uploads bytes **directly to R2**, then inserts `public.posts`.

Secrets:

[`docs/R2_UPLOAD_SECRETS.md`](./R2_UPLOAD_SECRETS.md)

R2 CORS (required for browser PUT):

[`docs/R2_CORS.md`](./R2_CORS.md)

Expected:

- Bucket: `apnipost-media`
- Public base: `https://media.apnipost.com`

### 6. RLS / policies

Confirm Row Level Security rules for:

- Reading/writing categories
- Reading/writing content
- Admin-only mutations

## Implementation rule

Until the items above are confirmed:

- Keep repository interfaces isolated
- Do not invent schema
- Do not fake Cloudflare uploads
- Do not return hardcoded production data
