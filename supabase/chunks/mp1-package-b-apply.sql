-- psy.market MP-1 Package B: additive private profile contracts
-- APPLY — OWNER-RUN ONLY; NOT EXECUTED BY THE REPOSITORY AGENT.
--
-- Scope is exactly three new functions. This transaction does not alter any
-- existing table, column, constraint, index, policy, trigger, function, grant,
-- publication, or profile-table privilege. Broad public.profiles access and
-- public.profiles_one_per_user_key remain unchanged.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Fail closed on a stale/mismatched dependency state and every same-name
-- overload. CREATE FUNCTION (not CREATE OR REPLACE) is used deliberately.
do $preconditions$
begin
  if current_database() <> 'postgres'
     or current_user <> 'postgres'
     or session_user <> 'postgres' then
    raise exception 'Package B precondition failed: project-owner context required';
  end if;

  if (select count(*)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in (
          'get_my_profiles',
          'current_user_owns_profile',
          'admin_get_profile_account'
        )) <> 0 then
    raise exception 'Package B precondition failed: helper name or overload already exists';
  end if;

  if to_regclass('public.profiles') is null
     or to_regtype('public.profile_type') is null
     or to_regprocedure('auth.uid()') is null
     or to_regprocedure('public.current_user_is_admin()') is null then
    raise exception 'Package B precondition failed: required dependency missing';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname = 'public'
      and p.proname = 'current_user_is_admin'
      and pg_get_function_identity_arguments(p.oid) = ''
      and pg_get_function_result(p.oid) = 'boolean'
      and l.lanname = 'sql'
      and p.provolatile = 's'
      and p.prosecdef
      and p.proowner = 'postgres'::regrole
  ) then
    raise exception 'Package B precondition failed: admin authorization helper drift';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.current_user_is_admin()', 'EXECUTE'
  ) then
    raise exception 'Package B precondition failed: authenticated cannot call admin authorization helper';
  end if;

  if not exists (
    select 1
    from pg_index i
    where i.indexrelid = to_regclass('public.profiles_one_per_user_key')
      and i.indrelid = to_regclass('public.profiles')
      and i.indisunique and i.indisvalid and i.indisready
      and i.indpred is null
      and pg_get_indexdef(i.indexrelid) =
        'CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)'
  ) then
    raise exception 'Package B precondition failed: one-profile guard drift';
  end if;

  if exists (
    with actual(grantor, grantee, privilege_type, is_grantable) as (
      select acl.grantor::regrole::text,
        case when acl.grantee = 0 then 'PUBLIC'
             else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable
      from pg_class c
      cross join lateral aclexplode(
        coalesce(c.relacl, acldefault('r', c.relowner))
      ) acl
      where c.oid = to_regclass('public.profiles')
    ), expected as (
      select 'postgres'::text, r.grantee, p.privilege_type, false
      from (values ('postgres'::text), ('anon'), ('authenticated'),
                   ('service_role')) r(grantee)
      cross join (values ('DELETE'::text), ('INSERT'), ('MAINTAIN'),
                         ('REFERENCES'), ('SELECT'), ('TRIGGER'),
                         ('TRUNCATE'), ('UPDATE')) p(privilege_type)
      union all
      select 'postgres', 'audit_readonly', 'SELECT', false
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Package B precondition failed: profiles table ACL drift';
  end if;
end;
$preconditions$;

-- SECURITY DEFINER is required here so this owner-only set contract continues
-- to read private owner/moderation columns after Package D revokes broad column
-- access. The caller is derived only from auth.uid(); user_id is never returned.
create function public.get_my_profiles()
returns table (
  id uuid,
  type public.profile_type,
  handle text,
  display_name text,
  bio text,
  avatar_url text,
  header_url text,
  location text,
  social_links jsonb,
  is_creator boolean,
  is_verified boolean,
  created_at timestamp with time zone,
  is_suspended boolean,
  updated_at timestamp with time zone
)
language sql
stable
security definer
set search_path = ''
as $function$
  with caller as (
    select auth.uid() as account_user_id
  )
  select
    p.id,
    p.type,
    p.handle,
    p.display_name,
    p.bio,
    p.avatar_url,
    p.header_url,
    p.location,
    p.social_links,
    p.is_creator,
    p.is_verified,
    p.created_at,
    p.is_suspended,
    p.updated_at
  from public.profiles p
  cross join caller c
  where c.account_user_id is not null
    and p.user_id = c.account_user_id
  order by p.created_at, p.id;
$function$;

-- SECURITY DEFINER is required so this boolean remains usable after user_id is
-- private. Both a nonexistent profile and another account's profile return
-- false; no owner identifier is exposed.
create function public.current_user_owns_profile(
  target_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  with caller as (
    select auth.uid() as account_user_id
  )
  select coalesce(
    (
      select exists (
        select 1
        from public.profiles p
        where p.id = target_profile_id
          and p.user_id = c.account_user_id
      )
      from caller c
      where c.account_user_id is not null
    ),
    false
  );
$function$;

-- SECURITY DEFINER is required for deliberate admin-only account grouping after
-- owner columns become private. ACL restriction is defense in depth; active
-- admin authorization is repeated internally before any owner ID can be read.
create function public.admin_get_profile_account(
  target_profile_id uuid
)
returns table (
  account_user_id uuid,
  profile_id uuid,
  handle text,
  display_name text,
  type public.profile_type,
  is_suspended boolean,
  created_at timestamp with time zone
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.current_user_is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  return query
  with target_account as (
    select target.user_id as account_user_id
    from public.profiles target
    where target.id = target_profile_id
  )
  select
    siblings.user_id as account_user_id,
    siblings.id as profile_id,
    siblings.handle,
    siblings.display_name,
    siblings.type,
    siblings.is_suspended,
    siblings.created_at
  from target_account target
  join public.profiles siblings
    on siblings.user_id = target.account_user_id
  order by siblings.created_at, siblings.id;
end;
$function$;

alter function public.get_my_profiles() owner to postgres;
alter function public.current_user_owns_profile(uuid) owner to postgres;
alter function public.admin_get_profile_account(uuid) owner to postgres;

comment on function public.get_my_profiles() is
  'Private owner profile set; derives caller from auth.uid() and never returns user_id.';
comment on function public.current_user_owns_profile(uuid) is
  'Private ownership boolean; never returns an owner identifier.';
comment on function public.admin_get_profile_account(uuid) is
  'Private active-admin account/profile grouping contract.';

-- PostgreSQL and Supabase function defaults can grant EXECUTE broadly. Revoke
-- every known default API path explicitly, then grant only authenticated.
revoke all on function public.get_my_profiles()
  from public, anon, authenticated, service_role;
revoke all on function public.current_user_owns_profile(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_get_profile_account(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.get_my_profiles() to authenticated;
grant execute on function public.current_user_owns_profile(uuid) to authenticated;
grant execute on function public.admin_get_profile_account(uuid) to authenticated;

-- Exact additive postconditions. No existing object is repaired automatically.
do $postconditions$
begin
  if (select count(*)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in (
          'get_my_profiles',
          'current_user_owns_profile',
          'admin_get_profile_account'
        )) <> 3 then
    raise exception 'Package B postcondition failed: function/overload count';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where p.oid = to_regprocedure('public.get_my_profiles()')
      and n.nspname = 'public'
      and l.lanname = 'sql'
      and p.proowner = 'postgres'::regrole
      and p.provolatile = 's' and p.proparallel = 'u' and p.prokind = 'f'
      and p.prosecdef and not p.proisstrict and not p.proleakproof
      and p.proretset
      and p.proconfig in (array['search_path=""'], array['search_path='])
      and p.proargtypes = ''::oidvector
      and p.proargmodes = array[
        't'::"char", 't'::"char", 't'::"char", 't'::"char",
        't'::"char", 't'::"char", 't'::"char", 't'::"char",
        't'::"char", 't'::"char", 't'::"char", 't'::"char",
        't'::"char", 't'::"char"
      ]
      and p.proargnames = array[
        'id', 'type', 'handle', 'display_name', 'bio', 'avatar_url',
        'header_url', 'location', 'social_links', 'is_creator',
        'is_verified', 'created_at', 'is_suspended', 'updated_at'
      ]
      and p.proallargtypes = array[
        'uuid'::regtype::oid, 'public.profile_type'::regtype::oid,
        'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
        'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
        'jsonb'::regtype::oid, 'boolean'::regtype::oid,
        'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid,
        'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid
      ]
  ) then
    raise exception 'Package B postcondition failed: get_my_profiles shape';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    where p.oid = to_regprocedure('public.current_user_owns_profile(uuid)')
      and l.lanname = 'sql'
      and p.proowner = 'postgres'::regrole
      and p.provolatile = 's' and p.proparallel = 'u' and p.prokind = 'f'
      and p.prosecdef and not p.proisstrict and not p.proleakproof
      and not p.proretset and p.prorettype = 'boolean'::regtype
      and p.proconfig in (array['search_path=""'], array['search_path='])
      and p.proargnames = array['target_profile_id']
  ) then
    raise exception 'Package B postcondition failed: ownership boolean shape';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    where p.oid = to_regprocedure('public.admin_get_profile_account(uuid)')
      and l.lanname = 'plpgsql'
      and p.proowner = 'postgres'::regrole
      and p.provolatile = 's' and p.proparallel = 'u' and p.prokind = 'f'
      and p.prosecdef and not p.proisstrict and not p.proleakproof
      and p.proretset
      and p.proconfig in (array['search_path=""'], array['search_path='])
      and p.proargmodes = array[
        'i'::"char", 't'::"char", 't'::"char", 't'::"char",
        't'::"char", 't'::"char", 't'::"char", 't'::"char"
      ]
      and p.proargnames = array[
        'target_profile_id', 'account_user_id', 'profile_id', 'handle',
        'display_name', 'type', 'is_suspended', 'created_at'
      ]
      and p.proallargtypes = array[
        'uuid'::regtype::oid, 'uuid'::regtype::oid, 'uuid'::regtype::oid,
        'text'::regtype::oid, 'text'::regtype::oid,
        'public.profile_type'::regtype::oid, 'boolean'::regtype::oid,
        'timestamp with time zone'::regtype::oid
      ]
  ) then
    raise exception 'Package B postcondition failed: admin grouping shape';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'get_my_profiles',
        'current_user_owns_profile',
        'admin_get_profile_account'
      )
      and md5(btrim(regexp_replace(p.prosrc, E'\\s+', ' ', 'g'))) <>
        case p.proname
          when 'get_my_profiles' then '068d419cf900e4bde1bd36b73433c2b3'
          when 'current_user_owns_profile' then 'b18b8e4f01df72097d092352423ab8af'
          when 'admin_get_profile_account' then '1b1617031aa49512a692d706462e4f18'
        end
  ) then
    raise exception 'Package B postcondition failed: normalized function body drift';
  end if;

  if exists (
    with actual(function_name, grantee, privilege_type, is_grantable, grantor) as (
      select p.proname,
        case when acl.grantee = 0 then 'PUBLIC'
             else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable,
        acl.grantor::regrole::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral aclexplode(
        coalesce(p.proacl, acldefault('f', p.proowner))
      ) acl
      where n.nspname = 'public'
        and p.proname in (
          'get_my_profiles',
          'current_user_owns_profile',
          'admin_get_profile_account'
        )
    ), expected as (
      values
        ('get_my_profiles'::name, 'postgres'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('get_my_profiles'::name, 'authenticated'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('current_user_owns_profile'::name, 'postgres'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('current_user_owns_profile'::name, 'authenticated'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('admin_get_profile_account'::name, 'postgres'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('admin_get_profile_account'::name, 'authenticated'::text, 'EXECUTE'::text,
          false, 'postgres'::text)
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Package B postcondition failed: function ACL drift';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'get_my_profiles',
        'current_user_owns_profile',
        'admin_get_profile_account'
      )
      and (
        not has_function_privilege('authenticated', p.oid, 'EXECUTE')
        or has_function_privilege('anon', p.oid, 'EXECUTE')
        or has_function_privilege('service_role', p.oid, 'EXECUTE')
      )
  ) then
    raise exception 'Package B postcondition failed: effective function ACL drift';
  end if;

  if not exists (
    select 1 from pg_index i
    where i.indexrelid = to_regclass('public.profiles_one_per_user_key')
      and i.indisunique and i.indisvalid and i.indisready
  ) then
    raise exception 'Package B postcondition failed: one-profile guard changed';
  end if;

  if exists (
    with actual(grantor, grantee, privilege_type, is_grantable) as (
      select acl.grantor::regrole::text,
        case when acl.grantee = 0 then 'PUBLIC'
             else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable
      from pg_class c
      cross join lateral aclexplode(
        coalesce(c.relacl, acldefault('r', c.relowner))
      ) acl
      where c.oid = to_regclass('public.profiles')
    ), expected as (
      select 'postgres'::text, r.grantee, p.privilege_type, false
      from (values ('postgres'::text), ('anon'), ('authenticated'),
                   ('service_role')) r(grantee)
      cross join (values ('DELETE'::text), ('INSERT'), ('MAINTAIN'),
                         ('REFERENCES'), ('SELECT'), ('TRIGGER'),
                         ('TRUNCATE'), ('UPDATE')) p(privilege_type)
      union all
      select 'postgres', 'audit_readonly', 'SELECT', false
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Package B postcondition failed: profiles table ACL changed';
  end if;
end;
$postconditions$;

commit;
