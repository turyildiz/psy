begin;

-- Restore the captured pre-Chunk-6 RLS policies.
drop policy if exists "Unbanned users insert own profiles"
  on public.profiles;
create policy "Users can insert their own profiles"
on public.profiles
for insert
to public
with check (auth.uid() = user_id);

drop policy if exists "Unbanned users update own profiles"
  on public.profiles;
create policy "Users can update their own profiles"
on public.profiles
for update
to public
using (auth.uid() = user_id);

drop policy if exists "Unbanned owners create active listings"
  on public.listings;
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

drop policy if exists "Unbanned owners update own listings"
  on public.listings;
create policy "Users can update their own listings"
on public.listings
for update
to public
using (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned owners delete own draft listings"
  on public.listings;
create policy "Users can delete their own draft listings"
on public.listings
for delete
to public
using (
  status = 'draft'::public.listing_status
  and profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned buyers create conversations"
  on public.conversations;
create policy "buyers create conversations"
on public.conversations
for insert
to public
with check (
  buyer_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned participants send messages"
  on public.messages;
create policy "participants send messages"
on public.messages
for insert
to public
with check (
  sender_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
  and conversation_id in (
    select c.id
    from public.conversations c
    where c.buyer_profile_id in (
      select p.id from public.profiles p where p.user_id = auth.uid()
    )
    or c.seller_profile_id in (
      select p.id from public.profiles p where p.user_id = auth.uid()
    )
  )
);

drop policy if exists "Unbanned users add own RSVP"
  on public.vendor_events;
create policy "Users can add themselves to events"
on public.vendor_events
for insert
to public
with check (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users remove own RSVP"
  on public.vendor_events;
create policy "Users can remove themselves from events"
on public.vendor_events
for delete
to public
using (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users create own notice posts"
  on public.notice_posts;
create policy "Logged-in users can create notice posts"
on public.notice_posts
for insert
to public
with check (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users delete own notice posts"
  on public.notice_posts;
create policy "Users can delete their own notice posts"
on public.notice_posts
for delete
to public
using (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users add own reactions"
  on public.notice_reactions;
create policy "Logged-in users can add reactions"
on public.notice_reactions
for insert
to public
with check (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users remove own reactions"
  on public.notice_reactions;
create policy "Users can remove their own reactions"
on public.notice_reactions
for delete
to public
using (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Restore the captured legacy/out-of-V1 policies.
drop policy if exists "Users can read their own favorites"
  on public.favorites;
drop policy if exists "Unbanned users manage own favorites"
  on public.favorites;
create policy "Users can manage their own favorites"
on public.favorites
for all
to public
using (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users follow from own profile"
  on public.follows;
create policy "follows_insert"
on public.follows
for insert
to public
with check (
  follower_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users unfollow from own profile"
  on public.follows;
create policy "follows_delete"
on public.follows
for delete
to public
using (
  follower_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users subscribe to event notifications"
  on public.event_notifications;
create policy "Users can subscribe to event notifications"
on public.event_notifications
for insert
to public
with check (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop policy if exists "Unbanned users unsubscribe from event notifications"
  on public.event_notifications;
create policy "Users can unsubscribe from event notifications"
on public.event_notifications
for delete
to public
using (
  profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Restore the pre-Chunk-6 unread RPC definitions.
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

-- Restore the pre-Chunk-6 Chunk 5 participant-state RPC definitions.
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

-- Restore the original Chunk 4 moderation RPC behavior before removing the
-- durable moderation metadata and guard.
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
      updated_at = now()
  where id = target_listing_id;

  get diagnostics affected_rows = row_count;
  if affected_rows = 0 then
    raise exception 'Listing does not exist';
  end if;
end;
$$;

-- Remove the durable moderation guard and metadata.
drop trigger if exists listings_enforce_moderation_state
  on public.listings;
drop function if exists public.enforce_listing_moderation_state();

drop index if exists public.listings_admin_unpublished_idx;

alter table public.listings
  drop constraint if exists listings_admin_unpublished_state_consistent,
  drop constraint if exists listings_admin_unpublished_by_fkey,
  drop column if exists admin_unpublished_by,
  drop column if exists admin_unpublished_at;

-- Reassert the established pre-Chunk-6 function permission model.
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
