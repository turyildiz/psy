# Proposed Supabase migration plan — NOT APPLIED

**Prepared:** 2026-07-12  
**Binding scope:** `docs/V1_DECISIONS.md`  
**Status:** proposal only. Every statement below requires review before execution.

The chunks are ordered to preserve compatibility. Each chunk is independently reviewable and should be applied in its own migration only after its dependencies and preflight checks pass. SQL uses explicit schema qualification and transactions where PostgreSQL permits it.

## CHUNK 0 — Immediate critical vulnerability closure

**Purpose:** Close only the two confirmed critical vulnerabilities, with no dependency on the later role, moderation, or soft-delete work:

1. Replace the two permissive listing INSERT policies with one policy requiring both profile ownership and non-suspension.
2. Harden the existing unread RPCs so only conversation participants can call them, constrain the target profile, set a safe `search_path`, and remove anonymous/public execution.

**Risk:** Medium. This changes authorization but preserves the intended application operations.

**What could break:** Listing INSERTs using another user's profile will begin failing, as intended. Unread RPC calls without an authenticated participant session, with the wrong profile ID, or against another conversation will fail, as intended.

### Apply SQL

```sql
begin;

-- FIX A: replace permissive-OR listing INSERT policies with one combined policy.
drop policy if exists "Suspended profiles cannot insert listings" on public.listings;
drop policy if exists "Users can create listings for their own profiles" on public.listings;
drop policy if exists "Owners create listings for own active profile" on public.listings;

create policy "Owners create listings for own active profile"
on public.listings
for insert
to authenticated
with check (
  profile_id in (
    select p.id
    from public.profiles p
    where p.user_id = auth.uid()
      and p.is_suspended = false
  )
);

-- FIX B: retain current RPC signatures for application compatibility,
-- but authorize the caller and target profile explicitly.
create or replace function public.append_unread_for(
  conv_id uuid,
  profile_id text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  caller_profile_id uuid;
  target_profile_id uuid := profile_id::uuid;
begin
  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = conv_id
  limit 1;

  if caller_profile_id is null then
    raise exception 'Not a conversation participant';
  end if;

  if not exists (
    select 1
    from public.conversations c
    where c.id = conv_id
      and target_profile_id in (c.buyer_profile_id, c.seller_profile_id)
      and target_profile_id <> caller_profile_id
  ) then
    raise exception 'Invalid unread recipient';
  end if;

  update public.conversations c
  set unread_for = array_append(
    coalesce(c.unread_for, '{}'::text[]),
    target_profile_id::text
  )
  where c.id = conv_id
    and not (
      coalesce(c.unread_for, '{}'::text[])
      @> array[target_profile_id::text]
    );
end;
$$;

create or replace function public.remove_unread_for(
  conv_id uuid,
  profile_id text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  caller_profile_id uuid;
  target_profile_id uuid := profile_id::uuid;
begin
  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = conv_id
  limit 1;

  if caller_profile_id is null then
    raise exception 'Not a conversation participant';
  end if;

  if target_profile_id <> caller_profile_id then
    raise exception 'Users may only clear their own unread state';
  end if;

  update public.conversations c
  set unread_for = array_remove(
    coalesce(c.unread_for, '{}'::text[]),
    target_profile_id::text
  )
  where c.id = conv_id;
end;
$$;

revoke all on function public.append_unread_for(uuid, text) from public;
revoke all on function public.remove_unread_for(uuid, text) from public;
revoke execute on function public.append_unread_for(uuid, text) from anon;
revoke execute on function public.remove_unread_for(uuid, text) from anon;

grant execute on function public.append_unread_for(uuid, text)
  to authenticated, service_role;
grant execute on function public.remove_unread_for(uuid, text)
  to authenticated, service_role;

commit;
```

### Rollback SQL

> Emergency rollback only: this restores the captured vulnerable definitions and policies.

