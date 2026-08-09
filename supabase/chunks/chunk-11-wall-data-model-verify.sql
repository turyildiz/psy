-- psy.market database Chunk 11
-- READ-ONLY POST-APPLY VERIFICATION: Wall data model
--
-- Status: COMPLETED; Chunks 11A, 11B, and 11C owner-confirmed applied and verified.
-- This one script is intentionally stage-aware:
--   * after 11A: chunk_11a_checks_pass = true; 11B/11C are null;
--   * after 11B: chunk_11a_checks_pass and chunk_11b_checks_pass = true;
--   * after 11C: all three checks and all_applied_checks_pass = true.
--
-- The transaction is READ ONLY. It directly CALLS every ordinary helper and
-- every client/admin RPC. Mutating RPCs are called without JWT claims and must
-- reject with SQLSTATE 42501 before any write; an attempted write would instead
-- fail the read-only transaction. Trigger-only functions cannot legally be
-- called outside their trigger context, so their context/definition/trigger
-- binding is verified structurally here and requires a separately authorized
-- rollback-only runtime smoke after owner application.

begin transaction isolation level repeatable read read only;

-- Behavioral function calls. Dynamic SQL keeps this script runnable after each
-- dependency-ordered chunk while later functions do not yet exist.
do $function_calls$
declare
  chunk_11a_present boolean :=
    to_regclass('public.post_link_blocklist') is not null
    and to_regclass('public.post_write_rate_limits') is not null;
  chunk_11b_present boolean := to_regclass('public.posts') is not null;
  chunk_11c_present boolean :=
    to_regclass('public.post_reactions') is not null
    and to_regclass('public.post_moderation_audit') is not null;
  normalized_domain text;
  behavior_ok boolean;
  sample_profile_id uuid;
  sample_user_id uuid;
  sample_blocked_domain text;
  allowed_code_count bigint;
  invalid_row_count bigint;
