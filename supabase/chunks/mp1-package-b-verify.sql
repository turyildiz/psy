-- psy.market MP-1 Package B
-- READ-ONLY POST-APPLY VERIFY — OWNER-RUN ONLY.
--
-- This verifier performs no DDL or DML. It uses transaction-local JWT/role
-- context only, ACTUALLY CALLS all three helpers, checks positive and negative
-- behavior, then ROLLBACK clears every local setting. No owner UUID is output.

begin transaction read only;
set local row_security = on;

-- Owner-only fixture setup. Values are stored in transaction-local settings and
-- are never selected into a result set.
do $fixture_setup$
declare
  ordinary_user_id uuid;
  ordinary_profile_id uuid;
  ordinary_profile_count bigint;
  ordinary_profile_ids uuid[];
  ordinary_profiles_md5 text;
  unrelated_profile_id uuid;
  admin_user_id uuid;
  admin_profile_id uuid;
  admin_profile_count bigint;
  admin_profile_ids uuid[];
  admin_profiles_md5 text;
  target_account_profile_count bigint;
  target_account_profile_ids uuid[];
  target_account_profiles_md5 text;
  unknown_profile_id uuid := '00000000-0000-0000-0000-000000000000';
begin
  if current_user <> 'postgres' or session_user <> 'postgres' then
    raise exception 'Package B verify requires project-owner context';
  end if;

  select p.user_id, p.id
  into ordinary_user_id, ordinary_profile_id
  from public.profiles p
  join public.users u on u.id = p.user_id
  where u.banned_at is null
    and u.role::text not in ('admin', 'super_admin')
  order by p.created_at, p.id
  limit 1;

  if ordinary_user_id is null or ordinary_profile_id is null then
    raise exception 'Package B verify fixture unavailable: active non-admin profile owner';
  end if;

  select count(*), array_agg(x.id order by x.created_at, x.id),
    md5(string_agg(to_jsonb(x)::text, E'\n'
      order by x.created_at, x.id))
  into ordinary_profile_count, ordinary_profile_ids, ordinary_profiles_md5
  from (
    select p.id, p.type, p.handle, p.display_name, p.bio, p.avatar_url,
      p.header_url, p.location, p.social_links, p.is_creator,
      p.is_verified, p.created_at, p.is_suspended, p.updated_at
    from public.profiles p
    where p.user_id = ordinary_user_id
  ) x;

  select p.id
  into unrelated_profile_id
  from public.profiles p
  where p.user_id <> ordinary_user_id
  order by p.created_at, p.id
  limit 1;

  if unrelated_profile_id is null then
    raise exception 'Package B verify fixture unavailable: unrelated profile';
  end if;

  select u.id, p.id
  into admin_user_id, admin_profile_id
  from public.users u
  join public.profiles p on p.user_id = u.id
  where u.banned_at is null
    and u.role::text in ('admin', 'super_admin')
  order by case when u.role::text = 'super_admin' then 0 else 1 end,
    p.created_at, p.id
  limit 1;

  if admin_user_id is null or admin_profile_id is null then
    raise exception 'Package B verify fixture unavailable: active admin profile owner';
  end if;

  select count(*), array_agg(x.id order by x.created_at, x.id),
    md5(string_agg(to_jsonb(x)::text, E'\n'
      order by x.created_at, x.id))
  into admin_profile_count, admin_profile_ids, admin_profiles_md5
  from (
    select p.id, p.type, p.handle, p.display_name, p.bio, p.avatar_url,
      p.header_url, p.location, p.social_links, p.is_creator,
      p.is_verified, p.created_at, p.is_suspended, p.updated_at
    from public.profiles p
    where p.user_id = admin_user_id
  ) x;

  select count(*), array_agg(x.profile_id order by x.created_at, x.profile_id),
    md5(string_agg(to_jsonb(x)::text, E'\n'
      order by x.created_at, x.profile_id))
  into target_account_profile_count, target_account_profile_ids,
    target_account_profiles_md5
  from (
    select p.user_id as account_user_id, p.id as profile_id, p.handle,
      p.display_name, p.type, p.is_suspended, p.created_at
    from public.profiles p
    where p.user_id = ordinary_user_id
  ) x;

  if exists (select 1 from public.profiles p where p.id = unknown_profile_id) then
    raise exception 'Package B verify fixture invalid: all-zero profile UUID exists';
  end if;

  perform pg_catalog.set_config(
    'mp1.package_b.ordinary_user_id', ordinary_user_id::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.ordinary_profile_id', ordinary_profile_id::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.ordinary_profile_count', ordinary_profile_count::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.ordinary_profile_ids', ordinary_profile_ids::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.ordinary_profiles_md5', ordinary_profiles_md5, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.unrelated_profile_id', unrelated_profile_id::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.unknown_profile_id', unknown_profile_id::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.admin_user_id', admin_user_id::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.admin_profile_id', admin_profile_id::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.admin_profile_count', admin_profile_count::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.admin_profile_ids', admin_profile_ids::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.admin_profiles_md5', admin_profiles_md5, true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.target_account_profile_count',
    target_account_profile_count::text,
    true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.target_account_profile_ids',
    target_account_profile_ids::text,
    true
  );
  perform pg_catalog.set_config(
    'mp1.package_b.target_account_profiles_md5',
    target_account_profiles_md5,
    true
  );

  perform pg_catalog.set_config(
    'request.jwt.claim.sub', ordinary_user_id::text, true
  );
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', ordinary_user_id::text,
      'role', 'authenticated',
      'aud', 'authenticated'
    )::text,
    true
  );
