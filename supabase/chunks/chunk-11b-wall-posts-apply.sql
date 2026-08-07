-- psy.market database Chunk 11B
-- APPLY: posts table, database invariants, RLS, trusted author/Hero RPCs,
-- and ban-time Hero clearing.
--
-- Status: APPLIED AND VERIFIED (owner-confirmed).
-- Dependency: Chunk 11A applied and verified.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preconditions$
declare
  conflicting_function_count bigint;
begin
  if current_user <> 'postgres' then
    raise exception 'Chunk 11B must run as postgres';
  end if;

  if to_regclass('public.post_link_blocklist') is null
     or to_regclass('public.post_write_rate_limits') is null
     or to_regprocedure('public.current_user_can_read_post_author(uuid)') is null
     or to_regprocedure('public.post_images_belong_to_profile(uuid,text[])') is null
     or to_regprocedure('public.post_body_passes_link_blocklist(text)') is null
     or to_regprocedure('public.consume_post_write_rate_limit()') is null then
    raise exception 'Chunk 11B precondition failed: Chunk 11A dependency missing';
  end if;

  if to_regclass('public.posts') is not null then
    raise exception 'Chunk 11B precondition failed: posts already exists';
  end if;

  select count(*)
    into conflicting_function_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'enforce_post_write_invariants',
      'clear_hero_on_author_ban',
      'create_post',
      'update_post',
      'delete_own_post',
      'admin_flag_post_for_hero',
      'admin_unflag_post_for_hero'
    );

  if conflicting_function_count <> 0 then
    raise exception 'Chunk 11B precondition failed: function name collision';
  end if;
end;
$preconditions$;

create table public.posts (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  profile_id uuid not null,
  body text not null,
  images text[] not null default '{}'::text[],
  show_in_stream boolean not null default true,
  is_hero_featured boolean not null default false,
  hero_featured_at timestamp with time zone,
  hero_featured_by uuid,
  created_at timestamp with time zone not null
    default pg_catalog.clock_timestamp(),
  updated_at timestamp with time zone not null
    default pg_catalog.clock_timestamp(),
  constraint posts_profile_id_fkey
    foreign key (profile_id)
    references public.profiles(id)
    on delete cascade,
  constraint posts_hero_featured_by_fkey
    foreign key (hero_featured_by)
    references public.users(id)
    on delete set null,
  constraint posts_body_check
    check (
      pg_catalog.char_length(body) between 1 and 2000
      and pg_catalog.char_length(pg_catalog.btrim(body)) > 0
    ),
  constraint posts_images_check
    check (public.post_image_array_has_unique_values(images)),
  constraint posts_hero_state_check
    check (
      (
        not is_hero_featured
        and hero_featured_at is null
        and hero_featured_by is null
      )
      or (
        is_hero_featured
        and show_in_stream
        and hero_featured_at is not null
      )
    )
);

alter table public.posts owner to postgres;
alter table public.posts enable row level security;
alter table public.posts force row level security;

create index posts_profile_created_id_idx
  on public.posts (profile_id, created_at desc, id desc);
create index posts_stream_created_id_idx
  on public.posts (created_at desc, id desc)
  where show_in_stream;
create index posts_hero_featured_id_idx
  on public.posts (hero_featured_at desc, id desc)
  where is_hero_featured and show_in_stream;

create policy "Visible posts are publicly readable"
on public.posts
for select
to public
using (public.current_user_can_read_post_author(profile_id));

-- There are deliberately no INSERT/UPDATE/DELETE policies. Direct client DML
-- is fail-closed even if a table grant is introduced accidentally; reviewed
-- SECURITY DEFINER RPCs are the only post mutation boundary.

-- Trigger-owned invariants apply to every write path, including privileged RPCs.
create function public.enforce_post_write_invariants()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  caller_is_active_admin boolean := public.current_user_is_admin();
  author_auto_unflag boolean := false;
  ban_cleanup boolean := coalesce(
    pg_catalog.current_setting('app.wall_ban_hero_cleanup', true),
    ''
  ) = 'on';
  consumes_burst_quota boolean := false;
