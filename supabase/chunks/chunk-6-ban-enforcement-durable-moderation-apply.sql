begin;

-- Durable listing moderation state. admin_unpublished_at is the authoritative
-- guard; admin_unpublished_by is audit metadata and may become null if that
-- admin account is later deleted.
alter table public.listings
  add column admin_unpublished_at timestamptz,
  add column admin_unpublished_by uuid;

alter table public.listings
  add constraint listings_admin_unpublished_by_fkey
  foreign key (admin_unpublished_by)
  references public.users(id)
  on delete set null;

alter table public.listings
  add constraint listings_admin_unpublished_state_consistent
  check (
    admin_unpublished_at is not null
    or admin_unpublished_by is null
  );

create index listings_admin_unpublished_idx
  on public.listings (admin_unpublished_at desc)
  where admin_unpublished_at is not null;

-- Non-admin callers may not forge/clear moderation metadata, and a listing
-- carrying an admin-unpublished marker must remain draft until admin republish.
create or replace function public.enforce_listing_moderation_state()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if not public.current_user_is_admin() then
    if new.admin_unpublished_at is distinct from old.admin_unpublished_at
       or new.admin_unpublished_by is distinct from old.admin_unpublished_by then
      raise exception 'Only an active admin may change listing moderation state';
    end if;

    if old.admin_unpublished_at is not null
       and new.status <> 'draft'::public.listing_status then
      raise exception 'An admin-unpublished listing must remain draft until an admin republishes it';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists listings_enforce_moderation_state
  on public.listings;

create trigger listings_enforce_moderation_state
before update on public.listings
for each row
execute function public.enforce_listing_moderation_state();

-- Replace the Chunk 4 listing moderation RPCs so unpublish records durable
-- state and republish is the only supported operation that clears it.
create or replace function public.admin_unpublish_listing(
  target_listing_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  update public.listings
  set status = 'draft'::public.listing_status,
      admin_unpublished_at = now(),
      admin_unpublished_by = auth.uid(),
      updated_at = now()
  where id = target_listing_id;

  get diagnostics affected_rows = row_count;
  if affected_rows = 0 then
    raise exception 'Listing does not exist';
  end if;
end;
$$;

create or replace function public.admin_republish_listing(
  target_listing_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  update public.listings
  set status = 'active'::public.listing_status,
      admin_unpublished_at = null,
      admin_unpublished_by = null,
      updated_at = now()
  where id = target_listing_id
    and admin_unpublished_at is not null;

  get diagnostics affected_rows = row_count;
  if affected_rows = 0 then
    if not exists (
      select 1 from public.listings l where l.id = target_listing_id
    ) then
      raise exception 'Listing does not exist';
    end if;

    raise exception 'Listing is not admin-unpublished';
  end if;
end;
$$;

-- Profiles: block profile creation and edits by banned accounts.
drop policy if exists "Users can insert their own profiles"
  on public.profiles;
drop policy if exists "Unbanned users insert own profiles"
  on public.profiles;
create policy "Unbanned users insert own profiles"
on public.profiles
for insert
to authenticated
with check (
  auth.uid() = user_id
  and not public.current_user_is_banned()
);

drop policy if exists "Users can update their own profiles"
  on public.profiles;
drop policy if exists "Unbanned users update own profiles"
  on public.profiles;
create policy "Unbanned users update own profiles"
on public.profiles
for update
to authenticated
using (
  auth.uid() = user_id
  and not public.current_user_is_banned()
)
with check (
  auth.uid() = user_id
  and not public.current_user_is_banned()
);

-- Listings: block create/edit/delete for banned owners. New owner-created rows
-- must be direct-published and may not forge admin moderation metadata.
drop policy if exists "Owners create listings for own active profile"
  on public.listings;
drop policy if exists "Unbanned owners create active listings"
  on public.listings;
create policy "Unbanned owners create active listings"
on public.listings
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and status = 'active'::public.listing_status
  and admin_unpublished_at is null
  and admin_unpublished_by is null
  and profile_id in (
    select p.id
    from public.profiles p
    where p.user_id = auth.uid()
      and p.is_suspended = false
  )
);

drop policy if exists "Users can update their own listings"
  on public.listings;
drop policy if exists "Unbanned owners update own listings"
  on public.listings;
create policy "Unbanned owners update own listings"
on public.listings
for update
to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
)
with check (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
  and (
    admin_unpublished_at is null
    or status = 'draft'::public.listing_status
  )
);

drop policy if exists "Users can delete their own draft listings"
  on public.listings;
drop policy if exists "Unbanned owners delete own draft listings"
  on public.listings;
