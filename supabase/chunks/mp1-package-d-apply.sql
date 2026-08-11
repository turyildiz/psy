-- psy.market MP-1 Package D: database-enforced public-profile privacy
-- APPLY — OWNER-RUN ONLY; NOT EXECUTED BY THE REPOSITORY AGENT.
--
-- Changes only SELECT privileges on public.profiles for anon/authenticated.
-- RLS policies, rows, columns, functions, non-SELECT grants, service_role,
-- audit_readonly and postgres access remain unchanged.
--
-- State machine:
-- * exact approved pre-cutover ACL -> apply the narrow column grants;
-- * exact approved post-cutover ACL -> safe no-op rerun;
-- * every other state -> readable refusal with no mutation.
--
-- Dependency summary: repository profile reads and embeds were audited at 282b011;
-- all browser queries use explicit safe projections, trusted user_id reads use
-- service_role, and the three Package B private helpers are exact postgres-owned
-- SECURITY DEFINER contracts. See PREFLIGHT header for the complete inventory and
-- the select=* / profiles(*) residual compatibility caveat.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Exact dependencies and ACL state are checked in the same block immediately
-- before the privilege mutation.
do $apply$
declare
  old_acl_ok boolean;
  new_acl_ok boolean;
  helper_ok boolean;
  helper_acl_ok boolean;
  embed_fks_ok boolean;
