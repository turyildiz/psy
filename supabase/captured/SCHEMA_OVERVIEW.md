# Live Supabase schema capture

Captured read-only on 2026-07-12 using the temporary `audit_readonly` PostgreSQL role. No DDL or data mutation was executed.

## Scope and format

The live server is PostgreSQL 17.6 while the installed `pg_dump` is 16.14, so a native schema dump was not possible without installing/upgrading software. The capture therefore uses PostgreSQL catalog exports. Together these files describe the complete current metadata for the application-facing `public` schema plus relevant `auth` and `storage` objects:

- `tables.csv` — tables, persistence, RLS enabled/forced state
- `columns.csv` — columns, formatted types, nullability, defaults, identity/generated state
- `enums.csv` — enum labels and order
- `constraints.csv` — PK, FK, unique, and check constraints
- `indexes.csv` — complete index definitions
- `policies.csv` — all RLS policies and expressions
- `rls-status.csv` — RLS state and policy count per table
- `triggers.csv` — non-internal triggers and target functions
- `functions.csv` and `function-definitions.csv` — signatures, privileges, security mode, and full definitions
- `publications.csv` and `publication-tables.csv` — Realtime/publication configuration
- `grants.csv` — table grants visible to the audit role
- `sequences.csv` and `extensions.csv` — supporting database objects
- `auth-settings-public.json` — public, non-secret Auth settings
- `storage-buckets-service-api.json` — existing buckets captured through the service API
- `storage-object-counts.csv` — object counts visible by bucket ID
- `row-counts-service-api.json` and `data-quality-service-api.json` — aggregate-only audit evidence; no row contents
- `role-privileges.csv` — proof that `audit_readonly` has SELECT but no INSERT/UPDATE/DELETE/CREATE privileges

## Application-facing tables

`blocked_handles`, `conversations`, `event_notifications`, `events`, `favorites`, `featured_sellers`, `follows`, `listings`, `messages`, `notice_posts`, `notice_reactions`, `profiles`, `reserved_handles`, `users`, and `vendor_events`.

All application-facing public tables have RLS enabled. `blocked_handles` and `reserved_handles` have zero policies, so normal anon/authenticated clients cannot read them. Several managed `auth` tables have RLS disabled; these are internal Supabase Auth tables rather than PostgREST application tables. See `rls-status.csv` for the exact list.

## Auth and user creation

`auth.users` has trigger `on_auth_user_created`, which executes `public.handle_new_user()`. The function creates `public.users`, derives or reserves a handle, and creates a `public.profiles` row. Email/password signup is enabled, email auto-confirm is disabled, and Google OAuth is disabled. See `triggers.csv`, `function-definitions.csv`, and `auth-settings-public.json`.

## Realtime

The `supabase_realtime` publication contains only `public.messages`, with insert/update/delete/truncate enabled. The current notice-wall client subscribes to `notice_posts`, but that table is not in this publication. See `publications.csv` and `publication-tables.csv`.

## Supabase Storage

Five buckets still exist: `avatars`, `listings`, `messages`, `events`, and `headers`. None has a file-size or MIME allowlist configured. `avatars`, `listings`, `events`, and `headers` are public; `messages` is private. Legacy application references remain in:

- `app/profile/edit/page.tsx` → `avatars`
- `app/listings/new/page.tsx` → `listings`
- `app/listing/[id]/edit/page.tsx` → `listings`

Storage policies also remain for all five buckets. The primary modal flows use Cloudflare R2, so Supabase Storage is now a legacy mixed path that conflicts with frozen V1 decisions.