create policy "Unbanned owners delete own draft listings"
on public.listings
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and status = 'draft'::public.listing_status
  and admin_unpublished_at is null
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Conversations: banned buyers cannot create a new listing/direct thread.
drop policy if exists "buyers create conversations"
  on public.conversations;
drop policy if exists "Unbanned buyers create conversations"
  on public.conversations;
create policy "Unbanned buyers create conversations"
on public.conversations
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and buyer_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
  and buyer_profile_id <> seller_profile_id
  and (
    listing_id is null
    or seller_profile_id = (
      select l.profile_id from public.listings l where l.id = listing_id
    )
  )
);

-- Messages: only an unbanned caller-owned participant profile may send.
drop policy if exists "participants send messages"
  on public.messages;
drop policy if exists "Unbanned participants send messages"
  on public.messages;
create policy "Unbanned participants send messages"
on public.messages
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and sender_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
  and conversation_id in (
    select c.id
    from public.conversations c
    where sender_profile_id in (c.buyer_profile_id, c.seller_profile_id)
  )
);

-- Chunk 0 unread RPCs also mutate shared conversation state, so ban checks are
-- added without changing their participant/target authorization behavior.
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
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot change unread state';
  end if;

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
      and target_profile_id in (
        c.buyer_profile_id,
        c.seller_profile_id
      )
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
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot change unread state';
  end if;

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

