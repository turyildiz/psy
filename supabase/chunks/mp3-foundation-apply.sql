-- psy.market Slice MP-3: database cardinality, type, and active-session foundation
-- APPLY — OWNER-RUN IN SUPABASE SQL EDITOR.
--
-- This file has one intentionally non-transactional step: PostgreSQL enum labels cannot
-- be removed by rollback. A guard runs immediately before ADD VALUE. If any later
-- transactional step refuses, vendor can remain as a harmless dormant label; rerun is
-- safe and accepts that exact residual state. No existing policy, ACL, helper, or signup
-- object is changed.

-- Guard immediately before the irreversible additive enum operation.
do $enum_guard$
begin
  if current_user<>'postgres' or session_user<>'postgres' then
    raise exception 'MP-3 APPLY refused: owner SQL Editor context required' using errcode='42501';
  end if;
  if pg_catalog.to_regtype('public.profile_type') is null then
    raise exception 'MP-3 APPLY refused: profile_type missing' using errcode='55000';
  end if;
  if (select array_agg(e.enumlabel::text order by e.enumsortorder) from pg_catalog.pg_enum e where e.enumtypid='public.profile_type'::regtype)
     not in (array['personal','artist','label','festival'],array['personal','artist','label','festival','vendor']) then
    raise exception 'MP-3 APPLY refused: profile_type label drift' using errcode='55000';
  end if;
end
$enum_guard$;

alter type public.profile_type add value if not exists 'vendor';

begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
lock table public.profiles in share row exclusive mode;
lock table public.users in share row exclusive mode;

-- Exact immediate state guard. Catalog fingerprints cover every unchanged profile
-- dependency and every MP-3 object. Complete ACLs are compared as sets so PG17's
-- MAINTAIN privilege is handled without weakening the manifest.
do $state_guard$
declare
  enum_ok boolean; base_ok boolean; before_state boolean; after_state boolean;
  table_acl_ok boolean; column_acl_ok boolean; helper_acl_ok boolean;
  private_table_acl_ok boolean; private_schema_acl_ok boolean;
  profile_constraints text; profile_indexes text; profile_triggers text;
  policy_hash text; helper_hash text; signup_hash text;
  mp3_function_hash text; mp3_function_acl_hash text;
  private_constraint_hash text; private_index_hash text;
  private_rel_hash text; private_schema_hash text;