end;
$fixture_setup$;

set local role authenticated;

-- Ordinary authenticated success paths plus the admin helper's internal denial.
do $ordinary_calls$
declare
  actual_profile_count bigint;
  actual_profile_ids uuid[];
  actual_profiles_md5 text;
  expected_profile_count bigint := pg_catalog.current_setting(
    'mp1.package_b.ordinary_profile_count'
  )::bigint;
  expected_profile_ids uuid[] := pg_catalog.current_setting(
    'mp1.package_b.ordinary_profile_ids'
  )::uuid[];
  expected_profiles_md5 text := pg_catalog.current_setting(
    'mp1.package_b.ordinary_profiles_md5'
  );
  owns_expected_profile boolean;
  owns_unrelated_profile boolean;
  owns_unknown_profile boolean;
  owns_null_profile boolean;
  admin_denied boolean := false;
  denied_state text;
  denied_message text;
begin
  select count(*), array_agg(r.id),
    md5(string_agg(to_jsonb(r)::text, E'\n'
      order by r.created_at, r.id))
  into actual_profile_count, actual_profile_ids, actual_profiles_md5
  from public.get_my_profiles() r;

  if actual_profile_count <> expected_profile_count
     or actual_profile_ids is distinct from expected_profile_ids
     or actual_profiles_md5 is distinct from expected_profiles_md5 then
    raise exception 'Package B verify failed: get_my_profiles exact result/order';
  end if;

  select public.current_user_owns_profile(
    pg_catalog.current_setting('mp1.package_b.ordinary_profile_id')::uuid
  ) into owns_expected_profile;

  select public.current_user_owns_profile(
    pg_catalog.current_setting('mp1.package_b.unrelated_profile_id')::uuid
  ) into owns_unrelated_profile;

  select public.current_user_owns_profile(
    pg_catalog.current_setting('mp1.package_b.unknown_profile_id')::uuid
  ) into owns_unknown_profile;

  select public.current_user_owns_profile(null::uuid)
  into owns_null_profile;

  if owns_expected_profile is distinct from true
     or owns_unrelated_profile is distinct from false
     or owns_unknown_profile is distinct from false
     or owns_null_profile is distinct from false then
    raise exception 'Package B verify failed: ownership boolean behavior';
  end if;

  begin
    perform *
    from public.admin_get_profile_account(
      pg_catalog.current_setting('mp1.package_b.ordinary_profile_id')::uuid
    );
  exception
    when others then
      get stacked diagnostics
        denied_state = returned_sqlstate,
        denied_message = message_text;
      admin_denied := denied_state = '42501'
        and denied_message = 'Admin access required';
  end;

  if not admin_denied then
    raise exception 'Package B verify failed: ordinary caller admin denial contract';
  end if;
end;
$ordinary_calls$;

reset role;

