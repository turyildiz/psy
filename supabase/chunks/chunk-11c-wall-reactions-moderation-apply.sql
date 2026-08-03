-- psy.market database Chunk 11C
-- APPLY: coded post reactions, metadata-only admin deletion audit, reaction
-- RPCs, and atomic admin hard deletion.
--
-- Status: NOT APPLIED.
-- Dependency: Chunks 11A and 11B applied and verified.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preconditions$
declare
  conflicting_function_count bigint;
begin
  if current_user <> 'postgres' then
    raise exception 'Chunk 11C must run as postgres';
  end if;

  if to_regclass('public.posts') is null
     or to_regprocedure('public.is_valid_post_reaction_code(text)') is null
     or to_regprocedure('public.profile_owner_is_banned(uuid)') is null
     or to_regprocedure('public.current_user_can_read_post_author(uuid)') is null then
    raise exception 'Chunk 11C precondition failed: Chunk 11A/11B dependency missing';
  end if;

  if to_regclass('public.post_reactions') is not null
     or to_regclass('public.post_moderation_audit') is not null then
    raise exception 'Chunk 11C precondition failed: target table already exists';
  end if;

  select count(*)
    into conflicting_function_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'current_user_can_read_post_reaction',
      'guard_post_reaction_identity',
      'set_post_reaction',
      'remove_post_reaction',
      'admin_delete_post'
    );

  if conflicting_function_count <> 0 then
    raise exception 'Chunk 11C precondition failed: function name collision';
  end if;
end;
$preconditions$;

create table public.post_reactions (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  post_id uuid not null,
  profile_id uuid not null,
  reaction_code text not null,
  created_at timestamp with time zone not null
    default pg_catalog.clock_timestamp(),
  constraint post_reactions_post_id_fkey
    foreign key (post_id)
    references public.posts(id)
    on delete cascade,
  constraint post_reactions_profile_id_fkey
    foreign key (profile_id)
    references public.profiles(id)
    on delete cascade,
  constraint post_reactions_post_profile_key
    unique (post_id, profile_id),
  constraint post_reactions_code_check
    check (public.is_valid_post_reaction_code(reaction_code))
);

alter table public.post_reactions owner to postgres;
alter table public.post_reactions enable row level security;
alter table public.post_reactions force row level security;

create index post_reactions_post_code_idx
  on public.post_reactions (post_id, reaction_code);