begin
  select array_agg(e.enumlabel::text order by e.enumsortorder)=array['personal','artist','label','festival','vendor']
  into enum_ok from pg_catalog.pg_enum e where e.enumtypid='public.profile_type'::regtype;

  with available(p) as (
    values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE')
    union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000
  ), expected(g,r,p,x) as (
    select 'postgres'::text,v.r,a.p,false from (values ('postgres'::text),('anon'),('authenticated'),('service_role')) v(r)
    cross join available a where not(v.r in ('anon','authenticated') and a.p='SELECT')
    union all select 'postgres','audit_readonly','SELECT',false
  ), actual(g,r,p,x) as (
    select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,
      a.privilege_type::text,a.is_grantable from pg_class c
    cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
    where c.oid='public.profiles'::regclass
  ) select not exists((select * from actual except select * from expected) union all
    (select * from expected except select * from actual)) into table_acl_ok;

  with safe(c) as (values ('id'::text),('type'),('handle'),('display_name'),('bio'),('avatar_url'),
    ('header_url'),('location'),('social_links'),('is_creator'),('is_verified'),('created_at')),
  expected(c,g,r,p,x) as (select s.c,'postgres'::text,v.r,'SELECT'::text,false from safe s
    cross join (values ('anon'::text),('authenticated')) v(r)),
  actual(c,g,r,p,x) as (select z.attname::text,a.grantor::regrole::text,
    case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable
    from pg_attribute z cross join lateral aclexplode(z.attacl) a where z.attrelid='public.profiles'::regclass
    and z.attnum>0 and not z.attisdropped and z.attacl is not null)
  select not exists((select * from actual except select * from expected) union all
    (select * from expected except select * from actual)) into column_acl_ok;

  with expected(n,r) as (values ('get_my_profiles'::text,'postgres'::text),('get_my_profiles','authenticated'),
    ('current_user_owns_profile','postgres'),('current_user_owns_profile','authenticated'),
    ('admin_get_profile_account','postgres'),('admin_get_profile_account','authenticated')),
  actual(n,r) as (select p.proname::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account')
    and a.privilege_type='EXECUTE' and not a.is_grantable and a.grantor='postgres'::regrole)
  select not exists((select * from actual except select * from expected) union all
    (select * from expected except select * from actual)) into helper_acl_ok;

  select md5(coalesce(string_agg(conname||'|'||regexp_replace(pg_get_constraintdef(oid,true),'(public|private)\.','','g')||'|'||convalidated||'|'||condeferrable||'|'||condeferred,E'\n' order by conname),''))
    into profile_constraints from pg_constraint where conrelid='public.profiles'::regclass;
  select md5(coalesce(string_agg(c.relname||'|'||pg_get_indexdef(c.oid)||'|'||i.indisunique||'|'||i.indisprimary||'|'||i.indisvalid||'|'||i.indisready,E'\n' order by c.relname),''))
    into profile_indexes from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid='public.profiles'::regclass;
  select md5(coalesce(string_agg(tgname||'|'||regexp_replace(pg_get_triggerdef(oid,true),'public\.','','g')||'|'||tgenabled::text,E'\n' order by tgname),''))
    into profile_triggers from pg_trigger where tgrelid='public.profiles'::regclass and not tgisinternal;
  select md5(coalesce(string_agg(policyname||'|'||cmd||'|'||permissive||'|'||roles::text||'|'||regexp_replace(coalesce(qual,''),'public\.','','g')||'|'||regexp_replace(coalesce(with_check,''),'public\.','','g'),E'\n' order by policyname),''))
    into policy_hash from pg_policies where schemaname='public' and tablename='profiles';
  select md5(coalesce(string_agg(p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),''))
    into helper_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
    and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account');
  select md5(p.proowner::regrole::text||'|'||p.prosecdef||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))))
    into signup_hash from pg_proc p where p.oid=to_regprocedure('public.handle_new_user()');

  select md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||p.prosecdef||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g')))||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g'),E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')),''))
    into mp3_function_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
    where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap','get_active_profile','switch_active_profile','create_additional_profile'));
  select md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||a.is_grantable||'|'||a.grantor::regrole::text,E'\n' order by n.nspname,p.proname,regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g'),(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)),''))
    into mp3_function_acl_hash from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where (n.nspname='private' and p.proname='current_auth_session_id') or (n.nspname='public' and p.proname in ('enforce_profile_owner_immutable','enforce_profile_cap','get_active_profile','switch_active_profile','create_additional_profile'));
  select md5(coalesce(string_agg(conname||'|'||regexp_replace(pg_get_constraintdef(oid,true),'(public|private)\.','','g')||'|'||convalidated||'|'||condeferrable||'|'||condeferred,E'\n' order by conname),''))
    into private_constraint_hash from pg_constraint where conrelid=to_regclass('private.account_session_active_profiles');
  select md5(coalesce(string_agg(c.relname||'|'||pg_get_indexdef(c.oid)||'|'||i.indisunique||'|'||i.indisprimary||'|'||i.indisvalid||'|'||i.indisready,E'\n' order by c.relname),''))
    into private_index_hash from pg_index i join pg_class c on c.oid=i.indexrelid where i.indrelid=to_regclass('private.account_session_active_profiles');
  select md5(c.relowner::regrole::text||'|'||c.relkind::text||'|'||c.relpersistence::text||'|'||c.relrowsecurity||'|'||c.relforcerowsecurity||'|'||c.relreplident::text)
    into private_rel_hash from pg_class c where c.oid=to_regclass('private.account_session_active_profiles');
  select md5(n.nspowner::regrole::text) into private_schema_hash from pg_namespace n where n.nspname='private';
  with available(p) as (values ('DELETE'::text),('INSERT'),('REFERENCES'),('SELECT'),('TRIGGER'),('TRUNCATE'),('UPDATE') union all select 'MAINTAIN' where current_setting('server_version_num')::int>=170000),
  expected(g,r,p,x) as (select 'postgres'::text,'postgres'::text,p,false from available),
  actual(g,r,p,x) as (select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_class c cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where c.oid=to_regclass('private.account_session_active_profiles'))
  select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_table_acl_ok;
  with expected(g,r,p,x) as (values ('postgres'::text,'postgres'::text,'CREATE'::text,false),('postgres','postgres','USAGE',false)),
  actual(g,r,p,x) as (select a.grantor::regrole::text,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end,a.privilege_type::text,a.is_grantable from pg_namespace n cross join lateral aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a where n.nspname='private')
  select not exists((select * from actual except select * from expected) union all (select * from expected except select * from actual)) into private_schema_acl_ok;

  base_ok := enum_ok and table_acl_ok and column_acl_ok and helper_acl_ok
    and policy_hash='b33046c229ea730bcf923ad9f8a114cb'
    and helper_hash='d175baa081926c85004e36268f061f76'
    and signup_hash='59ab4dce2526438016742af297aadc55'
    and exists(select 1 from pg_class where oid='public.profiles'::regclass and relowner='postgres'::regrole and relrowsecurity and not relforcerowsecurity)
    and not exists(select 1 from public.profiles group by user_id having count(*)<>1)
    and not exists(select 1 from public.profiles p left join public.users u on u.id=p.user_id where u.id is null);
  before_state := base_ok and profile_constraints='598ae47d30453ad1c903b5be7f602c27'
    and profile_indexes='79c9a17b697a7b73f8eb9525b4d9b2eb' and profile_triggers='1998fb8f45cd9c01e2899e8872a2e976'
    and mp3_function_hash='d41d8cd98f00b204e9800998ecf8427e' and to_regnamespace('private') is null;
  after_state := base_ok and profile_constraints='f4ac02be62984924b395f7b701a700f3'
    and profile_indexes='694204eef68f8094274c642e9123ee94' and profile_triggers='56c1252d8625f9a55726e920649de8c3'
    and mp3_function_hash='37642125b28b41fd83eb27d62e55e116'
    and mp3_function_acl_hash='278f9ec775ed45028d4d817ab12b0eb7'
    and private_constraint_hash='2890dfa115b3b4d990522a2ba9c49701'
    and private_index_hash='ae9b1f423455163225eaaa07886a845e'
    and private_rel_hash='f9a66a264d09636f09eac24c19eb6b43'
    and private_schema_hash='e8a48653851e28c69d0506508fb27fc5'
    and private_table_acl_ok and private_schema_acl_ok;
  if not before_state and not after_state then
    raise exception 'MP-3 APPLY refused: exact before/after catalog manifest not found' using errcode='55000';
  end if;
