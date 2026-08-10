-- MP-4 @darktribo deny-path fixture — verify temporary DB ban
--
-- Read-only. Run after APPLY and before the MP-4 preflight.
-- This proves the exact fixture conditions consumed by MP-4:
-- at least one profile owner is banned and at least two distinct profile
-- owners remain unbanned.
-- It also proves the fixture belongs specifically to @darktribo and that the
-- profile suspension/Hero-cleanup side effects reached their expected state.
-- Returns exactly one GO/STOP row.

with target_profiles as materialized (
  select p.id, p.user_id, p.handle, p.is_suspended
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
), state as materialized (
  select
    (select count(*) from target_profiles) as target_handle_count,
    (select count(*) from target_owner_ids) as target_owner_count,
    coalesce((select max(profile_count) from owner_profile_counts), 0) as owner_profile_count,
    (select count(*) from target_users) as target_user_count,
    coalesce((select bool_and(role not in ('admin', 'super_admin')) from target_users), false) as target_role_safe,
    coalesce((select bool_and(
      banned_at is not null
      and ban_reason = 'MP-4 deny-path fixture for @darktribo; DB-only; remove with fixture unban'
      and banned_by is null
    ) from target_users), false) as exact_fixture_ban,
    coalesce((select bool_and(is_suspended) from target_profiles), false) as target_profiles_suspended,
    exists (
      select 1
      from public.profiles as profile
      join public.users as app_user on app_user.id = profile.user_id
      where app_user.banned_at is not null
    ) as mp4_banned_owner_fixture,
    (select count(distinct profile.user_id)
     from public.profiles as profile
     join public.users as app_user on app_user.id = profile.user_id
     where app_user.banned_at is null) >= 2 as mp4_two_unbanned_owners_fixture,
    not exists (
      select 1
      from public.posts as post
      where post.profile_id in (select id from target_profiles)
        and post.is_hero_featured
    ) as hero_cleanup_complete
), verdict as (
  select
    state.*,
    case when
      target_handle_count = 1
      and target_owner_count = 1
      and owner_profile_count = 1
      and target_user_count = 1
      and target_role_safe
      and exact_fixture_ban
      and target_profiles_suspended
      and mp4_banned_owner_fixture
      and mp4_two_unbanned_owners_fixture
      and hero_cleanup_complete
    then 'GO' else 'STOP' end as overall_status
  from state
)
select
  'MP4_DARKTRIBO_BAN_FIXTURE_VERIFY'::text as result_set,
  verdict.overall_status,
  case when verdict.mp4_banned_owner_fixture then 'GO' else 'STOP' end as mp4_banned_profile_owner_status,
  array_remove(array[
    case when verdict.target_handle_count <> 1 then 'darktribo_handle_not_exactly_one' end,
    case when verdict.target_owner_count <> 1 then 'darktribo_owner_not_exactly_one' end,
    case when verdict.owner_profile_count <> 1 then 'darktribo_owner_profile_count_not_one' end,
    case when verdict.target_user_count <> 1 then 'darktribo_app_user_not_exactly_one' end,
    case when not verdict.target_role_safe then 'darktribo_is_admin_or_super_admin' end,
    case when not verdict.exact_fixture_ban then 'exact_fixture_ban_missing_or_drifted' end,
    case when not verdict.target_profiles_suspended then 'darktribo_profile_not_suspended' end,
    case when not verdict.mp4_banned_owner_fixture then 'banned_profile_owner_unproven' end,
    case when not verdict.mp4_two_unbanned_owners_fixture then 'two_unbanned_profile_owners_unproven' end,
    case when not verdict.hero_cleanup_complete then 'hero_cleanup_incomplete' end
  ], null) as findings,
  (select count(*) from public.posts as post where post.profile_id in (select id from target_profiles) and post.is_hero_featured) as current_hero_featured_count,
  'If GO, rerun the existing MP-4 preflight; do not bypass any other STOP/UNPROVEN result.'::text as operator_note
from verdict;
