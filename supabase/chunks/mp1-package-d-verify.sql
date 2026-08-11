-- psy.market MP-1 Package D: database-enforced public-profile privacy
-- VERIFY — READ ONLY; OWNER-RUN IN SUPABASE SQL EDITOR.
--
-- Uses transaction-local role/JWT simulation only. It performs no DDL or DML.
-- The final result is one GO/STOP row and never returns profile/user identifiers.
-- Every caught allow/deny failure records its SQLSTATE in findings.
--
-- Proves:
-- * anon and authenticated can read all 12 public columns and the same complete
--   profile row set as the unchanged USING (true) profile SELECT policy;
-- * user_id, is_suspended, updated_at, and select * fail with SQLSTATE 42501;
-- * every current application embed family returns safe profile data under its
--   applicable role (listings, vendor_events, notice_posts, posts, and both
--   conversation profile relationships). These checks exercise the exact profile
--   projection columns plus reviewed FKs at the database role/RLS layer; SQL Editor
--   does not invoke PostgREST HTTP serialization itself;
-- * Package B owner/ownership/admin helpers still execute through their reviewed
--   SECURITY DEFINER boundary after direct private-column access is removed;
-- * service_role and postgres retain full 15-column access;
-- * exact table/column ACLs, row policy, helpers and FK bindings match Package D.

begin transaction read only;
set local row_security = on;

-- Owner-only fixture discovery and non-output fingerprints.
do $owner_setup$
declare
  profile_count bigint;
  profile_md5 text;
  full_profile_md5 text;
  ordinary_user_id uuid;
  ordinary_profile_id uuid;
  unrelated_profile_id uuid;
  admin_user_id uuid;
  admin_profile_id uuid;
  conversation_user_id uuid;
  conversation_id uuid;
begin
  if current_user <> 'postgres'
     or session_user <> 'postgres' then
    raise exception 'Package D verify requires project-owner SQL Editor context';
  end if;

  select count(*), pg_catalog.md5(coalesce(pg_catalog.string_agg(
    pg_catalog.to_jsonb(x)::text, E'\n' order by x.id
  ), ''))
  into profile_count, profile_md5
  from (
    select p.id, p.type, p.handle, p.display_name, p.bio, p.avatar_url,
      p.header_url, p.location, p.social_links, p.is_creator,
      p.is_verified, p.created_at
    from public.profiles p
  ) x;

  select pg_catalog.md5(coalesce(pg_catalog.string_agg(
    pg_catalog.to_jsonb(x)::text, E'\n' order by x.id
  ), ''))
  into full_profile_md5
  from (
    select p.id, p.user_id, p.type, p.handle, p.display_name, p.bio,
      p.avatar_url, p.header_url, p.location, p.social_links, p.is_creator,
      p.is_verified, p.is_suspended, p.created_at, p.updated_at
    from public.profiles p
  ) x;

  select p.user_id, p.id
  into ordinary_user_id, ordinary_profile_id
  from public.profiles p
  join public.users u on u.id = p.user_id
  where u.banned_at is null
    and u.role::text not in ('admin', 'super_admin')
  order by p.created_at, p.id
  limit 1;

  select p.id into unrelated_profile_id
  from public.profiles p
  where ordinary_user_id is not null and p.user_id <> ordinary_user_id
  order by p.created_at, p.id
  limit 1;

  select u.id, p.id
  into admin_user_id, admin_profile_id
  from public.users u
  join public.profiles p on p.user_id = u.id
  where u.banned_at is null
    and u.role::text in ('admin', 'super_admin')
  order by case when u.role::text = 'super_admin' then 0 else 1 end,
    p.created_at, p.id
  limit 1;

  select p.user_id,c.id
  into conversation_user_id,conversation_id
  from public.conversations c
  join public.profiles p
    on p.id in (c.buyer_profile_id,c.seller_profile_id)
  join public.users u on u.id=p.user_id
  where u.banned_at is null
    and not exists (
      select 1
      from public.conversation_participant_state s
      join public.profiles hidden_profile on hidden_profile.id=s.profile_id
      where s.conversation_id=c.id
        and hidden_profile.user_id=p.user_id
        and s.hidden_at is not null
    )
  order by c.created_at,c.id,p.id
  limit 1;

  perform pg_catalog.set_config(
    'mp1.package_d.profile_count', profile_count::text, true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.profile_md5', profile_md5, true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.full_profile_md5', full_profile_md5, true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.ordinary_user_id',
    coalesce(ordinary_user_id::text, ''), true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.ordinary_profile_id',
    coalesce(ordinary_profile_id::text, ''), true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.unrelated_profile_id',
    coalesce(unrelated_profile_id::text, ''), true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.admin_user_id', coalesce(admin_user_id::text, ''), true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.admin_profile_id',
    coalesce(admin_profile_id::text, ''), true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.conversation_user_id',
    coalesce(conversation_user_id::text, ''), true
  );
  perform pg_catalog.set_config(
    'mp1.package_d.conversation_id',
    coalesce(conversation_id::text, ''), true
  );
