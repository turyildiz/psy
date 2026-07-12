begin;

-- Restore captured handle_new_user definition and execution grants.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
declare
  reserved_handle text;
  assigned_handle text;
  meta_handle text;
begin
  insert into public.users (id, role, email_notifications, created_at)
  values (new.id, 'user', true, now());

  meta_handle := lower(trim(coalesce(new.raw_user_meta_data->>'handle', '')));

  if meta_handle != '' then
    assigned_handle := meta_handle;
  else
    select handle into reserved_handle
    from public.reserved_handles
    where email = new.email
      and consumed = false
      and expires_at > now()
    order by reserved_at desc
    limit 1;

    if reserved_handle is not null then
      update public.reserved_handles
      set consumed = true, consumed_at = now()
      where email = new.email
        and handle = reserved_handle
        and consumed = false;

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

grant execute on function public.handle_new_user()
  to public, anon, authenticated, service_role;

drop trigger if exists profiles_enforce_handle
  on public.profiles;

drop function if exists public.enforce_profile_handle();

drop index if exists public.profiles_one_per_user_key;
drop index if exists public.profiles_handle_lower_key;

drop policy if exists "Blocked handles are publicly readable"
  on public.blocked_handles;

revoke select (handle) on public.blocked_handles
  from anon, authenticated;

-- Remove only the entries introduced by Chunk 2. The original 56 blocked
-- handles are not touched.
delete from public.blocked_handles
where handle in (
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
);

commit;
