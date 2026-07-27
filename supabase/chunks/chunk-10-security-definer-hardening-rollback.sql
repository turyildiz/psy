-- psy.market database Chunk 10
-- ROLLBACK: restore the exact pre-Chunk-10 function definitions and ACLs.
--
-- ROLLBACK STATUS: NOT APPLIED.
-- WARNING: this rollback deliberately restores the captured insecure state:
--   * no fixed search_path;
--   * PUBLIC, anon, authenticated, and service_role EXECUTE grants.
-- Use only if Chunk 10 causes a verified compatibility problem and the owner
-- explicitly accepts reopening those findings.
--
-- No table data is intentionally rewritten by this rollback.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Fail closed unless the hardened definitions/ACLs are still present.
do $$
declare
  increment_oid oid := to_regprocedure('public.increment_view_count(uuid)');
  conversation_trigger_oid oid := to_regprocedure(
    'public.update_conversation_last_message()'
  );
begin
  if increment_oid is null or conversation_trigger_oid is null then
    raise exception 'Chunk 10 rollback precondition failed: function missing';
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
    raise exception 'Chunk 10 rollback precondition failed: increment function drifted';
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
    raise exception 'Chunk 10 rollback precondition failed: trigger function drifted';
  end if;

  if has_function_privilege(
    'anon',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) then
    raise exception 'Chunk 10 rollback precondition failed: increment ACL drifted';
  end if;

  if has_function_privilege(
    'anon',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) then
    raise exception 'Chunk 10 rollback precondition failed: trigger ACL drifted';
  end if;

  if exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid in (increment_oid, conversation_trigger_oid)
      and a.privilege_type = 'EXECUTE'
      and a.grantee not in (p.proowner, 'service_role'::regrole)
  ) then
    raise exception 'Chunk 10 rollback precondition failed: unexpected EXECUTE grantee';
  end if;
end;
$$;

-- Exact captured pre-Chunk-10 definition.
create or replace function public.increment_view_count(listing_id uuid)
returns void
language sql
security definer
as $function$
  UPDATE listings SET view_count = view_count + 1 WHERE id = listing_id AND status = 'active';
$function$;

-- Exact captured pre-Chunk-10 trigger-function definition.
create or replace function public.update_conversation_last_message()
returns trigger
language plpgsql
security definer
as $function$
begin
  update conversations set
    last_message_at = NEW.created_at,
    last_message_body = left(NEW.body, 120)
  where id = NEW.conversation_id;
  return NEW;
end;
$function$;

-- Restore exact captured broad execution exposure.
revoke all on function public.increment_view_count(uuid) from public;
revoke execute on function public.increment_view_count(uuid) from anon;
revoke execute on function public.increment_view_count(uuid) from authenticated;
revoke execute on function public.increment_view_count(uuid) from service_role;
grant execute on function public.increment_view_count(uuid)
  to public, anon, authenticated, service_role;

revoke all on function public.update_conversation_last_message() from public;
revoke execute on function public.update_conversation_last_message() from anon;
revoke execute on function public.update_conversation_last_message()
  from authenticated;
revoke execute on function public.update_conversation_last_message()
  from service_role;
grant execute on function public.update_conversation_last_message()
  to public, anon, authenticated, service_role;

-- Transactional postconditions: exact captured definitions and broad ACLs.
do $$
declare
  increment_oid oid := to_regprocedure('public.increment_view_count(uuid)');
  conversation_trigger_oid oid := to_regprocedure(
    'public.update_conversation_last_message()'
  );
begin
  if md5(pg_get_functiondef(increment_oid))
       <> 'd81d823b78ccd0d43568fd1e953c9e33' then
    raise exception 'Chunk 10 rollback postcondition failed: increment definition mismatch';
  end if;

  if md5(pg_get_functiondef(conversation_trigger_oid))
       <> '7c039aa69192e88960c5a1b9e7518b62' then
    raise exception 'Chunk 10 rollback postcondition failed: trigger definition mismatch';
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
  ) or not has_function_privilege(
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
    raise exception 'Chunk 10 rollback postcondition failed: named-role ACL mismatch';
  end if;

  if (
    select count(*)
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid in (increment_oid, conversation_trigger_oid)
      and a.privilege_type = 'EXECUTE'
      and a.grantee in (
        0::oid,
        p.proowner,
        'anon'::regrole,
        'authenticated'::regrole,
        'service_role'::regrole
      )
  ) <> 10 or exists (
    select 1
    from pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where p.oid in (increment_oid, conversation_trigger_oid)
      and a.privilege_type = 'EXECUTE'
      and a.grantee not in (
        0::oid,
        p.proowner,
        'anon'::regrole,
        'authenticated'::regrole,
        'service_role'::regrole
      )
  ) then
    raise exception 'Chunk 10 rollback postcondition failed: direct ACL mismatch';
  end if;
end;
$$;

-- Inspectable final result. WARNING: true means the insecure captured ACLs and
-- definitions have been restored successfully.
select
  md5(pg_get_functiondef(to_regprocedure('public.increment_view_count(uuid)')))
    = 'd81d823b78ccd0d43568fd1e953c9e33'
    as increment_original_definition_restored,
  md5(pg_get_functiondef(
    to_regprocedure('public.update_conversation_last_message()')
  )) = '7c039aa69192e88960c5a1b9e7518b62'
    as conversation_trigger_original_definition_restored,
  has_function_privilege(
    'anon',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) as increment_anon_execute_restored,
  has_function_privilege(
    'authenticated',
    'public.increment_view_count(uuid)',
    'EXECUTE'
  ) as increment_authenticated_execute_restored,
  has_function_privilege(
    'anon',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) as conversation_trigger_anon_execute_restored,
  has_function_privilege(
    'authenticated',
    'public.update_conversation_last_message()',
    'EXECUTE'
  ) as conversation_trigger_authenticated_execute_restored;

commit;