end;
$owner_setup$;

-- A real anonymous request has no authenticated subject.
do $anon_context$
begin
  perform pg_catalog.set_config('request.jwt.claim.sub','',true);
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object('role','anon','aud','anon')::text,
    true
  );
end;
$anon_context$;

set local role anon;

do $anon_checks$
declare
  safe_count bigint := 0;
  safe_md5 text;
  state_code text;
  row_count_value bigint := 0;
  embed_md5 text;
begin
  begin
    select count(*), pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.to_jsonb(x)::text, E'\n' order by x.id
    ), ''))
    into safe_count, safe_md5
    from (
      select p.id, p.type, p.handle, p.display_name, p.bio, p.avatar_url,
        p.header_url, p.location, p.social_links, p.is_creator,
        p.is_verified, p.created_at
      from public.profiles p
    ) x;
    state_code := '00000';
  exception when others then
    get stacked diagnostics state_code = returned_sqlstate;
  end;
  perform pg_catalog.set_config('mp1.package_d.anon_safe_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.anon_safe_count',safe_count::text,true);
  perform pg_catalog.set_config('mp1.package_d.anon_safe_md5',coalesce(safe_md5,''),true);

  begin perform p.user_id from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.anon_user_id_state',state_code,true);

  begin perform p.is_suspended from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.anon_suspended_state',state_code,true);

  begin perform p.updated_at from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.anon_updated_state',state_code,true);

  begin perform * from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.anon_wildcard_state',state_code,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(p.handle,p.display_name,p.avatar_url)::text,
      E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.listings x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.anon_listings_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.anon_listings_count',row_count_value::text,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(
        p.id,p.type,p.handle,p.display_name,p.bio,p.avatar_url,p.header_url,
        p.location,p.social_links,p.is_creator,p.is_verified,p.created_at
      )::text,E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.vendor_events x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.anon_rsvp_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.anon_rsvp_count',row_count_value::text,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(p.handle,p.display_name,p.avatar_url)::text,
      E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.notice_posts x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.anon_notice_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.anon_notice_count',row_count_value::text,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(
        p.id,p.handle,p.display_name,p.avatar_url
      )::text,E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.posts x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.anon_posts_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.anon_posts_count',row_count_value::text,true);
end;
$anon_checks$;

reset role;

-- Existing ordinary authenticated caller for direct reads and private helpers.
do $ordinary_context$
declare ordinary_user_id text := nullif(pg_catalog.current_setting(
  'mp1.package_d.ordinary_user_id', true
), '');
begin
  perform pg_catalog.set_config(
    'request.jwt.claim.sub', coalesce(ordinary_user_id, ''), true
  );
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', coalesce(ordinary_user_id, ''),
      'role', 'authenticated',
      'aud', 'authenticated'
    )::text,
    true
  );
end;
$ordinary_context$;

set local role authenticated;

do $authenticated_checks$
declare
  safe_count bigint := 0;
  safe_md5 text;
  state_code text;
  row_count_value bigint := 0;
  embed_md5 text;
  owned_profile_id uuid;
  unrelated_profile_id uuid;
  owns_expected boolean := false;
  owns_unrelated boolean := true;
  helper_profile_count bigint := 0;
