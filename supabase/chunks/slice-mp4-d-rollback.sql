-- psy.market Slice MP-4-D: Wall post/reaction RPC active authority
-- Policy fingerprints use plain two-argument pg_get_expr(), matching admitted pg_policies evidence.
-- Exact live pins: 2026-08-15 MP4-D bundle plus applied MP4-A/MP4-C after-states.
-- ROLLBACK — OWNER-RUN IN SUPABASE SQL EDITOR.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
lock table public.posts,public.post_reactions,public.post_write_rate_limits in access exclusive mode;
do $transition$
declare source_ok boolean; target_ok boolean;
begin
 if current_user<>'postgres' or session_user<>'postgres' then raise exception 'Slice MP4-D ROLLBACK refused: owner SQL Editor context required' using errcode='42501'; end if;
 with
relation_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||c.relowner::regrole::text||'|'||c.relkind::text||'|'||c.relpersistence::text||'|'||case when c.relrowsecurity then 't' else 'f' end||'|'||case when c.relforcerowsecurity then 't' else 'f' end||'|'||c.relreplident::text,E'\n' order by c.relname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
column_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||a.attnum||'|'||a.attname||'|'||regexp_replace(format_type(a.atttypid,a.atttypmod),'public\.','','g')||'|'||case when a.attnotnull then 't' else 'f' end||'|'||regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'public\.','','g')||'|'||case when a.attcollation=0 then '-' else regexp_replace(a.attcollation::regcollation::text,'public\.','','g') end||'|'||coalesce(nullif(a.attidentity::text,''),'<none>')||'|'||coalesce(nullif(a.attgenerated::text,''),'<none>')||'|'||a.attstorage::text,E'\n' order by c.relname collate "C",a.attnum,a.attname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts') and a.attnum>0 and not a.attisdropped
),
constraint_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||x.conname||'|'||x.contype::text||'|'||regexp_replace(pg_get_constraintdef(x.oid,true),'public\.','','g')||'|'||case when x.convalidated then 't' else 'f' end||'|'||case when x.condeferrable then 't' else 'f' end||'|'||case when x.condeferred then 't' else 'f' end,E'\n' order by c.relname collate "C",x.conname collate "C"),'')) h
 from pg_constraint x join pg_class c on c.oid=x.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