```sql
begin;

drop policy if exists "Owners create listings for own active profile" on public.listings;

create policy "Suspended profiles cannot insert listings"
on public.listings
for insert
to public
with check (
  not exists (
    select 1
    from public.profiles
    where profiles.id = listings.profile_id
      and profiles.is_suspended = true
  )
);

create policy "Users can create listings for their own profiles"
on public.listings
for insert
to public
with check (
  profile_id in (
    select profiles.id
    from public.profiles
    where profiles.user_id = auth.uid()
  )
);

create or replace function public.append_unread_for(
  conv_id uuid,
  profile_id text
)
returns void
language sql
security definer
as $$
  update conversations
  set unread_for = array_append(unread_for, profile_id)
  where id = conv_id
    and not (unread_for @> array[profile_id]);
$$;

create or replace function public.remove_unread_for(
  conv_id uuid,
  profile_id text
)
returns void
language sql
security definer
as $$
  update conversations
  set unread_for = array_remove(unread_for, profile_id)
  where id = conv_id;
$$;

grant execute on function public.append_unread_for(uuid, text)
  to public, anon, authenticated, service_role;
grant execute on function public.remove_unread_for(uuid, text)
  to public, anon, authenticated, service_role;

commit;
```

**Application queries checked:**

- `components/NewListingModal.tsx`: INSERT into `listings` using the signed-in owner's `profileId` continues to pass when that profile is not suspended.
- `app/listings/new/page.tsx`: resolves the signed-in user's profile, then INSERTs the listing under that profile; continues to pass when not suspended.
- `components/MessagesInbox.tsx`: `remove_unread_for` passes the current user's own profile ID for the active conversation; continues to pass.
- `components/MessagesInbox.tsx`: `append_unread_for` passes the other conversation participant's profile ID after sending a message; continues to pass.

---

## CHUNK 1 — Admin roles and account-level ban state

**Purpose:** Bootstrap the single `super_admin`, provide super-admin-only admin appointment/removal, and provide admin/super-admin ban/unban with timestamp, reason, and banning admin. `profiles.is_suspended` is updated only as a temporary compatibility bridge for the Chunk 0 listing policy.

**Risk:** Medium/High because this creates privileged SECURITY DEFINER RPCs and assigns the first super-admin.

**Apply SQL:** [`chunks/chunk-1-admin-ban-apply.sql`](./chunks/chunk-1-admin-ban-apply.sql)  
**Rollback SQL:** [`chunks/chunk-1-admin-ban-rollback.sql`](./chunks/chunk-1-admin-ban-rollback.sql)

**What could break:** A wrong bootstrap UUID would abort the transaction. Banned accounts remain able to use write paths not yet updated by later RLS chunks; Chunk 1 creates authoritative state and safe RPCs, while full cross-table enforcement remains in Chunk 6. The current listing INSERT policy is immediately compatible because the ban RPC also updates `profiles.is_suspended`.

**Application queries checked:**

- Existing public/auth/profile/listing/message/festival queries do not query `public.users` and are unchanged.
- The existing `Users can read their own record` policy remains, so future settings reads of `role` and `email_notifications` continue.
- Chunk 0 owner listing creation still succeeds for normal accounts; `admin_ban_user` sets `profiles.is_suspended=true`, so banned accounts fail that policy.
- `app/api/auth/signup/route.ts` and `handle_new_user()` continue creating `public.users` with the default `user` role and null ban columns.
- No current application code calls these new RPCs; moderation UI/server routes must use the RPCs rather than direct table updates.

---

## CHUNK 2 — Reserved handles and profile uniqueness

**Purpose:** Reserve all current and frozen/planned V1 top-level routes, make the list readable by the existing signup client, enforce it in a database trigger for every write path, add case-insensitive handle uniqueness, and enforce one profile per user.

**Risk:** Medium. Preflight currently passes: zero duplicate users, zero case-insensitive handle collisions, and zero invalid existing handles.

**Apply SQL:** [`chunks/chunk-2-handles-profiles-apply.sql`](./chunks/chunk-2-handles-profiles-apply.sql)  
**Rollback SQL:** [`chunks/chunk-2-handles-profiles-rollback.sql`](./chunks/chunk-2-handles-profiles-rollback.sql)

**Compatibility checks:**

- `app/signup/page.tsx` can read `blocked_handles(handle)` through its new column grant and SELECT policy.
- `app/api/auth/signup/route.ts` still creates a temporary `user_<uuid>` profile via Auth and then updates it through the service role; the trigger validates the final handle and the route already deletes the Auth user if that update fails.
- `handle_new_user()` retains temporary-handle/reservation behavior, gains a fixed `search_path`, and its profile INSERT is validated by the new trigger.
- Existing exact-handle checks continue. Races and case variants are closed by the database unique index.