begin
  if (to_regclass('public.post_link_blocklist') is null)
       <> (to_regclass('public.post_write_rate_limits') is null) then
    raise exception 'Chunk 11 verify failed: partial Chunk 11A object set';
  end if;

  if (to_regclass('public.post_reactions') is null)
       <> (to_regclass('public.post_moderation_audit') is null) then
    raise exception 'Chunk 11 verify failed: partial Chunk 11C object set';
  end if;

  if chunk_11b_present and not chunk_11a_present then
    raise exception 'Chunk 11 verify failed: Chunk 11B exists without 11A';
  end if;

  if chunk_11c_present and not chunk_11b_present then
    raise exception 'Chunk 11 verify failed: Chunk 11C exists without 11B';
  end if;

  if chunk_11a_present then
    execute $sql$
      select public.normalize_post_link_domain(
        'HTTPS://WWW.Example.COM:443/path?q=1#fragment'
      )
    $sql$ into normalized_domain;
    if normalized_domain <> 'example.com' then
      raise exception 'Chunk 11 verify failed: domain normalization call mismatch';
    end if;

    execute $sql$
      select count(*)
      from pg_catalog.unnest(
        array['love', 'fire', 'dance', 'trippy', 'shanti', 'sad']::text[]
      ) as code
      where public.is_valid_post_reaction_code(code)
    $sql$ into allowed_code_count;
    if allowed_code_count <> 6 then
      raise exception 'Chunk 11 verify failed: allowlisted reaction-code call mismatch';
    end if;

    execute $sql$
      select
        not public.is_valid_post_reaction_code('heart')
        and not public.is_valid_post_reaction_code('🔥')
        and not public.is_valid_post_reaction_code('LOVE')
    $sql$ into behavior_ok;
    if not behavior_ok then
      raise exception 'Chunk 11 verify failed: invalid reaction code accepted';
    end if;

    execute $sql$
      select
        public.post_image_array_has_unique_values(array[]::text[])
        and public.post_image_array_has_unique_values(array['a', 'b']::text[])
        and not public.post_image_array_has_unique_values(array['a', 'a']::text[])
        and not public.post_image_array_has_unique_values(
          array[['a', 'b'], ['c', 'd']]::text[]
        )
        and not public.post_image_array_has_unique_values(
          '[0:0]={a}'::text[]
        )
        and not public.post_image_array_has_unique_values(
          array['1', '2', '3', '4', '5', '6']::text[]
        )
    $sql$ into behavior_ok;
    if not behavior_ok then
      raise exception 'Chunk 11 verify failed: image-array validator call mismatch';
    end if;

    select p.id, p.user_id
      into sample_profile_id, sample_user_id
    from public.profiles as p
    order by p.id
    limit 1;

    if sample_profile_id is not null then
      execute $sql$
        select
          public.post_images_belong_to_profile(
            $1,
            array[
              'https://images.psy.market/posts/' || $2::text
              || '/00000000-0000-4000-8000-000000000001.jpg'
            ]::text[]
          )
          and not public.post_images_belong_to_profile(
            $1,
            array[
              'https://images.psy.market/posts/'
              || '00000000-0000-4000-8000-000000000099'
              || '/00000000-0000-4000-8000-000000000001.jpg'
            ]::text[]
          )
          and not public.post_images_belong_to_profile(
            $1,
            array[
              'https://images.psy.market/posts/' || $2::text
              || '/00000000-0000-1000-8000-000000000001.jpg'
            ]::text[]
          )
      $sql$ into behavior_ok using sample_profile_id, sample_user_id;
      if not behavior_ok then
        raise exception 'Chunk 11 verify failed: owner-namespace helper call mismatch';
      end if;
    else
      execute $sql$
        select not public.post_images_belong_to_profile(
          '00000000-0000-4000-8000-000000000099'::uuid,
          array[]::text[]
        )
      $sql$ into behavior_ok;
      if not behavior_ok then
        raise exception 'Chunk 11 verify failed: missing-profile image helper not fail-closed';
      end if;
    end if;

    execute $sql$
      select public.post_body_passes_link_blocklist('Plain text without a link')
    $sql$ into behavior_ok;
    if not behavior_ok then
      raise exception 'Chunk 11 verify failed: plain body rejected by blocklist helper';
    end if;

    execute $sql$
      select not public.post_body_passes_link_blocklist(
        'https://münich.example/path'
      )
    $sql$ into behavior_ok;
    if not behavior_ok then
      raise exception 'Chunk 11 verify failed: Unicode link host was not fail-closed';
    end if;

    select blocked.domain
      into sample_blocked_domain
    from public.post_link_blocklist as blocked
    order by blocked.domain
    limit 1;

    if sample_blocked_domain is not null then
      execute $sql$
        select not public.post_body_passes_link_blocklist(
          'https://' || $1 || '/blocked'
        )
      $sql$ into behavior_ok using sample_blocked_domain;
      if not behavior_ok then
        raise exception 'Chunk 11 verify failed: blocked-domain helper call mismatch';
      end if;
    end if;

    execute $sql$
      select coalesce(
        bool_and(
          public.profile_owner_is_banned(p.id)
          = (u.banned_at is not null)
        ),
        true
      )
      from public.profiles as p
      join public.users as u on u.id = p.user_id
    $sql$ into behavior_ok;
    if not behavior_ok then
      raise exception 'Chunk 11 verify failed: author-ban helper call mismatch';
    end if;

    -- SQL Editor has no end-user JWT. In that ordinary/non-admin viewer state,
    -- current_user_can_read_post_author must match unbanned authors exactly.
    execute $sql$
      select coalesce(
        bool_and(
          public.current_user_can_read_post_author(p.id)
          = (u.banned_at is null)
        ),
        true
      )
      from public.profiles as p
      join public.users as u on u.id = p.user_id
    $sql$ into behavior_ok;
    if not behavior_ok then
      raise exception 'Chunk 11 verify failed: visible-author helper call mismatch';
    end if;

    begin
      execute 'select public.consume_post_write_rate_limit()';
      raise exception 'Chunk 11 verify failed: limiter unexpectedly accepted owner/no-JWT caller';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.admin_block_post_link_domain(
          'verify.invalid',
          'Verification must not write'
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: block-domain RPC unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.admin_unblock_post_link_domain('verify.invalid')
      $sql$;
      raise exception 'Chunk 11 verify failed: unblock-domain RPC unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    execute $sql$
      select count(*)
      from public.post_write_rate_limits as limits
      where limits.user_id is null
         or limits.attempts is null
         or limits.updated_at is null
         or pg_catalog.cardinality(limits.attempts) > 20
         or pg_catalog.array_position(
           limits.attempts,
           null::timestamp with time zone
         ) is not null
    $sql$ into invalid_row_count;
    if invalid_row_count <> 0 then
      raise exception 'Chunk 11 verify failed: invalid post-write limiter row';
    end if;
  end if;

  if chunk_11b_present then
    begin
      execute $sql$
        select public.create_post(
          '00000000-0000-4000-8000-000000000001'::uuid,
          'Read-only verification',
          array[]::text[],
          true
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: create_post unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.update_post(
          '00000000-0000-4000-8000-000000000001'::uuid,
          'Read-only verification',
          array[]::text[],
          true
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: update_post unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.delete_own_post(
          '00000000-0000-4000-8000-000000000001'::uuid
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: delete_own_post unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.admin_flag_post_for_hero(
          '00000000-0000-4000-8000-000000000001'::uuid
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: Hero flag RPC unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.admin_unflag_post_for_hero(
          '00000000-0000-4000-8000-000000000001'::uuid
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: Hero unflag RPC unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    execute $sql$
      select count(*)
      from public.posts as post
      join public.profiles as profile on profile.id = post.profile_id
      join public.users as author on author.id = profile.user_id
      where pg_catalog.char_length(post.body) not between 1 and 2000
         or pg_catalog.char_length(pg_catalog.btrim(post.body)) = 0
         or not public.post_image_array_has_unique_values(post.images)
         or not public.post_images_belong_to_profile(post.profile_id, post.images)
         or (post.is_hero_featured and not post.show_in_stream)
         or (post.is_hero_featured and post.hero_featured_at is null)
         or (
           not post.is_hero_featured
           and (
             post.hero_featured_at is not null
             or post.hero_featured_by is not null
           )
         )
         or (author.banned_at is not null and post.is_hero_featured)
    $sql$ into invalid_row_count;
    if invalid_row_count <> 0 then
      raise exception 'Chunk 11 verify failed: invalid post row invariant';
    end if;
  end if;

  if chunk_11c_present then
    begin
      execute $sql$
        select public.set_post_reaction(
          '00000000-0000-4000-8000-000000000001'::uuid,
          '00000000-0000-4000-8000-000000000002'::uuid,
          'love'
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: set reaction RPC unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.remove_post_reaction(
          '00000000-0000-4000-8000-000000000001'::uuid,
          '00000000-0000-4000-8000-000000000002'::uuid
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: remove reaction RPC unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    begin
      execute $sql$
        select public.admin_delete_post(
          '00000000-0000-4000-8000-000000000001'::uuid,
          'Read-only verification'
        )
      $sql$;
      raise exception 'Chunk 11 verify failed: admin delete RPC unexpectedly authorized';
    exception
      when sqlstate '42501' then null;
    end;

    execute $sql$
      select count(*)
      from public.post_reactions as reaction
      where not public.is_valid_post_reaction_code(reaction.reaction_code)
    $sql$ into invalid_row_count;
    if invalid_row_count <> 0 then
      raise exception 'Chunk 11 verify failed: invalid stored reaction code';
    end if;

    execute $sql$
      select coalesce(bool_and(
        public.current_user_can_read_post_reaction(
          reaction.profile_id,
          reaction.post_id
        ) = (
          reactor.banned_at is null
          and post_author.banned_at is null
        )
      ), true)
      from public.post_reactions as reaction
      join public.profiles as reactor_profile
        on reactor_profile.id = reaction.profile_id
      join public.users as reactor
        on reactor.id = reactor_profile.user_id
      join public.posts as post
        on post.id = reaction.post_id
      join public.profiles as post_profile
        on post_profile.id = post.profile_id
      join public.users as post_author
        on post_author.id = post_profile.user_id
    $sql$ into behavior_ok;
    if not behavior_ok then
      raise exception 'Chunk 11 verify failed: reaction visibility helper mismatch';
    end if;
  end if;
end;
$function_calls$;

with
stage as (
  select
    to_regclass('public.post_link_blocklist') is not null
      and to_regclass('public.post_write_rate_limits') is not null
      as chunk_11a_present,
    to_regclass('public.posts') is not null as chunk_11b_present,
    to_regclass('public.post_reactions') is not null
      and to_regclass('public.post_moderation_audit') is not null
      as chunk_11c_present
),
chunk_11a as (
  select
    s.chunk_11a_present,
    case when not s.chunk_11a_present then null else (
      coalesce((
        select c.relrowsecurity and c.relforcerowsecurity
        from pg_class c
        where c.oid = to_regclass('public.follows')
      ), false)
      and coalesce((
        select a.attnotnull
        from pg_attribute a
        where a.attrelid = to_regclass('public.follows')
          and a.attname = 'created_at'
          and a.attnum > 0
          and not a.attisdropped
      ), false)
      and (
        select count(*) = 3
        from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = 'follows'
          and p.permissive = 'PERMISSIVE'
          and (
            (
              p.policyname = 'follows_select'
              and p.cmd = 'SELECT'
              and p.roles = array['public'::name]
              and lower(pg_catalog.regexp_replace(
                coalesce(p.qual, ''), E'\\s+', '', 'g'
              )) = 'true'
              and p.with_check is null
            )
            or (
              p.policyname = 'Unbanned users follow from own profile'
              and p.cmd = 'INSERT'
              and p.roles = array['authenticated'::name]
              and p.qual is null
              and lower(pg_catalog.regexp_replace(
                coalesce(p.with_check, ''), E'\\s+', '', 'g'
              )) =
                '((notcurrent_user_is_banned())andcurrent_user_owns_profile(follower_profile_id))'
            )
            or (
              p.policyname = 'Unbanned users unfollow from own profile'
              and p.cmd = 'DELETE'
              and p.roles = array['authenticated'::name]
              and lower(pg_catalog.regexp_replace(
                coalesce(p.qual, ''), E'\\s+', '', 'g'
              )) =
                '((notcurrent_user_is_banned())andcurrent_user_owns_profile(follower_profile_id))'
              and p.with_check is null
            )
          )
      )
      and has_table_privilege('anon', 'public.follows', 'SELECT')
      and not has_table_privilege('anon', 'public.follows', 'INSERT')
      and not has_table_privilege('anon', 'public.follows', 'UPDATE')
      and not has_table_privilege('anon', 'public.follows', 'DELETE')
      and has_table_privilege('authenticated', 'public.follows', 'SELECT')
      and has_table_privilege('authenticated', 'public.follows', 'INSERT')
      and has_table_privilege('authenticated', 'public.follows', 'DELETE')
      and not has_table_privilege('authenticated', 'public.follows', 'UPDATE')
      and has_table_privilege('service_role', 'public.follows', 'SELECT')
      and not has_table_privilege('service_role', 'public.follows', 'INSERT')
      and not has_table_privilege('service_role', 'public.follows', 'UPDATE')
      and not has_table_privilege('service_role', 'public.follows', 'DELETE')
      and (
        select count(*) = 2
        from pg_class c
        where c.oid in (
          to_regclass('public.post_link_blocklist'),
          to_regclass('public.post_write_rate_limits')
        )
          and c.relowner = 'postgres'::regrole
          and c.relrowsecurity
          and c.relforcerowsecurity
      )
      and (
        select count(*) = 4
        from pg_attribute a
        where a.attrelid = to_regclass('public.post_link_blocklist')
          and a.attnum > 0
          and not a.attisdropped
          and a.attname in ('domain', 'reason', 'created_at', 'created_by')
      )
      and (
        select count(*) = 3
        from pg_attribute a
        where a.attrelid = to_regclass('public.post_write_rate_limits')
          and a.attnum > 0
          and not a.attisdropped
          and a.attname in ('user_id', 'attempts', 'updated_at')
      )
      and (
        select count(*) = 4
        from pg_constraint c
        where c.conrelid = to_regclass('public.post_write_rate_limits')
          and c.convalidated
          and c.conname in (
            'post_write_rate_limits_pkey',
            'post_write_rate_limits_user_id_fkey',
            'post_write_rate_limits_attempt_count_check',
            'post_write_rate_limits_attempts_no_null_check'
          )
      )
      and (
        select count(*) = 1
        from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = 'post_link_blocklist'
          and p.policyname = 'Active admins read post link blocklist'
          and p.cmd = 'SELECT'
          and p.permissive = 'PERMISSIVE'
          and p.roles = array['authenticated'::name]
          and p.qual = 'current_user_is_admin()'
          and p.with_check is null
      )
      and (
        select count(*) = 1
        from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = 'post_link_blocklist'
      )
      and (
        select count(*) = 0
        from pg_policy p
        where p.polrelid = to_regclass('public.post_write_rate_limits')
      )
      and not has_table_privilege('anon', 'public.post_link_blocklist', 'SELECT')
      and has_table_privilege('authenticated', 'public.post_link_blocklist', 'SELECT')
      and has_table_privilege('service_role', 'public.post_link_blocklist', 'SELECT')
      and not has_table_privilege('authenticated', 'public.post_link_blocklist', 'INSERT')
      and not has_table_privilege('authenticated', 'public.post_link_blocklist', 'UPDATE')
      and not has_table_privilege('authenticated', 'public.post_link_blocklist', 'DELETE')
      and not exists (
        select 1
        from pg_class c
        cross join lateral aclexplode(
          coalesce(c.relacl, acldefault('r', c.relowner))
        ) a
        where c.oid = to_regclass('public.post_write_rate_limits')
          and a.grantee in (
            0::oid,
            'anon'::regrole,
            'authenticated'::regrole,
            'service_role'::regrole
          )
          and a.privilege_type in (
            'SELECT', 'INSERT', 'UPDATE', 'DELETE',
            'TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN'
          )
      )
      and (
        select
          count(*) = 8
          and count(*) filter (
            where
              (c.relname = 'follows' and (
                (acl.grantee = 'audit_readonly'::regrole and acl.privilege_type = 'SELECT')
                or (acl.grantee = 'anon'::regrole and acl.privilege_type = 'SELECT')
                or (acl.grantee = 'authenticated'::regrole and acl.privilege_type in ('SELECT', 'INSERT', 'DELETE'))
                or (acl.grantee = 'service_role'::regrole and acl.privilege_type = 'SELECT')
              ))
              or (c.relname = 'post_link_blocklist' and (
                (acl.grantee = 'authenticated'::regrole and acl.privilege_type = 'SELECT')
                or (acl.grantee = 'service_role'::regrole and acl.privilege_type = 'SELECT')
              ))
          ) = 8
          and bool_and(not acl.is_grantable and acl.grantor = 'postgres'::regrole)
        from pg_class c
        cross join lateral aclexplode(c.relacl) as acl
        where c.oid in (
          to_regclass('public.follows'),
          to_regclass('public.post_link_blocklist'),
          to_regclass('public.post_write_rate_limits')
        )
          and acl.grantee <> c.relowner
      )
      and (
        select count(*) = 10
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
            'admin_unblock_post_link_domain'
          )
          and p.proowner = 'postgres'::regrole
          and p.proconfig in (
            array['search_path=""'],
            array['search_path=']
          )
          and case
            when p.proname in (
              'profile_owner_is_banned',
              'current_user_can_read_post_author'
            ) then p.proacl::text =
              '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres}'
            when p.proname in (
              'admin_block_post_link_domain',
              'admin_unblock_post_link_domain'
            ) then p.proacl::text =
              '{postgres=X/postgres,authenticated=X/postgres}'
            else p.proacl::text = '{postgres=X/postgres}'
          end
      )
      and not has_function_privilege(
        'anon',
        to_regprocedure('public.admin_block_post_link_domain(text,text)'),
        'EXECUTE'
      )
      and has_function_privilege(
        'authenticated',
        to_regprocedure('public.admin_block_post_link_domain(text,text)'),
        'EXECUTE'
      )
      and not has_function_privilege(
        'service_role',
        to_regprocedure('public.admin_block_post_link_domain(text,text)'),
        'EXECUTE'
      )
      and not has_function_privilege(
        'authenticated',
        to_regprocedure('public.consume_post_write_rate_limit()'),
        'EXECUTE'
      )
    ) end as chunk_11a_checks_pass
  from stage s
),
chunk_11b as (
  select
    s.chunk_11b_present,
    case when not s.chunk_11b_present then null else (
      coalesce((
        select
          c.relowner = 'postgres'::regrole
          and c.relrowsecurity
          and c.relforcerowsecurity
        from pg_class c
        where c.oid = to_regclass('public.posts')
      ), false)
      and (
        select count(*) = 10
        from pg_attribute a
        where a.attrelid = to_regclass('public.posts')
          and a.attnum > 0
          and not a.attisdropped
          and a.attname in (
            'id', 'profile_id', 'body', 'images', 'show_in_stream',
            'is_hero_featured', 'hero_featured_at', 'hero_featured_by',
            'created_at', 'updated_at'
          )
      )
      and (
        select count(*) = 6
        from pg_constraint c
        where c.conrelid = to_regclass('public.posts')
          and c.convalidated
          and c.conname in (
            'posts_pkey',
            'posts_profile_id_fkey',
            'posts_hero_featured_by_fkey',
            'posts_body_check',
            'posts_images_check',
            'posts_hero_state_check'
          )
      )
      and (
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
      )
      and (
        select count(*) = 1
        from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = 'posts'
      )
      and (
        select count(*) = 3
        from pg_indexes i
        where i.schemaname = 'public'
          and i.tablename = 'posts'
          and i.indexname in (
            'posts_profile_created_id_idx',
            'posts_stream_created_id_idx',
            'posts_hero_featured_id_idx'
          )
      )
      and (
        select count(*) = 1
        from pg_trigger t
        where not t.tgisinternal
          and t.tgrelid = to_regclass('public.posts')
          and t.tgname = 'enforce_post_write_invariants_trigger'
          and t.tgfoid = to_regprocedure('public.enforce_post_write_invariants()')
          and t.tgenabled = 'O'
      )
      and (
        select count(*) = 1
        from pg_trigger t
        where not t.tgisinternal
          and t.tgrelid = to_regclass('public.users')
          and t.tgname = 'clear_hero_on_author_ban_trigger'
          and t.tgfoid = to_regprocedure('public.clear_hero_on_author_ban()')
          and t.tgenabled = 'O'
      )
      and (
        select count(*) = 7
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
          )
          and case
            when p.proname in (
              'create_post',
              'update_post',
              'delete_own_post',
              'admin_flag_post_for_hero',
              'admin_unflag_post_for_hero'
            ) then p.proacl::text =
              '{postgres=X/postgres,authenticated=X/postgres}'
            else p.proacl::text = '{postgres=X/postgres}'
          end
      )
      and coalesce((
        select
          md5(pg_catalog.replace(p.prosrc, pg_catalog.chr(13), '')) =
            '0eaadf98a9435a045952184867c5b888'
        from pg_proc p
        where p.oid = to_regprocedure('public.clear_hero_on_author_ban()')
      ), false)

      and has_table_privilege('anon', to_regclass('public.posts'), 'SELECT')
      and has_table_privilege('authenticated', to_regclass('public.posts'), 'SELECT')
      and has_table_privilege('service_role', to_regclass('public.posts'), 'SELECT')
      and not has_table_privilege('anon', to_regclass('public.posts'), 'INSERT')
      and not has_table_privilege('authenticated', to_regclass('public.posts'), 'INSERT')
      and not has_table_privilege('authenticated', to_regclass('public.posts'), 'UPDATE')
      and not has_table_privilege('authenticated', to_regclass('public.posts'), 'DELETE')
      and not has_table_privilege('service_role', to_regclass('public.posts'), 'INSERT')
      and (
        select
          count(*) = 3
          and bool_and(
            acl.grantee in (
              'anon'::regrole,
              'authenticated'::regrole,
              'service_role'::regrole
            )
            and acl.privilege_type = 'SELECT'
            and not acl.is_grantable
            and acl.grantor = 'postgres'::regrole
          )
        from pg_class c
        cross join lateral aclexplode(c.relacl) as acl
        where c.oid = to_regclass('public.posts')
          and acl.grantee <> c.relowner
      )
      and not has_function_privilege(
        'authenticated',
        to_regprocedure('public.enforce_post_write_invariants()'),
        'EXECUTE'
      )
      and not has_function_privilege(
        'anon',
        to_regprocedure('public.create_post(uuid,text,text[],boolean)'),
        'EXECUTE'
      )
      and has_function_privilege(
        'authenticated',
        to_regprocedure('public.create_post(uuid,text,text[],boolean)'),
        'EXECUTE'
      )
      and not has_function_privilege(
        'service_role',
        to_regprocedure('public.create_post(uuid,text,text[],boolean)'),
        'EXECUTE'
      )
    ) end as chunk_11b_checks_pass
  from stage s
),
chunk_11c as (
  select
    s.chunk_11c_present,
    case when not s.chunk_11c_present then null else (
      (
        select count(*) = 2
        from pg_class c
        where c.oid in (
          to_regclass('public.post_reactions'),
          to_regclass('public.post_moderation_audit')
        )
          and c.relowner = 'postgres'::regrole
          and c.relrowsecurity
          and c.relforcerowsecurity
      )
      and (
        select count(*) = 5
        from pg_attribute a
        where a.attrelid = to_regclass('public.post_reactions')
          and a.attnum > 0
          and not a.attisdropped
          and a.attname in (
            'id', 'post_id', 'profile_id', 'reaction_code', 'created_at'
          )
      )
      and (
        select count(*) = 6
        from pg_attribute a
        where a.attrelid = to_regclass('public.post_moderation_audit')
          and a.attnum > 0
          and not a.attisdropped
          and a.attname in (
            'id', 'post_id', 'author_profile_id',
            'deleted_by', 'reason', 'created_at'
          )
      )
      and (
        select count(*) = 5
        from pg_constraint c
        where c.conrelid = to_regclass('public.post_reactions')
          and c.convalidated
          and c.conname in (
            'post_reactions_pkey',
            'post_reactions_post_id_fkey',
            'post_reactions_profile_id_fkey',
            'post_reactions_post_profile_key',
            'post_reactions_code_check'
          )
      )
      and (
        select count(*) = 3
        from pg_constraint c
        where c.conrelid = to_regclass('public.post_moderation_audit')
          and c.convalidated
          and c.conname in (
            'post_moderation_audit_pkey',
            'post_moderation_audit_deleted_by_fkey',
            'post_moderation_audit_reason_check'
          )
      )
      and (
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
      )
      and (
        select count(*) = 1
        from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = 'post_reactions'
      )
      and (
        select count(*) = 1
        from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = 'post_moderation_audit'
          and p.policyname = 'Active admins read post moderation audit'
          and p.cmd = 'SELECT'
          and p.permissive = 'PERMISSIVE'
          and p.roles = array['authenticated'::name]
          and p.qual = 'current_user_is_admin()'
          and p.with_check is null
      )
      and (
        select count(*) = 1
        from pg_policies p
        where p.schemaname = 'public'
          and p.tablename = 'post_moderation_audit'
      )
      and (
        select count(*) = 1
        from pg_constraint c
        where c.conrelid = to_regclass('public.post_reactions')
          and c.conname = 'post_reactions_post_id_fkey'
          and c.contype = 'f'
          and c.confrelid = to_regclass('public.posts')
          and c.confdeltype = 'c'
          and c.convalidated
      )
      and (
        select count(*) = 4
        from pg_indexes i
        where i.schemaname = 'public'
          and (
            (
              i.tablename = 'post_reactions'
              and i.indexname = 'post_reactions_post_code_idx'
            )
            or (
              i.tablename = 'post_moderation_audit'
              and i.indexname in (
                'post_moderation_audit_post_idx',
                'post_moderation_audit_created_id_idx',
                'post_moderation_audit_deleted_by_created_idx'
              )
            )
          )
      )
      and (
        select count(*) = 1
        from pg_trigger t
        where not t.tgisinternal
          and t.tgrelid = to_regclass('public.post_reactions')
          and t.tgname = 'guard_post_reaction_identity_trigger'
          and t.tgfoid = to_regprocedure('public.guard_post_reaction_identity()')
          and t.tgenabled = 'O'
      )
      and (
        select count(*) = 0
        from pg_attribute a
        where a.attrelid = to_regclass('public.post_moderation_audit')
          and a.attnum > 0
          and not a.attisdropped
          and a.attname in (
            'body', 'images', 'image_urls', 'image_keys', 'excerpt', 'content'
          )
      )
      and (
        select count(*) = 5
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
          )
          and case
            when p.proname = 'current_user_can_read_post_reaction' then
              p.proacl::text =
                '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres}'
            when p.proname = 'guard_post_reaction_identity' then
              p.proacl::text = '{postgres=X/postgres}'
            else p.proacl::text =
              '{postgres=X/postgres,authenticated=X/postgres}'
          end
      )
      and has_table_privilege('anon', to_regclass('public.post_reactions'), 'SELECT')
      and has_table_privilege('authenticated', to_regclass('public.post_reactions'), 'SELECT')
      and has_table_privilege('service_role', to_regclass('public.post_reactions'), 'SELECT')
      and not has_table_privilege('authenticated', to_regclass('public.post_reactions'), 'INSERT')
      and not has_table_privilege('authenticated', to_regclass('public.post_reactions'), 'UPDATE')
      and not has_table_privilege('authenticated', to_regclass('public.post_reactions'), 'DELETE')
      and not has_table_privilege('anon', to_regclass('public.post_moderation_audit'), 'SELECT')
      and has_table_privilege('authenticated', to_regclass('public.post_moderation_audit'), 'SELECT')
      and has_table_privilege('service_role', to_regclass('public.post_moderation_audit'), 'SELECT')
      and not has_table_privilege('authenticated', to_regclass('public.post_moderation_audit'), 'INSERT')
      and (
        select
          count(*) = 5
          and count(*) filter (
            where
              (c.relname = 'post_reactions'
               and acl.grantee in (
                 'anon'::regrole,
                 'authenticated'::regrole,
                 'service_role'::regrole
               )
               and acl.privilege_type = 'SELECT')
              or (c.relname = 'post_moderation_audit'
                  and acl.grantee in (
                    'authenticated'::regrole,
                    'service_role'::regrole
                  )
                  and acl.privilege_type = 'SELECT')
          ) = 5
          and bool_and(not acl.is_grantable and acl.grantor = 'postgres'::regrole)
        from pg_class c
        cross join lateral aclexplode(c.relacl) as acl
        where c.oid in (
          to_regclass('public.post_reactions'),
          to_regclass('public.post_moderation_audit')
        )
          and acl.grantee <> c.relowner
      )
      and not has_function_privilege(
        'authenticated',
        to_regprocedure('public.guard_post_reaction_identity()'),
        'EXECUTE'
      )
      and not has_function_privilege(
        'anon',
        to_regprocedure('public.admin_delete_post(uuid,text)'),
        'EXECUTE'
      )
      and has_function_privilege(
        'authenticated',
        to_regprocedure('public.admin_delete_post(uuid,text)'),
        'EXECUTE'
      )
      and not has_function_privilege(
        'service_role',
        to_regprocedure('public.admin_delete_post(uuid,text)'),
        'EXECUTE'
      )
    ) end as chunk_11c_checks_pass
  from stage s
)
select
  a.chunk_11a_present,
  a.chunk_11a_checks_pass,
  b.chunk_11b_present,
  b.chunk_11b_checks_pass,
  c.chunk_11c_present,
  c.chunk_11c_checks_pass,
  (
    coalesce(a.chunk_11a_checks_pass, false)
    and coalesce(b.chunk_11b_checks_pass, false)
    and coalesce(c.chunk_11c_checks_pass, false)
  ) as all_applied_checks_pass
from chunk_11a a
cross join chunk_11b b
cross join chunk_11c c;

rollback;
