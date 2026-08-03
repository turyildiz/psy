-- psy.market database Chunk 11
-- ROLLBACK: fully remove the Wall data-model package and restore the reviewed
-- pre-Chunk-11 follows schema and ACL state.
--
-- Status: NOT APPLIED.
-- This rollback is for a fully applied 11A + 11B + 11C package.
--
-- Schema/authorization rollback is complete, but no rollback can resurrect:
--   * posts physically deleted by authors/admins while Chunk 11 was active;
--   * Hero flags cleared by bans or Stream opt-out;
--   * post/reaction/blocklist rows created after apply once their tables drop;
--   * moderation audit rows or ephemeral burst timestamps once dropped.
-- Take a reviewed backup before running this destructive rollback.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preconditions$
begin
  if current_user <> 'postgres' then
    raise exception 'Chunk 11 rollback must run as postgres';
  end if;

  if to_regclass('public.posts') is null
     or to_regclass('public.post_reactions') is null
     or to_regclass('public.post_moderation_audit') is null
     or to_regclass('public.post_link_blocklist') is null
     or to_regclass('public.post_write_rate_limits') is null then
    raise exception 'Chunk 11 rollback refused: fully applied table set missing';
  end if;

  if to_regprocedure('public.create_post(uuid,text,text[],boolean)') is null
     or to_regprocedure('public.update_post(uuid,text,text[],boolean)') is null
     or to_regprocedure('public.delete_own_post(uuid)') is null
     or to_regprocedure('public.set_post_reaction(uuid,uuid,text)') is null
     or to_regprocedure('public.remove_post_reaction(uuid,uuid)') is null
     or to_regprocedure('public.admin_delete_post(uuid,text)') is null then
    raise exception 'Chunk 11 rollback refused: expected RPC missing';
  end if;

  if not exists (
    select 1
    from pg_class c
    where c.oid = 'public.follows'::regclass
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) then
    raise exception 'Chunk 11 rollback refused: hardened follows state missing';
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
      where c.oid = 'public.follows'::regclass
        and acl.grantee <> c.relowner
    ),
    expected(grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('audit_readonly', 'SELECT', false, 'postgres'),
        ('anon', 'SELECT', false, 'postgres'),
        ('authenticated', 'SELECT', false, 'postgres'),
        ('authenticated', 'INSERT', false, 'postgres'),
        ('authenticated', 'DELETE', false, 'postgres'),
        ('service_role', 'SELECT', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11 rollback refused: hardened follows direct ACL drifted';
  end if;

  if not coalesce((
    select
      md5(pg_catalog.replace(p.prosrc, pg_catalog.chr(13), '')) =
        '0eaadf98a9435a045952184867c5b888'
      and p.proowner = 'postgres'::regrole
      and p.prosecdef
      and p.proconfig in (array['search_path=""'], array['search_path='])
      and p.proacl::text = '{postgres=X/postgres}'
    from pg_proc p
    where p.oid = to_regprocedure('public.clear_hero_on_author_ban()')
  ), false) then
    raise exception 'Chunk 11 rollback refused: ban Hero trigger helper drifted';
  end if;
end;
$preconditions$;

-- Chunk 11C: remove privileged mutations before their tables.
drop function public.admin_delete_post(uuid, text);
drop function public.remove_post_reaction(uuid, uuid);
drop function public.set_post_reaction(uuid, uuid, text);

drop trigger guard_post_reaction_identity_trigger
  on public.post_reactions;
drop function public.guard_post_reaction_identity();

drop table public.post_reactions;
drop table public.post_moderation_audit;
drop function public.current_user_can_read_post_reaction(uuid, uuid);

-- Chunk 11B: remove post RPCs, triggers, and table without CASCADE.
drop function public.admin_unflag_post_for_hero(uuid);
drop function public.admin_flag_post_for_hero(uuid);
drop function public.delete_own_post(uuid);
drop function public.update_post(uuid, text, text[], boolean);
drop function public.create_post(uuid, text, text[], boolean);

drop trigger enforce_post_write_invariants_trigger
  on public.posts;
drop function public.enforce_post_write_invariants();

drop trigger clear_hero_on_author_ban_trigger
  on public.users;
drop function public.clear_hero_on_author_ban();

drop table public.posts;

-- Chunk 11A: remove administrative blocklist RPCs and internal limiter.
drop function public.admin_unblock_post_link_domain(text);
drop function public.admin_block_post_link_domain(text, text);
drop function public.consume_post_write_rate_limit();
drop table public.post_write_rate_limits;

drop function public.post_body_passes_link_blocklist(text);
drop table public.post_link_blocklist;

drop function public.post_images_belong_to_profile(uuid, text[]);
drop function public.current_user_can_read_post_author(uuid);
drop function public.profile_owner_is_banned(uuid);
drop function public.post_image_array_has_unique_values(text[]);
drop function public.is_valid_post_reaction_code(text);
drop function public.normalize_post_link_domain(text);

-- Restore follows to the exact broad pre-Chunk-11 API ACL shape and non-forced
-- RLS mode. Existing rows and policies were never removed.
alter table public.follows no force row level security;
alter table public.follows
  alter column created_at drop not null;

revoke all privileges on table public.follows
  from public, anon, authenticated, service_role, audit_readonly;
grant all privileges on table public.follows
  to anon, authenticated, service_role;
grant select on table public.follows
  to audit_readonly;

-- Rollback postconditions.
do $postconditions$
begin
  if to_regclass('public.posts') is not null
     or to_regclass('public.post_reactions') is not null
     or to_regclass('public.post_moderation_audit') is not null
     or to_regclass('public.post_link_blocklist') is not null
     or to_regclass('public.post_write_rate_limits') is not null then
    raise exception 'Chunk 11 rollback postcondition failed: package table remains';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'normalize_post_link_domain',
        'is_valid_post_reaction_code',
        'post_image_array_has_unique_values',
        'profile_owner_is_banned',
        'current_user_can_read_post_author',
        'post_images_belong_to_profile',
        'post_body_passes_link_blocklist',
        'consume_post_write_rate_limit',
        'admin_block_post_link_domain',
        'admin_unblock_post_link_domain',
        'enforce_post_write_invariants',
        'clear_hero_on_author_ban',
        'create_post',
        'update_post',
        'delete_own_post',
        'admin_flag_post_for_hero',
        'admin_unflag_post_for_hero',
        'current_user_can_read_post_reaction',
        'guard_post_reaction_identity',
        'set_post_reaction',
        'remove_post_reaction',
        'admin_delete_post'
      )
  ) then
    raise exception 'Chunk 11 rollback postcondition failed: package function remains';
  end if;

  if not exists (
    select 1
    from pg_class c
    where c.oid = 'public.follows'::regclass
      and c.relrowsecurity
      and not c.relforcerowsecurity
  ) or exists (
    select 1
    from pg_attribute a
    where a.attrelid = 'public.follows'::regclass
      and a.attname = 'created_at'
      and a.attnotnull
  ) then
    raise exception 'Chunk 11 rollback postcondition failed: follows state not restored';
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
      where c.oid = 'public.follows'::regclass
        and acl.grantee <> c.relowner
    ),
    expected(grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('anon', 'SELECT', false, 'postgres'),
        ('anon', 'INSERT', false, 'postgres'),
        ('anon', 'UPDATE', false, 'postgres'),
        ('anon', 'DELETE', false, 'postgres'),
        ('anon', 'TRUNCATE', false, 'postgres'),
        ('anon', 'REFERENCES', false, 'postgres'),
        ('anon', 'TRIGGER', false, 'postgres'),
        ('anon', 'MAINTAIN', false, 'postgres'),
        ('authenticated', 'SELECT', false, 'postgres'),
        ('authenticated', 'INSERT', false, 'postgres'),
        ('authenticated', 'UPDATE', false, 'postgres'),
        ('authenticated', 'DELETE', false, 'postgres'),
        ('authenticated', 'TRUNCATE', false, 'postgres'),
        ('authenticated', 'REFERENCES', false, 'postgres'),
        ('authenticated', 'TRIGGER', false, 'postgres'),
        ('authenticated', 'MAINTAIN', false, 'postgres'),
        ('service_role', 'SELECT', false, 'postgres'),
        ('service_role', 'INSERT', false, 'postgres'),
        ('service_role', 'UPDATE', false, 'postgres'),
        ('service_role', 'DELETE', false, 'postgres'),
        ('service_role', 'TRUNCATE', false, 'postgres'),
        ('service_role', 'REFERENCES', false, 'postgres'),
        ('service_role', 'TRIGGER', false, 'postgres'),
        ('service_role', 'MAINTAIN', false, 'postgres'),
        ('audit_readonly', 'SELECT', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11 rollback postcondition failed: follows direct ACL not restored';
  end if;
end;
$postconditions$;

commit;
