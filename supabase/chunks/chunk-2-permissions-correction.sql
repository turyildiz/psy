begin;

revoke select
  on table public.blocked_handles
  from anon, authenticated;

grant select (handle)
  on table public.blocked_handles
  to anon, authenticated;

commit;