end
$state_guard$;

do $ownership_key$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid='public.profiles'::regclass
      and conname='profiles_id_user_id_key' and contype='u'
  ) then
    alter table public.profiles
      add constraint profiles_id_user_id_key unique(id,user_id);
  end if;
end
$ownership_key$;

create schema if not exists private authorization postgres;
revoke all on schema private from public,anon,authenticated,service_role;

create table if not exists private.account_session_active_profiles (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  profile_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_session_active_profiles_profile_owner_fkey
    foreign key(profile_id,user_id) references public.profiles(id,user_id) on delete cascade
);
alter table private.account_session_active_profiles enable row level security;
alter table private.account_session_active_profiles force row level security;
revoke all on table private.account_session_active_profiles from public,anon,authenticated,service_role;
create index if not exists account_session_active_profiles_user_id_idx on private.account_session_active_profiles(user_id);
create index if not exists account_session_active_profiles_profile_id_idx on private.account_session_active_profiles(profile_id);

create or replace function private.current_auth_session_id()
returns uuid language plpgsql stable security invoker set search_path=''
as $function$
declare raw text;
begin
  raw:=auth.jwt()->>'session_id';
  if raw is null or raw='' then return null; end if;
  begin return raw::uuid; exception when invalid_text_representation then return null; end;
end
$function$;
revoke all on function private.current_auth_session_id() from public,anon,authenticated,service_role;

