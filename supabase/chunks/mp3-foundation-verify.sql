-- psy.market Slice MP-3: database cardinality, type, and active-session foundation
-- VERIFY — READ ONLY; OWNER-RUN IN SUPABASE SQL EDITOR.
--
-- No DDL or DML. Transaction-local JWT/role simulations prove fail-closed boundaries and
-- record SQLSTATE. Successful state-writing helper behavior, signup insertion, and the
-- concurrent cap race are validated only in disposable PostgreSQL, never against hosted
-- data. Final output is one GO/STOP row and exposes no identifiers.

begin transaction read only;
set local row_security=on;

-- Caught denial evidence is stored only in transaction-local GUCs.
do $runtime_denials$
declare state_code text;
begin
  if current_user<>'postgres' or session_user<>'postgres' then
    raise exception 'MP-3 VERIFY requires owner SQL Editor context';
  end if;

  perform set_config('mp3.verify.missing_session','unexpected_success',true);
  begin
    perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',
      (select p.user_id from public.profiles p order by p.created_at,p.id limit 1))::text,true);
    set local role authenticated;
    perform * from public.get_active_profile();
    reset role;
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    reset role;
    perform set_config('mp3.verify.missing_session',state_code,true);
  end;

  perform set_config('mp3.verify.malformed_session','unexpected_success',true);
  begin
    perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',
      (select p.user_id from public.profiles p order by p.created_at,p.id limit 1),
      'session_id','not-a-uuid')::text,true);
    set local role authenticated;
    perform * from public.get_active_profile();
    reset role;
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    reset role;
    perform set_config('mp3.verify.malformed_session',state_code,true);
  end;

  perform set_config('mp3.verify.create_authenticated','unexpected_success',true);
  begin
    set local role authenticated;
    perform * from public.create_additional_profile('blocked','Blocked','personal');
    reset role;
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    reset role;
    perform set_config('mp3.verify.create_authenticated',state_code,true);
  end;

  perform set_config('mp3.verify.create_service','unexpected_success',true);
  begin
    set local role service_role;
    perform * from public.create_additional_profile('blocked','Blocked','personal');
    reset role;
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    reset role;
    perform set_config('mp3.verify.create_service',state_code,true);
  end;
end
$runtime_denials$;

with
available(p) as (
 values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE')
 union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000
), expected_table(g,r,p,x) as (
 select 'postgres'::text,v.r,a.p,false from (values ('postgres'::text),('anon'),('authenticated'),('service_role')) v(r)
 cross join available a where not(v.r in ('anon','authenticated') and a.p='SELECT')
 union all select 'postgres','audit_readonly','SELECT',false
), actual_table(g,r,p,x) as (
 select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,
 a.privilege_type::text,a.is_grantable from pg_class c
 cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid='public.profiles'::regclass
), safe(c) as (values ('id'::text),('type'),('handle'),('display_name'),('bio'),('avatar_url'),
 ('header_url'),('location'),('social_links'),('is_creator'),('is_verified'),('created_at')),
expected_column(c,g,r,p,x) as (select s.c,'postgres'::text,v.r,'SELECT'::text,false from safe s
 cross join (values ('anon'::text),('authenticated')) v(r)),
actual_column(c,g,r,p,x) as (select z.attname::text,a.grantor::regrole::text,
 case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable
 from pg_attribute z cross join lateral aclexplode(z.attacl) a where z.attrelid='public.profiles'::regclass
 and z.attnum>0 and not z.attisdropped and z.attacl is not null),
expected_helper_acl(n,r) as (values ('get_my_profiles'::text,'postgres'::text),('get_my_profiles','authenticated'),
 ('current_user_owns_profile','postgres'),('current_user_owns_profile','authenticated'),
 ('admin_get_profile_account','postgres'),('admin_get_profile_account','authenticated')),
actual_helper_acl(n,r) as (select p.proname::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account')
 and a.privilege_type='EXECUTE' and not a.is_grantable and a.grantor='postgres'::regrole),
