-- psy.market database Chunk 11A
-- APPLY: Wall foundation, follows hardening, link blocklist, validation helpers,
-- and internal post-write burst limiter.
--
-- Status: APPLIED AND VERIFIED (owner-confirmed).
-- Dependency: chunk-11-wall-data-model-preflight.sql must return
-- all_preflight_checks_pass = true.
--
-- This chunk does not create posts yet. It preserves all follows rows and all
-- existing follows policies.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Exact fail-closed guards for the reviewed pre-Chunk-11 state.
do $preconditions$
declare
  conflicting_function_count bigint;
begin
  if current_user <> 'postgres' then
    raise exception 'Chunk 11A must run as postgres';
  end if;

  if to_regclass('public.follows') is null
     or to_regclass('public.users') is null
     or to_regclass('public.profiles') is null
     or to_regclass('auth.users') is null then
    raise exception 'Chunk 11A precondition failed: required base relation missing';
  end if;

  if to_regclass('public.post_link_blocklist') is not null
     or to_regclass('public.post_write_rate_limits') is not null then
    raise exception 'Chunk 11A precondition failed: new support table already exists';
  end if;

  select count(*)
    into conflicting_function_count
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
    );

  if conflicting_function_count <> 0 then
    raise exception 'Chunk 11A precondition failed: function name collision';
  end if;

  if not exists (
    select 1
    from pg_class c
    where c.oid = 'public.follows'::regclass
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity
      and not c.relforcerowsecurity
  ) then
    raise exception 'Chunk 11A precondition failed: follows owner/RLS drifted';
  end if;

  if exists (select 1 from public.follows f where f.created_at is null) then
    raise exception 'Chunk 11A precondition failed: follows.created_at contains nulls';
  end if;

  if (
    select count(*)
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = 'follows'
      and p.policyname in (
        'follows_select',
        'Unbanned users follow from own profile',
        'Unbanned users unfollow from own profile'
      )
  ) <> 3 then
    raise exception 'Chunk 11A precondition failed: follows policy set drifted';
  end if;

  if not exists (
    select 1 from pg_roles r
    where r.rolname = 'postgres'
      and not r.rolsuper
      and r.rolbypassrls
  ) then
    raise exception 'Chunk 11A precondition failed: postgres owner state drifted';
  end if;

  if (
    select count(*) from pg_roles r
    where r.rolname in ('anon', 'authenticated', 'service_role')
  ) <> 3 then
    raise exception 'Chunk 11A precondition failed: required API role missing';
  end if;
end;
$preconditions$;

-- Retain the existing follow graph and policies; only make the timestamp
-- non-null, force RLS, and narrow table ACLs.
alter table public.follows
  alter column created_at set not null;
alter table public.follows force row level security;

revoke all privileges on table public.follows
  from public, anon, authenticated, service_role;
grant select on table public.follows
  to anon, authenticated, service_role;
grant insert, delete on table public.follows
  to authenticated;

-- Pure normalized-domain validator. The result is a lower-case hostname with
-- no scheme, credentials, port, path, query, fragment, leading www, or trailing
-- dot. IP literals and single-label names are intentionally rejected.
create function public.normalize_post_link_domain(
  raw_domain text
)
returns text
language plpgsql
immutable
strict
set search_path = ''
as $function$
declare
  normalized_domain text := pg_catalog.lower(pg_catalog.btrim(raw_domain));
begin
  normalized_domain := pg_catalog.regexp_replace(
    normalized_domain,
    '^[a-z][a-z0-9+.-]*://',
    '',
    'i'
  );
  normalized_domain := pg_catalog.split_part(normalized_domain, '/', 1);
  normalized_domain := pg_catalog.split_part(normalized_domain, '?', 1);
  normalized_domain := pg_catalog.split_part(normalized_domain, '#', 1);
  normalized_domain := pg_catalog.regexp_replace(
    normalized_domain,
    ':[0-9]+$',
    ''
  );
  normalized_domain := pg_catalog.regexp_replace(
    normalized_domain,
    '^www[.]',
    '',
    'i'
  );
  normalized_domain := pg_catalog.regexp_replace(
    normalized_domain,
    '[.]+$',
    ''
  );

  if pg_catalog.strpos(normalized_domain, '@') > 0
     or pg_catalog.char_length(normalized_domain) > 253
     or normalized_domain !~
       '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?[.])+(?:[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?)$' then
    raise exception 'Invalid normalized post-link domain'
      using errcode = '22023';
  end if;

  return normalized_domain;
