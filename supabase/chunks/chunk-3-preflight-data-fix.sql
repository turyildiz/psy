begin;

do $$
declare
  expected_conversation_id constant uuid :=
    '310bdfa1-f29f-4176-b06f-c52996f2fc00'::uuid;
  expected_listing_id constant uuid :=
    '4e06fb52-38b2-47e8-9451-22ef6a80e3f0'::uuid;
  expected_buyer_profile_id constant uuid :=
    'b87ae4ee-d79a-40a1-a793-9b30251b2ee0'::uuid;
  expected_old_seller_profile_id constant uuid :=
    'a76d80cd-f584-4a6b-bb54-89e77155a576'::uuid;
  expected_new_seller_profile_id constant uuid :=
    'f7e80b32-60a6-40dc-ab5b-3ad2cd0f0a23'::uuid;

  current_listing_id uuid;
  current_buyer_profile_id uuid;
  current_seller_profile_id uuid;
  current_listing_owner_id uuid;
begin
  select
    c.listing_id,
    c.buyer_profile_id,
    c.seller_profile_id
  into strict
    current_listing_id,
    current_buyer_profile_id,
    current_seller_profile_id
  from public.conversations c
  where c.id = expected_conversation_id
  for update;

  if current_listing_id is distinct from expected_listing_id then
    raise exception
      'Aborted: conversation listing changed from expected value';
  end if;

  if current_buyer_profile_id is distinct from expected_buyer_profile_id then
    raise exception
      'Aborted: conversation buyer changed from expected value';
  end if;

  if current_seller_profile_id is distinct from expected_old_seller_profile_id then
    raise exception
      'Aborted: conversation seller changed from expected value';
  end if;

  select l.profile_id
  into strict current_listing_owner_id
  from public.listings l
  where l.id = expected_listing_id
  for update;

  if current_listing_owner_id is distinct from expected_new_seller_profile_id then
    raise exception
      'Aborted: listing owner changed from solarbeing profile';
  end if;

  if exists (
    select 1
    from public.conversations c
    where c.id <> expected_conversation_id
      and c.listing_id = expected_listing_id
      and c.buyer_profile_id = expected_buyer_profile_id
      and c.seller_profile_id = expected_new_seller_profile_id
  ) then
    raise exception
      'Aborted: corrected conversation would duplicate an existing conversation';
  end if;

  update public.conversations
  set seller_profile_id = expected_new_seller_profile_id
  where id = expected_conversation_id;
end
$$;

commit;
