-- MP-4 @darktribo deny-path fixture — preflight
--
-- Run in the Supabase SQL Editor as project owner before the fixture apply.
-- This script is read-only and returns exactly one result row.
-- Save that row: user_preban_state, profile_preban_state, and
-- hero_preban_state are the human-readable restoration baseline.
--
-- The fixture APPLY will touch:
--   1. public.users.{banned_at,ban_reason,banned_by};
--   2. public.profiles.is_suspended and, through tr_profiles_updated_at,
--      public.profiles.updated_at for the exact target profile;
--   3. Hero fields and updated_at on currently Hero-featured target posts,
--      through clear_hero_on_author_ban_trigger and the posts invariant trigger.
--
-- Profile/post updated_at values and cleared Hero metadata are intentionally
-- not rewritten from stale snapshots during UNBAN. This preflight displays
-- their exact pre-ban values; UNBAN-VERIFY displays the final values and labels
-- the timestamp/Hero differences as non-restored side effects for manual review.
-- Trigger guards use exact reviewed definitions plus normalized function-source
-- hashes and metadata; any drift ends in STOP before fixture mutation.

with target_profiles as materialized (
  select p.id, p.user_id, p.handle, p.is_suspended, p.updated_at
  from public.profiles as p
  where p.id = 'c18d4b9f-012e-4fed-877b-ece6cbc19884'::uuid
    and p.user_id = 'eb616b4a-2b0e-4ad7-ba92-6d2b67f03287'::uuid
    and p.handle = 'darktribo'
), target_owner_ids as materialized (
  select distinct p.user_id
  from target_profiles as p
), owner_profile_counts as materialized (
  select o.user_id, count(p.id)::bigint as profile_count
  from target_owner_ids as o
  left join public.profiles as p on p.user_id = o.user_id
  group by o.user_id
), target_users as materialized (
  select u.id, u.role::text as role, u.banned_at, u.ban_reason, u.banned_by
  from public.users as u
  where u.id in (select user_id from target_owner_ids)
), catalog_checks as materialized (
  select
    to_regclass('public.users') is not null
      and to_regclass('public.profiles') is not null
      and to_regclass('public.posts') is not null as required_tables_exist,
    exists (
      select 1
      from pg_proc as proc
      join pg_namespace as ns on ns.oid = proc.pronamespace
      where ns.nspname = 'public'
        and proc.proname = 'admin_ban_user'
        and pg_get_function_identity_arguments(proc.oid) = 'target_user_id uuid, reason text'
        and proc.prosecdef
        and pg_catalog.strpos(proc.prosrc, 'current_user_is_admin') > 0
        and pg_catalog.strpos(proc.prosrc, 'auth.uid') > 0
    ) as admin_ban_rpc_requires_app_admin,
    exists (
      select 1
      from pg_proc as proc
      join pg_namespace as ns on ns.oid = proc.pronamespace
      where ns.nspname = 'public'
        and proc.proname = 'admin_unban_user'
        and pg_get_function_identity_arguments(proc.oid) = 'target_user_id uuid'
        and proc.prosecdef
        and pg_catalog.strpos(proc.prosrc, 'current_user_is_admin') > 0
    ) as admin_unban_rpc_requires_app_admin,
    exists (
      select 1
      from pg_trigger as trigger_row
      where trigger_row.tgrelid = to_regclass('public.users')
        and trigger_row.tgname = 'clear_hero_on_author_ban_trigger'
        and not trigger_row.tgisinternal
        and trigger_row.tgenabled = 'O'
        and trigger_row.tgfoid = to_regprocedure('public.clear_hero_on_author_ban()')
        and pg_get_triggerdef(trigger_row.oid, true) =
          'CREATE TRIGGER clear_hero_on_author_ban_trigger AFTER UPDATE OF banned_at ON users FOR EACH ROW WHEN (old.banned_at IS NULL AND new.banned_at IS NOT NULL) EXECUTE FUNCTION clear_hero_on_author_ban()'
    ) as hero_cleanup_trigger_ready,
    exists (
      select 1
      from pg_proc as proc
      join pg_namespace as ns on ns.oid = proc.pronamespace
      where ns.nspname = 'public'
        and proc.proname = 'clear_hero_on_author_ban'
        and pg_get_function_identity_arguments(proc.oid) = ''
        and proc.proowner = 'postgres'::regrole
        and proc.prolang = (select oid from pg_language where lanname = 'plpgsql')
        and proc.provolatile = 'v'
        and proc.prosecdef
        and proc.proconfig in (array['search_path=""'], array['search_path='])
        and proc.proacl::text = '{postgres=X/postgres}'
        and proc.prorettype = 'trigger'::regtype
        and not proc.proretset
        and not proc.proisstrict
        and not proc.proleakproof
        and proc.proparallel = 'u'
        and proc.prokind = 'f'
        and md5(regexp_replace(proc.prosrc, '[[:space:]]+', '', 'g')) = '3a57a0e21d667d0fba08677476671cdf'
        and pg_catalog.strpos(proc.prosrc, 'app.wall_ban_hero_cleanup') > 0
        and pg_catalog.strpos(proc.prosrc, 'old.banned_at is null and new.banned_at is not null') > 0
        and pg_catalog.strpos(proc.prosrc, 'where profile.user_id = new.id') > 0
        and pg_catalog.strpos(proc.prosrc, 'and post.is_hero_featured') > 0
        and pg_catalog.strpos(proc.prosrc, 'is_hero_featured = false') > 0
        and pg_catalog.strpos(proc.prosrc, 'hero_featured_at = null') > 0
        and pg_catalog.strpos(proc.prosrc, 'hero_featured_by = null') > 0
    ) as hero_cleanup_function_ready,
    exists (
      select 1
      from pg_trigger as trigger_row
      where trigger_row.tgrelid = to_regclass('public.posts')
        and trigger_row.tgname = 'enforce_post_write_invariants_trigger'
        and not trigger_row.tgisinternal
        and trigger_row.tgenabled = 'O'
        and trigger_row.tgfoid = to_regprocedure('public.enforce_post_write_invariants()')
        and pg_get_triggerdef(trigger_row.oid, true) =
          'CREATE TRIGGER enforce_post_write_invariants_trigger BEFORE INSERT OR UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION enforce_post_write_invariants()'
    ) and exists (
      select 1
      from pg_proc as proc
      where proc.oid = to_regprocedure('public.enforce_post_write_invariants()')
        and proc.proowner = 'postgres'::regrole
        and proc.prolang = (select oid from pg_language where lanname = 'plpgsql')
        and proc.provolatile = 'v'
        and proc.prosecdef
        and proc.proconfig in (array['search_path=""'], array['search_path='])
        and proc.proacl::text = '{postgres=X/postgres}'
        and proc.prorettype = 'trigger'::regtype
        and not proc.proretset
        and not proc.proisstrict
        and not proc.proleakproof
        and proc.proparallel = 'u'
        and proc.prokind = 'f'
        and md5(regexp_replace(proc.prosrc, '[[:space:]]+', '', 'g')) = 'a2530650dd3839c484d282365f00b180'
        and pg_catalog.strpos(proc.prosrc, 'app.wall_ban_hero_cleanup') > 0
        and pg_catalog.strpos(proc.prosrc, 'ban_cleanup') > 0
        and pg_catalog.strpos(proc.prosrc, 'new.updated_at := pg_catalog.clock_timestamp()') > 0
        and pg_catalog.strpos(proc.prosrc, 'new.is_hero_featured') > 0
        and pg_catalog.strpos(proc.prosrc, 'new.hero_featured_at') > 0
        and pg_catalog.strpos(proc.prosrc, 'new.hero_featured_by') > 0
    ) as post_invariant_path_ready,
    exists (
      select 1
      from pg_trigger as trigger_row
      where trigger_row.tgrelid = to_regclass('public.profiles')
        and trigger_row.tgname = 'tr_profiles_updated_at'
        and not trigger_row.tgisinternal
        and trigger_row.tgenabled = 'O'
        and trigger_row.tgfoid = to_regprocedure('public.update_updated_at()')
        and pg_get_triggerdef(trigger_row.oid, true) =
          'CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()'
    ) and exists (
      select 1
      from pg_proc as proc
      where proc.oid = to_regprocedure('public.update_updated_at()')
        and proc.proowner = 'postgres'::regrole
        and proc.prolang = (select oid from pg_language where lanname = 'plpgsql')
        and proc.provolatile = 'v'
        and not proc.prosecdef
        and proc.proconfig is null
        and proc.prorettype = 'trigger'::regtype
        and not proc.proretset
        and not proc.proisstrict
        and not proc.proleakproof
        and proc.proparallel = 'u'
        and proc.prokind = 'f'
        and md5(regexp_replace(proc.prosrc, '[[:space:]]+', '', 'g')) = 'd258fba5feeb9ce8126471bef81c3228'
        and pg_catalog.strpos(lower(proc.prosrc), 'new.updated_at = now()') > 0
        and pg_catalog.strpos(lower(proc.prosrc), 'return new') > 0
    ) as profile_timestamp_path_ready
), state as materialized (
  select
    (select count(*) from target_profiles) as target_handle_count,
    (select count(*) from target_owner_ids) as target_owner_count,
    coalesce((select max(profile_count) from owner_profile_counts), 0) as owner_profile_count,
    (select count(*) from target_users) as target_user_count,
    coalesce((select bool_and(role not in ('admin', 'super_admin')) from target_users), false) as target_role_safe,
    coalesce((select bool_and(banned_at is null and ban_reason is null and banned_by is null) from target_users), false) as target_unbanned_clean,
    coalesce((select bool_and(not is_suspended) from target_profiles), false) as target_profiles_unsuspended,
    (select count(distinct profile.user_id)
     from public.profiles as profile
     join public.users as app_user on app_user.id = profile.user_id
     where app_user.banned_at is null
       and profile.user_id <> 'eb616b4a-2b0e-4ad7-ba92-6d2b67f03287'::uuid) >= 2
      as two_other_unbanned_owners,
    (select required_tables_exist from catalog_checks) as required_tables_exist,
    (select admin_ban_rpc_requires_app_admin from catalog_checks) as admin_ban_rpc_requires_app_admin,
    (select admin_unban_rpc_requires_app_admin from catalog_checks) as admin_unban_rpc_requires_app_admin,
    (select hero_cleanup_trigger_ready from catalog_checks) as hero_cleanup_trigger_ready,
    (select hero_cleanup_function_ready from catalog_checks) as hero_cleanup_function_ready,
    (select post_invariant_path_ready from catalog_checks) as post_invariant_path_ready,
    (select profile_timestamp_path_ready from catalog_checks) as profile_timestamp_path_ready
), snapshots as materialized (
  select
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', u.id,
        'role', u.role,
        'banned_at', u.banned_at,
        'ban_reason', u.ban_reason,
        'banned_by', u.banned_by
      ) order by u.id)
      from target_users as u
    ), '[]'::jsonb) as user_preban_state,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'profile_id', p.id,
        'handle', p.handle,
        'is_suspended', p.is_suspended,
        'updated_at', p.updated_at
      ) order by p.id)
      from target_profiles as p
    ), '[]'::jsonb) as profile_preban_state,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'post_id', post.id,
        'is_hero_featured', post.is_hero_featured,
        'hero_featured_at', post.hero_featured_at,
        'hero_featured_by', post.hero_featured_by,
        'updated_at', post.updated_at
      ) order by post.id)
      from public.posts as post
      where post.profile_id in (select id from target_profiles)
        and post.is_hero_featured
    ), '[]'::jsonb) as hero_preban_state
), verdict as (
  select
    state.*,
    case when
      target_handle_count = 1
      and target_owner_count = 1
      and owner_profile_count = 1
      and target_user_count = 1
      and target_role_safe
      and target_unbanned_clean
      and target_profiles_unsuspended
      and two_other_unbanned_owners
      and required_tables_exist
      and admin_ban_rpc_requires_app_admin
      and admin_unban_rpc_requires_app_admin
      and hero_cleanup_trigger_ready
      and hero_cleanup_function_ready
      and post_invariant_path_ready
      and profile_timestamp_path_ready
    then 'GO' else 'STOP' end as overall_status
  from state
)
select
  'MP4_DARKTRIBO_BAN_FIXTURE_PREFLIGHT'::text as result_set,
  verdict.overall_status,
  array_remove(array[
    case when verdict.target_handle_count <> 1 then 'darktribo_handle_not_exactly_one' end,
    case when verdict.target_owner_count <> 1 then 'darktribo_owner_not_exactly_one' end,
    case when verdict.owner_profile_count <> 1 then 'darktribo_owner_profile_count_not_one' end,
    case when verdict.target_user_count <> 1 then 'darktribo_app_user_not_exactly_one' end,
    case when not verdict.target_role_safe then 'darktribo_is_admin_or_super_admin' end,
    case when not verdict.target_unbanned_clean then 'darktribo_not_cleanly_unbanned' end,
    case when not verdict.target_profiles_unsuspended then 'darktribo_profile_already_suspended' end,
    case when not verdict.two_other_unbanned_owners then 'two_unbanned_profile_owners_would_not_remain' end,
    case when not verdict.required_tables_exist then 'required_table_missing' end,
    case when not verdict.admin_ban_rpc_requires_app_admin then 'admin_ban_rpc_caller_guard_drift' end,
    case when not verdict.admin_unban_rpc_requires_app_admin then 'admin_unban_rpc_caller_guard_drift' end,
    case when not verdict.hero_cleanup_trigger_ready then 'hero_cleanup_trigger_missing_or_disabled' end,
    case when not verdict.hero_cleanup_function_ready then 'hero_cleanup_function_drift' end,
    case when not verdict.post_invariant_path_ready then 'post_invariant_trigger_or_function_drift' end,
    case when not verdict.profile_timestamp_path_ready then 'profile_timestamp_trigger_or_function_drift' end
  ], null) as findings,
  snapshots.user_preban_state,
  snapshots.profile_preban_state,
  snapshots.hero_preban_state,
  jsonb_array_length(snapshots.hero_preban_state) as hero_preban_count,
  'Save this complete row for comparison with UNBAN-VERIFY.'::text as operator_note
from verdict
cross join snapshots;