begin
  begin
    select count(*), pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.to_jsonb(x)::text, E'\n' order by x.id
    ), ''))
    into safe_count, safe_md5
    from (
      select p.id, p.type, p.handle, p.display_name, p.bio, p.avatar_url,
        p.header_url, p.location, p.social_links, p.is_creator,
        p.is_verified, p.created_at
      from public.profiles p
    ) x;
    state_code := '00000';
  exception when others then
    get stacked diagnostics state_code = returned_sqlstate;
  end;
  perform pg_catalog.set_config('mp1.package_d.auth_safe_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_safe_count',safe_count::text,true);
  perform pg_catalog.set_config('mp1.package_d.auth_safe_md5',coalesce(safe_md5,''),true);

  begin perform p.user_id from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.auth_user_id_state',state_code,true);

  begin perform p.is_suspended from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.auth_suspended_state',state_code,true);

  begin perform p.updated_at from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.auth_updated_state',state_code,true);

  begin perform * from public.profiles p limit 1; state_code:='NO_ERROR';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; end;
  perform pg_catalog.set_config('mp1.package_d.auth_wildcard_state',state_code,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(p.handle,p.display_name,p.avatar_url)::text,
      E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.listings x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.auth_listings_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_listings_count',row_count_value::text,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(
        p.id,p.type,p.handle,p.display_name,p.bio,p.avatar_url,p.header_url,
        p.location,p.social_links,p.is_creator,p.is_verified,p.created_at
      )::text,E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.vendor_events x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.auth_rsvp_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_rsvp_count',row_count_value::text,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(p.handle,p.display_name,p.avatar_url)::text,
      E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.notice_posts x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.auth_notice_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_notice_count',row_count_value::text,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(
        p.id,p.handle,p.display_name,p.avatar_url
      )::text,E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.posts x join public.profiles p on p.id=x.profile_id;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.auth_posts_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_posts_count',row_count_value::text,true);

  begin
    select count(*) into helper_profile_count from public.get_my_profiles();
    owned_profile_id := nullif(pg_catalog.current_setting(
      'mp1.package_d.ordinary_profile_id', true
    ), '')::uuid;
    unrelated_profile_id := nullif(pg_catalog.current_setting(
      'mp1.package_d.unrelated_profile_id', true
    ), '')::uuid;
    owns_expected := public.current_user_owns_profile(owned_profile_id);
    owns_unrelated := public.current_user_owns_profile(unrelated_profile_id);
    state_code := '00000';
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
  end;
  perform pg_catalog.set_config('mp1.package_d.auth_owner_helpers_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_owner_helper_count',helper_profile_count::text,true);
  perform pg_catalog.set_config('mp1.package_d.auth_owns_expected',owns_expected::text,true);
  perform pg_catalog.set_config('mp1.package_d.auth_owns_unrelated',owns_unrelated::text,true);

  begin
    perform * from public.admin_get_profile_account(
      nullif(pg_catalog.current_setting(
        'mp1.package_d.ordinary_profile_id', true
      ), '')::uuid
    );
    state_code := 'NO_ERROR';
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
  end;
  perform pg_catalog.set_config('mp1.package_d.auth_admin_denied_state',state_code,true);
end;
$authenticated_checks$;

reset role;

-- Exercise both conversations -> profiles embeds as an existing participant;
-- this fixture is independent of the ordinary helper caller fixture.
do $conversation_context$
declare conversation_user_id text := nullif(pg_catalog.current_setting(
  'mp1.package_d.conversation_user_id', true
), '');
begin
  perform pg_catalog.set_config(
    'request.jwt.claim.sub', coalesce(conversation_user_id, ''), true
  );
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', coalesce(conversation_user_id, ''),
      'role', 'authenticated',
      'aud', 'authenticated'
    )::text,
    true
  );
end;
$conversation_context$;

set local role authenticated;
do $conversation_embed_checks$
declare
  state_code text;
  row_count_value bigint := 0;
  embed_md5 text;
begin
  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(
        p.id,p.handle,p.display_name,p.avatar_url
      )::text,E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.conversations x
    join public.profiles p on p.id=x.buyer_profile_id
    where x.id=nullif(pg_catalog.current_setting(
      'mp1.package_d.conversation_id',true
    ),'')::uuid;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.auth_buyer_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_buyer_count',row_count_value::text,true);

  begin
    select count(*),pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.jsonb_build_array(
        p.id,p.handle,p.display_name,p.avatar_url
      )::text,E'\n' order by x.id
    ),'')) into row_count_value,embed_md5
    from public.conversations x
    join public.profiles p on p.id=x.seller_profile_id
    where x.id=nullif(pg_catalog.current_setting(
      'mp1.package_d.conversation_id',true
    ),'')::uuid;
    state_code:='00000';
  exception when others then get stacked diagnostics state_code=returned_sqlstate; row_count_value:=0; end;
  perform pg_catalog.set_config('mp1.package_d.auth_seller_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.auth_seller_count',row_count_value::text,true);
end;
$conversation_embed_checks$;
reset role;

-- Switch only transaction-local JWT claims to the existing active admin fixture.
do $admin_context$
declare admin_user_id text := nullif(pg_catalog.current_setting(
  'mp1.package_d.admin_user_id', true
), '');
begin
  perform pg_catalog.set_config(
    'request.jwt.claim.sub', coalesce(admin_user_id, ''), true
  );
  perform pg_catalog.set_config(
    'request.jwt.claims',
    pg_catalog.jsonb_build_object(
      'sub', coalesce(admin_user_id, ''),
      'role', 'authenticated',
      'aud', 'authenticated'
    )::text,
    true
  );