---

## CHUNK 3 — Ticket category and core validation constraints

**Purpose:** Add `ticket` to the listing category enum; enforce listing image, shipping, and tag limits; enforce the 2,000-character message limit; prevent self-conversations; and ensure a listing-linked conversation names the listing owner as seller.

**Risk:** Medium. A read-only preflight currently finds one listing-seller mismatch and all other violation counts at zero. The apply transaction intentionally aborts until that row is reviewed and corrected or removed.

**Apply SQL:** [`chunks/chunk-3-tickets-validation-apply.sql`](./chunks/chunk-3-tickets-validation-apply.sql)  
**Rollback SQL:** [`chunks/chunk-3-tickets-validation-rollback.sql`](./chunks/chunk-3-tickets-validation-rollback.sql)

**Compatibility checks:**

- Both listing creation paths already require at least one shipping destination and cap tags at 10. Tag inputs normalize to lowercase alphanumeric text, which is accepted by the proposed rule.
- Both current image uploaders allow up to eight selections, while Chunk 3 enforces the frozen maximum of five. Existing rows pass, but the UI must be reduced to five before users can attempt six-to-eight-image listings; until then those inserts will fail safely at the database boundary.
- Existing listing categories remain unchanged. The UI must add `ticket` before users can select the new category.
- `MessagesInbox` trims and rejects empty messages; normal messages up to 2,000 characters continue to insert. The UI does not yet expose a 2,000-character counter/maxLength.
- Listing-detail conversations set `seller_profile_id` from the displayed listing seller and pass the ownership trigger.
- Direct profile conversations use `listing_id = null` and bypass only the listing-owner check while still requiring buyer and seller to differ.

---

## CHUNK 4 — Admin listing and notice-wall moderation actions

**Purpose:** Add the narrowly scoped reactive moderation actions frozen for V1. Active admins and the single super-admin can unpublish or republish any listing and delete any notice-wall post. Chunk 0 already closed the listing INSERT vulnerability, so Chunk 4 does not replace listing RLS policies.

**Risk:** Medium. Listing moderation changes visibility by moving a listing between `draft` and `active`. Notice-post deletion is destructive and cascades to all reactions on that post.

**Dependencies:** Chunk 1 must be active because every RPC authorizes through `public.current_user_is_admin()`, which permits only `admin`/`super_admin` roles and excludes accounts with `banned_at` set.

**Apply SQL:** [`chunks/chunk-4-admin-moderation-apply.sql`](./chunks/chunk-4-admin-moderation-apply.sql)

**Rollback SQL:** [`chunks/chunk-4-admin-moderation-rollback.sql`](./chunks/chunk-4-admin-moderation-rollback.sql)

**What could break:** Existing application queries and RLS policies are unchanged. Admin callers receive an exception for a missing listing/post ID or when the caller is anonymous, non-admin, or banned. Deleting a notice post also deletes its reactions through the validated `notice_reactions_post_id_fkey ... ON DELETE CASCADE` relationship. Rollback removes the RPCs but cannot restore posts/reactions deleted while Chunk 4 was active or reverse listing status changes already made.

**Security and permission checks:**

- All three functions are `SECURITY DEFINER` with `search_path = pg_catalog, public, auth` and schema-qualified table/function references.
- `public.current_user_is_admin()` is checked inside every RPC; its Chunk 1 definition returns false for banned admins.
- Default `PUBLIC` execution is revoked, `anon` execution is explicitly revoked to cover Supabase default grants, and execution is granted only to `authenticated` and `service_role`. The internal admin check still applies to every invocation.
- No direct admin UPDATE/DELETE RLS policy is added; moderation authority exists only through these RPCs.

**Application queries checked:**

- `components/NewListingModal.tsx` and `app/listings/new/page.tsx`: listing INSERT behavior is unchanged and remains protected by the combined Chunk 0 policy.
- `components/EditListingModal.tsx` and `app/listing/[id]/edit/page.tsx`: owner listing edits remain direct UPDATEs and are unchanged.
- `app/[handle]/page.tsx`: the owner's existing direct status change to `draft` remains unchanged.
- Homepage, browse, category, profile, and listing-detail SELECTs already filter/read active or sold listings. Admin unpublish changes a target to `draft`, hiding it from public reads; republish restores it to `active`.
- `app/festivals/[slug]/page.tsx`: owners continue deleting their own notice posts through the existing direct DELETE policy. Future admin tooling must call `admin_delete_notice_post`; the current joined `notice_reactions` read remains valid after cascade deletion.
- No current application code calls the new RPCs, so adding them is backward-compatible. Admin UI/server integration remains a later application task.