index_state as (
 select count(*)::int n,md5(coalesce(string_agg(t.relname||'|'||i.relname||'|'||regexp_replace(pg_get_indexdef(i.oid),'public\.','','g')||'|'||case when x.indisunique then 't' else 'f' end||'|'||case when x.indisprimary then 't' else 'f' end||'|'||case when x.indisvalid then 't' else 'f' end||'|'||case when x.indisready then 't' else 'f' end,E'\n' order by t.relname collate "C",i.relname collate "C"),'')) h
 from pg_index x join pg_class t on t.oid=x.indrelid join pg_class i on i.oid=x.indexrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and t.relname in ('post_reactions','post_write_rate_limits','posts')
),
trigger_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||t.tgname||'|'||regexp_replace(pg_get_triggerdef(t.oid,true),'public\.','','g')||'|'||t.tgenabled::text,E'\n' order by c.relname collate "C",t.tgname collate "C"),'')) h
 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts') and not t.tgisinternal
),
policy_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.polname||'|'||(case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE' when 'd' then 'DELETE' when '*' then 'ALL' end)||'|'||(case when p.polpermissive then 'PERMISSIVE' else 'RESTRICTIVE' end)||'|'||lower(coalesce((select array_agg(case when x=0 then 'public' else x::regrole::text end order by (case when x=0 then 'public' else x::regrole::text end) collate "C")::text from unnest(p.polroles) x),'{}'))||'|'||(case when p.polqual is null then '<null>' else lower(regexp_replace(regexp_replace(pg_get_expr(p.polqual,p.polrelid),'public\.','','g'),'[[:space:]]+','','g')) end)||'|'||(case when p.polwithcheck is null then '<null>' else lower(regexp_replace(regexp_replace(pg_get_expr(p.polwithcheck,p.polrelid),'public\.','','g'),'[[:space:]]+','','g')) end),E'\n' order by c.relname collate "C",p.polname collate "C"),'')) h
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end||'|'||a.grantor::regrole::text,E'\n' order by c.relname collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C",a.grantor::regrole::text collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
colacl_state as (
 select count(*)::int n from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute att on att.attrelid=c.oid cross join lateral aclexplode(att.attacl) a where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts') and att.attnum>0 and not att.attisdropped
),
publication_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.pubname,E'\n' order by c.relname collate "C",p.pubname collate "C"),'')) h from pg_publication_rel pr join pg_publication p on p.oid=pr.prpubid join pg_class c on c.oid=pr.prrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
wall_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||regexp_replace(pg_get_function_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('admin_block_post_link_domain','admin_delete_notice_post','admin_delete_post','admin_flag_post_for_hero','admin_unblock_post_link_domain','admin_unflag_post_for_hero','clear_hero_on_author_ban','consume_post_write_rate_limit','create_post','current_user_can_read_post','current_user_can_read_post_author','current_user_can_read_post_reaction','delete_own_post','enforce_post_write_invariants','guard_post_reaction_identity','is_valid_post_reaction_code','normalize_post_link_domain','post_body_passes_link_blocklist','post_image_array_has_unique_values','post_images_belong_to_profile','remove_post_reaction','set_post_reaction','update_post')
),
wall_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('admin_block_post_link_domain','admin_delete_notice_post','admin_delete_post','admin_flag_post_for_hero','admin_unblock_post_link_domain','admin_unflag_post_for_hero','clear_hero_on_author_ban','consume_post_write_rate_limit','create_post','current_user_can_read_post','current_user_can_read_post_author','current_user_can_read_post_reaction','delete_own_post','enforce_post_write_invariants','guard_post_reaction_identity','is_valid_post_reaction_code','normalize_post_link_domain','post_body_passes_link_blocklist','post_image_array_has_unique_values','post_images_belong_to_profile','remove_post_reaction','set_post_reaction','update_post')
),
mp4a_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||regexp_replace(pg_get_function_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
mp4a_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
legacy_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||regexp_replace(pg_get_function_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
legacy_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
manifest as (
 select r.n relation_n,r.h relation_h,c.n column_n,c.h column_h,co.n constraint_n,co.h constraint_h,i.n index_n,i.h index_h,t.n trigger_n,t.h trigger_h,p.n policy_n,p.h policy_h,a.n acl_n,a.h acl_h,ca.n colacl_n,pu.n publication_n,pu.h publication_h,wf.n wall_function_n,wf.h wall_function_h,wa.n wall_acl_n,wa.h wall_acl_h,mf.n mp4a_function_n,mf.h mp4a_function_h,ma.n mp4a_acl_n,ma.h mp4a_acl_h,lf.n legacy_function_n,lf.h legacy_function_h,la.n legacy_acl_n,la.h legacy_acl_h from relation_state r cross join column_state c cross join constraint_state co cross join index_state i cross join trigger_state t cross join policy_state p cross join acl_state a cross join colacl_state ca cross join publication_state pu cross join wall_function_state wf cross join wall_acl_state wa cross join mp4a_function_state mf cross join mp4a_acl_state ma cross join legacy_function_state lf cross join legacy_acl_state la
)
 select (m.relation_n=3 and m.relation_h='896fc89a04d20b4a954675e4b6617c7d'
 and m.column_n=18 and m.column_h='7e21ce93ef5410cf8b1deddef17f3dfc'
 and m.constraint_n=15 and m.constraint_h='b0d239ef13d46d549eb86256aafb2635'
 and m.index_n=8 and m.index_h='de0159494a3da73e317dc15ee2d38a4e'
 and m.trigger_n=2 and m.trigger_h='b0e55d8bf75f44aed109a3f69b0d2a4e'
 and m.policy_n=2 and m.policy_h='4ed569e4742a87d96141c344ced1f5d8'
 and m.acl_n=(case when current_setting('server_version_num')::int>=170000 then 30 else 27 end)
 and m.acl_h=(case when current_setting('server_version_num')::int>=170000 then 'cc7fa3fcddd72c7542f85a0fb8fd10ef' else '51d2feec17ddf0a309e74ef4bc6e471b' end)
 and m.colacl_n=0 and m.publication_n=0 and m.publication_h='d41d8cd98f00b204e9800998ecf8427e'
 and m.wall_acl_n=41 and m.wall_acl_h='72c6cd1caebd622429534fb762bd103b'
 and m.mp4a_function_n=4 and m.mp4a_function_h='094e79ae6b137952098334f53f54f695'
 and m.mp4a_acl_n=7 and m.mp4a_acl_h='1a9bc3c64d199fbfe7463dc80a3f7fb1'
 and m.legacy_function_n=4 and m.legacy_function_h='587f39a8031bb763f494e3612df94b73'
 and m.legacy_acl_n=8 and m.legacy_acl_h='6736d5d9cb627a2c79a7d2a84fb8f7d2'
 and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)))
 and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5
 and m.wall_function_n=23 and m.wall_function_h='9ee1c2705f46e6c97892fc241344ebee'),(m.relation_n=3 and m.relation_h='896fc89a04d20b4a954675e4b6617c7d'
 and m.column_n=18 and m.column_h='7e21ce93ef5410cf8b1deddef17f3dfc'
 and m.constraint_n=15 and m.constraint_h='b0d239ef13d46d549eb86256aafb2635'
 and m.index_n=8 and m.index_h='de0159494a3da73e317dc15ee2d38a4e'
 and m.trigger_n=2 and m.trigger_h='b0e55d8bf75f44aed109a3f69b0d2a4e'
 and m.policy_n=2 and m.policy_h='4ed569e4742a87d96141c344ced1f5d8'
 and m.acl_n=(case when current_setting('server_version_num')::int>=170000 then 30 else 27 end)
 and m.acl_h=(case when current_setting('server_version_num')::int>=170000 then 'cc7fa3fcddd72c7542f85a0fb8fd10ef' else '51d2feec17ddf0a309e74ef4bc6e471b' end)
 and m.colacl_n=0 and m.publication_n=0 and m.publication_h='d41d8cd98f00b204e9800998ecf8427e'
 and m.wall_acl_n=41 and m.wall_acl_h='72c6cd1caebd622429534fb762bd103b'
 and m.mp4a_function_n=4 and m.mp4a_function_h='094e79ae6b137952098334f53f54f695'
 and m.mp4a_acl_n=7 and m.mp4a_acl_h='1a9bc3c64d199fbfe7463dc80a3f7fb1'
 and m.legacy_function_n=4 and m.legacy_function_h='587f39a8031bb763f494e3612df94b73'
 and m.legacy_acl_n=8 and m.legacy_acl_h='6736d5d9cb627a2c79a7d2a84fb8f7d2'
 and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)))
 and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5
 and m.wall_function_n=23 and m.wall_function_h='650916cc5006e33fd07e4fe90a568d81') into source_ok,target_ok from manifest m;
 if target_ok then return; end if;
 if not source_ok then raise exception 'Slice MP4-D ROLLBACK refused: exact source/target manifest not found' using errcode='55000'; end if;
 execute $ddl_0$