end;
$admin_context$;

set local role authenticated;

do $admin_helper_check$
declare
  state_code text;
  result_count bigint := 0;
begin
  begin
    select count(*) into result_count
    from public.admin_get_profile_account(
      nullif(pg_catalog.current_setting(
        'mp1.package_d.ordinary_profile_id', true
      ), '')::uuid
    ) r
    where r.account_user_id is not null and r.profile_id is not null;
    state_code := '00000';
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
  end;
  perform pg_catalog.set_config('mp1.package_d.admin_helper_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.admin_helper_count',result_count::text,true);
end;
$admin_helper_check$;

reset role;
set local role service_role;

do $service_role_check$
declare
  row_count_value bigint := 0;
  row_md5 text;
  state_code text;
begin
  begin
    select count(*), pg_catalog.md5(coalesce(pg_catalog.string_agg(
      pg_catalog.to_jsonb(x)::text, E'\n' order by x.id
    ), ''))
    into row_count_value, row_md5
    from (
      select p.id, p.user_id, p.type, p.handle, p.display_name, p.bio,
        p.avatar_url, p.header_url, p.location, p.social_links, p.is_creator,
        p.is_verified, p.is_suspended, p.created_at, p.updated_at
      from public.profiles p
    ) x;
    state_code := '00000';
  exception when others then
    get stacked diagnostics state_code=returned_sqlstate;
  end;
  perform pg_catalog.set_config('mp1.package_d.service_state',state_code,true);
  perform pg_catalog.set_config('mp1.package_d.service_count',row_count_value::text,true);
  perform pg_catalog.set_config('mp1.package_d.service_md5',coalesce(row_md5,''),true);
end;
$service_role_check$;

reset role;

