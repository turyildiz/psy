-- psy.market database Chunk 10
-- READ-ONLY POST-APPLY VERIFICATION
--
-- Run only after Turgay reports that the reviewed apply file was executed in
-- Supabase SQL Editor. This script performs no writes.
-- Expected: one row and all_checks_pass = true.

begin transaction isolation level repeatable read read only;

with
function_checks as (
  select
    coalesce((
      select
        p.prosecdef
        and l.lanname = 'sql'
        and r.rolname = 'postgres'
        and pg_get_function_result(p.oid) = 'void'
        and pg_get_function_identity_arguments(p.oid) = 'listing_id uuid'
        and p.proconfig in (
          array['search_path=""'],
          array['search_path=']
        )
        and position('update public.listings' in lower(p.prosrc)) > 0
        and position('''active''::public.listing_status' in p.prosrc) > 0
      from pg_proc p
      join pg_language l on l.oid = p.prolang
      join pg_roles r on r.oid = p.proowner
      where p.oid = to_regprocedure('public.increment_view_count(uuid)')
    ), false) as increment_definition_hardened,
    coalesce((
      select
        p.prosecdef
        and l.lanname = 'plpgsql'
        and r.rolname = 'postgres'
        and pg_get_function_result(p.oid) = 'trigger'
        and pg_get_function_identity_arguments(p.oid) = ''
        and p.proconfig in (
          array['search_path=""'],
          array['search_path=']
        )
        and position('update public.conversations' in lower(p.prosrc)) > 0
        and position('tg_table_schema' in lower(p.prosrc)) > 0
        and position('affected_rows <> 1' in lower(p.prosrc)) > 0
      from pg_proc p
      join pg_language l on l.oid = p.prolang
      join pg_roles r on r.oid = p.proowner
      where p.oid = to_regprocedure(
        'public.update_conversation_last_message()'
      )
    ), false) as conversation_trigger_definition_hardened
),
acl_checks as (
  select
    not exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure('public.increment_view_count(uuid)')
        and a.grantee = 0
        and a.privilege_type = 'EXECUTE'
    ) as increment_public_revoked,
    not has_function_privilege(
      'anon',
      'public.increment_view_count(uuid)',
      'EXECUTE'
    ) as increment_anon_revoked,
    not has_function_privilege(
      'authenticated',
      'public.increment_view_count(uuid)',
      'EXECUTE'
    ) as increment_authenticated_revoked,
    has_function_privilege(
      'service_role',
      'public.increment_view_count(uuid)',
      'EXECUTE'
    ) as increment_service_role_granted,
    not exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid = to_regprocedure(
        'public.update_conversation_last_message()'
      )
        and a.grantee = 0
        and a.privilege_type = 'EXECUTE'
    ) as conversation_trigger_public_revoked,
    not has_function_privilege(
      'anon',
      'public.update_conversation_last_message()',
      'EXECUTE'
    ) as conversation_trigger_anon_revoked,
    not has_function_privilege(
      'authenticated',
      'public.update_conversation_last_message()',
      'EXECUTE'
    ) as conversation_trigger_authenticated_revoked,
    has_function_privilege(
      'service_role',
      'public.update_conversation_last_message()',
      'EXECUTE'
    ) as conversation_trigger_service_role_granted,
    not exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where p.oid in (
        to_regprocedure('public.increment_view_count(uuid)'),
        to_regprocedure('public.update_conversation_last_message()')
      )
        and a.privilege_type = 'EXECUTE'
        and a.grantee not in (p.proowner, 'service_role'::regrole)
    ) as only_owner_and_service_role_execute
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
    and t.tgfoid = to_regprocedure(
      'public.update_conversation_last_message()'
    )
    and t.tgname = 'on_message_insert'
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
    dc.*
  from function_checks fc
  cross join acl_checks ac
  cross join rls_owner_checks ro
  cross join trigger_checks tc
  cross join data_checks dc
)
select
  checks.*,
  (
    increment_definition_hardened
    and conversation_trigger_definition_hardened
    and increment_public_revoked
    and increment_anon_revoked
    and increment_authenticated_revoked
    and increment_service_role_granted
    and conversation_trigger_public_revoked
    and conversation_trigger_anon_revoked
    and conversation_trigger_authenticated_revoked
    and conversation_trigger_service_role_granted
    and only_owner_and_service_role_execute
    and conversations_rls_enabled_not_forced_and_postgres_owned
    and trigger_definer_owner_bypasses_rls
    and trigger_definer_owner_has_update
    and matching_message_trigger_count = 1
    and exact_enabled_after_insert_row_trigger
    and null_view_count_rows = 0
    and negative_view_count_rows = 0
    and orphan_message_count = 0
    and last_message_mismatch_count = 0
  ) as all_checks_pass
from checks;

rollback;