CREATE OR REPLACE FUNCTION public.create_post(target_profile_id uuid, post_body text, post_images text[] DEFAULT '{}'::text[], include_in_stream boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller_user_id uuid := auth.uid();
  created_post_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot create posts'
      using errcode = '42501';
  end if;

  if not public.current_user_owns_profile(target_profile_id) then
    raise exception 'Post profile is not owned by the caller'
      using errcode = '42501';
  end if;

  if post_body is null
     or pg_catalog.char_length(post_body) not between 1 and 2000
     or pg_catalog.char_length(pg_catalog.btrim(post_body)) = 0 then
    raise exception 'Post body must contain between 1 and 2000 characters'
      using errcode = '22023';
  end if;

  if post_images is null
     or not public.post_images_belong_to_profile(target_profile_id, post_images) then
    raise exception 'Post images are invalid or outside the owner namespace'
      using errcode = '22023';
  end if;

  if not public.post_body_passes_link_blocklist(post_body) then
    raise exception 'Post body contains a blocked link domain'
      using errcode = '22023';
  end if;

  insert into public.posts (
    profile_id,
    body,
    images,
    show_in_stream
  ) values (
    target_profile_id,
    post_body,
    post_images,
    coalesce(include_in_stream, true)
  )
  returning id into created_post_id;

  return created_post_id;
end;
$function$;
$ddl_0$;
 execute $ddl_1$
CREATE OR REPLACE FUNCTION public.delete_own_post(target_post_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller_user_id uuid := auth.uid();
  affected_rows bigint;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot delete posts'
      using errcode = '42501';
  end if;

  delete from public.posts as post
  where post.id = target_post_id
    and public.current_user_owns_profile(post.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;
$function$;
$ddl_1$;
 execute $ddl_2$
CREATE OR REPLACE FUNCTION public.remove_post_reaction(target_post_id uuid, target_profile_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller_user_id uuid := auth.uid();
  affected_rows bigint;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated reaction owner required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot remove reactions'
      using errcode = '42501';
  end if;

  delete from public.post_reactions as reaction
  where reaction.post_id = target_post_id
    and reaction.profile_id = target_profile_id
    and public.current_user_owns_profile(reaction.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Reaction does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;
$function$;
$ddl_2$;
 execute $ddl_3$
CREATE OR REPLACE FUNCTION public.set_post_reaction(target_post_id uuid, target_profile_id uuid, target_reaction_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller_user_id uuid := auth.uid();
  parent_profile_id uuid;
  reaction_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated reaction owner required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot react to posts'
      using errcode = '42501';
  end if;

  if not public.current_user_owns_profile(target_profile_id) then
    raise exception 'Reaction profile is not owned by the caller'
      using errcode = '42501';
  end if;

  if not public.is_valid_post_reaction_code(target_reaction_code) then
    raise exception 'Unsupported post reaction code'
      using errcode = '22023';
  end if;

  select p.profile_id
    into parent_profile_id
  from public.posts as p
  where p.id = target_post_id;

  if parent_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  if public.profile_owner_is_banned(parent_profile_id) then
    raise exception 'Reactions are disabled while the post author is banned'
      using errcode = '42501';
  end if;

  insert into public.post_reactions as reaction (
    post_id,
    profile_id,
    reaction_code
  ) values (
    target_post_id,
    target_profile_id,
    target_reaction_code
  )
  on conflict (post_id, profile_id) do update
  set reaction_code = excluded.reaction_code
  returning reaction.id into reaction_id;

  return reaction_id;
end;
$function$;
$ddl_3$;
 execute $ddl_4$
CREATE OR REPLACE FUNCTION public.update_post(target_post_id uuid, post_body text, post_images text[], include_in_stream boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  caller_user_id uuid := auth.uid();
  author_profile_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot update posts'
      using errcode = '42501';
  end if;

  select p.profile_id
    into author_profile_id
  from public.posts as p
  where p.id = target_post_id
  for update;

  if author_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  if not public.current_user_owns_profile(author_profile_id) then
    raise exception 'Post is not owned by the caller'
      using errcode = '42501';
  end if;

  if post_body is null
     or pg_catalog.char_length(post_body) not between 1 and 2000
     or pg_catalog.char_length(pg_catalog.btrim(post_body)) = 0 then
    raise exception 'Post body must contain between 1 and 2000 characters'
      using errcode = '22023';
  end if;

  if post_images is null
     or not public.post_images_belong_to_profile(author_profile_id, post_images) then
    raise exception 'Post images are invalid or outside the owner namespace'
      using errcode = '22023';
  end if;

  if not public.post_body_passes_link_blocklist(post_body) then
    raise exception 'Post body contains a blocked link domain'
      using errcode = '22023';
  end if;

  if include_in_stream is null then
    raise exception 'Post Stream visibility must be true or false'
      using errcode = '22023';
  end if;

  update public.posts as p
  set body = post_body,
      images = post_images,
      show_in_stream = include_in_stream,
      is_hero_featured = case
        when include_in_stream then p.is_hero_featured
        else false
      end,
      hero_featured_at = case
        when include_in_stream then p.hero_featured_at
        else null
      end,
      hero_featured_by = case
        when include_in_stream then p.hero_featured_by
        else null
      end
  where p.id = target_post_id;
end;
$function$;
$ddl_4$;
end
$transition$;

do $post$
declare ok boolean;
begin
 with
relation_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||c.relowner::regrole::text||'|'||c.relkind::text||'|'||c.relpersistence::text||'|'||case when c.relrowsecurity then 't' else 'f' end||'|'||case when c.relforcerowsecurity then 't' else 'f' end||'|'||c.relreplident::text,E'\n' order by c.relname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
column_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||a.attnum||'|'||a.attname||'|'||regexp_replace(format_type(a.atttypid,a.atttypmod),'public\.','','g')||'|'||case when a.attnotnull then 't' else 'f' end||'|'||regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'public\.','','g')||'|'||case when a.attcollation=0 then '-' else regexp_replace(a.attcollation::regcollation::text,'public\.','','g') end||'|'||coalesce(nullif(a.attidentity::text,''),'<none>')||'|'||coalesce(nullif(a.attgenerated::text,''),'<none>')||'|'||a.attstorage::text,E'\n' order by c.relname collate "C",a.attnum,a.attname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts') and a.attnum>0 and not a.attisdropped
),
constraint_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||x.conname||'|'||x.contype::text||'|'||regexp_replace(pg_get_constraintdef(x.oid,true),'public\.','','g')||'|'||case when x.convalidated then 't' else 'f' end||'|'||case when x.condeferrable then 't' else 'f' end||'|'||case when x.condeferred then 't' else 'f' end,E'\n' order by c.relname collate "C",x.conname collate "C"),'')) h
 from pg_constraint x join pg_class c on c.oid=x.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
index_state as (
 select count(*)::int n,md5(coalesce(string_agg(t.relname||'|'||i.relname||'|'||regexp_replace(pg_get_indexdef(i.oid),'public\.','','g')||'|'||case when x.indisunique then 't' else 'f' end||'|'||case when x.indisprimary then 't' else 'f' end||'|'||case when x.indisvalid then 't' else 'f' end||'|'||case when x.indisready then 't' else 'f' end,E'\n' order by t.relname collate "C",i.relname collate "C"),'')) h
 from pg_index x join pg_class t on t.oid=x.indrelid join pg_class i on i.oid=x.indexrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and t.relname in ('post_reactions','post_write_rate_limits','posts')
),
trigger_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||t.tgname||'|'||regexp_replace(pg_get_triggerdef(t.oid,true),'public\.','','g')||'|'||t.tgenabled::text,E'\n' order by c.relname collate "C",t.tgname collate "C"),'')) h
 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts') and not t.tgisinternal
),
policy_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.polname||'|'||(case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE' when 'd' then 'DELETE' when '*' then 'ALL' end)||'|'||(case when p.polpermissive then 'PERMISSIVE' else 'RESTRICTIVE' end)||'|'||lower(coalesce((select array_agg(case when x=0 then 'public' else x::regrole::text end order by (case when x=0 then 'public' else x::regrole::text end) collate "C")::text from unnest(p.polroles) x),'{}'))||'|'||(case when p.polqual is null then '<null>' else lower(regexp_replace(regexp_replace(pg_get_expr(p.polqual,p.polrelid),'public\.','','g'),'[[:space:]]+','','g')) end)||'|'||(case when p.polwithcheck is null then '<null>' else lower(regexp_replace(regexp_replace(pg_get_expr(p.polwithcheck,p.polrelid),'public\.','','g'),'[[:space:]]+','','g')) end),E'\n' order by c.relname collate "C",p.polname collate "C"),'')) h
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end||'|'||a.grantor::regrole::text,E'\n' order by c.relname collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C",a.grantor::regrole::text collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
colacl_state as (
 select count(*)::int n from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute att on att.attrelid=c.oid cross join lateral aclexplode(att.attacl) a where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts') and att.attnum>0 and not att.attisdropped
),
publication_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.pubname,E'\n' order by c.relname collate "C",p.pubname collate "C"),'')) h from pg_publication_rel pr join pg_publication p on p.oid=pr.prpubid join pg_class c on c.oid=pr.prrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('post_reactions','post_write_rate_limits','posts')
),
wall_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||regexp_replace(pg_get_function_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('admin_block_post_link_domain','admin_delete_notice_post','admin_delete_post','admin_flag_post_for_hero','admin_unblock_post_link_domain','admin_unflag_post_for_hero','clear_hero_on_author_ban','consume_post_write_rate_limit','create_post','current_user_can_read_post','current_user_can_read_post_author','current_user_can_read_post_reaction','delete_own_post','enforce_post_write_invariants','guard_post_reaction_identity','is_valid_post_reaction_code','normalize_post_link_domain','post_body_passes_link_blocklist','post_image_array_has_unique_values','post_images_belong_to_profile','remove_post_reaction','set_post_reaction','update_post')
),
wall_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('admin_block_post_link_domain','admin_delete_notice_post','admin_delete_post','admin_flag_post_for_hero','admin_unblock_post_link_domain','admin_unflag_post_for_hero','clear_hero_on_author_ban','consume_post_write_rate_limit','create_post','current_user_can_read_post','current_user_can_read_post_author','current_user_can_read_post_reaction','delete_own_post','enforce_post_write_invariants','guard_post_reaction_identity','is_valid_post_reaction_code','normalize_post_link_domain','post_body_passes_link_blocklist','post_image_array_has_unique_values','post_images_belong_to_profile','remove_post_reaction','set_post_reaction','update_post')
),
mp4a_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||regexp_replace(pg_get_function_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
mp4a_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
legacy_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||regexp_replace(pg_get_function_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
legacy_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
manifest as (
 select r.n relation_n,r.h relation_h,c.n column_n,c.h column_h,co.n constraint_n,co.h constraint_h,i.n index_n,i.h index_h,t.n trigger_n,t.h trigger_h,p.n policy_n,p.h policy_h,a.n acl_n,a.h acl_h,ca.n colacl_n,pu.n publication_n,pu.h publication_h,wf.n wall_function_n,wf.h wall_function_h,wa.n wall_acl_n,wa.h wall_acl_h,mf.n mp4a_function_n,mf.h mp4a_function_h,ma.n mp4a_acl_n,ma.h mp4a_acl_h,lf.n legacy_function_n,lf.h legacy_function_h,la.n legacy_acl_n,la.h legacy_acl_h from relation_state r cross join column_state c cross join constraint_state co cross join index_state i cross join trigger_state t cross join policy_state p cross join acl_state a cross join colacl_state ca cross join publication_state pu cross join wall_function_state wf cross join wall_acl_state wa cross join mp4a_function_state mf cross join mp4a_acl_state ma cross join legacy_function_state lf cross join legacy_acl_state la
)
 select (m.relation_n=3 and m.relation_h='896fc89a04d20b4a954675e4b6617c7d'
 and m.column_n=18 and m.column_h='7e21ce93ef5410cf8b1deddef17f3dfc'
 and m.constraint_n=15 and m.constraint_h='b0d239ef13d46d549eb86256aafb2635'
 and m.index_n=8 and m.index_h='de0159494a3da73e317dc15ee2d38a4e'
 and m.trigger_n=2 and m.trigger_h='b0e55d8bf75f44aed109a3f69b0d2a4e'
 and m.policy_n=2 and m.policy_h='4ed569e4742a87d96141c344ced1f5d8'
 and m.acl_n=(case when current_setting('server_version_num')::int>=170000 then 30 else 27 end)
 and m.acl_h=(case when current_setting('server_version_num')::int>=170000 then 'cc7fa3fcddd72c7542f85a0fb8fd10ef' else '51d2feec17ddf0a309e74ef4bc6e471b' end)
 and m.colacl_n=0 and m.publication_n=0 and m.publication_h='d41d8cd98f00b204e9800998ecf8427e'
 and m.wall_acl_n=41 and m.wall_acl_h='72c6cd1caebd622429534fb762bd103b'
 and m.mp4a_function_n=4 and m.mp4a_function_h='094e79ae6b137952098334f53f54f695'
 and m.mp4a_acl_n=7 and m.mp4a_acl_h='1a9bc3c64d199fbfe7463dc80a3f7fb1'
 and m.legacy_function_n=4 and m.legacy_function_h='587f39a8031bb763f494e3612df94b73'
 and m.legacy_acl_n=8 and m.legacy_acl_h='6736d5d9cb627a2c79a7d2a84fb8f7d2'
 and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)))
 and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5
 and m.wall_function_n=23 and m.wall_function_h='650916cc5006e33fd07e4fe90a568d81') into ok from manifest m;
 if not ok then raise exception 'Slice MP4-D ROLLBACK postcondition failed' using errcode='55000'; end if;
end
$post$;
commit;