create or replace function public.enforce_profile_owner_immutable()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'Profile owner is immutable' using errcode='23514';
  end if;
  return new;
end
$function$;
revoke all on function public.enforce_profile_owner_immutable() from public,anon,authenticated,service_role;
drop trigger if exists profiles_owner_immutable on public.profiles;
create trigger profiles_owner_immutable before update of user_id on public.profiles
for each row execute function public.enforce_profile_owner_immutable();

create or replace function public.enforce_profile_cap()
returns trigger language plpgsql security definer set search_path=''
as $function$
declare existing_count integer;
begin
  perform 1 from public.users u where u.id=new.user_id for update;
  if not found then raise exception 'Profile owner account does not exist' using errcode='23503'; end if;
  select count(*) into existing_count from public.profiles p where p.user_id=new.user_id;
  if existing_count>=5 then raise exception 'Profile limit reached' using errcode='23514'; end if;
  return new;
end
$function$;
revoke all on function public.enforce_profile_cap() from public,anon,authenticated,service_role;
drop trigger if exists profiles_five_cap on public.profiles;
create trigger profiles_five_cap before insert on public.profiles
for each row execute function public.enforce_profile_cap();

-- Already exists live; this form is intentionally non-unique and rerun-safe.
create index if not exists idx_profiles_user_id on public.profiles(user_id);

create or replace function public.get_active_profile()
returns table(id uuid,type public.profile_type,handle text,display_name text,bio text,avatar_url text,header_url text,location text,social_links jsonb,is_creator boolean,is_verified boolean,created_at timestamptz,is_suspended boolean,updated_at timestamptz)
language plpgsql volatile security definer set search_path=''
as $function$
declare uid uuid:=auth.uid(); sid uuid; selected uuid;
begin
  if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  sid:=private.current_auth_session_id();
  if sid is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
  perform 1 from public.users u where u.id=uid for update;
  if not found then raise exception 'Account invariant missing' using errcode='42501'; end if;
  if exists(select 1 from public.users u where u.id=uid and u.banned_at is not null) then raise exception 'Banned accounts cannot select an active profile' using errcode='42501'; end if;
  select a.profile_id into selected from private.account_session_active_profiles a join public.profiles p on p.id=a.profile_id and p.user_id=a.user_id where a.session_id=sid and a.user_id=uid;
  if selected is null then
    select p.id into selected from public.profiles p where p.user_id=uid order by p.created_at,p.id limit 1;
    if selected is null then raise exception 'No owned profile available' using errcode='55000'; end if;
    insert into private.account_session_active_profiles(session_id,user_id,profile_id) values(sid,uid,selected)
    on conflict(session_id) do update set user_id=excluded.user_id,profile_id=excluded.profile_id,updated_at=now();
  end if;
  return query select p.id,p.type,p.handle,p.display_name,p.bio,p.avatar_url,p.header_url,p.location,p.social_links,p.is_creator,p.is_verified,p.created_at,p.is_suspended,p.updated_at from public.profiles p where p.id=selected and p.user_id=uid;
end
$function$;

create or replace function public.switch_active_profile(target_profile_id uuid)
returns table(id uuid,type public.profile_type,handle text,display_name text,bio text,avatar_url text,header_url text,location text,social_links jsonb,is_creator boolean,is_verified boolean,created_at timestamptz,is_suspended boolean,updated_at timestamptz)
language plpgsql volatile security definer set search_path=''
as $function$
declare uid uuid:=auth.uid(); sid uuid;
begin
  if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  sid:=private.current_auth_session_id();
  if sid is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
  perform 1 from public.users u where u.id=uid for update;
  if not found then raise exception 'Account invariant missing' using errcode='42501'; end if;
  if exists(select 1 from public.users u where u.id=uid and u.banned_at is not null) then raise exception 'Banned accounts cannot switch profiles' using errcode='42501'; end if;
  if not exists(select 1 from public.profiles p where p.id=target_profile_id and p.user_id=uid) then raise exception 'Profile is not owned by caller' using errcode='42501'; end if;
  insert into private.account_session_active_profiles(session_id,user_id,profile_id) values(sid,uid,target_profile_id)
  on conflict(session_id) do update set user_id=excluded.user_id,profile_id=excluded.profile_id,updated_at=now();
  return query select p.id,p.type,p.handle,p.display_name,p.bio,p.avatar_url,p.header_url,p.location,p.social_links,p.is_creator,p.is_verified,p.created_at,p.is_suspended,p.updated_at from public.profiles p where p.id=target_profile_id and p.user_id=uid;