-- Switch only transaction-local JWT claims, then exercise the admin success path.
do $admin_fixture$
declare
  admin_user_id uuid := pg_catalog.current_setting(
    'mp1.package_b.admin_user_id'
  )::uuid;
begin
  perform pg_catalog.set_config(
    'request.jwt.claim.sub', admin_user_id::text, true
  );
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', admin_user_id::text,
      'role', 'authenticated',
      'aud', 'authenticated'
    )::text,
    true
  );
end;
$admin_fixture$;

set local role authenticated;

do $admin_calls$
declare
  target_profile_id uuid := pg_catalog.current_setting(
    'mp1.package_b.ordinary_profile_id'
  )::uuid;
  target_account_user_id uuid := pg_catalog.current_setting(
    'mp1.package_b.ordinary_user_id'
  )::uuid;
  expected_count bigint := pg_catalog.current_setting(
    'mp1.package_b.target_account_profile_count'
  )::bigint;
  expected_group_ids uuid[] := pg_catalog.current_setting(
    'mp1.package_b.target_account_profile_ids'
  )::uuid[];
  expected_group_md5 text := pg_catalog.current_setting(
    'mp1.package_b.target_account_profiles_md5'
  );
  expected_owner_count bigint := pg_catalog.current_setting(
    'mp1.package_b.admin_profile_count'
  )::bigint;
  expected_owner_ids uuid[] := pg_catalog.current_setting(
    'mp1.package_b.admin_profile_ids'
  )::uuid[];
  expected_owner_md5 text := pg_catalog.current_setting(
    'mp1.package_b.admin_profiles_md5'
  );
  actual_owner_count bigint;
  actual_owner_ids uuid[];
  actual_owner_md5 text;
  owns_admin_profile boolean;
  owns_ordinary_profile boolean;
  owns_unknown_profile boolean;
  owns_null_profile boolean;
  actual_count bigint;
  actual_group_ids uuid[];
  actual_group_md5 text;
  missing_target_count bigint;
  all_rows_match_target boolean;
  target_row_present boolean;
begin
  select count(*), array_agg(r.id),
    md5(string_agg(to_jsonb(r)::text, E'\n'
      order by r.created_at, r.id))
  into actual_owner_count, actual_owner_ids, actual_owner_md5
  from public.get_my_profiles() r;

  if actual_owner_count <> expected_owner_count
     or actual_owner_ids is distinct from expected_owner_ids
     or actual_owner_md5 is distinct from expected_owner_md5 then
    raise exception 'Package B verify failed: admin owner-list semantics';
  end if;

  select public.current_user_owns_profile(
    pg_catalog.current_setting('mp1.package_b.admin_profile_id')::uuid
  ) into owns_admin_profile;
  select public.current_user_owns_profile(target_profile_id)
  into owns_ordinary_profile;
  select public.current_user_owns_profile(
    pg_catalog.current_setting('mp1.package_b.unknown_profile_id')::uuid
  ) into owns_unknown_profile;
  select public.current_user_owns_profile(null::uuid)
  into owns_null_profile;

  if owns_admin_profile is distinct from true
     or owns_ordinary_profile is distinct from false
     or owns_unknown_profile is distinct from false
     or owns_null_profile is distinct from false then
    raise exception 'Package B verify failed: admin ownership semantics';
  end if;

  select count(*), array_agg(r.profile_id),
    md5(string_agg(to_jsonb(r)::text, E'\n'
      order by r.created_at, r.profile_id)),
    coalesce(bool_and(r.account_user_id = target_account_user_id), false),
    coalesce(bool_or(r.profile_id = target_profile_id), false)
  into actual_count, actual_group_ids, actual_group_md5,
    all_rows_match_target, target_row_present
  from public.admin_get_profile_account(target_profile_id) r;

  if actual_count <> expected_count
     or actual_group_ids is distinct from expected_group_ids
     or actual_group_md5 is distinct from expected_group_md5
     or not all_rows_match_target
     or not target_row_present then
    raise exception 'Package B verify failed: admin grouping exact result/order';
  end if;

  select count(*)
  into missing_target_count
  from public.admin_get_profile_account(
    pg_catalog.current_setting('mp1.package_b.unknown_profile_id')::uuid
  );

  if missing_target_count <> 0 then
    raise exception 'Package B verify failed: admin missing-target behavior';
  end if;
end;
$admin_calls$;

