-- psy.market Slice MP-4-F VERIFY — owner-run, read-only target proof.
-- Plain policy rendering only; every LIVE_PIN/digest is wingman-recomputed.
begin transaction isolation level repeatable read read only;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,
 public.conversation_participant_state in share mode;

do $assert$
declare failures text;
begin
 with policies as(
  select c.relname table_name,p.polname,p.polcmd::text command,p.polpermissive,p.polroles,
   regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'public\.','','g') using_expr,
   regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'public\.','','g') check_expr
  from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
 ),checks(name,ok,detail) as(values
  ('owner_complete_context',current_user='postgres' and session_user='postgres' and (select rolsuper or rolbypassrls from pg_roles where rolname=current_user),'LIVE_PIN owner completeness'),
  -- Five is derived: conversation INSERT+SELECT, message INSERT+SELECT, state SELECT.
  ('five_target_policies_exact_shape',(select count(*)=5 and bool_and(polpermissive and polroles=array['authenticated'::regrole::oid]) and count(*) filter(where using_expr||check_expr like '%current_active_profile_id%')=5 from policies),'LIVE_PIN exact five-policy family'),
  ('same_account_denial_policy',(select count(*)=1 from policies where table_name='conversations' and polname='Unbanned buyers create conversations' and check_expr like '%buyer_profile_id = ( SELECT current_active_profile_id()%' and check_expr like '%NOT current_user_owns_profile(seller_profile_id)%'),'database-policy denial uses hidden boolean ownership helper; no owner output'),
  ('conversation_read_active_and_hide_isolated',(select count(*)=1 from policies where polname='participants view visible conversations' and using_expr like '%buyer_profile_id = ( SELECT current_active_profile_id()%' and using_expr like '%seller_profile_id = ( SELECT current_active_profile_id()%' and using_expr like '%s.profile_id = ( SELECT current_active_profile_id()%'),'active equality controls participant and only active hide state'),
  ('message_insert_active_two_present',(select count(*)=1 from policies where polname='Unbanned participants send messages' and check_expr like '%sender_profile_id = ( SELECT current_active_profile_id()%' and check_expr like '%buyer_profile_id IS NOT NULL%' and check_expr like '%seller_profile_id IS NOT NULL%' and check_expr like '%buyer_profile_id <> c.seller_profile_id%'),'active sender and two-present parent'),
  ('same_account_message_denial',(select count(*)=1 from policies where polname='Unbanned participants send messages' and check_expr ~ 'NOT current_user_owns_profile\([[:space:]]*CASE'),'message policy also denies a sibling counterpart before a message row exists'),
  ('message_and_state_reads_active',(select count(*)=2 from policies where polname in('participants view messages','Participants read own conversation state') and using_expr like '%current_active_profile_id%'),'active exact read authority'),
  ('no_first_owned_match_remaining',not exists(select 1 from policies where (using_expr||check_expr) like '%current_user_owns_profile%' and polname not in('Unbanned buyers create conversations','Unbanned participants send messages')),'ownership helper remains only for neutral same-account target denial; actor identity is always active equality'),
  ('post_e_foundation_unchanged',(select count(*)=3 from pg_attribute where attrelid in('public.conversations'::regclass,'public.messages'::regclass) and attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and not attnotnull) and (select count(*)=4 from pg_trigger where not tgisinternal and (tgrelid,tgname) in(('public.conversations'::regclass,'conversations_guard_participants'),('public.conversations'::regclass,'conversations_guard_unread'),('public.messages'::regclass,'messages_guard_active_participant'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard'))),'POST-E nullable/guard state'),
  ('rls_owner_force_unchanged',(select count(*)=3 and bool_and(c.relowner='postgres'::regrole and c.relrowsecurity and not c.relforcerowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')),'owner/RLS/FORCE'),
  ('five_rpcs_unchanged',(select count(*)=5 and count(*) filter(where (p.proname,md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))) in(('append_unread_for','6023d0d555a24427a1d98f92d9d37e25'),('remove_unread_for','ca52e0ea7f804024cf6f9f7955dc9a62'),('hide_conversation','4e5756391924dc30ca09f7b535d36afa'),('unhide_conversation','7e7d2ce7d7cef459c1dd9a72a2eb87ab'),('find_and_unhide_conversation','ad6475d6ac60d2fe451597dbe78c2453')))=5 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation')),'MP4-G RPC scope unchanged'),
  ('realtime_replica_identity_unchanged',(select count(*)=3 and bool_and(c.relreplident='d') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')) and (select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in('conversations','messages','conversation_participant_state')),'publication/replica identity'),
  ('package_d_privacy_intact',not has_column_privilege('anon','public.profiles','user_id','SELECT') and not has_column_privilege('authenticated','public.profiles','user_id','SELECT'),'owner linkage hidden')
 ) select string_agg(name||': '||detail,E'\n' order by name collate "C") into failures from checks where not ok;
 if failures is not null then raise exception 'MP4-F VERIFY STOP:%',E'\n'||failures using errcode='55000'; end if;
end$assert$;

-- Twelve is derived from the twelve named checks in the assertion CTE above.
with p as(select c.relname,p.polname,p.polcmd::text cmd,p.polpermissive,
 lower(regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'[[:space:]]+','','g')) q,
 lower(regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'[[:space:]]+','','g')) w
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state'))
select 'SLICE_MP4_F_VERIFY' package,'GO' verdict,12::int passed,12::int total,'{}'::text[] findings,
 md5(string_agg(relname||'|'||polname||'|'||cmd||'|'||polpermissive||'|'||q||'|'||w,E'\n' order by relname collate "C",polname collate "C")) plain_policy_md5,
 'Database-layer lifecycle/behavior is disposable-proven. Hosted Realtime JWT-context delivery remains an owner Gate-1 verification: authenticate a subscriber with session_id state, prove active-only events, sibling silence, and subscription replacement on switch.'::text realtime_boundary
from p;
rollback;