**Known limitation for review:** The existing owner UPDATE policy does not restrict status transitions. Although the current owner UI only changes a listing to `draft`, an owner can technically issue a direct API UPDATE back to `active` after an admin unpublishes it. If admin unpublishing must be durable against a malicious owner, a separate moderation-state field or status-transition guard is required; that is not added in this narrowly scoped RPC chunk.

---

## CHUNK 5 — Per-user conversation hiding

**Purpose:** Replace participant hard deletion of shared conversations with per-user hiding. A hidden conversation disappears only for the participant who hid it; the shared conversation and messages remain available to the other participant and to trusted service-role/admin dispute tooling. Chunk 0 already hardened the unread RPCs, so Chunk 5 does not replace them.

**Risk:** High. This removes the current participant DELETE capability, changes participant conversation/message visibility, and requires the inbox delete control to call a new RPC instead of issuing a table DELETE.

**Dependencies:** Chunks 0–3 must remain active. In particular, the current message INSERT policy and Chunk 3 conversation/message constraints ensure that the new-message restoration trigger receives a valid participant sender.

**Apply SQL:** [`chunks/chunk-5-conversation-hiding-apply.sql`](./chunks/chunk-5-conversation-hiding-apply.sql)

**Rollback SQL:** [`chunks/chunk-5-conversation-hiding-rollback.sql`](./chunks/chunk-5-conversation-hiding-rollback.sql)

**State and behavior:**

- `conversation_participant_state` stores one row per conversation/profile, with nullable `hidden_at` plus creation/update timestamps. Both foreign keys cascade only when trusted maintenance physically removes a conversation or profile.
- Authenticated clients can SELECT only their own state. They receive no direct INSERT/UPDATE/DELETE grant; `hide_conversation(uuid)` and `unhide_conversation(uuid)` perform participant authorization and state mutation. `find_and_unhide_conversation(uuid, uuid)` safely finds a caller-participating listing/direct conversation despite hidden-row RLS, restores it for that caller, and returns its ID or null so existing contact flows can create only when no conversation exists.
- The participant conversation SELECT policy excludes a row only when the current user's own state has `hidden_at` set. The other participant remains unaffected. Existing message SELECT authorization resolves through conversation visibility, so the hiding participant also stops seeing the hidden thread's messages.
- The captured participant DELETE policy is dropped and DELETE is revoked from `PUBLIC`, `anon`, and `authenticated`. Trusted `service_role` maintenance remains capable of physical deletion, but ordinary participants cannot cascade-delete shared messages.
- An AFTER INSERT message trigger clears `hidden_at` only for the message recipient. It does not change the sender's independent state. The restored conversation becomes visible on the recipient's next authorized query.
- The three participant RPCs are `SECURITY DEFINER` with `search_path = pg_catalog, public, auth`; the trigger function uses `pg_catalog, public`. Default `PUBLIC` execution and explicit `anon` execution are revoked. Participant RPCs are granted to `authenticated`/`service_role`; the trigger function is not executable by `anon` or `authenticated`.

**Rollback behavior:** Rollback removes the trigger/RPCs/state table, restores the captured participant SELECT policy, and restores the captured direct DELETE grant/policy. It cannot reconstruct state rows after rollback and intentionally re-enables the old destructive delete behavior, so rollback should be used only as an emergency compatibility measure.

**Application compatibility checks:**

