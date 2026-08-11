# ApniPost Admin

Production Flutter Web admin panel for the published ApniPost Android application.

## Stack

- Flutter (Web / Chrome)
- Material 3
- Riverpod
- go_router
- Supabase Flutter SDK
- Cloudflare R2 (via secure backend only — never in the browser)

## Run (local)

```bash
flutter pub get

flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Build (web)

```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Backend requirements

Existing ApniPost Supabase/R2 details are documented in:

[`docs/BACKEND_REQUIREMENTS.md`](docs/BACKEND_REQUIREMENTS.md)

Do not invent schema. Reuse the Android app’s production backend.
