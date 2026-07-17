begin;

-- Per-participant conversation state. Shared conversations and messages remain
-- intact; hiding is represented only by the participant's own state row.
create table public.conversation_participant_state (
  conversation_id uuid not null
    references public.conversations(id) on delete cascade,
  profile_id uuid not null
    references public.profiles(id) on delete cascade,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, profile_id)
);

create index conversation_participant_state_hidden_profile_idx
  on public.conversation_participant_state (profile_id, conversation_id)
  where hidden_at is not null;

alter table public.conversation_participant_state enable row level security;

-- Clients may inspect only their own state. All state mutations go through
-- participant-authorized SECURITY DEFINER RPCs.
create policy "Participants read own conversation state"
on public.conversation_participant_state
for select
to authenticated
using (
  profile_id in (
    select p.id
    from public.profiles p
    where p.user_id = auth.uid()
  )
);

revoke all on table public.conversation_participant_state
  from public, anon, authenticated;

grant select on table public.conversation_participant_state
  to authenticated, service_role;

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

-- Find an existing conversation even when it is hidden from the caller's
-- ordinary SELECT policy, restore it for that caller, and return its ID.
-- Returns null when no matching conversation exists so the application can
-- continue through its normal participant-authorized INSERT path.
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

-- A new message restores the conversation only for its recipient. The sender's
-- independent hidden state, if any, is not changed.
create or replace function public.unhide_conversation_for_message_recipient()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.conversation_participant_state s
  set hidden_at = null,
      updated_at = now()
  from public.conversations c
  where c.id = new.conversation_id
    and s.conversation_id = c.id
    and s.hidden_at is not null
    and s.profile_id = case
      when new.sender_profile_id = c.buyer_profile_id
        then c.seller_profile_id
      when new.sender_profile_id = c.seller_profile_id
        then c.buyer_profile_id
      else null
    end;

  return new;
end;
$$;

drop trigger if exists messages_unhide_recipient_conversation
  on public.messages;

create trigger messages_unhide_recipient_conversation
after insert on public.messages
for each row
execute function public.unhide_conversation_for_message_recipient();

-- Hidden conversations are excluded only for the participant who hid them.
-- The other participant's visibility is unaffected.
drop policy if exists "participants view conversations"
  on public.conversations;

drop policy if exists "participants view visible conversations"
  on public.conversations;

create policy "participants view visible conversations"
on public.conversations
for select
to authenticated
using (
  (
    buyer_profile_id in (
      select p.id from public.profiles p where p.user_id = auth.uid()
    )
    or seller_profile_id in (
      select p.id from public.profiles p where p.user_id = auth.uid()
    )
  )
  and not exists (
    select 1
    from public.conversation_participant_state s
    join public.profiles p on p.id = s.profile_id
    where s.conversation_id = conversations.id
      and p.user_id = auth.uid()
      and s.hidden_at is not null
  )
);

-- Participants must no longer be able to physically delete the shared row.
drop policy if exists "participants delete conversations"
  on public.conversations;

revoke delete on table public.conversations
  from public, anon, authenticated;

-- Remove PostgreSQL/Supabase default execution, then expose participant RPCs
-- only to signed-in callers and trusted service-role code. Each RPC performs
-- its own participant authorization check.
revoke all on function public.hide_conversation(uuid) from public;
revoke all on function public.unhide_conversation(uuid) from public;
revoke all
  on function public.find_and_unhide_conversation(uuid, uuid)
  from public;
revoke all on function public.unhide_conversation_for_message_recipient()
  from public;

revoke execute on function public.hide_conversation(uuid) from anon;
revoke execute on function public.unhide_conversation(uuid) from anon;
revoke execute
  on function public.find_and_unhide_conversation(uuid, uuid)
  from anon;
revoke execute
  on function public.unhide_conversation_for_message_recipient()
  from anon, authenticated;

grant execute on function public.hide_conversation(uuid)
  to authenticated, service_role;
grant execute on function public.unhide_conversation(uuid)
  to authenticated, service_role;
grant execute
  on function public.find_and_unhide_conversation(uuid, uuid)
  to authenticated, service_role;
grant execute
  on function public.unhide_conversation_for_message_recipient()
  to service_role;

commit;
