-- PRE-FLIGHT REPORT
-- Review this result before enforcement. Every violation_count must be zero.
select
  'listing_images_over_5' as violation,
  (select count(*) from public.listings l where cardinality(l.images) > 5) as violation_count,
  array(
    select l.id::text
    from public.listings l
    where cardinality(l.images) > 5
    order by l.id
    limit 10
  ) as sample_ids

union all

select
  'listing_shipping_empty',
  (select count(*) from public.listings l where cardinality(l.ships_to) < 1),
  array(
    select l.id::text
    from public.listings l
    where cardinality(l.ships_to) < 1
    order by l.id
    limit 10
  )

union all

select
  'listing_tags_over_10',
  (select count(*) from public.listings l where cardinality(l.tags) > 10),
  array(
    select l.id::text
    from public.listings l
    where cardinality(l.tags) > 10
    order by l.id
    limit 10
  )

union all

select
  'listing_tag_invalid',
  (
    select count(*)
    from public.listings l
    where exists (
      select 1
      from unnest(l.tags) as tag(value)
      where tag.value !~ '^[a-z0-9-]{1,30}$'
    )
  ),
  array(
    select l.id::text
    from public.listings l
    where exists (
      select 1
      from unnest(l.tags) as tag(value)
      where tag.value !~ '^[a-z0-9-]{1,30}$'
    )
    order by l.id
    limit 10
  )

union all

select
  'message_body_over_2000',
  (select count(*) from public.messages m where char_length(m.body) > 2000),
  array(
    select m.id::text
    from public.messages m
    where char_length(m.body) > 2000
    order by m.id
    limit 10
  )

union all

select
  'conversation_buyer_equals_seller',
  (
    select count(*)
    from public.conversations c
    where c.buyer_profile_id = c.seller_profile_id
  ),
  array(
    select c.id::text
    from public.conversations c
    where c.buyer_profile_id = c.seller_profile_id
    order by c.id
    limit 10
  )

union all

select
  'conversation_listing_seller_mismatch',
  (
    select count(*)
    from public.conversations c
    join public.listings l on l.id = c.listing_id
    where c.seller_profile_id <> l.profile_id
  ),
  array(
    select c.id::text
    from public.conversations c
    join public.listings l on l.id = c.listing_id
    where c.seller_profile_id <> l.profile_id
    order by c.id
    limit 10
  );

begin;

-- Abort before any schema change if a preflight violation exists.
do $$
begin
  if exists (
    select 1 from public.listings l where cardinality(l.images) > 5
  ) then
    raise exception 'Preflight failed: listing has more than 5 images';
  end if;

  if exists (
    select 1 from public.listings l where cardinality(l.ships_to) < 1
  ) then
    raise exception 'Preflight failed: listing has an empty shipping list';
  end if;

  if exists (
    select 1 from public.listings l where cardinality(l.tags) > 10
  ) then
    raise exception 'Preflight failed: listing has more than 10 tags';
  end if;

  if exists (
    select 1
    from public.listings l
    where exists (
      select 1
      from unnest(l.tags) as tag(value)
      where tag.value !~ '^[a-z0-9-]{1,30}$'
    )
  ) then
    raise exception 'Preflight failed: listing has an invalid tag';
  end if;

  if exists (
    select 1 from public.messages m where char_length(m.body) > 2000
  ) then
    raise exception 'Preflight failed: message body exceeds 2000 characters';
  end if;

  if exists (
    select 1
    from public.conversations c
    where c.buyer_profile_id = c.seller_profile_id
  ) then
    raise exception 'Preflight failed: conversation buyer equals seller';
  end if;

  if exists (
    select 1
    from public.conversations c
    join public.listings l on l.id = c.listing_id
    where c.seller_profile_id <> l.profile_id
  ) then
    raise exception 'Preflight failed: conversation seller does not own listing';
  end if;
end
$$;

-- Tickets become a normal V1 listing category.
alter type public.listing_category
  add value if not exists 'ticket';

-- Reusable immutable validation for the tags array.
create or replace function public.valid_listing_tags(value text[])
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select
    cardinality(coalesce(value, '{}'::text[])) <= 10
    and not exists (
      select 1
      from unnest(coalesce(value, '{}'::text[])) as tag(item)
      where tag.item !~ '^[a-z0-9-]{1,30}$'
    );
$$;

revoke all on function public.valid_listing_tags(text[]) from public;
grant execute on function public.valid_listing_tags(text[])
  to authenticated, service_role;

-- Add as NOT VALID first, then explicitly validate against current rows.
alter table public.listings
  add constraint listings_images_max_5
    check (cardinality(images) <= 5) not valid,
  add constraint listings_shipping_required
    check (cardinality(ships_to) >= 1) not valid,
  add constraint listings_tags_valid
    check (public.valid_listing_tags(tags)) not valid;

alter table public.messages
  add constraint messages_body_max_2000
    check (char_length(body) <= 2000) not valid;

alter table public.conversations
  add constraint conversations_buyer_seller_differ
    check (buyer_profile_id <> seller_profile_id) not valid;

alter table public.listings
  validate constraint listings_images_max_5;

alter table public.listings
  validate constraint listings_shipping_required;

alter table public.listings
  validate constraint listings_tags_valid;

alter table public.messages
  validate constraint messages_body_max_2000;

alter table public.conversations
  validate constraint conversations_buyer_seller_differ;

-- Cross-table listing ownership cannot be represented by a CHECK constraint.
-- Enforce it for listing-linked conversations in a trigger instead.
create or replace function public.enforce_conversation_listing_seller()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  expected_seller_profile_id uuid;
begin
  if new.listing_id is null then
    return new;
  end if;

  select l.profile_id
    into expected_seller_profile_id
  from public.listings l
  where l.id = new.listing_id;

  if expected_seller_profile_id is null then
    raise exception 'Listing does not exist';
  end if;

  if new.seller_profile_id <> expected_seller_profile_id then
    raise exception 'Conversation seller must own the linked listing';
  end if;

  return new;
end;
$$;

revoke all
  on function public.enforce_conversation_listing_seller()
  from public;

revoke execute
  on function public.enforce_conversation_listing_seller()
  from anon, authenticated;

grant execute
  on function public.enforce_conversation_listing_seller()
  to service_role;

drop trigger if exists conversations_enforce_listing_seller
  on public.conversations;

create trigger conversations_enforce_listing_seller
before insert or update of listing_id, seller_profile_id
on public.conversations
for each row
execute function public.enforce_conversation_listing_seller();

commit;
