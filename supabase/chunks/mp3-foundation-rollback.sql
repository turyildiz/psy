-- psy.market Slice MP-3: database cardinality, type, and active-session foundation
-- ROLLBACK — OWNER-RUN IN SUPABASE SQL EDITOR.
--
-- Operational rollback only. PostgreSQL has no supported DROP VALUE. This removes every
-- reversible MP-3 object and restores the exact operational pre-state while retaining the
-- dormant vendor label. Exact enum removal would require replacing the type and rewriting
-- dependent columns/functions, which is outside this approved rollback.

begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
lock table public.profiles in share row exclusive mode;
lock table public.users in share row exclusive mode;

do $guard$
declare
 profile_constraints text; profile_indexes text; profile_triggers text;
 policy_hash text; helper_hash text; signup_hash text;
 mp3_function_hash text; mp3_acl_hash text; private_constraints text; private_indexes text;
 private_rel text; private_schema text; exact_after boolean; exact_restored boolean;
 table_acl_ok boolean; column_acl_ok boolean; helper_acl_ok boolean;
begin
 if current_user<>'postgres' or session_user<>'postgres' then
   raise exception 'MP-3 ROLLBACK refused: owner context required' using errcode='42501';
 end if;
 if (select array_agg(enumlabel::text order by enumsortorder) from pg_enum where enumtypid='public.profile_type'::regtype)
    <>array['personal','artist','label','festival','vendor'] then
   raise exception 'MP-3 ROLLBACK refused: enum drift' using errcode='55000';
 end if;
 with available(p) as (values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE') union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000),
 expected(g,r,p,x) as (select 'postgres'::text,v.r,a.p,false from (values ('postgres'::text),('anon'),('authenticated'),('service_role')) v(r) cross join available a where not(v.r in ('anon','authenticated') and a.p='SELECT') union all select 'postgres','audit_readonly','SELECT',false),
 actual(g,r,p,x) as (select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid='public.profiles'::regclass)
 select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into table_acl_ok;
 with safe(c) as (values ('id'::text),('type'),('handle'),('display_name'),('bio'),('avatar_url'),('header_url'),('location'),('social_links'),('is_creator'),('is_verified'),('created_at')),
 expected(c,g,r,p,x) as (select s.c,'postgres'::text,v.r,'SELECT'::text,false from safe s cross join (values ('anon'::text),('authenticated')) v(r)),
 actual(c,g,r,p,x) as (select z.attname::text,a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_attribute z cross join lateral aclexplode(z.attacl) a where z.attrelid='public.profiles'::regclass and z.attnum>0 and not z.attisdropped and z.attacl is not null)
 select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into column_acl_ok;
 with expected(n,r) as (values ('get_my_profiles'::text,'postgres'::text),('get_my_profiles','authenticated'),('current_user_owns_profile','postgres'),('current_user_owns_profile','authenticated'),('admin_get_profile_account','postgres'),('admin_get_profile_account','authenticated')),
 actual(n,r) as (select p.proname::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account') and a.privilege_type='EXECUTE' and not a.is_grantable and a.grantor='postgres'::regrole)
 select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into helper_acl_ok;
 select md5(coalesce(string_agg(conname||'|'||pg_get_constraintdef(oid,true)||'|'||convalidated||'|'||condeferrable||'|'||condeferred,E'\n' order by conname),'')) into profile_constraints from pg_constraint where conrelid='public.profiles'::regclass;
 select md5(coalesce(string_agg(c.relname||'|'||pg_get_indexdef(c.oid)||'|'||i.indisunique||'|'||i.indisprimary||'|'||i.indisvalid||'|'||i.indisready,E'\n' order by c.relname),'')) into profile_indexes from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid='public.profiles'::regclass;
 select md5(coalesce(string_agg(tgname||'|'||pg_get_triggerdef(oid,true)||'|'||tgenabled::text,E'\n' order by tgname),'')) into profile_triggers from pg_trigger where tgrelid='public.profiles'::regclass and not tgisinternal;
 select md5(coalesce(string_agg(policyname||'|'||cmd||'|'||permissive||'|'||roles::text||'|'||coalesce(qual,'')||'|'||coalesce(with_check,''),E'\n' order by policyname),'')) into policy_hash from pg_policies where schemaname='public' and tablename='profiles';
 select md5(coalesce(string_agg(p.proname||'|'||pg_get_function_identity_arguments(p.oid)||'|'||p.proowner::regrole::text||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||coalesce(p.proconfig::text,'')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by p.proname,pg_get_function_identity_arguments(p.oid)),'')) into helper_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account');
 select md5(p.proowner::regrole::text||'|'||p.prosecdef||'|'||coalesce(p.proconfig::text,'')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))) into signup_hash from pg_proc p where p.oid=to_regprocedure('public.handle_new_user()');
 select md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||pg_get_function_identity_arguments(p.oid)||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||coalesce(p.proconfig::text,'')||'|'||md5(btrim(regexp_replace(p.prosrc,E'\s+',' ','g')))||'|'||pg_get_function_result(p.oid),E'\n' order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)),'')) into mp3_function_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap','get_active_profile','switch_active_profile','create_additional_profile'));
 select md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||pg_get_function_identity_arguments(p.oid)||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)),'')) into mp3_acl_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap','get_active_profile','switch_active_profile','create_additional_profile'));
 select md5(coalesce(string_agg(conname||'|'||pg_get_constraintdef(oid,true)||'|'||convalidated||'|'||condeferrable||'|'||condeferred,E'\n' order by conname),'')) into private_constraints from pg_constraint where conrelid=to_regclass('private.account_session_active_profiles');
 select md5(coalesce(string_agg(c.relname||'|'||pg_get_indexdef(c.oid)||'|'||i.indisunique||'|'||i.indisprimary||'|'||i.indisvalid||'|'||i.indisready,E'\n' order by c.relname),'')) into private_indexes from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('private.account_session_active_profiles');
 select md5(c.relowner::regrole::text||'|'||c.relrowsecurity||'|'||c.relforcerowsecurity||'|'||coalesce(c.relacl::text,'')) into private_rel from pg_class c where c.oid=to_regclass('private.account_session_active_profiles');
 select md5(n.nspowner::regrole::text||'|'||coalesce(n.nspacl::text,'')) into private_schema from pg_namespace n where n.nspname='private';

 exact_after := table_acl_ok and column_acl_ok and helper_acl_ok
   and exists(select 1 from pg_class where oid='public.profiles'::regclass and relowner='postgres'::regrole and relrowsecurity and not relforcerowsecurity)
   and profile_constraints='4881500f6d558e559b5095d6c454e854' and profile_indexes='694204eef68f8094274c642e9123ee94'
   and profile_triggers='56c1252d8625f9a55726e920649de8c3' and policy_hash='b33046c229ea730bcf923ad9f8a114cb'
   and helper_hash='7213a442d3445ac4a461633404ba5555' and signup_hash='d814d105b6725b18b19394a1cb558477'
   and mp3_function_hash='7b61fe89e5500b46404adc499a51b176' and mp3_acl_hash='278f9ec775ed45028d4d817ab12b0eb7'
   and private_constraints='2890dfa115b3b4d990522a2ba9c49701' and private_indexes='ae9b1f423455163225eaaa07886a845e'
   and private_rel='44be9e1e66bb700a28e67c743d387326' and private_schema='f87dd710df4f276338840300b34ad313';
 exact_restored := table_acl_ok and column_acl_ok and helper_acl_ok
   and exists(select 1 from pg_class where oid='public.profiles'::regclass and relowner='postgres'::regrole and relrowsecurity and not relforcerowsecurity)
   and profile_constraints='77ece998656bdd9f2734038e2f9af94c' and profile_indexes='79c9a17b697a7b73f8eb9525b4d9b2eb'
   and profile_triggers='1998fb8f45cd9c01e2899e8872a2e976' and policy_hash='b33046c229ea730bcf923ad9f8a114cb'
   and helper_hash='7213a442d3445ac4a461633404ba5555' and signup_hash='d814d105b6725b18b19394a1cb558477'
   and mp3_function_hash='d41d8cd98f00b204e9800998ecf8427e' and to_regnamespace('private') is null;
 if not exact_after and not exact_restored then
   raise exception 'MP-3 ROLLBACK refused: exact after/restored catalog manifest not found' using errcode='55000';
 end if;
