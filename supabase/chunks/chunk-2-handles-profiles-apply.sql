begin;

-- Preflight: abort before changing anything if current profile data cannot
-- satisfy the new invariants or conflicts with a newly reserved route.
do $$
begin
  if exists (
    select 1
    from public.profiles p
    group by lower(btrim(p.handle))
    having count(*) > 1
  ) then
    raise exception 'Cannot create case-insensitive handle uniqueness: duplicates exist';
  end if;

  if exists (
    select 1
    from public.profiles p
    group by p.user_id
    having count(*) > 1
  ) then
    raise exception 'Cannot create one-profile-per-user uniqueness: duplicates exist';
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.handle <> lower(btrim(p.handle))
       or p.handle !~ '^[a-z0-9_]{3,30}$'
  ) then
    raise exception 'Cannot enforce handle format: non-normalized profiles exist';
  end if;

  if exists (
    select 1
    from public.profiles p
    where lower(p.handle) in (
      'about',
      'agb',
      'apparel',
      'categories',
      'category',
      'checkout',
      'datenschutz',
      'datenschutzerklaerung',
      'favorites',
      'festivals',
      'forgot_password',
      'follows',
      'impressum',
      'jewellery',
      'listing',
      'listings',
      'magazin',
      'magazine',
      'messages',
      'notifications',
      'payment',
      'payments',
      'reset_password',
      'reviews',
      'safety',
      'safety_tips',
      'search',
      'seller',
      'tickets'
    )
  ) then
    raise exception 'A current profile conflicts with a route being reserved';
  end if;
end
$$;

-- Add current and frozen/planned V1 top-level routes not already present.
-- Existing blocked entries are retained unchanged.
insert into public.blocked_handles (handle)
values
  ('about'),
  ('agb'),
  ('apparel'),
  ('categories'),
  ('category'),
  ('checkout'),
  ('datenschutz'),
  ('datenschutzerklaerung'),
  ('favorites'),
  ('festivals'),
  ('forgot_password'),
  ('follows'),
  ('impressum'),
  ('jewellery'),
  ('listing'),
  ('listings'),
  ('magazin'),
  ('magazine'),
  ('messages'),
  ('notifications'),
  ('payment'),
  ('payments'),
  ('reset_password'),
  ('reviews'),
  ('safety'),
  ('safety_tips'),
  ('search'),
  ('seller'),
  ('tickets')
on conflict (handle) do nothing;

-- The signup client reads only the handle column for availability feedback.
-- Enforcement does not rely on this policy; the profile trigger below is final.
grant select (handle) on public.blocked_handles to anon, authenticated;

drop policy if exists "Blocked handles are publicly readable"
  on public.blocked_handles;

create policy "Blocked handles are publicly readable"
on public.blocked_handles
for select
to anon, authenticated
using (true);

-- Database-level final enforcement for every profile INSERT or handle UPDATE,
-- including service-role writes from the server signup route.
create or replace function public.enforce_profile_handle()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  new.handle := lower(btrim(new.handle));

  if new.handle is null
     or new.handle !~ '^[a-z0-9_]{3,30}$' then
    raise exception 'Handle must contain 3-30 lowercase letters, numbers, or underscores';
  end if;

  if exists (
    select 1
    from public.blocked_handles b
    where lower(b.handle) = new.handle
  ) then
    raise exception 'Handle is reserved';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_profile_handle() from public;
revoke execute on function public.enforce_profile_handle() from anon, authenticated;
grant execute on function public.enforce_profile_handle() to service_role;

drop trigger if exists profiles_enforce_handle
  on public.profiles;

create trigger profiles_enforce_handle
before insert or update of handle
on public.profiles
for each row
execute function public.enforce_profile_handle();

-- Existing data passed the preflight. These indexes enforce the V1 invariants.
create unique index profiles_handle_lower_key
  on public.profiles (lower(handle));

create unique index profiles_one_per_user_key
  on public.profiles (user_id);

-- Preserve existing handle_new_user behavior while making its execution
-- context explicit and safe. The profile trigger validates every chosen handle.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  reserved_handle text;
  assigned_handle text;
  meta_handle text;
begin
  insert into public.users (id, role, email_notifications, created_at)
  values (new.id, 'user', true, now());

  meta_handle := lower(btrim(coalesce(new.raw_user_meta_data->>'handle', '')));

  if meta_handle <> '' then
    assigned_handle := meta_handle;
  else
    select rh.handle
      into reserved_handle
    from public.reserved_handles rh
    where rh.email = new.email
      and rh.consumed = false
      and rh.expires_at > now()
    order by rh.reserved_at desc
    limit 1;

    if reserved_handle is not null then
      update public.reserved_handles rh
      set consumed = true,
          consumed_at = now()
      where rh.email = new.email
        and rh.handle = reserved_handle
        and rh.consumed = false;

      assigned_handle := reserved_handle;
    else
      assigned_handle := 'user_' || substr(new.id::text, 1, 8);
    end if;
  end if;

  insert into public.profiles (
    user_id,
    type,
    handle,
    display_name,
    created_at,
    updated_at
  )
  values (
    new.id,
    'personal',
    assigned_handle,
    coalesce(new.raw_user_meta_data->>'full_name', 'New User'),
    now(),
    now()
  );

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;
revoke execute on function public.handle_new_user() from anon, authenticated;
grant execute on function public.handle_new_user() to service_role;

commit;
