-- psy.market Slice MP-4-F PREFLIGHT — owner-run, no DML/DDL.
-- Plain policy rendering matches pg_policies (pg_get_expr(..., false)).
-- Every LIVE_PIN and displayed digest/row set must be recomputed by the wingman.
-- DECLARED BOUNDARIES:
-- * Gate-1 authenticated-session coverage remains open. Every messaging read now depends on
--   session-derived active identity; a missing/invalid session_id silently yields an empty inbox.
-- * mp4-policy-conversion-verify.sql intentionally STOPs after F because it pins the superseded
--   ownership expressions. Do not modify or use that historical verifier for post-F state.
-- * Active-authority policies become exactly 23 after F: 13 social/event + 5 profile/listing
--   + 5 conversation policies. Rollback returns the count to 18.
begin transaction isolation level repeatable read read only;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,
 public.conversation_participant_state in share mode;

-- Human-inspectable manifests. These are intentionally emitted as rows as well as asserted
-- bidirectionally below; digests are convenience summaries, never substitutes for the rows.
select 'SOURCE_POLICY_ROW' record_type,c.relname table_name,p.polname,p.polcmd::text command,p.polpermissive,
 array(select case when r=0 then 'PUBLIC' else r::regrole::text end from unnest(p.polroles) r order by (case when r=0 then 'PUBLIC' else r::regrole::text end) collate "C") roles,
 lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) using_expr,
 lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) check_expr
from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
order by c.relname collate "C",p.polname collate "C";

select 'TABLE_ACL_ROW' record_type,c.relname table_name,a.grantor::regrole::text grantor,
 case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end grantee,a.privilege_type,a.is_grantable
from pg_class c join pg_namespace n on n.oid=c.relnamespace
cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
order by c.relname collate "C",(a.grantor::regrole::text) collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C";

select 'AUTH_HELPER_ROW' record_type,n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'(public|private)\.','','g') args,
 p.proowner::regrole::text owner,l.lanname,p.provolatile::text volatility,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text parallel,p.pronargdefaults,
 coalesce((select string_agg(case when cfg in('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by cfg collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>') settings,
 regexp_replace(pg_get_function_result(p.oid),'(public|private)\.','','g') result,md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g'))) body_hash
from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in('current_active_profile_id','current_user_owns_profile','current_user_is_banned'))
order by n.nspname collate "C",p.proname collate "C";

select 'AUTH_HELPER_ACL_ROW' record_type,n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'(public|private)\.','','g')||')' object_name,
 a.grantor::regrole::text grantor,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end grantee,a.privilege_type,a.is_grantable
from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in('current_active_profile_id','current_user_owns_profile','current_user_is_banned'))
order by (n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'(public|private)\.','','g')||')') collate "C",(a.grantor::regrole::text) collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C";

