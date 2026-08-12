-- psy.market Slice MP-3: database cardinality, type, and active-session foundation
-- PREFLIGHT — READ ONLY; OWNER-RUN IN SUPABASE SQL EDITOR.
--
-- Investigation summary:
-- * vendor is additive and dormant: current app unions/selectors expose only the four
--   existing types, while policies do not enumerate profile_type labels.
-- * active state is private and keyed by the Supabase JWT session_id, so independent
--   sessions remain independent. One-profile accounts lazily resolve their sole profile.
--   Missing/malformed claims, missing account rows, foreign ownership, and banned users
--   fail closed.
-- * profiles_one_per_user_key and signup's one-personal-profile behavior remain in force.
-- * the trusted additional-profile RPC is installed with owner-only EXECUTE and also
--   refuses while profiles_one_per_user_key exists.
-- * Package B helper fingerprints/ACLs, Package D's complete profile ACL, profile RLS
--   policies, signup, constraints, indexes, and triggers are pinned below.
--
-- Honest rollback: PostgreSQL has no supported DROP VALUE. Operational rollback removes
-- every reversible MP-3 object but deliberately retains the dormant vendor label.

begin transaction read only;

with
expected_enum(ord,label) as (
 values (1,'personal'::text),(2,'artist'),(3,'label'),(4,'festival')
), actual_enum as (
 select row_number() over(order by e.enumsortorder)::int,e.enumlabel::text
 from pg_catalog.pg_enum e where e.enumtypid=pg_catalog.to_regtype('public.profile_type')
), expected_columns(ord,name,type_name,not_null,default_expr) as (
 values
 (1,'id'::text,'uuid'::text,true,'gen_random_uuid()'::text),(2,'user_id','uuid',true,''),
 (3,'type','profile_type',true,'''personal''::profile_type'),(4,'handle','text',true,''),
 (5,'display_name','text',true,''),(6,'bio','text',false,''),(7,'avatar_url','text',false,''),
 (8,'header_url','text',false,''),(9,'location','text',false,''),(10,'social_links','jsonb',false,'''{}''::jsonb'),
 (11,'is_creator','bool',true,'false'),(12,'is_verified','bool',true,'false'),
 (13,'is_suspended','bool',true,'false'),(14,'created_at','timestamptz',true,'now()'),
 (15,'updated_at','timestamptz',true,'now()')
), actual_columns as (
 select a.attnum::int,a.attname::text,t.typname::text,a.attnotnull,
   regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'public\.','','g')
 from pg_attribute a join pg_type t on t.oid=a.atttypid
 left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
 where a.attrelid=to_regclass('public.profiles') and a.attnum>0 and not a.attisdropped
), expected_constraints(name,definition) as (
 values
 ('bio_length'::text,'CHECK (bio IS NULL OR char_length(bio) <= 500)'::text),
 ('display_name_length','CHECK (char_length(display_name) >= 1 AND char_length(display_name) <= 100)'),
 ('handle_format','CHECK (handle ~ ''^[a-zA-Z0-9_]+$''::text)'),
 ('handle_length','CHECK (char_length(handle) >= 3 AND char_length(handle) <= 30)'),
 ('location_length','CHECK (location IS NULL OR char_length(location) <= 100)'),
 ('profiles_handle_key','UNIQUE (handle)'),('profiles_pkey','PRIMARY KEY (id)'),
 ('profiles_one_per_user_key','UNIQUE (user_id)'),
 ('profiles_user_id_fkey','FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE')
), actual_constraints as (
 select conname::text,pg_get_constraintdef(oid,true)::text from pg_constraint
 where conrelid=to_regclass('public.profiles') and convalidated and not condeferrable and not condeferred
), expected_indexes(name,definition) as (
 values
 ('idx_profiles_handle'::text,'CREATE INDEX idx_profiles_handle ON public.profiles USING btree (handle)'::text),
 ('idx_profiles_user_id','CREATE INDEX idx_profiles_user_id ON public.profiles USING btree (user_id)'),
 ('profiles_handle_key','CREATE UNIQUE INDEX profiles_handle_key ON public.profiles USING btree (handle)'),
 ('profiles_handle_lower_key','CREATE UNIQUE INDEX profiles_handle_lower_key ON public.profiles USING btree (lower(handle))'),
 ('profiles_one_per_user_key','CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)'),
 ('profiles_pkey','CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id)')
), actual_indexes as (
 select c.relname::text,pg_get_indexdef(c.oid)::text from pg_index i join pg_class c on c.oid=i.indexrelid
 where i.indrelid=to_regclass('public.profiles') and i.indisvalid and i.indisready and i.indpred is null
), expected_triggers(name,definition,enabled) as (
 values
 ('profiles_enforce_handle'::text,'CREATE TRIGGER profiles_enforce_handle BEFORE INSERT OR UPDATE OF handle ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_handle()'::text,'O'::text),
 ('tr_profiles_updated_at','CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()','O')
), actual_triggers as (
 select tgname::text,pg_get_triggerdef(oid,true)::text,tgenabled::text from pg_trigger
 where tgrelid=to_regclass('public.profiles') and not tgisinternal
), expected_policies(name,cmd,permissive,roles,qual,check_expr) as (
 values
 ('Profiles are publicly readable'::text,'SELECT'::text,'PERMISSIVE'::text,'{public}'::text,'true'::text,''::text),
 ('Unbanned users insert own profiles','INSERT','PERMISSIVE','{authenticated}','', '((auth.uid() = user_id) AND (NOT current_user_is_banned()))'),
 ('Unbanned users update own profiles','UPDATE','PERMISSIVE','{authenticated}','((auth.uid() = user_id) AND (NOT current_user_is_banned()))','((auth.uid() = user_id) AND (NOT current_user_is_banned()))')
), actual_policies as (
 select policyname::text,cmd::text,permissive::text,roles::text,coalesce(qual,''),coalesce(with_check,'')
 from pg_policies where schemaname='public' and tablename='profiles'
), available_privilege(privilege_type) as (
 values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE')
 union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000
), expected_table_acl(grantor,grantee,privilege_type,is_grantable) as (
 select 'postgres'::text,r.grantee,p.privilege_type,false
 from (values ('postgres'::text),('anon'),('authenticated'),('service_role')) r(grantee)
 cross join available_privilege p where not(r.grantee in ('anon','authenticated') and p.privilege_type='SELECT')
 union all select 'postgres','audit_readonly','SELECT',false
), actual_table_acl as (
 select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,
   a.privilege_type::text,a.is_grantable
 from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
 where c.oid=to_regclass('public.profiles')
), safe_column(name) as (
 values ('id'::text),('type'),('handle'),('display_name'),('bio'),('avatar_url'),('header_url'),
 ('location'),('social_links'),('is_creator'),('is_verified'),('created_at')
), expected_column_acl(column_name,grantor,grantee,privilege_type,is_grantable) as (
 select c.name,'postgres'::text,r.grantee,'SELECT'::text,false
 from safe_column c cross join (values ('anon'::text),('authenticated')) r(grantee)
), actual_column_acl as (
 select x.attname::text,a.grantor::regrole::text,
   case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable
 from pg_attribute x cross join lateral aclexplode(x.attacl) a
 where x.attrelid=to_regclass('public.profiles') and x.attnum>0 and not x.attisdropped and x.attacl is not null
), expected_helper(name,args,body_md5) as (
 values ('get_my_profiles'::text,''::text,'068d419cf900e4bde1bd36b73433c2b3'::text),
 ('current_user_owns_profile','target_profile_id uuid','b18b8e4f01df72097d092352423ab8af'),
 ('admin_get_profile_account','target_profile_id uuid','1b1617031aa49512a692d706462e4f18')
), actual_helper as (
 select p.proname::text,pg_get_function_identity_arguments(p.oid),
   md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account')
   and p.proowner='postgres'::regrole and p.prosecdef and p.provolatile='s'
   and p.proconfig in (array['search_path=""'],array['search_path='])
), expected_helper_acl(name,grantee) as (
 values ('get_my_profiles'::text,'postgres'::text),('get_my_profiles','authenticated'),
 ('current_user_owns_profile','postgres'),('current_user_owns_profile','authenticated'),
 ('admin_get_profile_account','postgres'),('admin_get_profile_account','authenticated')
), actual_helper_acl as (
 select p.proname::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account')
   and a.privilege_type='EXECUTE' and not a.is_grantable and a.grantor='postgres'::regrole
), checks(name,ok,detail) as (
 values
 ('owner_context',current_user='postgres' and session_user='postgres','owner SQL Editor context required'),
 ('enum_exact',not exists((select * from actual_enum except select * from expected_enum) union all (select * from expected_enum except select * from actual_enum)),'enum drift'),
 ('profiles_relation_exact',exists(select 1 from pg_class where oid=to_regclass('public.profiles') and relkind='r' and relowner='postgres'::regrole and relrowsecurity and not relforcerowsecurity),'relation/RLS drift'),
 ('profiles_columns_exact',not exists((select * from actual_columns except select * from expected_columns) union all (select * from expected_columns except select * from actual_columns)),'column drift'),
 ('profiles_constraints_exact',not exists((select * from actual_constraints except select * from expected_constraints) union all (select * from expected_constraints except select * from actual_constraints)),'constraint drift'),
 ('profiles_indexes_exact',not exists((select * from actual_indexes except select * from expected_indexes) union all (select * from expected_indexes except select * from actual_indexes)),'index drift'),
 ('profiles_triggers_exact',not exists((select * from actual_triggers except select * from expected_triggers) union all (select * from expected_triggers except select * from actual_triggers)),'trigger drift'),
 ('profiles_policies_exact',not exists((select * from actual_policies except select * from expected_policies) union all (select * from expected_policies except select * from actual_policies)),'policy drift'),
 ('package_d_table_acl_exact',not exists((select * from actual_table_acl except select * from expected_table_acl) union all (select * from expected_table_acl except select * from actual_table_acl)),'table ACL drift'),
 ('package_d_column_acl_exact',not exists((select * from actual_column_acl except select * from expected_column_acl) union all (select * from expected_column_acl except select * from actual_column_acl)),'column ACL drift'),
 ('package_b_helpers_exact',not exists((select * from actual_helper except select * from expected_helper) union all (select * from expected_helper except select * from actual_helper)),'helper definition/overload drift'),
 ('package_b_helper_acl_exact',not exists((select * from actual_helper_acl except select * from expected_helper_acl) union all (select * from expected_helper_acl except select * from actual_helper_acl)),'helper ACL drift'),
 ('signup_exact',exists(select 1 from pg_proc p where p.oid=to_regprocedure('public.handle_new_user()') and p.proowner='postgres'::regrole and p.prosecdef and p.proconfig=array['search_path=pg_catalog, public, auth'] and md5(btrim(regexp_replace(p.prosrc,E'\s+',' ','g')))='eba9c36d311b3cf937ff3dd964ca8e58') and exists(select 1 from pg_trigger t where t.tgrelid=to_regclass('auth.users') and t.tgname='on_auth_user_created' and not t.tgisinternal and t.tgenabled='O' and t.tgfoid=to_regprocedure('public.handle_new_user()')),'signup drift'),
 ('one_profile_data',not exists(select 1 from public.profiles group by user_id having count(*)<>1),'cardinality drift'),
 ('account_correspondence',not exists(select 1 from public.profiles p left join public.users u on u.id=p.user_id where u.id is null),'public account invariant drift'),
 ('mp3_names_absent',to_regnamespace('private') is null and not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname in ('current_auth_session_id','get_active_profile','switch_active_profile','create_additional_profile','enforce_profile_owner_immutable','enforce_profile_cap')) and not exists(select 1 from pg_constraint where conrelid=to_regclass('public.profiles') and conname='profiles_id_user_id_key'),'MP-3 or same-name object already exists')
), verdict as (
 select case when bool_and(ok) then 'GO' else 'STOP' end verdict,
 coalesce(array_agg(name order by name) filter(where not ok),'{}'::text[]) findings,
 coalesce(array_agg(name||': '||detail order by name) filter(where not ok),'{}'::text[]) details from checks
)
select 'MP3_FOUNDATION_PREFLIGHT'::text package,verdict,findings,details from verdict;
rollback;