begin
  if tg_when <> 'BEFORE'
     or tg_level <> 'ROW'
     or tg_table_schema <> 'public'
     or tg_table_name <> 'posts'
     or tg_op not in ('INSERT', 'UPDATE') then
    raise exception 'Unexpected enforce_post_write_invariants trigger context'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.is_hero_featured
       or new.hero_featured_at is not null
       or new.hero_featured_by is not null then
      raise exception 'New posts cannot set Hero state'
        using errcode = '42501';
    end if;

    if not public.post_images_belong_to_profile(new.profile_id, new.images) then
      raise exception 'Post image URL is outside the author owner namespace'
        using errcode = '23514';
    end if;

    if not public.post_body_passes_link_blocklist(new.body) then
      raise exception 'Post body contains a blocked link domain'
        using errcode = '23514';
    end if;

    consumes_burst_quota := true;
  else
    if new.profile_id is distinct from old.profile_id then
      raise exception 'Post author profile cannot change'
        using errcode = '42501';
    end if;

    if new.images is distinct from old.images
       and not public.post_images_belong_to_profile(new.profile_id, new.images) then
      raise exception 'Post image URL is outside the author owner namespace'
        using errcode = '23514';
    end if;

    if new.body is distinct from old.body
       and not public.post_body_passes_link_blocklist(new.body) then
      raise exception 'Post body contains a blocked link domain'
        using errcode = '23514';
    end if;

    if not caller_is_active_admin
       and old.is_hero_featured
       and old.show_in_stream
       and not new.show_in_stream then
      new.is_hero_featured := false;
      new.hero_featured_at := null;
      new.hero_featured_by := null;
      author_auto_unflag := true;
    end if;

    if not caller_is_active_admin
       and not author_auto_unflag
       and not (
         ban_cleanup
         and not new.is_hero_featured
         and new.hero_featured_at is null
         and new.hero_featured_by is null
         and new.profile_id is not distinct from old.profile_id
         and new.body is not distinct from old.body
         and new.images is not distinct from old.images
         and new.show_in_stream is not distinct from old.show_in_stream
       )
       and (
         new.is_hero_featured is distinct from old.is_hero_featured
         or new.hero_featured_at is distinct from old.hero_featured_at
         or new.hero_featured_by is distinct from old.hero_featured_by
       ) then
      raise exception 'Only active admins can change Hero state'
        using errcode = '42501';
    end if;

    consumes_burst_quota :=
      new.body is distinct from old.body
      or new.images is distinct from old.images
      or new.show_in_stream is distinct from old.show_in_stream;
  end if;

  if consumes_burst_quota and auth.role() = 'authenticated' then
    if not public.consume_post_write_rate_limit() then
      raise exception 'Post write burst limit reached'
        using errcode = 'P0001';
    end if;
  end if;

  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$function$;

create trigger enforce_post_write_invariants_trigger
before insert or update on public.posts
for each row
execute function public.enforce_post_write_invariants();

-- Any route that changes users.banned_at from NULL to non-NULL clears Hero.
-- The transaction-local marker authorizes only the narrow Hero-clear update in
-- the posts invariant trigger; it grants no table/function privilege.
create function public.clear_hero_on_author_ban()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  previous_cleanup_setting text := pg_catalog.current_setting(
    'app.wall_ban_hero_cleanup',
    true
  );
begin
  if tg_when <> 'AFTER'
     or tg_level <> 'ROW'
     or tg_op <> 'UPDATE'
     or tg_table_schema <> 'public'
     or tg_table_name <> 'users' then
    raise exception 'Unexpected clear_hero_on_author_ban trigger context'
      using errcode = '42501';
  end if;

  if old.banned_at is null and new.banned_at is not null then
    perform pg_catalog.set_config('app.wall_ban_hero_cleanup', 'on', true);

    update public.posts as post
    set is_hero_featured = false,
        hero_featured_at = null,
        hero_featured_by = null
    where post.profile_id in (
      select profile.id
      from public.profiles as profile
      where profile.user_id = new.id
    )
      and post.is_hero_featured;

    perform pg_catalog.set_config(
      'app.wall_ban_hero_cleanup',
      coalesce(previous_cleanup_setting, ''),
      true
    );
  end if;

  return new;
end;
$function$;

