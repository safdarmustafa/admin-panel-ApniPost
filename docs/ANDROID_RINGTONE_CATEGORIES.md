# Android: read ringtone categories from Supabase

The admin panel now manages ringtone categories in a new table,
`public.ringtone_categories`. The Ringtones screen should build its chips from
this table, so new categories, renames, Hindi labels and chip order all come
from the admin panel with no app update.

## Table (already live)

| Column | Type | Notes |
|---|---|---|
| `name` | text, unique | English name. `ringtones.category` references it. |
| `hindi_name` | text, nullable | Chip label. Fall back to `name` when null. |
| `display_order` | int | Chip order, ascending. |

RLS: `anon` and `authenticated` can SELECT. Nobody but admins can write.

## What to change on the Ringtones screen

1. **Load categories** when the screen opens:
   ```
   from("ringtone_categories")
     .select("name, hindi_name, display_order")
     .order("display_order")
   ```
2. **Load ringtones** as today:
   `from("ringtones").select(...).order("created_at", desc)`.
3. **Chips**:
   - "सभी" (All) first. The app adds it; it is never stored.
   - Then one chip per category in `display_order`, labelled
     `hindi_name ?: name`.
   - **Hide categories that have no ringtones** (the admin may create a
     category before uploading to it).
4. **Filter**: tapping a chip shows ringtones where `category == name`. The
   foreign key keeps names identical, so exact match is safe.
5. Remove the hardcoded English → Hindi label map (Durga → दुर्गा, …). The
   labels are in `hindi_name` now.

## Rollout order

The table and data already exist, so the app update can ship any time. Older
app versions keep working: they still read `ringtones` only.
