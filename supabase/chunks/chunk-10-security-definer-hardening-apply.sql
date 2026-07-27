-- psy.market database Chunk 10
-- APPLY: harden increment_view_count(uuid) and
-- public.update_conversation_last_message().
--
-- EXECUTION STATUS: OWNER-APPLIED 2026-07-27; independently verified live.
-- Historical apply artifact: do not rerun. Its exact-old-state guards are
-- expected to abort after the successful first application.
--
-- Scope:
--   * preserve both signatures and current data behavior;
--   * fix search_path and schema qualification;
--   * restrict EXECUTE to service_role (plus function owner postgres);
--   * retain the existing on_message_insert trigger unchanged;
--   * add trigger-context and exact-parent guards to the trigger function.
--
-- No table data is intentionally rewritten by this chunk.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Fail closed unless both functions and the trigger still match the exact live
-- state captured during the 2026-07-27 read-only review.
do $$
declare
  increment_oid oid := to_regprocedure('public.increment_view_count(uuid)');
  conversation_trigger_oid oid := to_regprocedure(
    'public.update_conversation_last_message()'
  );
  matching_trigger_count bigint;
begin
  if increment_oid is null then
    raise exception 'Chunk 10 precondition failed: increment_view_count(uuid) is missing';
  end if;

  if conversation_trigger_oid is null then
    raise exception 'Chunk 10 precondition failed: update_conversation_last_message() is missing';
  end if;

  if md5(pg_get_functiondef(increment_oid))
       <> 'd81d823b78ccd0d43568fd1e953c9e33' then
    raise exception 'Chunk 10 precondition failed: increment_view_count(uuid) drifted';
  end if;

  if md5(pg_get_functiondef(conversation_trigger_oid))
       <> '7c039aa69192e88960c5a1b9e7518b62' then
    raise exception 'Chunk 10 precondition failed: update_conversation_last_message() drifted';
  end if;

  if not has_function_privilege(
    'anon',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) then
    raise exception 'Chunk 10 precondition failed: increment_view_count ACL drifted';
  end if;

  if (
    select count(distinct a.grantee)
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = increment_oid
      and a.grantee in (
        0::oid,
        'anon'::regrole,
        'authenticated'::regrole,
        'service_role'::regrole
      )
      and a.privilege_type = 'EXECUTE'
  ) <> 4 then
    raise exception 'Chunk 10 precondition failed: increment_view_count direct ACL drifted';
  end if;

  if not has_function_privilege(
    'anon',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) then
    raise exception 'Chunk 10 precondition failed: conversation trigger ACL drifted';
  end if;

  if (
    select count(distinct a.grantee)
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = conversation_trigger_oid
      and a.grantee in (
        0::oid,
        'anon'::regrole,
        'authenticated'::regrole,
        'service_role'::regrole
      )
      and a.privilege_type = 'EXECUTE'
  ) <> 4 then
    raise exception 'Chunk 10 precondition failed: conversation trigger direct ACL drifted';
  end if;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    join pg_roles table_owner on table_owner.oid = c.relowner
    join pg_proc p on p.oid = conversation_trigger_oid
    join pg_roles function_owner on function_owner.oid = p.proowner
    where n.nspname = 'public'
      and c.relname = 'conversations'
      and c.relkind = 'r'
      and c.relrowsecurity
      and not c.relforcerowsecurity
      and table_owner.rolname = 'postgres'
      and function_owner.rolname = 'postgres'
      and function_owner.rolbypassrls
      and has_table_privilege(
        'postgres',
        'public.conversations',
        'UPDATE'
      )
  ) then
    raise exception 'Chunk 10 precondition failed: conversation RLS/definer-owner state drifted';
  end if;

  select count(*)
    into matching_trigger_count
  from pg_trigger t
  where not t.tgisinternal
    and t.tgrelid = 'public.messages'::regclass
    and t.tgfoid = conversation_trigger_oid
    and t.tgname = 'on_message_insert'
    and t.tgenabled = 'O'
    and t.tgtype = 5;

  if matching_trigger_count <> 1 then
    raise exception 'Chunk 10 precondition failed: expected one enabled AFTER INSERT ROW trigger';
  end if;
end;
$$;

-- No current app code calls this RPC. Keep the signature and active-listing-only
-- behavior for compatibility, but expose it only to trusted server-side code.
create or replace function public.increment_view_count(
  listing_id uuid
)
returns void
language sql
volatile
security definer
set search_path = ''
as $function$
  update public.listings as l
  set view_count = l.view_count + 1
  where l.id = $1
    and l.status = 'active'::public.listing_status;
$function$;

