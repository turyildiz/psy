-- CHUNK 6 READ-ONLY PREFLIGHT
-- Run before the apply file. This file performs no writes.

-- 1. Required helper/RPC dependencies must all resolve.
select
  to_regprocedure('public.current_user_is_banned()') as current_user_is_banned,
  to_regprocedure('public.current_user_is_admin()') as current_user_is_admin,
  to_regprocedure('public.admin_unpublish_listing(uuid)') as admin_unpublish_listing,
  to_regprocedure('public.admin_republish_listing(uuid)') as admin_republish_listing,
  to_regprocedure('public.append_unread_for(uuid,text)') as append_unread_for,
  to_regprocedure('public.remove_unread_for(uuid,text)') as remove_unread_for,
  to_regprocedure('public.hide_conversation(uuid)') as hide_conversation,
  to_regprocedure('public.unhide_conversation(uuid)') as unhide_conversation,
  to_regprocedure('public.find_and_unhide_conversation(uuid,uuid)')
    as find_and_unhide_conversation;

-- 2. Review current ban/admin state. Existing rows are not rewritten by Chunk 6.
select
  role,
  count(*) as account_count,
  count(*) filter (where banned_at is not null) as banned_count
from public.users
group by role
order by role;

-- 3. Existing drafts cannot be classified automatically as owner drafts versus
-- pre-Chunk-6 admin-unpublished listings because Chunk 4 stored only status.
-- Review every row. The currently known "Testing" draft
-- (f4ebbcb1-d18c-43f2-8a5f-83c4a7b315bd) was reviewed and confirmed to be an
-- ordinary owner draft, so it needs no moderation backfill. If any other row
-- was admin-unpublished under Chunk 4, call the revised
-- admin_unpublish_listing RPC again after Chunk 6 so it gains durable state.
select
  l.id,
  l.profile_id,
  l.title,
  l.status,
  l.created_at,
  l.updated_at
from public.listings l
where l.status = 'draft'::public.listing_status
order by l.updated_at desc, l.id;

-- 4. The new moderation columns/guard should not already exist.
select
  to_regprocedure('public.enforce_listing_moderation_state()')
    as existing_guard_function,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'listings'
      and column_name in ('admin_unpublished_at', 'admin_unpublished_by')
  ) as moderation_columns_already_exist;

-- 5. Capture the write policies that Chunk 6 will replace.
select
  tablename,
  policyname,
  cmd,
  roles::text,
  coalesce(qual, '') as using_expression,
  coalesce(with_check, '') as check_expression
from pg_policies
where schemaname = 'public'
  and tablename in (
    'profiles',
    'listings',
    'conversations',
    'messages',
    'vendor_events',
    'notice_posts',
    'notice_reactions',
    'favorites',
    'follows',
    'event_notifications'
  )
  and cmd in ('INSERT', 'UPDATE', 'DELETE')
order by tablename, cmd, policyname;
