-- psy.market R2 migration Step 10
-- READ-ONLY PREFLIGHT
--
-- This script does not modify data or schema.
-- Expected result:
--   * two target rows;
--   * all row_state_matches values = true;
--   * approved_destination_reference_count = 0;
--   * compatible text/UUID column types;
--   * no media-URL constraints;
--   * only the known updated_at and handle triggers;
--   * deferred featured_sellers reference unchanged.
--
-- R2 HTTP/content/checksum verification is external to PostgreSQL and must also
-- pass immediately before the owner executes the apply package.

begin transaction isolation level repeatable read read only;

-- 1. Exact target-row and old-value compatibility.
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
      'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg'::text,
      'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg'::text,
      true
    ),
    (
      'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid,
      '7aba9d97-2572-4f40-9858-27c3892191cb'::uuid,
      'otis'::text,
      'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif'::text,
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

-- 2. Assertable summary: expected 2, 2, 3.
with expected (
  profile_id,
  owning_user_id,
  expected_handle,
  expected_avatar_url,
  expected_header_url
) as (
  values
    (
      'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid,
      'b03d0533-1931-47c3-abce-f2d601698bf9'::uuid,
      'turgay'::text,
      'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg'::text,
      'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg'::text
    ),
    (
      'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid,
      '7aba9d97-2572-4f40-9858-27c3892191cb'::uuid,
      'otis'::text,
      'https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif'::text,
      null::text
    )
),
matched as (
  select
    p.id,
    (p.avatar_url = e.expected_avatar_url)::integer
      + (
          e.expected_header_url is not null
          and p.header_url = e.expected_header_url
        )::integer as matching_fields
  from expected e
  join public.profiles p
    on p.id = e.profile_id
   and p.user_id = e.owning_user_id
   and p.handle = e.expected_handle
)
select
  count(*) as matching_profile_rows,
  coalesce(sum(matching_fields), 0) as matching_url_fields,
  count(*) = 2 as exactly_two_rows,
  coalesce(sum(matching_fields), 0) = 3 as exactly_three_fields
from matched;

-- 3. No approved R2 destination may already appear in another media reference.
with approved_urls(value) as (
  values
    ('https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg'::text),
    ('https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg'::text),
    ('https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'::text)
),
media_references as (
  select 'profiles'::text as table_name, id as row_id, 'avatar_url'::text as field_name, avatar_url as value
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
  union all
  select 'featured_sellers', id, 'image_url', image_url from public.featured_sellers
)
select
  count(*) as approved_destination_reference_count,
  count(*) = 0 as no_approved_destination_is_referenced
from media_references r
join approved_urls a on a.value = r.value;

-- Expected: zero rows.
with approved_urls(value) as (
  values
    ('https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg'::text),
    ('https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg'::text),
    ('https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg'::text)
),
media_references as (
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
  union all
  select 'featured_sellers', id, 'image_url', image_url from public.featured_sellers
)
select r.*
from media_references r
join approved_urls a on a.value = r.value
order by r.table_name, r.row_id, r.field_name;

-- 4. Relevant column compatibility.
select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in ('id', 'user_id', 'handle', 'avatar_url', 'header_url', 'updated_at')
order by column_name;

-- 5. Profile constraints. No URL-specific constraint should be present.
select
  c.conname as constraint_name,
  c.contype as constraint_type,
  pg_get_constraintdef(c.oid, true) as definition
from pg_constraint c
join pg_class t on t.oid = c.conrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname = 'profiles'
order by c.conname;

-- 6. Profile triggers.
-- Expected:
--   profiles_enforce_handle: only UPDATE OF handle
--   tr_profiles_updated_at: updates updated_at for each modified row
select
  tg.tgname as trigger_name,
  pg_get_triggerdef(tg.oid, true) as definition
from pg_trigger tg
join pg_class t on t.oid = tg.tgrelid
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname = 'profiles'
  and not tg.tgisinternal
order by tg.tgname;

-- 7. Deferred legacy reference must remain unchanged.
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

rollback;
