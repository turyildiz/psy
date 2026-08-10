-- MP-4 @darktribo deny-path fixture — apply temporary DB ban
--
-- Run in the Supabase SQL Editor as project owner only after PREFLIGHT = GO.
-- DB-level ban only: Supabase Auth banned_until synchronization is deliberately
-- out of scope for this short-lived verification fixture.
--
-- Why this script does NOT call public.admin_ban_user:
-- the live RPC first requires public.current_user_is_admin(), which derives the
-- caller from auth.uid(). A project-owner SQL Editor session is PostgreSQL owner
-- context, not an authenticated application-admin JWT, so auth.uid() is NULL and
-- the RPC would correctly reject the call. This script therefore performs the
-- same two database mutations directly, behind exact target/state/owner guards.
-- The public.users update intentionally fires clear_hero_on_author_ban_trigger.
-- That trigger clears Hero metadata and advances affected posts.updated_at; the
-- profile suspension updates also advance profiles.updated_at. PREFLIGHT shows
-- those exact pre-ban values. UNBAN restores ban/suspension fields but does not
-- rewrite stale timestamps or recreate cleared Hero metadata. Trigger guards
-- compare exact reviewed definitions, normalized function-source hashes, and
-- security/runtime metadata again immediately before mutation.
--
-- Rerun behavior:
--   * exact fixture state: safe no-op followed by postcondition checks;
--   * any unrelated/partial ban: readable exception and full rollback.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- The marker makes the later UNBAN refuse to clear any unrelated real ban.
-- Keep this exact text synchronized with VERIFY and UNBAN.
do $fixture_apply$
declare
  fixture_reason constant text :=
    'MP-4 deny-path fixture for @darktribo; DB-only; remove with fixture unban';
  target_profile_id uuid;
  target_user_id uuid;
  target_role text;
  target_banned_at timestamptz;
  target_ban_reason text;
  target_banned_by uuid;
  target_suspended boolean;
  handle_count bigint;
  owner_profile_count bigint;
