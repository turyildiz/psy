-- psy.market R2 migration Step 10
-- OWNER-APPLIED TRANSACTIONAL ROLLBACK
--
-- STOP unless all three original Supabase source objects still return HTTP 200
-- and exactly match these approved values:
--   * Turgay avatar: image/jpeg, 117243 bytes,
--     SHA-256 60b837ffc1b445c11268dfb25735083524fe08fa932f625a6e7c4b5794cc30f9
--   * Turgay header: image/jpeg, 216455 bytes,
--     SHA-256 7faeadabcb744153b3c50afdcecbb551af0f64cba733e306a07c1c35dc729c82
--   * Otis avatar: image/jpeg, 130087 bytes,
--     SHA-256 1d8a7d7260229ba24638139aeaeaf5d7d04b734c616b08b09005a39092e5f8ce
--
-- This rollback:
--   * locks exactly two target rows;
--   * requires the exact Step 10 R2 state;
--   * restores exactly three original Supabase URLs;
--   * aborts the complete transaction on any mismatch;
--   * does not delete any R2 object.

begin;
set transaction isolation level serializable;
set local lock_timeout = '10s';
set local statement_timeout = '30s';

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

do $step10_rollback$
declare
  v_target_rows integer;
  v_turgay_rows integer;
  v_otis_rows integer;
  v_reverted_rows integer;
  v_reverted_fields integer;
  v_r2_reference_count integer;
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
      'Step 10 rollback aborted: expected exactly 2 locked profiles, found %',
      v_target_rows;
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
      'Step 10 rollback aborted: Turgay identity or R2 avatar/header state differs';
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
      'Step 10 rollback aborted: Otis identity or R2 avatar state differs';
  end if;

  -- Verify that the approved R2 URLs occur exactly three times before removing
  -- the expected profile references.
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
  into v_r2_reference_count
  from media_references
  where value in (
    'https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg',
    'https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg',
    'https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'
  );

  if v_r2_reference_count <> 3 then
    raise exception
      'Step 10 rollback aborted: expected exactly 3 approved R2 references, found %',
      v_r2_reference_count;
  end if;

  update public.profiles
  set
    avatar_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg',
    header_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg'
  where id = 'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid
    and user_id = 'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid
    and handle = 'turgay'
    and avatar_url = 'https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg'
    and header_url = 'https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg';

  get diagnostics v_turgay_rows = row_count;

  if v_turgay_rows <> 1 then
    raise exception
      'Step 10 rollback aborted: expected 1 Turgay row, reverted %',
      v_turgay_rows;
  end if;

  update public.profiles
  set
    avatar_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif'
  where id = 'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
    and user_id = '7aba9d97-2572-4f40-9858-27c3892191cb'::uuid
    and handle = 'otis'
    and avatar_url = 'https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg';

  get diagnostics v_otis_rows = row_count;

  if v_otis_rows <> 1 then
    raise exception
      'Step 10 rollback aborted: expected 1 Otis row, reverted %',
      v_otis_rows;
  end if;

  v_reverted_rows := v_turgay_rows + v_otis_rows;
  v_reverted_fields := (v_turgay_rows * 2) + v_otis_rows;

  if v_reverted_rows <> 2 or v_reverted_fields <> 3 then
    raise exception
      'Step 10 rollback aborted: expected 2 rows / 3 fields, got % rows / % fields',
      v_reverted_rows,
      v_reverted_fields;
  end if;

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
      'Step 10 rollback aborted: Turgay final Supabase state is not exact';
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
      'Step 10 rollback aborted: Otis final Supabase state is not exact';
  end if;
end
$step10_rollback$;

-- Inspectable final rollback state. This runs before COMMIT.
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
