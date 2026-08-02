-- psy.market Item 3 / Commit 3
-- ROLLBACK: remove the shared upload-intent rate limiter
--
-- Package applied by the owner on 2026-08-02.
-- Preflight result: all_preflight_checks_pass = true.
-- Post-apply verification result: all_checks_pass = true.
-- Rollback status: NOT APPLIED.
-- This deletes only ephemeral rate-limit timestamps. It does not restore the
-- process-local limiter, which application code no longer uses. Do not run this
-- rollback without coordinating the application change first.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preconditions$
declare
  table_oid oid := to_regclass('public.upload_intent_rate_limits');
  function_oid oid := to_regprocedure(
    'public.consume_upload_intent_rate_limit(uuid)'
  );
begin
  if current_user <> 'postgres' then
    raise exception 'Upload limiter rollback must run as postgres';
  end if;

  if table_oid is null or function_oid is null then
    raise exception 'Upload limiter rollback refused: expected object missing';
  end if;

  if not exists (
    select 1
    from pg_class c
    where c.oid = table_oid
      and c.relkind = 'r'
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) then
    raise exception 'Upload limiter rollback refused: table owner/RLS drifted';
  end if;

  if (
    select count(*)
    from pg_attribute a
    where a.attrelid = table_oid
      and a.attnum > 0
      and not a.attisdropped
  ) <> 3 then
    raise exception 'Upload limiter rollback refused: table columns drifted';
  end if;

  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = table_oid
      and c.conname = 'upload_intent_rate_limits_user_id_fkey'
      and c.contype = 'f'
      and c.convalidated
      and c.confrelid = 'auth.users'::regclass
      and c.confdeltype = 'c'
  ) or not exists (
    select 1
    from pg_constraint c
    where c.conrelid = table_oid
      and c.conname = 'upload_intent_rate_limits_attempt_count_check'
      and c.contype = 'c'
      and c.convalidated
  ) or not exists (
    select 1
    from pg_constraint c
    where c.conrelid = table_oid
      and c.conname = 'upload_intent_rate_limits_attempts_no_null_check'
      and c.contype = 'c'
      and c.convalidated
  ) then
    raise exception 'Upload limiter rollback refused: table constraints drifted';
  end if;

  if (
    select count(*)
    from pg_policy p
    where p.polrelid = table_oid
  ) <> 0 then
    raise exception 'Upload limiter rollback refused: unexpected RLS policy found';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    where p.oid = function_oid
      and p.proowner = 'postgres'::regrole
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
  ) then
    raise exception 'Upload limiter rollback refused: function definition drifted';
  end if;

  if has_function_privilege(
    'anon', function_oid, 'EXECUTE'
  ) or not has_function_privilege(
    'authenticated', function_oid, 'EXECUTE'
  ) or not has_function_privilege(
    'service_role', function_oid, 'EXECUTE'
  ) then
    raise exception 'Upload limiter rollback refused: function ACL drifted';
  end if;

  if exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) a
    where p.oid = function_oid
      and a.privilege_type = 'EXECUTE'
      and a.grantee not in (
        p.proowner,
        'authenticated'::regrole,
        'service_role'::regrole
      )
  ) then
    raise exception 'Upload limiter rollback refused: unexpected function grantee';
  end if;
end;
$preconditions$;

-- No CASCADE: any unexpected dependency makes the rollback fail safely.
drop function public.consume_upload_intent_rate_limit(uuid);
drop table public.upload_intent_rate_limits;

do $postconditions$
begin
  if to_regclass('public.upload_intent_rate_limits') is not null then
    raise exception 'Upload limiter rollback postcondition failed: table remains';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'consume_upload_intent_rate_limit'
  ) then
    raise exception 'Upload limiter rollback postcondition failed: function remains';
  end if;
end;
$postconditions$;

commit;