- `components/MessagesInbox.tsx` conversation SELECT requires no query change: the replacement RLS policy automatically omits conversations hidden by the current user. The other participant's same query continues returning the shared row.
- `components/MessagesInbox.tsx` message SELECT/INSERT and the Chunk 0 `append_unread_for`/`remove_unread_for` calls are unchanged. Hidden messages become inaccessible only to the hiding participant because the message SELECT policy resolves through visible conversations.
- The current `deleteConv()` implementation is **not compatible as written**: it calls `supabase.from("conversations").delete()`, ignores the returned error, and removes the row optimistically. It must be changed to `supabase.rpc("hide_conversation", { target_conversation_id: id })`, handle errors, and label the action as Hide rather than Delete before or alongside applying Chunk 5.
- `components/layout/Header.tsx` and the profile inbox badge query use `conversations`; hidden rows therefore stop contributing to unread counts automatically. After a new incoming message clears the recipient's hidden state and Chunk 0 appends unread state, the conversation contributes again.
- The current inbox subscribes only to INSERTs for the active thread and fetches its conversation list once. A newly restored hidden conversation is visible after reload/navigation, but immediate live reappearance while the inbox is already open requires a later refetch/global Realtime subscription. Chunk 7's publication work should account for this state change.
- `app/listing/[id]/page.tsx` and `app/[handle]/page.tsx` must replace their base-table existing-conversation lookup with `find_and_unhide_conversation`. The RPC derives the caller profile from `auth.uid()`, validates the target profile/listing relationship, selects only a conversation containing the caller, clears only the caller's hidden state, and returns null when the normal INSERT path should run. This avoids listing uniqueness collisions and duplicate direct-profile conversations after re-contact.
- Trusted service-role/admin dispute tooling continues to see the retained conversation and messages because no shared row is deleted. This chunk does not add a direct authenticated-admin read policy.

---

## CHUNK 6 — Ban enforcement and durable listing moderation

**Purpose:** Make the Chunk 1 account ban authoritative across every in-scope community write path, and close the Chunk 4 durability gap that allowed an owner to reactivate an admin-unpublished listing. Reads remain unchanged.

**Risk:** High. This replaces eighteen write policies, replaces five messaging/unread RPC bodies, upgrades the two Chunk 4 listing moderation RPCs, adds listing moderation metadata, and installs a listing UPDATE guard.

**Dependencies:** Chunks 1, 4, and 5 must remain active. `public.current_user_is_banned()` and `public.current_user_is_admin()` are the authorization sources; Chunk 4 supplies the moderation RPCs being upgraded; Chunk 5 supplies the participant-state RPCs being upgraded.

**Read-only preflight:** [`chunks/chunk-6-preflight.sql`](./chunks/chunk-6-preflight.sql)

**Apply SQL:** [`chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql`](./chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql)

**Rollback SQL:** [`chunks/chunk-6-ban-enforcement-durable-moderation-rollback.sql`](./chunks/chunk-6-ban-enforcement-durable-moderation-rollback.sql)

### Preflight result and data handling

The read-only service-level check found six app users, zero currently banned accounts, zero `admin` accounts, one `super_admin`, and 26 listings: 25 active and one draft. No existing row violates a new SQL constraint because the moderation columns are introduced nullable.

The one existing draft (`Testing`, ID `f4ebbcb1-d18c-43f2-8a5f-83c4a7b315bd`) was reviewed by the owner and confirmed to be an ordinary owner draft. It requires no moderation backfill or post-apply action. The preflight continues listing all drafts because Chunk 4 stored only `status = draft`; any future pre-Chunk-6 admin-unpublished row would still require explicit classification rather than an unsafe bulk backfill.

### Durable moderation mechanism

Chunk 6 uses explicit moderation state rather than a status-only transition rule:

- `listings.admin_unpublished_at` is the authoritative durable marker.
- `listings.admin_unpublished_by` records the acting admin and uses `ON DELETE SET NULL`; the timestamp remains authoritative if that admin account is later removed.
- `admin_unpublish_listing` atomically sets `status = draft` and both moderation fields.
- `admin_republish_listing` is the only normal operation that clears the marker and returns the listing to `active`. It refuses rows that are not admin-unpublished, so it cannot accidentally publish an owner's ordinary draft.
- A BEFORE UPDATE trigger rejects any non-active-admin attempt to alter the moderation fields or move a marked listing away from `draft`. This also blocks `sold`, which is publicly readable under the current SELECT policy and would otherwise be a visibility bypass.
- The owner UPDATE policy independently requires a marked row to remain `draft`, providing RLS defense in depth; the owner DELETE policy also excludes marked rows so the moderated record/audit state cannot be removed and reinserted under the same ID.
- Owner edits to title, description, price, images, and similar fields remain possible while the listing stays admin-unpublished/draft; only status changes, owner deletion, and moderation-state tampering are blocked.