with
policy_state as (
 select c.relname table_name,p.polname,p.polcmd::text command,p.polpermissive,
  array(select case when r=0 then 'PUBLIC' else r::regrole::text end from unnest(p.polroles) r order by (case when r=0 then 'PUBLIC' else r::regrole::text end) collate "C") roles,
  lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) using_expr,
  lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) check_expr
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
),
expected_policy_state(table_name,polname,command,polpermissive,roles,using_expr,check_expr) as (values
 ('conversation_participant_state','Participants read own conversation state','r',true,array['authenticated'],'current_user_owns_profile(profile_id)',''),
 ('conversations','Unbanned buyers create conversations','a',true,array['authenticated'],'','((notcurrent_user_is_banned())andcurrent_user_owns_profile(buyer_profile_id)and(buyer_profile_id<>seller_profile_id)and((listing_idisnull)or(seller_profile_id=(selectl.profile_idfromlistingslwhere(l.id=conversations.listing_id)))))'),
 ('conversations','participants view visible conversations','r',true,array['authenticated'],'((current_user_owns_profile(buyer_profile_id)orcurrent_user_owns_profile(seller_profile_id))and(not(exists(select1fromconversation_participant_stateswhere((s.conversation_id=conversations.id)andcurrent_user_owns_profile(s.profile_id)and(s.hidden_atisnotnull))))))',''),
 ('messages','Unbanned participants send messages','a',true,array['authenticated'],'','((notcurrent_user_is_banned())andcurrent_user_owns_profile(sender_profile_id)and(conversation_idin(selectc.idfromconversationscwhere((messages.sender_profile_id=c.buyer_profile_id)or(messages.sender_profile_id=c.seller_profile_id)))))'),
 ('messages','participants view messages','r',true,array['authenticated'],'(conversation_idin(selectc.idfromconversationscwhere(current_user_owns_profile(c.buyer_profile_id)orcurrent_user_owns_profile(c.seller_profile_id))))','')
),
policy_acl as (
 select c.relname table_name,a.grantor::regrole::text grantor,
  case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end grantee,
  a.privilege_type,a.is_grantable
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
 where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
),
legal_privileges(privilege_type) as (
 select unnest(case when current_setting('server_version_num')::int>=170000
  then array['DELETE','INSERT','MAINTAIN','REFERENCES','SELECT','TRIGGER','TRUNCATE','UPDATE']
  else array['DELETE','INSERT','REFERENCES','SELECT','TRIGGER','TRUNCATE','UPDATE'] end)
),
expected_policy_acl(table_name,grantor,grantee,privilege_type,is_grantable) as (
 select t,'postgres',r,p,false from unnest(array['conversation_participant_state','conversations','messages']) t cross join unnest(array['postgres','service_role']) r cross join legal_privileges l(p)
 union all select 'conversations','postgres',r,p,false from unnest(array['anon','authenticated']) r cross join legal_privileges l(p) where p<>'DELETE'
 union all select 'messages','postgres',r,p,false from unnest(array['anon','authenticated']) r cross join legal_privileges l(p)
 union all select 'conversation_participant_state','postgres','authenticated','SELECT',false
),
helper_state as (
 select n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'(public|private)\.','','g') args,
  p.proowner::regrole::text owner,l.lanname,p.provolatile::text volatility,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text parallel,p.pronargdefaults,
  coalesce((select string_agg(case when cfg in('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by cfg collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>') settings,
  regexp_replace(pg_get_function_result(p.oid),'(public|private)\.','','g') result,
  md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g'))) body_hash
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where (n.nspname='private' and p.proname='current_active_profile_id') or
  (n.nspname='public' and p.proname in('current_active_profile_id','current_user_owns_profile','current_user_is_banned'))
),
expected_helper_state(nspname,proname,args,owner,lanname,volatility,prosecdef,proisstrict,proleakproof,parallel,pronargdefaults,settings,result,body_hash) as (values
 ('private','current_active_profile_id','','postgres','plpgsql','s',true,false,false,'u',0,'search_path=<empty>','uuid','8ab19811ddcf117a757e7663efc5ac77'),
 ('public','current_active_profile_id','','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','uuid','6f6b53dbd223db8ba168073c196f7b1a'),
 ('public','current_user_owns_profile','target_profile_id uuid','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','boolean','b18b8e4f01df72097d092352423ab8af'),
 ('public','current_user_is_banned','','postgres','sql','s',true,false,false,'u',0,'search_path=pg_catalog, public, auth','boolean','682d0a1d82cd433e5bd7deb4aeee5ede')
),
helper_acl as (
 select n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'(public|private)\.','','g')||')' object_name,
  a.grantor::regrole::text grantor,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end grantee,a.privilege_type,a.is_grantable
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in('current_active_profile_id','current_user_owns_profile','current_user_is_banned'))
),
expected_helper_acl(object_name,grantor,grantee,privilege_type,is_grantable) as (values
 ('private.current_active_profile_id()','postgres','postgres','EXECUTE',false),
 ('public.current_active_profile_id()','postgres','authenticated','EXECUTE',false),('public.current_active_profile_id()','postgres','postgres','EXECUTE',false),
 ('public.current_user_owns_profile(target_profile_id uuid)','postgres','authenticated','EXECUTE',false),('public.current_user_owns_profile(target_profile_id uuid)','postgres','postgres','EXECUTE',false),
 ('public.current_user_is_banned()','postgres','authenticated','EXECUTE',false),('public.current_user_is_banned()','postgres','postgres','EXECUTE',false),('public.current_user_is_banned()','postgres','service_role','EXECUTE',false)
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
 ('five_source_policies_exact_shape',not exists((select * from policy_state except select * from expected_policy_state) union all (select * from expected_policy_state except select * from policy_state)),'LIVE_PIN: exact five post-E policy rows, plain renderer, normalized public qualification'),
 ('policy_names_commands_exact',not exists((select table_name,polname,command from policy_state) except(values
   ('conversation_participant_state','Participants read own conversation state','r'),('conversations','Unbanned buyers create conversations','a'),('conversations','participants view visible conversations','r'),('messages','Unbanned participants send messages','a'),('messages','participants view messages','r')))
   and not exists((values ('conversation_participant_state','Participants read own conversation state','r'),('conversations','Unbanned buyers create conversations','a'),('conversations','participants view visible conversations','r'),('messages','Unbanned participants send messages','a'),('messages','participants view messages','r')) except select table_name,polname,command from policy_state),'LIVE_PIN: complete policy name/command set; five is derived above'),
 ('post_e_nullable_guards_exact',(select count(*)=3 from pg_attribute where attrelid in('public.conversations'::regclass,'public.messages'::regclass) and attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and not attnotnull)
   and (select count(*)=4 from pg_trigger where not tgisinternal and (tgrelid,tgname) in(('public.conversations'::regclass,'conversations_guard_participants'),('public.conversations'::regclass,'conversations_guard_unread'),('public.messages'::regclass,'messages_guard_active_participant'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard'))),'LIVE_PIN: POST-E nullable columns and four guards'),
 ('table_owner_rls_force_exact',(select count(*)=3 and bool_and(c.relowner='postgres'::regrole and c.relrowsecurity and not c.relforcerowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')),'LIVE_PIN: exact owner/RLS/FORCE-RLS'),
 ('table_acl_security_boundary',not exists((select * from policy_acl except select * from expected_policy_acl) union all (select * from expected_policy_acl except select * from policy_acl)),'LIVE_PIN: exact exploded ACL rows, including out-of-scope anon/authenticated mutation and TRUNCATE posture'),
 ('active_and_ownership_helpers_exact',not exists((select * from helper_state except select * from expected_helper_state) union all (select * from expected_helper_state except select * from helper_state)) and not exists((select * from helper_acl except select * from expected_helper_acl) union all (select * from expected_helper_acl except select * from helper_acl)),'LIVE_PIN: transitive active resolver plus ownership/ban helper overloads, attributes, bodies, settings, results and direct ACLs'),
 ('sole_profile_fallback_index_exact',exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.profiles_one_per_user_key') and i.indrelid=to_regclass('public.profiles') and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)') and not exists(select 1 from pg_constraint where conindid=to_regclass('public.profiles_one_per_user_key')),'LIVE_PIN: exact bare unique index required by sole-profile fallback'),
 ('five_live_rpcs_exact',(select count(*)=5 and bool_and(owner='postgres' and prosecdef and volatility='v' and settings='search_path=pg_catalog, public, auth')
   and count(*) filter(where (proname,body_hash) in(('append_unread_for','6023d0d555a24427a1d98f92d9d37e25'),('remove_unread_for','ca52e0ea7f804024cf6f9f7955dc9a62'),('hide_conversation','4e5756391924dc30ca09f7b535d36afa'),('unhide_conversation','7e7d2ce7d7cef459c1dd9a72a2eb87ab'),('find_and_unhide_conversation','ad6475d6ac60d2fe451597dbe78c2453')))=5 from rpc_state)
   and exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='find_and_unhide_conversation' and p.prosrc like '%caller_profile_count > 1%'),'LIVE_PIN: five real RPC bodies; find RPC retains multi-profile ambiguity guard for MP4-G'),
 ('realtime_replica_identity_exact',(select count(*)=3 and bool_and(c.relreplident='d') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')) and (select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in('conversations','messages','conversation_participant_state')),'LIVE_PIN: publication membership and replica identity unchanged'),
 ('package_d_privacy_intact',not has_column_privilege('anon','public.profiles','user_id','SELECT') and not has_column_privilege('authenticated','public.profiles','user_id','SELECT'),'LIVE_PIN: sibling linkage remains hidden')
),summary as(select bool_and(ok) all_ok,count(*) filter(where ok)::int passed,count(*)::int total,coalesce(array_agg(name||': '||detail order by name collate "C") filter(where not ok),'{}'::text[]) findings from checks)
select 'SLICE_MP4_F_PREFLIGHT' package,case when all_ok then 'GO' else 'STOP' end verdict,passed,total,findings,
 (select md5(coalesce(string_agg(table_name||'|'||polname||'|'||command||'|'||polpermissive||'|'||array_to_string(roles,',')||'|'||using_expr||'|'||check_expr,E'\n' order by table_name collate "C",polname collate "C"),'')) from policy_state) plain_policy_md5,
 (select md5(coalesce(string_agg(table_name||'|'||grantor||'|'||grantee||'|'||privilege_type||'|'||is_grantable,E'\n' order by table_name collate "C",grantor collate "C",grantee collate "C",privilege_type collate "C"),'')) from policy_acl) exploded_table_acl_md5,
 'LIVE_PIN recompute: emitted plain five-policy rows/digest; emitted exact exploded table ACL rows/digest; owners/RLS/FORCE; public/private active resolver plus ownership/ban helper full definitions and direct ACLs; profiles_one_per_user_key exact anatomy; five RPC bodies/ACLs; POST-E nullable/guard objects; publication/replica identity; Package-D profile owner-column privacy.'::text wingman_recompute,
 'SESSION_COVERAGE=UNPROVEN: missing/invalid session_id silently empties messaging reads. REALTIME_WORKER_DELIVERY=UNPROVEN. mp4-policy-conversion-verify.sql is historical and intentionally STOPs post-F. Active-authority policies after F=23 (13+5+5), rollback=18.'::text boundary
from summary;
rollback;