reset role;

-- ACL denial paths are real calls under anon; each must fail before body access.
do $anon_fixture$
begin
  perform pg_catalog.set_config('request.jwt.claim.sub', '', true);
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object('role', 'anon')::text,
    true
  );
end;
$anon_fixture$;

set local role anon;

do $anon_calls$
declare
  get_denied boolean := false;
  owns_denied boolean := false;
  admin_denied boolean := false;
begin
  begin
    perform * from public.get_my_profiles();
  exception when insufficient_privilege then
    get_denied := true;
  end;

  begin
    perform public.current_user_owns_profile(null::uuid);
  exception when insufficient_privilege then
    owns_denied := true;
  end;

  begin
    perform * from public.admin_get_profile_account(null::uuid);
  exception when insufficient_privilege then
    admin_denied := true;
  end;

  if not get_denied or not owns_denied or not admin_denied then
    raise exception 'Package B verify failed: anon function ACL';
  end if;
end;
$anon_calls$;

reset role;

-- Clear every transaction-local JWT/role fixture before returning the summary.
rollback;

-- Final exportable result: exact catalog/ACL status. Runtime-call failures above
-- abort before this row; reaching it proves all positive/negative calls passed.
with function_state as (
  select p.oid, p.proname, p.proowner, p.prosecdef, p.provolatile,
    p.proparallel, p.prokind, p.proisstrict, p.proleakproof, p.proretset, p.prorettype,
    p.proargtypes, p.proallargtypes, p.proargmodes, p.proargnames,
    p.proconfig, l.lanname, p.prosrc
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_language l on l.oid = p.prolang
  where n.nspname = 'public'
    and p.proname in (
      'get_my_profiles',
      'current_user_owns_profile',
      'admin_get_profile_account'
    )
), shape_checks as (
  select
    (select count(*) from function_state) = 3 as exact_function_count,
    exists (
      select 1 from function_state p
      where p.oid = to_regprocedure('public.get_my_profiles()')
        and p.lanname = 'sql' and p.proowner = 'postgres'::regrole
        and p.prosecdef and p.provolatile = 's'
        and p.proparallel = 'u' and p.prokind = 'f' and p.proretset
        and md5(btrim(regexp_replace(p.prosrc, E'\\s+', ' ', 'g'))) =
          '068d419cf900e4bde1bd36b73433c2b3'
        and not p.proisstrict and not p.proleakproof
        and p.proconfig in (array['search_path=""'], array['search_path='])
        and p.proargnames = array[
          'id', 'type', 'handle', 'display_name', 'bio', 'avatar_url',
          'header_url', 'location', 'social_links', 'is_creator',
          'is_verified', 'created_at', 'is_suspended', 'updated_at'
        ]
        and p.proargmodes = array[
          't'::"char", 't'::"char", 't'::"char", 't'::"char",
          't'::"char", 't'::"char", 't'::"char", 't'::"char",
          't'::"char", 't'::"char", 't'::"char", 't'::"char",
          't'::"char", 't'::"char"
        ]
        and p.proallargtypes = array[
          'uuid'::regtype::oid, 'public.profile_type'::regtype::oid,
          'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
          'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
          'jsonb'::regtype::oid, 'boolean'::regtype::oid,
          'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid,
          'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid
        ]
    ) as owner_list_shape,
    exists (
      select 1 from function_state p
      where p.oid = to_regprocedure('public.current_user_owns_profile(uuid)')
        and p.lanname = 'sql' and p.proowner = 'postgres'::regrole
        and p.prosecdef and p.provolatile = 's'
        and p.proparallel = 'u' and p.prokind = 'f' and not p.proretset
        and md5(btrim(regexp_replace(p.prosrc, E'\\s+', ' ', 'g'))) =
          'b18b8e4f01df72097d092352423ab8af'
        and p.prorettype = 'boolean'::regtype
        and not p.proisstrict and not p.proleakproof
        and p.proconfig in (array['search_path=""'], array['search_path='])
        and p.proargnames = array['target_profile_id']
    ) as ownership_boolean_shape,
    exists (
      select 1 from function_state p
      where p.oid = to_regprocedure('public.admin_get_profile_account(uuid)')
        and p.lanname = 'plpgsql' and p.proowner = 'postgres'::regrole
        and p.prosecdef and p.provolatile = 's'
        and p.proparallel = 'u' and p.prokind = 'f' and p.proretset
        and md5(btrim(regexp_replace(p.prosrc, E'\\s+', ' ', 'g'))) =
          '1b1617031aa49512a692d706462e4f18'
        and not p.proisstrict and not p.proleakproof
        and p.proconfig in (array['search_path=""'], array['search_path='])
        and p.proargnames = array[
          'target_profile_id', 'account_user_id', 'profile_id', 'handle',
          'display_name', 'type', 'is_suspended', 'created_at'
        ]
        and p.proargmodes = array[
          'i'::"char", 't'::"char", 't'::"char", 't'::"char",
          't'::"char", 't'::"char", 't'::"char", 't'::"char"
        ]
        and p.proallargtypes = array[
          'uuid'::regtype::oid, 'uuid'::regtype::oid, 'uuid'::regtype::oid,
          'text'::regtype::oid, 'text'::regtype::oid,
          'public.profile_type'::regtype::oid, 'boolean'::regtype::oid,
          'timestamp with time zone'::regtype::oid
        ]
    ) as admin_grouping_shape
), actual_acl as (
  select p.proname as function_name,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type,
    acl.is_grantable,
    acl.grantor::regrole::text as grantor
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
), expected_acl(function_name, grantee, privilege_type, is_grantable, grantor) as (
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
), acl_check as (
  select not exists (
    (select * from actual_acl except select * from expected_acl)
    union all
    (select * from expected_acl except select * from actual_acl)
  )
  and not exists (
    select 1
    from function_state p
    where not has_function_privilege('authenticated', p.oid, 'EXECUTE')
      or has_function_privilege('anon', p.oid, 'EXECUTE')
      or has_function_privilege('service_role', p.oid, 'EXECUTE')
  ) as exact_acl
), profile_table_acl as (
  select acl.grantor::regrole::text as grantor,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type,
    acl.is_grantable
  from pg_class c
  cross join lateral aclexplode(
    coalesce(c.relacl, acldefault('r', c.relowner))
  ) acl
  where c.oid = to_regclass('public.profiles')
), expected_profile_table_acl as (
  select 'postgres'::text as grantor, r.grantee,
    p.privilege_type, false as is_grantable
  from (values ('postgres'::text), ('anon'), ('authenticated'),
               ('service_role')) r(grantee)
  cross join (values ('DELETE'::text), ('INSERT'), ('MAINTAIN'),
                     ('REFERENCES'), ('SELECT'), ('TRIGGER'),
                     ('TRUNCATE'), ('UPDATE')) p(privilege_type)
  union all
  select 'postgres', 'audit_readonly', 'SELECT', false
), existing_baseline_check as (
  select
    exists (
      select 1 from pg_index i
      where i.indexrelid = to_regclass('public.profiles_one_per_user_key')
        and i.indrelid = to_regclass('public.profiles')
        and i.indisunique and i.indisvalid and i.indisready
    )
    and not exists (
      (select * from profile_table_acl
       except select * from expected_profile_table_acl)
      union all
      (select * from expected_profile_table_acl
       except select * from profile_table_acl)
    ) as existing_baseline_unchanged
), final_check as (
  select s.exact_function_count and s.owner_list_shape
    and s.ownership_boolean_shape and s.admin_grouping_shape
    and a.exact_acl and b.existing_baseline_unchanged as all_checks_pass
  from shape_checks s
  cross join acl_check a
  cross join existing_baseline_check b
)
select
  case when all_checks_pass then 'GO' else 'STOP' end as overall_status,
  'GO'::text as runtime_calls_status,
  'GO'::text as anon_calls_status,
  'GO'::text as ordinary_owner_list_status,
  'GO'::text as ordinary_ownership_status,
  'GO'::text as ordinary_admin_denial_status,
  'GO'::text as admin_owner_list_status,
  'GO'::text as admin_ownership_status,
  'GO'::text as admin_grouping_status,
  'database_layer_only'::text as verification_scope,
  all_checks_pass as catalog_and_acl_checks_pass,
  array_remove(array[
    case when not all_checks_pass then 'package_b_catalog_or_acl_drift' end
  ], null) as findings
from final_check;
