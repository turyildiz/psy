begin;

-- Reactive V1 listing moderation. public.current_user_is_admin() permits
-- admin/super_admin roles only and returns false for banned accounts.
create or replace function public.admin_unpublish_listing(
  target_listing_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  update public.listings
  set status = 'draft'::public.listing_status,
      updated_at = now()
  where id = target_listing_id;

  get diagnostics affected_rows = row_count;
  if affected_rows = 0 then
    raise exception 'Listing does not exist';
  end if;
end;
$$;

create or replace function public.admin_republish_listing(
  target_listing_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  update public.listings
  set status = 'active'::public.listing_status,
      updated_at = now()
  where id = target_listing_id;

  get diagnostics affected_rows = row_count;
  if affected_rows = 0 then
    raise exception 'Listing does not exist';
  end if;
end;
$$;

-- notice_reactions.post_id has ON DELETE CASCADE, so deleting a post
-- atomically removes all reactions attached to it.
create or replace function public.admin_delete_notice_post(
  target_notice_post_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required';
  end if;

  delete from public.notice_posts
  where id = target_notice_post_id;

  get diagnostics affected_rows = row_count;
  if affected_rows = 0 then
    raise exception 'Notice post does not exist';
  end if;
end;
$$;

-- Remove PostgreSQL's default PUBLIC execution and Supabase's explicit anon
-- execution, then expose the RPCs only to signed-in callers and trusted
-- service-role code. Each RPC independently enforces active admin status.
revoke all on function public.admin_unpublish_listing(uuid) from public;
revoke all on function public.admin_republish_listing(uuid) from public;
revoke all on function public.admin_delete_notice_post(uuid) from public;

revoke execute on function public.admin_unpublish_listing(uuid) from anon;
revoke execute on function public.admin_republish_listing(uuid) from anon;
revoke execute on function public.admin_delete_notice_post(uuid) from anon;

grant execute on function public.admin_unpublish_listing(uuid)
  to authenticated, service_role;
grant execute on function public.admin_republish_listing(uuid)
  to authenticated, service_role;
grant execute on function public.admin_delete_notice_post(uuid)
  to authenticated, service_role;

commit;