-- Chunk 5 participant-state RPCs: banned callers may read retained threads but
-- cannot hide, unhide, or restore/create through contact flows.
create or replace function public.hide_conversation(
  target_conversation_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  caller_profile_id uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot hide conversations';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = target_conversation_id
  limit 1;

  if caller_profile_id is null then
    raise exception 'Conversation not found or caller is not a participant';
  end if;

  insert into public.conversation_participant_state (
    conversation_id,
    profile_id,
    hidden_at,
    updated_at
  )
  values (
    target_conversation_id,
    caller_profile_id,
    now(),
    now()
  )
  on conflict (conversation_id, profile_id)
  do update
    set hidden_at = excluded.hidden_at,
        updated_at = excluded.updated_at;
end;
$$;

create or replace function public.unhide_conversation(
  target_conversation_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  caller_profile_id uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot unhide conversations';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = target_conversation_id
  limit 1;

  if caller_profile_id is null then
    raise exception 'Conversation not found or caller is not a participant';
  end if;

  insert into public.conversation_participant_state (
    conversation_id,
    profile_id,
    hidden_at,
    updated_at
  )
  values (
    target_conversation_id,
    caller_profile_id,
    null,
    now()
  )
  on conflict (conversation_id, profile_id)
  do update
    set hidden_at = null,
        updated_at = excluded.updated_at;
end;
$$;

create or replace function public.find_and_unhide_conversation(
  target_other_profile_id uuid,
  target_listing_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  caller_profile_id uuid;
  existing_conversation_id uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot open conversations';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;

  if caller_profile_id is null then
    raise exception 'Caller profile not found';
  end if;

  if target_other_profile_id = caller_profile_id then
    raise exception 'Cannot open a conversation with the same profile';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = target_other_profile_id
  ) then
    raise exception 'Target profile does not exist';
  end if;

  if target_listing_id is not null
     and not exists (
       select 1
       from public.listings l
       where l.id = target_listing_id
         and l.profile_id = target_other_profile_id
     ) then
    raise exception 'Listing does not belong to the target profile';
  end if;

  select c.id
    into existing_conversation_id
  from public.conversations c
  where c.listing_id is not distinct from target_listing_id
    and (
      (
        c.buyer_profile_id = caller_profile_id
        and c.seller_profile_id = target_other_profile_id
      )
      or (
        c.buyer_profile_id = target_other_profile_id
        and c.seller_profile_id = caller_profile_id
      )
    )
  order by c.last_message_at desc, c.created_at desc
  limit 1;

  if existing_conversation_id is null then
    return null;
  end if;

  insert into public.conversation_participant_state (
    conversation_id,
    profile_id,
    hidden_at,
    updated_at
  )
  values (
    existing_conversation_id,
    caller_profile_id,
    null,
    now()
  )
  on conflict (conversation_id, profile_id)
  do update
    set hidden_at = null,
        updated_at = excluded.updated_at;

  return existing_conversation_id;
end;
$$;

-- RSVPs: both adding/changing and removing are blocked for banned accounts.
drop policy if exists "Users can add themselves to events"
  on public.vendor_events;
drop policy if exists "Unbanned users add own RSVP"
  on public.vendor_events;
create policy "Unbanned users add own RSVP"
on public.vendor_events
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Users can remove themselves from events"
  on public.vendor_events;
drop policy if exists "Unbanned users remove own RSVP"
  on public.vendor_events;
create policy "Unbanned users remove own RSVP"
on public.vendor_events
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Notice posts: block both creation and owner deletion by banned accounts.
drop policy if exists "Logged-in users can create notice posts"
  on public.notice_posts;
drop policy if exists "Unbanned users create own notice posts"
  on public.notice_posts;
create policy "Unbanned users create own notice posts"
on public.notice_posts
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Users can delete their own notice posts"
  on public.notice_posts;
drop policy if exists "Unbanned users delete own notice posts"
  on public.notice_posts;
create policy "Unbanned users delete own notice posts"
on public.notice_posts
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Reactions: block adding and removing reactions by banned accounts.
drop policy if exists "Logged-in users can add reactions"
  on public.notice_reactions;
drop policy if exists "Unbanned users add own reactions"
  on public.notice_reactions;
create policy "Unbanned users add own reactions"
on public.notice_reactions
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Users can remove their own reactions"
  on public.notice_reactions;
drop policy if exists "Unbanned users remove own reactions"
  on public.notice_reactions;
create policy "Unbanned users remove own reactions"
on public.notice_reactions
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Legacy/out-of-V1 tables still exist until Chunk 9. Their dormant write
-- policies are ban-gated as well so "banned means read-only" is complete at
-- the public-schema boundary, even if old clients call these tables directly.
drop policy if exists "Users can manage their own favorites"
  on public.favorites;
drop policy if exists "Users can read their own favorites"
  on public.favorites;
drop policy if exists "Unbanned users manage own favorites"
  on public.favorites;
create policy "Users can read their own favorites"
on public.favorites
for select
to public
using (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);
create policy "Unbanned users manage own favorites"
on public.favorites
for all
to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
)
with check (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "follows_insert"
  on public.follows;
drop policy if exists "Unbanned users follow from own profile"
  on public.follows;
create policy "Unbanned users follow from own profile"
on public.follows
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and follower_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "follows_delete"
  on public.follows;
drop policy if exists "Unbanned users unfollow from own profile"
  on public.follows;
create policy "Unbanned users unfollow from own profile"
on public.follows
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and follower_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Users can subscribe to event notifications"
  on public.event_notifications;
drop policy if exists "Unbanned users subscribe to event notifications"
  on public.event_notifications;
create policy "Unbanned users subscribe to event notifications"
on public.event_notifications
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Users can unsubscribe from event notifications"
  on public.event_notifications;
drop policy if exists "Unbanned users unsubscribe from event notifications"
  on public.event_notifications;
create policy "Unbanned users unsubscribe from event notifications"
on public.event_notifications
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Reassert the established explicit function permission model after replacing
-- function bodies. Trigger execution remains service-role-only.
revoke all on function public.enforce_listing_moderation_state() from public;
revoke execute on function public.enforce_listing_moderation_state()
  from anon, authenticated;
grant execute on function public.enforce_listing_moderation_state()
  to service_role;

revoke all on function public.admin_unpublish_listing(uuid) from public;
revoke all on function public.admin_republish_listing(uuid) from public;
revoke execute on function public.admin_unpublish_listing(uuid) from anon;
revoke execute on function public.admin_republish_listing(uuid) from anon;
grant execute on function public.admin_unpublish_listing(uuid)
  to authenticated, service_role;
grant execute on function public.admin_republish_listing(uuid)
  to authenticated, service_role;

revoke all on function public.append_unread_for(uuid, text) from public;
revoke all on function public.remove_unread_for(uuid, text) from public;
revoke execute on function public.append_unread_for(uuid, text) from anon;
revoke execute on function public.remove_unread_for(uuid, text) from anon;
grant execute on function public.append_unread_for(uuid, text)
  to authenticated, service_role;
grant execute on function public.remove_unread_for(uuid, text)
  to authenticated, service_role;

revoke all on function public.hide_conversation(uuid) from public;
revoke all on function public.unhide_conversation(uuid) from public;
revoke all
  on function public.find_and_unhide_conversation(uuid, uuid)
  from public;
revoke execute on function public.hide_conversation(uuid) from anon;
revoke execute on function public.unhide_conversation(uuid) from anon;
revoke execute
  on function public.find_and_unhide_conversation(uuid, uuid)
  from anon;
grant execute on function public.hide_conversation(uuid)
  to authenticated, service_role;
grant execute on function public.unhide_conversation(uuid)
  to authenticated, service_role;
grant execute
  on function public.find_and_unhide_conversation(uuid, uuid)
  to authenticated, service_role;

commit;
