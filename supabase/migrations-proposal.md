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

## CHUNK 4 — Repair listing RLS and add reactive unpublish authority

**Purpose:** Close the critical cross-profile INSERT hole and grant admins only the reactive listing power frozen for V1.

**Risk:** High because this changes write authorization.

**What could break:** Listing creation fails if `public.users` is missing for a legitimate account or the account is banned. Admin tooling must authenticate as an admin/super-admin. Existing owner updates continue to work.

```sql
begin;

-- Permissive INSERT policies are OR-combined; both old policies must be replaced.
drop policy if exists "Suspended profiles cannot insert listings" on public.listings;
drop policy if exists "Users can create listings for their own profiles" on public.listings;
drop policy if exists "Owners create listings for own active profile" on public.listings;

create policy "Unbanned users create listings for own profile"
on public.listings for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p
    where p.user_id = auth.uid() and not p.is_suspended
  )
  and status = 'active'::public.listing_status
);

-- Preserve the existing owner edit/unpublish/sold path, but block banned accounts.
drop policy if exists "Users can update their own listings" on public.listings;
create policy "Unbanned users update own listings"
on public.listings for update
to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
)
with check (
  not public.current_user_is_banned()
  and profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
);

create or replace function public.admin_unpublish_listing(target_listing_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  update public.listings
  set status = 'draft'::public.listing_status
  where id = target_listing_id;
end;
$$;

revoke all on function public.admin_unpublish_listing(uuid) from public;
grant execute on function public.admin_unpublish_listing(uuid) to authenticated, service_role;

commit;
```

**App queries checked under the new policies:**

- `components/NewListingModal.tsx` and `app/listings/new/page.tsx`: INSERT with the signed-in user's profile and `status='active'` still passes.
- `components/EditListingModal.tsx` and `app/listing/[id]/edit/page.tsx`: owner UPDATE still passes.
- `app/[handle]/page.tsx`: owner sets status to `draft`; still passes.
- Homepage, browse, category, profile, and listing-detail SELECT queries are unchanged because the existing public active/sold SELECT policy remains.

---

## CHUNK 5 — Per-user conversation hiding and hardened messaging RPCs

**Purpose:** Preserve shared conversation/message rows, make current DELETE calls soft-delete per participant, and close unread RPC authorization bypasses.

**Risk:** High because messaging authorization and deletion semantics change.

**What could break:** Hidden conversations stop appearing for that participant. The compatibility trigger relies on `auth.uid()` being present. Service-role maintenance must bypass or explicitly handle the trigger.

```sql
begin;

create table if not exists public.conversation_participant_state (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  hidden_at timestamptz,
  last_read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, profile_id)
);

alter table public.conversation_participant_state enable row level security;

create policy "Participants manage own conversation state"
on public.conversation_participant_state for all
to authenticated
using (
  profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
)
with check (
  profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
  and conversation_id in (
    select c.id from public.conversations c
    where c.buyer_profile_id = profile_id or c.seller_profile_id = profile_id
  )
);

create or replace function public.soft_delete_conversation()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  caller_profile uuid;
begin
  select p.id into caller_profile
  from public.profiles p
  where p.user_id = auth.uid()
    and p.id in (old.buyer_profile_id, old.seller_profile_id)
  limit 1;

  if caller_profile is null then
    raise exception 'Not a conversation participant';
  end if;

  insert into public.conversation_participant_state
    (conversation_id, profile_id, hidden_at, updated_at)
  values (old.id, caller_profile, now(), now())
  on conflict (conversation_id, profile_id)
  do update set hidden_at = excluded.hidden_at, updated_at = now();

  return null; -- cancel physical deletion
end;
$$;

drop trigger if exists conversations_soft_delete on public.conversations;
create trigger conversations_soft_delete
before delete on public.conversations
for each row execute function public.soft_delete_conversation();

-- Keep the current participant DELETE policy temporarily: the trigger converts it.
drop policy if exists "participants view conversations" on public.conversations;
create policy "participants view visible conversations"
on public.conversations for select
to authenticated
using (
  (
    buyer_profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
    or seller_profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
  )
  and not exists (
    select 1 from public.conversation_participant_state s
    join public.profiles p on p.id = s.profile_id
    where s.conversation_id = conversations.id
      and p.user_id = auth.uid()
      and s.hidden_at is not null
  )
);

create or replace function public.append_unread_for(conv_id uuid, profile_id text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare target uuid := profile_id::uuid;
begin
  if public.current_user_is_banned() then raise exception 'Account is banned'; end if;
  if not exists (
    select 1 from public.conversations c
    join public.profiles me on me.user_id = auth.uid()
    where c.id = conv_id
      and me.id in (c.buyer_profile_id, c.seller_profile_id)
      and target in (c.buyer_profile_id, c.seller_profile_id)
      and target <> me.id
  ) then raise exception 'Not authorized'; end if;

  update public.conversations
  set unread_for = array_append(coalesce(unread_for, '{}'), target::text)
  where id = conv_id and not (coalesce(unread_for, '{}') @> array[target::text]);
end;
$$;

create or replace function public.remove_unread_for(conv_id uuid, profile_id text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare target uuid := profile_id::uuid;
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = target and p.user_id = auth.uid()
  ) then raise exception 'Not authorized'; end if;

  update public.conversations
  set unread_for = array_remove(coalesce(unread_for, '{}'), target::text)
  where id = conv_id
    and target in (buyer_profile_id, seller_profile_id);

  insert into public.conversation_participant_state
    (conversation_id, profile_id, last_read_at, hidden_at, updated_at)
  values (conv_id, target, now(), null, now())
  on conflict (conversation_id, profile_id)
  do update set last_read_at = now(), hidden_at = null, updated_at = now();
end;
$$;

revoke all on function public.append_unread_for(uuid,text) from public;
revoke all on function public.remove_unread_for(uuid,text) from public;
grant execute on function public.append_unread_for(uuid,text) to authenticated, service_role;
grant execute on function public.remove_unread_for(uuid,text) to authenticated, service_role;

commit;
```

