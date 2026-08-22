#!/usr/bin/env bash
set -euo pipefail
# Self-contained disposable lifecycle. Creates/drops only a fresh local DB.
# PostgreSQL 17+ is target acceptance; explicit PG16 override is supporting evidence.
HOST=${MP4G_HOST:-/tmp/mp4g-sock}; PORT=${MP4G_PORT:-55443}; USER=${MP4G_USER:-postgres}; ADMIN=${MP4G_ADMIN_USER:-supabase_admin}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd); DB=${MP4G_DB:-mp4g_disposable_$$}; LOG_DIR=${MP4G_LOG_DIR:-$(mktemp -d)}; mkdir -p "$LOG_DIR"
P=(psql -X -q -v ON_ERROR_STOP=1 -h "$HOST" -p "$PORT" -U "$USER" -d "$DB")
FILES=("$ROOT/supabase/chunks/slice-mp4-g-preflight.sql" "$ROOT/supabase/chunks/slice-mp4-g-apply.sql" "$ROOT/supabase/chunks/slice-mp4-g-verify.sql" "$ROOT/supabase/chunks/slice-mp4-g-rollback.sql" "$ROOT/supabase/chunks/slice-mp4-g-rollback-verify.sql" "$ROOT/supabase/chunks/slice-mp4-g-disposable-runtime.sql" "$ROOT/supabase/chunks/slice-mp4-g-disposable-harness.sh")
cleanup(){ dropdb -h "$HOST" -p "$PORT" -U "$ADMIN" --if-exists "$DB" >/dev/null 2>&1 || true; }; trap cleanup EXIT
sha256sum "${FILES[@]}" >"$LOG_DIR/start.sha256"; cleanup; createdb -h "$HOST" -p "$PORT" -U "$ADMIN" -T template0 -O "$USER" "$DB"
"${P[@]}" >"$LOG_DIR/setup.log" <<'SQL'
create schema auth; create schema private; create extension if not exists pgcrypto;
do $$begin
  if not exists(select 1 from pg_roles where rolname='audit_readonly') then
    create role audit_readonly nologin;
  end if;
end$$;
-- The disposable cluster must already provide the standard Supabase roles.
create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
create function auth.uid() returns uuid language sql stable as $$select nullif(auth.jwt()->>'sub','')::uuid$$;
create function auth.role() returns text language sql stable as $$select auth.jwt()->>'role'$$;
create table public.users(id uuid primary key,banned_at timestamptz);
create table public.profiles(id uuid primary key,user_id uuid not null,handle text not null unique,created_at timestamptz not null default now(),unique(id,user_id));
create unique index profiles_one_per_user_key on public.profiles(user_id);
create type public.listing_status as enum('draft','active','sold');
create table public.listings(id uuid primary key default gen_random_uuid(),profile_id uuid not null references public.profiles(id),status public.listing_status not null default 'active');
create table public.conversations(id uuid primary key default gen_random_uuid(),listing_id uuid references public.listings(id) on delete set null,buyer_profile_id uuid not null,seller_profile_id uuid not null,last_message_at timestamptz not null default now(),last_message_body text,created_at timestamptz not null default now(),unread_for text[] default '{}'::text[],constraint conversations_buyer_profile_id_fkey foreign key(buyer_profile_id) references public.profiles(id) on delete cascade,constraint conversations_seller_profile_id_fkey foreign key(seller_profile_id) references public.profiles(id) on delete cascade,constraint unique_conversation unique(listing_id,buyer_profile_id,seller_profile_id),constraint conversations_buyer_seller_differ check(buyer_profile_id<>seller_profile_id));
create index idx_conversations_buyer on public.conversations(buyer_profile_id); create index idx_conversations_seller on public.conversations(seller_profile_id); create index idx_conversations_last_message on public.conversations(last_message_at desc);
create table public.messages(id uuid primary key default gen_random_uuid(),conversation_id uuid not null,sender_profile_id uuid not null,body text not null constraint messages_body_check check(length(btrim(body))>0) constraint messages_body_max_2000 check(length(body)<=2000),created_at timestamptz not null default now(),constraint messages_conversation_id_fkey foreign key(conversation_id) references public.conversations(id) on delete cascade,constraint messages_sender_profile_id_fkey foreign key(sender_profile_id) references public.profiles(id) on delete cascade);
create index idx_messages_conversation on public.messages(conversation_id,created_at);
create table public.conversation_participant_state(conversation_id uuid not null,profile_id uuid not null,hidden_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),constraint conversation_participant_state_pkey primary key(conversation_id,profile_id),constraint conversation_participant_state_conversation_id_fkey foreign key(conversation_id) references public.conversations(id) on delete cascade,constraint conversation_participant_state_profile_id_fkey foreign key(profile_id) references public.profiles(id) on delete cascade);
create index conversation_participant_state_hidden_profile_idx on public.conversation_participant_state(profile_id,conversation_id) where hidden_at is not null;
create table private.account_session_active_profiles(session_id uuid primary key,user_id uuid not null,profile_id uuid not null,constraint account_session_active_profiles_profile_owner_fkey foreign key(profile_id,user_id) references public.profiles(id,user_id) on delete cascade);
create function private.current_auth_session_id()
returns uuid language plpgsql stable security invoker set search_path=''
as $function$
declare raw text;
begin
  raw:=auth.jwt()->>'session_id';
  if raw is null or raw='' then return null; end if;
  begin return raw::uuid; exception when invalid_text_representation then return null; end;
