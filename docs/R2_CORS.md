# Cloudflare R2 CORS + browser PUT troubleshooting

## Your CORS JSON is fine (for the listed origin)

If OPTIONS for your Chrome origin returns `Access-Control-Allow-Origin`, CORS
is not the blocker.

Chrome often reports **CORS** when the real problem is:

**R2 `PUT` → HTTP 403** (bad signature / checksum), and the error response
does not include CORS headers.

## Fix path A — direct browser PUT (preferred)

1. Keep R2 CORS with your **current** exact origin + `AllowedHeaders: ["*"]`.
2. Prefer a fixed Flutter port:

```bash
flutter run -d chrome --web-port=63581 \
  --dart-define=SUPABASE_URL="https://nnexolilmowmcrwlgzfm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY"
```

3. Deployed `create-r2-upload-urls` uses AWS SDK `3.726.1` (no CRC32 signed URLs)
   and does **not** force signed `content-type` headers.
4. Admin app uses browser `fetch` + `Blob` for the PUT.

## Fix path B — proxy fallback (works around browser→R2)

New Edge Function: `proxy-r2-upload`

- Admin JWT required
- Server uploads bytes to R2 (no browser CORS to R2)
- Limited to **4 MB** per file (Edge Function body limit)
- App automatically falls back to proxy when direct R2 PUT fails and the file
  is ≤ 4 MB

Redeploy both:

```bash
supabase functions deploy create-r2-upload-urls --project-ref nnexolilmowmcrwlgzfm
supabase functions deploy proxy-r2-upload --project-ref nnexolilmowmcrwlgzfm
```

## Verify console

Success via direct PUT:

- `stage=r2_put OK`

Success via proxy fallback:

- `stage=r2_put FAILED ...`
- `falling back to proxy-r2-upload`
- `stage=proxy_put OK`
- `stage=db_insert OK`

Never paste full signed URLs into chat.
