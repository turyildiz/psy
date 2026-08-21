-- psy.market Slice MP-4-F PREFLIGHT — owner-run, no DML/DDL.
-- Plain policy rendering matches pg_policies (pg_get_expr(..., false)).
-- Every LIVE_PIN and displayed digest/row set must be recomputed by the wingman.
begin transaction isolation level repeatable read read only;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,
 public.conversation_participant_state in share mode;

with
policy_state as (
 select c.relname table_name,p.polname,p.polcmd::text command,p.polpermissive,
  array(select case when r=0 then 'PUBLIC' else r::regrole::text end from unnest(p.polroles) r order by (case when r=0 then 'PUBLIC' else r::regrole::text end) collate "C") roles,
  lower(regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'[[:space:]]+','','g')) using_expr,
  lower(regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'[[:space:]]+','','g')) check_expr
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
),
policy_acl as (
 select c.relname table_name,a.grantor::regrole::text grantor,
  case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end grantee,
  a.privilege_type,a.is_grantable
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
 where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
),
rpc_state as (
 select p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') args,
  md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g'))) body_hash,
  p.proowner::regrole::text owner,p.prosecdef,p.provolatile::text volatility,
  coalesce((select string_agg(case when cfg in('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by cfg collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>') settings
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation')
),
checks(name,ok,detail) as (values
 ('owner_complete_context',current_user='postgres' and session_user='postgres' and (select rolsuper or rolbypassrls from pg_roles where rolname=current_user),'LIVE_PIN: owner/BYPASSRLS complete read path'),
 ('five_source_policies_exact_shape',(select count(*)=5 and bool_and(polpermissive and roles=array['authenticated'])
   and count(*) filter(where using_expr||check_expr like '%current_user_owns_profile%')=5
   and count(*) filter(where using_expr||check_expr like '%current_active_profile_id%')=0 from policy_state),'LIVE_PIN: exact five post-E policy rows; wingman compares displayed plain expressions bidirectionally'),
 ('policy_names_commands_exact',not exists((select table_name,polname,command from policy_state) except(values
   ('conversation_participant_state','Participants read own conversation state','r'),('conversations','Unbanned buyers create conversations','a'),('conversations','participants view visible conversations','r'),('messages','Unbanned participants send messages','a'),('messages','participants view messages','r')))
   and not exists((values ('conversation_participant_state','Participants read own conversation state','r'),('conversations','Unbanned buyers create conversations','a'),('conversations','participants view visible conversations','r'),('messages','Unbanned participants send messages','a'),('messages','participants view messages','r')) except select table_name,polname,command from policy_state),'LIVE_PIN: complete policy name/command set; five is derived above'),
 ('post_e_nullable_guards_exact',(select count(*)=3 from pg_attribute where attrelid in('public.conversations'::regclass,'public.messages'::regclass) and attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and not attnotnull)
   and (select count(*)=4 from pg_trigger where not tgisinternal and (tgrelid,tgname) in(('public.conversations'::regclass,'conversations_guard_participants'),('public.conversations'::regclass,'conversations_guard_unread'),('public.messages'::regclass,'messages_guard_active_participant'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard'))),'LIVE_PIN: POST-E nullable columns and four guards'),
 ('table_owner_rls_force_exact',(select count(*)=3 and bool_and(c.relowner='postgres'::regrole and c.relrowsecurity and not c.relforcerowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')),'LIVE_PIN: exact owner/RLS/FORCE-RLS'),
 ('table_acl_security_boundary',(select count(*)>0 from policy_acl)
   and not exists(select 1 from policy_acl where table_name='conversation_participant_state' and grantee in('PUBLIC','anon','authenticated') and privilege_type<>'SELECT')
   and not exists(select 1 from policy_acl where table_name in('conversations','messages') and grantee in('PUBLIC','anon') and privilege_type in('INSERT','UPDATE','DELETE')),'LIVE_PIN: exploded ACL set displayed below; no anonymous mutation or direct state mutation'),
 ('active_and_ownership_helpers_present',to_regprocedure('public.current_active_profile_id()') is not null and to_regprocedure('public.current_user_owns_profile(uuid)') is not null and to_regprocedure('public.current_user_is_banned()') is not null,'LIVE_PIN: active, same-account ownership and account-ban dependencies'),
 ('five_live_rpcs_exact',(select count(*)=5 and bool_and(owner='postgres' and prosecdef and volatility='v' and settings='search_path=pg_catalog, public, auth')
   and count(*) filter(where (proname,body_hash) in(('append_unread_for','6023d0d555a24427a1d98f92d9d37e25'),('remove_unread_for','ca52e0ea7f804024cf6f9f7955dc9a62'),('hide_conversation','4e5756391924dc30ca09f7b535d36afa'),('unhide_conversation','7e7d2ce7d7cef459c1dd9a72a2eb87ab'),('find_and_unhide_conversation','ad6475d6ac60d2fe451597dbe78c2453')))=5 from rpc_state)
   and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='find_and_unhide_conversation' and p.prosrc like '%caller_profile_count > 1%'),'LIVE_PIN: five real RPC bodies; find RPC retains multi-profile ambiguity guard for MP4-G'),
 ('realtime_replica_identity_exact',(select count(*)=3 and bool_and(c.relreplident='d') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')) and (select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in('conversations','messages','conversation_participant_state')),'LIVE_PIN: publication membership and replica identity unchanged'),
 ('package_d_privacy_intact',not has_column_privilege('anon','public.profiles','user_id','SELECT') and not has_column_privilege('authenticated','public.profiles','user_id','SELECT'),'LIVE_PIN: sibling linkage remains hidden')
),summary as(select bool_and(ok) all_ok,count(*) filter(where ok)::int passed,count(*)::int total,coalesce(array_agg(name||': '||detail order by name collate "C") filter(where not ok),'{}'::text[]) findings from checks)
select 'SLICE_MP4_F_PREFLIGHT' package,case when all_ok then 'GO' else 'STOP' end verdict,passed,total,findings,
 (select md5(coalesce(string_agg(table_name||'|'||polname||'|'||command||'|'||polpermissive||'|'||array_to_string(roles,',')||'|'||using_expr||'|'||check_expr,E'\n' order by table_name collate "C",polname collate "C"),'')) from policy_state) plain_policy_md5,
 (select md5(coalesce(string_agg(table_name||'|'||grantor||'|'||grantee||'|'||privilege_type||'|'||is_grantable,E'\n' order by table_name collate "C",grantor collate "C",grantee collate "C",privilege_type collate "C"),'')) from policy_acl) exploded_table_acl_md5,
 'LIVE_PIN recompute: plain five-policy rows/digest; exploded table ACL rows/digest; owners/RLS/FORCE; active/ownership/ban helper overloads, attributes, bodies and ACLs; five RPC hashes/ACLs; POST-E nullable/guard objects; publication/replica identity; Package-D profile owner-column privacy.'::text wingman_recompute,
 'Repository-authored from recorded post-E state; owner-hosted pins remain mandatory. No fixture row was inferred for live execution.'::text boundary
from summary;
rollback;
