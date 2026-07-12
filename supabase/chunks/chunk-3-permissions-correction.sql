begin;

revoke execute
  on function public.valid_listing_tags(text[])
  from anon;

commit;
