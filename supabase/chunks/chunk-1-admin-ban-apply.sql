begin;

-- Account-level ban state.
alter table public.users
  add column if not exists banned_at timestamptz,
  add column if not exists ban_reason text,
  add column if not exists banned_by uuid;

alter table public.users
  drop constraint if exists users_banned_by_fkey;

alter table public.users
  add constraint users_banned_by_fkey
  foreign key (banned_by)
  references public.users(id)
  on delete set null;

alter table public.users
  drop constraint if exists users_ban_state_consistent;

alter table public.users
  add constraint users_ban_state_consistent
  check (
    (
      banned_at is null
      and ban_reason is null
      and banned_by is null
    )
    or
    (
      banned_at is not null
      and ban_reason is not null
      and char_length(btrim(ban_reason)) between 3 and 500
    )
  );

-- At most one super_admin can exist.
create unique index if not exists users_one_super_admin_key
  on public.users (role)
  where role = 'super_admin'::public.user_role;

-- Safe authorization helpers for later RLS chunks and server/UI checks.
create or replace function public.current_user_is_banned()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select coalesce(
    (
      select u.banned_at is not null
      from public.users u
      where u.id = auth.uid()
    ),
    false
  );
$$;

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select coalesce(
    (
      select u.role in ('admin', 'super_admin')
      from public.users u
      where u.id = auth.uid()
        and u.banned_at is null
    ),
    false
  );
$$;

create or replace function public.current_user_is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select coalesce(
    (
      select u.role = 'super_admin'
      from public.users u
      where u.id = auth.uid()
        and u.banned_at is null
    ),
    false
  );
$$;

-- Only the super_admin can appoint an admin.
create or replace function public.super_admin_appoint_admin(
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if not public.current_user_is_super_admin() then
    raise exception 'Super admin access required';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'The super admin already has all admin rights';
  end if;

  if not exists (
    select 1 from public.users u where u.id = target_user_id
  ) then
    raise exception 'Target user does not exist';
  end if;

  if exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and u.role = 'super_admin'
  ) then
    raise exception 'Cannot modify the super admin through this RPC';
  end if;

  update public.users
  set role = 'admin'::public.user_role
  where id = target_user_id;
end;
$$;

-- Only the super_admin can remove an admin.
create or replace function public.super_admin_remove_admin(
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if not public.current_user_is_super_admin() then
    raise exception 'Super admin access required';
  end if;

  if not exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and u.role = 'admin'
  ) then
    raise exception 'Target user is not an admin';
  end if;

  update public.users
  set role = 'user'::public.user_role
  where id = target_user_id
    and role = 'admin'::public.user_role;
end;
$$;

-- Admins and the super_admin have identical ban rights.
-- Neither can ban the super_admin or themselves.
create or replace function public.admin_ban_user(
  target_user_id uuid,
  reason text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  normalized_reason text := btrim(reason);
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'Admins cannot ban themselves';
  end if;

  if not exists (
    select 1 from public.users u where u.id = target_user_id
  ) then
    raise exception 'Target user does not exist';
  end if;

  if exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and u.role = 'super_admin'
  ) then
    raise exception 'The super admin cannot be banned';
  end if;

  if normalized_reason is null
     or char_length(normalized_reason) not between 3 and 500 then
    raise exception 'Ban reason must contain between 3 and 500 characters';
  end if;

  update public.users
  set banned_at = now(),
      ban_reason = normalized_reason,
      banned_by = auth.uid()
  where id = target_user_id;

  -- Compatibility bridge for the current Chunk 0 listing policy.
  -- Later RLS chunks will use public.users.banned_at directly.
  update public.profiles
  set is_suspended = true
  where user_id = target_user_id;
end;
$$;

create or replace function public.admin_unban_user(
  target_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  if not exists (
    select 1 from public.users u where u.id = target_user_id
  ) then
    raise exception 'Target user does not exist';
  end if;

  if exists (
    select 1
    from public.users u
    where u.id = target_user_id
      and u.role = 'super_admin'
  ) then
    raise exception 'The super admin cannot be modified through this RPC';
  end if;

  update public.users
  set banned_at = null,
      ban_reason = null,
      banned_by = null
  where id = target_user_id;

  update public.profiles
  set is_suspended = false
  where user_id = target_user_id;
end;
$$;

-- Remove default PUBLIC/anon execution and expose only to signed-in users
-- and trusted service-role code. Each RPC performs its own role check.
revoke all on function public.current_user_is_banned() from public;
revoke all on function public.current_user_is_admin() from public;
revoke all on function public.current_user_is_super_admin() from public;
revoke all on function public.super_admin_appoint_admin(uuid) from public;
revoke all on function public.super_admin_remove_admin(uuid) from public;
revoke all on function public.admin_ban_user(uuid, text) from public;
revoke all on function public.admin_unban_user(uuid) from public;

revoke execute on function public.current_user_is_banned() from anon;
revoke execute on function public.current_user_is_admin() from anon;
revoke execute on function public.current_user_is_super_admin() from anon;
revoke execute on function public.super_admin_appoint_admin(uuid) from anon;
revoke execute on function public.super_admin_remove_admin(uuid) from anon;
revoke execute on function public.admin_ban_user(uuid, text) from anon;
revoke execute on function public.admin_unban_user(uuid) from anon;

grant execute on function public.current_user_is_banned()
  to authenticated, service_role;
grant execute on function public.current_user_is_admin()
  to authenticated, service_role;
grant execute on function public.current_user_is_super_admin()
  to authenticated, service_role;
grant execute on function public.super_admin_appoint_admin(uuid)
  to authenticated, service_role;
grant execute on function public.super_admin_remove_admin(uuid)
  to authenticated, service_role;
grant execute on function public.admin_ban_user(uuid, text)
  to authenticated, service_role;
grant execute on function public.admin_unban_user(uuid)
  to authenticated, service_role;

-- Admins may inspect app-level role/ban state. Existing users retain
-- their own-row SELECT policy.
drop policy if exists "Admins can read app users" on public.users;
create policy "Admins can read app users"
on public.users
for select
to authenticated
using (public.current_user_is_admin());

-- Bootstrap the single super_admin to the existing turgay account.
do $$
begin
  if not exists (
    select 1
    from public.users u
    join public.profiles p on p.user_id = u.id
    where u.id = 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid
      and p.id = 'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid
      and p.handle = 'turgay'
  ) then
    raise exception 'Expected turgay account/profile was not found';
  end if;

  if exists (
    select 1
    from public.users u
    where u.role = 'super_admin'
      and u.id <> 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid
  ) then
    raise exception 'A different super admin already exists';
  end if;

  update public.users
  set role = 'super_admin'::public.user_role
  where id = 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid;
end
$$;

commit;