end
$guard$;

-- Every DROP is protected by the exact-after gate above. A rerun from exact restored state
-- is a no-op; IF EXISTS never normalizes an unknown partial state.
drop function if exists public.create_additional_profile(text,text,public.profile_type);
drop function if exists public.switch_active_profile(uuid);
drop function if exists public.get_active_profile();
drop trigger if exists profiles_five_cap on public.profiles;
drop function if exists public.enforce_profile_cap();
drop trigger if exists profiles_owner_immutable on public.profiles;
drop function if exists public.enforce_profile_owner_immutable();
drop table if exists private.account_session_active_profiles;
drop function if exists private.current_auth_session_id();
drop schema if exists private;
alter table public.profiles drop constraint if exists profiles_id_user_id_key;

-- Exact restored postcondition; vendor intentionally remains.
do $post$
declare c text;i text;t text;
begin
 select md5(coalesce(string_agg(conname||'|'||pg_get_constraintdef(oid,true)||'|'||convalidated||'|'||condeferrable||'|'||condeferred,E'\n' order by conname),'')) into c from pg_constraint where conrelid='public.profiles'::regclass;
 select md5(coalesce(string_agg(x.relname||'|'||pg_get_indexdef(x.oid)||'|'||p.indisunique||'|'||p.indisprimary||'|'||p.indisvalid||'|'||p.indisready,E'\n' order by x.relname),'')) into i from pg_index p join pg_class x on x.oid=p.indexrelid where p.indrelid='public.profiles'::regclass;
 select md5(coalesce(string_agg(tgname||'|'||pg_get_triggerdef(oid,true)||'|'||tgenabled::text,E'\n' order by tgname),'')) into t from pg_trigger where tgrelid='public.profiles'::regclass and not tgisinternal;
 if c<>'77ece998656bdd9f2734038e2f9af94c' or i<>'79c9a17b697a7b73f8eb9525b4d9b2eb' or t<>'1998fb8f45cd9c01e2899e8872a2e976' or to_regnamespace('private') is not null then
   raise exception 'MP-3 rollback postcondition failed' using errcode='55000';
 end if;
end
$post$;
commit;
