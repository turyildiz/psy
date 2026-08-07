-- psy.market database Chunk 11
-- READ-ONLY PRE-APPLY PREFLIGHT: Wall data model package
--
-- Status: COMPLETED before owner application of Chunk 11A.
-- This script performs no writes. Expected: exactly one row with
-- all_preflight_checks_pass = true.

begin transaction isolation level repeatable read read only;

with
roles_and_owner as (
  select
    current_user = 'postgres' as running_as_postgres,
    coalesce((
      select not r.rolsuper and r.rolbypassrls
      from pg_roles r
      where r.rolname = 'postgres'
    ), false) as postgres_is_expected_bypass_owner,
    (
      select count(*) = 4
      from pg_roles r
      where r.rolname in ('anon', 'authenticated', 'service_role', 'audit_readonly')
    ) as required_api_roles_exist
),
base_relations as (
  select
    to_regclass('public.users') is not null as users_exists,
    to_regclass('public.profiles') is not null as profiles_exists,
    to_regclass('public.follows') is not null as follows_exists,
    to_regclass('auth.users') is not null as auth_users_exists
),
follows_state as (
  select
    coalesce((
      select
        c.relkind = 'r'
        and c.relowner = 'postgres'::regrole
        and c.relrowsecurity
        and not c.relforcerowsecurity
      from pg_class c
      where c.oid = to_regclass('public.follows')
    ), false) as follows_owner_and_rls_match,
    coalesce((
      select count(*) = 4
      from pg_attribute a
      where a.attrelid = to_regclass('public.follows')
        and a.attnum > 0
        and not a.attisdropped
        and (
          (a.attname = 'id' and a.atttypid = 'uuid'::regtype and a.attnotnull)
          or (a.attname = 'follower_profile_id' and a.atttypid = 'uuid'::regtype and a.attnotnull)
          or (a.attname = 'following_profile_id' and a.atttypid = 'uuid'::regtype and a.attnotnull)
          or (a.attname = 'created_at' and a.atttypid = 'timestamp with time zone'::regtype and not a.attnotnull)
        )
    ), false) as follows_columns_match,
    coalesce((
      select count(*) = 5
      from pg_constraint c
      where c.conrelid = to_regclass('public.follows')
        and c.convalidated
        and c.conname in (
          'follows_pkey',
          'follows_check',
          'follows_follower_profile_id_fkey',
          'follows_following_profile_id_fkey',
          'follows_follower_profile_id_following_profile_id_key'
        )
    ), false) as follows_core_constraints_match,
    coalesce((
      select count(*) = 3
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'follows'
        and p.permissive = 'PERMISSIVE'
        and (
          (
            p.policyname = 'follows_select'
            and p.cmd = 'SELECT'
            and p.roles = array['public'::name]
            and md5(coalesce(p.qual, '')) = 'b326b5062b2f0e69046810717534cb09'
            and p.with_check is null
          )
          or (
            p.policyname = 'Unbanned users follow from own profile'
            and p.cmd = 'INSERT'
            and p.roles = array['authenticated'::name]
            and p.qual is null
            and md5(coalesce(p.with_check, '')) = '5ac7eaf7775c67c6dde36eca809ad58a'
          )
          or (
            p.policyname = 'Unbanned users unfollow from own profile'
            and p.cmd = 'DELETE'
            and p.roles = array['authenticated'::name]
            and md5(coalesce(p.qual, '')) = '5ac7eaf7775c67c6dde36eca809ad58a'
            and p.with_check is null
          )
        )
    ), false) as follows_policies_match,
    coalesce((
      select count(*) = 0
      from public.follows f
      where f.created_at is null
    ), false) as follows_has_no_null_created_at,
    coalesce((
      select c.relacl::text =
        '{postgres=arwdDxtm/postgres,anon=arwdDxtm/postgres,authenticated=arwdDxtm/postgres,service_role=arwdDxtm/postgres,audit_readonly=r/postgres}'
      from pg_class c
      where c.oid = to_regclass('public.follows')
    ), false) as follows_direct_acl_exact
),
identity_shape as (
  select
    coalesce((
      select count(*) = 2
      from pg_attribute a
      where a.attrelid = to_regclass('public.profiles')
        and a.attnum > 0
        and not a.attisdropped
        and (
          (a.attname = 'id' and a.atttypid = 'uuid'::regtype and a.attnotnull)
          or (a.attname = 'user_id' and a.atttypid = 'uuid'::regtype and a.attnotnull)
        )
    ), false) as profile_identity_columns_match,
    coalesce((
      select count(*) = 3
      from pg_attribute a
      where a.attrelid = to_regclass('public.users')
        and a.attnum > 0
        and not a.attisdropped
        and (
          (a.attname = 'id' and a.atttypid = 'uuid'::regtype and a.attnotnull)
          or (a.attname = 'role' and a.atttypid = 'public.user_role'::regtype and a.attnotnull)
          or (a.attname = 'banned_at' and a.atttypid = 'timestamp with time zone'::regtype)
        )
    ), false) as user_ban_columns_match,
    coalesce((
      select count(*) = 1
      from pg_constraint c
      where c.conrelid = to_regclass('public.profiles')
        and c.confrelid = to_regclass('auth.users')
        and c.contype = 'f'
        and c.convalidated
        and pg_get_constraintdef(c.oid, true)
          like 'FOREIGN KEY (user_id) REFERENCES auth.users(id)%'
    ), false) as profile_auth_user_fk_exists,
    coalesce((
      select count(*) = 1
      from pg_constraint c
      where c.conrelid = to_regclass('public.users')
        and c.confrelid = to_regclass('auth.users')
        and c.contype = 'f'
        and c.convalidated
        and pg_get_constraintdef(c.oid, true)
          like 'FOREIGN KEY (id) REFERENCES auth.users(id)%'
    ), false) as app_user_auth_user_fk_exists,
    not exists (
      select 1
      from public.profiles as p
      left join public.users as u on u.id = p.user_id
      where u.id is null
    ) as every_profile_has_app_user_row
),
existing_auth_helpers as (
  select
    to_regprocedure('public.current_user_is_admin()') is not null as admin_helper_exists,
    to_regprocedure('public.current_user_is_banned()') is not null as ban_helper_exists
),
new_objects_absent as (
  select
    to_regclass('public.posts') is null as posts_absent,
    to_regclass('public.post_reactions') is null as reactions_absent,
    to_regclass('public.post_moderation_audit') is null as audit_absent,
    to_regclass('public.post_link_blocklist') is null as blocklist_absent,
    to_regclass('public.post_write_rate_limits') is null as rate_limits_absent,
    not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in (
          'normalize_post_link_domain',
          'is_valid_post_reaction_code',
          'post_image_array_has_unique_values',
          'profile_owner_is_banned',
          'current_user_can_read_post_author',
          'post_images_belong_to_profile',
          'post_body_passes_link_blocklist',
          'consume_post_write_rate_limit',
          'admin_block_post_link_domain',
          'admin_unblock_post_link_domain',
          'enforce_post_write_invariants',
          'clear_hero_on_author_ban',
          'create_post',
          'update_post',
          'delete_own_post',
          'admin_flag_post_for_hero',
          'admin_unflag_post_for_hero',
          'current_user_can_read_post_reaction',
          'guard_post_reaction_identity',
          'set_post_reaction',
          'remove_post_reaction',
          'admin_delete_post'
        )
    ) as new_function_names_absent,
    not exists (
      select 1
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      where not t.tgisinternal
        and n.nspname = 'public'
        and t.tgname in (
          'enforce_post_write_invariants_trigger',
          'clear_hero_on_author_ban_trigger',
          'guard_post_reaction_identity_trigger'
        )
    ) as new_trigger_names_absent,
    not exists (
      select 1
      from pg_policy p
      where p.polname in (
        'Active admins read post link blocklist',
        'Visible posts are publicly readable',
        'Visible reactions are publicly readable',
        'Active admins read post moderation audit'
      )
    ) as new_policy_names_absent,
    to_regclass('public.posts_profile_created_id_idx') is null
      and to_regclass('public.posts_stream_created_id_idx') is null
      and to_regclass('public.posts_hero_featured_id_idx') is null
      and to_regclass('public.post_reactions_post_code_idx') is null
      and to_regclass('public.post_moderation_audit_post_idx') is null
      and to_regclass('public.post_moderation_audit_created_id_idx') is null
      and to_regclass('public.post_moderation_audit_deleted_by_created_idx') is null
      as new_index_names_absent
),
checks as (
  select ra.*, br.*, fs.*, ids.*, eah.*, noa.*
  from roles_and_owner ra
  cross join base_relations br
  cross join follows_state fs
  cross join identity_shape ids
  cross join existing_auth_helpers eah
  cross join new_objects_absent noa
)
select
  checks.*,
  (
    running_as_postgres
    and postgres_is_expected_bypass_owner
    and required_api_roles_exist
    and users_exists
    and profiles_exists
    and follows_exists
    and auth_users_exists
    and follows_owner_and_rls_match
    and follows_columns_match
    and follows_core_constraints_match
    and follows_policies_match
    and follows_has_no_null_created_at
    and follows_direct_acl_exact
    and profile_identity_columns_match
    and user_ban_columns_match
    and profile_auth_user_fk_exists
    and app_user_auth_user_fk_exists
    and every_profile_has_app_user_row
    and admin_helper_exists
    and ban_helper_exists
    and posts_absent
    and reactions_absent
    and audit_absent
    and blocklist_absent
    and rate_limits_absent
    and new_function_names_absent
    and new_trigger_names_absent
    and new_policy_names_absent
    and new_index_names_absent
  ) as all_preflight_checks_pass
from checks;

rollback;
