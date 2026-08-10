-- MP-4 @darktribo deny-path fixture — unban verification
--
-- Read-only. Run after UNBAN. Returns exactly one GO/STOP row.
--
-- GO means every mechanically reversible field is back at the required
-- pre-ban state: clean null ban fields, one non-admin owner/profile, and
-- is_suspended = false. profiles.updated_at, affected posts.updated_at, and
-- cleared Hero flag/timestamp/actor values are deliberately outside the GO
-- verdict: the package stores no durable snapshot from which to rewrite them
-- safely. Compare current_profile_state/current_target_post_state below with
-- profile_preban_state/hero_preban_state from the saved PREFLIGHT result. Any
-- difference is real and explicitly outside automatic restoration.

with target_profiles as materialized (
  select p.id, p.user_id, p.handle, p.is_suspended, p.updated_at
  from public.profiles as p
  where p.id = 'c18d4b9f-012e-4fed-877b-ece6cbc19884'::uuid
    and p.user_id = 'eb616b4a-2b0e-4ad7-ba92-6d2b67f03287'::uuid
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
), state as materialized (
  select
    (select count(*) from target_profiles) as target_handle_count,
    (select count(*) from target_owner_ids) as target_owner_count,
    coalesce((select max(profile_count) from owner_profile_counts), 0) as owner_profile_count,
    (select count(*) from target_users) as target_user_count,
    coalesce((select bool_and(handle = 'darktribo') from target_profiles), false) as target_handle_matches,
    coalesce((select bool_and(role not in ('admin', 'super_admin')) from target_users), false) as target_role_safe,
    coalesce((select bool_and(banned_at is null and ban_reason is null and banned_by is null) from target_users), false) as target_unbanned_clean,
    coalesce((select bool_and(not is_suspended) from target_profiles), false) as target_profiles_unsuspended,
    not exists (
      select 1
      from target_users as app_user
      where app_user.ban_reason = 'MP-4 deny-path fixture for @darktribo; DB-only; remove with fixture unban'
    ) as fixture_marker_removed
), current_snapshot as materialized (
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
    ), '[]'::jsonb) as current_user_state,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'profile_id', p.id,
        'handle', p.handle,
        'is_suspended', p.is_suspended,
        'updated_at', p.updated_at
      ) order by p.id)
      from target_profiles as p
    ), '[]'::jsonb) as current_profile_state,
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
    ), '[]'::jsonb) as current_target_post_state
), verdict as (
  select
    state.*,
    case when
      target_handle_count = 1
      and target_owner_count = 1
      and owner_profile_count = 1
      and target_user_count = 1
      and target_handle_matches
      and target_role_safe
      and target_unbanned_clean
      and target_profiles_unsuspended
      and fixture_marker_removed
    then 'GO' else 'STOP' end as overall_status
  from state
)
select
  'MP4_DARKTRIBO_BAN_FIXTURE_UNBAN_VERIFY'::text as result_set,
  verdict.overall_status,
  array_remove(array[
    case when verdict.target_handle_count <> 1 then 'darktribo_handle_not_exactly_one' end,
    case when verdict.target_owner_count <> 1 then 'darktribo_owner_not_exactly_one' end,
    case when verdict.owner_profile_count <> 1 then 'darktribo_owner_profile_count_not_one' end,
    case when verdict.target_user_count <> 1 then 'darktribo_app_user_not_exactly_one' end,
    case when not verdict.target_handle_matches then 'darktribo_handle_changed_from_preflight' end,
    case when not verdict.target_role_safe then 'darktribo_is_admin_or_super_admin' end,
    case when not verdict.target_unbanned_clean then 'ban_fields_not_restored' end,
    case when not verdict.target_profiles_unsuspended then 'profile_suspension_not_restored' end,
    case when not verdict.fixture_marker_removed then 'fixture_marker_not_removed' end
  ], null) as findings,
  current_snapshot.current_user_state,
  current_snapshot.current_profile_state,
  current_snapshot.current_target_post_state,
  (select count(*) from public.posts as post where post.profile_id in (select id from target_profiles) and post.is_hero_featured) as current_hero_featured_count,
  'MANUAL_COMPARISON_REQUIRED'::text as nonrestored_side_effect_status,
  'Ban fields and suspension are fully checked. profiles.updated_at, affected posts.updated_at, and cleared Hero metadata are not automatically restored; compare final snapshots with PREFLIGHT.'::text as restoration_note
from verdict
cross join current_snapshot;
