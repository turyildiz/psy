-- psy.market Item 3 / Commit 3
-- APPLY: shared upload-intent rolling-window rate limiter
--
-- Limit: 20 accepted upload intents per rolling 10 minutes per user.
-- Package applied by the owner on 2026-08-02.
-- Preflight result: all_preflight_checks_pass = true.
-- Post-apply verification result: all_checks_pass = true.
-- Run only after the paired read-only preflight returns
-- all_preflight_checks_pass = true.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Fail closed on re-run, name collision, wrong execution role, missing roles,
-- or an incompatible auth.users identity target.
do $preflight$
declare
  auth_users_oid oid := to_regclass('auth.users');
  auth_users_id_attnum smallint;
begin
  if current_user <> 'postgres' then
    raise exception 'Upload limiter apply must run as postgres';
  end if;

  if to_regclass('public.upload_intent_rate_limits') is not null then
    raise exception 'Upload limiter apply refused: table already exists';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'consume_upload_intent_rate_limit'
  ) then
    raise exception 'Upload limiter apply refused: function name already exists';
  end if;

  if not exists (
    select 1
    from pg_roles
    where rolname = 'postgres'
      and not rolsuper
      and rolbypassrls
  ) then
    raise exception 'Upload limiter apply refused: postgres owner state drifted';
  end if;

  if (
    select count(*)
    from pg_roles
    where rolname in ('anon', 'authenticated', 'service_role')
  ) <> 3 then
    raise exception 'Upload limiter apply refused: required API roles are missing';
  end if;

  if auth_users_oid is null then
    raise exception 'Upload limiter apply refused: auth.users is missing';
  end if;

  select a.attnum
    into auth_users_id_attnum
  from pg_attribute a
  where a.attrelid = auth_users_oid
    and a.attname = 'id'
    and a.attnum > 0
    and not a.attisdropped
    and a.atttypid = 'uuid'::regtype
    and a.attnotnull;

  if auth_users_id_attnum is null or not exists (
    select 1
    from pg_constraint c
    where c.conrelid = auth_users_oid
      and c.contype in ('p', 'u')
      and c.convalidated
      and c.conkey = array[auth_users_id_attnum]::smallint[]
  ) then
    raise exception 'Upload limiter apply refused: auth.users.id is not a unique non-null uuid';
  end if;
end;
$preflight$;

create table public.upload_intent_rate_limits (
  user_id uuid primary key,
  attempts timestamp with time zone[] not null
    default '{}'::timestamp with time zone[],
  updated_at timestamp with time zone not null
    default pg_catalog.clock_timestamp(),
  constraint upload_intent_rate_limits_user_id_fkey
    foreign key (user_id)
    references auth.users(id)
    on delete cascade,
  constraint upload_intent_rate_limits_attempt_count_check
    check (pg_catalog.cardinality(attempts) between 0 and 20),
  constraint upload_intent_rate_limits_attempts_no_null_check
    check (
      pg_catalog.array_position(
        attempts,
        null::timestamp with time zone
      ) is null
    )
);

alter table public.upload_intent_rate_limits owner to postgres;
alter table public.upload_intent_rate_limits enable row level security;
alter table public.upload_intent_rate_limits force row level security;

-- The table is internal. There are deliberately no RLS policies and no direct
-- Data API table privileges. All consumption goes through the function below.
revoke all privileges on table public.upload_intent_rate_limits
  from public, anon, authenticated, service_role;