with
expected_profile_columns(ordinal_position,column_name,data_type,is_not_null) as (
  values
    (1,'id'::text,'uuid'::text,true),
    (2,'user_id','uuid',true),
    (3,'type','profile_type',true),
    (4,'handle','text',true),
    (5,'display_name','text',true),
    (6,'bio','text',false),
    (7,'avatar_url','text',false),
    (8,'header_url','text',false),
    (9,'location','text',false),
    (10,'social_links','jsonb',false),
    (11,'is_creator','boolean',true),
    (12,'is_verified','boolean',true),
    (13,'is_suspended','boolean',true),
    (14,'created_at','timestamp with time zone',true),
    (15,'updated_at','timestamp with time zone',true)
),
actual_profile_columns as (
  select a.attnum::integer,a.attname::text,
    pg_catalog.format_type(a.atttypid,a.atttypmod)::text,a.attnotnull
  from pg_catalog.pg_attribute a
  where a.attrelid=pg_catalog.to_regclass('public.profiles')
    and a.attnum>0 and not a.attisdropped
),
available_privileges(privilege_type) as (
  values ('DELETE'::text), ('INSERT'), ('REFERENCES'), ('SELECT'),
    ('TRIGGER'), ('TRUNCATE'), ('UPDATE')
  union all
  select 'MAINTAIN'
  where pg_catalog.current_setting('server_version_num')::integer >= 170000
),
expected_table(grantor, grantee, privilege_type, is_grantable) as (
  select 'postgres'::text, r.grantee, p.privilege_type, false
  from (values ('postgres'::text), ('anon'), ('authenticated'),
               ('service_role')) r(grantee)
  cross join available_privileges p
  where not (
    r.grantee in ('anon', 'authenticated') and p.privilege_type='SELECT'
  )
  union all select 'postgres', 'audit_readonly', 'SELECT', false
),
expected_columns(column_name, grantor, grantee, privilege_type, is_grantable) as (
  select c.column_name, 'postgres'::text, r.grantee, 'SELECT'::text, false
  from (values
    ('id'::text), ('type'), ('handle'), ('display_name'), ('bio'),
    ('avatar_url'), ('header_url'), ('location'), ('social_links'),
    ('is_creator'), ('is_verified'), ('created_at')
  ) c(column_name)
  cross join (values ('anon'::text), ('authenticated')) r(grantee)
),
actual_table as (
  select acl.grantor::regrole::text,
    case when acl.grantee=0 then 'PUBLIC'
         else acl.grantee::regrole::text end,
    acl.privilege_type::text, acl.is_grantable
  from pg_catalog.pg_class c
  cross join lateral pg_catalog.aclexplode(
    coalesce(c.relacl, pg_catalog.acldefault('r', c.relowner))
  ) acl
  where c.oid=pg_catalog.to_regclass('public.profiles')
),
actual_columns as (
  select a.attname::text, acl.grantor::regrole::text,
    case when acl.grantee=0 then 'PUBLIC'
         else acl.grantee::regrole::text end,
    acl.privilege_type::text, acl.is_grantable
  from pg_catalog.pg_attribute a
  cross join lateral pg_catalog.aclexplode(a.attacl) acl
  where a.attrelid=pg_catalog.to_regclass('public.profiles')
    and a.attnum>0 and not a.attisdropped and a.attacl is not null
),
expected_helper_acl(function_name, grantee, privilege_type, is_grantable, grantor) as (
  values
    ('get_my_profiles'::text,'postgres'::text,'EXECUTE'::text,false,'postgres'::text),
    ('get_my_profiles','authenticated','EXECUTE',false,'postgres'),
    ('current_user_owns_profile','postgres','EXECUTE',false,'postgres'),
    ('current_user_owns_profile','authenticated','EXECUTE',false,'postgres'),
    ('admin_get_profile_account','postgres','EXECUTE',false,'postgres'),
    ('admin_get_profile_account','authenticated','EXECUTE',false,'postgres')
),
actual_helper_acl as (
  select p.proname::text,
    case when acl.grantee=0 then 'PUBLIC' else acl.grantee::regrole::text end,
    acl.privilege_type::text, acl.is_grantable, acl.grantor::regrole::text
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  cross join lateral pg_catalog.aclexplode(
    coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))
  ) acl
  where n.nspname='public' and p.proname in (
    'get_my_profiles','current_user_owns_profile','admin_get_profile_account'
  )
),
helper_catalog as (
  select count(*)=3 and pg_catalog.bool_and(
    p.proowner='postgres'::regrole and p.prosecdef
    and p.provolatile='s' and p.proparallel='u' and p.prokind='f'
    and not p.proisstrict and not p.proleakproof
    and p.proconfig in (array['search_path=""'],array['search_path='])
    and pg_catalog.md5(pg_catalog.btrim(pg_catalog.regexp_replace(
      p.prosrc,E'\\s+',' ','g'
    ))) = case p.proname
      when 'get_my_profiles' then '068d419cf900e4bde1bd36b73433c2b3'
      when 'current_user_owns_profile' then 'b18b8e4f01df72097d092352423ab8af'
      when 'admin_get_profile_account' then '1b1617031aa49512a692d706462e4f18'
    end
  ) as ok
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in (
    'get_my_profiles','current_user_owns_profile','admin_get_profile_account'
  )
),
expected_embed_fks(
  table_name,constraint_name,local_columns,referenced_columns,
  validated,delete_action,update_action,match_type,is_deferrable,is_initially_deferred
) as (
  values
    ('listings'::text,'listings_profile_id_fkey'::text,'profile_id'::text,
      'id'::text,true,'c'::text,'a'::text,'s'::text,false,false),
    ('vendor_events','vendor_events_profile_id_fkey','profile_id',
      'id',true,'c','a','s',false,false),
    ('notice_posts','notice_posts_profile_id_fkey','profile_id',
      'id',true,'c','a','s',false,false),
    ('posts','posts_profile_id_fkey','profile_id',
      'id',true,'c','a','s',false,false),
    ('conversations','conversations_buyer_profile_id_fkey','buyer_profile_id',
      'id',true,'c','a','s',false,false),
    ('conversations','conversations_seller_profile_id_fkey','seller_profile_id',
      'id',true,'c','a','s',false,false)
),
actual_embed_fks as (
  select child.relname::text,con.conname::text,
    (
      select pg_catalog.string_agg(a.attname,',' order by k.ord)
      from pg_catalog.unnest(con.conkey) with ordinality k(attnum,ord)
      join pg_catalog.pg_attribute a
        on a.attrelid=con.conrelid and a.attnum=k.attnum
    ),
    (
      select pg_catalog.string_agg(a.attname,',' order by k.ord)
      from pg_catalog.unnest(con.confkey) with ordinality k(attnum,ord)
      join pg_catalog.pg_attribute a
        on a.attrelid=con.confrelid and a.attnum=k.attnum
    ),
    con.convalidated,con.confdeltype::text,con.confupdtype::text,
    con.confmatchtype::text,con.condeferrable,con.condeferred
  from pg_catalog.pg_constraint con
  join pg_catalog.pg_class child on child.oid=con.conrelid
  join pg_catalog.pg_namespace child_ns on child_ns.oid=child.relnamespace
  where con.contype='f'
    and con.confrelid=pg_catalog.to_regclass('public.profiles')
    and child_ns.nspname='public'
    and child.relname in (
      'listings','vendor_events','notice_posts','posts','conversations'
    )
),
checks(check_name,ok,finding) as (
  values
    ('profiles_relation_and_columns_exact',
      exists (
        select 1 from pg_catalog.pg_class c
        where c.oid=pg_catalog.to_regclass('public.profiles')
          and c.relkind='r' and c.relowner='postgres'::regrole
          and c.relrowsecurity and not c.relforcerowsecurity
      ) and not exists (
        (select * from actual_profile_columns except select * from expected_profile_columns)
        union all
        (select * from expected_profile_columns except select * from actual_profile_columns)
      ),'profiles relation/column/RLS drift'),
    ('api_roles_and_inheritance_exact',
      exists (select 1 from pg_catalog.pg_roles where rolname='anon'
        and rolinherit and not rolsuper and not rolbypassrls)
      and exists (select 1 from pg_catalog.pg_roles where rolname='authenticated'
        and rolinherit and not rolsuper and not rolbypassrls)
      and exists (select 1 from pg_catalog.pg_roles where rolname='service_role'
        and rolinherit and not rolsuper and rolbypassrls)
      and exists (select 1 from pg_catalog.pg_roles where rolname='postgres'
        and rolbypassrls)
      and not exists (
        select 1 from pg_catalog.pg_auth_members m
        where m.member in ('anon'::regrole,'authenticated'::regrole)
      )
      and (
        exists (
          select 1 from pg_catalog.pg_roles
          where rolname='postgres' and rolsuper
        )
        or not exists (
          select 1
          from (values ('anon'::text),('authenticated'),('service_role'))
            target(role_name)
          where not exists (
            select 1
            from pg_catalog.pg_auth_members m
            join pg_catalog.pg_roles granted_role on granted_role.oid=m.roleid
            join pg_catalog.pg_roles member_role on member_role.oid=m.member
            where granted_role.rolname=target.role_name
              and member_role.rolname='postgres'
              and m.set_option
          )
        )
      ),'API/trusted role, inheritance, or SET authorization drift'),
    ('exact_post_acl',
      not exists (
        (select * from actual_table except select * from expected_table)
        union all (select * from expected_table except select * from actual_table)
      ) and not exists (
        (select * from actual_columns except select * from expected_columns)
        union all (select * from expected_columns except select * from actual_columns)
      ), 'catalog ACL mismatch'),
    ('profile_row_policy_unchanged', (
      select count(*)=1 and pg_catalog.bool_and(
        policyname='Profiles are publicly readable'
        and cmd='SELECT'
        and permissive='PERMISSIVE' and roles=array['public']::name[]
        and qual='true' and with_check is null
      ) from pg_catalog.pg_policies
      where schemaname='public' and tablename='profiles'
        and cmd in ('SELECT','ALL')
    ), 'profile SELECT policy drift'),
    ('private_helpers_catalog_exact',
      (select ok from helper_catalog) and not exists (
        (select * from actual_helper_acl except select * from expected_helper_acl)
        union all
        (select * from expected_helper_acl except select * from actual_helper_acl)
      ), 'private helper definition/ACL drift'),
    ('embed_foreign_keys_exact',not exists (
      (select * from actual_embed_fks except select * from expected_embed_fks)
      union all
      (select * from expected_embed_fks except select * from actual_embed_fks)
    ),'embedded profile FK drift'),
    ('profile_fixture',
      pg_catalog.current_setting('mp1.package_d.profile_count')::bigint > 0,
      'profile fixture unavailable'),
    ('ordinary_admin_fixtures',
      nullif(pg_catalog.current_setting('mp1.package_d.ordinary_user_id',true),'') is not null
      and nullif(pg_catalog.current_setting('mp1.package_d.unrelated_profile_id',true),'') is not null
      and nullif(pg_catalog.current_setting('mp1.package_d.admin_user_id',true),'') is not null
      and nullif(pg_catalog.current_setting('mp1.package_d.conversation_user_id',true),'') is not null
      and nullif(pg_catalog.current_setting('mp1.package_d.conversation_id',true),'') is not null,
      'ordinary/unrelated/admin/conversation fixture unavailable'),
    ('anon_safe_columns_and_rows',
      pg_catalog.current_setting('mp1.package_d.anon_safe_state',true)='00000'
      and pg_catalog.current_setting('mp1.package_d.anon_safe_count',true)::bigint=
        pg_catalog.current_setting('mp1.package_d.profile_count')::bigint
      and pg_catalog.current_setting('mp1.package_d.anon_safe_md5',true)=
        pg_catalog.current_setting('mp1.package_d.profile_md5'),
      pg_catalog.format('anon safe SELECT SQLSTATE=%s',
        pg_catalog.current_setting('mp1.package_d.anon_safe_state',true))),
    ('auth_safe_columns_and_rows',
      pg_catalog.current_setting('mp1.package_d.auth_safe_state',true)='00000'
      and pg_catalog.current_setting('mp1.package_d.auth_safe_count',true)::bigint=
        pg_catalog.current_setting('mp1.package_d.profile_count')::bigint
      and pg_catalog.current_setting('mp1.package_d.auth_safe_md5',true)=
        pg_catalog.current_setting('mp1.package_d.profile_md5'),
      pg_catalog.format('authenticated safe SELECT SQLSTATE=%s',
        pg_catalog.current_setting('mp1.package_d.auth_safe_state',true))),
    ('anon_user_id_denied',pg_catalog.current_setting('mp1.package_d.anon_user_id_state',true)='42501',pg_catalog.format('anon user_id SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.anon_user_id_state',true))),
    ('anon_is_suspended_denied',pg_catalog.current_setting('mp1.package_d.anon_suspended_state',true)='42501',pg_catalog.format('anon is_suspended SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.anon_suspended_state',true))),
    ('anon_updated_at_denied',pg_catalog.current_setting('mp1.package_d.anon_updated_state',true)='42501',pg_catalog.format('anon updated_at SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.anon_updated_state',true))),
    ('anon_wildcard_denied',pg_catalog.current_setting('mp1.package_d.anon_wildcard_state',true)='42501',pg_catalog.format('anon select * SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.anon_wildcard_state',true))),
    ('auth_user_id_denied',pg_catalog.current_setting('mp1.package_d.auth_user_id_state',true)='42501',pg_catalog.format('authenticated user_id SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.auth_user_id_state',true))),
    ('auth_is_suspended_denied',pg_catalog.current_setting('mp1.package_d.auth_suspended_state',true)='42501',pg_catalog.format('authenticated is_suspended SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.auth_suspended_state',true))),
    ('auth_updated_at_denied',pg_catalog.current_setting('mp1.package_d.auth_updated_state',true)='42501',pg_catalog.format('authenticated updated_at SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.auth_updated_state',true))),
    ('auth_wildcard_denied',pg_catalog.current_setting('mp1.package_d.auth_wildcard_state',true)='42501',pg_catalog.format('authenticated select * SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.auth_wildcard_state',true))),
    ('anon_listings_embed',pg_catalog.current_setting('mp1.package_d.anon_listings_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.anon_listings_count',true)::bigint>0,pg_catalog.format('anon listings embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.anon_listings_state',true),pg_catalog.current_setting('mp1.package_d.anon_listings_count',true))),
    ('anon_rsvp_embed',pg_catalog.current_setting('mp1.package_d.anon_rsvp_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.anon_rsvp_count',true)::bigint>0,pg_catalog.format('anon RSVP embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.anon_rsvp_state',true),pg_catalog.current_setting('mp1.package_d.anon_rsvp_count',true))),
    ('anon_notice_embed',pg_catalog.current_setting('mp1.package_d.anon_notice_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.anon_notice_count',true)::bigint>0,pg_catalog.format('anon Notice embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.anon_notice_state',true),pg_catalog.current_setting('mp1.package_d.anon_notice_count',true))),
    ('anon_posts_embed',pg_catalog.current_setting('mp1.package_d.anon_posts_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.anon_posts_count',true)::bigint>0,pg_catalog.format('anon posts embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.anon_posts_state',true),pg_catalog.current_setting('mp1.package_d.anon_posts_count',true))),
    ('auth_listings_embed',pg_catalog.current_setting('mp1.package_d.auth_listings_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.auth_listings_count',true)::bigint>0,pg_catalog.format('authenticated listings embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.auth_listings_state',true),pg_catalog.current_setting('mp1.package_d.auth_listings_count',true))),
    ('auth_rsvp_embed',pg_catalog.current_setting('mp1.package_d.auth_rsvp_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.auth_rsvp_count',true)::bigint>0,pg_catalog.format('authenticated RSVP embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.auth_rsvp_state',true),pg_catalog.current_setting('mp1.package_d.auth_rsvp_count',true))),
    ('auth_notice_embed',pg_catalog.current_setting('mp1.package_d.auth_notice_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.auth_notice_count',true)::bigint>0,pg_catalog.format('authenticated Notice embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.auth_notice_state',true),pg_catalog.current_setting('mp1.package_d.auth_notice_count',true))),
    ('auth_posts_embed',pg_catalog.current_setting('mp1.package_d.auth_posts_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.auth_posts_count',true)::bigint>0,pg_catalog.format('authenticated posts embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.auth_posts_state',true),pg_catalog.current_setting('mp1.package_d.auth_posts_count',true))),
    ('auth_buyer_embed',pg_catalog.current_setting('mp1.package_d.auth_buyer_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.auth_buyer_count',true)::bigint>0,pg_catalog.format('authenticated buyer embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.auth_buyer_state',true),pg_catalog.current_setting('mp1.package_d.auth_buyer_count',true))),
    ('auth_seller_embed',pg_catalog.current_setting('mp1.package_d.auth_seller_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.auth_seller_count',true)::bigint>0,pg_catalog.format('authenticated seller embed SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.auth_seller_state',true),pg_catalog.current_setting('mp1.package_d.auth_seller_count',true))),
    ('owner_helpers_work',pg_catalog.current_setting('mp1.package_d.auth_owner_helpers_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.auth_owner_helper_count',true)::bigint>0 and pg_catalog.current_setting('mp1.package_d.auth_owns_expected',true)::boolean and not pg_catalog.current_setting('mp1.package_d.auth_owns_unrelated',true)::boolean,pg_catalog.format('owner helpers SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.auth_owner_helpers_state',true))),
    ('ordinary_admin_helper_denied',pg_catalog.current_setting('mp1.package_d.auth_admin_denied_state',true)='42501',pg_catalog.format('ordinary admin helper SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.auth_admin_denied_state',true))),
    ('admin_helper_works',pg_catalog.current_setting('mp1.package_d.admin_helper_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.admin_helper_count',true)::bigint>0,pg_catalog.format('admin helper SQLSTATE=%s count=%s',pg_catalog.current_setting('mp1.package_d.admin_helper_state',true),pg_catalog.current_setting('mp1.package_d.admin_helper_count',true))),
    ('service_role_full_access',pg_catalog.current_setting('mp1.package_d.service_state',true)='00000' and pg_catalog.current_setting('mp1.package_d.service_count',true)::bigint=pg_catalog.current_setting('mp1.package_d.profile_count')::bigint and pg_catalog.current_setting('mp1.package_d.service_md5',true)=pg_catalog.current_setting('mp1.package_d.full_profile_md5'),pg_catalog.format('service_role full SELECT SQLSTATE=%s',pg_catalog.current_setting('mp1.package_d.service_state',true))),
    ('postgres_full_access',pg_catalog.has_table_privilege('postgres','public.profiles','SELECT') and pg_catalog.has_column_privilege('postgres','public.profiles','user_id','SELECT'),'postgres full SELECT changed')
),
summary as (
  select pg_catalog.bool_and(ok) as all_ok,
    coalesce(pg_catalog.array_agg(
      check_name || ': ' || finding order by check_name
    ) filter(where not ok),array[]::text[]) as findings
  from checks
)
select
  'MP1_PACKAGE_D_PROFILE_PRIVACY_VERIFY'::text as package,
  case when all_ok then 'GO' else 'STOP' end::text as status,
  (select count(*) from checks where ok) as passed_check_count,
  (select count(*) from checks) as total_check_count,
  findings,
  pg_catalog.jsonb_build_object(
    'anon_private_sqlstates',pg_catalog.jsonb_build_object(
      'user_id',pg_catalog.current_setting('mp1.package_d.anon_user_id_state',true),
      'is_suspended',pg_catalog.current_setting('mp1.package_d.anon_suspended_state',true),
      'updated_at',pg_catalog.current_setting('mp1.package_d.anon_updated_state',true),
      'wildcard',pg_catalog.current_setting('mp1.package_d.anon_wildcard_state',true)
    ),
    'authenticated_private_sqlstates',pg_catalog.jsonb_build_object(
      'user_id',pg_catalog.current_setting('mp1.package_d.auth_user_id_state',true),
      'is_suspended',pg_catalog.current_setting('mp1.package_d.auth_suspended_state',true),
      'updated_at',pg_catalog.current_setting('mp1.package_d.auth_updated_state',true),
      'wildcard',pg_catalog.current_setting('mp1.package_d.auth_wildcard_state',true)
    )
  ) as role_sqlstates
from summary;

rollback;
