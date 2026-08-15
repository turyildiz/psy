-- psy.market Slice MP-4-B: profile/listing active authorization
-- VERIFY — READ ONLY; OWNER-RUN IN SUPABASE SQL EDITOR.
-- Hosted-safe catalog proof; synthetic behavior and write SQLSTATEs are disposable-only.

begin transaction read only;
set local row_security=on;

with

relation_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||c.relowner::regrole::text||'|'||c.relkind::text||'|'||c.relpersistence::text||'|'||case when c.relrowsecurity then 't' else 'f' end||'|'||case when c.relforcerowsecurity then 't' else 'f' end||'|'||c.relreplident::text,E'\n' order by c.relname),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('profiles','listings')
),
profile_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg((case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end||'|'||a.grantor::regrole::text,E'\n' order by (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C",a.grantor),'')) h
 from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid=to_regclass('public.profiles')
),
listing_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg((case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end||'|'||a.grantor::regrole::text,E'\n' order by (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C",a.grantor),'')) h
 from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid=to_regclass('public.listings')
),
profile_colacl_state as (
 select count(*)::int n,md5(coalesce(string_agg(att.attname||'|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by att.attname collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C",a.grantor),'')) h
 from pg_attribute att cross join lateral aclexplode(att.attacl) a where att.attrelid=to_regclass('public.profiles') and att.attnum>0 and not att.attisdropped
),
listing_colacl_state as (
 select count(*)::int n from pg_attribute att cross join lateral aclexplode(att.attacl) a where att.attrelid=to_regclass('public.listings') and att.attnum>0 and not att.attisdropped
),
default_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(d.defaclrole::regrole::text||'|'||coalesce(n.nspname,'<global>')||'|'||d.defaclobjtype::text||'|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by d.defaclrole::regrole::text collate "C",coalesce(n.nspname,'<global>') collate "C",d.defaclobjtype::text collate "C",a.grantor,(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h
 from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace cross join lateral aclexplode(d.defaclacl) a
),
policy_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.polname||'|'||(case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE' when 'd' then 'DELETE' when '*' then 'ALL' end)||'|'||(case when p.polpermissive then 'PERMISSIVE' else 'RESTRICTIVE' end)||'|'||lower(coalesce((select array_agg(case when x=0 then 'public' else x::regrole::text end order by case when x=0 then 'public' else x::regrole::text end)::text from unnest(p.polroles) x),'{}'))||'|'||(case when p.polqual is null then '<null>' else lower(regexp_replace(regexp_replace(regexp_replace(pg_get_expr(p.polqual,p.polrelid,true),'(public|profiles|listings)\.','','g'),'[[:space:]]+','','g'),'as(current_active_profile_id|current_user_is_banned|current_user_is_active_unsuspended_profile)','','g')) end)||'|'||(case when p.polwithcheck is null then '<null>' else lower(regexp_replace(regexp_replace(regexp_replace(pg_get_expr(p.polwithcheck,p.polrelid,true),'(public|profiles|listings)\.','','g'),'[[:space:]]+','','g'),'as(current_active_profile_id|current_user_is_banned|current_user_is_active_unsuspended_profile)','','g')) end),E'\n' order by c.relname,p.polname),'')) h
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('profiles','listings')
),
guard_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),'')) h
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('enforce_profile_cap','enforce_profile_handle','enforce_profile_owner_immutable','handle_new_user','update_updated_at')
),
guard_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor,(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('enforce_profile_cap','enforce_profile_handle','enforce_profile_owner_immutable','handle_new_user','update_updated_at')
),
moderation_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),'')) h
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('current_user_is_admin','enforce_listing_moderation_state')
),
moderation_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor,(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('current_user_is_admin','enforce_listing_moderation_state')
),
profile_trigger_state as (
 select count(*)::int n,md5(coalesce(string_agg(t.tgname||'|'||t.tgenabled::text||'|'||regexp_replace(pg_get_triggerdef(t.oid,true),'public\.','','g'),E'\n' order by t.tgname),'')) h from pg_trigger t where t.tgrelid=to_regclass('public.profiles') and not t.tgisinternal
),
membership_state as (
 select count(*)::int n,md5(coalesce(string_agg(member.rolname||'|'||granted.rolname||'|'||case when m.admin_option then 't' else 'f' end||'|'||case when m.inherit_option then 't' else 'f' end||'|'||case when m.set_option then 't' else 'f' end||'|'||grantor.rolname,E'\n' order by member.rolname,granted.rolname),'')) h
 from pg_auth_members m join pg_roles member on member.oid=m.member join pg_roles granted on granted.oid=m.roleid join pg_roles grantor on grantor.oid=m.grantor where member.rolname in ('anon','authenticated','service_role','authenticator','postgres')
),
listing_column_state as (
 select count(*)::int n,md5(coalesce(string_agg(a.attnum||'|'||a.attname||'|'||regexp_replace(format_type(a.atttypid,a.atttypmod),'public\.','','g')||'|'||case when a.attnotnull then 't' else 'f' end||'|'||regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'public\.','','g'),E'\n' order by a.attnum),'')) h from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=to_regclass('public.listings') and a.attnum>0 and not a.attisdropped
),
listing_constraint_state as (
 select count(*)::int n,md5(coalesce(string_agg(conname||'|'||contype::text||'|'||regexp_replace(pg_get_constraintdef(oid,true),'public\.','','g')||'|'||case when convalidated then 't' else 'f' end||'|'||case when condeferrable then 't' else 'f' end||'|'||case when condeferred then 't' else 'f' end,E'\n' order by conname),'')) h from pg_constraint where conrelid=to_regclass('public.listings')
),
listing_index_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||pg_get_indexdef(c.oid)||'|'||case when i.indisunique then 't' else 'f' end||'|'||case when i.indisprimary then 't' else 'f' end||'|'||case when i.indisvalid then 't' else 'f' end||'|'||case when i.indisready then 't' else 'f' end,E'\n' order by c.relname),'')) h from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('public.listings')
),
listing_trigger_state as (
 select count(*)::int n,md5(coalesce(string_agg(t.tgname||'|'||regexp_replace(pg_get_triggerdef(t.oid,true),'public\.','','g')||'|'||t.tgenabled::text,E'\n' order by t.tgname),'')) h from pg_trigger t where t.tgrelid=to_regclass('public.listings') and not t.tgisinternal
),
mp4a_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
mp4a_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor,(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
legacy_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
legacy_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor,(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
manifest as (
 select r.n relation_n,r.h relation_h,pa.n profile_acl_n,pa.h profile_acl_h,la.n listing_acl_n,la.h listing_acl_h,pc.n profile_colacl_n,pc.h profile_colacl_h,lc.n listing_colacl_n,da.n default_acl_n,da.h default_acl_h,po.n policy_n,po.h policy_h,gf.n guard_function_n,gf.h guard_function_h,ga.n guard_acl_n,ga.h guard_acl_h,mf2.n moderation_function_n,mf2.h moderation_function_h,mac.n moderation_acl_n,mac.h moderation_acl_h,pt.n profile_trigger_n,pt.h profile_trigger_h,ms.n membership_n,ms.h membership_h,lcol.n listing_column_n,lcol.h listing_column_h,lcon.n listing_constraint_n,lcon.h listing_constraint_h,li.n listing_index_n,li.h listing_index_h,lt.n listing_trigger_n,lt.h listing_trigger_h,mf.n mp4a_function_n,mf.h mp4a_function_h,ma.n mp4a_acl_n,ma.h mp4a_acl_h,lf.n legacy_function_n,lf.h legacy_function_h,lla.n legacy_acl_n,lla.h legacy_acl_h
 from relation_state r cross join profile_acl_state pa cross join listing_acl_state la cross join profile_colacl_state pc cross join listing_colacl_state lc cross join default_acl_state da cross join policy_state po cross join guard_function_state gf cross join guard_acl_state ga cross join moderation_function_state mf2 cross join moderation_acl_state mac cross join profile_trigger_state pt cross join membership_state ms cross join listing_column_state lcol cross join listing_constraint_state lcon cross join listing_index_state li cross join listing_trigger_state lt cross join mp4a_function_state mf cross join mp4a_acl_state ma cross join legacy_function_state lf cross join legacy_acl_state lla
)
,
checks(name,ok,detail) as (
 select v.* from manifest m cross join lateral (values
 ('owner_context',current_user='postgres' and session_user='postgres','owner SQL Editor context required'),
 ('dependency_manifest_exact',(m.relation_n=2 and m.relation_h='f1fe7c4aeb160fea5044ab172d5a863d'
 and m.listing_acl_n=(case when current_setting('server_version_num')::int>=170000 then 33 else 29 end)
 and m.listing_acl_h=(case when current_setting('server_version_num')::int>=170000 then '9999dff08df8d6692a1f77fa6475dd58' else '6ec0e2d64c5630ec271f4ca9dc26c7b0' end)
 and m.profile_colacl_n=24 and m.profile_colacl_h='c30def816773ab9c1a81dbeecfc1f53d' and m.listing_colacl_n=0
 and m.default_acl_n=(case when current_setting('server_version_num')::int>=170000 then 312 else 286 end)
 and m.default_acl_h=(case when current_setting('server_version_num')::int>=170000 then '23cf4be7e586d9052207de14212d2ce4' else 'ce181bd0f3d808550e9730bae42492f0' end)
 and m.guard_function_n=5 and m.guard_function_h='4500723599d5b96718f29f71fbd68a43'
 and m.guard_acl_n=11 and m.guard_acl_h='0534a9949aa140ca4f6e7bf695e504e3'
 and m.moderation_function_n=2 and m.moderation_function_h='91e82a53a892af9b72a094ff360684cc'
 and m.moderation_acl_n=5 and m.moderation_acl_h='fdb533459b6d2c727be4d57a5bc1b692'
 and m.profile_trigger_n=4 and m.profile_trigger_h='e4cc298423807e0cda462b59f4d5bf38'
 and m.membership_n=13 and m.membership_h='2c5626f6dd72493cd1f6b18bd20a6036'
 and m.listing_column_n=21 and m.listing_column_h='ddbdc8849887bf9ce4c084292649a01f'
 and m.listing_constraint_n=11 and m.listing_constraint_h='4dd8169744900c114fc47cce5b3b66f3'
 and m.listing_index_n=9 and m.listing_index_h='fbb0dc03ee0370f09c3882d10165e8c6'
 and m.listing_trigger_n=3 and m.listing_trigger_h='2b166e209b20f2b2b1f7533aa805c499'
 and m.mp4a_function_n=4 and m.mp4a_function_h='165eb4bc928f79c5ba10124209af4db4'
 and m.mp4a_acl_n=7 and m.mp4a_acl_h='1a9bc3c64d199fbfe7463dc80a3f7fb1'
 and m.legacy_function_n=4 and m.legacy_function_h='0259776e2bcc6a144ac3bf3787245497'
 and m.legacy_acl_n=8 and m.legacy_acl_h='6736d5d9cb627a2c79a7d2a84fb8f7d2'
 and exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.profiles_one_per_user_key') and i.indrelid=to_regclass('public.profiles') and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)')
 and not exists(select 1 from pg_constraint where conindid=to_regclass('public.profiles_one_per_user_key'))
 and exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.idx_profiles_user_id') and i.indrelid=to_regclass('public.profiles') and not i.indisunique and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE INDEX idx_profiles_user_id ON public.profiles USING btree (user_id)')
 and exists(select 1 from pg_constraint where conrelid=to_regclass('public.profiles') and conname='profiles_user_id_fkey' and contype='f' and convalidated and not condeferrable and not condeferred and regexp_replace(pg_get_constraintdef(oid,true),'public\.','','g')='FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE')
 and exists(select 1 from pg_trigger t where t.tgrelid=to_regclass('auth.users') and t.tgname='on_auth_user_created' and t.tgenabled::text='O' and regexp_replace(pg_get_triggerdef(t.oid,true),'public\.','','g')='CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user()')
 and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)))
 and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5
 and not has_function_privilege('anon','public.create_additional_profile(text,text,public.profile_type)','EXECUTE')
 and not has_function_privilege('authenticated','public.create_additional_profile(text,text,public.profile_type)','EXECUTE')
 and not has_function_privilege('service_role','public.create_additional_profile(text,text,public.profile_type)','EXECUTE')),'unchanged dependency drift'),
 ('after_policy_acl_exact',(m.policy_n=7 and m.policy_h=(case when current_setting('server_version_num')::int>=170000 then 'c06d36ed0330e2dcac1df91962cb4c55' else '244e88fef8081408484743848dc6ef3a' end)
 and m.profile_acl_n=(case when current_setting('server_version_num')::int>=170000 then 30 else 26 end)
 and m.profile_acl_h=(case when current_setting('server_version_num')::int>=170000 then '29e23694b3fc1e0f9e48ba0a00c7925d' else 'eed8b709d0bf2766aa213cd75afc8e27' end)
 and not has_table_privilege('authenticated','public.profiles','INSERT')
 and not exists(select 1 from pg_attribute a where a.attrelid=to_regclass('public.profiles') and a.attnum>0 and not a.attisdropped and has_column_privilege('authenticated','public.profiles',a.attname,'INSERT'))),'authored policy/profile ACL/effective INSERT drift'),
 ('public_listing_policy_unchanged',exists(select 1 from pg_policy where polrelid=to_regclass('public.listings') and polname='Active and sold listings are publicly readable' and polcmd='r'),'public read policy missing'),
 ('signup_and_creation_paths_closed',to_regprocedure('public.handle_new_user()') is not null and to_regprocedure('public.create_additional_profile(text,text,public.profile_type)') is not null and not has_function_privilege('authenticated','public.create_additional_profile(text,text,public.profile_type)','EXECUTE'),'signup/additional-profile contract drift')
 ) v(name,ok,detail)
), summary as (select bool_and(ok) all_ok,count(*) filter(where ok)::int passed,count(*)::int total,coalesce(array_agg(name||': '||detail order by name) filter(where not ok),'{}'::text[]) findings from checks)
select 'SLICE_MP4_B_VERIFY' package,case when all_ok then 'GO' else 'STOP' end verdict,passed,total,findings,'auth.users.on_auth_user_created is the authorized MP-3 owner pin and is reverified owner-side here; all other exact pins come from the 2026-08-15 MP4-B bundle, supplement, S9 moderation-chain evidence, or the prior applied MP4-A package. Full sibling/write/signup/index-removal/compatibility/InitPlan evidence is required from the final-byte disposable harness before owner application.'::text boundary from summary;
rollback;
