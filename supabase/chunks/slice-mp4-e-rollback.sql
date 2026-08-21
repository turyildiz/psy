-- psy.market Slice MP-4-E ROLLBACK — exact target -> reviewed source.
-- Refuses rollback if any retained null exists or any target guard has drifted.
begin;
set local row_security=off;
lock table public.profiles,public.listings,public.conversations,public.messages,
 public.conversation_participant_state in share row exclusive mode;

do $mp4e_rollback$
declare source_state boolean; target_state boolean; missing_guard int;
begin
 if current_user<>'postgres' or session_user<>'postgres' or not(select rolsuper or rolbypassrls from pg_roles where rolname=current_user) then raise exception 'MP4-E ROLLBACK requires complete postgres owner context' using errcode='42501'; end if;
 select count(*) filter(where a.attnotnull)=3 and to_regprocedure('public.guard_conversation_participants()') is null and to_regprocedure('public.guard_message_active_participant()') is null
 and (select count(*)=3 from pg_trigger t join pg_proc p on p.oid=t.tgfoid where not t.tgisinternal and (t.tgrelid,t.tgname,p.proname) in (('public.conversations'::regclass,'conversations_enforce_listing_seller','enforce_conversation_listing_seller'),('public.messages'::regclass,'messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient'),('public.messages'::regclass,'on_message_insert','update_conversation_last_message')))
 and (select count(*)=5 from pg_constraint where conname in ('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey') and confdeltype='c')
 and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='enforce_conversation_listing_seller' and p.prosrc like '%Conversation seller must own the linked listing%')
 and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='unhide_conversation_for_message_recipient' and p.prosrc like '%s.hidden_at is not null%') into source_state
 from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and (c.relname,a.attname) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id'));
 if source_state then return; end if;
 select count(*) filter(where not a.attnotnull)=3 and to_regprocedure('public.guard_conversation_participants()') is not null and to_regprocedure('public.guard_message_active_participant()') is not null and to_regprocedure('public.guard_conversation_unread_participants()') is not null and to_regprocedure('public.guard_conversation_participant_state()') is not null
 and (select count(*)=7 from pg_trigger t join pg_proc p on p.oid=t.tgfoid where not t.tgisinternal and (t.tgrelid,t.tgname,p.proname) in (('public.conversations'::regclass,'conversations_enforce_listing_seller','enforce_conversation_listing_seller'),('public.conversations'::regclass,'conversations_guard_participants','guard_conversation_participants'),('public.conversations'::regclass,'conversations_guard_unread','guard_conversation_unread_participants'),('public.messages'::regclass,'messages_guard_active_participant','guard_message_active_participant'),('public.messages'::regclass,'messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient'),('public.messages'::regclass,'on_message_insert','update_conversation_last_message'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard','guard_conversation_participant_state')))
 and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='guard_message_active_participant' and p.prosrc like '%One-sided retained conversations are read-only%' and p.prosrc like '%current_active_profile_id%')
 and not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('enforce_conversation_listing_seller','guard_conversation_participants','guard_conversation_unread_participants','guard_message_active_participant','guard_conversation_participant_state','unhide_conversation_for_message_recipient','update_conversation_last_message') and (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) in ('PUBLIC','anon','authenticated')) into target_state
 from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and (c.relname,a.attname) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id'));
 if not target_state then raise exception 'MP4-E ROLLBACK target drift' using errcode='55000'; end if;
 if exists(select 1 from public.conversations where buyer_profile_id is null or seller_profile_id is null) or exists(select 1 from public.messages where sender_profile_id is null) then raise exception 'MP4-E ROLLBACK unsafe: retained null participant/sender rows exist' using errcode='55000'; end if;
 select 4-count(*) into missing_guard from pg_trigger where not tgisinternal and (tgrelid,tgname) in (('public.conversations'::regclass,'conversations_guard_participants'),('public.conversations'::regclass,'conversations_guard_unread'),('public.messages'::regclass,'messages_guard_active_participant'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard'));
 if missing_guard<>0 then raise exception 'MP4-E ROLLBACK guard-trigger drift' using errcode='55000'; end if;

 execute 'drop trigger conversations_guard_participants on public.conversations';
 execute 'drop trigger conversations_guard_unread on public.conversations';
 execute 'drop trigger messages_guard_active_participant on public.messages';
 execute 'drop trigger conversation_participant_state_guard on public.conversation_participant_state';
 execute 'drop function public.guard_conversation_participants()';
 execute 'drop function public.guard_conversation_unread_participants()';
 execute 'drop function public.guard_message_active_participant()';
 execute 'drop function public.guard_conversation_participant_state()';

 execute $ddl$create or replace function public.enforce_conversation_listing_seller()
 returns trigger language plpgsql security definer set search_path=pg_catalog,public as $fn$
 declare expected_seller_profile_id uuid;
 begin
  if new.listing_id is null then return new; end if;
  select l.profile_id into expected_seller_profile_id from public.listings l where l.id=new.listing_id;
  if expected_seller_profile_id is null then raise exception 'Listing does not exist'; end if;
  if new.seller_profile_id<>expected_seller_profile_id then raise exception 'Conversation seller must own the linked listing'; end if;
  return new;
 end$fn$$ddl$;
 execute $ddl$create or replace function public.unhide_conversation_for_message_recipient()
 returns trigger language plpgsql security definer set search_path=pg_catalog,public as $fn$
 begin
  update public.conversation_participant_state s set hidden_at=null,updated_at=now()
  from public.conversations c where c.id=new.conversation_id and s.conversation_id=c.id and s.hidden_at is not null
   and s.profile_id=case when new.sender_profile_id=c.buyer_profile_id then c.seller_profile_id when new.sender_profile_id=c.seller_profile_id then c.buyer_profile_id else null end;
  return new;
 end$fn$$ddl$;
 execute $ddl$create or replace function public.update_conversation_last_message()
 returns trigger language plpgsql volatile security definer set search_path='' as $fn$
 declare affected_rows bigint;
 begin
  if tg_when<>'AFTER' or tg_level<>'ROW' or tg_op<>'INSERT' or tg_table_schema<>'public' or tg_table_name<>'messages' then raise exception 'Unexpected update_conversation_last_message trigger context' using errcode='42501'; end if;
  update public.conversations as c set last_message_at=new.created_at,last_message_body=pg_catalog.left(new.body,120) where c.id=new.conversation_id;
  get diagnostics affected_rows=row_count;
  if affected_rows<>1 then raise exception 'Message parent conversation does not exist' using errcode='23503'; end if;
  return new;
 end$fn$$ddl$;
 execute 'revoke all on function public.enforce_conversation_listing_seller() from public; revoke execute on function public.enforce_conversation_listing_seller() from anon,authenticated; grant execute on function public.enforce_conversation_listing_seller() to service_role';
 execute 'revoke all on function public.unhide_conversation_for_message_recipient() from public; revoke execute on function public.unhide_conversation_for_message_recipient() from anon,authenticated; grant execute on function public.unhide_conversation_for_message_recipient() to service_role';
 execute 'revoke all on function public.update_conversation_last_message() from public; revoke execute on function public.update_conversation_last_message() from anon,authenticated; grant execute on function public.update_conversation_last_message() to service_role';
 execute 'alter table public.conversations drop constraint conversations_buyer_seller_differ';
 execute 'alter table public.conversations add constraint conversations_buyer_seller_differ check (buyer_profile_id<>seller_profile_id)';
 execute 'alter table public.conversations alter column buyer_profile_id set not null,alter column seller_profile_id set not null';
 execute 'alter table public.messages alter column sender_profile_id set not null';
end$mp4e_rollback$;

do $post$
begin
 if (select count(*) from pg_attribute a where a.attrelid in('public.conversations'::regclass,'public.messages'::regclass) and a.attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and a.attnotnull)<>3 then raise exception 'MP4-E rollback postcondition: NOT NULL restoration failed'; end if;
 if to_regprocedure('public.guard_conversation_participants()') is not null or to_regprocedure('public.guard_message_active_participant()') is not null then raise exception 'MP4-E rollback postcondition: target guards remain'; end if;
 if exists(select 1 from pg_constraint where conname in('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey') and confdeltype<>'c') then raise exception 'MP4-E rollback postcondition: live cascade drift'; end if;
end$post$;
commit;
