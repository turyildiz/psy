begin;

-- Remove only the four Chunk 7 memberships. public.messages remains published.
do $$
begin
  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversation_participant_state'
  ) then
    execute 'alter publication supabase_realtime drop table public.conversation_participant_state';
  end if;

  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversations'
  ) then
    execute 'alter publication supabase_realtime drop table public.conversations';
  end if;

  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notice_reactions'
  ) then
    execute 'alter publication supabase_realtime drop table public.notice_reactions';
  end if;

  if exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notice_posts'
  ) then
    execute 'alter publication supabase_realtime drop table public.notice_posts';
  end if;
end
$$;

commit;
