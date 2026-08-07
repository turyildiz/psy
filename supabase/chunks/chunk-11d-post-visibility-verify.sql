-- psy.market database Chunk 11D
-- READ-ONLY VERIFY: public versus members-only post visibility.
--
-- Status: COMPLETED — DATABASE PASS with UNPROVEN missing-fixture branches only
-- (owner-confirmed 2026-08-07).
--
-- Run after owner application of Chunk 11D. This script performs no DDL or DML.
-- It aborts on any available-fixture failure and returns one final summary row.
-- Branches without representative existing data are reported as UNPROVEN; the
-- script never creates users, profiles, posts, or reactions.

begin transaction isolation level repeatable read read only;

-- Catalog, ACL, policy, helper-definition, and invariant verification.
do $catalog_checks$
declare
  author_helper_oid oid := to_regprocedure(
    'public.current_user_can_read_post_author(uuid)'
  );
  visibility_helper_oid oid := to_regprocedure(
    'public.current_user_can_read_post(uuid,boolean)'
  );
  reaction_helper_oid oid := to_regprocedure(
    'public.current_user_can_read_post_reaction(uuid,uuid)'
  );
begin
  if current_user <> 'postgres' then
    raise exception 'Chunk 11D verify must run as postgres';
  end if;

  if not coalesce((
    select not r.rolsuper and r.rolbypassrls
    from pg_roles r
    where r.rolname = 'postgres'
  ), false) then
    raise exception 'Chunk 11D verify failed: postgres role attributes mismatch';
  end if;

  if author_helper_oid is null
     or visibility_helper_oid is null
     or reaction_helper_oid is null then
    raise exception 'Chunk 11D verify failed: helper missing';
  end if;

  if (
    select count(*)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'current_user_can_read_post'
  ) <> 1 then
    raise exception 'Chunk 11D verify failed: conflicting visibility helper overload';
  end if;

  if (
    select count(*)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'current_user_can_read_post_author',
        'current_user_can_read_post_reaction'
      )
  ) <> 2 then
    raise exception 'Chunk 11D verify failed: baseline helper overload set drifted';
  end if;

  if not coalesce((
    select r.rolbypassrls
    from pg_roles r
    where r.rolname = 'service_role'
  ), false) then
    raise exception 'Chunk 11D verify failed: service_role BYPASSRLS mismatch';
  end if;

  if (
    select count(*)
    from pg_class c
    where c.oid in (
      'public.posts'::regclass,
      'public.post_reactions'::regclass
    )
      and c.relkind = 'r'
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) <> 2 then
    raise exception 'Chunk 11D verify failed: table owner/RLS mismatch';
  end if;

  if (
    select count(*)
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = 'posts'
      and p.policyname = 'Visible posts are publicly readable'
      and p.cmd = 'SELECT'
      and p.permissive = 'PERMISSIVE'
      and p.roles = array['public'::name]
      and p.qual = 'current_user_can_read_post(profile_id, show_in_stream)'
      and p.with_check is null
  ) <> 1
     or (
       select count(*)
       from pg_policies p
       where p.schemaname = 'public'
         and p.tablename = 'posts'
     ) <> 1 then
    raise exception 'Chunk 11D verify failed: exact posts policy mismatch';
  end if;

  if (
    select count(*)
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = 'post_reactions'
      and p.policyname = 'Visible reactions are publicly readable'
      and p.cmd = 'SELECT'
      and p.permissive = 'PERMISSIVE'
      and p.roles = array['public'::name]
      and p.qual = 'current_user_can_read_post_reaction(profile_id, post_id)'
      and p.with_check is null
  ) <> 1
     or (
       select count(*)
       from pg_policies p
       where p.schemaname = 'public'
         and p.tablename = 'post_reactions'
     ) <> 1 then
    raise exception 'Chunk 11D verify failed: exact reaction policy mismatch';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    where p.oid = author_helper_oid
      and p.proowner = 'postgres'::regrole
      and p.prosecdef
      and p.provolatile = 's'
      and l.lanname = 'sql'
      and pg_get_function_result(p.oid) = 'boolean'
      and pg_get_function_identity_arguments(p.oid) =
        'target_profile_id uuid'
      and p.proconfig in (
        array['search_path=""'],
        array['search_path=']
      )
      and pg_catalog.btrim(pg_catalog.regexp_replace(
        p.prosrc,
        E'\\s+',
        ' ',
        'g'
      )) = 'select not public.profile_owner_is_banned($1) or public.current_user_is_admin();'
  ) then
    raise exception 'Chunk 11D verify failed: author helper drifted';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    where p.oid = visibility_helper_oid
      and p.proowner = 'postgres'::regrole
      and p.prosecdef
      and p.provolatile = 's'
      and l.lanname = 'sql'
      and pg_get_function_result(p.oid) = 'boolean'
      and pg_get_function_identity_arguments(p.oid) =
        'target_profile_id uuid, target_show_in_stream boolean'
      and p.proconfig in (
        array['search_path=""'],
        array['search_path=']
      )
      and pg_catalog.btrim(pg_catalog.regexp_replace(
        p.prosrc,
        E'\\s+',
        ' ',
        'g'
      )) = 'select public.current_user_can_read_post_author($1) and ($2 or auth.role() = ''authenticated'');'
  ) then
    raise exception 'Chunk 11D verify failed: visibility helper mismatch';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_language l on l.oid = p.prolang
    where p.oid = reaction_helper_oid
      and p.proowner = 'postgres'::regrole
      and p.prosecdef
      and p.provolatile = 's'
      and l.lanname = 'sql'
      and pg_get_function_result(p.oid) = 'boolean'
      and pg_get_function_identity_arguments(p.oid) =
        'reaction_profile_id uuid, target_post_id uuid'
      and p.proconfig in (
        array['search_path=""'],
        array['search_path=']
      )
      and pg_catalog.btrim(pg_catalog.regexp_replace(
        p.prosrc,
        E'\\s+',
        ' ',
        'g'
      )) = 'select not public.profile_owner_is_banned($1) and coalesce(( select public.current_user_can_read_post( post.profile_id, post.show_in_stream ) from public.posts as post where post.id = $2 ), false);'
  ) then
    raise exception 'Chunk 11D verify failed: reaction helper mismatch';
  end if;

  if exists (
    with actual(function_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      select
        p.proname,
        case when acl.grantee = 0 then 'PUBLIC'
          else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable,
        acl.grantor::regrole::text
      from pg_proc p
      cross join lateral aclexplode(p.proacl) as acl
      where p.oid in (
        author_helper_oid,
        visibility_helper_oid,
        reaction_helper_oid
      )
        and acl.grantee <> p.proowner
    ),
    expected(function_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('current_user_can_read_post_author', 'anon', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_author', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post', 'anon', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_reaction', 'anon', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_reaction', 'authenticated', 'EXECUTE', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11D verify failed: helper ACL mismatch';
  end if;

  if exists (
    with actual(object_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      select
        c.relname,
        case when acl.grantee = 0 then 'PUBLIC'
          else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable,
        acl.grantor::regrole::text
      from pg_class c
      cross join lateral aclexplode(c.relacl) as acl
      where c.oid in (
        'public.posts'::regclass,
        'public.post_reactions'::regclass
      )
        and acl.grantee <> c.relowner
    ),
    expected(object_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('posts', 'anon', 'SELECT', false, 'postgres'),
        ('posts', 'authenticated', 'SELECT', false, 'postgres'),
        ('posts', 'service_role', 'SELECT', false, 'postgres'),
        ('post_reactions', 'anon', 'SELECT', false, 'postgres'),
        ('post_reactions', 'authenticated', 'SELECT', false, 'postgres'),
        ('post_reactions', 'service_role', 'SELECT', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11D verify failed: table ACL mismatch';
  end if;

  if has_table_privilege('anon', 'public.posts', 'INSERT')
     or has_table_privilege('authenticated', 'public.posts', 'INSERT')
     or has_table_privilege('authenticated', 'public.posts', 'UPDATE')
     or has_table_privilege('authenticated', 'public.posts', 'DELETE')
     or has_table_privilege('authenticated', 'public.post_reactions', 'INSERT')
     or has_table_privilege('authenticated', 'public.post_reactions', 'UPDATE')
     or has_table_privilege('authenticated', 'public.post_reactions', 'DELETE') then
    raise exception 'Chunk 11D verify failed: direct mutation privilege appeared';
  end if;

  if exists (
    with expected_functions(signature) as (
      values
        ('public.create_post(uuid,text,text[],boolean)'),
        ('public.update_post(uuid,text,text[],boolean)'),
        ('public.delete_own_post(uuid)'),
        ('public.admin_flag_post_for_hero(uuid)'),
        ('public.admin_unflag_post_for_hero(uuid)'),
        ('public.set_post_reaction(uuid,uuid,text)'),
        ('public.remove_post_reaction(uuid,uuid)'),
        ('public.admin_delete_post(uuid,text)')
    ),
    actual_functions(signature, function_oid) as (
      select
        format(
          '%s.%s(%s)',
          n.nspname,
          p.proname,
          replace(oidvectortypes(p.proargtypes), ' ', '')
        ),
        p.oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in (
          'create_post',
          'update_post',
          'delete_own_post',
          'admin_flag_post_for_hero',
          'admin_unflag_post_for_hero',
          'set_post_reaction',
          'remove_post_reaction',
          'admin_delete_post'
        )
    ),
    expected_state(marker) as (
      select 'function|' || f.signature
      from expected_functions f
      union all
      select
        'acl|' || f.signature || '|' || grantee.name
        || '|EXECUTE|false|postgres'
      from expected_functions f
      cross join (values ('postgres'), ('authenticated')) as grantee(name)
    ),
    actual_state(marker) as (
      select 'function|' || f.signature
      from actual_functions f
      union all
      select
        'acl|' || f.signature || '|'
        || case when acl.grantee = 0 then 'PUBLIC'
          else acl.grantee::regrole::text end
        || '|' || acl.privilege_type
        || '|' || acl.is_grantable::text
        || '|' || acl.grantor::regrole::text
      from actual_functions f
      join pg_proc p on p.oid = f.function_oid
      cross join lateral aclexplode(
        coalesce(p.proacl, acldefault('f', p.proowner))
      ) as acl
    )
    (select marker from actual_state except select marker from expected_state)
    union all
    (select marker from expected_state except select marker from actual_state)
  ) then
    raise exception 'Chunk 11D verify failed: mutation RPC signature/ACL drifted';
  end if;

  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.posts'::regclass
      and c.conname = 'posts_hero_state_check'
      and c.contype = 'c'
      and c.convalidated
      and pg_catalog.strpos(
        pg_get_constraintdef(c.oid, true),
        'show_in_stream'
      ) > 0
      and pg_catalog.strpos(
        pg_get_constraintdef(c.oid, true),
        'is_hero_featured'
      ) > 0
  ) or exists (
    select 1
    from public.posts p
    where p.is_hero_featured and not p.show_in_stream
  ) then
    raise exception 'Chunk 11D verify failed: Hero invariant mismatch';
  end if;

  if exists (
    select 1
    from public.post_reactions r
    left join public.posts p on p.id = r.post_id
    where p.id is null
  ) then
    raise exception 'Chunk 11D verify failed: orphan reaction exists';
  end if;
end;
$catalog_checks$;

-- Capture only opaque fixture identifiers in transaction-local settings. They
-- are never selected into the output. Empty strings mean no existing fixture.
do $capture_fixtures$
declare
  fixture_id text;
begin
  select p.id::text into fixture_id
  from public.posts p
  join public.profiles profile on profile.id = p.profile_id
  join public.users author on author.id = profile.user_id
  where p.show_in_stream and author.banned_at is null
  order by p.created_at desc, p.id desc
  limit 1;
  perform set_config('app.chunk_11d_public_post_id', coalesce(fixture_id, ''), true);

  select p.profile_id::text into fixture_id
  from public.posts p
  where p.id = nullif(current_setting('app.chunk_11d_public_post_id', true), '')::uuid;
  perform set_config('app.chunk_11d_public_post_profile_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select p.id::text into fixture_id
  from public.posts p
  join public.profiles profile on profile.id = p.profile_id
  join public.users author on author.id = profile.user_id
  where not p.show_in_stream and author.banned_at is null
  order by p.created_at desc, p.id desc
  limit 1;
  perform set_config('app.chunk_11d_private_post_id', coalesce(fixture_id, ''), true);

  select p.profile_id::text into fixture_id
  from public.posts p
  where p.id = nullif(current_setting('app.chunk_11d_private_post_id', true), '')::uuid;
  perform set_config('app.chunk_11d_private_post_profile_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select p.id::text into fixture_id
  from public.posts p
  join public.profiles profile on profile.id = p.profile_id
  join public.users author on author.id = profile.user_id
  where author.banned_at is not null
  order by p.created_at desc, p.id desc
  limit 1;
  perform set_config('app.chunk_11d_banned_author_post_id', coalesce(fixture_id, ''), true);

  select p.profile_id::text into fixture_id
  from public.posts p
  where p.id = nullif(current_setting('app.chunk_11d_banned_author_post_id', true), '')::uuid;
  perform set_config('app.chunk_11d_banned_author_profile_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select r.id::text into fixture_id
  from public.post_reactions r
  join public.posts p on p.id = r.post_id
  join public.profiles post_profile on post_profile.id = p.profile_id
  join public.users post_author on post_author.id = post_profile.user_id
  join public.profiles reactor_profile on reactor_profile.id = r.profile_id
  join public.users reactor on reactor.id = reactor_profile.user_id
  where p.show_in_stream
    and post_author.banned_at is null
    and reactor.banned_at is null
  order by r.created_at desc, r.id desc
  limit 1;
  perform set_config('app.chunk_11d_public_reaction_id', coalesce(fixture_id, ''), true);

  select r.post_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_public_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_public_reaction_post_id', coalesce(fixture_id, ''), true);

  select r.profile_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_public_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_public_reaction_profile_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select r.id::text into fixture_id
  from public.post_reactions r
  join public.posts p on p.id = r.post_id
  join public.profiles post_profile on post_profile.id = p.profile_id
  join public.users post_author on post_author.id = post_profile.user_id
  join public.profiles reactor_profile on reactor_profile.id = r.profile_id
  join public.users reactor on reactor.id = reactor_profile.user_id
  where not p.show_in_stream
    and post_author.banned_at is null
    and reactor.banned_at is null
  order by r.created_at desc, r.id desc
  limit 1;
  perform set_config('app.chunk_11d_private_reaction_id', coalesce(fixture_id, ''), true);

  select r.post_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_private_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_private_reaction_post_id', coalesce(fixture_id, ''), true);

  select r.profile_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_private_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_private_reaction_profile_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select r.id::text into fixture_id
  from public.post_reactions r
  join public.profiles reactor_profile on reactor_profile.id = r.profile_id
  join public.users reactor on reactor.id = reactor_profile.user_id
  where reactor.banned_at is not null
  order by r.created_at desc, r.id desc
  limit 1;
  perform set_config('app.chunk_11d_banned_reactor_reaction_id', coalesce(fixture_id, ''), true);

  select r.post_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_banned_reactor_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_banned_reactor_post_id', coalesce(fixture_id, ''), true);

  select r.profile_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_banned_reactor_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_banned_reactor_profile_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select r.id::text into fixture_id
  from public.post_reactions r
  join public.posts p on p.id = r.post_id
  join public.profiles post_profile on post_profile.id = p.profile_id
  join public.users post_author on post_author.id = post_profile.user_id
  join public.profiles reactor_profile on reactor_profile.id = r.profile_id
  join public.users reactor on reactor.id = reactor_profile.user_id
  where post_author.banned_at is not null
    and reactor.banned_at is null
  order by r.created_at desc, r.id desc
  limit 1;
  perform set_config('app.chunk_11d_banned_author_reaction_id', coalesce(fixture_id, ''), true);

  select r.post_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_banned_author_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_banned_author_reaction_post_id', coalesce(fixture_id, ''), true);

  select r.profile_id::text into fixture_id
  from public.post_reactions r
  where r.id = nullif(current_setting('app.chunk_11d_banned_author_reaction_id', true), '')::uuid;
  perform set_config('app.chunk_11d_banned_author_reaction_profile_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select u.id::text into fixture_id
  from public.users u
  where u.banned_at is null
    and u.role::text not in ('admin', 'super_admin')
  order by u.created_at, u.id
  limit 1;
  perform set_config('app.chunk_11d_member_user_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select u.id::text into fixture_id
  from public.users u
  where u.banned_at is not null
  order by u.created_at, u.id
  limit 1;
  perform set_config('app.chunk_11d_banned_user_id', coalesce(fixture_id, ''), true);

  fixture_id := null;
  select u.id::text into fixture_id
  from public.users u
  where u.banned_at is null
    and u.role::text in ('admin', 'super_admin')
  order by u.created_at, u.id
  limit 1;
  perform set_config('app.chunk_11d_admin_user_id', coalesce(fixture_id, ''), true);
end;
$capture_fixtures$;

-- Anonymous viewer: actual anon database role plus owner-supplied anon JWT
-- claims. This proves database RLS/helper behavior, not gateway token transport;
-- the final row explicitly requires separate real-session PostgREST probes.
do $anon_context$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
end;
$anon_context$;
set local role anon;

do $anon_runtime$
declare
  zero_id constant uuid := '00000000-0000-0000-0000-000000000000';
  fixture text;
  profile_fixture text;
  post_fixture text;
begin
  -- Unconditional legal calls prove both helpers resolve and execute for anon.
  if public.current_user_can_read_post(zero_id, true)
     or public.current_user_can_read_post_reaction(zero_id, zero_id) then
    raise exception 'Chunk 11D verify failed: anon missing-target helper result';
  end if;

  fixture := current_setting('app.chunk_11d_public_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_public_post_profile_id', true);
  if fixture = '' then
    perform set_config('app.chunk_11d_anon_public_post_status', 'UNPROVEN: no public-post fixture', true);
  else
    if not public.current_user_can_read_post(profile_fixture::uuid, true)
       or not exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: anon public-post branch';
    end if;
    perform set_config('app.chunk_11d_anon_public_post_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_private_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_private_post_profile_id', true);
  if fixture = '' then
    perform set_config('app.chunk_11d_anon_private_post_status', 'UNPROVEN: no members-only-post fixture', true);
  else
    if public.current_user_can_read_post(profile_fixture::uuid, false)
       or exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: anon members-only-post branch';
    end if;
    perform set_config('app.chunk_11d_anon_private_post_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_public_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_public_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_public_reaction_profile_id', true);
  if fixture = '' then
    perform set_config('app.chunk_11d_anon_public_reaction_status', 'UNPROVEN: no public-reaction fixture', true);
  else
    if not public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or not exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: anon public-reaction branch';
    end if;
    perform set_config('app.chunk_11d_anon_public_reaction_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_private_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_private_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_private_reaction_profile_id', true);
  if fixture = '' then
    perform set_config('app.chunk_11d_anon_private_reaction_status', 'UNPROVEN: no members-only-reaction fixture', true);
  else
    if public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: anon members-only-reaction branch';
    end if;
    perform set_config('app.chunk_11d_anon_private_reaction_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_banned_author_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_banned_author_profile_id', true);
  if fixture = '' then
    perform set_config('app.chunk_11d_anon_banned_author_status', 'UNPROVEN: no banned-author-post fixture', true);
  else
    if public.current_user_can_read_post(profile_fixture::uuid, true)
       or exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: anon banned-author-post branch';
    end if;
    perform set_config('app.chunk_11d_anon_banned_author_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_banned_author_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_banned_author_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_banned_author_reaction_profile_id', true);
  if fixture = '' then
    perform set_config('app.chunk_11d_anon_banned_author_reaction_status', 'UNPROVEN: no banned-author-reaction fixture', true);
  else
    if public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: anon banned-author-reaction branch';
    end if;
    perform set_config('app.chunk_11d_anon_banned_author_reaction_status', 'PASS', true);
  end if;
end;
$anon_runtime$;

reset role;

-- Authenticated ordinary member. An existing active non-admin identity is used
-- where available; otherwise affected branches are reported UNPROVEN.
do $member_context$
declare
  user_fixture text := current_setting('app.chunk_11d_member_user_id', true);
begin
  perform set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'role', 'authenticated',
      'sub', case when user_fixture = ''
        then '00000000-0000-0000-0000-000000000000'
        else user_fixture end
    )::text,
    true
  );
end;
$member_context$;
set local role authenticated;

do $member_runtime$
declare
  fixture text;
  profile_fixture text;
  post_fixture text;
begin
  fixture := current_setting('app.chunk_11d_public_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_public_post_profile_id', true);
  if current_setting('app.chunk_11d_member_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_member_public_post_status', 'UNPROVEN: missing member or public-post fixture', true);
  else
    if not public.current_user_can_read_post(profile_fixture::uuid, true)
       or not exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: authenticated public-post branch';
    end if;
    perform set_config('app.chunk_11d_member_public_post_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_public_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_public_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_public_reaction_profile_id', true);
  if current_setting('app.chunk_11d_member_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_member_public_reaction_status', 'UNPROVEN: missing member or public-reaction fixture', true);
  else
    if not public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or not exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: authenticated public-reaction branch';
    end if;
    perform set_config('app.chunk_11d_member_public_reaction_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_private_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_private_post_profile_id', true);
  if current_setting('app.chunk_11d_member_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_member_private_post_status', 'UNPROVEN: missing member or members-only-post fixture', true);
  else
    if not public.current_user_can_read_post(profile_fixture::uuid, false)
       or not exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: authenticated members-only-post branch';
    end if;
    perform set_config('app.chunk_11d_member_private_post_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_private_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_private_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_private_reaction_profile_id', true);
  if current_setting('app.chunk_11d_member_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_member_private_reaction_status', 'UNPROVEN: missing member or members-only-reaction fixture', true);
  else
    if not public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or not exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: authenticated members-only-reaction branch';
    end if;
    perform set_config('app.chunk_11d_member_private_reaction_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_banned_author_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_banned_author_profile_id', true);
  if current_setting('app.chunk_11d_member_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_member_banned_author_status', 'UNPROVEN: missing member or banned-author-post fixture', true);
  else
    if public.current_user_can_read_post(profile_fixture::uuid, true)
       or exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: non-admin banned-author branch';
    end if;
    perform set_config('app.chunk_11d_member_banned_author_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_banned_author_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_banned_author_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_banned_author_reaction_profile_id', true);
  if current_setting('app.chunk_11d_member_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_member_banned_author_reaction_status', 'UNPROVEN: missing member or banned-author-reaction fixture', true);
  else
    if public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: non-admin banned-author-reaction branch';
    end if;
    perform set_config('app.chunk_11d_member_banned_author_reaction_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_banned_reactor_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_banned_reactor_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_banned_reactor_profile_id', true);
  if current_setting('app.chunk_11d_member_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_banned_reactor_status', 'UNPROVEN: missing member or banned-reactor fixture', true);
  else
    if public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: banned-reactor branch';
    end if;
    perform set_config('app.chunk_11d_banned_reactor_status', 'PASS', true);
  end if;
end;
$member_runtime$;

reset role;

-- Banned authenticated viewer: reads remain unchanged for unbanned authors.
do $banned_viewer_context$
declare
  user_fixture text := current_setting('app.chunk_11d_banned_user_id', true);
begin
  perform set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'role', 'authenticated',
      'sub', case when user_fixture = ''
        then '00000000-0000-0000-0000-000000000000'
        else user_fixture end
    )::text,
    true
  );
end;
$banned_viewer_context$;
set local role authenticated;

do $banned_viewer_runtime$
declare
  fixture text := current_setting('app.chunk_11d_private_post_id', true);
  profile_fixture text := current_setting('app.chunk_11d_private_post_profile_id', true);
  post_fixture text;
begin
  if current_setting('app.chunk_11d_banned_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_banned_viewer_status', 'UNPROVEN: missing banned-viewer or members-only-post fixture', true);
  else
    if not public.current_user_can_read_post(profile_fixture::uuid, false)
       or not exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: banned authenticated viewer branch';
    end if;
    perform set_config('app.chunk_11d_banned_viewer_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_private_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_private_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_private_reaction_profile_id', true);
  if current_setting('app.chunk_11d_banned_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_banned_viewer_reaction_status', 'UNPROVEN: missing banned-viewer or members-only-reaction fixture', true);
  else
    if not public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or not exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: banned authenticated viewer reaction branch';
    end if;
    perform set_config('app.chunk_11d_banned_viewer_reaction_status', 'PASS', true);
  end if;
end;
$banned_viewer_runtime$;

reset role;

-- Active admin: existing exception for banned-author posts remains intact.
do $admin_context$
declare
  user_fixture text := current_setting('app.chunk_11d_admin_user_id', true);
begin
  perform set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'role', 'authenticated',
      'sub', case when user_fixture = ''
        then '00000000-0000-0000-0000-000000000000'
        else user_fixture end
    )::text,
    true
  );
end;
$admin_context$;
set local role authenticated;

do $admin_runtime$
declare
  fixture text;
  profile_fixture text;
  post_fixture text;
begin
  fixture := current_setting('app.chunk_11d_banned_author_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_banned_author_profile_id', true);
  if current_setting('app.chunk_11d_admin_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_admin_banned_author_status', 'UNPROVEN: missing active-admin or banned-author-post fixture', true);
  else
    if not public.current_user_can_read_post(profile_fixture::uuid, false)
       or not exists (select 1 from public.posts p where p.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: active-admin banned-author branch';
    end if;
    perform set_config('app.chunk_11d_admin_banned_author_status', 'PASS', true);
  end if;

  fixture := current_setting('app.chunk_11d_banned_author_reaction_id', true);
  post_fixture := current_setting('app.chunk_11d_banned_author_reaction_post_id', true);
  profile_fixture := current_setting('app.chunk_11d_banned_author_reaction_profile_id', true);
  if current_setting('app.chunk_11d_admin_user_id', true) = '' or fixture = '' then
    perform set_config('app.chunk_11d_admin_banned_author_reaction_status', 'UNPROVEN: missing active-admin or banned-author-reaction fixture', true);
  else
    if not public.current_user_can_read_post_reaction(profile_fixture::uuid, post_fixture::uuid)
       or not exists (select 1 from public.post_reactions r where r.id = fixture::uuid) then
      raise exception 'Chunk 11D verify failed: active-admin banned-author-reaction branch';
    end if;
    perform set_config('app.chunk_11d_admin_banned_author_reaction_status', 'PASS', true);
  end if;
end;
$admin_runtime$;

reset role;

-- Expected Supabase service role bypasses RLS and sees complete operational data.
do $service_context$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
end;
$service_context$;
set local role service_role;

do $service_runtime$
declare
  zero_id constant uuid := '00000000-0000-0000-0000-000000000000';
  private_fixture text := current_setting('app.chunk_11d_private_post_id', true);
  banned_fixture text := current_setting('app.chunk_11d_banned_author_post_id', true);
  private_reaction_fixture text := current_setting('app.chunk_11d_private_reaction_id', true);
  banned_reaction_fixture text := current_setting('app.chunk_11d_banned_author_reaction_id', true);
begin
  begin
    perform public.current_user_can_read_post(zero_id, false);
    raise exception 'Chunk 11D verify failed: service unexpectedly executed post helper';
  exception
    when insufficient_privilege then
      perform set_config('app.chunk_11d_service_post_helper_acl_status', 'EXPECTED_DENY', true);
  end;

  begin
    perform public.current_user_can_read_post_reaction(zero_id, zero_id);
    raise exception 'Chunk 11D verify failed: service unexpectedly executed reaction helper';
  exception
    when insufficient_privilege then
      perform set_config('app.chunk_11d_service_reaction_helper_acl_status', 'EXPECTED_DENY', true);
  end;

  if private_fixture = '' then
    perform set_config('app.chunk_11d_service_private_status', 'UNPROVEN: no members-only-post fixture', true);
  else
    if not exists (select 1 from public.posts p where p.id = private_fixture::uuid) then
      raise exception 'Chunk 11D verify failed: service members-only-post branch';
    end if;
    perform set_config('app.chunk_11d_service_private_status', 'PASS', true);
  end if;

  if banned_fixture = '' then
    perform set_config('app.chunk_11d_service_banned_author_status', 'UNPROVEN: no banned-author-post fixture', true);
  else
    if not exists (select 1 from public.posts p where p.id = banned_fixture::uuid) then
      raise exception 'Chunk 11D verify failed: service banned-author branch';
    end if;
    perform set_config('app.chunk_11d_service_banned_author_status', 'PASS', true);
  end if;

  if private_reaction_fixture = '' then
    perform set_config('app.chunk_11d_service_private_reaction_status', 'UNPROVEN: no members-only-reaction fixture', true);
  else
    if not exists (
      select 1
      from public.post_reactions r
      where r.id = private_reaction_fixture::uuid
    ) then
      raise exception 'Chunk 11D verify failed: service members-only-reaction branch';
    end if;
    perform set_config('app.chunk_11d_service_private_reaction_status', 'PASS', true);
  end if;

  if banned_reaction_fixture = '' then
    perform set_config('app.chunk_11d_service_banned_author_reaction_status', 'UNPROVEN: no banned-author-reaction fixture', true);
  else
    if not exists (
      select 1
      from public.post_reactions r
      where r.id = banned_reaction_fixture::uuid
    ) then
      raise exception 'Chunk 11D verify failed: service banned-author-reaction branch';
    end if;
    perform set_config('app.chunk_11d_service_banned_author_reaction_status', 'PASS', true);
  end if;
end;
$service_runtime$;

reset role;
do $clear_jwt_context$
begin
  perform set_config('request.jwt.claims', '{}', true);
end;
$clear_jwt_context$;

do $final_status_checks$
declare
  setting_name text;
  required_status_settings constant text[] := array[
    'app.chunk_11d_anon_public_post_status',
    'app.chunk_11d_anon_private_post_status',
    'app.chunk_11d_anon_public_reaction_status',
    'app.chunk_11d_anon_private_reaction_status',
    'app.chunk_11d_anon_banned_author_status',
    'app.chunk_11d_anon_banned_author_reaction_status',
    'app.chunk_11d_member_public_post_status',
    'app.chunk_11d_member_public_reaction_status',
    'app.chunk_11d_member_private_post_status',
    'app.chunk_11d_member_private_reaction_status',
    'app.chunk_11d_member_banned_author_status',
    'app.chunk_11d_member_banned_author_reaction_status',
    'app.chunk_11d_banned_reactor_status',
    'app.chunk_11d_banned_viewer_status',
    'app.chunk_11d_banned_viewer_reaction_status',
    'app.chunk_11d_admin_banned_author_status',
    'app.chunk_11d_admin_banned_author_reaction_status',
    'app.chunk_11d_service_private_status',
    'app.chunk_11d_service_banned_author_status',
    'app.chunk_11d_service_private_reaction_status',
    'app.chunk_11d_service_banned_author_reaction_status',
    'app.chunk_11d_service_post_helper_acl_status',
    'app.chunk_11d_service_reaction_helper_acl_status'
  ]::text[];
begin
  foreach setting_name in array required_status_settings loop
    if coalesce(current_setting(setting_name, true), '') = '' then
      raise exception 'Chunk 11D verify failed: runtime status was not recorded for %',
        setting_name;
    end if;
  end loop;
end;
$final_status_checks$;

-- One final summary row. Any available-fixture mismatch has already aborted the
-- transaction. UNPROVEN is not PASS and is intentionally preserved for review.
select
  case when concat_ws(
    ' ',
    current_setting('app.chunk_11d_anon_public_post_status', true),
    current_setting('app.chunk_11d_anon_private_post_status', true),
    current_setting('app.chunk_11d_anon_public_reaction_status', true),
    current_setting('app.chunk_11d_anon_private_reaction_status', true),
    current_setting('app.chunk_11d_anon_banned_author_status', true),
    current_setting('app.chunk_11d_anon_banned_author_reaction_status', true),
    current_setting('app.chunk_11d_member_public_post_status', true),
    current_setting('app.chunk_11d_member_public_reaction_status', true),
    current_setting('app.chunk_11d_member_private_post_status', true),
    current_setting('app.chunk_11d_member_private_reaction_status', true),
    current_setting('app.chunk_11d_member_banned_author_status', true),
    current_setting('app.chunk_11d_member_banned_author_reaction_status', true),
    current_setting('app.chunk_11d_banned_reactor_status', true),
    current_setting('app.chunk_11d_banned_viewer_status', true),
    current_setting('app.chunk_11d_banned_viewer_reaction_status', true),
    current_setting('app.chunk_11d_admin_banned_author_status', true),
    current_setting('app.chunk_11d_admin_banned_author_reaction_status', true),
    current_setting('app.chunk_11d_service_private_status', true),
    current_setting('app.chunk_11d_service_banned_author_status', true),
    current_setting('app.chunk_11d_service_private_reaction_status', true),
    current_setting('app.chunk_11d_service_banned_author_reaction_status', true),
    current_setting('app.chunk_11d_service_post_helper_acl_status', true),
    current_setting('app.chunk_11d_service_reaction_helper_acl_status', true)
  ) like '%UNPROVEN%'
  then 'DATABASE PASS WITH UNPROVEN DATA BRANCHES; EXTERNAL SESSION PROBES REQUIRED'
  else 'DATABASE PASS; EXTERNAL SESSION PROBES REQUIRED'
  end as chunk_11d_verify_status,
  'PASS' as catalog_policy_acl_invariants,
  current_setting('app.chunk_11d_anon_public_post_status', true)
    as anon_public_post,
  current_setting('app.chunk_11d_anon_private_post_status', true)
    as anon_members_only_post,
  current_setting('app.chunk_11d_anon_public_reaction_status', true)
    as anon_public_reaction,
  current_setting('app.chunk_11d_anon_private_reaction_status', true)
    as anon_members_only_reaction,
  current_setting('app.chunk_11d_anon_banned_author_status', true)
    as anon_banned_author_post,
  current_setting('app.chunk_11d_anon_banned_author_reaction_status', true)
    as anon_banned_author_reaction,
  current_setting('app.chunk_11d_member_public_post_status', true)
    as member_public_post,
  current_setting('app.chunk_11d_member_public_reaction_status', true)
    as member_public_reaction,
  current_setting('app.chunk_11d_member_private_post_status', true)
    as member_members_only_post,
  current_setting('app.chunk_11d_member_private_reaction_status', true)
    as member_members_only_reaction,
  current_setting('app.chunk_11d_member_banned_author_status', true)
    as member_banned_author_post,
  current_setting('app.chunk_11d_member_banned_author_reaction_status', true)
    as member_banned_author_reaction,
  current_setting('app.chunk_11d_banned_reactor_status', true)
    as banned_reactor_hidden,
  current_setting('app.chunk_11d_banned_viewer_status', true)
    as banned_viewer_reads_members_only,
  current_setting('app.chunk_11d_banned_viewer_reaction_status', true)
    as banned_viewer_reads_members_only_reaction,
  current_setting('app.chunk_11d_admin_banned_author_status', true)
    as admin_banned_author_post,
  current_setting('app.chunk_11d_admin_banned_author_reaction_status', true)
    as admin_banned_author_reaction,
  current_setting('app.chunk_11d_service_private_status', true)
    as service_members_only_post,
  current_setting('app.chunk_11d_service_banned_author_status', true)
    as service_banned_author_post,
  current_setting('app.chunk_11d_service_private_reaction_status', true)
    as service_members_only_reaction,
  current_setting('app.chunk_11d_service_banned_author_reaction_status', true)
    as service_banned_author_reaction,
  current_setting('app.chunk_11d_service_post_helper_acl_status', true)
    as service_post_helper_execute,
  current_setting('app.chunk_11d_service_reaction_helper_acl_status', true)
    as service_reaction_helper_execute,
  'REQUIRED OUTSIDE SQL EDITOR: repeat anon and approved authenticated lookups through the real PostgREST/Supabase session paths'::text
    as external_session_path_check,
  'REQUIRES REPOSITORY STATIC CHECK: Stream client keeps show_in_stream = true'::text
    as application_stream_filter_check,
  'NOT RUN HERE: non-admin Hero switch and admin flag are mutating probes'::text
    as mutating_hero_runtime_check;

commit;