end
$function$;

create or replace function public.create_additional_profile(new_handle text,new_display_name text,new_type public.profile_type)
returns table(id uuid,type public.profile_type,handle text,display_name text,bio text,avatar_url text,header_url text,location text,social_links jsonb,is_creator boolean,is_verified boolean,created_at timestamptz,is_suspended boolean,updated_at timestamptz)
language plpgsql volatile security definer set search_path=''
as $function$
declare
  uid uuid:=auth.uid();
  sid uuid;
  created_profile public.profiles%rowtype;
begin
  if uid is null then raise exception 'Authentication required' using errcode='42501'; end if;
  sid:=private.current_auth_session_id();
  if sid is null then raise exception 'Authenticated session required' using errcode='42501'; end if;
  perform 1 from public.users u where u.id=uid and u.banned_at is null for update;
  if not found then raise exception 'Account cannot create profiles' using errcode='42501'; end if;
  if pg_catalog.to_regclass('public.profiles_one_per_user_key') is not null then
    raise exception 'Additional profile creation is not enabled' using errcode='42501';
  end if;
  if new_display_name is null or char_length(btrim(new_display_name)) not between 1 and 100 then
    raise exception 'Display name must contain 1-100 characters' using errcode='23514';
  end if;
  insert into public.profiles(user_id,type,handle,display_name)
  values(uid,new_type,new_handle,btrim(new_display_name)) returning * into created_profile;
  insert into private.account_session_active_profiles(session_id,user_id,profile_id)
  values(sid,uid,created_profile.id)
  on conflict(session_id) do update set user_id=excluded.user_id,profile_id=excluded.profile_id,updated_at=now();
  return query select created_profile.id,created_profile.type,created_profile.handle,
    created_profile.display_name,created_profile.bio,created_profile.avatar_url,
    created_profile.header_url,created_profile.location,created_profile.social_links,
    created_profile.is_creator,created_profile.is_verified,created_profile.created_at,
    created_profile.is_suspended,created_profile.updated_at;
end
$function$;

alter function public.get_active_profile() owner to postgres;
alter function public.switch_active_profile(uuid) owner to postgres;
alter function public.create_additional_profile(text,text,public.profile_type) owner to postgres;
revoke all on function public.get_active_profile() from public,anon,service_role;
revoke all on function public.switch_active_profile(uuid) from public,anon,service_role;
grant execute on function public.get_active_profile() to authenticated;
grant execute on function public.switch_active_profile(uuid) to authenticated;
revoke all on function public.create_additional_profile(text,text,public.profile_type) from public,anon,authenticated,service_role;

-- Postconditions before commit.
do $post$
begin
  if pg_catalog.to_regclass('public.profiles_one_per_user_key') is null then raise exception 'MP-3 postcondition: one-profile guard missing'; end if;
  if has_function_privilege('anon','public.create_additional_profile(text,text,public.profile_type)','EXECUTE') or has_function_privilege('authenticated','public.create_additional_profile(text,text,public.profile_type)','EXECUTE') or has_function_privilege('service_role','public.create_additional_profile(text,text,public.profile_type)','EXECUTE') then raise exception 'MP-3 postcondition: creation RPC exposed'; end if;
  if has_table_privilege('anon','private.account_session_active_profiles','SELECT') or has_table_privilege('authenticated','private.account_session_active_profiles','SELECT') or has_table_privilege('service_role','private.account_session_active_profiles','SELECT') then raise exception 'MP-3 postcondition: private state exposed'; end if;
  if has_column_privilege('anon','public.profiles','user_id','SELECT') or has_column_privilege('authenticated','public.profiles','user_id','SELECT') then raise exception 'MP-3 postcondition: Package D privacy regressed'; end if;
end
$post$;
commit;