end;
$function$;

create function public.is_valid_post_reaction_code(
  reaction_code text
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $function$
  select $1 = any (
    array['love', 'fire', 'dance', 'trippy', 'shanti', 'sad']::text[]
  );
$function$;

create function public.post_image_array_has_unique_values(
  image_urls text[]
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $function$
  select case
    when pg_catalog.cardinality($1) not between 0 and 5 then false
    when pg_catalog.cardinality($1) = 0 then true
    when pg_catalog.array_ndims($1) <> 1
      or pg_catalog.array_lower($1, 1) <> 1 then false
    else
      pg_catalog.array_position($1, null::text) is null
      and not exists (
        select 1
        from pg_catalog.unnest($1) as image_url
        where pg_catalog.btrim(image_url) = ''
      )
      and pg_catalog.cardinality($1) = (
        select pg_catalog.count(distinct image_url)
        from pg_catalog.unnest($1) as image_url
      )
  end;
$function$;

create table public.post_link_blocklist (
  domain text primary key,
  reason text,
  created_at timestamp with time zone not null
    default pg_catalog.clock_timestamp(),
  created_by uuid,
  constraint post_link_blocklist_domain_normalized_check
    check (domain = public.normalize_post_link_domain(domain)),
  constraint post_link_blocklist_reason_check
    check (
      reason is null
      or (
        reason = pg_catalog.btrim(reason)
        and pg_catalog.char_length(reason) between 3 and 500
      )
    ),
  constraint post_link_blocklist_created_by_fkey
    foreign key (created_by)
    references public.users(id)
    on delete set null
);

alter table public.post_link_blocklist owner to postgres;
alter table public.post_link_blocklist enable row level security;
alter table public.post_link_blocklist force row level security;

create policy "Active admins read post link blocklist"
on public.post_link_blocklist
for select
to authenticated
using (public.current_user_is_admin());

revoke all privileges on table public.post_link_blocklist
  from public, anon, authenticated, service_role;
grant select on table public.post_link_blocklist
  to authenticated, service_role;

create table public.post_write_rate_limits (
  user_id uuid primary key,
  attempts timestamp with time zone[] not null
    default '{}'::timestamp with time zone[],
  updated_at timestamp with time zone not null
    default pg_catalog.clock_timestamp(),
  constraint post_write_rate_limits_user_id_fkey
    foreign key (user_id)
    references auth.users(id)
    on delete cascade,
  constraint post_write_rate_limits_attempt_count_check
    check (pg_catalog.cardinality(attempts) between 0 and 20),
  constraint post_write_rate_limits_attempts_no_null_check
    check (
      pg_catalog.array_position(
        attempts,
        null::timestamp with time zone
      ) is null
    )
);

alter table public.post_write_rate_limits owner to postgres;
alter table public.post_write_rate_limits enable row level security;
alter table public.post_write_rate_limits force row level security;

-- Internal state: no policies and no API table grants.
revoke all privileges on table public.post_write_rate_limits
  from public, anon, authenticated, service_role;

create function public.profile_owner_is_banned(
  target_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    (
      select u.banned_at is not null
      from public.profiles as p
      join public.users as u on u.id = p.user_id
      where p.id = $1
    ),
    true
  );
$function$;

create function public.current_user_can_read_post_author(
  target_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    not public.profile_owner_is_banned($1)
    or public.current_user_is_admin();
$function$;

create function public.post_images_belong_to_profile(
  target_profile_id uuid,
  image_urls text[]
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  owner_user_id uuid;
  required_pattern text;
begin
  if not public.post_image_array_has_unique_values(image_urls) then
    return false;
  end if;

  select p.user_id
    into owner_user_id
  from public.profiles as p
  where p.id = target_profile_id;

  if owner_user_id is null then
    return false;
  end if;

  required_pattern :=
    '^https://images[.]psy[.]market/posts/'
    || owner_user_id::text
    || '/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}[.](jpg|png|webp)$';

  return not exists (
    select 1
    from pg_catalog.unnest(image_urls) as image_url
    where image_url !~ required_pattern
  );
end;
$function$;

create function public.post_body_passes_link_blocklist(
  post_body text
)
returns boolean
language sql
stable
strict
security definer
set search_path = ''
as $function$
  with linkish_tokens as (
    select token_parts[1] as token
    from pg_catalog.regexp_matches(
      $1,
      $regex$([^[:space:]<>]+[.][^[:space:]<>]+)$regex$,
      'g'
    ) as token_match(token_parts)
  ),
  extracted_domains as (
    select pg_catalog.lower(parts[1]) as domain
    from pg_catalog.regexp_matches(
      $1,
      $regex$\m(?:https?://)?(?:www[.])?((?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?[.])+(?:[a-z](?:[a-z0-9-]{0,61}[a-z0-9])?))$regex$,
      'gi'
    ) as found(parts)
  )
  select
    not exists (
      select 1
      from linkish_tokens as candidate
      where pg_catalog.octet_length(candidate.token)
        <> pg_catalog.char_length(candidate.token)
    )
    and not exists (
      select 1
      from extracted_domains as extracted
      join public.post_link_blocklist as blocked
        on extracted.domain = blocked.domain
        or extracted.domain like '%.' || blocked.domain
    );
$function$;

-- Internal atomic limiter: 20 accepted post creates/updates per rolling ten
-- minutes. It is consumed by the post invariant trigger, not called directly by
-- the client.
create function public.consume_post_write_rate_limit()
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  caller_role text := auth.role();
  caller_user_id uuid := auth.uid();
  request_timestamp timestamp with time zone := pg_catalog.clock_timestamp();
  cutoff_timestamp timestamp with time zone;
  retained_attempts timestamp with time zone[];
begin
  if caller_role <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post writer identity required'
      using errcode = '42501';
  end if;

  cutoff_timestamp := request_timestamp - interval '10 minutes';

  insert into public.post_write_rate_limits as limits (user_id)
  values (caller_user_id)
  on conflict (user_id) do nothing;

  select limits.attempts
    into retained_attempts
  from public.post_write_rate_limits as limits
  where limits.user_id = caller_user_id
  for update;

  if not found then
    raise exception 'Post-write limiter row could not be locked';
  end if;

  retained_attempts := array(
    select attempt_timestamp
    from pg_catalog.unnest(retained_attempts) as attempt_timestamp
    where attempt_timestamp > cutoff_timestamp
    order by attempt_timestamp
  );

  if pg_catalog.cardinality(retained_attempts) >= 20 then
    update public.post_write_rate_limits as limits
    set attempts = retained_attempts,
        updated_at = request_timestamp
    where limits.user_id = caller_user_id;
    return false;
  end if;

  retained_attempts := pg_catalog.array_append(
    retained_attempts,
    request_timestamp
  );

  update public.post_write_rate_limits as limits
  set attempts = retained_attempts,
      updated_at = request_timestamp
  where limits.user_id = caller_user_id;

  return true;
end;
$function$;

create function public.admin_block_post_link_domain(
  target_domain text,
  target_reason text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  normalized_domain text;
  normalized_reason text;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required'
      using errcode = '42501';
  end if;

  normalized_domain := public.normalize_post_link_domain(target_domain);
  normalized_reason := nullif(pg_catalog.btrim(target_reason), '');

  if normalized_reason is not null
     and pg_catalog.char_length(normalized_reason) not between 3 and 500 then
    raise exception 'Block reason must contain between 3 and 500 characters'
      using errcode = '22023';
  end if;

  insert into public.post_link_blocklist as blocked (
    domain,
    reason,
    created_at,
    created_by
  ) values (
    normalized_domain,
    normalized_reason,
    pg_catalog.clock_timestamp(),
    auth.uid()
  )
  on conflict (domain) do update
  set reason = excluded.reason,
      created_at = excluded.created_at,
      created_by = excluded.created_by;
end;
$function$;

create function public.admin_unblock_post_link_domain(
  target_domain text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  normalized_domain text;
  affected_rows bigint;
begin
  if not public.current_user_is_admin() then
    raise exception 'Admin access required'
      using errcode = '42501';
  end if;

  normalized_domain := public.normalize_post_link_domain(target_domain);

  delete from public.post_link_blocklist as blocked
  where blocked.domain = normalized_domain;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Blocked post-link domain does not exist'
      using errcode = 'P0002';
  end if;
end;
$function$;

-- Deterministic function ownership and ACLs.
alter function public.normalize_post_link_domain(text) owner to postgres;
alter function public.is_valid_post_reaction_code(text) owner to postgres;
alter function public.post_image_array_has_unique_values(text[]) owner to postgres;
alter function public.profile_owner_is_banned(uuid) owner to postgres;
alter function public.current_user_can_read_post_author(uuid) owner to postgres;
alter function public.post_images_belong_to_profile(uuid, text[]) owner to postgres;
alter function public.post_body_passes_link_blocklist(text) owner to postgres;
alter function public.consume_post_write_rate_limit() owner to postgres;
alter function public.admin_block_post_link_domain(text, text) owner to postgres;
alter function public.admin_unblock_post_link_domain(text) owner to postgres;

revoke all privileges on function public.normalize_post_link_domain(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.is_valid_post_reaction_code(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.post_image_array_has_unique_values(text[])
  from public, anon, authenticated, service_role;
revoke all privileges on function public.profile_owner_is_banned(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.current_user_can_read_post_author(uuid)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.post_images_belong_to_profile(uuid, text[])
  from public, anon, authenticated, service_role;
revoke all privileges on function public.post_body_passes_link_blocklist(text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.consume_post_write_rate_limit()
  from public, anon, authenticated, service_role;
revoke all privileges on function public.admin_block_post_link_domain(text, text)
  from public, anon, authenticated, service_role;
revoke all privileges on function public.admin_unblock_post_link_domain(text)
  from public, anon, authenticated, service_role;

grant execute on function public.profile_owner_is_banned(uuid)
  to anon, authenticated;
grant execute on function public.current_user_can_read_post_author(uuid)
  to anon, authenticated;
grant execute on function public.admin_block_post_link_domain(text, text)
  to authenticated;
grant execute on function public.admin_unblock_post_link_domain(text)
  to authenticated;

comment on table public.post_link_blocklist is
  'Admin-managed normalized domains rejected by trusted post create/update operations.';
comment on table public.post_write_rate_limits is
  'Internal rolling ten-minute state for post create/update burst protection.';
comment on function public.consume_post_write_rate_limit() is
  'Internal trigger helper: consumes one of 20 accepted post creates/updates per rolling ten minutes.';

-- Transactional postconditions.
do $postconditions$
declare
  support_function_count bigint;
begin
  if not exists (
    select 1
    from pg_class c
    where c.oid = 'public.follows'::regclass
      and c.relrowsecurity
      and c.relforcerowsecurity
  ) then
    raise exception 'Chunk 11A postcondition failed: follows FORCE RLS missing';
  end if;

  if exists (select 1 from public.follows f where f.created_at is null) then
    raise exception 'Chunk 11A postcondition failed: null follows.created_at remains';
  end if;

  if has_table_privilege('anon', 'public.follows', 'INSERT')
     or has_table_privilege('anon', 'public.follows', 'UPDATE')
     or has_table_privilege('anon', 'public.follows', 'DELETE')
     or has_table_privilege('authenticated', 'public.follows', 'UPDATE')
     or has_table_privilege('service_role', 'public.follows', 'INSERT')
     or has_table_privilege('service_role', 'public.follows', 'UPDATE')
     or has_table_privilege('service_role', 'public.follows', 'DELETE')
     or not has_table_privilege('anon', 'public.follows', 'SELECT')
     or not has_table_privilege('authenticated', 'public.follows', 'SELECT')
     or not has_table_privilege('authenticated', 'public.follows', 'INSERT')
     or not has_table_privilege('authenticated', 'public.follows', 'DELETE')
     or not has_table_privilege('service_role', 'public.follows', 'SELECT') then
    raise exception 'Chunk 11A postcondition failed: follows ACL mismatch';
  end if;

  if not exists (
    select 1 from pg_class c
    where c.oid = 'public.post_link_blocklist'::regclass
      and c.relrowsecurity and c.relforcerowsecurity
  ) or not exists (
    select 1 from pg_class c
    where c.oid = 'public.post_write_rate_limits'::regclass
      and c.relrowsecurity and c.relforcerowsecurity
  ) then
    raise exception 'Chunk 11A postcondition failed: support table RLS mismatch';
  end if;

  if (
    select count(*) from pg_policy p
    where p.polrelid = 'public.post_write_rate_limits'::regclass
  ) <> 0 then
    raise exception 'Chunk 11A postcondition failed: limiter must have no policies';
  end if;

  if (
    select count(*)
    from pg_policies p
    where p.schemaname = 'public'
      and p.tablename = 'post_link_blocklist'
      and p.policyname = 'Active admins read post link blocklist'
      and p.cmd = 'SELECT'
      and p.permissive = 'PERMISSIVE'
      and p.roles = array['authenticated'::name]
      and p.qual = 'current_user_is_admin()'
      and p.with_check is null
  ) <> 1
     or (select count(*) from pg_policies p
         where p.schemaname = 'public'
           and p.tablename = 'post_link_blocklist') <> 1 then
    raise exception 'Chunk 11A postcondition failed: exact blocklist policy mismatch';
  end if;

  select count(*)
    into support_function_count
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
    );

  if support_function_count <> 10 then
    raise exception 'Chunk 11A postcondition failed: function owner/search_path mismatch';
  end if;

  if public.normalize_post_link_domain('HTTPS://WWW.Example.COM/path') <> 'example.com'
     or not public.is_valid_post_reaction_code('love')
     or public.is_valid_post_reaction_code('heart')
     or not public.post_image_array_has_unique_values(array['a', 'b']::text[])
     or public.post_image_array_has_unique_values(array['a', 'a']::text[]) then
    raise exception 'Chunk 11A postcondition failed: pure validator behavior mismatch';
  end if;

  if has_function_privilege('anon', 'public.admin_block_post_link_domain(text,text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.admin_block_post_link_domain(text,text)', 'EXECUTE')
     or has_function_privilege('service_role', 'public.admin_block_post_link_domain(text,text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.consume_post_write_rate_limit()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.consume_post_write_rate_limit()', 'EXECUTE')
     or has_function_privilege('service_role', 'public.consume_post_write_rate_limit()', 'EXECUTE') then
    raise exception 'Chunk 11A postcondition failed: function ACL mismatch';
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
        'public.follows'::regclass,
        'public.post_link_blocklist'::regclass,
        'public.post_write_rate_limits'::regclass
      )
        and acl.grantee <> c.relowner
    ),
    expected(object_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('follows', 'audit_readonly', 'SELECT', false, 'postgres'),
        ('follows', 'anon', 'SELECT', false, 'postgres'),
        ('follows', 'authenticated', 'SELECT', false, 'postgres'),
        ('follows', 'authenticated', 'INSERT', false, 'postgres'),
        ('follows', 'authenticated', 'DELETE', false, 'postgres'),
        ('follows', 'service_role', 'SELECT', false, 'postgres'),
        ('post_link_blocklist', 'authenticated', 'SELECT', false, 'postgres'),
        ('post_link_blocklist', 'service_role', 'SELECT', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11A postcondition failed: direct table ACL set mismatch';
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
        and acl.grantee <> p.proowner
    ),
    expected(function_name, grantee_name, privilege_type, is_grantable, grantor_name) as (
      values
        ('profile_owner_is_banned', 'anon', 'EXECUTE', false, 'postgres'),
        ('profile_owner_is_banned', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_author', 'anon', 'EXECUTE', false, 'postgres'),
        ('current_user_can_read_post_author', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('admin_block_post_link_domain', 'authenticated', 'EXECUTE', false, 'postgres'),
        ('admin_unblock_post_link_domain', 'authenticated', 'EXECUTE', false, 'postgres')
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Chunk 11A postcondition failed: direct function ACL set mismatch';
  end if;
end;
$postconditions$;

commit;
