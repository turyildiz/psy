# Supabase Phase A audit report

**Capture date:** 2026-07-12  
**Scope source:** `docs/V1_DECISIONS.md`  
**Method:** catalog queries using a SELECT-only PostgreSQL role, plus aggregate service-API checks for rows hidden from that role by RLS. No DDL or database mutation was executed.

## Executive findings

1. **Critical listing INSERT RLS bypass:** two permissive INSERT policies are OR-combined. The ownership policy permits own-profile inserts, but `Suspended profiles cannot insert listings` separately permits an insert whenever the target profile is not suspended. A logged-in user can therefore insert a listing under another non-suspended profile ID.
2. **Critical SECURITY DEFINER RPC authorization gap:** `append_unread_for` and `remove_unread_for` are executable by anon/authenticated and update any conversation ID without checking that the caller participates in it. `increment_view_count` is also SECURITY DEFINER and executable publicly; that may be intentional, but it lacks an explicit safe `search_path`.
3. **All public application tables have RLS enabled**, but policy quality varies. No listed V1 application table has RLS disabled.
4. **Reactive moderation is not implemented in the data model:** the `user_role` enum already includes `admin` and `super_admin`, but no current `public.users` row has either role. `profiles.is_suspended` exists, but it is profile-level rather than account-level and is enforced only by the flawed listing INSERT policy. There is no durable app-level ban timestamp/reason or broad enforcement across messaging, RSVPs, notices, reactions, and profile updates.
5. **Per-user conversation hiding is missing.** The schema has only shared conversations and a shared `unread_for text[]`; the current DELETE policy and UI physically delete the shared conversation and cascade all messages.
6. **Tickets are missing** from `listing_category`; current values are clothing, accessories, gear, art, and other.
7. **Sold status already exists.** `listing_status` contains draft, pending, active, sold, and rejected. All 25 current listings are active.
8. **Email opt-out state already exists.** `public.users.email_notifications boolean default true` matches V1, although no application email sender currently uses it.
9. **Reserved-handle enforcement is incomplete.** `blocked_handles` contains 56 rows but has RLS enabled with no policies, so the signup page's client query cannot read it. The server signup route checks only profile uniqueness. The auth trigger accepts metadata handles without checking `blocked_handles`. Handle uniqueness is case-sensitive, so `Alice` and `alice` can coexist.
10. **Current code assumes one profile per user, but the database does not enforce it.** Three user IDs currently have multiple profile rows. Calls using `.eq("user_id", ...).single()` can fail or behave inconsistently.
11. **Realtime is incomplete for the festival layer.** Only `messages` is published. The notice-wall client subscribes to `notice_posts`, which is absent from `supabase_realtime`.
12. **Supabase Storage remains live and unsecured by bucket limits.** Five legacy buckets exist and have no file-size or MIME allowlists. Legacy code still writes `avatars` and `listings`, contrary to the R2-only V1 decision.

## RLS audit by V1 table

| Table | RLS | Finding |
|---|---|---|
| `profiles` | Enabled | Public SELECT exposes every column, including `user_id` and `is_suspended`. INSERT/UPDATE ownership is based on `auth.uid() = user_id`. No ban enforcement. |
| `listings` | Enabled | **Critical:** permissive INSERT policies combine with OR and allow impersonated inserts under any non-suspended profile. Public reads correctly limit non-owners to active/sold. Owner UPDATE is allowed. |
| `conversations` | Enabled | Participants can read and physically delete shared rows. Buyer can create, but policy does not prevent self-conversations or validate a listing's seller. No seller-side insert, no ban check, no soft-delete state. |
| `messages` | Enabled | Participants can read/send text messages. Base INSERT policy checks sender ownership and conversation participation. Unread RPCs bypass these checks. No 2,000-character database maximum. |
| `events` | Enabled | Public SELECT only. Mutations require service role, matching the current controlled event-import workflow. |
| `vendor_events` | Enabled | Public SELECT; users can insert/delete rows for their own profiles. No ban check. |
| `notice_posts` | Enabled | Public SELECT; authenticated owners can insert/delete their own posts. No admin-delete policy and no ban check. |
| `notice_reactions` | Enabled | Public SELECT; users can add/remove their own reactions. No ban check. |
| `users` | Enabled | Users can read their own row; service role can manage all. No policy/helper for super-admin/admin moderation. |
| `blocked_handles` | Enabled, 0 policies | Deny-all to anon/authenticated, breaking the client availability check. |
| `reserved_handles` | Enabled, 0 policies | Correctly private from clients, but the trigger trusts metadata handles before reservation logic. |

### RLS-disabled tables