create function public.current_user_can_read_post_reaction(
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

create policy "Visible reactions are publicly readable"
on public.post_reactions
for select
to public
using (public.current_user_can_read_post_reaction(profile_id, post_id));

-- There are deliberately no INSERT/UPDATE/DELETE policies. Direct client DML
-- is fail-closed; the set/remove RPCs are the only reaction mutation boundary.

create function public.guard_post_reaction_identity()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  if tg_when <> 'BEFORE'
     or tg_level <> 'ROW'
     or tg_op <> 'UPDATE'
     or tg_table_schema <> 'public'
     or tg_table_name <> 'post_reactions' then
    raise exception 'Unexpected guard_post_reaction_identity trigger context'
      using errcode = '42501';
  end if;

  if new.post_id is distinct from old.post_id
     or new.profile_id is distinct from old.profile_id then
    raise exception 'Reaction post and profile identities cannot change'
      using errcode = '42501';
  end if;

  if new.reaction_code is distinct from old.reaction_code then
    new.created_at := pg_catalog.clock_timestamp();
  else
    new.created_at := old.created_at;
  end if;

  return new;
end;
$function$;

create trigger guard_post_reaction_identity_trigger
before update on public.post_reactions
for each row
execute function public.guard_post_reaction_identity();

create table public.post_moderation_audit (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  post_id uuid not null,
  author_profile_id uuid not null,
  deleted_by uuid,
  reason text not null,
  created_at timestamp with time zone not null
    default pg_catalog.clock_timestamp(),
  constraint post_moderation_audit_deleted_by_fkey
    foreign key (deleted_by)
    references public.users(id)
    on delete set null,
  constraint post_moderation_audit_reason_check
    check (
      reason = pg_catalog.btrim(reason)
      and pg_catalog.char_length(reason) between 3 and 500
    )
);

alter table public.post_moderation_audit owner to postgres;
alter table public.post_moderation_audit enable row level security;
alter table public.post_moderation_audit force row level security;

create index post_moderation_audit_post_idx
  on public.post_moderation_audit (post_id);
create index post_moderation_audit_created_id_idx
  on public.post_moderation_audit (created_at desc, id desc);
create index post_moderation_audit_deleted_by_created_idx
  on public.post_moderation_audit (deleted_by, created_at desc);

create policy "Active admins read post moderation audit"
on public.post_moderation_audit
for select
to authenticated
using (public.current_user_is_admin());

-- One stable reaction row per profile/post pair. A code change updates that row
-- and refreshes its reaction timestamp; it never inserts a second reaction.
create function public.set_post_reaction(
  target_post_id uuid,
  target_profile_id uuid,
  target_reaction_code text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  caller_user_id uuid := auth.uid();
  parent_profile_id uuid;
  reaction_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated reaction owner required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot react to posts'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = target_profile_id
      and p.user_id = caller_user_id
  ) then
    raise exception 'Reaction profile is not owned by the caller'
      using errcode = '42501';
  end if;

  if not public.is_valid_post_reaction_code(target_reaction_code) then
    raise exception 'Unsupported post reaction code'
      using errcode = '22023';
  end if;

  select p.profile_id
    into parent_profile_id
  from public.posts as p
  where p.id = target_post_id;

  if parent_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  if public.profile_owner_is_banned(parent_profile_id) then
    raise exception 'Reactions are disabled while the post author is banned'
      using errcode = '42501';
  end if;

  insert into public.post_reactions as reaction (
    post_id,
    profile_id,
    reaction_code
  ) values (
    target_post_id,
    target_profile_id,
    target_reaction_code
  )
  on conflict (post_id, profile_id) do update
  set reaction_code = excluded.reaction_code
  returning reaction.id into reaction_id;

  return reaction_id;
end;
$function$;

create function public.remove_post_reaction(
  target_post_id uuid,
  target_profile_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  caller_user_id uuid := auth.uid();
  affected_rows bigint;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated reaction owner required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot remove reactions'
      using errcode = '42501';
  end if;

  delete from public.post_reactions as reaction
  using public.profiles as profile
  where reaction.post_id = target_post_id
    and reaction.profile_id = target_profile_id
    and profile.id = reaction.profile_id
    and profile.user_id = caller_user_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Reaction does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;
$function$;

-- Atomic metadata-only audit plus hard delete. No post text, image URL, image
-- key, excerpt, or profile foreign key is copied into the audit record.
create function public.admin_delete_post(
  target_post_id uuid,
  reason text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  normalized_reason text := pg_catalog.btrim(reason);
  target_author_profile_id uuid;
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required'
      using errcode = '42501';
  end if;

  if normalized_reason is null
     or pg_catalog.char_length(normalized_reason) not between 3 and 500 then
    raise exception 'Deletion reason must contain between 3 and 500 characters'
      using errcode = '22023';
  end if;

  select post.profile_id
    into target_author_profile_id
  from public.posts as post
  where post.id = target_post_id
  for update;

  if target_author_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  insert into public.post_moderation_audit (
    post_id,
    author_profile_id,
    deleted_by,
    reason
  ) values (
    target_post_id,
    target_author_profile_id,
    auth.uid(),
    normalized_reason
  );

  delete from public.posts as post
  where post.id = target_post_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post hard deletion failed';
  end if;
end;
$function$;

revoke all privileges on table public.post_reactions
  from public, anon, authenticated, service_role;
grant select on table public.post_reactions
  to anon, authenticated, service_role;

revoke all privileges on table public.post_moderation_audit
  from public, anon, authenticated, service_role;
grant select on table public.post_moderation_audit
  to authenticated, service_role;

alter function public.current_user_can_read_post_reaction(uuid, uuid) owner to postgres;
alter function public.guard_post_reaction_identity() owner to postgres;
alter function public.set_post_reaction(uuid, uuid, text) owner to postgres;
alter function public.remove_post_reaction(uuid, uuid) owner to postgres;
alter function public.admin_delete_post(uuid, text) owner to postgres;

revoke all privileges on function public.current_user_can_read_post_reaction(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.guard_post_reaction_identity()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.set_post_reaction(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.remove_post_reaction(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.admin_delete_post(uuid, text)
  from public, anon, authenticated, service_role;

grant execute on function public.current_user_can_read_post_reaction(uuid, uuid)
  to anon, authenticated;
grant execute on function public.set_post_reaction(uuid, uuid, text)
  to authenticated;
grant execute on function public.remove_post_reaction(uuid, uuid)
  to authenticated;
grant execute on function public.admin_delete_post(uuid, text)
  to authenticated;

comment on table public.post_reactions is
  'One fixed allowlisted reaction code per profile/post pair.';
comment on table public.post_moderation_audit is
  'Metadata-only records of admin hard deletion; never stores post content or image references.';
comment on function public.admin_delete_post(uuid, text) is
  'Atomically records a bounded metadata-only moderation reason and physically deletes the post.';

-- Transactional postconditions.
do $postconditions$
declare
  expected_function_count bigint;
begin
  if not exists (
    select 1
    from pg_class c
    where c.oid = 'public.post_reactions'::regclass
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) or not exists (
    select 1
    from pg_class c
    where c.oid = 'public.post_moderation_audit'::regclass
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) then
    raise exception 'Chunk 11C postcondition failed: table owner/RLS mismatch';
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
     or (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = 'post_reactions') <> 1 then
    raise exception 'Chunk 11C postcondition failed: exact reaction policy mismatch';
  end if;

  if (
    select count(*)
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = 'post_moderation_audit'
      and p.policyname = 'Active admins read post moderation audit'
      and p.cmd = 'SELECT'
      and p.permissive = 'PERMISSIVE'
      and p.roles = array['authenticated'::name]
      and p.qual = 'current_user_is_admin()'
      and p.with_check is null
  ) <> 1
     or (select count(*) from pg_policies p
         where p.schemaname = 'public'
           and p.tablename = 'post_moderation_audit') <> 1 then
    raise exception 'Chunk 11C postcondition failed: exact audit policy mismatch';
  end if;

  if (
    select count(*)
    from pg_trigger t
    where not t.tgisinternal
      and t.tgrelid = 'public.post_reactions'::regclass
      and t.tgname = 'guard_post_reaction_identity_trigger'
      and t.tgfoid = to_regprocedure('public.guard_post_reaction_identity()')
      and t.tgenabled = 'O'
  ) <> 1 then
    raise exception 'Chunk 11C postcondition failed: reaction trigger mismatch';
  end if;

  select count(*)
    into expected_function_count
  from pg_proc p
  where p.oid in (
    to_regprocedure('public.current_user_can_read_post_reaction(uuid,uuid)'),
    to_regprocedure('public.guard_post_reaction_identity()'),
    to_regprocedure('public.set_post_reaction(uuid,uuid,text)'),
    to_regprocedure('public.remove_post_reaction(uuid,uuid)'),
    to_regprocedure('public.admin_delete_post(uuid,text)')
  )
    and p.proowner = 'postgres'::regrole
    and p.prosecdef
    and p.proconfig in (
      array['search_path=""'],
      array['search_path=']
    );

  if expected_function_count <> 5 then
    raise exception 'Chunk 11C postcondition failed: function hardening mismatch';
  end if;

  if has_table_privilege('authenticated', 'public.post_reactions', 'INSERT')
     or has_table_privilege('authenticated', 'public.post_reactions', 'UPDATE')
     or has_table_privilege('authenticated', 'public.post_reactions', 'DELETE')
     or has_table_privilege('authenticated', 'public.post_moderation_audit', 'INSERT')
     or has_table_privilege('authenticated', 'public.post_moderation_audit', 'UPDATE')
     or has_table_privilege('authenticated', 'public.post_moderation_audit', 'DELETE')
     or not has_table_privilege('anon', 'public.post_reactions', 'SELECT')
     or not has_table_privilege('authenticated', 'public.post_moderation_audit', 'SELECT') then
    raise exception 'Chunk 11C postcondition failed: table ACL mismatch';
  end if;

  if has_function_privilege('anon', 'public.set_post_reaction(uuid,uuid,text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.set_post_reaction(uuid,uuid,text)', 'EXECUTE')
     or has_function_privilege('service_role', 'public.set_post_reaction(uuid,uuid,text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_delete_post(uuid,text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.admin_delete_post(uuid,text)', 'EXECUTE')
     or has_function_privilege('service_role', 'public.admin_delete_post(uuid,text)', 'EXECUTE') then
    raise exception 'Chunk 11C postcondition failed: RPC ACL mismatch';
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
        'public.post_reactions'::regclass,
        'public.post_moderation_audit'::regclass
      )
        and acl.grantee <> c.relowner
    ),
    expected(object_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('post_reactions', 'anon', 'SELECT', false, 'postgres'),
        ('post_reactions', 'authenticated', 'SELECT', false, 'postgres'),
        ('post_reactions', 'service_role', 'SELECT', false, 'postgres'),
        ('post_moderation_audit', 'authenticated', 'SELECT', false, 'postgres'),
        ('post_moderation_audit', 'service_role', 'SELECT', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11C postcondition failed: direct table ACL set mismatch';
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
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral aclexplode(p.proacl) as acl
      where n.nspname = 'public'
        and p.proname in (
          'current_user_can_read_post_reaction',
          'guard_post_reaction_identity',
          'set_post_reaction',
          'remove_post_reaction',
          'admin_delete_post'
        )
        and acl.grantee <> p.proowner
    ),
    expected(function_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('current_user_can_read_post_reaction', 'anon', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_reaction', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('set_post_reaction', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('remove_post_reaction', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('admin_delete_post', 'authenticated', 'EXECUTE', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11C postcondition failed: direct function ACL set mismatch';
  end if;

  if exists (
    select 1
    from public.post_reactions as reaction
    where not public.is_valid_post_reaction_code(reaction.reaction_code)
  ) then
    raise exception 'Chunk 11C postcondition failed: invalid reaction code exists';
  end if;
end;
$postconditions$;

commit;