This is preferable to checking only `OLD.status = draft`: status alone cannot distinguish an owner's draft from an admin moderation action, carries no actor/timestamp audit data, and would make legitimate owner draft-to-active transitions impossible to distinguish from bypass attempts.

### Ban enforcement coverage

Banned authenticated accounts retain reads but are blocked from:

- profile INSERT and UPDATE;
- listing INSERT, UPDATE, and owner draft DELETE;
- conversation INSERT;
- message INSERT;
- unread-state mutation through `append_unread_for` and `remove_unread_for`;
- conversation hide, unhide, and find-and-restore through all three Chunk 5 RPCs;
- RSVP INSERT and DELETE;
- notice-post INSERT and owner DELETE;
- reaction INSERT and DELETE.
- dormant favorites, follows, and event-notification writes that remain in the schema until Chunk 9.

Each replacement policy is scoped to `authenticated` and checks `not public.current_user_is_banned()` together with the existing ownership/participant condition. Every replaced `SECURITY DEFINER` function keeps the established fixed search path, internal authorization, explicit `PUBLIC` revocation, explicit `anon` revocation, and intended `authenticated`/`service_role` grants. The moderation trigger function is not executable by `anon` or `authenticated`.

The legacy favorites policy is split into an unchanged own-row read policy plus a ban-gated write policy, so reads remain available. Existing follows/event-notification read policies are unchanged. The Chunk 4 `admin_delete_notice_post` RPC is unchanged because `current_user_is_admin()` already returns false for banned admins. The system new-message trigger may still unhide a banned recipient's conversation because that write is caused by the unbanned sender/system, not by the banned recipient; the banned recipient may continue reading.

### Current UI behavior for a banned account

The database will reject all listed writes, but current UI feedback is inconsistent:

| Flow | Current banned-user experience after Chunk 6 |
|---|---|
| New listing modal/page | Shows the returned insert error, but image uploads happen first and may leave orphaned R2/Supabase Storage objects. |
| Edit listing modal/page | Shows a generic “Failed to save” message. |
| Profile edit modal/page | Shows a generic “Failed to save changes” message. Password changes use Supabase Auth and are outside this public-schema migration. |
| Owner “Remove listing” control | Silently removes the card locally even though the rejected status UPDATE did not persist; it returns on reload. |
| Send message | Silent failure: the code ignores both Promise results, clears the composer, and optimistically changes unread state. No message row is created. |
| Mark message read | Silent failure: the code ignores the RPC error and optimistically clears local unread state; server state remains unchanged. |
| Hide conversation | Shows the existing generic “Could not hide this conversation” error and keeps the thread visible. |
| Listing/direct-profile Contact | The find-and-restore RPC error stops loading but is not shown. New conversation INSERT errors are also not surfaced. |
| RSVP add/change/remove | Silent and potentially misleading: errors are ignored and local RSVP state may change until the next refetch/reload. |
| Create notice post | Silent failure; the form is cleared and closed before refetch shows that no post was created. |
| Add/remove reaction or delete own notice post | Silent failure followed by refetch; no explicit error is shown. |

These are compatibility findings, not reasons to weaken database enforcement. A coordinated UI follow-up should query ban state to disable controls and should handle every mutation error explicitly. Chunk 6 itself changes no application code.

### Boundary outside this SQL chunk

This migration blocks the specified public-schema writes. It does not by itself block Supabase Auth password changes, revoke an already-issued JWT, or prevent object uploads performed before a rejected metadata write. Trusted ban tooling should continue synchronizing Auth `banned_until`, and R2/Supabase Storage upload endpoints/policies need their own ban checks to prevent orphan uploads.

### Rollback behavior

Rollback restores the exact captured pre-Chunk-6 policies and RPC bodies, restores the original Chunk 4 status-only moderation functions, removes the guard, and drops the two moderation columns. It does not reverse user-visible status changes made while Chunk 6 was active. Any listing still draft after rollback becomes owner-reactivatable again, and all ban-enforcement gaps intentionally return.

---

## CHUNK 7 — Realtime publication alignment

**Purpose:** Publish the V1 tables that current clients subscribe to or need for live unread state.

**Risk:** Medium due to increased Realtime traffic and data exposure through change payloads; RLS must remain enabled.

**What could break:** Realtime quotas/traffic may increase. Clients must subscribe only to required events and filters.