create function public.consume_upload_intent_rate_limit(
  target_user_id uuid default null
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  caller_role text := auth.role();
  caller_user_id uuid := auth.uid();
  effective_user_id uuid;
  current_time timestamp with time zone := pg_catalog.clock_timestamp();
  cutoff_time timestamp with time zone;
  retained_attempts timestamp with time zone[];
begin
  if caller_role = 'authenticated' then
    if caller_user_id is null then
      raise exception 'Authenticated upload limiter caller has no user identity'
        using errcode = '42501';
    end if;
    if target_user_id is not null then
      raise exception 'Authenticated callers cannot select a rate-limit identity'
        using errcode = '42501';
    end if;
    effective_user_id := caller_user_id;
  elsif caller_role = 'service_role' then
    if target_user_id is null then
      raise exception 'Service-role upload limiter calls require a verified target user'
        using errcode = '22023';
    end if;
    effective_user_id := target_user_id;
  else
    raise exception 'Unexpected role cannot consume upload-intent quota'
      using errcode = '42501';
  end if;

  cutoff_time := current_time - interval '10 minutes';

  insert into public.upload_intent_rate_limits as limits (user_id)
  values (effective_user_id)
  on conflict (user_id) do nothing;

  select limits.attempts
    into retained_attempts
  from public.upload_intent_rate_limits as limits
  where limits.user_id = effective_user_id
  for update;

  if not found then
    raise exception 'Upload limiter row could not be locked';
  end if;

  retained_attempts := array(
    select attempt_time
    from pg_catalog.unnest(retained_attempts) as attempt_time
    where attempt_time > cutoff_time
    order by attempt_time
  );

  if pg_catalog.cardinality(retained_attempts) >= 20 then
    update public.upload_intent_rate_limits as limits
    set attempts = retained_attempts,
        updated_at = current_time
    where limits.user_id = effective_user_id;
    return false;
  end if;

  retained_attempts := pg_catalog.array_append(
    retained_attempts,
    current_time
  );

  update public.upload_intent_rate_limits as limits
  set attempts = retained_attempts,
      updated_at = current_time
  where limits.user_id = effective_user_id;

  return true;
end;
$function$;

alter function public.consume_upload_intent_rate_limit(uuid)
  owner to postgres;

revoke all privileges
  on function public.consume_upload_intent_rate_limit(uuid)
  from public;
revoke execute
  on function public.consume_upload_intent_rate_limit(uuid)
  from anon, authenticated, service_role;
grant execute
  on function public.consume_upload_intent_rate_limit(uuid)
  to authenticated, service_role;

comment on table public.upload_intent_rate_limits is
  'Internal per-user rolling-window state for upload-intent rate limiting.';
comment on function public.consume_upload_intent_rate_limit(uuid) is
  'Atomically consumes one of 20 upload intents per rolling 10 minutes. Authenticated callers use auth.uid(); service_role must supply a previously verified user.';

-- Transactional postconditions. Any mismatch aborts the entire apply.
do $postconditions$
declare
  table_oid oid := to_regclass('public.upload_intent_rate_limits');
  function_oid oid := to_regprocedure(
    'public.consume_upload_intent_rate_limit(uuid)'
  );
begin
  if table_oid is null or function_oid is null then
    raise exception 'Upload limiter apply postcondition failed: object missing';
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
    raise exception 'Upload limiter apply postcondition failed: table owner/RLS mismatch';
  end if;

  if (
    select count(*)
    from pg_policy p
    where p.polrelid = table_oid
  ) <> 0 then
    raise exception 'Upload limiter apply postcondition failed: table must have no policies';
  end if;

  if exists (
    select 1
    from pg_class c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) a
    where c.oid = table_oid
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
  ) then
    raise exception 'Upload limiter apply postcondition failed: direct table grant found';
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
    raise exception 'Upload limiter apply postcondition failed: function definition mismatch';
  end if;

  if has_function_privilege(
    'anon', function_oid, 'EXECUTE'
  ) or not has_function_privilege(
    'authenticated', function_oid, 'EXECUTE'
  ) or not has_function_privilege(
    'service_role', function_oid, 'EXECUTE'
  ) then
    raise exception 'Upload limiter apply postcondition failed: effective function ACL mismatch';
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
    raise exception 'Upload limiter apply postcondition failed: unexpected function grantee';
  end if;
end;
$postconditions$;

commit;
