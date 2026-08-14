-- psy.market Slice MP-4-A: read-only active-authority primitives
-- PREFLIGHT — READ ONLY; OWNER-RUN IN SUPABASE SQL EDITOR.
-- Pins only the wingman-read 2026-08-13 live evidence bundle. No row aggregates.

begin transaction read only;

with
expected_columns(ord,name,type_name,not_null,default_expr) as (
 values (1,'session_id'::text,'uuid'::text,true,''::text),(2,'user_id','uuid',true,''),
 (3,'profile_id','uuid',true,''),(4,'created_at','timestamp with time zone',true,'now()'),
 (5,'updated_at','timestamp with time zone',true,'now()')
), actual_columns as (
 select a.attnum::int,a.attname::text,pg_catalog.format_type(a.atttypid,a.atttypmod),a.attnotnull,
   regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'(public|private)\.','','g')
 from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
 where a.attrelid=to_regclass('private.account_session_active_profiles') and a.attnum>0 and not a.attisdropped
), expected_constraints(name,type_code,definition,is_validated,is_deferrable,is_deferred) as (
 values
 ('account_session_active_profiles_pkey'::text,'p'::text,'PRIMARY KEY (session_id)'::text,true,false,false),
 ('account_session_active_profiles_profile_owner_fkey','f','FOREIGN KEY (profile_id, user_id) REFERENCES profiles(id, user_id) ON DELETE CASCADE',true,false,false),
 ('account_session_active_profiles_user_id_fkey','f','FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE',true,false,false)
), actual_constraints as (
 select conname::text,contype::text,regexp_replace(pg_get_constraintdef(oid,true),'(public|private)\.','','g'),convalidated,condeferrable,condeferred
 from pg_constraint where conrelid=to_regclass('private.account_session_active_profiles')
), expected_indexes(name,definition,is_unique,is_primary,is_valid,is_ready) as (
 values
 ('account_session_active_profiles_pkey'::text,'CREATE UNIQUE INDEX account_session_active_profiles_pkey ON private.account_session_active_profiles USING btree (session_id)'::text,true,true,true,true),
 ('account_session_active_profiles_profile_id_idx','CREATE INDEX account_session_active_profiles_profile_id_idx ON private.account_session_active_profiles USING btree (profile_id)',false,false,true,true),
 ('account_session_active_profiles_user_id_idx','CREATE INDEX account_session_active_profiles_user_id_idx ON private.account_session_active_profiles USING btree (user_id)',false,false,true,true)
), actual_indexes as (
 select c.relname::text,pg_get_indexdef(c.oid),i.indisunique,i.indisprimary,i.indisvalid,i.indisready
 from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('private.account_session_active_profiles')
), available_table_privilege(privilege_type) as (
 values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE')
 union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000
), expected_table_acl(grantor,grantee,privilege_type,is_grantable) as (
 select 'postgres'::text,'postgres'::text,privilege_type,false from available_table_privilege
), actual_table_acl as (
 select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable
 from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
 where c.oid=to_regclass('private.account_session_active_profiles')
), expected_schema_acl(grantor,grantee,privilege_type,is_grantable) as (
 values ('postgres'::text,'postgres'::text,'CREATE'::text,false),('postgres','postgres','USAGE',false)
), actual_schema_acl as (
 select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable
 from pg_namespace n cross join lateral aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a where n.nspname='private'
), expected_functions(schema_name,function_name,identity_args,owner_name,language_name,volatility,security_definer,is_strict,is_leakproof,parallel_mode,default_count,config,result_type,body_md5) as (
 values
 ('private'::text,'current_auth_session_id'::text,''::text,'postgres'::text,'plpgsql'::text,'s'::text,false,false,false,'u'::text,0,'search_path=<empty>'::text,'uuid'::text,'2f25b202bcb90002e021092abb2654fa'::text),
 ('public','create_additional_profile','new_handle text, new_display_name text, new_type profile_type','postgres','plpgsql','v',true,false,false,'u',0,'search_path=<empty>','TABLE(id uuid, type profile_type, handle text, display_name text, bio text, avatar_url text, header_url text, location text, social_links jsonb, is_creator boolean, is_verified boolean, created_at timestamp with time zone, is_suspended boolean, updated_at timestamp with time zone)','72a5036707a926b12ce03146202f5b09'),
 ('public','current_user_is_banned','','postgres','sql','s',true,false,false,'u',0,'search_path=pg_catalog, public, auth','boolean','682d0a1d82cd433e5bd7deb4aeee5ede'),
 ('public','current_user_owns_profile','target_profile_id uuid','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','boolean','b18b8e4f01df72097d092352423ab8af'),
 ('public','current_user_owns_unsuspended_profile','target_profile_id uuid','postgres','sql','s',true,false,false,'u',0,'search_path=<empty>','boolean','5b357bc0a9b5cc0680d8db5a7299d2c7'),
 ('public','get_active_profile','','postgres','plpgsql','v',true,false,false,'u',0,'search_path=<empty>','TABLE(id uuid, type profile_type, handle text, display_name text, bio text, avatar_url text, header_url text, location text, social_links jsonb, is_creator boolean, is_verified boolean, created_at timestamp with time zone, is_suspended boolean, updated_at timestamp with time zone)','efaa1328753958d579292244967afbcd'),
 ('public','switch_active_profile','target_profile_id uuid','postgres','plpgsql','v',true,false,false,'u',0,'search_path=<empty>','TABLE(id uuid, type profile_type, handle text, display_name text, bio text, avatar_url text, header_url text, location text, social_links jsonb, is_creator boolean, is_verified boolean, created_at timestamp with time zone, is_suspended boolean, updated_at timestamp with time zone)','cd1d9fe7006ad3578c8043d89f92e230')
), actual_functions as (
 select n.nspname::text,p.proname::text,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),p.proowner::regrole::text,l.lanname::text,p.provolatile::text,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text,p.pronargdefaults,
 coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),''),
 regexp_replace(pg_get_function_result(p.oid),'public\.','','g'),md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where (n.nspname='private' and p.proname='current_auth_session_id') or
 (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile'))
), expected_function_acl(object_name,grantee,privilege_type,is_grantable,grantor) as (
 values
 ('private.current_auth_session_id()'::text,'postgres'::text,'EXECUTE'::text,false,'postgres'::text),
 ('public.create_additional_profile(new_handle text, new_display_name text, new_type profile_type)','postgres','EXECUTE',false,'postgres'),
 ('public.current_user_is_banned()','authenticated','EXECUTE',false,'postgres'),('public.current_user_is_banned()','postgres','EXECUTE',false,'postgres'),('public.current_user_is_banned()','service_role','EXECUTE',false,'postgres'),
 ('public.current_user_owns_profile(target_profile_id uuid)','authenticated','EXECUTE',false,'postgres'),('public.current_user_owns_profile(target_profile_id uuid)','postgres','EXECUTE',false,'postgres'),
 ('public.current_user_owns_unsuspended_profile(target_profile_id uuid)','authenticated','EXECUTE',false,'postgres'),('public.current_user_owns_unsuspended_profile(target_profile_id uuid)','postgres','EXECUTE',false,'postgres'),
 ('public.get_active_profile()','authenticated','EXECUTE',false,'postgres'),('public.get_active_profile()','postgres','EXECUTE',false,'postgres'),
 ('public.switch_active_profile(target_profile_id uuid)','authenticated','EXECUTE',false,'postgres'),('public.switch_active_profile(target_profile_id uuid)','postgres','EXECUTE',false,'postgres')
), actual_function_acl as (
 select n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')',case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable,a.grantor::regrole::text
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 where (n.nspname='private' and p.proname='current_auth_session_id') or
 (n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile','get_active_profile','switch_active_profile'))
), expected_profile_triggers(name,definition,enabled) as (
 values
 ('profiles_enforce_handle'::text,'CREATE TRIGGER profiles_enforce_handle BEFORE INSERT OR UPDATE OF handle ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_handle()'::text,'O'::text),
 ('profiles_five_cap','CREATE TRIGGER profiles_five_cap BEFORE INSERT ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_cap()','O'),
 ('profiles_owner_immutable','CREATE TRIGGER profiles_owner_immutable BEFORE UPDATE OF user_id ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_owner_immutable()','O'),
 ('tr_profiles_updated_at','CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()','O')
), actual_profile_triggers as (
 select tgname::text,regexp_replace(pg_get_triggerdef(oid,true),'public\.','','g'),tgenabled::text from pg_trigger where tgrelid=to_regclass('public.profiles') and not tgisinternal
), expected_profile_guard_functions(name,args,language_name,volatility,security_definer,is_strict,is_leakproof,parallel_mode,default_count,config,result_type,body_md5) as (
 values
 ('enforce_profile_owner_immutable'::text,''::text,'plpgsql'::text,'v'::text,true,false,false,'u'::text,0,'search_path=<empty>'::text,'trigger'::text,'f593015ac29445f3dba408c2d6847535'::text),
 ('enforce_profile_cap','','plpgsql','v',true,false,false,'u',0,'search_path=<empty>','trigger','5fbdaad00844b2c7181946addd7dce58')
), actual_profile_guard_functions as (
 select p.proname::text,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),l.lanname::text,p.provolatile::text,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text,p.pronargdefaults,
 coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),''),regexp_replace(pg_get_function_result(p.oid),'public\.','','g'),md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap')
), checks(name,ok,detail) as (
 values
 ('owner_context',current_user='postgres' and session_user='postgres','owner SQL Editor context required'),
 ('private_relation_exact',exists(select 1 from pg_class where oid=to_regclass('private.account_session_active_profiles') and relowner='postgres'::regrole and relkind='r' and relpersistence='p' and relrowsecurity and relforcerowsecurity and relreplident='d'),'private relation flags/owner drift'),
 ('private_columns_exact',not exists((select * from actual_columns except select * from expected_columns) union all (select * from expected_columns except select * from actual_columns)),'private columns drift'),
 ('private_constraints_exact',not exists((select * from actual_constraints except select * from expected_constraints) union all (select * from expected_constraints except select * from actual_constraints)),'private constraints drift'),
 ('private_indexes_exact',not exists((select * from actual_indexes except select * from expected_indexes) union all (select * from expected_indexes except select * from actual_indexes)),'private indexes drift'),
 ('private_table_acl_exact',not exists((select * from actual_table_acl except select * from expected_table_acl) union all (select * from expected_table_acl except select * from actual_table_acl)),'private table ACL drift'),
 ('private_schema_acl_exact',exists(select 1 from pg_namespace where nspname='private' and nspowner='postgres'::regrole) and not exists((select * from actual_schema_acl except select * from expected_schema_acl) union all (select * from expected_schema_acl except select * from actual_schema_acl)),'private schema owner/ACL drift'),
 ('private_no_policies',not exists(select 1 from pg_policy where polrelid=to_regclass('private.account_session_active_profiles')),'private policies drift'),
 ('private_not_published',not exists(select 1 from pg_publication_rel where prrelid=to_regclass('private.account_session_active_profiles')),'private publication drift'),
 ('mp3_helpers_exact',not exists((select * from actual_functions except select * from expected_functions) union all (select * from expected_functions except select * from actual_functions)),'MP-3/helper overload, definition, attribute, or result drift'),
 ('mp3_helper_acls_exact',not exists((select * from actual_function_acl except select * from expected_function_acl) union all (select * from expected_function_acl except select * from actual_function_acl)),'MP-3/helper ACL drift'),
 ('profile_indexes_exact',exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.profiles_one_per_user_key') and i.indrelid=to_regclass('public.profiles') and i.indisunique and not i.indisprimary and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)') and not exists(select 1 from pg_constraint where conindid=to_regclass('public.profiles_one_per_user_key')) and exists(select 1 from pg_index i where i.indexrelid=to_regclass('public.idx_profiles_user_id') and i.indrelid=to_regclass('public.profiles') and not i.indisunique and i.indisvalid and i.indisready and i.indpred is null and pg_get_indexdef(i.indexrelid)='CREATE INDEX idx_profiles_user_id ON public.profiles USING btree (user_id)'),'profile index anatomy drift'),
 ('profile_owner_fk_exact',exists(select 1 from pg_constraint where conrelid=to_regclass('public.profiles') and conname='profiles_user_id_fkey' and contype='f' and convalidated and not condeferrable and not condeferred and regexp_replace(pg_get_constraintdef(oid,true),'public\.','','g')='FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE'),'profile owner FK drift'),
 ('profile_guards_exact',not exists((select * from actual_profile_triggers except select * from expected_profile_triggers) union all (select * from expected_profile_triggers except select * from actual_profile_triggers)) and not exists((select * from actual_profile_guard_functions except select * from expected_profile_guard_functions) union all (select * from expected_profile_guard_functions except select * from actual_profile_guard_functions)),'profile trigger definition or live-proven guard-function attribute/body/overload drift'),
 ('role_attributes_exact',not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon',false,true,false),('audit_readonly',false,false,false),('authenticated',false,true,false),('postgres',false,true,true),('service_role',false,true,true))) and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5,'role attribute drift'),
 ('table_owners_exact',exists(select 1 from pg_class where oid=to_regclass('public.profiles') and relowner='postgres'::regrole) and exists(select 1 from pg_class where oid=to_regclass('public.users') and relowner='postgres'::regrole),'owner drift'),
 ('mp4a_names_absent',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))),'MP4-A same-name function/overload exists')
), summary as (
 select bool_and(ok) all_ok,coalesce(array_agg(name order by name) filter(where not ok),'{}'::text[]) findings,coalesce(array_agg(name||': '||detail order by name) filter(where not ok),'{}'::text[]) details from checks
)
select 'SLICE_MP4_A_PREFLIGHT'::text package,case when all_ok then 'GO' else 'STOP' end verdict,findings,details,
 'Guard-function owner/direct ACL for enforce_profile_cap() and enforce_profile_owner_immutable() is UNPROVEN because the supplied live bundle did not capture it; no pin was invented.'::text boundary from summary;
rollback;
