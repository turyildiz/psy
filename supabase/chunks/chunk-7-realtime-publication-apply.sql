begin;

-- Abort before publication changes if the reviewed RLS/replica-identity
-- prerequisites are no longer true.
do $$
begin
  if not exists (
    select 1 from pg_publication p
    where p.pubname = 'supabase_realtime'
  ) then
    raise exception 'Publication supabase_realtime does not exist';
  end if;

  if (
    select count(*)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'notice_posts',
        'notice_reactions',
        'conversations',
        'conversation_participant_state'
      )
      and c.relkind = 'r'
  ) <> 4 then
    raise exception 'One or more Chunk 7 target tables are missing';
  end if;

  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'notice_posts',
        'notice_reactions',
        'conversations',
        'conversation_participant_state'
      )
      and not c.relrowsecurity
  ) then
    raise exception 'All Chunk 7 target tables must have RLS enabled';
  end if;

  -- Keep default replica identity. Supabase Postgres Changes cannot apply RLS
  -- to DELETE authorization; default identity limits DELETE payloads to the
  -- row key rather than an old full-row image.
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'notice_posts',
        'notice_reactions',
        'conversations',
        'conversation_participant_state'
      )
      and c.relreplident <> 'd'
  ) then
    raise exception 'Chunk 7 target tables must use REPLICA IDENTITY DEFAULT';
  end if;

  if exists (
    with expected(table_name, policy_name) as (
      values
        ('notice_posts', 'Notice posts are publicly readable'),
        ('notice_reactions', 'Reactions are publicly readable'),
        ('conversations', 'participants view visible conversations'),
        (
          'conversation_participant_state',
          'Participants read own conversation state'
        )
    )
    select 1
    from expected e
    left join pg_policies p
      on p.schemaname = 'public'
     and p.tablename = e.table_name
     and p.policyname = e.policy_name
     and p.cmd = 'SELECT'
    where p.policyname is null
  ) then
    raise exception 'One or more reviewed Chunk 7 SELECT policies are missing';
  end if;
end
$$;

-- Add only missing memberships so a safe re-run does not fail. The existing
-- public.messages membership is intentionally unchanged.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notice_posts'
  ) then
    execute 'alter publication supabase_realtime add table public.notice_posts';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notice_reactions'
  ) then
    execute 'alter publication supabase_realtime add table public.notice_reactions';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversations'
  ) then
    execute 'alter publication supabase_realtime add table public.conversations';
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversation_participant_state'
  ) then
    execute 'alter publication supabase_realtime add table public.conversation_participant_state';
  end if;
end
$$;

commit;