end
$function$;
create function private.current_active_profile_id() returns uuid language plpgsql stable security definer set search_path='' as $$
    declare
      uid uuid:=auth.uid();
      sid uuid;
      selected uuid;
      state_exists boolean;
      fallback_guard boolean;
    begin
      if uid is null then return null; end if;
      sid:=private.current_auth_session_id();
      if sid is null then return null; end if;

      select exists(
        select 1 from private.account_session_active_profiles a where a.session_id=sid
      ) into state_exists;
      if state_exists then
        select a.profile_id into selected
        from private.account_session_active_profiles a
        join public.profiles p on p.id=a.profile_id and p.user_id=a.user_id
        where a.session_id=sid and a.user_id=uid;
        return selected;
      end if;

      select exists(
        select 1 from pg_catalog.pg_index i
        where i.indexrelid=pg_catalog.to_regclass('public.profiles_one_per_user_key')
          and i.indrelid=pg_catalog.to_regclass('public.profiles')
          and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready
          and i.indpred is null
          and pg_catalog.pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)'
          and not exists(select 1 from pg_catalog.pg_constraint c where c.conindid=i.indexrelid)
      ) into fallback_guard;
      if not fallback_guard then return null; end if;

      select p.id into selected from public.profiles p where p.user_id=uid;
      return selected;
    end
$$;
create function public.current_active_profile_id() returns uuid language sql stable security definer set search_path='' as $$
      select private.current_active_profile_id();
