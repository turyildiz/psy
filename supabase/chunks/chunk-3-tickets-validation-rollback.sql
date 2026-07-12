begin;

-- Refuse enum rollback while ticket listings exist. They must be reclassified
-- or deleted through a separately reviewed data migration first.
do $$
begin
  if exists (
    select 1
    from public.listings l
    where l.category = 'ticket'::public.listing_category
  ) then
    raise exception 'Rollback blocked: ticket listings still exist';
  end if;
end
$$;

drop trigger if exists conversations_enforce_listing_seller
  on public.conversations;

drop function if exists public.enforce_conversation_listing_seller();

alter table public.conversations
  drop constraint if exists conversations_buyer_seller_differ;

alter table public.messages
  drop constraint if exists messages_body_max_2000;

alter table public.listings
  drop constraint if exists listings_tags_valid,
  drop constraint if exists listings_shipping_required,
  drop constraint if exists listings_images_max_5;

drop function if exists public.valid_listing_tags(text[]);

-- PostgreSQL does not support DROP VALUE on an enum. Recreate the captured
-- pre-Chunk-3 type after confirming no ticket rows remain.
alter type public.listing_category
  rename to listing_category_with_ticket;

create type public.listing_category as enum (
  'clothing',
  'accessories',
  'gear',
  'art',
  'other'
);

alter table public.listings
  alter column category type public.listing_category
  using category::text::public.listing_category;

drop type public.listing_category_with_ticket;

commit;
