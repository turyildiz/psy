-- psy.market MP-1 Package D: database-enforced public-profile privacy
-- ROLLBACK — OWNER-RUN ONLY; NOT EXECUTED BY THE REPOSITORY AGENT.
--
-- Restores the exact pre-cutover public.profiles ACL captured by PREFLIGHT:
-- postgres/anon/authenticated/service_role retain every table privilege available
-- on the target PostgreSQL major; audit_readonly retains SELECT; no direct column
-- ACL remains. All grantors are postgres and every grant option is false.
--
-- State machine:
-- * exact Package D post-state -> revoke the 24 narrow column grants and restore
--   anon/authenticated table SELECT;
-- * exact pre-state -> safe no-op rerun;
-- * every other ACL/relation state -> refuse without mutation.
-- No row, policy, function, schema or non-SELECT privilege is changed.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $rollback$
declare
  old_acl_ok boolean;
  new_acl_ok boolean;
begin
  if current_user <> 'postgres'
     or session_user <> 'postgres' then
    raise exception 'Package D rollback refused: project-owner SQL Editor context required';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_class c
    where c.oid = pg_catalog.to_regclass('public.profiles')
      and c.relkind = 'r'
      and c.relowner = 'postgres'::regrole
      and c.relrowsecurity and not c.relforcerowsecurity
  ) then
    raise exception 'Package D rollback refused: profiles relation/RLS drift';
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
    raise exception 'Package D rollback refused: profiles column contract drift';
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
    raise exception 'Package D rollback refused: profile row-visibility policy drift';
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

  if new_acl_ok then
    execute 'revoke select (
      id, type, handle, display_name, bio, avatar_url, header_url, location,
      social_links, is_creator, is_verified, created_at
    ) on table public.profiles from anon, authenticated';
    execute 'grant select on table public.profiles to anon, authenticated';
  elsif old_acl_ok then
    null; -- exact restored state: idempotent-safe rerun
  else
    raise exception 'Package D rollback refused: profiles ACL is neither exact post-state nor exact pre-state';
  end if;
end;
$rollback$;

do $postconditions$
declare old_acl_ok boolean;
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
    union all select 'postgres', 'audit_readonly', 'SELECT', false
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
    select 1
    from pg_catalog.pg_attribute a
    cross join lateral pg_catalog.aclexplode(a.attacl) acl
    where a.attrelid = pg_catalog.to_regclass('public.profiles')
      and a.attnum>0 and not a.attisdropped and a.attacl is not null
  )
  select not exists (
    (select * from actual_table except select * from expected_table)
    union all
    (select * from expected_table except select * from actual_table)
  ) and not exists (select 1 from actual_columns)
  into old_acl_ok;

  if not old_acl_ok
     or not pg_catalog.has_table_privilege(
       'anon','public.profiles','SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'authenticated','public.profiles','SELECT'
     )
     or not pg_catalog.has_column_privilege(
       'anon','public.profiles','user_id','SELECT'
     )
     or not pg_catalog.has_column_privilege(
       'authenticated','public.profiles','user_id','SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'service_role','public.profiles','SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'postgres','public.profiles','SELECT'
     )
     or not pg_catalog.has_table_privilege(
       'audit_readonly','public.profiles','SELECT'
     ) then
    raise exception 'Package D rollback postcondition failed: exact old ACL not restored';
  end if;
end;
$postconditions$;

commit;
