-- psy.market Slice MP-4-A: read-only active-authority primitives
-- VERIFY — READ ONLY; OWNER-RUN IN SUPABASE SQL EDITOR.
-- Hosted-safe proof is catalog/ACL plus fail-closed calls that perform no writes.
-- Full success matrix, two-session independence, lock/write proof, and EXPLAIN evidence
-- run only on disposable PostgreSQL because they require synthetic state fixtures.

begin transaction read only;
set local row_security=on;

do $runtime$
declare before_count bigint; after_count bigint; state_code text;
begin
  if current_user<>'postgres' or session_user<>'postgres' then
    raise exception 'Slice MP4-A VERIFY requires owner SQL Editor context' using errcode='42501';
  end if;
  select count(*) into before_count from private.account_session_active_profiles;

  perform set_config('request.jwt.claims','{}',true);
  if public.current_active_profile_id() is not null or public.current_user_is_active_profile(null) or public.current_user_is_active_unsuspended_profile(null) then
    raise exception 'anonymous fail-closed probe failed';
  end if;

  perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub','00000000-0000-0000-0000-000000000001')::text,true);
  set local role authenticated;
  if public.current_active_profile_id() is not null or public.current_user_is_active_profile('00000000-0000-0000-0000-000000000001') or public.current_user_is_active_unsuspended_profile('00000000-0000-0000-0000-000000000001') then
    raise exception 'missing-session fail-closed probe failed';
  end if;
  reset role;

  perform set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub','00000000-0000-0000-0000-000000000001','session_id','malformed')::text,true);
  set local role authenticated;
  if public.current_active_profile_id() is not null or public.current_user_is_active_profile('00000000-0000-0000-0000-000000000001') or public.current_user_is_active_unsuspended_profile('00000000-0000-0000-0000-000000000001') then
    raise exception 'malformed-session fail-closed probe failed';
  end if;
  reset role;

  perform set_config('mp4a.verify.private_anon','unexpected_success',true);
  begin
    set local role anon;
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    reset role;
    raise exception 'Slice MP4-A VERIFY could not assume anon; private denial unproven (SQLSTATE %)',state_code using errcode='55000';
  end;
  begin
    execute 'select private.current_active_profile_id()';
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    perform set_config('mp4a.verify.private_anon',state_code,true);
  end;
  reset role;

  perform set_config('mp4a.verify.private_authenticated','unexpected_success',true);
  begin
    set local role authenticated;
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    reset role;
    raise exception 'Slice MP4-A VERIFY could not assume authenticated; private denial unproven (SQLSTATE %)',state_code using errcode='55000';
  end;
  begin
    execute 'select private.current_active_profile_id()';
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    perform set_config('mp4a.verify.private_authenticated',state_code,true);
  end;
  reset role;

  perform set_config('mp4a.verify.private_service','unexpected_success',true);
  begin
    set local role service_role;
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    reset role;
    raise exception 'Slice MP4-A VERIFY could not assume service_role; private denial unproven (SQLSTATE %)',state_code using errcode='55000';
  end;
  begin
    execute 'select private.current_active_profile_id()';
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
    perform set_config('mp4a.verify.private_service',state_code,true);
  end;
  reset role;

  select count(*) into after_count from private.account_session_active_profiles;
  if after_count<>before_count then raise exception 'read-only helper changed session state'; end if;
end
$runtime$;

