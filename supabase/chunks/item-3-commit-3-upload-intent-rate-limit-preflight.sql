-- psy.market Item 3 / Commit 3
-- READ-ONLY PREFLIGHT: shared upload-intent rolling-window rate limiter
--
-- Package applied by the owner on 2026-08-02.
-- Preflight result: all_preflight_checks_pass = true.
-- Post-apply verification result: all_checks_pass = true.
-- Run in Supabase SQL Editor before the apply SQL.
-- Expected: exactly one row with all_preflight_checks_pass = true.
-- This transaction performs no writes.

begin transaction isolation level repeatable read read only;

with
objects as (
  select
    to_regclass('public.upload_intent_rate_limits') as table_oid,
    to_regprocedure(
      'public.consume_upload_intent_rate_limit(uuid)'
    ) as function_oid,
    to_regclass('auth.users') as auth_users_oid
),
role_state as (
  select
    count(*) filter (where rolname = 'anon') = 1 as anon_role_exists,
    count(*) filter (where rolname = 'authenticated') = 1
      as authenticated_role_exists,
    count(*) filter (where rolname = 'service_role') = 1
      as service_role_exists,
    count(*) filter (
      where rolname = 'postgres'
        and not rolsuper
        and rolbypassrls
    ) = 1 as postgres_is_expected_bypassrls_owner
  from pg_roles
  where rolname in ('anon', 'authenticated', 'service_role', 'postgres')
),
function_state as (
  select
    o.function_oid,
    (
      select count(*)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'consume_upload_intent_rate_limit'
    ) as same_name_function_count,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'grantee', case
            when a.grantee = 0 then 'PUBLIC'
            else pg_get_userbyid(a.grantee)
          end,
          'privilege', a.privilege_type
        )
        order by a.grantee, a.privilege_type
      )
      from pg_proc p
      cross join lateral aclexplode(
        coalesce(p.proacl, acldefault('f', p.proowner))
      ) a
      where p.oid = o.function_oid
    ), '[]'::jsonb) as existing_function_acl
  from objects o
),
table_state as (
  select
    o.table_oid,
    coalesce((
      select jsonb_build_object(
        'owner', pg_get_userbyid(c.relowner),
        'rls_enabled', c.relrowsecurity,
        'rls_forced', c.relforcerowsecurity,
        'relkind', c.relkind
      )
      from pg_class c
      where c.oid = o.table_oid
    ), '{}'::jsonb) as existing_table_state,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'grantee', case
            when a.grantee = 0 then 'PUBLIC'
            else pg_get_userbyid(a.grantee)
          end,
          'privilege', a.privilege_type
        )
        order by a.grantee, a.privilege_type
      )
      from pg_class c
      cross join lateral aclexplode(
        coalesce(c.relacl, acldefault('r', c.relowner))
      ) a
      where c.oid = o.table_oid
    ), '[]'::jsonb) as existing_table_acl,
    (
      select count(*)
      from pg_policy p
      where p.polrelid = o.table_oid
    ) as existing_policy_count
  from objects o
),
auth_users_state as (
  select
    o.auth_users_oid is not null as auth_users_exists,
    coalesce((
      select
        a.atttypid = 'uuid'::regtype
        and a.attnotnull
        and exists (
          select 1
          from pg_constraint c
          where c.conrelid = o.auth_users_oid
            and c.contype in ('p', 'u')
            and c.convalidated
            and c.conkey = array[a.attnum]::smallint[]
        )
      from pg_attribute a
      where a.attrelid = o.auth_users_oid
        and a.attname = 'id'
        and a.attnum > 0
        and not a.attisdropped
    ), false) as auth_users_id_is_unique_nonnull_uuid
  from objects o
),
checks as (
  select
    current_user as executing_role,
    session_user as session_role,
    o.table_oid is not null as limiter_table_exists,
    o.function_oid is not null as limiter_function_exists,
    fs.same_name_function_count,
    ts.existing_policy_count,
    ts.existing_table_state,
    ts.existing_table_acl,
    fs.existing_function_acl,
    au.auth_users_exists,
    au.auth_users_id_is_unique_nonnull_uuid,
    rs.anon_role_exists,
    rs.authenticated_role_exists,
    rs.service_role_exists,
    rs.postgres_is_expected_bypassrls_owner
  from objects o
  cross join role_state rs
  cross join function_state fs
  cross join table_state ts
  cross join auth_users_state au
)
select
  checks.*,
  (
    executing_role = 'postgres'
    and not limiter_table_exists
    and not limiter_function_exists
    and same_name_function_count = 0
    and existing_policy_count = 0
    and auth_users_exists
    and auth_users_id_is_unique_nonnull_uuid
    and anon_role_exists
    and authenticated_role_exists
    and service_role_exists
    and postgres_is_expected_bypassrls_owner
  ) as all_preflight_checks_pass
from checks;

rollback;
