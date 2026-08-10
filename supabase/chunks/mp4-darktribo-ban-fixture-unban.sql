-- MP-4 @darktribo deny-path fixture — unban/restore reversible state
--
-- Run in the Supabase SQL Editor as project owner after the approved MP-4
-- verification ritual (or to abort the fixture before MP-4 apply).
--
-- This script clears only the exact fixture ban marker and restores every
-- target profile to is_suspended = false. It refuses to clear an unrelated
-- real ban. A second run after successful cleanup is a safe no-op.
--
-- Recovery boundary: if the exact fixture ban marker remains, this script
-- clears it and unsuspends the exact approved profile even if suspension was
-- already cleared. Any other partial/real moderation state is fail-closed and
-- requires owner review; the exception says so plainly.
--
-- Restoration limit: the suspension changes advance profiles.updated_at, and
-- Hero cleanup advances affected posts.updated_at while clearing Hero flag,
-- timestamp and actor values. This script does not guess or rewrite those
-- historical values. UNBAN-VERIFY displays them for comparison with PREFLIGHT.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $fixture_unban$
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
  owner_profile_count bigint;
begin
  if current_user <> 'postgres' or session_user <> 'postgres' then
    raise exception 'MP-4 @darktribo fixture unban requires project-owner postgres context';
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
    raise exception 'MP-4 @darktribo fixture unban dependency drift: profile timestamp trigger/function mismatch';
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
  for update of profile, app_user;

  if target_user_id is null then
    raise exception 'MP-4 @darktribo fixture unban refused: profile owner/app user missing';
  end if;

  perform 1
  from public.profiles as profile
  where profile.user_id = target_user_id
  for update;

  select count(*)
  into owner_profile_count
  from public.profiles as profile
  where profile.user_id = target_user_id;

  if owner_profile_count <> 1 then
    raise exception 'MP-4 @darktribo fixture unban refused: owner has % profiles, expected exactly one', owner_profile_count;
  end if;

  if target_role in ('admin', 'super_admin') then
    raise exception 'MP-4 @darktribo fixture unban refused: target role is %', target_role;
  end if;

  if target_banned_at is null
     and target_ban_reason is null
     and target_banned_by is null
     and not target_suspended then
    raise notice 'MP-4 @darktribo fixture already removed; no data changed';
  elsif target_banned_at is not null
        and target_ban_reason = fixture_reason
        and target_banned_by is null then
    update public.users as app_user
    set banned_at = null,
        ban_reason = null,
        banned_by = null
    where app_user.id = target_user_id;

    update public.profiles as profile
    set is_suspended = false
    where profile.user_id = target_user_id
      and profile.is_suspended;
  else
    raise exception 'MP-4 @darktribo fixture unban refused: ambiguous partial or unrelated moderation state; owner review/manual recovery required';
  end if;

  if not exists (
    select 1
    from public.users as app_user
    where app_user.id = target_user_id
      and app_user.banned_at is null
      and app_user.ban_reason is null
      and app_user.banned_by is null
      and app_user.role::text not in ('admin', 'super_admin')
  ) then
    raise exception 'MP-4 @darktribo fixture unban postcondition failed: app-user state mismatch';
  end if;

  if (select count(*) from public.profiles as profile where profile.user_id = target_user_id) <> 1
     or exists (
       select 1
       from public.profiles as profile
       where profile.user_id = target_user_id
         and profile.is_suspended
     ) then
    raise exception 'MP-4 @darktribo fixture unban postcondition failed: profile suspension mismatch';
  end if;
end;
$fixture_unban$;

commit;

select
  'MP4_DARKTRIBO_BAN_FIXTURE_UNBAN'::text as result_set,
  'RESTORED_OR_ALREADY_RESTORED'::text as status,
  'Ban fields and suspension are restored. profiles.updated_at, affected posts.updated_at, and cleared Hero metadata are not rewritten; run UNBAN-VERIFY and compare with PREFLIGHT.'::text as operator_note;