with
expected_state_columns(ord,name,type_name,not_null,default_expr) as (
 values (1,'session_id'::text,'uuid'::text,true,''::text),(2,'user_id','uuid',true,''),(3,'profile_id','uuid',true,''),(4,'created_at','timestamp with time zone',true,'now()'),(5,'updated_at','timestamp with time zone',true,'now()')
), actual_state_columns as (
 select a.attnum::int,a.attname::text,pg_catalog.format_type(a.atttypid,a.atttypmod),a.attnotnull,regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'(public|private)\.','','g')
 from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=to_regclass('private.account_session_active_profiles') and a.attnum>0 and not a.attisdropped
), expected_state_constraints(name,type_code,definition,is_validated,is_deferrable,is_deferred) as (
 values ('account_session_active_profiles_pkey'::text,'p'::text,'PRIMARY KEY (session_id)'::text,true,false,false),('account_session_active_profiles_profile_owner_fkey','f','FOREIGN KEY (profile_id, user_id) REFERENCES profiles(id, user_id) ON DELETE CASCADE',true,false,false),('account_session_active_profiles_user_id_fkey','f','FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE',true,false,false)
), actual_state_constraints as (
 select conname::text,contype::text,regexp_replace(pg_get_constraintdef(oid,true),'(public|private)\.','','g'),convalidated,condeferrable,condeferred from pg_constraint where conrelid=to_regclass('private.account_session_active_profiles')
), expected_state_indexes(name,definition,is_unique,is_primary,is_valid,is_ready) as (
 values ('account_session_active_profiles_pkey'::text,'CREATE UNIQUE INDEX account_session_active_profiles_pkey ON private.account_session_active_profiles USING btree (session_id)'::text,true,true,true,true),('account_session_active_profiles_profile_id_idx','CREATE INDEX account_session_active_profiles_profile_id_idx ON private.account_session_active_profiles USING btree (profile_id)',false,false,true,true),('account_session_active_profiles_user_id_idx','CREATE INDEX account_session_active_profiles_user_id_idx ON private.account_session_active_profiles USING btree (user_id)',false,false,true,true)
), actual_state_indexes as (
 select c.relname::text,pg_get_indexdef(c.oid),i.indisunique,i.indisprimary,i.indisvalid,i.indisready from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('private.account_session_active_profiles')
), available_state_privilege(privilege_type) as (
 values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE') union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000
), expected_state_acl(grantor,grantee,privilege_type,is_grantable) as (
 select 'postgres'::text,'postgres'::text,privilege_type,false from available_state_privilege
), actual_state_acl as (
 select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid=to_regclass('private.account_session_active_profiles')
), expected_private_schema_acl(grantor,grantee,privilege_type,is_grantable) as (
 values ('postgres'::text,'postgres'::text,'CREATE'::text,false),('postgres','postgres','USAGE',false)
), actual_private_schema_acl as (
 select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_namespace n cross join lateral aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a where n.nspname='private'
), expected_profile_triggers(name,definition,enabled) as (
 values ('profiles_enforce_handle'::text,'CREATE TRIGGER profiles_enforce_handle BEFORE INSERT OR UPDATE OF handle ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_handle()'::text,'O'::text),('profiles_five_cap','CREATE TRIGGER profiles_five_cap BEFORE INSERT ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_cap()','O'),('profiles_owner_immutable','CREATE TRIGGER profiles_owner_immutable BEFORE UPDATE OF user_id ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_owner_immutable()','O'),('tr_profiles_updated_at','CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()','O')
), actual_profile_triggers as (
 select tgname::text,regexp_replace(pg_get_triggerdef(oid,true),'public\.','','g'),tgenabled::text from pg_trigger where tgrelid=to_regclass('public.profiles') and not tgisinternal
), expected_profile_guard_functions(name,args,language_name,volatility,security_definer,is_strict,is_leakproof,parallel_mode,default_count,config,result_type,body_md5) as (
 values ('enforce_profile_owner_immutable'::text,''::text,'plpgsql'::text,'v'::text,true,false,false,'u'::text,0,'search_path=<empty>'::text,'trigger'::text,'f593015ac29445f3dba408c2d6847535'::text),('enforce_profile_cap','','plpgsql','v',true,false,false,'u',0,'search_path=<empty>','trigger','5fbdaad00844b2c7181946addd7dce58')
), actual_profile_guard_functions as (
 select p.proname::text,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),l.lanname::text,p.provolatile::text,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text,p.pronargdefaults,coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),''),regexp_replace(pg_get_function_result(p.oid),'public\.','','g'),md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap')
), expected_functions(schema_name,name,args,owner_name,language_name,volatility,security_definer,is_strict,is_leakproof,parallel_mode,default_count,config,result_type,body_md5) as (
 values
 ('private'::text,'current_active_profile_id'::text,''::text,'postgres'::text,'plpgsql'::text,'s'::text,true,false,false,'u'::text,0,'search_path=<empty>'::text,'uuid'::text,'8ab19811ddcf117a757e7663efc5ac77'::text),
 ('public','current_active_profile_id','','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','uuid','6f6b53dbd223db8ba168073c196f7b1a'),
 ('public','current_user_is_active_profile','target_profile_id uuid','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','boolean','63cc27212d60aa55cc7536c3c26310c1'),
 ('public','current_user_is_active_unsuspended_profile','target_profile_id uuid','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','boolean','a31ffdeee866090a0d7cd1c859a9ec23')
), actual_functions as (
 select n.nspname::text,p.proname::text,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),p.proowner::regrole::text,l.lanname::text,p.provolatile::text,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text,p.pronargdefaults,
 coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),''),pg_get_function_result(p.oid),md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
), expected_acl(object_name,grantee,privilege_type,is_grantable,grantor) as (
 values
 ('private.current_active_profile_id()'::text,'postgres'::text,'EXECUTE'::text,false,'postgres'::text),
 ('public.current_active_profile_id()','authenticated','EXECUTE',false,'postgres'),('public.current_active_profile_id()','postgres','EXECUTE',false,'postgres'),
 ('public.current_user_is_active_profile(target_profile_id uuid)','authenticated','EXECUTE',false,'postgres'),('public.current_user_is_active_profile(target_profile_id uuid)','postgres','EXECUTE',false,'postgres'),
 ('public.current_user_is_active_unsuspended_profile(target_profile_id uuid)','authenticated','EXECUTE',false,'postgres'),('public.current_user_is_active_unsuspended_profile(target_profile_id uuid)','postgres','EXECUTE',false,'postgres')
), actual_acl as (
 select n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')',case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable,a.grantor::regrole::text
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
), checks(name,ok,detail) as (
 values
 ('functions_exact',not exists((select * from actual_functions except select * from expected_functions) union all (select * from expected_functions except select * from actual_functions)),'definitions/attributes/overloads'),
 ('acls_exact',not exists((select * from actual_acl except select * from expected_acl) union all (select * from expected_acl except select * from actual_acl)),'authenticated and owner only'),
 ('private_state_exact',exists(select 1 from pg_class where oid=to_regclass('private.account_session_active_profiles') and relowner='postgres'::regrole and relkind='r' and relpersistence='p' and relrowsecurity and relforcerowsecurity and relreplident='d') and not exists((select * from actual_state_columns except select * from expected_state_columns) union all (select * from expected_state_columns except select * from actual_state_columns)) and not exists((select * from actual_state_constraints except select * from expected_state_constraints) union all (select * from expected_state_constraints except select * from actual_state_constraints)) and not exists((select * from actual_state_indexes except select * from expected_state_indexes) union all (select * from expected_state_indexes except select * from actual_state_indexes)) and not exists((select * from actual_state_acl except select * from expected_state_acl) union all (select * from expected_state_acl except select * from actual_state_acl)) and exists(select 1 from pg_namespace where nspname='private' and nspowner='postgres'::regrole) and not exists((select * from actual_private_schema_acl except select * from expected_private_schema_acl) union all (select * from expected_private_schema_acl except select * from actual_private_schema_acl)) and not exists(select 1 from pg_policy where polrelid=to_regclass('private.account_session_active_profiles')) and not exists(select 1 from pg_publication_rel where prrelid=to_regclass('private.account_session_active_profiles')),'private session relation/ACL/schema drift'),
 ('mp3_dependencies_exact',
   (select count(*)=7 and md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||p.proisstrict||'|'||p.proleakproof||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),''))='e508fa48daa3f8b44237db8e649e553d' from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile')))
   and (select count(*)=13 and md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end),''))='ebdbcf02bd5c1f94e3daa384bdec210a' from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile'))),
   'MP-3 helper definition/attribute/result/ACL drift'),
 ('one_profile_fallback_guard',exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.profiles_one_per_user_key') and i.indrelid=to_regclass('public.profiles') and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)') and not exists(select 1 from pg_constraint where conindid=to_regclass('public.profiles_one_per_user_key')),'exact bare unique index'),
 ('supporting_indexes',exists(select 1 from pg_index where indexrelid=to_regclass('private.account_session_active_profiles_pkey') and indisunique and indisprimary and indisvalid and indisready) and exists(select 1 from pg_index where indexrelid=to_regclass('public.idx_profiles_user_id') and not indisunique and indisvalid and indisready),'session PK and owner lookup index'),
 ('profile_dependencies_exact',exists(select 1 from pg_constraint where conrelid=to_regclass('public.profiles') and conname='profiles_user_id_fkey' and contype='f' and convalidated and not condeferrable and not condeferred and regexp_replace(pg_get_constraintdef(oid,true),'public\.','','g')='FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE') and not exists((select * from actual_profile_triggers except select * from expected_profile_triggers) union all (select * from expected_profile_triggers except select * from actual_profile_triggers)) and not exists((select * from actual_profile_guard_functions except select * from expected_profile_guard_functions) union all (select * from expected_profile_guard_functions except select * from actual_profile_guard_functions)) and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true))) and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5 and exists(select 1 from pg_class where oid=to_regclass('public.profiles') and relowner='postgres'::regrole) and exists(select 1 from pg_class where oid=to_regclass('public.users') and relowner='postgres'::regrole),'owner FK, exact trigger definitions, live-proven guard attributes, role attributes, and owners'),
 ('no_mutation_tokens',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where ((n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))) and p.prosrc ~* '\m(insert|update|delete|merge|truncate|lock|for[[:space:]]+update|pg_advisory)\M'),'no write/lock syntax'),
 ('private_anon_denied',current_setting('mp4a.verify.private_anon',true)='42501','SQLSTATE='||coalesce(current_setting('mp4a.verify.private_anon',true),'<null>')),
 ('private_authenticated_denied',current_setting('mp4a.verify.private_authenticated',true)='42501','SQLSTATE='||coalesce(current_setting('mp4a.verify.private_authenticated',true),'<null>')),
 ('private_service_denied',current_setting('mp4a.verify.private_service',true)='42501','SQLSTATE='||coalesce(current_setting('mp4a.verify.private_service',true),'<null>')),
 ('security_boundary',not has_function_privilege('anon','private.current_active_profile_id()','EXECUTE') and not has_function_privilege('authenticated','private.current_active_profile_id()','EXECUTE') and not has_function_privilege('service_role','private.current_active_profile_id()','EXECUTE') and not has_function_privilege('anon','public.current_active_profile_id()','EXECUTE') and not has_function_privilege('service_role','public.current_active_profile_id()','EXECUTE') and not has_function_privilege('anon','public.current_user_is_active_profile(uuid)','EXECUTE') and not has_function_privilege('service_role','public.current_user_is_active_profile(uuid)','EXECUTE') and not has_function_privilege('anon','public.current_user_is_active_unsuspended_profile(uuid)','EXECUTE') and not has_function_privilege('service_role','public.current_user_is_active_unsuspended_profile(uuid)','EXECUTE') and has_function_privilege('authenticated','public.current_active_profile_id()','EXECUTE') and has_function_privilege('authenticated','public.current_user_is_active_profile(uuid)','EXECUTE') and has_function_privilege('authenticated','public.current_user_is_active_unsuspended_profile(uuid)','EXECUTE'),'private owner-only; public authenticated-only'),
 ('public_output_contract',(select count(*)=3 and bool_and(pg_get_function_result(p.oid) in ('uuid','boolean')) and bool_and(p.prosrc !~* '\muser_id\M') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile')),'only active profile UUID/booleans; no account owner ID')
), summary as (select bool_and(ok) all_ok,count(*) filter(where ok)::int passed,count(*)::int total,coalesce(array_agg(name||': '||detail order by name) filter(where not ok),'{}'::text[]) findings from checks)
select 'SLICE_MP4_A_VERIFY'::text package,case when all_ok then 'GO' else 'STOP' end verdict,passed,total,findings,
 'Rotation/logout lifecycle remains UNPROVEN before MP4-B. Local disposable lifecycle is PostgreSQL 16; target PostgreSQL 17 lifecycle remains UNPROVEN and owner-hosted PREFLIGHT/VERIFY are mandatory. Guard-function owner/direct ACL for enforce_profile_cap() and enforce_profile_owner_immutable() is UNPROVEN because the supplied live bundle did not capture it; no pin was invented.'::text boundary from summary;
rollback;