begin
  if current_user <> 'postgres' or session_user <> 'postgres' then
    raise exception 'MP-4 @darktribo fixture apply requires project-owner postgres context';
  end if;

  if not exists (
    select 1
    from pg_proc as proc
    join pg_namespace as ns on ns.oid = proc.pronamespace
    where ns.nspname = 'public'
      and proc.proname = 'admin_ban_user'
      and pg_get_function_identity_arguments(proc.oid) = 'target_user_id uuid, reason text'
      and proc.prosecdef
      and pg_catalog.strpos(proc.prosrc, 'current_user_is_admin') > 0
      and pg_catalog.strpos(proc.prosrc, 'auth.uid') > 0
  ) then
    raise exception 'MP-4 @darktribo fixture dependency drift: admin_ban_user caller guard mismatch';
  end if;

  if not exists (
    select 1
    from pg_trigger as trigger_row
    where trigger_row.tgrelid = to_regclass('public.users')
      and trigger_row.tgname = 'clear_hero_on_author_ban_trigger'
      and not trigger_row.tgisinternal
      and trigger_row.tgenabled = 'O'
      and trigger_row.tgfoid = to_regprocedure('public.clear_hero_on_author_ban()')
      and pg_get_triggerdef(trigger_row.oid, true) =
        'CREATE TRIGGER clear_hero_on_author_ban_trigger AFTER UPDATE OF banned_at ON users FOR EACH ROW WHEN (old.banned_at IS NULL AND new.banned_at IS NOT NULL) EXECUTE FUNCTION clear_hero_on_author_ban()'
  ) or not exists (
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
  ) then
    raise exception 'MP-4 @darktribo fixture dependency drift: Hero cleanup trigger/function mismatch';
  end if;

  if not exists (
    select 1
    from pg_trigger as trigger_row
    where trigger_row.tgrelid = to_regclass('public.posts')
      and trigger_row.tgname = 'enforce_post_write_invariants_trigger'
      and not trigger_row.tgisinternal
      and trigger_row.tgenabled = 'O'
      and trigger_row.tgfoid = to_regprocedure('public.enforce_post_write_invariants()')
      and pg_get_triggerdef(trigger_row.oid, true) =
        'CREATE TRIGGER enforce_post_write_invariants_trigger BEFORE INSERT OR UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION enforce_post_write_invariants()'
  ) or not exists (
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
  ) then
    raise exception 'MP-4 @darktribo fixture dependency drift: post invariant trigger/function mismatch';
  end if;

  if not exists (
    select 1
    from pg_trigger as trigger_row
    where trigger_row.tgrelid = to_regclass('public.profiles')
      and trigger_row.tgname = 'tr_profiles_updated_at'
      and not trigger_row.tgisinternal
      and trigger_row.tgenabled = 'O'
      and trigger_row.tgfoid = to_regprocedure('public.update_updated_at()')
      and pg_get_triggerdef(trigger_row.oid, true) =
        'CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()'
  ) or not exists (
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
  ) then
    raise exception 'MP-4 @darktribo fixture dependency drift: profile timestamp trigger/function mismatch';
  end if;

  select count(*)
  into handle_count
  from public.profiles as profile
  where lower(profile.handle) = lower('darktribo');

  if handle_count <> 1 then
    raise exception 'MP-4 @darktribo fixture refused: expected exactly one handle row, found %', handle_count;
  end if;

  select profile.id, profile.user_id, app_user.role::text,
         app_user.banned_at, app_user.ban_reason, app_user.banned_by,
         profile.is_suspended
  into target_profile_id, target_user_id, target_role,
       target_banned_at, target_ban_reason, target_banned_by,
       target_suspended
  from public.profiles as profile
  join public.users as app_user on app_user.id = profile.user_id
  where profile.id = 'c18d4b9f-012e-4fed-877b-ece6cbc19884'::uuid
    and profile.user_id = 'eb616b4a-2b0e-4ad7-ba92-6d2b67f03287'::uuid
    and profile.handle = 'darktribo'
  for update of profile, app_user;

  if target_user_id is null then
    raise exception 'MP-4 @darktribo fixture refused: profile owner/app user missing';
  end if;

  perform 1
  from public.profiles as profile
  where profile.user_id = target_user_id
  for update;

  select count(*)
  into owner_profile_count
  from public.profiles as profile
  where profile.user_id = target_user_id;

  -- Hold the target's post rows through the ban transition so the Hero cleanup
  -- and its postcondition cannot race a concurrent Hero update.
  perform 1
  from public.posts as post
  where post.profile_id = target_profile_id
  for update;

  if owner_profile_count <> 1 then
    raise exception 'MP-4 @darktribo fixture refused: owner has % profiles, expected exactly one', owner_profile_count;
  end if;

  if target_role in ('admin', 'super_admin') then
    raise exception 'MP-4 @darktribo fixture refused: target role is %', target_role;
  end if;

  if (
    select count(distinct profile.user_id)
    from public.profiles as profile
    join public.users as app_user on app_user.id = profile.user_id
    where app_user.banned_at is null
      and profile.user_id <> target_user_id
  ) < 2 then
    raise exception 'MP-4 @darktribo fixture refused: fewer than two other unbanned profile owners would remain';
  end if;

  if target_banned_at is not null
     and target_ban_reason = fixture_reason
     and target_banned_by is null
     and target_suspended then
    if exists (
      select 1
      from public.posts as post
      where post.profile_id = target_profile_id
        and post.is_hero_featured
    ) then
      raise exception 'MP-4 @darktribo fixture drift: exact ban marker exists but Hero cleanup is incomplete';
    end if;
    raise notice 'MP-4 @darktribo fixture already applied; no data changed';
  elsif target_banned_at is not null
        or target_ban_reason is not null
        or target_banned_by is not null
        or target_suspended then
    raise exception 'MP-4 @darktribo fixture refused: target is already banned, suspended, or partially drifted';
  else
    update public.users as app_user
    set banned_at = clock_timestamp(),
        ban_reason = fixture_reason,
        banned_by = null
    where app_user.id = target_user_id;

    update public.profiles as profile
    set is_suspended = true
    where profile.user_id = target_user_id;
  end if;

  if not exists (
    select 1
    from public.users as app_user
    where app_user.id = target_user_id
      and app_user.banned_at is not null
      and app_user.ban_reason = fixture_reason
      and app_user.banned_by is null
      and app_user.role::text not in ('admin', 'super_admin')
  ) then
    raise exception 'MP-4 @darktribo fixture apply postcondition failed: ban state mismatch';
  end if;

  if (select count(*) from public.profiles as profile where profile.user_id = target_user_id) <> 1
     or exists (
       select 1
       from public.profiles as profile
       where profile.user_id = target_user_id
         and not profile.is_suspended
     ) then
    raise exception 'MP-4 @darktribo fixture apply postcondition failed: suspension state mismatch';
  end if;

  if exists (
    select 1
    from public.posts as post
    where post.profile_id = target_profile_id
      and post.is_hero_featured
  ) then
    raise exception 'MP-4 @darktribo fixture apply postcondition failed: Hero cleanup did not complete';
  end if;
end;
$fixture_apply$;

commit;

select
  'MP4_DARKTRIBO_BAN_FIXTURE_APPLY'::text as result_set,
  'APPLIED_OR_ALREADY_APPLIED'::text as status,
  'DB ban and profile suspension are active; run fixture VERIFY next.'::text as operator_note;
