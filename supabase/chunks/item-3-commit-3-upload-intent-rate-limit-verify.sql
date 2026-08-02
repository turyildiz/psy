-- psy.market Item 3 / Commit 3
-- READ-ONLY POST-APPLY VERIFICATION
--
-- Package applied by the owner on 2026-08-02.
-- Preflight result: all_preflight_checks_pass = true.
-- Post-apply verification result: all_checks_pass = true.
-- Run only after the apply SQL succeeds in Supabase SQL Editor.
-- Expected: exactly one row with all_checks_pass = true.
-- This transaction performs no writes and does not consume quota.

begin transaction isolation level repeatable read read only;

with
objects as (
  select
    to_regclass('public.upload_intent_rate_limits') as table_oid,
    to_regprocedure(
      'public.consume_upload_intent_rate_limit(uuid)'
    ) as function_oid
),
table_checks as (
  select
    o.table_oid is not null as table_exists,
    coalesce((
      select
        c.relkind = 'r'
        and c.relowner = 'postgres'::regrole
        and c.relrowsecurity
        and c.relforcerowsecurity
      from pg_class c
      where c.oid = o.table_oid
    ), false) as table_owner_and_rls_correct,
    (
      select count(*)
      from pg_policy p
      where p.polrelid = o.table_oid
    ) = 0 as table_has_no_policies,
    not exists (
      select 1
      from pg_class c
      cross join lateral aclexplode(
        coalesce(c.relacl, acldefault('r', c.relowner))
      ) a
      where c.oid = o.table_oid
        and a.privilege_type in (
          'SELECT', 'INSERT', 'UPDATE', 'DELETE',
          'TRUNCATE', 'REFERENCES', 'TRIGGER'
        )
        and a.grantee in (
          0::oid,
          'anon'::regrole,
          'authenticated'::regrole,
          'service_role'::regrole
        )
    ) as no_direct_api_table_grants,
    coalesce((
      select count(*) = 3
      from pg_attribute a
      where a.attrelid = o.table_oid
        and a.attnum > 0
        and not a.attisdropped
        and (
          (a.attname = 'user_id'
            and a.atttypid = 'uuid'::regtype
            and a.attnotnull)
          or (a.attname = 'attempts'
            and a.atttypid = 'timestamp with time zone[]'::regtype
            and a.attnotnull)
          or (a.attname = 'updated_at'
            and a.atttypid = 'timestamp with time zone'::regtype
            and a.attnotnull)
        )
    ), false) as exact_columns,
    coalesce((
      select
        count(*) filter (
          where c.conname = 'upload_intent_rate_limits_pkey'
            and c.contype = 'p'
            and c.convalidated
        ) = 1
        and count(*) filter (
          where c.conname = 'upload_intent_rate_limits_user_id_fkey'
            and c.contype = 'f'
            and c.convalidated
            and c.confrelid = 'auth.users'::regclass
            and c.confdeltype = 'c'
        ) = 1
        and count(*) filter (
          where c.conname = 'upload_intent_rate_limits_attempt_count_check'
            and c.contype = 'c'
            and c.convalidated
        ) = 1
        and count(*) filter (
          where c.conname = 'upload_intent_rate_limits_attempts_no_null_check'
            and c.contype = 'c'
            and c.convalidated
        ) = 1
      from pg_constraint c
      where c.conrelid = o.table_oid
    ), false) as exact_constraints
  from objects o
),
function_checks as (
  select
    o.function_oid is not null as function_exists,
    coalesce((
      select
        p.proowner = 'postgres'::regrole
        and p.prosecdef
        and p.provolatile = 'v'
        and l.lanname = 'plpgsql'
        and pg_get_function_result(p.oid) = 'boolean'
        and pg_get_function_identity_arguments(p.oid) = 'target_user_id uuid'
        and p.proconfig in (
          array['search_path=""'],
          array['search_path=']
        )
        and position('auth.uid()' in lower(p.prosrc)) > 0
        and position('auth.role()' in lower(p.prosrc)) > 0
        and position('for update' in lower(p.prosrc)) > 0
        and position('interval ''10 minutes''' in lower(p.prosrc)) > 0
        and position('>= 20' in p.prosrc) > 0
        and position('return false' in lower(p.prosrc)) > 0
        and position('return true' in lower(p.prosrc)) > 0
      from pg_proc p
      join pg_language l on l.oid = p.prolang
      where p.oid = o.function_oid
    ), false) as function_definition_correct,
    coalesce(not has_function_privilege(
      'anon', o.function_oid, 'EXECUTE'
    ), false) as anon_execute_revoked,
    coalesce(has_function_privilege(
      'authenticated', o.function_oid, 'EXECUTE'
    ), false) as authenticated_execute_granted,
    coalesce(has_function_privilege(
      'service_role', o.function_oid, 'EXECUTE'
    ), false) as service_role_execute_granted,
    not exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(
        coalesce(p.proacl, acldefault('f', p.proowner))
      ) a
      where p.oid = o.function_oid
        and a.privilege_type = 'EXECUTE'
        and a.grantee not in (
          p.proowner,
          'authenticated'::regrole,
          'service_role'::regrole
        )
    ) as no_unexpected_execute_grantee
  from objects o
),
data_checks as (
  select
    count(*) as limiter_row_count,
    count(*) filter (
      where user_id is null
        or attempts is null
        or updated_at is null
        or pg_catalog.cardinality(attempts) < 1
        or pg_catalog.cardinality(attempts) > 20
        or pg_catalog.array_position(
          attempts,
          null::timestamp with time zone
        ) is not null
        or updated_at < (
          select max(attempt_time)
          from pg_catalog.unnest(attempts) as attempt_time
        )
    ) as invalid_limiter_row_count
  from public.upload_intent_rate_limits
),
checks as (
  select tc.*, fc.*, dc.*
  from table_checks tc
  cross join function_checks fc
  cross join data_checks dc
)
select
  checks.*,
  (
    table_exists
    and table_owner_and_rls_correct
    and table_has_no_policies
    and no_direct_api_table_grants
    and exact_columns
    and exact_constraints
    and function_exists
    and function_definition_correct
    and anon_execute_revoked
    and authenticated_execute_granted
    and service_role_execute_granted
    and no_unexpected_execute_grantee
    and invalid_limiter_row_count = 0
  ) as all_checks_pass
from checks;

rollback;