create trigger clear_hero_on_author_ban_trigger
after update of banned_at on public.users
for each row
when (old.banned_at is null and new.banned_at is not null)
execute function public.clear_hero_on_author_ban();

-- Trusted authenticated author operations. They repeat caller, ban, ownership,
-- payload, link, and image checks before the trigger and constraints run.
create function public.create_post(
  target_profile_id uuid,
  post_body text,
  post_images text[] default '{}'::text[],
  include_in_stream boolean default true
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  caller_user_id uuid := auth.uid();
  created_post_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot create posts'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = target_profile_id
      and p.user_id = caller_user_id
  ) then
    raise exception 'Post profile is not owned by the caller'
      using errcode = '42501';
  end if;

  if post_body is null
     or pg_catalog.char_length(post_body) not between 1 and 2000
     or pg_catalog.char_length(pg_catalog.btrim(post_body)) = 0 then
    raise exception 'Post body must contain between 1 and 2000 characters'
      using errcode = '22023';
  end if;

  if post_images is null
     or not public.post_images_belong_to_profile(target_profile_id, post_images) then
    raise exception 'Post images are invalid or outside the owner namespace'
      using errcode = '22023';
  end if;

  if not public.post_body_passes_link_blocklist(post_body) then
    raise exception 'Post body contains a blocked link domain'
      using errcode = '22023';
  end if;

  insert into public.posts (
    profile_id,
    body,
    images,
    show_in_stream
  ) values (
    target_profile_id,
    post_body,
    post_images,
    coalesce(include_in_stream, true)
  )
  returning id into created_post_id;

  return created_post_id;
end;
$function$;

create function public.update_post(
  target_post_id uuid,
  post_body text,
  post_images text[],
  include_in_stream boolean
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  caller_user_id uuid := auth.uid();
  author_profile_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot update posts'
      using errcode = '42501';
  end if;

  select p.profile_id
    into author_profile_id
  from public.posts as p
  where p.id = target_post_id
  for update;

  if author_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = author_profile_id
      and profile.user_id = caller_user_id
  ) then
    raise exception 'Post is not owned by the caller'
      using errcode = '42501';
  end if;

  if post_body is null
     or pg_catalog.char_length(post_body) not between 1 and 2000
     or pg_catalog.char_length(pg_catalog.btrim(post_body)) = 0 then
    raise exception 'Post body must contain between 1 and 2000 characters'
      using errcode = '22023';
  end if;

  if post_images is null
     or not public.post_images_belong_to_profile(author_profile_id, post_images) then
    raise exception 'Post images are invalid or outside the owner namespace'
      using errcode = '22023';
  end if;

  if not public.post_body_passes_link_blocklist(post_body) then
    raise exception 'Post body contains a blocked link domain'
      using errcode = '22023';
  end if;

  if include_in_stream is null then
    raise exception 'Post Stream visibility must be true or false'
      using errcode = '22023';
  end if;

  update public.posts as p
  set body = post_body,
      images = post_images,
      show_in_stream = include_in_stream,
      is_hero_featured = case
        when include_in_stream then p.is_hero_featured
        else false
      end,
      hero_featured_at = case
        when include_in_stream then p.hero_featured_at
        else null
      end,
      hero_featured_by = case
        when include_in_stream then p.hero_featured_by
        else null
      end
  where p.id = target_post_id;
end;
$function$;

