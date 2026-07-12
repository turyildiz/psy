begin;

-- Remove Chunk 1 policy before dropping the helper it depends on.
drop policy if exists "Admins can read app users" on public.users;

-- Clear compatibility suspension only for accounts currently marked banned
-- by the Chunk 1 account-level state.
update public.profiles p
set is_suspended = false
where p.user_id in (
  select u.id
  from public.users u
  where u.banned_at is not null
);

-- Restore the bootstrapped account to its pre-Chunk-1 role.
update public.users
set role = 'user'::public.user_role
where id = 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid
  and role = 'super_admin'::public.user_role;

drop function if exists public.admin_unban_user(uuid);
drop function if exists public.admin_ban_user(uuid, text);
drop function if exists public.super_admin_remove_admin(uuid);
drop function if exists public.super_admin_appoint_admin(uuid);
drop function if exists public.current_user_is_super_admin();
drop function if exists public.current_user_is_admin();
drop function if exists public.current_user_is_banned();

drop index if exists public.users_one_super_admin_key;

alter table public.users
  drop constraint if exists users_ban_state_consistent,
  drop constraint if exists users_banned_by_fkey,
  drop column if exists banned_by,
  drop column if exists ban_reason,
  drop column if exists banned_at;

commit;
