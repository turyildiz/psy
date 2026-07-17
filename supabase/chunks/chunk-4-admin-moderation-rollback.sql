begin;

drop function if exists public.admin_delete_notice_post(uuid);
drop function if exists public.admin_republish_listing(uuid);
drop function if exists public.admin_unpublish_listing(uuid);

commit;
