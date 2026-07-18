-- psy.market R2 migration Step 10
-- OWNER-APPLIED TRANSACTIONAL DATABASE SWITCH
--
-- STOP unless the read-only preflight and external R2 verification both pass.
--
-- This script:
--   * locks exactly two target profile rows;
--   * switches exactly three URL fields;
--   * treats Turgay avatar + header as one guarded row transition;
--   * aborts the complete transaction on every mismatch;
--   * does not delete any source object.
--
-- Expected automatic side effect:
--   tr_profiles_updated_at will update updated_at on the two changed rows.

begin;
set transaction isolation level serializable;
set local lock_timeout = '10s';
set local statement_timeout = '30s';

-- Lock the two target rows before validation or update.
-- The deterministic order avoids inconsistent lock order.
select
  id,
  user_id,
  handle,
  avatar_url,
  header_url
from public.profiles
where id in (
  'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid,
  'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
)
order by id
for update;

do $step10_apply$
declare
  v_target_rows integer;
  v_turgay_rows integer;
  v_otis_rows integer;
  v_switched_rows integer;
  v_switched_fields integer;
  v_existing_destination_references integer;
begin
  select count(*)
  into v_target_rows
  from public.profiles
  where id in (
    'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid,
    'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
  );

  if v_target_rows <> 2 then
    raise exception
      'Step 10 aborted: expected exactly 2 locked target profiles, found %',
      v_target_rows;
  end if;

  -- Turgay's avatar and header are one inseparable guarded transition.
  if not exists (
    select 1
    from public.profiles
    where id = 'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid
      and user_id = 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid
      and handle = 'turgay'
      and avatar_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg'
      and header_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg'
  ) then
    raise exception
      'Step 10 aborted: Turgay profile identity or old avatar/header state differs from the approved manifest';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = 'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
      and user_id = '7aba9d97-2572-4f40-9858-27c3892191cb'::uuid
      and handle = 'otis'
      and avatar_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif'
  ) then
    raise exception
      'Step 10 aborted: Otis profile identity or old avatar state differs from the approved manifest';
  end if;

  -- No approved destination may already be referenced anywhere in the known
  -- application media-reference schema.
  with media_references(value) as (
    select avatar_url from public.profiles
    union all
    select header_url from public.profiles
    union all
    select i.value
    from public.listings l
    cross join lateral unnest(l.images) as i(value)
    union all
    select cover_image_url from public.events
    union all
    select logo_url from public.events
    union all
    select image_url from public.featured_sellers
  )
  select count(*)
  into v_existing_destination_references
  from media_references
  where value in (
    'https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg',
    'https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg',
    'https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'
  );

  if v_existing_destination_references <> 0 then
    raise exception
      'Step 10 aborted: expected 0 existing destination references, found %',
      v_existing_destination_references;
  end if;

  update public.profiles
  set
    avatar_url = 'https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg',
    header_url = 'https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg'
  where id = 'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid
    and user_id = 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid
    and handle = 'turgay'
    and avatar_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg'
    and header_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg';

  get diagnostics v_turgay_rows = row_count;

  if v_turgay_rows <> 1 then
    raise exception
      'Step 10 aborted: expected exactly 1 Turgay row transition, switched %',
      v_turgay_rows;
  end if;

  update public.profiles
  set
    avatar_url = 'https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'
  where id = 'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
    and user_id = '7aba9d97-2572-4f40-9858-27c3892191cb'::uuid
    and handle = 'otis'
    and avatar_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif';

  get diagnostics v_otis_rows = row_count;

  if v_otis_rows <> 1 then
    raise exception
      'Step 10 aborted: expected exactly 1 Otis row transition, switched %',
      v_otis_rows;
  end if;

  v_switched_rows := v_turgay_rows + v_otis_rows;
  v_switched_fields := (v_turgay_rows * 2) + v_otis_rows;

  if v_switched_rows <> 2 or v_switched_fields <> 3 then
    raise exception
      'Step 10 aborted: expected 2 rows / 3 fields, got % rows / % fields',
      v_switched_rows,
      v_switched_fields;
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = 'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid
      and user_id = 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid
      and handle = 'turgay'
      and avatar_url = 'https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg'
      and header_url = 'https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg'
  ) then
    raise exception
      'Step 10 aborted: Turgay final state does not exactly match the approved R2 values';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = 'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
      and user_id = '7aba9d97-2572-4f40-9858-27c3892191cb'::uuid
      and handle = 'otis'
      and avatar_url = 'https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'
  ) then
    raise exception
      'Step 10 aborted: Otis final state does not exactly match the approved R2 value';
  end if;
end
$step10_apply$;

-- Inspectable final state. This runs before COMMIT.
select
  id,
  user_id,
  handle,
  avatar_url,
  header_url,
  updated_at
from public.profiles
where id in (
  'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid,
  'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
)
order by id;

commit;