$$;
create function public.current_user_is_active_profile(target_profile_id uuid) returns boolean language sql stable security definer set search_path='' as $$select coalesce(target_profile_id=private.current_active_profile_id(),false)$$;
create function public.current_user_owns_profile(target_profile_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  with caller as (
    select auth.uid() as account_user_id
  )
  select coalesce(
    (
      select exists (
        select 1
        from public.profiles p
        where p.id = target_profile_id
          and p.user_id = c.account_user_id
      )
      from caller c
      where c.account_user_id is not null
    ),
    false
  );
$$;
create function public.current_user_is_banned() returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $$
  select coalesce(
    (
      select u.banned_at is not null
      from public.users u
      where u.id = auth.uid()
    ),
    false
  );
$$;
create function public.enforce_conversation_listing_seller() returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
declare
  expected_seller_profile_id uuid;
begin
  if new.listing_id is null then
    return new;
  end if;

  select l.profile_id
    into expected_seller_profile_id
  from public.listings l
  where l.id = new.listing_id;

  if expected_seller_profile_id is null then
    raise exception 'Listing does not exist';
  end if;

  if new.seller_profile_id <> expected_seller_profile_id then
    raise exception 'Conversation seller must own the linked listing';
  end if;

  return new;
end;
$$;
create function public.unhide_conversation_for_message_recipient() returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
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
create function public.update_conversation_last_message() returns trigger language plpgsql volatile security definer set search_path='' as $$
declare
  affected_rows bigint;
begin
  if tg_when <> 'AFTER'
     or tg_level <> 'ROW'
     or tg_op <> 'INSERT'
     or tg_table_schema <> 'public'
     or tg_table_name <> 'messages' then
    raise exception 'Unexpected update_conversation_last_message trigger context'
      using errcode = '42501';
  end if;

  update public.conversations as c
  set last_message_at = new.created_at,
      last_message_body = pg_catalog.left(new.body, 120)
  where c.id = new.conversation_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Message parent conversation does not exist'
      using errcode = '23503';
  end if;

  return new;
end;
$$;
create trigger conversations_enforce_listing_seller before insert or update of listing_id,seller_profile_id on public.conversations for each row execute function public.enforce_conversation_listing_seller();
create trigger messages_unhide_recipient_conversation after insert on public.messages for each row execute function public.unhide_conversation_for_message_recipient();
create trigger on_message_insert after insert on public.messages for each row execute function public.update_conversation_last_message();
create function public.get_my_profiles() returns setof public.profiles language sql stable security definer set search_path='' as $$select p.* from public.profiles p where p.user_id=auth.uid() order by p.created_at,p.id$$;
revoke all on function public.get_my_profiles() from public; grant execute on function public.get_my_profiles() to authenticated;
create function public.append_unread_for(
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

  select case
           when public.current_user_owns_profile(c.buyer_profile_id)
             then c.buyer_profile_id
           when public.current_user_owns_profile(c.seller_profile_id)
             then c.seller_profile_id
         end
    into caller_profile_id
  from public.conversations c
  where c.id = conv_id;

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

create function public.remove_unread_for(
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

  select case
           when public.current_user_owns_profile(c.buyer_profile_id)
             then c.buyer_profile_id
           when public.current_user_owns_profile(c.seller_profile_id)
             then c.seller_profile_id
         end
    into caller_profile_id
  from public.conversations c
  where c.id = conv_id;

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

create function public.hide_conversation(
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

  select case
           when public.current_user_owns_profile(c.buyer_profile_id)
             then c.buyer_profile_id
           when public.current_user_owns_profile(c.seller_profile_id)
             then c.seller_profile_id
         end
    into caller_profile_id
  from public.conversations c
  where c.id = target_conversation_id;

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

create function public.unhide_conversation(
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

  select case
           when public.current_user_owns_profile(c.buyer_profile_id)
             then c.buyer_profile_id
           when public.current_user_owns_profile(c.seller_profile_id)
             then c.seller_profile_id
         end
    into caller_profile_id
  from public.conversations c
  where c.id = target_conversation_id;

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

create function public.find_and_unhide_conversation(
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
  caller_profile_count bigint;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot open conversations';
  end if;

  select (array_agg(owned.id order by owned.created_at, owned.id))[1], count(*)
    into caller_profile_id, caller_profile_count
  from public.get_my_profiles() as owned;

  if caller_profile_count > 1 then
    raise exception 'Active profile selection is required';
  end if;

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

revoke all on function private.current_active_profile_id(),public.current_active_profile_id(),public.current_user_is_active_profile(uuid),public.current_user_owns_profile(uuid),public.current_user_is_banned(),public.enforce_conversation_listing_seller(),public.unhide_conversation_for_message_recipient(),public.update_conversation_last_message() from public;
grant execute on function public.current_active_profile_id(),public.current_user_is_active_profile(uuid) to authenticated;
grant execute on function public.current_user_owns_profile(uuid) to authenticated;
grant execute on function public.current_user_is_banned() to authenticated,service_role;
grant execute on function public.enforce_conversation_listing_seller(),public.unhide_conversation_for_message_recipient(),public.update_conversation_last_message() to service_role;
revoke all on function public.append_unread_for(uuid,text),public.remove_unread_for(uuid,text),public.hide_conversation(uuid),public.unhide_conversation(uuid),public.find_and_unhide_conversation(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.append_unread_for(uuid,text),public.remove_unread_for(uuid,text),public.hide_conversation(uuid),public.unhide_conversation(uuid),public.find_and_unhide_conversation(uuid,uuid) to authenticated,service_role;
grant usage on schema public to anon,authenticated,service_role;
grant select on public.listings to authenticated;
-- Transcribe the live post-E ACL posture, warts included. MP4-F changes no grants;
-- the separate ACL-remediation package owns removal of browser mutation/TRUNCATE rights.
grant select,insert,update,references,trigger,truncate on public.conversations to anon,authenticated;
grant select,insert,update,delete,references,trigger,truncate on public.messages to anon,authenticated;
-- PostgreSQL 17 added MAINTAIN. The inherited F fixture omitted these four rows,
-- making its target-version preflight unreachable; reproduce the live PG17 ACLs.
do $$begin if current_setting('server_version_num')::int>=170000 then execute 'grant maintain on public.conversations,public.messages to anon,authenticated';end if;end$$;
grant select on public.conversations,public.messages to audit_readonly;
grant select on public.conversation_participant_state to authenticated;
grant all privileges on public.conversations,public.messages,public.conversation_participant_state to service_role;
alter table public.profiles enable row level security; alter table public.listings enable row level security;
alter table public.conversations enable row level security; alter table public.messages enable row level security; alter table public.conversation_participant_state enable row level security;
-- Exact live names/types/read predicates are retained for the two tables that the
-- conversation policies read transitively. The unexercised profile UPDATE policy
-- and three listing mutation policies are intentionally omitted: this fixture
-- inserts no listing and asserts no profile/listing mutation behavior.
create policy "Profiles are publicly readable" on public.profiles for select to public using(true);
create policy "Active and sold listings are publicly readable" on public.listings for select to public using(status=any(array['active'::public.listing_status,'sold'::public.listing_status]));
create policy "Owners can read own private listings" on public.listings for select to authenticated using(profile_id=(select public.current_active_profile_id()));
create policy "Unbanned buyers create conversations" on public.conversations for insert to authenticated with check(not public.current_user_is_banned() and public.current_user_owns_profile(buyer_profile_id) and buyer_profile_id<>seller_profile_id and(listing_id is null or seller_profile_id=(select l.profile_id from public.listings l where l.id=conversations.listing_id)));
create policy "participants view visible conversations" on public.conversations for select to authenticated using((public.current_user_owns_profile(buyer_profile_id) or public.current_user_owns_profile(seller_profile_id)) and not exists(select 1 from public.conversation_participant_state s where s.conversation_id=conversations.id and public.current_user_owns_profile(s.profile_id) and s.hidden_at is not null));
create policy "Unbanned participants send messages" on public.messages for insert to authenticated with check(not public.current_user_is_banned() and public.current_user_owns_profile(sender_profile_id) and conversation_id in(select c.id from public.conversations c where sender_profile_id=c.buyer_profile_id or sender_profile_id=c.seller_profile_id));
create policy "participants view messages" on public.messages for select to authenticated using(conversation_id in(select c.id from public.conversations c where public.current_user_owns_profile(c.buyer_profile_id) or public.current_user_owns_profile(c.seller_profile_id)));
create policy "Participants read own conversation state" on public.conversation_participant_state for select to authenticated using(public.current_user_owns_profile(profile_id));
create publication supabase_realtime for table public.conversations,public.messages,public.conversation_participant_state;
insert into public.users(id) values('aa000000-0000-4000-8000-000000000001'),('bb000000-0000-4000-8000-000000000001'),('cc000000-0000-4000-8000-000000000001');
insert into public.profiles(id,user_id,handle) values('a1000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000001','mp4e_a'),('b2000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000001','mp4e_b'),('c3000000-0000-4000-8000-000000000001','cc000000-0000-4000-8000-000000000001','mp4e_c');
select set_config('request.jwt.claims','{"sub":"aa000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"aa000000-0000-4000-8000-000000000011"}',false);
set role authenticated;
insert into public.conversations(id,buyer_profile_id,seller_profile_id) values('e0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
insert into public.messages(id,conversation_id,sender_profile_id,body) values('e1000000-0000-4000-8000-000000000001','e0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','before behavior');
select public.append_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
select set_config('request.jwt.claims','{"sub":"bb000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"bb000000-0000-4000-8000-000000000011"}',false);
select public.remove_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
select set_config('request.jwt.claims','{"sub":"aa000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"aa000000-0000-4000-8000-000000000011"}',false);
select public.hide_conversation('e0000000-0000-4000-8000-000000000001');
select public.unhide_conversation('e0000000-0000-4000-8000-000000000001');
select public.find_and_unhide_conversation('b2000000-0000-4000-8000-000000000001',null);
reset role;
create table private.mp4e_before_behavior as select last_message_body,unread_for,(select hidden_at from public.conversation_participant_state where conversation_id='e0000000-0000-4000-8000-000000000001' and profile_id='a1000000-0000-4000-8000-000000000001') hidden_at from public.conversations where id='e0000000-0000-4000-8000-000000000001';
SQL
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-e-apply.sql" >"$LOG_DIR/mp4e-foundation.log"
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-f-apply.sql" >"$LOG_DIR/mp4f-policy.log"
# The disposable schema omits unrelated social/event tables. Reproduce only their
# catalog contribution to the live post-F global active-authority count of 23.
"${P[@]}" <<'SQL' >"$LOG_DIR/policy-total-fixture.log"
create table public.mp4g_policy_count_fixture(id integer primary key);
alter table public.mp4g_policy_count_fixture enable row level security;
do $fixture$
declare current_count integer;i integer;
begin
 select count(*) into current_count from pg_policy p where(coalesce(pg_get_expr(p.polqual,p.polrelid,false),'')||coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''))like'%current_active_profile_id%';
 if current_count>23 then raise exception 'Fixture active-authority policy count exceeds live target: %',current_count;end if;
 for i in current_count+1..23 loop execute format('create policy %I on public.mp4g_policy_count_fixture for select using ((select public.current_active_profile_id()) is not null)','mp4g_count_'||i);end loop;
end$fixture$;
SQL
version=$("${P[@]}" -At -c "show server_version_num")
if ((version>=170000)); then echo POSTGRESQL_17_SEMANTICS=PASS; elif [[ ${MP4G_ALLOW_SUPPORTING_PG16:-0} == 1 ]]; then echo "POSTGRESQL_17_SEMANTICS=UNAVAILABLE(server_version_num=$version); explicit PG16 supporting run"; else echo "POSTGRESQL_17_SEMANTICS=BLOCKED(server_version_num=$version)" >&2; exit 1; fi
verdict(){ local f=$1 label=$2 hostile=${3:-no};local out="$LOG_DIR/$label.log";if [[ $hostile == yes ]];then "${P[@]}" -At -c 'set search_path=pg_catalog' -f "$f" >"$out";else "${P[@]}" -At -f "$f" >"$out";fi;grep -q '|GO|' "$out";printf '%s=GO\n' "$label";}
state(){ "${P[@]}" -At -c "with f as(select p.proname||'|'||md5(btrim(regexp_replace(replace(p.prosrc,E'\\r\\n',E'\\n'),'[[:space:]]+',' ','g'))) v from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message')),a as(select p.proname||'|'||a.grantor||'|'||a.grantee||'|'||a.privilege_type||'|'||a.is_grantable v from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))a where n.nspname='public'and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message'))select md5(string_agg(v,E'\n'order by v collate \"C\"))from(select * from f union all select * from a)x;";}
verdict "$ROOT/supabase/chunks/slice-mp4-g-preflight.sql" preflight-default;verdict "$ROOT/supabase/chunks/slice-mp4-g-preflight.sql" preflight-hostile yes
if "${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-g-disposable-runtime.sql" >"$LOG_DIR/red-before-apply.log" 2>&1;then echo 'RED failed: target behavior passed before G'>&2;exit 1;fi;echo RED_RPC_MATRIX=PASS_EXPECTED_FAILURE
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-g-apply.sql" >"$LOG_DIR/apply.log"
"${P[@]}" -At -c "select p.proname,md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message')order by p.proname collate \"C\"" >"$LOG_DIR/target-hashes.log"
before=$(state);"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-g-apply.sql" >"$LOG_DIR/apply-noop.log";[[ $before == "$(state)" ]];echo APPLY_NOOP=PASS
if [[ -f "$ROOT/supabase/chunks/slice-mp4-g-verify.sql" ]];then verdict "$ROOT/supabase/chunks/slice-mp4-g-verify.sql" verify-default;verdict "$ROOT/supabase/chunks/slice-mp4-g-verify.sql" verify-hostile yes;fi
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-g-disposable-runtime.sql" >"$LOG_DIR/runtime.log" 2>&1;grep -q MP4G_RPC_TRIGGER_BEHAVIOR_MATRIX=PASS "$LOG_DIR/runtime.log";echo RPC_TRIGGER_BEHAVIOR_MATRIX=PASS
# Concurrency: unread identity, authorization-before-lock, and deliberately
# interleaved conversation->cps ordering remain exact and deadlock-free.
"${P[@]}" <<'SQL' >"$LOG_DIR/concurrency-seed.log"
insert into private.account_session_active_profiles(session_id,user_id,profile_id) values
 ('aa000000-0000-4000-8000-000000000011','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'),
 ('bb000000-0000-4000-8000-000000000011','bb000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001') on conflict(session_id)do update set user_id=excluded.user_id,profile_id=excluded.profile_id;
insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at)values
 ('e0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',now()),
 ('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001',now()) on conflict(conversation_id,profile_id)do update set hidden_at=excluded.hidden_at;
SQL
("${P[@]}" -c "begin;set request.jwt.claims='{\"sub\":\"aa000000-0000-4000-8000-000000000001\",\"role\":\"authenticated\",\"session_id\":\"aa000000-0000-4000-8000-000000000011\"}';set role authenticated;select public.append_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');select pg_sleep(1);commit" >"$LOG_DIR/concurrent-a.log")& pa=$!
("${P[@]}" -c "begin;set request.jwt.claims='{\"sub\":\"bb000000-0000-4000-8000-000000000001\",\"role\":\"authenticated\",\"session_id\":\"bb000000-0000-4000-8000-000000000011\"}';set role authenticated;select public.remove_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');commit" >"$LOG_DIR/concurrent-b.log")& pb=$!;wait $pa;wait $pb
[[ $("${P[@]}" -At -c "select cardinality(coalesce(unread_for,'{}'::text[]))<=1 and not exists(select 1 from unnest(coalesce(unread_for,'{}'::text[]))u(v)where v<>'b2000000-0000-4000-8000-000000000001')from public.conversations where id='e0000000-0000-4000-8000-000000000001'") == t ]];echo CONCURRENT_UNREAD_IDENTITY=PASS
# A foreign caller must reject from the unlocked authorization read while an
# arbitrary target row is locked, rather than waiting on the definer row lock.
("${P[@]}" -c "begin;select 1 from public.conversations where id='e0000000-0000-4000-8000-000000000001' for update;select pg_sleep(2);rollback" >"$LOG_DIR/auth-lock-holder.log")& locker=$!;sleep .2
if "${P[@]}" -c "set statement_timeout='750ms';set request.jwt.claims='{\"sub\":\"cc000000-0000-4000-8000-000000000001\",\"role\":\"authenticated\",\"session_id\":\"cc000000-0000-4000-8000-000000000011\"}';set role authenticated;select public.hide_conversation('e0000000-0000-4000-8000-000000000001')" >"$LOG_DIR/unauthorized-before-lock.log" 2>&1;then echo 'Unauthorized lock probe unexpectedly succeeded'>&2;exit 1;fi
grep -q 'Conversation not found or caller is not a participant' "$LOG_DIR/unauthorized-before-lock.log";! grep -q 'statement timeout' "$LOG_DIR/unauthorized-before-lock.log";wait $locker;echo AUTHORIZATION_BEFORE_LOCK=PASS
# A statement trigger pauses hide after it owns the conversation row but before
# its cps upsert. With the old recipient cps->conversation order this schedule
# deadlocks; the corrected conversation->cps order serializes and completes.
"${P[@]}" <<'SQL' >"$LOG_DIR/deadlock-probe-setup.log"
create function public.mp4g_pause_before_cps_insert()returns trigger language plpgsql as $$begin if current_setting('mp4g.pause_before_cps',true)='on'then perform pg_sleep(1);end if;return null;end$$;
create trigger mp4g_pause_before_cps_insert before insert on public.conversation_participant_state for each statement execute function public.mp4g_pause_before_cps_insert();
SQL
("${P[@]}" -c "begin;set statement_timeout='8s';set mp4g.pause_before_cps='on';set request.jwt.claims='{\"sub\":\"aa000000-0000-4000-8000-000000000001\",\"role\":\"authenticated\",\"session_id\":\"aa000000-0000-4000-8000-000000000011\"}';set role authenticated;select public.hide_conversation('e0000000-0000-4000-8000-000000000001');commit" >"$LOG_DIR/concurrent-hide.log" 2>&1)& pa=$!;sleep .2
("${P[@]}" -c "begin;set statement_timeout='8s';set request.jwt.claims='{\"sub\":\"bb000000-0000-4000-8000-000000000001\",\"role\":\"authenticated\",\"session_id\":\"bb000000-0000-4000-8000-000000000011\"}';insert into public.messages(conversation_id,sender_profile_id,body)values('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','interleaved unhide');commit" >"$LOG_DIR/concurrent-message.log" 2>&1)& pb=$!;wait $pa;wait $pb
"${P[@]}" -c 'drop trigger mp4g_pause_before_cps_insert on public.conversation_participant_state;drop function public.mp4g_pause_before_cps_insert()' >"$LOG_DIR/deadlock-probe-cleanup.log"
! grep -q 'deadlock detected\|statement timeout' "$LOG_DIR/concurrent-hide.log" "$LOG_DIR/concurrent-message.log";echo INTERLEAVED_LOCK_ORDER=PASS
[[ $("${P[@]}" -At -c "select count(*)filter(where profile_id='a1000000-0000-4000-8000-000000000001'and hidden_at is null)=1 and count(*)filter(where profile_id='b2000000-0000-4000-8000-000000000001'and hidden_at is not null)=1 from public.conversation_participant_state where conversation_id='e0000000-0000-4000-8000-000000000001'") == t ]];echo CONCURRENT_RECIPIENT_UNHIDE_IDENTITY=PASS
"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-g-rollback.sql" >"$LOG_DIR/rollback.log"
if [[ -f "$ROOT/supabase/chunks/slice-mp4-g-rollback-verify.sql" ]];then verdict "$ROOT/supabase/chunks/slice-mp4-g-rollback-verify.sql" rollback-verify;fi
before=$(state);"${P[@]}" -f "$ROOT/supabase/chunks/slice-mp4-g-rollback.sql" >"$LOG_DIR/rollback-noop.log";[[ $before == "$(state)" ]];echo ROLLBACK_NOOP=PASS
verdict "$ROOT/supabase/chunks/slice-mp4-g-preflight.sql" restored-default;verdict "$ROOT/supabase/chunks/slice-mp4-g-preflight.sql" restored-hostile yes
sha256sum "${FILES[@]}" >"$LOG_DIR/end.sha256";cmp "$LOG_DIR/start.sha256" "$LOG_DIR/end.sha256";echo "SLICE_MP4_G_BOUND_LIFECYCLE=PASS logs=$LOG_DIR"
