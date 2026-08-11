# Temporary verification tools

These scripts are **not** part of the production Flutter app.

## Phase 4A — Edge Function presign verification

File: `tool/test_r2_upload_function.dart`

Verifies deployed `create-r2-upload-urls` generates a presigned PUT URL.  
Does **not** upload bytes to R2.

### Run

```bash
cd /path/to/apnipost_admin

export SUPABASE_URL="https://nnexolilmowmcrwlgzfm.supabase.co"
export SUPABASE_ANON_KEY="<your-anon-or-publishable-key>"
export ADMIN_EMAIL="<admin-email>"
export ADMIN_PASSWORD="<admin-password>"

dart run tool/test_r2_upload_function.dart
```

### Notes

- Never commit credentials.
- JWT / Authorization / `uploadUrl` are redacted in output.
- Expected success: HTTP 200, objectKey starts with `updesh/`, publicUrl starts with `https://media.apnipost.com/updesh/`.
