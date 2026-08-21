-- psy.market Slice MP-4-E: dormant conversation nullability foundation
-- APPLY: guarded source -> exact target, with a true no-op target rerun.
-- No FK delete action changes, participant rewrites, deletion path, policy, grant,
-- publication membership, replica identity, or retained-row cutover is performed.
-- Scoped hardening: the listing-seller and recipient-unhide trigger functions move
-- from search_path=pg_catalog,public to an empty path and gain context/null guards.
-- Operational boundary: message guards require browser JWT active authority. JWT-less
-- service_role/postgres writers cannot insert messages; no such trusted writer exists
-- today. Owner break-glass is explicit, audited DISABLE TRIGGER around exact writes.
begin;
set local row_security = off;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
lock table public.profiles, public.listings, public.conversations,
  public.messages, public.conversation_participant_state in share row exclusive mode;

do $mp4e$
declare
  source_state boolean;
  target_state boolean;
  bad_rows bigint;
begin
  if current_user <> 'postgres' or session_user <> 'postgres' or not (select rolsuper or rolbypassrls from pg_roles where rolname=current_user) then
    raise exception 'MP4-E APPLY requires complete postgres owner context' using errcode='42501';
  end if;

  select
    count(*) filter(where (c.relname,a.attname) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id')) and a.attnotnull)=3
    and exists(select 1 from pg_constraint where conrelid='public.conversations'::regclass and conname='conversations_buyer_seller_differ' and pg_get_constraintdef(oid,false) ~ 'buyer_profile_id <> seller_profile_id')
    and to_regprocedure('public.guard_conversation_participants()') is null
    and to_regprocedure('public.guard_message_active_participant()') is null
    and to_regprocedure('public.guard_conversation_unread_participants()') is null
    and to_regprocedure('public.guard_conversation_participant_state()') is null
    and (select count(*)=3 from pg_trigger t join pg_proc p on p.oid=t.tgfoid where not t.tgisinternal and (t.tgrelid,t.tgname,p.proname) in (('public.conversations'::regclass,'conversations_enforce_listing_seller','enforce_conversation_listing_seller'),('public.messages'::regclass,'messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient'),('public.messages'::regclass,'on_message_insert','update_conversation_last_message')))
    and (select count(*)=5 from pg_constraint where conname in ('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey') and confdeltype='c')
    and (select count(*)=2 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile'))
    and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='enforce_conversation_listing_seller' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='0dff735e21efc845ee166e57f902136a')
    and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='unhide_conversation_for_message_recipient' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='66074618fc4aefdc17cd2b6c0274950a')
    and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='update_conversation_last_message' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='45c2da17ae8a0272b0fd3e1fbb3d388e')
  into source_state
  from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and (c.relname,a.attname) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id'));

  select
    count(*) filter(where not a.attnotnull)=3
    and exists(select 1 from pg_constraint where conrelid='public.conversations'::regclass and conname='conversations_buyer_seller_differ'
      and lower(regexp_replace(pg_get_constraintdef(oid,false),'[[:space:]]+',' ','g'))=
        'check ((((buyer_profile_id is not null) and (seller_profile_id is not null) and (buyer_profile_id <> seller_profile_id)) or ((buyer_profile_id is null) and (seller_profile_id is not null)) or ((buyer_profile_id is not null) and (seller_profile_id is null))))')
    and to_regprocedure('public.guard_conversation_participants()') is not null
    and to_regprocedure('public.guard_message_active_participant()') is not null
    and to_regprocedure('public.guard_conversation_unread_participants()') is not null
    and to_regprocedure('public.guard_conversation_participant_state()') is not null
    and (select count(*)=7 from pg_trigger t join pg_proc p on p.oid=t.tgfoid where not t.tgisinternal and (t.tgrelid,t.tgname,p.proname) in (('public.conversations'::regclass,'conversations_enforce_listing_seller','enforce_conversation_listing_seller'),('public.conversations'::regclass,'conversations_guard_participants','guard_conversation_participants'),('public.conversations'::regclass,'conversations_guard_unread','guard_conversation_unread_participants'),('public.messages'::regclass,'messages_guard_active_participant','guard_message_active_participant'),('public.messages'::regclass,'messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient'),('public.messages'::regclass,'on_message_insert','update_conversation_last_message'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard','guard_conversation_participant_state')))
    and (select count(*)=5 from pg_constraint where conname in ('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey') and confdeltype='c')
    and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='guard_message_active_participant' and p.prosrc like '%One-sided retained conversations are read-only%' and p.prosrc like '%current_active_profile_id%')
    and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='guard_conversation_unread_participants' and p.prosrc like '%Unread state may reference only a present participant%')
    and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='guard_conversation_participant_state' and p.prosrc like '%Participant state may reference only a present side%')
    and (select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname,md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))) in (
      ('guard_conversation_participants','64cc5737cb441eecb523f8ad3bc02db5'),('guard_message_active_participant','1f6556e8cb4a22f83ef9365b1cefd920'),('guard_conversation_unread_participants','6d71b91028733e83bc5d5f22d77aee8a'),('guard_conversation_participant_state','c407c042adbfc7a77ccacbe7abe10127'),('enforce_conversation_listing_seller','676d753fe3b692b035ddaf5537c0fe7a'),('unhide_conversation_for_message_recipient','65000503f5c585632d5cae3282217b43'),('update_conversation_last_message','396ba90811a1f9ba79cbdf3bc3f5b060')))
    and not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('enforce_conversation_listing_seller','guard_conversation_participants','guard_conversation_unread_participants','guard_message_active_participant','guard_conversation_participant_state','unhide_conversation_for_message_recipient','update_conversation_last_message') and (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) in ('PUBLIC','anon','authenticated'))
  into target_state
  from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and (c.relname,a.attname) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id'));

  if target_state then
    return;
  end if;
  if not source_state then
    raise exception 'MP4-E APPLY source drift: neither exact source nor exact target state' using errcode='55000';
  end if;

  select count(*) into bad_rows from (
    select id from public.conversations where buyer_profile_id is null or seller_profile_id is null or buyer_profile_id=seller_profile_id
    union all select id from public.messages where sender_profile_id is null
    union all select m.id from public.messages m join public.conversations c on c.id=m.conversation_id
      where m.sender_profile_id is distinct from c.buyer_profile_id and m.sender_profile_id is distinct from c.seller_profile_id
  ) q;
  if bad_rows<>0 then raise exception 'MP4-E APPLY row invariant drift: % invalid rows',bad_rows using errcode='55000'; end if;

  -- Preserve live CASCADE actions; only remove the three NOT NULL flags.
  execute 'alter table public.conversations alter column buyer_profile_id drop not null, alter column seller_profile_id drop not null';
  execute 'alter table public.messages alter column sender_profile_id drop not null';
  execute 'alter table public.conversations drop constraint conversations_buyer_seller_differ';
  execute $ddl$alter table public.conversations add constraint conversations_buyer_seller_differ check (
    (buyer_profile_id is not null and seller_profile_id is not null and buyer_profile_id<>seller_profile_id)
    or (buyer_profile_id is null and seller_profile_id is not null)
    or (buyer_profile_id is not null and seller_profile_id is null)
  )$ddl$;

  execute $ddl$create or replace function public.guard_conversation_participants()
  returns trigger language plpgsql volatile security definer set search_path=''
  as $fn$
  begin
    if tg_when<>'BEFORE' or tg_level<>'ROW' or tg_table_schema<>'public' or tg_table_name<>'conversations' or tg_op not in ('INSERT','UPDATE') then
      raise exception 'Unexpected guard_conversation_participants trigger context' using errcode='42501';
    end if;
    if new.buyer_profile_id is null or new.seller_profile_id is null or new.buyer_profile_id=new.seller_profile_id then
      raise exception 'Ordinary conversation writes require two distinct present participants' using errcode='23514';
    end if;
    if tg_op='UPDATE' and (new.buyer_profile_id is distinct from old.buyer_profile_id or new.seller_profile_id is distinct from old.seller_profile_id) then
      raise exception 'Conversation participant identity is immutable in ordinary writes' using errcode='42501';
    end if;
    return new;
  end$fn$$ddl$;

  execute $ddl$create or replace function public.guard_message_active_participant()
  returns trigger language plpgsql volatile security definer set search_path=''
  as $fn$
  declare c public.conversations%rowtype; active_profile uuid;
  begin
    if tg_when<>'BEFORE' or tg_level<>'ROW' or tg_table_schema<>'public' or tg_table_name<>'messages' or tg_op not in ('INSERT','UPDATE') then
      raise exception 'Unexpected guard_message_active_participant trigger context' using errcode='42501';
    end if;
    if new.sender_profile_id is null then raise exception 'Message sender must be present' using errcode='23514'; end if;
    select * into c from public.conversations where id=new.conversation_id;
    if not found then raise exception 'Message parent conversation does not exist' using errcode='23503'; end if;
    if c.buyer_profile_id is null or c.seller_profile_id is null or c.buyer_profile_id=c.seller_profile_id then
      raise exception 'One-sided retained conversations are read-only' using errcode='55000';
    end if;
    active_profile:=public.current_active_profile_id();
    if active_profile is null or new.sender_profile_id<>active_profile
       or (new.sender_profile_id is distinct from c.buyer_profile_id and new.sender_profile_id is distinct from c.seller_profile_id) then
      raise exception 'Message sender must be the active conversation participant' using errcode='42501';
    end if;
    if tg_op='UPDATE' and (new.sender_profile_id is distinct from old.sender_profile_id or new.conversation_id is distinct from old.conversation_id) then
      raise exception 'Message identity is immutable' using errcode='42501';
    end if;
    return new;
  end$fn$$ddl$;

  execute $ddl$create or replace function public.guard_conversation_unread_participants()
  returns trigger language plpgsql volatile security definer set search_path=''
  as $fn$
  declare value text; parsed uuid; seen uuid[]:='{}'::uuid[];
  begin
    if tg_when<>'BEFORE' or tg_level<>'ROW' or tg_table_schema<>'public' or tg_table_name<>'conversations' then
      raise exception 'Unexpected guard_conversation_unread_participants trigger context' using errcode='42501';
    end if;
    foreach value in array coalesce(new.unread_for,'{}'::text[]) loop
      if value !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
        raise exception 'Unread profile identifier must be a canonical RFC-4122 UUID' using errcode='23514';
      end if;
      parsed:=value::uuid;
      if parsed is distinct from new.buyer_profile_id and parsed is distinct from new.seller_profile_id then
        raise exception 'Unread state may reference only a present participant' using errcode='23514';
      end if;
      if parsed=any(seen) then raise exception 'Unread state may not contain duplicate UUID identities' using errcode='23514'; end if;
      seen:=array_append(seen,parsed);
    end loop;
    return new;
  end$fn$$ddl$;

  execute $ddl$create or replace function public.guard_conversation_participant_state()
  returns trigger language plpgsql volatile security definer set search_path=''
  as $fn$
  declare c public.conversations%rowtype;
  begin
    if tg_when<>'BEFORE' or tg_level<>'ROW' or tg_table_schema<>'public' or tg_table_name<>'conversation_participant_state' or tg_op not in ('INSERT','UPDATE') then
      raise exception 'Unexpected guard_conversation_participant_state trigger context' using errcode='42501';
    end if;
    select * into c from public.conversations where id=new.conversation_id;
    if not found then raise exception 'Participant-state parent does not exist' using errcode='23503'; end if;
    if new.profile_id is distinct from c.buyer_profile_id and new.profile_id is distinct from c.seller_profile_id then
      raise exception 'Participant state may reference only a present side' using errcode='23514';
    end if;
    return new;
  end$fn$$ddl$;

  execute $ddl$create or replace function public.enforce_conversation_listing_seller()
  returns trigger language plpgsql volatile security definer set search_path=''
  as $fn$
  declare expected_seller_profile_id uuid;
  begin
    if tg_when<>'BEFORE' or tg_level<>'ROW' or tg_table_schema<>'public' or tg_table_name<>'conversations' then raise exception 'Unexpected listing-seller trigger context' using errcode='42501'; end if;
    if new.listing_id is null or new.seller_profile_id is null then return new; end if;
    select l.profile_id into expected_seller_profile_id from public.listings l where l.id=new.listing_id;
    if expected_seller_profile_id is null then raise exception 'Listing does not exist' using errcode='23503'; end if;
    if new.seller_profile_id<>expected_seller_profile_id then raise exception 'Conversation seller must own the linked listing' using errcode='23514'; end if;
    return new;
  end$fn$$ddl$;

  execute $ddl$create or replace function public.unhide_conversation_for_message_recipient()
  returns trigger language plpgsql volatile security definer set search_path=''
  as $fn$
  declare affected_rows bigint;
  begin
    if tg_when<>'AFTER' or tg_level<>'ROW' or tg_op<>'INSERT' or tg_table_schema<>'public' or tg_table_name<>'messages' then raise exception 'Unexpected recipient-unhide trigger context' using errcode='42501'; end if;
    update public.conversation_participant_state s set hidden_at=null,updated_at=pg_catalog.now()
    from public.conversations c where c.id=new.conversation_id and c.buyer_profile_id is not null and c.seller_profile_id is not null and c.buyer_profile_id<>c.seller_profile_id
      and new.sender_profile_id in(c.buyer_profile_id,c.seller_profile_id) and s.conversation_id=c.id and s.hidden_at is not null
      and s.profile_id=case when new.sender_profile_id=c.buyer_profile_id then c.seller_profile_id else c.buyer_profile_id end;
    get diagnostics affected_rows=row_count;
    return new;
  end$fn$$ddl$;

  execute $ddl$create or replace function public.update_conversation_last_message()
  returns trigger language plpgsql volatile security definer set search_path=''
  as $fn$
  declare affected_rows bigint;
  begin
    if tg_when<>'AFTER' or tg_level<>'ROW' or tg_op<>'INSERT' or tg_table_schema<>'public' or tg_table_name<>'messages' then raise exception 'Unexpected update_conversation_last_message trigger context' using errcode='42501'; end if;
    update public.conversations c set last_message_at=new.created_at,last_message_body=pg_catalog.left(new.body,120)
    where c.id=new.conversation_id and c.buyer_profile_id is not null and c.seller_profile_id is not null and c.buyer_profile_id<>c.seller_profile_id
      and new.sender_profile_id is not null and new.sender_profile_id in(c.buyer_profile_id,c.seller_profile_id);
    get diagnostics affected_rows=row_count;
    if affected_rows <> 1 then raise exception 'Message parent conversation does not exist' using errcode='23503'; end if;
    return new;
  end$fn$$ddl$;

  execute 'revoke all on function public.guard_conversation_participants() from public; revoke execute on function public.guard_conversation_participants() from anon,authenticated; grant execute on function public.guard_conversation_participants() to service_role';
  execute 'revoke all on function public.guard_message_active_participant() from public; revoke execute on function public.guard_message_active_participant() from anon,authenticated; grant execute on function public.guard_message_active_participant() to service_role';
  execute 'revoke all on function public.guard_conversation_unread_participants() from public; revoke execute on function public.guard_conversation_unread_participants() from anon,authenticated; grant execute on function public.guard_conversation_unread_participants() to service_role';
  execute 'revoke all on function public.guard_conversation_participant_state() from public; revoke execute on function public.guard_conversation_participant_state() from anon,authenticated; grant execute on function public.guard_conversation_participant_state() to service_role';
  execute 'revoke all on function public.enforce_conversation_listing_seller() from public; revoke execute on function public.enforce_conversation_listing_seller() from anon,authenticated; grant execute on function public.enforce_conversation_listing_seller() to service_role';
  execute 'revoke all on function public.unhide_conversation_for_message_recipient() from public; revoke execute on function public.unhide_conversation_for_message_recipient() from anon,authenticated; grant execute on function public.unhide_conversation_for_message_recipient() to service_role';
  execute 'revoke all on function public.update_conversation_last_message() from public; revoke execute on function public.update_conversation_last_message() from anon,authenticated; grant execute on function public.update_conversation_last_message() to service_role';

  execute 'create trigger conversations_guard_participants before insert or update of buyer_profile_id,seller_profile_id on public.conversations for each row execute function public.guard_conversation_participants()';
  execute 'create trigger conversations_guard_unread before insert or update of unread_for on public.conversations for each row execute function public.guard_conversation_unread_participants()';
  execute 'create trigger messages_guard_active_participant before insert or update of conversation_id,sender_profile_id on public.messages for each row execute function public.guard_message_active_participant()';
  execute 'create trigger conversation_participant_state_guard before insert or update of conversation_id,profile_id on public.conversation_participant_state for each row execute function public.guard_conversation_participant_state()';