begin
  if current_user <> 'postgres'
     or session_user <> 'postgres' then
    raise exception 'Package D apply refused: project-owner SQL Editor context required';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_class c
    where c.oid = pg_catalog.to_regclass('public.profiles')
      and c.relkind = 'r'
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity and not c.relforcerowsecurity
  ) then
    raise exception 'Package D apply refused: profiles relation/RLS drift';
  end if;

  if (
    select pg_catalog.array_agg(
      pg_catalog.format('%s|%s|%s|%s', a.attnum, a.attname,
        pg_catalog.format_type(a.atttypid, a.atttypmod), a.attnotnull)
      order by a.attnum
    )
    from pg_catalog.pg_attribute a
    where a.attrelid = pg_catalog.to_regclass('public.profiles')
      and a.attnum > 0 and not a.attisdropped
  ) is distinct from array[
    '1|id|uuid|t',
    '2|user_id|uuid|t',
    '3|type|profile_type|t',
    '4|handle|text|t',
    '5|display_name|text|t',
    '6|bio|text|f',
    '7|avatar_url|text|f',
    '8|header_url|text|f',
    '9|location|text|f',
    '10|social_links|jsonb|f',
    '11|is_creator|boolean|t',
    '12|is_verified|boolean|t',
    '13|is_suspended|boolean|t',
    '14|created_at|timestamp with time zone|t',
    '15|updated_at|timestamp with time zone|t'
  ]::text[] then
    raise exception 'Package D apply refused: profiles column contract drift';
  end if;

  if not (
    select count(*) = 1 and pg_catalog.bool_and(
      p.policyname = 'Profiles are publicly readable'
      and p.cmd = 'SELECT'
      and p.permissive = 'PERMISSIVE'
      and p.roles = array['public']::name[]
      and p.qual = 'true'
      and p.with_check is null
    )
    from pg_catalog.pg_policies p
    where p.schemaname = 'public' and p.tablename = 'profiles'
      and p.cmd in ('SELECT', 'ALL')
  ) then
    raise exception 'Package D apply refused: profile row-visibility policy drift';
  end if;

  if not exists (select 1 from pg_catalog.pg_roles where rolname='anon'
      and rolinherit and not rolsuper and not rolbypassrls)
     or not exists (select 1 from pg_catalog.pg_roles where rolname='authenticated'
      and rolinherit and not rolsuper and not rolbypassrls)
     or not exists (select 1 from pg_catalog.pg_roles where rolname='service_role'
      and rolinherit and not rolsuper and rolbypassrls)
     or not exists (select 1 from pg_catalog.pg_roles where rolname='postgres'
      and rolbypassrls)
     or exists (
       select 1 from pg_catalog.pg_auth_members m
       where m.member in ('anon'::regrole, 'authenticated'::regrole)
     )
     or (
       not exists (
         select 1 from pg_catalog.pg_roles
         where rolname='postgres' and rolsuper
       )
       and exists (
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
     ) then
    raise exception 'Package D apply refused: API/trusted role or inheritance drift';
  end if;

  select
    count(*) = 3
    and pg_catalog.bool_and(
      p.proowner = 'postgres'::regrole
      and p.provolatile = 's'
      and p.proparallel = 'u'
      and p.prokind = 'f'
      and p.prosecdef
      and not p.proisstrict
      and not p.proleakproof
      and p.proconfig in (array['search_path=""'], array['search_path='])
      and case p.proname
        when 'get_my_profiles' then
          l.lanname = 'sql'
          and p.proretset
          and p.proargtypes = ''::oidvector
          and p.proargmodes = array[
            't'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char"
          ]
          and p.proargnames = array[
            'id', 'type', 'handle', 'display_name', 'bio', 'avatar_url',
            'header_url', 'location', 'social_links', 'is_creator',
            'is_verified', 'created_at', 'is_suspended', 'updated_at'
          ]
          and p.proallargtypes = array[
            'uuid'::regtype::oid, 'public.profile_type'::regtype::oid,
            'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
            'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
            'jsonb'::regtype::oid, 'boolean'::regtype::oid,
            'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid,
            'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid
          ]
          and pg_catalog.md5(pg_catalog.btrim(pg_catalog.regexp_replace(
            p.prosrc, E'\\s+', ' ', 'g'
          ))) = '068d419cf900e4bde1bd36b73433c2b3'
        when 'current_user_owns_profile' then
          l.lanname = 'sql'
          and not p.proretset
          and p.prorettype = 'boolean'::regtype
          and pg_catalog.pg_get_function_identity_arguments(p.oid) =
            'target_profile_id uuid'
          and p.proargnames = array['target_profile_id']
          and pg_catalog.md5(pg_catalog.btrim(pg_catalog.regexp_replace(
            p.prosrc, E'\\s+', ' ', 'g'
          ))) = 'b18b8e4f01df72097d092352423ab8af'
        when 'admin_get_profile_account' then
          l.lanname = 'plpgsql'
          and p.proretset
          and p.proargmodes = array[
            'i'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char", 't'::"char", 't'::"char"
          ]
          and p.proargnames = array[
            'target_profile_id', 'account_user_id', 'profile_id', 'handle',
            'display_name', 'type', 'is_suspended', 'created_at'
          ]
          and p.proallargtypes = array[
            'uuid'::regtype::oid, 'uuid'::regtype::oid, 'uuid'::regtype::oid,
            'text'::regtype::oid, 'text'::regtype::oid,
            'public.profile_type'::regtype::oid, 'boolean'::regtype::oid,
            'timestamp with time zone'::regtype::oid
          ]
          and pg_catalog.md5(pg_catalog.btrim(pg_catalog.regexp_replace(
            p.prosrc, E'\\s+', ' ', 'g'
          ))) = '1b1617031aa49512a692d706462e4f18'
        else false
      end
    )
  into helper_ok
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  join pg_catalog.pg_language l on l.oid = p.prolang
  where n.nspname = 'public'
    and p.proname in (
      'get_my_profiles',
      'current_user_owns_profile',
      'admin_get_profile_account'
    );

  with expected(function_name, grantee, privilege_type, is_grantable, grantor) as (
    values
      ('get_my_profiles'::text, 'postgres'::text, 'EXECUTE'::text, false, 'postgres'::text),
      ('get_my_profiles', 'authenticated', 'EXECUTE', false, 'postgres'),
      ('current_user_owns_profile', 'postgres', 'EXECUTE', false, 'postgres'),
      ('current_user_owns_profile', 'authenticated', 'EXECUTE', false, 'postgres'),
      ('admin_get_profile_account', 'postgres', 'EXECUTE', false, 'postgres'),
      ('admin_get_profile_account', 'authenticated', 'EXECUTE', false, 'postgres')
  ), actual as (
    select p.proname::text,
      case when acl.grantee = 0 then 'PUBLIC'
           else acl.grantee::regrole::text end,
      acl.privilege_type::text, acl.is_grantable,
      acl.grantor::regrole::text
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join lateral pg_catalog.aclexplode(
      coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
    ) acl
    where n.nspname = 'public'
      and p.proname in (
        'get_my_profiles',
        'current_user_owns_profile',
        'admin_get_profile_account'
      )
  )
  select not exists (
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) into helper_acl_ok;

  if not helper_ok or not helper_acl_ok or exists (
    select 1 from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'get_my_profiles',
        'current_user_owns_profile',
        'admin_get_profile_account'
      )
      and (
        not pg_catalog.has_function_privilege(
          'authenticated', p.oid, 'EXECUTE'
        )
        or pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
        or pg_catalog.has_function_privilege('service_role', p.oid, 'EXECUTE')
      )
  ) then
    raise exception 'Package D apply refused: private helper definition/ACL drift';
  end if;

  with expected(
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
  ), actual as (
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
  )
  select not exists (
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) into embed_fks_ok;

  if not embed_fks_ok then
    raise exception 'Package D apply refused: embedded profile FK drift';
  end if;

  if not (
    exists (
      select 1 from public.profiles p
      join public.users u on u.id=p.user_id
      where u.banned_at is null
        and u.role::text not in ('admin','super_admin')
    )
    and exists (
      select 1 from public.profiles a
      join public.profiles b on b.user_id<>a.user_id
    )
    and exists (
      select 1 from public.profiles p
      join public.users u on u.id=p.user_id
      where u.banned_at is null
        and u.role::text in ('admin','super_admin')
    )
    and exists (
      select 1 from public.listings x
      join public.profiles p on p.id=x.profile_id
      where x.status::text in ('active','sold')
    )
    and exists (
      select 1 from public.vendor_events x
      join public.profiles p on p.id=x.profile_id
    )
    and exists (
      select 1 from public.notice_posts x
      join public.profiles p on p.id=x.profile_id
    )
    and exists (
      select 1 from public.posts x
      join public.profiles p on p.id=x.profile_id
      join public.users u on u.id=p.user_id
      where x.show_in_stream and u.banned_at is null
    )
    and exists (
      select 1
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
    )
  ) then
    raise exception 'Package D apply refused: required role/embed verification fixture unavailable';
  end if;

  with available_privileges(privilege_type) as (
    values ('DELETE'::text), ('INSERT'), ('REFERENCES'), ('SELECT'),
      ('TRIGGER'), ('TRUNCATE'), ('UPDATE')
    union all
    select 'MAINTAIN'
    where pg_catalog.current_setting('server_version_num')::integer >= 170000
  ), old_table(grantor, grantee, privilege_type, is_grantable) as (
    select 'postgres'::text, r.grantee, p.privilege_type, false
    from (values ('postgres'::text), ('anon'), ('authenticated'),
                 ('service_role')) r(grantee)
    cross join available_privileges p
    union all select 'postgres', 'audit_readonly', 'SELECT', false
  ), new_table as (
    select * from old_table
    where not (
      grantee in ('anon', 'authenticated') and privilege_type = 'SELECT'
    )
  ), new_columns(column_name, grantor, grantee, privilege_type, is_grantable) as (
    select c.column_name, 'postgres'::text, r.grantee, 'SELECT'::text, false
    from (values
      ('id'::text), ('type'), ('handle'), ('display_name'), ('bio'),
      ('avatar_url'), ('header_url'), ('location'), ('social_links'),
      ('is_creator'), ('is_verified'), ('created_at')
    ) c(column_name)
    cross join (values ('anon'::text), ('authenticated')) r(grantee)
  ), actual_table as (
    select acl.grantor::regrole::text,
      case when acl.grantee=0 then 'PUBLIC'
           else acl.grantee::regrole::text end,
      acl.privilege_type::text, acl.is_grantable
    from pg_catalog.pg_class c
    cross join lateral pg_catalog.aclexplode(
      coalesce(c.relacl, pg_catalog.acldefault('r', c.relowner))
    ) acl
    where c.oid = pg_catalog.to_regclass('public.profiles')
  ), actual_columns as (
    select a.attname::text, acl.grantor::regrole::text,
      case when acl.grantee=0 then 'PUBLIC'
           else acl.grantee::regrole::text end,
      acl.privilege_type::text, acl.is_grantable
    from pg_catalog.pg_attribute a
    cross join lateral pg_catalog.aclexplode(a.attacl) acl
    where a.attrelid = pg_catalog.to_regclass('public.profiles')
      and a.attnum>0 and not a.attisdropped and a.attacl is not null
  )
  select
    not exists (
      (select * from actual_table except select * from old_table)
      union all
      (select * from old_table except select * from actual_table)
    ) and not exists (select 1 from actual_columns),
    not exists (
      (select * from actual_table except select * from new_table)
      union all
      (select * from new_table except select * from actual_table)
    ) and not exists (
      (select * from actual_columns except select * from new_columns)
      union all
      (select * from new_columns except select * from actual_columns)
    )
  into old_acl_ok, new_acl_ok;

  if old_acl_ok then
    execute 'revoke select on table public.profiles from anon, authenticated';
    execute 'grant select (
      id, type, handle, display_name, bio, avatar_url, header_url, location,
      social_links, is_creator, is_verified, created_at
    ) on table public.profiles to anon, authenticated';
  elsif new_acl_ok then
    null; -- exact post-state: idempotent-safe rerun
  else
    raise exception 'Package D apply refused: profiles ACL is neither exact pre-state nor exact post-state';
  end if;