-- This is a trigger-only function. Message INSERT authorization remains in the
-- existing Chunk 6 RLS policy. The trigger derives all mutation inputs from NEW,
-- verifies its invocation context, and requires exactly one parent conversation.
create or replace function public.update_conversation_last_message()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  affected_rows bigint;
begin
  if tg_when <> 'AFTER'
     or tg_level <> 'ROW'
     or tg_op <> 'INSERT'
     or tg_table_schema <> 'public'
     or tg_table_name <> 'messages' then
    raise exception 'Unexpected update_conversation_last_message trigger context'
      using errcode = '42501';
  end if;

  update public.conversations as c
  set last_message_at = new.created_at,
      last_message_body = pg_catalog.left(new.body, 120)
  where c.id = new.conversation_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Message parent conversation does not exist'
      using errcode = '23503';
  end if;

  return new;
end;
$function$;

-- CREATE OR REPLACE retains prior ACLs. Remove PostgreSQL PUBLIC execution and
-- every client-role grant explicitly, then keep only the reviewed trusted role.
revoke all on function public.increment_view_count(uuid) from public;
revoke execute on function public.increment_view_count(uuid) from anon;
revoke execute on function public.increment_view_count(uuid) from authenticated;
grant execute on function public.increment_view_count(uuid) to service_role;

revoke all on function public.update_conversation_last_message() from public;
revoke execute on function public.update_conversation_last_message() from anon;
revoke execute on function public.update_conversation_last_message()
  from authenticated;
grant execute on function public.update_conversation_last_message()
  to service_role;

-- Transactional postconditions: abort the entire chunk on any mismatch.
do $$
declare
  increment_oid oid := to_regprocedure('public.increment_view_count(uuid)');
  conversation_trigger_oid oid := to_regprocedure(
    'public.update_conversation_last_message()'
  );
  increment_public_execute boolean;
  conversation_public_execute boolean;
begin
  if increment_oid is null or conversation_trigger_oid is null then
    raise exception 'Chunk 10 postcondition failed: function missing';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    join pg_roles r on r.oid = p.proowner
    where p.oid = increment_oid
      and p.prosecdef
      and l.lanname = 'sql'
      and r.rolname = 'postgres'
      and p.proconfig in (
        array['search_path=""'],
        array['search_path=']
      )
      and position('update public.listings' in lower(p.prosrc)) > 0
      and position('''active''::public.listing_status' in p.prosrc) > 0
  ) then
    raise exception 'Chunk 10 postcondition failed: increment_view_count definition mismatch';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    join pg_roles r on r.oid = p.proowner
    where p.oid = conversation_trigger_oid
      and p.prosecdef
      and l.lanname = 'plpgsql'
      and r.rolname = 'postgres'
      and p.proconfig in (
        array['search_path=""'],
        array['search_path=']
      )
      and position('update public.conversations' in lower(p.prosrc)) > 0
      and position('tg_table_schema' in lower(p.prosrc)) > 0
      and position('affected_rows <> 1' in lower(p.prosrc)) > 0
  ) then
    raise exception 'Chunk 10 postcondition failed: conversation trigger definition mismatch';
  end if;

  select exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = increment_oid
      and a.grantee = 0
      and a.privilege_type = 'EXECUTE'
  ) into increment_public_execute;

  select exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid = conversation_trigger_oid
      and a.grantee = 0
      and a.privilege_type = 'EXECUTE'
  ) into conversation_public_execute;

  if increment_public_execute
     or has_function_privilege(
       'anon',
       'public.increment_view_count(uuid)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.increment_view_count(uuid)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'service_role',
       'public.increment_view_count(uuid)',
       'EXECUTE'
     ) then
    raise exception 'Chunk 10 postcondition failed: increment_view_count ACL mismatch';
  end if;

  if conversation_public_execute
     or has_function_privilege(
       'anon',
       'public.update_conversation_last_message()',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.update_conversation_last_message()',
       'EXECUTE'
     )
     or not has_function_privilege(
       'service_role',
       'public.update_conversation_last_message()',
       'EXECUTE'
     ) then
    raise exception 'Chunk 10 postcondition failed: conversation trigger ACL mismatch';
  end if;

  if exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid in (increment_oid, conversation_trigger_oid)
      and a.privilege_type = 'EXECUTE'
      and a.grantee not in (p.proowner, 'service_role'::regrole)
  ) then
    raise exception 'Chunk 10 postcondition failed: unexpected EXECUTE grantee';
  end if;

  if not exists (
    select 1
    from pg_trigger t
    where not t.tgisinternal
      and t.tgrelid = 'public.messages'::regclass
      and t.tgfoid = conversation_trigger_oid
      and t.tgname = 'on_message_insert'
      and t.tgenabled = 'O'
      and t.tgtype = 5
  ) then
    raise exception 'Chunk 10 postcondition failed: on_message_insert trigger mismatch';
  end if;
end;
$$;

-- Inspectable final result. Expected: all booleans true.
select
  to_regprocedure('public.increment_view_count(uuid)') is not null
    as increment_function_present,
  to_regprocedure('public.update_conversation_last_message()') is not null
    as conversation_trigger_function_present,
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
  ) as conversation_trigger_service_role_granted;

commit;