**App queries checked under the new policies:**

- `app/listing/[id]/page.tsx` and `app/[handle]/page.tsx`: participant conversation SELECT/INSERT remains allowed; direct-profile conversations with `listing_id=null` remain valid.
- `components/MessagesInbox.tsx`: participant conversation SELECT, message SELECT/INSERT, unread RPC calls, and DELETE remain accepted. DELETE becomes per-user hiding instead of a shared hard delete.
- `components/layout/Header.tsx`: participant conversation unread query remains allowed.
- Existing message SELECT policy resolves conversations through the new visible-conversation policy, so hidden conversations and their messages disappear only for the hiding user.

---

## CHUNK 6 — Enforce bans and reactive moderation across community writes

**Purpose:** Apply account bans consistently and allow admins to delete notice-wall posts without broad admin analytics or approval powers.

**Risk:** High because several RLS policies are replaced.

**What could break:** Banned accounts will no longer update profiles, RSVP, post, react, create conversations, or send messages. Public reads remain unchanged.

```sql
begin;

-- Profiles
 drop policy if exists "Users can update their own profiles" on public.profiles;
create policy "Unbanned users update own profiles"
on public.profiles for update to authenticated
using (auth.uid() = user_id and not public.current_user_is_banned())
with check (auth.uid() = user_id and not public.current_user_is_banned());

-- Conversations
 drop policy if exists "buyers create conversations" on public.conversations;
create policy "Unbanned buyers create conversations"
on public.conversations for insert to authenticated
with check (
  not public.current_user_is_banned()
  and buyer_profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
  and buyer_profile_id <> seller_profile_id
  and (
    listing_id is null
    or seller_profile_id = (select l.profile_id from public.listings l where l.id = listing_id)
  )
);

-- Messages
 drop policy if exists "participants send messages" on public.messages;
create policy "Unbanned participants send messages"
on public.messages for insert to authenticated
with check (
  not public.current_user_is_banned()
  and sender_profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
  and conversation_id in (
    select c.id from public.conversations c
    where sender_profile_id in (c.buyer_profile_id, c.seller_profile_id)
  )
);

-- RSVPs
 drop policy if exists "Users can add themselves to events" on public.vendor_events;
create policy "Unbanned users add own RSVP"
on public.vendor_events for insert to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
);

drop policy if exists "Users can remove themselves from events" on public.vendor_events;
create policy "Unbanned users remove own RSVP"
on public.vendor_events for delete to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
);

-- Notice posts
 drop policy if exists "Logged-in users can create notice posts" on public.notice_posts;
create policy "Unbanned users create own notice posts"
on public.notice_posts for insert to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
);

create policy "Admins delete notice posts"
on public.notice_posts for delete to authenticated
using (public.current_user_is_admin());

-- Reactions
 drop policy if exists "Logged-in users can add reactions" on public.notice_reactions;
create policy "Unbanned users add own reactions"
on public.notice_reactions for insert to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (select p.id from public.profiles p where p.user_id = auth.uid())
);

commit;
```

**App queries checked under the new policies:**

- `components/EditProfileModal.tsx` and `app/profile/edit/page.tsx`: authenticated owner UPDATE continues for unbanned users.
- Festival detail page: public event/RSVP/notice/reaction SELECT remains unchanged; own RSVP INSERT/DELETE, notice INSERT, owner notice DELETE, and reaction INSERT/DELETE continue for unbanned users.
- Listing/profile Contact buttons and `MessagesInbox`: conversation/message writes continue for unbanned participants.
- Admin notice deletion is additive and does not expose private reads.

**Additional application requirement:** trusted server-side moderation must update `public.users.banned_at`, `ban_reason`, and `banned_by`, and should synchronize Supabase Auth's `banned_until` so banned users cannot continue authenticating.

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
| 4 | Close listing INSERT RLS bypass; admin unpublish | High | Chunk 1 |
| 5 | Conversation soft-delete and secure unread RPCs | High | Chunk 1 |
| 6 | Ban enforcement and reactive community moderation | High | Chunk 1; preferably Chunks 4–5 |
| 7 | Realtime alignment | Medium | Chunk 5 table; RLS reviewed |
| 8 | Retire Supabase Storage policies/buckets | High | R2 code migration, URL migration, backup, Storage API cleanup |
| 9 | Remove dead/out-of-V1 schema | High | Code cleanup, data export, explicit destructive approval |