```sql
begin;

alter publication supabase_realtime add table public.notice_posts;
alter publication supabase_realtime add table public.notice_reactions;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.conversation_participant_state;

commit;
```

Before applying, use conditional catalog checks or migration guards if tables may already be members. `public.messages` is already published.

**Queries/subscriptions checked:** `components/MessagesInbox.tsx` subscribes to message INSERTs; festival detail subscribes to notice-post INSERTs. Conversation publication supports unread/last-message changes without changing ordinary PostgREST queries.

---

## CHUNK 8 — Retire legacy Supabase Storage after R2 migration

**Purpose:** Enforce the frozen R2-only decision after all legacy application paths and stored URLs have been migrated.

**Risk:** High and potentially destructive.

**Dependencies:** Application deployment must first remove all `supabase.storage.from(...)` paths and migrate required objects/URLs to R2. A verified backup is mandatory.

**What could break:** Existing avatar/header/listing/event URLs may stop loading. Direct SQL deletion from `storage.objects` is not recommended because it may leave physical objects; bucket/object removal should use the Supabase Storage API.

```sql
-- Read-only preflight: must be reviewed before any API deletion.
select bucket_id, count(*) from storage.objects group by bucket_id order by bucket_id;

-- Apply only after Storage API deletion of objects and buckets is verified.
begin;

drop policy if exists "Avatar public read" on storage.objects;
drop policy if exists "Avatar upload" on storage.objects;
drop policy if exists "Event cover public read" on storage.objects;
drop policy if exists "Header public read" on storage.objects;
drop policy if exists "Header upload" on storage.objects;
drop policy if exists "Listing image public read" on storage.objects;
drop policy if exists "Listing image upload" on storage.objects;
drop policy if exists "Message image read by participants" on storage.objects;
drop policy if exists "Message image upload" on storage.objects;

commit;
```

The actual deletion of `avatars`, `listings`, `messages`, `events`, and `headers` must be a separately approved Storage API operation, not hidden inside this SQL migration.

---

## CHUNK 9 — Remove superseded feature schema after code cleanup

**Purpose:** Remove dead/out-of-V1 structures only after all application and reporting references have been eliminated.

**Risk:** High and destructive.

**Dependencies:** Full backups; explicit data-retention decision for the one existing follow and featured-seller rows; code no longer reads `is_featured`, `is_verified`, or writes `submitted_at`; payment roadmap confirms no near-term need for `stripe_account_id`.

**What could break:** Historical data, old scripts, or future V2 work may depend on these objects. Enum value removal requires a table rewrite and is intentionally not proposed for V1 launch.

```sql
begin;

-- Apply only after explicit approval and data export.
drop table if exists public.favorites;
drop table if exists public.follows;
drop table if exists public.featured_sellers;
drop table if exists public.event_notifications;

alter table public.listings
  drop column if exists admin_notes,
  drop column if exists submitted_at,
  drop column if exists is_featured;

alter table public.users
  drop column if exists stripe_account_id;

alter table public.profiles
  drop column if exists is_verified;

commit;
```

Keep `pending` and `rejected` enum labels until a later maintenance window; PostgreSQL enum-value removal requires replacing the enum type and rewriting the dependent column.

---

## Summary

| Chunk | Purpose | Risk | Dependencies |
|---:|---|---|---|
| 0 | Immediate listing INSERT and unread-RPC vulnerability closure | Medium | None |
| 1 | Account bans and role helper functions | Medium | None |
| 2 | Reserved handles, case-insensitive handles, one-profile invariant | High → Low after cleanup | Manual resolution of three duplicate-profile groups |
| 3 | Tickets and validation constraints | Low/Medium | App types/forms before ticket creation |
| 4 | Admin listing unpublish/republish and notice-post deletion RPCs | Medium | Chunk 1 |
| 5 | Per-user conversation hiding and new-message restoration | High | Chunks 0–3; coordinated inbox delete UI update |
| 6 | Ban enforcement and durable listing moderation | High | Chunks 1, 4, and 5; run read-only preflight |
| 7 | Realtime alignment | Medium | Chunk 5 table; RLS reviewed |
| 8 | Retire Supabase Storage policies/buckets | High | R2 code migration, URL migration, backup, Storage API cleanup |
| 9 | Remove dead/out-of-V1 schema | High | Code cleanup, data export, explicit destructive approval |