fingerprints as (
 select
 (select md5(coalesce(string_agg(conname||'|'||pg_get_constraintdef(oid,true)||'|'||convalidated||'|'||condeferrable||'|'||condeferred,E'\n' order by conname),'')) from pg_constraint where conrelid='public.profiles'::regclass) profile_constraints,
 (select md5(coalesce(string_agg(c.relname||'|'||pg_get_indexdef(c.oid)||'|'||i.indisunique||'|'||i.indisprimary||'|'||i.indisvalid||'|'||i.indisready,E'\n' order by c.relname),'')) from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid='public.profiles'::regclass) profile_indexes,
 (select md5(coalesce(string_agg(tgname||'|'||pg_get_triggerdef(oid,true)||'|'||tgenabled::text,E'\n' order by tgname),'')) from pg_trigger where tgrelid='public.profiles'::regclass and not tgisinternal) profile_triggers,
 (select md5(coalesce(string_agg(policyname||'|'||cmd||'|'||permissive||'|'||roles::text||'|'||coalesce(qual,'')||'|'||coalesce(with_check,''),E'\n' order by policyname),'')) from pg_policies where schemaname='public' and tablename='profiles') policy_hash,
 (select md5(coalesce(string_agg(p.proname||'|'||pg_get_function_identity_arguments(p.oid)||'|'||p.proowner::regrole::text||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||coalesce(p.proconfig::text,'')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by p.proname,pg_get_function_identity_arguments(p.oid)),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account')) helper_hash,
 (select md5(p.proowner::regrole::text||'|'||p.prosecdef||'|'||coalesce(p.proconfig::text,'')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))) from pg_proc p where p.oid=to_regprocedure('public.handle_new_user()')) signup_hash,
 (select md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||pg_get_function_identity_arguments(p.oid)||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||coalesce(p.proconfig::text,'')||'|'||md5(btrim(regexp_replace(p.prosrc,E'\s+',' ','g')))||'|'||pg_get_function_result(p.oid),E'\n' order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap','get_active_profile','switch_active_profile','create_additional_profile'))) mp3_function_hash,
 (select md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||pg_get_function_identity_arguments(p.oid)||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)),'')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap','get_active_profile','switch_active_profile','create_additional_profile'))) mp3_acl_hash,
 (select md5(coalesce(string_agg(conname||'|'||pg_get_constraintdef(oid,true)||'|'||convalidated||'|'||condeferrable||'|'||condeferred,E'\n' order by conname),'')) from pg_constraint where conrelid=to_regclass('private.account_session_active_profiles')) private_constraints,
 (select md5(coalesce(string_agg(c.relname||'|'||pg_get_indexdef(c.oid)||'|'||i.indisunique||'|'||i.indisprimary||'|'||i.indisvalid||'|'||i.indisready,E'\n' order by c.relname),'')) from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('private.account_session_active_profiles')) private_indexes,
 (select md5(c.relowner::regrole::text||'|'||c.relrowsecurity||'|'||c.relforcerowsecurity||'|'||coalesce(c.relacl::text,'')) from pg_class c where c.oid=to_regclass('private.account_session_active_profiles')) private_rel,
 (select md5(n.nspowner::regrole::text||'|'||coalesce(n.nspacl::text,'')) from pg_namespace n where n.nspname='private') private_schema
), checks(name,ok,sqlstate,detail) as (
 select * from (values
 ('owner_context',current_user='postgres' and session_user='postgres',null::text,'owner context'),
 ('enum_exact',(select array_agg(enumlabel::text order by enumsortorder)=array['personal','artist','label','festival','vendor'] from pg_enum where enumtypid='public.profile_type'::regtype),null,'vendor appended exactly'),
 ('profiles_relation_exact',exists(select 1 from pg_class where oid='public.profiles'::regclass and relowner='postgres'::regrole and relrowsecurity and not relforcerowsecurity),null,'owner/RLS'),
 ('profiles_constraints_exact',(select profile_constraints='4881500f6d558e559b5095d6c454e854' from fingerprints),null,'complete constraint manifest'),
 ('profiles_indexes_exact',(select profile_indexes='694204eef68f8094274c642e9123ee94' from fingerprints),null,'complete index manifest'),
 ('profiles_triggers_exact',(select profile_triggers='56c1252d8625f9a55726e920649de8c3' from fingerprints),null,'complete trigger manifest'),
 ('profiles_policies_exact',(select policy_hash='b33046c229ea730bcf923ad9f8a114cb' from fingerprints),null,'unchanged policies'),
 ('package_d_table_acl_exact',not exists((select * from actual_table except select * from expected_table) union all (select * from expected_table except select * from actual_table)),null,'complete table ACL'),
 ('package_d_column_acl_exact',not exists((select * from actual_column except select * from expected_column) union all (select * from expected_column except select * from actual_column)),null,'12-column ACL'),
 ('package_b_helpers_exact',(select helper_hash='7213a442d3445ac4a461633404ba5555' from fingerprints),null,'helper definitions'),
 ('package_b_helper_acl_exact',not exists((select * from actual_helper_acl except select * from expected_helper_acl) union all (select * from expected_helper_acl except select * from actual_helper_acl)),null,'helper ACL'),
 ('signup_exact',(select signup_hash='d814d105b6725b18b19394a1cb558477' from fingerprints),null,'signup definition'),
 ('mp3_functions_exact',(select mp3_function_hash='7b61fe89e5500b46404adc499a51b176' and mp3_acl_hash='278f9ec775ed45028d4d817ab12b0eb7' from fingerprints),null,'function definitions/ACL/overloads'),
 ('private_state_exact',(select private_constraints='2890dfa115b3b4d990522a2ba9c49701' and private_indexes='ae9b1f423455163225eaaa07886a845e' and private_rel='44be9e1e66bb700a28e67c743d387326' and private_schema='f87dd710df4f276338840300b34ad313' from fingerprints),null,'private schema/table'),
 ('one_profile_guard',exists(select 1 from pg_index where indexrelid='public.profiles_one_per_user_key'::regclass and indisunique and indisvalid and indisready),null,'still in force'),
 ('missing_session_denied',current_setting('mp3.verify.missing_session',true)='42501',current_setting('mp3.verify.missing_session',true),'fail closed'),
 ('malformed_session_denied',current_setting('mp3.verify.malformed_session',true)='42501',current_setting('mp3.verify.malformed_session',true),'fail closed'),
 ('creation_authenticated_denied',current_setting('mp3.verify.create_authenticated',true)='42501',current_setting('mp3.verify.create_authenticated',true),'ACL denial'),
 ('creation_service_denied',current_setting('mp3.verify.create_service',true)='42501',current_setting('mp3.verify.create_service',true),'ACL denial')
 ) v(name,ok,sqlstate,detail)
), summary as (select bool_and(ok) all_ok,count(*) filter(where ok)::int passed,count(*)::int total,
 coalesce(array_agg(name||coalesce(' ['||sqlstate||']','')||': '||detail order by name) filter(where not ok),'{}'::text[]) findings from checks)
select 'MP3_FOUNDATION_VERIFY'::text package,case when all_ok then 'GO' else 'STOP' end verdict,passed,total,findings from summary;
rollback;