create function public.delete_own_post(
  target_post_id uuid
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
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot delete posts'
      using errcode = '42501';
  end if;

  delete from public.posts as post
  using public.profiles as profile
  where post.id = target_post_id
    and profile.id = post.profile_id
    and profile.user_id = caller_user_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;
$function$;

create function public.admin_flag_post_for_hero(
  target_post_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  target_profile_id uuid;
  target_show_in_stream boolean;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required'
      using errcode = '42501';
  end if;

  select p.profile_id, p.show_in_stream
    into target_profile_id, target_show_in_stream
  from public.posts as p
  where p.id = target_post_id
  for update;

  if target_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  if not target_show_in_stream then
    raise exception 'A post excluded from Stream cannot be flagged for Hero'
      using errcode = '23514';
  end if;

  if public.profile_owner_is_banned(target_profile_id) then
    raise exception 'A banned author post cannot be flagged for Hero'
      using errcode = '42501';
  end if;

  update public.posts as p
  set is_hero_featured = true,
      hero_featured_at = pg_catalog.clock_timestamp(),
      hero_featured_by = auth.uid()
  where p.id = target_post_id;
end;
$function$;

create function public.admin_unflag_post_for_hero(
  target_post_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required'
      using errcode = '42501';
  end if;

  update public.posts as p
  set is_hero_featured = false,
      hero_featured_at = null,
      hero_featured_by = null
  where p.id = target_post_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;
end;
$function$;

-- Table ACLs: clients can read through RLS, but every mutation must use a
-- reviewed RPC. service_role receives SELECT for complete media-reference and
-- operational scans, not direct mutation.
revoke all privileges on table public.posts
  from public, anon, authenticated, service_role;
grant select on table public.posts
  to anon, authenticated, service_role;

alter function public.enforce_post_write_invariants() owner to postgres;
alter function public.clear_hero_on_author_ban() owner to postgres;
alter function public.create_post(uuid, text, text[], boolean) owner to postgres;
alter function public.update_post(uuid, text, text[], boolean) owner to postgres;
alter function public.delete_own_post(uuid) owner to postgres;
alter function public.admin_flag_post_for_hero(uuid) owner to postgres;
alter function public.admin_unflag_post_for_hero(uuid) owner to postgres;

revoke all privileges on function public.enforce_post_write_invariants()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.clear_hero_on_author_ban()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.create_post(uuid, text, text[], boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.update_post(uuid, text, text[], boolean)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.delete_own_post(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.admin_flag_post_for_hero(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.admin_unflag_post_for_hero(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.create_post(uuid, text, text[], boolean)
  to authenticated;
grant execute on function public.update_post(uuid, text, text[], boolean)
  to authenticated;
grant execute on function public.delete_own_post(uuid)
  to authenticated;
grant execute on function public.admin_flag_post_for_hero(uuid)
  to authenticated;
grant execute on function public.admin_unflag_post_for_hero(uuid)
  to authenticated;

comment on table public.posts is
  'V1 profile Wall posts. Rows are physically deleted; images are full promoted URLs.';
comment on constraint posts_hero_state_check on public.posts is
  'Database invariant: a post excluded from Stream cannot be Hero featured.';
comment on function public.create_post(uuid, text, text[], boolean) is
  'Trusted authenticated post creation boundary; trigger consumes burst quota.';
comment on function public.update_post(uuid, text, text[], boolean) is
  'Trusted authenticated post update boundary; Stream opt-out atomically clears Hero.';
comment on function public.delete_own_post(uuid) is
  'Physically deletes the caller-owned post so image URLs become unreferenced.';

-- Transactional postconditions.
do $postconditions$
declare
  expected_function_count bigint;
  expected_policy_count bigint;
begin
  if not exists (
    select 1
    from pg_class c
    where c.oid = 'public.posts'::regclass
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) then
    raise exception 'Chunk 11B postcondition failed: posts owner/RLS mismatch';
  end if;

  select count(*)
    into expected_policy_count
  from pg_policies p
  where p.schemaname = 'public'
    and p.tablename = 'posts'
    and p.policyname = 'Visible posts are publicly readable'
    and p.cmd = 'SELECT'
    and p.permissive = 'PERMISSIVE'
    and p.roles = array['public'::name]
    and p.qual = 'current_user_can_read_post_author(profile_id)'
    and p.with_check is null;

  if expected_policy_count <> 1
     or (select count(*) from pg_policies p
         where p.schemaname = 'public' and p.tablename = 'posts') <> 1 then
    raise exception 'Chunk 11B postcondition failed: exact posts policy set mismatch';
  end if;

  if (
    select count(*)
    from pg_trigger t
    where not t.tgisinternal
      and t.tgrelid = 'public.posts'::regclass
      and t.tgname = 'enforce_post_write_invariants_trigger'
      and t.tgfoid = to_regprocedure('public.enforce_post_write_invariants()')
      and t.tgenabled = 'O'
  ) <> 1 then
    raise exception 'Chunk 11B postcondition failed: invariant trigger mismatch';
  end if;

  if (
    select count(*)
    from pg_trigger t
    where not t.tgisinternal
      and t.tgrelid = 'public.users'::regclass
      and t.tgname = 'clear_hero_on_author_ban_trigger'
      and t.tgfoid = to_regprocedure('public.clear_hero_on_author_ban()')
      and t.tgenabled = 'O'
  ) <> 1 then
    raise exception 'Chunk 11B postcondition failed: ban Hero-clear trigger mismatch';
  end if;

  select count(*)
    into expected_function_count
  from pg_proc p
  where p.oid in (
    to_regprocedure('public.enforce_post_write_invariants()'),
    to_regprocedure('public.clear_hero_on_author_ban()'),
    to_regprocedure('public.create_post(uuid,text,text[],boolean)'),
    to_regprocedure('public.update_post(uuid,text,text[],boolean)'),
    to_regprocedure('public.delete_own_post(uuid)'),
    to_regprocedure('public.admin_flag_post_for_hero(uuid)'),
    to_regprocedure('public.admin_unflag_post_for_hero(uuid)')
  )
    and p.proowner = 'postgres'::regrole
    and p.prosecdef
    and p.proconfig in (
      array['search_path=""'],
      array['search_path=']
    );

  if expected_function_count <> 7 then
    raise exception 'Chunk 11B postcondition failed: function hardening mismatch';
  end if;

  if has_table_privilege('anon', 'public.posts', 'INSERT')
     or has_table_privilege('authenticated', 'public.posts', 'INSERT')
     or has_table_privilege('authenticated', 'public.posts', 'UPDATE')
     or has_table_privilege('authenticated', 'public.posts', 'DELETE')
     or has_table_privilege('service_role', 'public.posts', 'INSERT')
     or not has_table_privilege('anon', 'public.posts', 'SELECT')
     or not has_table_privilege('authenticated', 'public.posts', 'SELECT')
     or not has_table_privilege('service_role', 'public.posts', 'SELECT') then
    raise exception 'Chunk 11B postcondition failed: posts ACL mismatch';
  end if;

  if has_function_privilege('anon', 'public.create_post(uuid,text,text[],boolean)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.create_post(uuid,text,text[],boolean)', 'EXECUTE')
     or has_function_privilege('service_role', 'public.create_post(uuid,text,text[],boolean)', 'EXECUTE')
     or has_function_privilege('anon', 'public.admin_flag_post_for_hero(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.admin_flag_post_for_hero(uuid)', 'EXECUTE')
     or has_function_privilege('service_role', 'public.admin_flag_post_for_hero(uuid)', 'EXECUTE') then
    raise exception 'Chunk 11B postcondition failed: RPC ACL mismatch';
  end if;


  if exists (
    with actual(grantee_name, privilege_type, is_grantable, grantor_name) as (
      select
        case when acl.grantee = 0 then 'PUBLIC'
          else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable,
        acl.grantor::regrole::text
      from pg_class c
      cross join lateral aclexplode(c.relacl) as acl
      where c.oid = 'public.posts'::regclass
        and acl.grantee <> c.relowner
    ),
    expected(grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('anon', 'SELECT', false, 'postgres'),
        ('authenticated', 'SELECT', false, 'postgres'),
        ('service_role', 'SELECT', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11B postcondition failed: posts direct ACL set mismatch';
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
          'enforce_post_write_invariants',
          'clear_hero_on_author_ban',
          'create_post',
          'update_post',
          'delete_own_post',
          'admin_flag_post_for_hero',
          'admin_unflag_post_for_hero'
        )
        and acl.grantee <> p.proowner
    ),
    expected(function_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('create_post', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('update_post', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('delete_own_post', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('admin_flag_post_for_hero', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('admin_unflag_post_for_hero', 'authenticated', 'EXECUTE', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11B postcondition failed: direct function ACL set mismatch';
  end if;

  if exists (
    select 1
    from public.posts as p
    where (p.is_hero_featured and not p.show_in_stream)
       or (p.is_hero_featured and p.hero_featured_at is null)
       or (not p.is_hero_featured and (
         p.hero_featured_at is not null or p.hero_featured_by is not null
       ))
  ) then
    raise exception 'Chunk 11B postcondition failed: invalid Hero row exists';
  end if;
end;
$postconditions$;

commit;