No application-facing `public` table has RLS disabled. Managed Auth tables with RLS disabled are: `auth.custom_oauth_providers`, `auth.oauth_authorizations`, `auth.oauth_client_states`, `auth.oauth_clients`, `auth.oauth_consents`, `auth.webauthn_challenges`, and `auth.webauthn_credentials`. These are Supabase-managed internal tables and should not be modified by this app migration plan.

## Missing V1 state

| Frozen requirement | Current state | Gap |
|---|---|---|
| One super-admin and admins | Enum values exist; zero assigned roles | Need assignment invariant, authorization helpers, and policies/server paths. |
| Ban/unban users | `profiles.is_suspended` only | Need account-level ban state and enforcement across all write paths; optionally synchronize Supabase Auth `banned_until` from trusted server code. |
| Unpublish listings | Status supports draft/active/sold | Need a clearly defined unpublished state or reuse `draft`, plus admin-authorized mutation. |
| Sold listings | `sold` already exists | No schema gap; application flow is missing. |
| Per-user conversation hiding | Missing | Add participant-state table or participant-specific hidden timestamps. Never delete shared conversation/message rows from client UI. |
| New-message email opt-out | `users.email_notifications default true` | State exists; email delivery and setting UI are application work. |
| Tickets category | Missing enum value | Add `ticket`/`tickets` consistently; proposal uses `ticket`. |
| Reactive notice moderation | Owner delete only | Add admin delete policy/helper. |

## Constraints and validation gaps

- No unique constraint on `profiles.user_id`; three duplicate-user groups already exist despite code using `.single()`.
- Profile handle uniqueness is case-sensitive; no database check against the blocked/reserved route list.
- Listing arrays have no constraints for 1–5 images, at least one shipping target, maximum 10 tags, or tag length/format.
- Listing image URLs and profile avatar/header URLs have no provider/domain constraint; mixed Supabase and R2 URLs are accepted.
- Message body requires non-empty trimmed text but has no 2,000-character maximum.
- Conversations allow buyer=seller and do not guarantee that `seller_profile_id` owns `listing_id`.
- `unread_for` is `text[]` although profile IDs are UUIDs; RPC argument `profile_id` is text.
- SECURITY DEFINER functions do not set a safe fixed `search_path`.
- Storage buckets have no MIME or file-size restrictions, and upload policies allow any authenticated user to upload without an owner-folder check.
- Notice titles default to an empty string with no length constraint; contact handle is optional. Both existing notice posts lack contact handles, which may be acceptable if contact is inferred from the author profile.

## Dead or superseded schema candidates

These are candidates for later removal only after code/reference verification; Phase A does not recommend immediate drops:

- `favorites` — zero rows; explicitly out of V1.
- `follows` — one row; explicitly out of V1.
- `featured_sellers` and `listings.is_featured` — old promotion/display concept; no current DB query found for `featured_sellers`; admin featured tooling is out of V1.
- `event_notifications` — zero rows and no application query found.
- Listing moderation remnants: `pending` and `rejected` enum values, `admin_notes`, `submitted_at`, and `idx_listings_status_submitted` conflict with direct-publish V1. Keep temporarily because removing enum values is disruptive.
- `users.stripe_account_id` — payment integration is out of V1.
- `profiles.is_verified` — verified identities are not frozen V1 scope, though the mapper reads it.
- Supabase Storage buckets and policies — superseded by R2-only V1, but legacy application routes still reference them and must be migrated first.
- `reserved_handles` — currently empty but still used by `handle_new_user`; do not drop until the final reserved-handle design is implemented.

## Aggregate evidence

- 25 listings: all active; none have zero images, more than five images, empty shipping arrays, or more than ten tags.
- 9 profiles; three user IDs have multiple profiles; no case-insensitive duplicate handles currently exist.
- 6 public user rows; zero admins, zero super-admins, and zero users opted out of email notifications.
- 3 conversations and 11 messages; two conversations are profile-to-profile with no listing, which the current UI supports.
- 21 events, 3 RSVPs, 2 notice posts, and 2 reactions.
- 56 blocked handles, but normal clients cannot read them under current RLS.

## Capture limitations

- PostgreSQL catalog metadata is complete for the selected `public`, `auth`, and `storage` schemas. A native `pg_dump` was not created because the installed client major version is older than the server.
- The SELECT-only PostgreSQL role is still subject to RLS, so aggregate data checks were repeated through the existing service API and saved only as counts. No record contents were persisted.
- Dashboard-only settings such as every Auth redirect URL, SMTP configuration, and Realtime service settings are not all represented in PostgreSQL. Public Auth provider settings were captured; secret/dashboard configuration remains an operational verification item.