end
$mp4e$;

-- Transactional postconditions: failure aborts every authored change.
do $post$
declare n int;
begin
  select count(*) into n from pg_attribute a where a.attrelid in ('public.conversations'::regclass,'public.messages'::regclass) and a.attname in ('buyer_profile_id','seller_profile_id','sender_profile_id') and not a.attnotnull;
  if n<>3 then raise exception 'MP4-E postcondition: nullability mismatch'; end if;
  if (select count(*) from pg_trigger where not tgisinternal and (tgrelid,tgname) in (('public.conversations'::regclass,'conversations_guard_participants'),('public.conversations'::regclass,'conversations_guard_unread'),('public.messages'::regclass,'messages_guard_active_participant'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard')))<>4 then raise exception 'MP4-E postcondition: guard trigger mismatch'; end if;
  if exists(select 1 from pg_constraint where conname in ('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey') and confdeltype<>'c') then raise exception 'MP4-E postcondition: live CASCADE action changed'; end if;
  if exists(select 1 from public.conversations where buyer_profile_id is null or seller_profile_id is null) or exists(select 1 from public.messages where sender_profile_id is null) then raise exception 'MP4-E postcondition: package introduced null live values'; end if;
end$post$;

-- HOLD — deliberately NOT EXECUTED in MP4-E:
-- 1. participant/sender profile FKs CASCADE -> SET NULL;
-- 2. cleanup of deleted IDs from unread_for and deleted-side participant state;
-- 3. retained-conversation uniqueness/find-or-create treatment;
-- 4. both-null final-participant/account-deletion cleanup.
-- Those artifacts require fresh live pins and coordinated MP4-F/G + MP-8/12/13 approval.
commit;
