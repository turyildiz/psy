-- psy.market Slice MP-4-A: read-only active-authority primitives
-- APPLY — OWNER-RUN IN SUPABASE SQL EDITOR.
-- Adds one owner-only resolver plus three STABLE, read-only, SECURITY DEFINER public primitives. No policy or MP-3 object changes.

begin;
set local lock_timeout='5s';
set local statement_timeout='60s';

-- No table lock is required: this additive package reads catalogs and creates functions only.
do $apply$
declare
  old_ok boolean;
  after_ok boolean;
  old_function_count integer;
  old_acl_count integer;
  new_function_count integer;
  new_acl_count integer;
  old_function_hash text;
  old_acl_hash text;
  new_acl_hash text;
  private_columns_ok boolean;
  private_constraints_ok boolean;
  private_indexes_ok boolean;
  private_table_acl_ok boolean;
  private_schema_acl_ok boolean;
  profile_triggers_ok boolean;
  profile_guard_functions_ok boolean;
  role_attributes_ok boolean;
begin
  if current_user<>'postgres' or session_user<>'postgres' then
    raise exception 'Slice MP4-A APPLY refused: owner SQL Editor context required' using errcode='42501';
  end if;
  if not exists(select 1 from pg_namespace where nspname='private' and nspowner='postgres'::regrole) then
    raise exception 'Slice MP4-A APPLY refused: private schema owner drift' using errcode='55000';
  end if;

  select count(*),md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||p.proisstrict||'|'||p.proleakproof||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),'')) into old_function_count,old_function_hash
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where (n.nspname='private' and p.proname='current_auth_session_id') or
    (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile'));

  select count(*),md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)),'')) into old_acl_count,old_acl_hash
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  where (n.nspname='private' and p.proname='current_auth_session_id') or
    (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile'));

  with expected(ord,name,type_name,not_null,default_expr) as (values (1,'session_id'::text,'uuid'::text,true,''::text),(2,'user_id','uuid',true,''),(3,'profile_id','uuid',true,''),(4,'created_at','timestamp with time zone',true,'now()'),(5,'updated_at','timestamp with time zone',true,'now()')), actual as (select a.attnum::int,a.attname::text,pg_catalog.format_type(a.atttypid,a.atttypmod),a.attnotnull,regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'(public|private)\.','','g') from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=to_regclass('private.account_session_active_profiles') and a.attnum>0 and not a.attisdropped) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_columns_ok;
  with expected(name,type_code,definition,is_validated,is_deferrable,is_deferred) as (values ('account_session_active_profiles_pkey'::text,'p'::text,'PRIMARY KEY (session_id)'::text,true,false,false),('account_session_active_profiles_profile_owner_fkey','f','FOREIGN KEY (profile_id, user_id) REFERENCES profiles(id, user_id) ON DELETE CASCADE',true,false,false),('account_session_active_profiles_user_id_fkey','f','FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE',true,false,false)), actual as (select conname::text,contype::text,regexp_replace(pg_get_constraintdef(oid,true),'(public|private)\.','','g'),convalidated,condeferrable,condeferred from pg_constraint where conrelid=to_regclass('private.account_session_active_profiles')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_constraints_ok;
  with expected(name,definition,is_unique,is_primary,is_valid,is_ready) as (values ('account_session_active_profiles_pkey'::text,'CREATE UNIQUE INDEX account_session_active_profiles_pkey ON private.account_session_active_profiles USING btree (session_id)'::text,true,true,true,true),('account_session_active_profiles_profile_id_idx','CREATE INDEX account_session_active_profiles_profile_id_idx ON private.account_session_active_profiles USING btree (profile_id)',false,false,true,true),('account_session_active_profiles_user_id_idx','CREATE INDEX account_session_active_profiles_user_id_idx ON private.account_session_active_profiles USING btree (user_id)',false,false,true,true)), actual as (select c.relname::text,pg_get_indexdef(c.oid),i.indisunique,i.indisprimary,i.indisvalid,i.indisready from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('private.account_session_active_profiles')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_indexes_ok;
  with available(privilege_type) as (values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE') union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000), expected(grantor,grantee,privilege_type,is_grantable) as (select 'postgres'::text,'postgres'::text,privilege_type,false from available), actual as (select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid=to_regclass('private.account_session_active_profiles')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_table_acl_ok;
  with expected(grantor,grantee,privilege_type,is_grantable) as (values ('postgres'::text,'postgres'::text,'CREATE'::text,false),('postgres','postgres','USAGE',false)), actual as (select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_namespace n cross join lateral aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a where n.nspname='private') select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_schema_acl_ok;
  with expected(name,definition,enabled) as (values ('profiles_enforce_handle'::text,'CREATE TRIGGER profiles_enforce_handle BEFORE INSERT OR UPDATE OF handle ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_handle()'::text,'O'::text),('profiles_five_cap','CREATE TRIGGER profiles_five_cap BEFORE INSERT ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_cap()','O'),('profiles_owner_immutable','CREATE TRIGGER profiles_owner_immutable BEFORE UPDATE OF user_id ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_owner_immutable()','O'),('tr_profiles_updated_at','CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()','O')), actual as (select tgname::text,regexp_replace(pg_get_triggerdef(oid,true),'public\.','','g'),tgenabled::text from pg_trigger where tgrelid=to_regclass('public.profiles') and not tgisinternal) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into profile_triggers_ok;
  with expected(name,args,language_name,volatility,security_definer,is_strict,is_leakproof,parallel_mode,default_count,config,result_type,body_md5) as (values ('enforce_profile_owner_immutable'::text,''::text,'plpgsql'::text,'v'::text,true,false,false,'u'::text,0,'search_path=<empty>'::text,'trigger'::text,'f593015ac29445f3dba408c2d6847535'::text),('enforce_profile_cap','','plpgsql','v',true,false,false,'u',0,'search_path=<empty>','trigger','5fbdaad00844b2c7181946addd7dce58')), actual as (select p.proname::text,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),l.lanname::text,p.provolatile::text,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text,p.pronargdefaults,coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),''),regexp_replace(pg_get_function_result(p.oid),'public\.','','g'),md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into profile_guard_functions_ok;
  with expected(rolname,rolsuper,rolinherit,rolbypassrls) as (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)), actual as (select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into role_attributes_ok;

  old_ok := old_function_count=7 and old_acl_count=13 and old_function_hash='e508fa48daa3f8b44237db8e649e553d' and old_acl_hash='ebdbcf02bd5c1f94e3daa384bdec210a'
    and private_columns_ok and private_constraints_ok and private_indexes_ok and private_table_acl_ok and private_schema_acl_ok
    and exists(select 1 from pg_namespace where nspname='private' and nspowner='postgres'::regrole)
    and exists(select 1 from pg_class where oid=to_regclass('private.account_session_active_profiles') and relowner='postgres'::regrole and relkind='r' and relpersistence='p' and relrowsecurity and relforcerowsecurity and relreplident='d')
    and not exists(select 1 from pg_policy where polrelid=to_regclass('private.account_session_active_profiles'))
    and not exists(select 1 from pg_publication_rel where prrelid=to_regclass('private.account_session_active_profiles'))
    and exists(select 1 from pg_proc where oid=to_regprocedure('private.current_auth_session_id()') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='plpgsql') and provolatile='s' and not prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and regexp_replace(pg_get_function_result(oid),'public\.','','g')='uuid' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='2f25b202bcb90002e021092abb2654fa')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.create_additional_profile(text,text,public.profile_type)') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='plpgsql') and provolatile='v' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='72a5036707a926b12ce03146202f5b09')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.current_user_is_banned()') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='sql') and provolatile='s' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig=array['search_path=pg_catalog, public, auth'] and pg_get_function_result(oid)='boolean' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='682d0a1d82cd433e5bd7deb4aeee5ede')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.current_user_owns_profile(uuid)') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='sql') and provolatile='s' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and pg_get_function_result(oid)='boolean' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='b18b8e4f01df72097d092352423ab8af')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.current_user_owns_unsuspended_profile(uuid)') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='sql') and provolatile='s' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and pg_get_function_result(oid)='boolean' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='5b357bc0a9b5cc0680d8db5a7299d2c7')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.get_active_profile()') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='plpgsql') and provolatile='v' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='efaa1328753958d579292244967afbcd')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.switch_active_profile(uuid)') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='plpgsql') and provolatile='v' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='cd1d9fe7006ad3578c8043d89f92e230')
    and exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.profiles_one_per_user_key') and i.indrelid=to_regclass('public.profiles') and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)')
    and not exists(select 1 from pg_constraint where conindid=to_regclass('public.profiles_one_per_user_key'))
    and exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.idx_profiles_user_id') and i.indrelid=to_regclass('public.profiles') and not i.indisunique and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE INDEX idx_profiles_user_id ON public.profiles USING btree (user_id)')
    and exists(select 1 from pg_constraint where conrelid=to_regclass('public.profiles') and conname='profiles_user_id_fkey' and contype='f' and convalidated and not condeferrable and not condeferred and regexp_replace(pg_get_constraintdef(oid,true),'public\.','','g')='FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE')
    and profile_triggers_ok and profile_guard_functions_ok and role_attributes_ok
    and exists(select 1 from pg_class where oid=to_regclass('public.profiles') and relowner='postgres'::regrole)
    and exists(select 1 from pg_class where oid=to_regclass('public.users') and relowner='postgres'::regrole);

  select count(*) into new_function_count from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'));
  select count(*),md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)),'')) into new_acl_count,new_acl_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'));

  after_ok := old_ok and new_function_count=4 and new_acl_count=7 and new_acl_hash='92eda60f333bdf026d5e1aab0aefd0cd'
    and exists(select 1 from pg_proc where oid=to_regprocedure('private.current_active_profile_id()') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='plpgsql') and provolatile='s' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and pg_get_function_result(oid)='uuid' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='8ab19811ddcf117a757e7663efc5ac77')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.current_active_profile_id()') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='sql') and provolatile='s' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and pg_get_function_result(oid)='uuid' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='6f6b53dbd223db8ba168073c196f7b1a')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.current_user_is_active_profile(uuid)') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='sql') and provolatile='s' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and pg_get_function_result(oid)='boolean' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='63cc27212d60aa55cc7536c3c26310c1')
    and exists(select 1 from pg_proc where oid=to_regprocedure('public.current_user_is_active_unsuspended_profile(uuid)') and proowner='postgres'::regrole and prolang=(select oid from pg_language where lanname='sql') and provolatile='s' and prosecdef and not proisstrict and not proleakproof and proparallel='u' and pronargdefaults=0 and proconfig in (array['search_path='],array['search_path=""']) and pg_get_function_result(oid)='boolean' and md5(btrim(regexp_replace(prosrc,'[[:space:]]+',' ','g')))='a31ffdeee866090a0d7cd1c859a9ec23');

  if after_ok then
    return;
  end if;
  if not old_ok or new_function_count<>0 then
    raise exception 'Slice MP4-A APPLY refused: exact live before/after catalog manifest not found' using errcode='55000';
  end if;

  execute $sql$
    create function private.current_active_profile_id()
    returns uuid
    language plpgsql
    stable
    security definer
    set search_path=''
    as $function$
    declare
      uid uuid:=auth.uid();
      sid uuid;
      selected uuid;
      state_exists boolean;
      fallback_guard boolean;
    begin
      if uid is null then return null; end if;
      sid:=private.current_auth_session_id();
      if sid is null then return null; end if;

      select exists(
        select 1 from private.account_session_active_profiles a where a.session_id=sid
      ) into state_exists;
      if state_exists then
        select a.profile_id into selected
        from private.account_session_active_profiles a
        join public.profiles p on p.id=a.profile_id and p.user_id=a.user_id
        where a.session_id=sid and a.user_id=uid;
        return selected;
      end if;

      select exists(
        select 1 from pg_catalog.pg_index i
        where i.indexrelid=pg_catalog.to_regclass('public.profiles_one_per_user_key')
          and i.indrelid=pg_catalog.to_regclass('public.profiles')
          and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready
          and i.indpred is null
          and pg_catalog.pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)'
          and not exists(select 1 from pg_catalog.pg_constraint c where c.conindid=i.indexrelid)
      ) into fallback_guard;
      if not fallback_guard then return null; end if;

      select p.id into selected from public.profiles p where p.user_id=uid;
      return selected;
    end
    $function$
  $sql$;

  execute $sql$
    create function public.current_active_profile_id()
    returns uuid
    language sql
    stable
    security definer
    set search_path=''
    as $function$
      select private.current_active_profile_id();
    $function$
  $sql$;

  execute $sql$
    create function public.current_user_is_active_profile(target_profile_id uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path=''
    as $function$
      select coalesce(target_profile_id=private.current_active_profile_id(),false);
    $function$
  $sql$;

  execute $sql$
    create function public.current_user_is_active_unsuspended_profile(target_profile_id uuid)
    returns boolean
    language sql
    stable
    security definer
    set search_path=''
    as $function$
      select coalesce(
        target_profile_id=private.current_active_profile_id()
        and exists(select 1 from public.profiles p where p.id=target_profile_id and not p.is_suspended),
        false
      );
    $function$
  $sql$;

  execute 'alter function private.current_active_profile_id() owner to postgres';
  execute 'alter function public.current_active_profile_id() owner to postgres';
  execute 'alter function public.current_user_is_active_profile(uuid) owner to postgres';
  execute 'alter function public.current_user_is_active_unsuspended_profile(uuid) owner to postgres';
  execute 'revoke all on function private.current_active_profile_id() from public,anon,authenticated,service_role';
  execute 'revoke all on function public.current_active_profile_id() from public,anon,service_role';
  execute 'revoke all on function public.current_user_is_active_profile(uuid) from public,anon,service_role';
  execute 'revoke all on function public.current_user_is_active_unsuspended_profile(uuid) from public,anon,service_role';
  execute 'grant execute on function public.current_active_profile_id() to authenticated';
  execute 'grant execute on function public.current_user_is_active_profile(uuid) to authenticated';
  execute 'grant execute on function public.current_user_is_active_unsuspended_profile(uuid) to authenticated';
end
$apply$;

-- Exact postcondition: complete overload/definition/attribute/result and exploded-ACL manifests.
do $post$
declare function_count integer; functions_ok boolean; acl_ok boolean;
begin
  select count(*) into function_count from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'));
  with expected(schema_name,name,args,owner_name,language_name,volatility,security_definer,is_strict,is_leakproof,parallel_mode,default_count,config,result_type,body_md5) as (
    values
    ('private'::text,'current_active_profile_id'::text,''::text,'postgres'::text,'plpgsql'::text,'s'::text,true,false,false,'u'::text,0,'search_path=<empty>'::text,'uuid'::text,'8ab19811ddcf117a757e7663efc5ac77'::text),
    ('public','current_active_profile_id','','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','uuid','6f6b53dbd223db8ba168073c196f7b1a'),
    ('public','current_user_is_active_profile','target_profile_id uuid','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','boolean','63cc27212d60aa55cc7536c3c26310c1'),
    ('public','current_user_is_active_unsuspended_profile','target_profile_id uuid','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','boolean','a31ffdeee866090a0d7cd1c859a9ec23')
  ), actual as (
    select n.nspname::text,p.proname::text,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),p.proowner::regrole::text,l.lanname::text,p.provolatile::text,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text,p.pronargdefaults,
      coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),''),
      regexp_replace(pg_get_function_result(p.oid),'public\.','','g'),md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
    where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
  ) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into functions_ok;
  with expected(object_name,grantee,privilege_type,is_grantable,grantor) as (
    values
    ('private.current_active_profile_id()'::text,'postgres'::text,'EXECUTE'::text,false,'postgres'::text),
    ('public.current_active_profile_id()','authenticated','EXECUTE',false,'postgres'),('public.current_active_profile_id()','postgres','EXECUTE',false,'postgres'),
    ('public.current_user_is_active_profile(target_profile_id uuid)','authenticated','EXECUTE',false,'postgres'),('public.current_user_is_active_profile(target_profile_id uuid)','postgres','EXECUTE',false,'postgres'),
    ('public.current_user_is_active_unsuspended_profile(target_profile_id uuid)','authenticated','EXECUTE',false,'postgres'),('public.current_user_is_active_unsuspended_profile(target_profile_id uuid)','postgres','EXECUTE',false,'postgres')
  ), actual as (
    select n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')',case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable,a.grantor::regrole::text
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
  ) select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into acl_ok;
  if function_count<>4 or not functions_ok or not acl_ok then raise exception 'Slice MP4-A postcondition failed' using errcode='55000'; end if;
end
$post$;
commit;
