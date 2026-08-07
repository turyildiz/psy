-- psy.market database Chunk 11D
-- READ-ONLY PREFLIGHT: public versus members-only post visibility.
--
-- Status: COMPLETED — GO (owner-confirmed 2026-08-07).
--
-- Run this before Chunk 11D apply. It returns exactly one summary row and
-- performs no writes. Apply only when go_no_go = 'GO'.
--
-- Dependency: owner-applied and verified Chunks 11A, 11B, and 11C.

begin transaction isolation level repeatable read read only;

with
role_checks as (
  select
    current_database() = 'postgres' as expected_database_name,
    current_user = 'postgres' as expected_executor,
    coalesce((
      select not r.rolsuper and r.rolbypassrls
      from pg_roles r
      where r.rolname = 'postgres'
    ), false) as expected_owner_role_attributes,
    coalesce((
      select r.rolbypassrls
      from pg_roles r
      where r.rolname = 'service_role'
    ), false) as service_role_bypasses_rls,
    to_regrole('anon') is not null as anon_role_exists,
    to_regrole('authenticated') is not null as authenticated_role_exists
),
table_checks as (
  select
    coalesce((
      select
        c.relkind = 'r'
        and c.relowner = 'postgres'::regrole
        and c.relrowsecurity
        and c.relforcerowsecurity
      from pg_class c
      where c.oid = to_regclass('public.posts')
    ), false) as posts_table_matches,
    coalesce((
      select
        c.relkind = 'r'
        and c.relowner = 'postgres'::regrole
        and c.relrowsecurity
        and c.relforcerowsecurity
      from pg_class c
      where c.oid = to_regclass('public.post_reactions')
    ), false) as reactions_table_matches,
    coalesce((
      select
        a.atttypid = 'boolean'::regtype
        and a.attnotnull
        and not a.attisdropped
      from pg_attribute a
      where a.attrelid = to_regclass('public.posts')
        and a.attname = 'show_in_stream'
        and a.attnum > 0
    ), false) as show_in_stream_column_matches,
    coalesce((
      select
        c.contype = 'c'
        and c.convalidated
        and pg_catalog.strpos(
          pg_get_constraintdef(c.oid, true),
          'show_in_stream'
        ) > 0
        and pg_catalog.strpos(
          pg_get_constraintdef(c.oid, true),
          'is_hero_featured'
        ) > 0
      from pg_constraint c
      where c.conrelid = to_regclass('public.posts')
        and c.conname = 'posts_hero_state_check'
    ), false) as hero_constraint_matches
),
policy_checks as (
  select
    (
      select count(*) = 1
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'posts'
        and p.policyname = 'Visible posts are publicly readable'
        and p.cmd = 'SELECT'
        and p.permissive = 'PERMISSIVE'
        and p.roles = array['public'::name]
        and p.qual = 'current_user_can_read_post_author(profile_id)'
        and p.with_check is null
    ) and (
      select count(*) = 1
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'posts'
    ) as posts_policy_exact,
    (
      select count(*) = 1
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'post_reactions'
        and p.policyname = 'Visible reactions are publicly readable'
        and p.cmd = 'SELECT'
        and p.permissive = 'PERMISSIVE'
        and p.roles = array['public'::name]
        and p.qual = 'current_user_can_read_post_reaction(profile_id, post_id)'
        and p.with_check is null
    ) and (
      select count(*) = 1
      from pg_policies p
      where p.schemaname = 'public'
        and p.tablename = 'post_reactions'
    ) as reactions_policy_exact
),
function_checks as (
  select
    not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'current_user_can_read_post'
    ) as new_visibility_helper_absent,
    (
      select count(*) = 2
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in (
          'current_user_can_read_post_author',
          'current_user_can_read_post_reaction'
        )
    ) as baseline_helper_name_sets_exact,
    coalesce((
      select
        p.proowner = 'postgres'::regrole
        and p.prosecdef
        and p.provolatile = 's'
        and l.lanname = 'sql'
        and pg_get_function_result(p.oid) = 'boolean'
        and pg_get_function_identity_arguments(p.oid) = 'target_profile_id uuid'
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
      from pg_proc p
      join pg_language l on l.oid = p.prolang
      where p.oid = to_regprocedure(
        'public.current_user_can_read_post_author(uuid)'
      )
    ), false) as author_helper_exact,
    coalesce((
      select
        p.proowner = 'postgres'::regrole
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
      from pg_proc p
      join pg_language l on l.oid = p.prolang
      where p.oid = to_regprocedure(
        'public.current_user_can_read_post_reaction(uuid,uuid)'
      )
    ), false) as reaction_helper_exact
),
table_acl_checks as (
  select not exists (
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
        to_regclass('public.posts'),
        to_regclass('public.post_reactions')
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
  ) as table_acls_exact
),
function_acl_checks as (
  select not exists (
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
        to_regprocedure('public.current_user_can_read_post_author(uuid)'),
        to_regprocedure('public.current_user_can_read_post_reaction(uuid,uuid)')
      )
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
  ) as function_acls_exact
),
data_checks as (
  select
    count(*) filter (where p.show_in_stream) as public_post_count,
    count(*) filter (where not p.show_in_stream) as members_only_post_count,
    count(*) filter (
      where p.is_hero_featured and not p.show_in_stream
    ) as invalid_hero_post_count
  from public.posts p
),
reaction_data_checks as (
  select
    count(*) filter (where p.show_in_stream) as public_parent_reaction_count,
    count(*) filter (where not p.show_in_stream) as members_only_parent_reaction_count,
    count(*) filter (where p.id is null) as orphan_reaction_count
  from public.post_reactions r
  left join public.posts p on p.id = r.post_id
),
summary as (
  select
    rc.*,
    tc.*,
    pc.*,
    fc.*,
    tac.table_acls_exact,
    fac.function_acls_exact,
    dc.public_post_count,
    dc.members_only_post_count,
    dc.invalid_hero_post_count,
    rdc.public_parent_reaction_count,
    rdc.members_only_parent_reaction_count,
    rdc.orphan_reaction_count
  from role_checks rc
  cross join table_checks tc
  cross join policy_checks pc
  cross join function_checks fc
  cross join table_acl_checks tac
  cross join function_acl_checks fac
  cross join data_checks dc
  cross join reaction_data_checks rdc
)
select
  case when
    expected_database_name
    and expected_executor
    and expected_owner_role_attributes
    and service_role_bypasses_rls
    and anon_role_exists
    and authenticated_role_exists
    and posts_table_matches
    and reactions_table_matches
    and show_in_stream_column_matches
    and hero_constraint_matches
    and posts_policy_exact
    and reactions_policy_exact
    and new_visibility_helper_absent
    and baseline_helper_name_sets_exact
    and author_helper_exact
    and reaction_helper_exact
    and table_acls_exact
    and function_acls_exact
    and invalid_hero_post_count = 0
    and orphan_reaction_count = 0
  then 'GO'
  else 'NO-GO'
  end as go_no_go,
  expected_database_name,
  expected_executor,
  expected_owner_role_attributes,
  service_role_bypasses_rls,
  anon_role_exists,
  authenticated_role_exists,
  posts_table_matches,
  reactions_table_matches,
  show_in_stream_column_matches,
  hero_constraint_matches,
  posts_policy_exact,
  reactions_policy_exact,
  new_visibility_helper_absent,
  baseline_helper_name_sets_exact,
  author_helper_exact,
  reaction_helper_exact,
  table_acls_exact,
  function_acls_exact,
  public_post_count,
  members_only_post_count,
  public_parent_reaction_count,
  members_only_parent_reaction_count,
  invalid_hero_post_count,
  orphan_reaction_count
from summary;

commit;