end;
$apply$;

-- Exact postconditions: complete table/column ACL plus effective access.
do $postconditions$
declare post_acl_ok boolean;
begin
  with available_privileges(privilege_type) as (
    values ('DELETE'::text), ('INSERT'), ('REFERENCES'), ('SELECT'),
      ('TRIGGER'), ('TRUNCATE'), ('UPDATE')
    union all
    select 'MAINTAIN'
    where pg_catalog.current_setting('server_version_num')::integer >= 170000
  ), expected_table(grantor, grantee, privilege_type, is_grantable) as (
    select 'postgres'::text, r.grantee, p.privilege_type, false
    from (values ('postgres'::text), ('anon'), ('authenticated'),
                 ('service_role')) r(grantee)
    cross join available_privileges p
    where not (
      r.grantee in ('anon', 'authenticated')
      and p.privilege_type = 'SELECT'
    )
    union all select 'postgres', 'audit_readonly', 'SELECT', false
  ), expected_columns(column_name, grantor, grantee, privilege_type, is_grantable) as (
    select c.column_name, 'postgres'::text, r.grantee, 'SELECT'::text, false
    from (values
      ('id'::text), ('type'), ('handle'), ('display_name'), ('bio'),
      ('avatar_url'), ('header_url'), ('location'), ('social_links'),
      ('is_creator'), ('is_verified'), ('created_at')
    ) c(column_name)
    cross join (values ('anon'::text), ('authenticated')) r(grantee)
  ), actual_table as (
    select acl.grantor::regrole::text,
      case when acl.grantee=0 then 'PUBLIC'
           else acl.grantee::regrole::text end,
      acl.privilege_type::text, acl.is_grantable
    from pg_catalog.pg_class c
    cross join lateral pg_catalog.aclexplode(
      coalesce(c.relacl, pg_catalog.acldefault('r', c.relowner))
    ) acl
    where c.oid = pg_catalog.to_regclass('public.profiles')
  ), actual_columns as (
    select a.attname::text, acl.grantor::regrole::text,
      case when acl.grantee=0 then 'PUBLIC'
           else acl.grantee::regrole::text end,
      acl.privilege_type::text, acl.is_grantable
    from pg_catalog.pg_attribute a
    cross join lateral pg_catalog.aclexplode(a.attacl) acl
    where a.attrelid = pg_catalog.to_regclass('public.profiles')
      and a.attnum>0 and not a.attisdropped and a.attacl is not null
  )
  select not exists (
    (select * from actual_table except select * from expected_table)
    union all
    (select * from expected_table except select * from actual_table)
  ) and not exists (
    (select * from actual_columns except select * from expected_columns)
    union all
    (select * from expected_columns except select * from actual_columns)
  ) into post_acl_ok;

  if not post_acl_ok
     or pg_catalog.has_table_privilege('anon','public.profiles','SELECT')
     or pg_catalog.has_table_privilege(
       'authenticated','public.profiles','SELECT'
     )
     or not (
       select pg_catalog.bool_and(
         pg_catalog.has_column_privilege(
           role_name, 'public.profiles', column_name, 'SELECT'
         )
       )
       from (values ('anon'::text),('authenticated')) roles(role_name)
       cross join (values
         ('id'::text),('type'),('handle'),('display_name'),('bio'),
         ('avatar_url'),('header_url'),('location'),('social_links'),
         ('is_creator'),('is_verified'),('created_at')
       ) columns(column_name)
     )
     or exists (
       select 1
       from (values ('anon'::text),('authenticated')) roles(role_name)
       cross join (values
         ('user_id'::text),('is_suspended'),('updated_at')
       ) columns(column_name)
       where pg_catalog.has_column_privilege(
         role_name, 'public.profiles', column_name, 'SELECT'
       )
     )
     or not pg_catalog.has_table_privilege(
       'service_role','public.profiles','SELECT'
     )
     or not pg_catalog.has_column_privilege(
       'service_role','public.profiles','user_id','SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'postgres','public.profiles','SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'audit_readonly','public.profiles','SELECT'
     ) then
    raise exception 'Package D postcondition failed: exact/effective ACL mismatch';
  end if;
end;
$postconditions$;

commit;
