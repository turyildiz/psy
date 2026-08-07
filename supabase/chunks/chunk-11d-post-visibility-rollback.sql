-- psy.market database Chunk 11D
-- ROLLBACK: restore exact pre-11D public post/reaction visibility.
--
-- Status: AVAILABLE FOR ROLLBACK ONLY; NOT RUN as of 2026-08-07.
-- WARNING: this rollback intentionally makes show_in_stream = false posts and
-- their allowed reactions anonymously readable again.
--
-- No table data is intentionally rewritten by this rollback.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Fail closed unless the exact reviewed 11D state is still installed.
do $preconditions$
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
    raise exception 'Chunk 11D rollback must run as postgres';
  end if;

  if not coalesce((
    select not r.rolsuper and r.rolbypassrls
    from pg_roles r
    where r.rolname = 'postgres'
  ), false) then
    raise exception 'Chunk 11D rollback precondition failed: postgres role attributes drifted';
  end if;

  if not coalesce((
    select r.rolbypassrls
    from pg_roles r
    where r.rolname = 'service_role'
  ), false) then
    raise exception 'Chunk 11D rollback precondition failed: service_role BYPASSRLS drifted';
  end if;

  if author_helper_oid is null
     or visibility_helper_oid is null
     or reaction_helper_oid is null then
    raise exception 'Chunk 11D rollback precondition failed: helper missing';
  end if;

  if (
    select count(*)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'current_user_can_read_post'
  ) <> 1 then
    raise exception 'Chunk 11D rollback precondition failed: conflicting visibility helper overload';
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
    raise exception 'Chunk 11D rollback precondition failed: baseline helper overload set drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: table owner/RLS drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: posts policy drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: reaction policy drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: author helper drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: visibility helper drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: reaction helper drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: table ACL drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: function ACL drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: mutation RPC signature/ACL drifted';
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
    raise exception 'Chunk 11D rollback precondition failed: Hero invariant drifted';
  end if;
end;
$preconditions$;

-- Restore the exact captured pre-11D reaction helper body.
create or replace function public.current_user_can_read_post_reaction(
  reaction_profile_id uuid,
  target_post_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    not public.profile_owner_is_banned($1)
    and coalesce((
      select public.current_user_can_read_post_author(post.profile_id)
      from public.posts as post
      where post.id = $2
    ), false);
$function$;

alter function public.current_user_can_read_post_reaction(uuid, uuid)
  owner to postgres;
revoke all privileges on function public.current_user_can_read_post_reaction(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.current_user_can_read_post_reaction(uuid, uuid)
  to anon, authenticated;

-- Restore the exact captured pre-11D posts policy.
drop policy "Visible posts are publicly readable" on public.posts;
create policy "Visible posts are publicly readable"
on public.posts
for select
to public
using (public.current_user_can_read_post_author(profile_id));

-- Dependencies have been restored to the old helper; the 11D helper can now go.
drop function public.current_user_can_read_post(uuid, boolean);

-- Transactional postconditions: restore the exact captured pre-11D state.
do $postconditions$
declare
  author_helper_oid oid := to_regprocedure(
    'public.current_user_can_read_post_author(uuid)'
  );
  reaction_helper_oid oid := to_regprocedure(
    'public.current_user_can_read_post_reaction(uuid,uuid)'
  );
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'current_user_can_read_post'
  ) then
    raise exception 'Chunk 11D rollback postcondition failed: visibility helper name remains';
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
    raise exception 'Chunk 11D rollback postcondition failed: baseline helper overload set mismatch';
  end if;

  if author_helper_oid is null or reaction_helper_oid is null then
    raise exception 'Chunk 11D rollback postcondition failed: baseline helper missing';
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
    raise exception 'Chunk 11D rollback postcondition failed: table owner/RLS mismatch';
  end if;

  if not coalesce((
    select r.rolbypassrls
    from pg_roles r
    where r.rolname = 'service_role'
  ), false) then
    raise exception 'Chunk 11D rollback postcondition failed: service_role BYPASSRLS mismatch';
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
    raise exception 'Chunk 11D rollback postcondition failed: author helper drifted';
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
      and p.qual = 'current_user_can_read_post_author(profile_id)'
      and p.with_check is null
  ) <> 1
     or (
       select count(*)
       from pg_policies p
       where p.schemaname = 'public'
         and p.tablename = 'posts'
     ) <> 1 then
    raise exception 'Chunk 11D rollback postcondition failed: posts policy mismatch';
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
    raise exception 'Chunk 11D rollback postcondition failed: reaction policy mismatch';
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
      )) = 'select not public.profile_owner_is_banned($1) and coalesce(( select public.current_user_can_read_post_author(post.profile_id) from public.posts as post where post.id = $2 ), false);'
  ) then
    raise exception 'Chunk 11D rollback postcondition failed: reaction helper mismatch';
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
      where p.oid in (author_helper_oid, reaction_helper_oid)
        and acl.grantee <> p.proowner
    ),
    expected(function_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('current_user_can_read_post_author', 'anon', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_author', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_reaction', 'anon', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_reaction', 'authenticated', 'EXECUTE', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11D rollback postcondition failed: function ACL set mismatch';
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
    raise exception 'Chunk 11D rollback postcondition failed: table ACL set mismatch';
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
    raise exception 'Chunk 11D rollback postcondition failed: mutation RPC signature/ACL mismatch';
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
    raise exception 'Chunk 11D rollback postcondition failed: Hero invariant mismatch';
  end if;
end;
$postconditions$;

commit;
