-- psy.market database Chunk 10
-- READ-ONLY PREFLIGHT: SECURITY DEFINER hardening
--
-- Execution record: PASSED before owner apply on 2026-07-27. Chunk 10 is now
-- live. This historical pre-apply script performs no writes but should not be
-- expected to pass again after the hardened definitions/ACLs replaced its
-- captured preconditions.
--
-- Chunk 10 depends only on live Chunks 0-7. Unapplied/deferred Chunks 8-9 are
-- not dependencies.

begin transaction isolation level repeatable read read only;

with
function_state as (
  select
    to_regprocedure('public.increment_view_count(uuid)') as increment_oid,
    to_regprocedure('public.update_conversation_last_message()') as conversation_trigger_oid
),
function_checks as (
  select
    fs.increment_oid is not null as increment_function_exists,
    fs.conversation_trigger_oid is not null as conversation_trigger_function_exists,
    coalesce((
      select
        p.prosecdef
        and l.lanname = 'sql'
        and r.rolname = 'postgres'
        and pg_get_function_result(p.oid) = 'void'
        and pg_get_function_identity_arguments(p.oid) = 'listing_id uuid'
        and p.proconfig is null
        and md5(pg_get_functiondef(p.oid)) = 'd81d823b78ccd0d43568fd1e953c9e33'
      from pg_proc p
      join pg_language l on l.oid = p.prolang
      join pg_roles r on r.oid = p.proowner
      where p.oid = fs.increment_oid
    ), false) as increment_matches_captured_live_definition,
    coalesce((
      select
        p.prosecdef
        and l.lanname = 'plpgsql'
        and r.rolname = 'postgres'
        and pg_get_function_result(p.oid) = 'trigger'
        and pg_get_function_identity_arguments(p.oid) = ''
        and p.proconfig is null
        and md5(pg_get_functiondef(p.oid)) = '7c039aa69192e88960c5a1b9e7518b62'
      from pg_proc p
      join pg_language l on l.oid = p.prolang
      join pg_roles r on r.oid = p.proowner
      where p.oid = fs.conversation_trigger_oid
    ), false) as conversation_trigger_matches_captured_live_definition
  from function_state fs
),
acl_checks as (
  select
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.increment_view_count(uuid)')
        and a.grantee = 0
        and a.privilege_type = 'EXECUTE'
    ) as increment_public_execute,
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.increment_view_count(uuid)')
        and a.grantee = 'anon'::regrole
        and a.privilege_type = 'EXECUTE'
    ) as increment_anon_execute,
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.increment_view_count(uuid)')
        and a.grantee = 'authenticated'::regrole
        and a.privilege_type = 'EXECUTE'
    ) as increment_authenticated_execute,
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.increment_view_count(uuid)')
        and a.grantee = 'service_role'::regrole
        and a.privilege_type = 'EXECUTE'
    ) as increment_service_role_execute,
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.update_conversation_last_message()')
        and a.grantee = 0
        and a.privilege_type = 'EXECUTE'
    ) as conversation_trigger_public_execute,
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.update_conversation_last_message()')
        and a.grantee = 'anon'::regrole
        and a.privilege_type = 'EXECUTE'
    ) as conversation_trigger_anon_execute,
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.update_conversation_last_message()')
        and a.grantee = 'authenticated'::regrole
        and a.privilege_type = 'EXECUTE'
    ) as conversation_trigger_authenticated_execute,
    exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.update_conversation_last_message()')
        and a.grantee = 'service_role'::regrole
        and a.privilege_type = 'EXECUTE'
    ) as conversation_trigger_service_role_execute
),
rls_owner_checks as (
  select
    coalesce((
      select
        c.relrowsecurity
        and not c.relforcerowsecurity
        and table_owner.rolname = 'postgres'
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      join pg_roles table_owner on table_owner.oid = c.relowner
      where n.nspname = 'public'
        and c.relname = 'conversations'
        and c.relkind = 'r'
    ), false) as conversations_rls_enabled_not_forced_and_postgres_owned,
    coalesce((
      select
        function_owner.rolname = 'postgres'
        and not function_owner.rolsuper
        and function_owner.rolbypassrls
        and p.prosecdef
      from pg_proc p
      join pg_roles function_owner on function_owner.oid = p.proowner
      where p.oid = to_regprocedure(
        'public.update_conversation_last_message()'
      )
    ), false) as trigger_definer_owner_bypasses_rls,
    has_table_privilege(
      'postgres',
      'public.conversations',
      'UPDATE'
    ) as trigger_definer_owner_has_update
),
trigger_checks as (
  select
    count(*) as matching_message_trigger_count,
    count(*) = 1
      and bool_and(t.tgenabled = 'O')
      and bool_and(t.tgtype = 5)
      as exact_enabled_after_insert_row_trigger
  from pg_trigger t
  where not t.tgisinternal
    and t.tgrelid = 'public.messages'::regclass
    and t.tgfoid = to_regprocedure('public.update_conversation_last_message()')
    and t.tgname = 'on_message_insert'
),
column_checks as (
  select
    count(*) filter (
      where table_name = 'listings'
        and column_name = 'view_count'
        and data_type = 'integer'
        and is_nullable = 'NO'
        and column_default = '0'
    ) = 1 as compatible_view_count_column,
    count(*) filter (
      where table_name = 'conversations'
        and column_name = 'last_message_at'
        and data_type = 'timestamp with time zone'
        and is_nullable = 'NO'
    ) = 1 as compatible_last_message_at_column,
    count(*) filter (
      where table_name = 'conversations'
        and column_name = 'last_message_body'
        and data_type = 'text'
        and is_nullable = 'YES'
    ) = 1 as compatible_last_message_body_column
  from information_schema.columns
  where table_schema = 'public'
    and (
      (table_name = 'listings' and column_name = 'view_count')
      or (
        table_name = 'conversations'
        and column_name in ('last_message_at', 'last_message_body')
      )
    )
),
fk_checks as (
  select exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.messages'::regclass
      and c.confrelid = 'public.conversations'::regclass
      and c.conname = 'messages_conversation_id_fkey'
      and c.contype = 'f'
      and c.convalidated
      and pg_get_constraintdef(c.oid, true)
        = 'FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE'
  ) as validated_message_conversation_fk
),
latest_message as (
  select distinct on (m.conversation_id)
    m.conversation_id,
    m.created_at,
    left(m.body, 120) as expected_last_message_body
  from public.messages m
  order by m.conversation_id, m.created_at desc, m.id desc
),
data_checks as (
  select
    (select count(*) from public.listings) as listing_count,
    (select count(*) from public.listings where view_count is null) as null_view_count_rows,
    (select count(*) from public.listings where view_count < 0) as negative_view_count_rows,
    (select min(view_count) from public.listings) as minimum_view_count,
    (select max(view_count) from public.listings) as maximum_view_count,
    (select count(*) from public.messages) as message_count,
    (select count(*) from public.conversations) as conversation_count,
    (
      select count(*)
      from public.messages m
      left join public.conversations c on c.id = m.conversation_id
      where c.id is null
    ) as orphan_message_count,
    (
      select count(*)
      from latest_message lm
      join public.conversations c on c.id = lm.conversation_id
      where c.last_message_at is distinct from lm.created_at
         or c.last_message_body is distinct from lm.expected_last_message_body
    ) as last_message_mismatch_count
),
checks as (
  select
    fc.*,
    ac.*,
    ro.*,
    tc.*,
    cc.*,
    fk.*,
    dc.*
  from function_checks fc
  cross join acl_checks ac
  cross join rls_owner_checks ro
  cross join trigger_checks tc
  cross join column_checks cc
  cross join fk_checks fk
  cross join data_checks dc
)
select
  checks.*,
  (
    increment_function_exists
    and conversation_trigger_function_exists
    and increment_matches_captured_live_definition
    and conversation_trigger_matches_captured_live_definition
    and increment_public_execute
    and increment_anon_execute
    and increment_authenticated_execute
    and increment_service_role_execute
    and conversation_trigger_public_execute
    and conversation_trigger_anon_execute
    and conversation_trigger_authenticated_execute
    and conversation_trigger_service_role_execute
    and conversations_rls_enabled_not_forced_and_postgres_owned
    and trigger_definer_owner_bypasses_rls
    and trigger_definer_owner_has_update
    and matching_message_trigger_count = 1
    and exact_enabled_after_insert_row_trigger
    and compatible_view_count_column
    and compatible_last_message_at_column
    and compatible_last_message_body_column
    and validated_message_conversation_fk
    and null_view_count_rows = 0
    and negative_view_count_rows = 0
    and orphan_message_count = 0
    and last_message_mismatch_count = 0
  ) as all_checks_pass
from checks;

rollback;
