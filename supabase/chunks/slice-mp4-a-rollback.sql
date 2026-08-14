-- psy.market Slice MP-4-A: read-only active-authority primitives
-- ROLLBACK — OWNER-RUN IN SUPABASE SQL EDITOR.
-- Exact after-state gate; removes only the four additive MP4-A functions.

begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

do $rollback$
declare
  function_count integer;
  function_hash text;
  acl_count integer;
  acl_hash text;
  mp3_function_count integer;
  mp3_function_hash text;
  mp3_acl_count integer;
  mp3_acl_hash text;
  private_columns_ok boolean;
  private_constraints_ok boolean;
  private_indexes_ok boolean;
  private_table_acl_ok boolean;
  private_schema_acl_ok boolean;
  profile_triggers_ok boolean;
  profile_guard_functions_ok boolean;
  role_attributes_ok boolean;
  dependencies_ok boolean;
begin
  if current_user<>'postgres' or session_user<>'postgres' then
    raise exception 'Slice MP4-A ROLLBACK refused: owner SQL Editor context required' using errcode='42501';
  end if;
  if not exists(select 1 from pg_namespace where nspname='private' and nspowner='postgres'::regrole) then
    raise exception 'Slice MP4-A ROLLBACK refused: private schema owner drift' using errcode='55000';
  end if;

  select count(*),md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||p.proisstrict||'|'||p.proleakproof||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),''))
  into function_count,function_hash
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'));

  select count(*),md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)),''))
  into acl_count,acl_hash
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'));

  select count(*),md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||p.proisstrict||'|'||p.proleakproof||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),'')) into mp3_function_count,mp3_function_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile'));
  select count(*),md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)),'')) into mp3_acl_count,mp3_acl_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile'));

  with expected(ord,name,type_name,not_null,default_expr) as (values (1,'session_id'::text,'uuid'::text,true,''::text),(2,'user_id','uuid',true,''),(3,'profile_id','uuid',true,''),(4,'created_at','timestamp with time zone',true,'now()'),(5,'updated_at','timestamp with time zone',true,'now()')), actual as (select a.attnum::int,a.attname::text,pg_catalog.format_type(a.atttypid,a.atttypmod),a.attnotnull,regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'(public|private)\.','','g') from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=to_regclass('private.account_session_active_profiles') and a.attnum>0 and not a.attisdropped) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_columns_ok;
  with expected(name,type_code,definition,is_validated,is_deferrable,is_deferred) as (values ('account_session_active_profiles_pkey'::text,'p'::text,'PRIMARY KEY (session_id)'::text,true,false,false),('account_session_active_profiles_profile_owner_fkey','f','FOREIGN KEY (profile_id, user_id) REFERENCES profiles(id, user_id) ON DELETE CASCADE',true,false,false),('account_session_active_profiles_user_id_fkey','f','FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE',true,false,false)), actual as (select conname::text,contype::text,regexp_replace(pg_get_constraintdef(oid,true),'(public|private)\.','','g'),convalidated,condeferrable,condeferred from pg_constraint where conrelid=to_regclass('private.account_session_active_profiles')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_constraints_ok;
  with expected(name,definition,is_unique,is_primary,is_valid,is_ready) as (values ('account_session_active_profiles_pkey'::text,'CREATE UNIQUE INDEX account_session_active_profiles_pkey ON private.account_session_active_profiles USING btree (session_id)'::text,true,true,true,true),('account_session_active_profiles_profile_id_idx','CREATE INDEX account_session_active_profiles_profile_id_idx ON private.account_session_active_profiles USING btree (profile_id)',false,false,true,true),('account_session_active_profiles_user_id_idx','CREATE INDEX account_session_active_profiles_user_id_idx ON private.account_session_active_profiles USING btree (user_id)',false,false,true,true)), actual as (select c.relname::text,pg_get_indexdef(c.oid),i.indisunique,i.indisprimary,i.indisvalid,i.indisready from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('private.account_session_active_profiles')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_indexes_ok;
  with available(privilege_type) as (values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE') union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000), expected(grantor,grantee,privilege_type,is_grantable) as (select 'postgres'::text,'postgres'::text,privilege_type,false from available), actual as (select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid=to_regclass('private.account_session_active_profiles')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_table_acl_ok;
  with expected(grantor,grantee,privilege_type,is_grantable) as (values ('postgres'::text,'postgres'::text,'CREATE'::text,false),('postgres','postgres','USAGE',false)), actual as (select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_namespace n cross join lateral aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a where n.nspname='private') select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_schema_acl_ok;
  with expected(name,definition,enabled) as (values ('profiles_enforce_handle'::text,'CREATE TRIGGER profiles_enforce_handle BEFORE INSERT OR UPDATE OF handle ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_handle()'::text,'O'::text),('profiles_five_cap','CREATE TRIGGER profiles_five_cap BEFORE INSERT ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_cap()','O'),('profiles_owner_immutable','CREATE TRIGGER profiles_owner_immutable BEFORE UPDATE OF user_id ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_owner_immutable()','O'),('tr_profiles_updated_at','CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()','O')), actual as (select tgname::text,regexp_replace(pg_get_triggerdef(oid,true),'public\.','','g'),tgenabled::text from pg_trigger where tgrelid=to_regclass('public.profiles') and not tgisinternal) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into profile_triggers_ok;
  with expected(name,args,language_name,volatility,security_definer,is_strict,is_leakproof,parallel_mode,default_count,config,result_type,body_md5) as (values ('enforce_profile_owner_immutable'::text,''::text,'plpgsql'::text,'v'::text,true,false,false,'u'::text,0,'search_path=<empty>'::text,'trigger'::text,'f593015ac29445f3dba408c2d6847535'::text),('enforce_profile_cap','','plpgsql','v',true,false,false,'u',0,'search_path=<empty>','trigger','5fbdaad00844b2c7181946addd7dce58')), actual as (select p.proname::text,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),l.lanname::text,p.provolatile::text,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text,p.pronargdefaults,coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),''),regexp_replace(pg_get_function_result(p.oid),'public\.','','g'),md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into profile_guard_functions_ok;
  with expected(rolname,rolsuper,rolinherit,rolbypassrls) as (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)), actual as (select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into role_attributes_ok;

  dependencies_ok := mp3_function_count=7 and mp3_acl_count=13 and mp3_function_hash='e508fa48daa3f8b44237db8e649e553d' and mp3_acl_hash='ebdbcf02bd5c1f94e3daa384bdec210a'
    and private_columns_ok and private_constraints_ok and private_indexes_ok and private_table_acl_ok and private_schema_acl_ok
    and exists(select 1 from pg_namespace where nspname='private' and nspowner='postgres'::regrole)
    and exists(select 1 from pg_class where oid=to_regclass('private.account_session_active_profiles') and relowner='postgres'::regrole and relkind='r' and relpersistence='p' and relrowsecurity and relforcerowsecurity and relreplident='d')
    and not exists(select 1 from pg_policy where polrelid=to_regclass('private.account_session_active_profiles'))
    and not exists(select 1 from pg_publication_rel where prrelid=to_regclass('private.account_session_active_profiles'))
    and exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.profiles_one_per_user_key') and i.indrelid=to_regclass('public.profiles') and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)')
    and not exists(select 1 from pg_constraint where conindid=to_regclass('public.profiles_one_per_user_key'))
    and exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.idx_profiles_user_id') and i.indrelid=to_regclass('public.profiles') and not i.indisunique and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE INDEX idx_profiles_user_id ON public.profiles USING btree (user_id)')
    and exists(select 1 from pg_constraint where conrelid=to_regclass('public.profiles') and conname='profiles_user_id_fkey' and contype='f' and convalidated and not condeferrable and not condeferred and regexp_replace(pg_get_constraintdef(oid,true),'public\.','','g')='FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE')
    and profile_triggers_ok and profile_guard_functions_ok and role_attributes_ok
    and exists(select 1 from pg_class where oid=to_regclass('public.profiles') and relowner='postgres'::regrole)
    and exists(select 1 from pg_class where oid=to_regclass('public.users') and relowner='postgres'::regrole);

  if function_count=0 and acl_count=0 then
    if not dependencies_ok then raise exception 'Slice MP4-A ROLLBACK refused: dependency drift in restored state' using errcode='55000'; end if;
    return;
  end if;
  if function_count<>4 or acl_count<>7 or function_hash<>'e91f9fb04472240f49bbd1b6b74aeff1' or acl_hash<>'92eda60f333bdf026d5e1aab0aefd0cd' or not dependencies_ok then
    raise exception 'Slice MP4-A ROLLBACK refused: exact after/restored manifest not found' using errcode='55000';
  end if;

  drop function public.current_user_is_active_unsuspended_profile(uuid);
  drop function public.current_user_is_active_profile(uuid);
  drop function public.current_active_profile_id();
  drop function private.current_active_profile_id();
end
$rollback$;

-- Restored postcondition: all same-name overloads absent; MP-3 objects remain.
do $post$
begin
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))) then
    raise exception 'Slice MP4-A rollback postcondition: same-name function remains' using errcode='55000';
  end if;
  if to_regprocedure('private.current_auth_session_id()') is null or to_regprocedure('public.get_active_profile()') is null or to_regprocedure('public.switch_active_profile(uuid)') is null or to_regprocedure('public.create_additional_profile(text,text,public.profile_type)') is null then
    raise exception 'Slice MP4-A rollback postcondition: MP-3 dependency missing' using errcode='55000';
  end if;
end
$post$;
commit;
