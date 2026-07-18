-- psy.market R2 migration Step 10
-- READ-ONLY POST-APPLY VERIFICATION
--
-- Expected:
--   * both target rows exact;
--   * exactly 2 profile rows and 3 R2 URL fields;
--   * zero approved old Supabase URLs in runtime media fields;
--   * deferred Yacxilan URL unchanged;
--   * staging profile handles: turgay and otis.

begin transaction isolation level repeatable read read only;

-- 1. Exact post-apply row state.
with expected (
  profile_id,
  owning_user_id,
  expected_handle,
  expected_avatar_url,
  expected_header_url,
  require_header_match
) as (
  values
    (
      'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid,
      'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid,
      'turgay'::text,
      'https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg'::text,
      'https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg'::text,
      true
    ),
    (
      'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid,
      '7aba9d97-2572-4f40-9858-27c3892191cb'::uuid,
      'otis'::text,
      'https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'::text,
      null::text,
      false
    )
)
select
  e.profile_id,
  e.owning_user_id,
  e.expected_handle,
  p.id is not null as row_exists,
  p.user_id = e.owning_user_id as user_id_matches,
  p.handle = e.expected_handle as handle_matches,
  p.avatar_url = e.expected_avatar_url as avatar_url_matches,
  case
    when e.require_header_match then p.header_url = e.expected_header_url
    else true
  end as header_url_matches,
  (
    p.id = e.profile_id
    and p.user_id = e.owning_user_id
    and p.handle = e.expected_handle
    and p.avatar_url = e.expected_avatar_url
    and (
      not e.require_header_match
      or p.header_url = e.expected_header_url
    )
  ) as row_state_matches
from expected e
left join public.profiles p on p.id = e.profile_id
order by e.profile_id;

-- 2. Exact two-row / three-field R2 scope.
with expected_urls(value) as (
  values
    ('https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg'::text),
    ('https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg'::text),
    ('https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'::text)
),
profile_fields as (
  select id, 'avatar_url'::text as field_name, avatar_url as value from public.profiles
  union all
  select id, 'header_url', header_url from public.profiles
),
matches as (
  select p.*
  from profile_fields p
  join expected_urls e on e.value = p.value
)
select
  count(distinct id) as switched_profile_rows,
  count(*) as switched_url_fields,
  count(distinct id) = 2 as exactly_two_rows,
  count(*) = 3 as exactly_three_fields
from matches;

-- Inspect the exact three resulting references.
with expected_urls(value) as (
  values
    ('https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg'::text),
    ('https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg'::text),
    ('https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'::text)
),
profile_fields as (
  select id, 'avatar_url'::text as field_name, avatar_url as value from public.profiles
  union all
  select id, 'header_url', header_url from public.profiles
)
select p.id, pr.handle, p.field_name, p.value
from profile_fields p
join expected_urls e on e.value = p.value
join public.profiles pr on pr.id = p.id
order by pr.handle, p.field_name;

-- 3. Approved old Supabase URLs must no longer appear in runtime media fields.
with old_urls(value) as (
  values
    ('https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg'::text),
    ('https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg'::text),
    ('https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif'::text)
),
runtime_media_references as (
  select 'profiles'::text table_name, id row_id, 'avatar_url'::text field_name, avatar_url value
  from public.profiles
  union all
  select 'profiles', id, 'header_url', header_url from public.profiles
  union all
  select 'listings', l.id, 'images[' || (i.ordinality - 1)::text || ']', i.value
  from public.listings l
  cross join lateral unnest(l.images) with ordinality as i(value, ordinality)
  union all
  select 'events', id, 'cover_image_url', cover_image_url from public.events
  union all
  select 'events', id, 'logo_url', logo_url from public.events
)
select
  count(*) as old_supabase_runtime_reference_count,
  count(*) = 0 as old_supabase_runtime_references_removed
from runtime_media_references r
join old_urls o on o.value = r.value;

-- Expected: zero rows.
with old_urls(value) as (
  values
    ('https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg'::text),
    ('https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg'::text),
    ('https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif'::text)
),
runtime_media_references as (
  select 'profiles'::text table_name, id row_id, 'avatar_url'::text field_name, avatar_url value
  from public.profiles
  union all
  select 'profiles', id, 'header_url', header_url from public.profiles
  union all
  select 'listings', l.id, 'images[' || (i.ordinality - 1)::text || ']', i.value
  from public.listings l
  cross join lateral unnest(l.images) with ordinality as i(value, ordinality)
  union all
  select 'events', id, 'cover_image_url', cover_image_url from public.events
  union all
  select 'events', id, 'logo_url', logo_url from public.events
)
select r.*
from runtime_media_references r
join old_urls o on o.value = r.value
order by r.table_name, r.row_id, r.field_name;

-- 4. Deferred Yacxilan reference must remain untouched.
select
  id,
  profile_id,
  image_url,
  (
    id = 'af51e0fe-0f73-4636-bdc1-62e26e8fe74a'::uuid
    and profile_id = '26e48650-0fef-45a5-b6eb-3da895450ccf'::uuid
    and image_url = 'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/headers/yacxilan/header.jpg'
  ) as deferred_reference_unchanged
from public.featured_sellers
where id = 'af51e0fe-0f73-4636-bdc1-62e26e8fe74a'::uuid;

-- 5. Identify affected staging pages for later hands-on verification.
select
  id as profile_id,
  user_id as owning_user_id,
  handle,
  'https://psy.heyturgay.com/' || handle as staging_profile_url,
  avatar_url,
  header_url
from public.profiles
where id in (
  'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid,
  'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid
)
order by handle;

rollback;
