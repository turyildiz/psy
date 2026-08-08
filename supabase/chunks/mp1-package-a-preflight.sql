-- psy.market MP-1 Package A
-- FRESH OWNER-RUN READ-ONLY PREFLIGHT: public profile unlinkability baseline
--
-- Authoring status: NOT RUN by the repository agent.
-- Run the complete file once in the Supabase SQL Editor as the project owner.
-- This file contains SELECT/WITH statements only. It performs no DDL, DML,
-- transaction setting, schema-cache reload, application/RPC function call, or write.
-- Catalog and aggregate statements are intentionally separate snapshots; do not
-- make concurrent schema/ACL changes while this one-pass capture is running.
--
-- Detailed catalog-only result sets appear first. The final statement returns
-- exactly one compact summary row. Copy that final row back to the project agent.
-- GO means the repository-backed pre-change baseline is exact; it does not mean
-- that profiles.user_id is already private. STOP means drift or an unknown object.
-- UNPROVEN means required fixture evidence is still unavailable. Owner-confirmation
-- notes are listed separately and do not change section or overall status.

-- 01. Database/project identity. No project URL, key, or credential is selected.
select
  'DETAIL_01_PROJECT_IDENTITY'::text as result_set,
  current_database() as database_name,
  current_user as executor,
  session_user as session_executor,
  current_setting('server_version_num') as server_version_num,
  current_setting('row_security') as row_security,
  r.rolsuper,
  r.rolbypassrls,
  r.rolinherit,
  (select count(*)::bigint from auth.instances) as auth_instance_count,
  (select md5(string_agg(i.id::text, ',' order by i.id))
   from auth.instances i) as project_instance_fingerprint,
  md5(concat_ws('|', current_database(), current_user,
    current_setting('server_version_num'), r.rolsuper, r.rolbypassrls,
    r.rolinherit,
    (select md5(string_agg(i.id::text, ',' order by i.id))
     from auth.instances i))) as identity_fingerprint
from pg_roles r
where r.rolname = current_user;

-- 02a. public.profiles relation, columns, defaults, identity/generated state, comments.
select
  'DETAIL_02_PROFILES_COLUMNS'::text as result_set,
  c.relowner::regrole::text as table_owner,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls,
  obj_description(c.oid, 'pg_class') as table_comment,
  a.attnum as ordinal_position,
  a.attname as column_name,
  tn.nspname as type_schema,
  t.typname as type_name,
  pg_catalog.format_type(a.atttypid, a.atttypmod) as formatted_type,
  a.attnotnull as not_null,
  pg_get_expr(d.adbin, d.adrelid, true) as column_default,
  nullif(a.attidentity, '') as identity_kind,
  nullif(a.attgenerated, '') as generated_kind,
  col_description(a.attrelid, a.attnum) as column_comment,
  md5(concat_ws('|', a.attnum, a.attname, tn.nspname, t.typname,
    a.attnotnull, coalesce(pg_get_expr(d.adbin, d.adrelid, true), ''),
    a.attidentity, a.attgenerated,
    coalesce(obj_description(c.oid, 'pg_class'), ''),
    coalesce(col_description(a.attrelid, a.attnum), ''))) as column_fingerprint
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
join pg_attribute a on a.attrelid = c.oid
join pg_type t on t.oid = a.atttypid
join pg_namespace tn on tn.oid = t.typnamespace
left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
where n.nspname = 'public'
  and c.relname = 'profiles'
  and c.relkind = 'r'
  and a.attnum > 0
  and not a.attisdropped
order by a.attnum;

select
  'DETAIL_02_PROFILE_TYPE_ENUM'::text as result_set,
  e.enumsortorder,
  e.enumlabel,
  md5(concat_ws('|', e.enumsortorder, e.enumlabel)) as enum_value_fingerprint
from pg_enum e
where e.enumtypid = to_regtype('public.profile_type')
order by e.enumsortorder;

-- 02b. Exact constraints, indexes, and non-internal triggers.
select
  'DETAIL_02_PROFILES_OBJECTS'::text as result_set,
  'constraint'::text as object_kind,
  con.conname as object_name,
  pg_get_constraintdef(con.oid, true) as definition,
  con.convalidated as validated,
  md5(pg_get_constraintdef(con.oid, true)) as definition_fingerprint
from pg_constraint con
where con.conrelid = to_regclass('public.profiles')
union all
select
  'DETAIL_02_PROFILES_OBJECTS',
  'index',
  i.relname,
  pg_get_indexdef(i.oid),
  ix.indisvalid and ix.indisready,
  md5(pg_get_indexdef(i.oid))
from pg_index ix
join pg_class i on i.oid = ix.indexrelid
where ix.indrelid = to_regclass('public.profiles')
union all
select
  'DETAIL_02_PROFILES_OBJECTS',
  'trigger',
  t.tgname,
  pg_get_triggerdef(t.oid, true),
  t.tgenabled <> 'D',
  md5(pg_get_triggerdef(t.oid, true))
from pg_trigger t
where t.tgrelid = to_regclass('public.profiles')
  and not t.tgisinternal
order by object_kind, object_name;

-- 03. Exact table ACL, including implicit owner defaults when relacl is null.
select
  'DETAIL_03_PROFILES_TABLE_ACL'::text as result_set,
  acl.grantor::regrole::text as grantor,
  case when acl.grantee = 0 then 'PUBLIC'
       else acl.grantee::regrole::text end as grantee,
  acl.privilege_type,
  acl.is_grantable,
  case when c.relacl is null then 'implicit_acl_default'
       else 'direct_relacl' end as acl_source,
  md5(concat_ws('|', acl.grantor, acl.grantee, acl.privilege_type,
    acl.is_grantable)) as acl_entry_fingerprint
from pg_class c
cross join lateral aclexplode(
  coalesce(c.relacl, acldefault('r', c.relowner))
) acl
where c.oid = to_regclass('public.profiles')
order by grantee, privilege_type, grantor;

-- 04a. Direct column ACL entries. An empty result means no direct attacl entries.
select
  'DETAIL_04_PROFILES_DIRECT_COLUMN_ACL'::text as result_set,
  a.attnum as ordinal_position,
  a.attname as column_name,
  acl.grantor::regrole::text as grantor,
  case when acl.grantee = 0 then 'PUBLIC'
       else acl.grantee::regrole::text end as grantee,
  acl.privilege_type,
  acl.is_grantable,
  md5(concat_ws('|', a.attnum, a.attname, acl.grantor, acl.grantee,
    acl.privilege_type, acl.is_grantable)) as acl_entry_fingerprint
from pg_attribute a
cross join lateral aclexplode(a.attacl) acl
where a.attrelid = to_regclass('public.profiles')
  and a.attnum > 0
  and not a.attisdropped
order by a.attnum, grantee, privilege_type;

-- 04b. Effective table/column SELECT matrix and role existence.
-- PUBLIC is PostgreSQL's pseudo-role and is evaluated from grantee OID zero.
with principals(principal_name, role_exists) as (
  values
    ('PUBLIC'::text, true),
    ('anon', to_regrole('anon') is not null),
    ('authenticated', to_regrole('authenticated') is not null),
    ('service_role', to_regrole('service_role') is not null)
), public_table_select as (
  select exists (
    select 1
    from pg_class c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) acl
    where c.oid = to_regclass('public.profiles')
      and acl.grantee = 0
      and acl.privilege_type = 'SELECT'
  ) as allowed
)
select
  'DETAIL_04_EFFECTIVE_PRIVILEGES'::text as result_set,
  p.principal_name,
  p.role_exists,
  a.attnum as ordinal_position,
  a.attname as column_name,
  case
    when not p.role_exists then null
    when p.principal_name = 'PUBLIC' then pts.allowed
    else has_table_privilege(p.principal_name, 'public.profiles', 'SELECT')
  end as effective_table_select,
  case
    when not p.role_exists then null
    when p.principal_name = 'PUBLIC' then pts.allowed or exists (
      select 1 from aclexplode(a.attacl) ca
      where ca.grantee = 0 and ca.privilege_type = 'SELECT'
    )
    else has_column_privilege(
      p.principal_name, 'public.profiles', a.attname, 'SELECT'
    )
  end as effective_column_select
from principals p
cross join pg_attribute a
cross join public_table_select pts
where a.attrelid = to_regclass('public.profiles')
  and a.attnum > 0
  and not a.attisdropped
order by p.principal_name, a.attnum;

-- 04c. Direct role memberships touching an API role.
select
  'DETAIL_04_RELEVANT_ROLE_MEMBERSHIPS'::text as result_set,
  granted.rolname as granted_role,
  member.rolname as member_role,
  grantor.rolname as grantor_role,
  m.admin_option,
  md5(concat_ws('|', granted.rolname, member.rolname, grantor.rolname,
    m.admin_option)) as membership_fingerprint
from pg_auth_members m
join pg_roles granted on granted.oid = m.roleid
join pg_roles member on member.oid = m.member
join pg_roles grantor on grantor.oid = m.grantor
where granted.rolname in ('anon', 'authenticated', 'service_role')
   or member.rolname in ('anon', 'authenticated', 'service_role')
order by granted_role, member_role, grantor_role;

with recursive membership_paths(
  api_role_oid, inherited_role_oid, depth, role_path, membership_options
) as (
  select member.oid, granted.oid, 1,
    array[member.oid, granted.oid],
    jsonb_build_array(to_jsonb(m) - 'roleid' - 'member' - 'grantor')
  from pg_auth_members m
  join pg_roles member on member.oid = m.member
  join pg_roles granted on granted.oid = m.roleid
  where member.rolname in ('anon', 'authenticated', 'service_role')
  union all
  select mp.api_role_oid, granted.oid, mp.depth + 1,
    mp.role_path || granted.oid,
    mp.membership_options ||
      jsonb_build_array(to_jsonb(m) - 'roleid' - 'member' - 'grantor')
  from membership_paths mp
  join pg_auth_members m on m.member = mp.inherited_role_oid
  join pg_roles granted on granted.oid = m.roleid
  where not granted.oid = any(mp.role_path)
)
select
  'DETAIL_04_ROLE_MEMBERSHIP_CLOSURE'::text as result_set,
  api.rolname as api_role,
  inherited.rolname as inherited_role,
  mp.depth,
  inherited.rolinherit,
  inherited.rolsuper,
  inherited.rolbypassrls,
  mp.membership_options,
  md5(concat_ws('|', api.rolname, inherited.rolname, mp.depth,
    mp.membership_options::text)) as membership_path_fingerprint
from membership_paths mp
join pg_roles api on api.oid = mp.api_role_oid
join pg_roles inherited on inherited.oid = mp.inherited_role_oid
order by api_role, depth, inherited_role;

-- 05. Relevant public-schema default privileges, fully exploded.
select
  'DETAIL_05_DEFAULT_PRIVILEGES'::text as result_set,
  owner_role.rolname as object_creator,
  coalesce(n.nspname, '*ALL_SCHEMAS*') as target_schema,
  d.defaclobjtype as object_type_code,
  case d.defaclobjtype
    when 'r' then 'tables'
    when 'S' then 'sequences'
    when 'f' then 'functions'
    when 'T' then 'types'
    when 'n' then 'schemas'
    else d.defaclobjtype::text
  end as object_type,
  acl.grantor::regrole::text as grantor,
  case when acl.grantee = 0 then 'PUBLIC'
       else acl.grantee::regrole::text end as grantee,
  acl.privilege_type,
  acl.is_grantable,
  md5(concat_ws('|', owner_role.rolname, coalesce(n.nspname, '*'),
    d.defaclobjtype, acl.grantor, acl.grantee, acl.privilege_type,
    acl.is_grantable)) as default_acl_fingerprint
from pg_default_acl d
join pg_roles owner_role on owner_role.oid = d.defaclrole
left join pg_namespace n on n.oid = d.defaclnamespace
cross join lateral aclexplode(d.defaclacl) acl
where n.nspname = 'public' or d.defaclnamespace = 0
order by object_creator, target_schema, object_type_code, grantee,
  privilege_type;

select
  'DETAIL_05_PUBLIC_SCHEMA_ACL'::text as result_set,
  n.nspowner::regrole::text as schema_owner,
  acl.grantor::regrole::text as grantor,
  case when acl.grantee = 0 then 'PUBLIC'
       else acl.grantee::regrole::text end as grantee,
  acl.privilege_type,
  acl.is_grantable,
  md5(concat_ws('|', n.nspowner, acl.grantor, acl.grantee,
    acl.privilege_type, acl.is_grantable)) as schema_acl_fingerprint
from pg_namespace n
cross join lateral aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) acl
where n.nspname = 'public'
order by grantee, privilege_type, grantor;

-- 06. Every policy on public.profiles, including complete expressions.
select
  'DETAIL_06_PROFILES_POLICIES'::text as result_set,
  pol.polname as policy_name,
  case pol.polcmd
    when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE'
    when 'd' then 'DELETE' when '*' then 'ALL' else pol.polcmd::text
  end as command,
  case when pol.polpermissive then 'PERMISSIVE' else 'RESTRICTIVE' end as mode,
  array(
    select case when role_oid = 0 then 'PUBLIC'
                else role_oid::regrole::text end
    from unnest(pol.polroles) as r(role_oid)
    order by 1
  ) as roles,
  pg_get_expr(pol.polqual, pol.polrelid, true) as using_expression,
  pg_get_expr(pol.polwithcheck, pol.polrelid, true) as with_check_expression,
  md5(concat_ws('|', pol.polname, pol.polcmd, pol.polpermissive,
    pol.polroles::text,
    coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), ''),
    coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), '')))
    as policy_fingerprint
from pg_policy pol
where pol.polrelid = to_regclass('public.profiles')
order by policy_name;

-- 07. Every cross-table policy that references profiles, owner columns, or
-- reviewed profile-visibility/ownership helper names.
select
  'DETAIL_07_CROSS_TABLE_OWNER_POLICIES'::text as result_set,
  n.nspname as schema_name,
  c.relname as table_name,
  pol.polname as policy_name,
  case pol.polcmd
    when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE'
    when 'd' then 'DELETE' when '*' then 'ALL' else pol.polcmd::text
  end as command,
  case when pol.polpermissive then 'PERMISSIVE' else 'RESTRICTIVE' end as mode,
  array(
    select case when role_oid = 0 then 'PUBLIC'
                else role_oid::regrole::text end
    from unnest(pol.polroles) as r(role_oid)
    order by 1
  ) as roles,
  pg_get_expr(pol.polqual, pol.polrelid, true) as using_expression,
  pg_get_expr(pol.polwithcheck, pol.polrelid, true) as with_check_expression,
  md5(concat_ws('|', n.nspname, c.relname, pol.polname, pol.polcmd,
    pol.polpermissive, pol.polroles::text,
    coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), ''),
    coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), '')))
    as policy_fingerprint
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace
where pol.polrelid <> to_regclass('public.profiles')
  and lower(concat_ws(' ',
    pg_get_expr(pol.polqual, pol.polrelid, true),
    pg_get_expr(pol.polwithcheck, pol.polrelid, true)
  )) ~ '(profiles|user_id|profile_owner_is_banned|current_user_can_read_post)'
order by schema_name, table_name, policy_name;

-- 08a. Complete definitions and ACL fingerprints for every relevant public
-- function/overload. Function bodies are catalog source, not executed.
with target_functions as (
  select
    p.oid,
    n.nspname,
    p.proname,
    pg_get_function_identity_arguments(p.oid) as identity_arguments,
    pg_get_function_result(p.oid) as result_type,
    p.proowner,
    p.prolang,
    p.prokind,
    p.provolatile,
    p.proparallel,
    p.proisstrict,
    p.proleakproof,
    p.proretset,
    p.proallargtypes,
    p.proargmodes,
    p.proargnames,
    p.prosecdef,
    p.proconfig,
    p.prosrc,
    pg_get_functiondef(p.oid) as full_definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_type rt on rt.oid = p.prorettype
  join pg_namespace rtn on rtn.oid = rt.typnamespace
  where n.nspname = 'public'
    and (
      lower(p.prosrc) ~ '((^|[^a-z0-9_])user_id([^a-z0-9_]|$)|target_user_id|account_user_id)'
      or (rtn.nspname = 'public' and rt.typname in ('profiles', '_profiles'))
      or rt.typname in ('record', 'json', 'jsonb')
      or (rt.typname = 'uuid' and lower(p.prosrc) like '%auth.uid()%')
      or p.proname in (
        'profile_owner_is_banned',
        'current_user_can_read_post_author',
        'current_user_can_read_post',
        'current_user_can_read_post_reaction'
      )
    )
)
select
  'DETAIL_08_RELEVANT_FUNCTIONS'::text as result_set,
  tf.nspname as schema_name,
  tf.proname as function_name,
  tf.identity_arguments,
  tf.result_type,
  tf.proowner::regrole::text as owner,
  l.lanname as language,
  tf.prokind as function_kind,
  tf.provolatile as volatility_code,
  tf.proparallel as parallel_safety_code,
  tf.proisstrict as strict,
  tf.proleakproof as leakproof,
  tf.proretset as returns_set,
  tf.proallargtypes,
  tf.proargmodes,
  tf.proargnames,
  tf.prosecdef as security_definer,
  tf.proconfig,
  tf.prosrc as complete_body,
  tf.full_definition,
  md5(tf.full_definition) as definition_fingerprint,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'grantor', acl.grantor::regrole::text,
      'grantee', case when acl.grantee = 0 then 'PUBLIC'
                      else acl.grantee::regrole::text end,
      'privilege', acl.privilege_type,
      'grantable', acl.is_grantable
    ) order by case when acl.grantee = 0 then 'PUBLIC'
                    else acl.grantee::regrole::text end,
               acl.privilege_type, acl.grantor::regrole::text)
    from aclexplode(coalesce(
      (select p2.proacl from pg_proc p2 where p2.oid = tf.oid),
      acldefault('f', tf.proowner)
    )) acl
  ), '[]'::jsonb) as exploded_acl
from target_functions tf
join pg_language l on l.oid = tf.prolang
order by schema_name, function_name, identity_arguments;

-- 08b. One row per relevant function ACL entry for copy/paste-safe diffing.
with target_functions as (
  select p.oid, p.proowner
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_type rt on rt.oid = p.prorettype
  join pg_namespace rtn on rtn.oid = rt.typnamespace
  where n.nspname = 'public'
    and (
      lower(p.prosrc) ~ '((^|[^a-z0-9_])user_id([^a-z0-9_]|$)|target_user_id|account_user_id)'
      or (rtn.nspname = 'public' and rt.typname in ('profiles', '_profiles'))
      or rt.typname in ('record', 'json', 'jsonb')
      or (rt.typname = 'uuid' and lower(p.prosrc) like '%auth.uid()%')
      or p.proname in (
        'profile_owner_is_banned',
        'current_user_can_read_post_author',
        'current_user_can_read_post',
        'current_user_can_read_post_reaction'
      )
    )
)
select
  'DETAIL_08_RELEVANT_FUNCTION_ACLS'::text as result_set,
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  acl.grantor::regrole::text as grantor,
  case when acl.grantee = 0 then 'PUBLIC'
       else acl.grantee::regrole::text end as grantee,
  acl.privilege_type,
  acl.is_grantable,
  md5(concat_ws('|', p.oid::text, acl.grantor, acl.grantee,
    acl.privilege_type, acl.is_grantable)) as acl_entry_fingerprint
from target_functions tf
join pg_proc p on p.oid = tf.oid
join pg_namespace n on n.oid = p.pronamespace
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
order by schema_name, function_name, identity_arguments, grantee,
  privilege_type;

-- 09. Every ordinary/materialized view with a catalog dependency on profiles.
with recursive dependent_views(oid, dependency_depth, dependency_path) as (
  select distinct vc.oid, 1, array[to_regclass('public.profiles')::oid, vc.oid]
  from pg_rewrite rw
  join pg_depend dep
    on dep.classid = 'pg_rewrite'::regclass
   and dep.objid = rw.oid
   and dep.refclassid = 'pg_class'::regclass
  join pg_class vc on vc.oid = rw.ev_class
  where dep.refobjid = to_regclass('public.profiles')
    and vc.relkind in ('v', 'm')
  union all
  select vc.oid, dv.dependency_depth + 1, dv.dependency_path || vc.oid
  from dependent_views dv
  join pg_depend dep
    on dep.refclassid = 'pg_class'::regclass
   and dep.refobjid = dv.oid
   and dep.classid = 'pg_rewrite'::regclass
  join pg_rewrite rw on rw.oid = dep.objid
  join pg_class vc on vc.oid = rw.ev_class
  where vc.relkind in ('v', 'm')
    and not vc.oid = any(dv.dependency_path)
), canonical_dependent_views as (
  select oid, min(dependency_depth) as dependency_depth
  from dependent_views
  group by oid
)
select
  'DETAIL_09_DEPENDENT_VIEWS'::text as result_set,
  n.nspname as schema_name,
  c.relname as view_name,
  case c.relkind when 'v' then 'view' else 'materialized_view' end as view_kind,
  c.relowner::regrole::text as owner,
  dv.dependency_depth,
  c.relispopulated as materialized_view_populated,
  c.reloptions as security_options,
  obj_description(c.oid, 'pg_class') as view_comment,
  pg_get_viewdef(c.oid, true) as definition,
  md5(pg_get_viewdef(c.oid, true)) as definition_fingerprint,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'grantor', acl.grantor::regrole::text,
      'grantee', case when acl.grantee = 0 then 'PUBLIC'
                      else acl.grantee::regrole::text end,
      'privilege', acl.privilege_type,
      'grantable', acl.is_grantable
    ) order by case when acl.grantee = 0 then 'PUBLIC'
                    else acl.grantee::regrole::text end,
               acl.privilege_type)
    from aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
  ), '[]'::jsonb) as exploded_acl
from canonical_dependent_views dv
join pg_class c on c.oid = dv.oid
join pg_namespace n on n.oid = c.relnamespace
order by schema_name, view_name;

-- 10. Complete PostgREST FK relationship manifest involving profiles.
select
  'DETAIL_10_POSTGREST_PROFILE_FKS'::text as result_set,
  child_ns.nspname as child_schema,
  child.relname as child_table,
  con.conname as constraint_name,
  array(
    select child_att.attname
    from unnest(con.conkey) with ordinality ck(attnum, ord)
    join pg_attribute child_att
      on child_att.attrelid = con.conrelid and child_att.attnum = ck.attnum
    order by ck.ord
  ) as child_columns,
  parent_ns.nspname as parent_schema,
  parent.relname as parent_table,
  array(
    select parent_att.attname
    from unnest(con.confkey) with ordinality fk(attnum, ord)
    join pg_attribute parent_att
      on parent_att.attrelid = con.confrelid and parent_att.attnum = fk.attnum
    order by fk.ord
  ) as parent_columns,
  con.convalidated as validated,
  con.condeferrable as is_deferrable,
  con.condeferred as initially_deferred,
  con.confmatchtype as match_type_code,
  con.confupdtype as update_action_code,
  con.confdeltype as delete_action_code,
  pg_get_constraintdef(con.oid, true) as definition,
  md5(pg_get_constraintdef(con.oid, true)) as relationship_fingerprint
from pg_constraint con
join pg_class child on child.oid = con.conrelid
join pg_namespace child_ns on child_ns.oid = child.relnamespace
join pg_class parent on parent.oid = con.confrelid
join pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
where con.contype = 'f'
  and (con.conrelid = to_regclass('public.profiles')
       or con.confrelid = to_regclass('public.profiles'))
order by child_schema, child_table, constraint_name;

-- 11. Realtime publication flags, exact membership/column filters, and replica identity.
select
  'DETAIL_11_REALTIME_PUBLICATION'::text as result_set,
  pub.pubname,
  pub.puballtables,
  pub.pubinsert,
  pub.pubupdate,
  pub.pubdelete,
  pub.pubtruncate,
  pub.pubviaroot,
  n.nspname as schema_name,
  c.relname as table_name,
  case c.relreplident
    when 'd' then 'DEFAULT' when 'n' then 'NOTHING'
    when 'f' then 'FULL' when 'i' then 'INDEX' else c.relreplident::text
  end as replica_identity,
  coalesce(to_jsonb(pr)->'prattrs', 'null'::jsonb)
    as publication_column_list_raw,
  coalesce(to_jsonb(pr)->'prqual', 'null'::jsonb)
    as publication_row_filter_raw,
  md5(concat_ws('|', pub.pubname, pub.puballtables, pub.pubinsert,
    pub.pubupdate, pub.pubdelete, pub.pubtruncate, pub.pubviaroot,
    n.nspname, c.relname, c.relreplident,
    coalesce((to_jsonb(pr)->'prattrs')::text, '*'),
    coalesce((to_jsonb(pr)->'prqual')::text, '*'))) as publication_fingerprint
from pg_publication pub
left join pg_publication_rel pr on pr.prpubid = pub.oid
left join pg_class c on c.oid = pr.prrelid
left join pg_namespace n on n.oid = c.relnamespace
where pub.pubname in ('supabase_realtime',
                      'supabase_realtime_messages_publication')
order by pub.pubname, schema_name nulls first, table_name nulls first;

select
  'DETAIL_11_ALL_PUBLICATIONS'::text as result_set,
  pubname, puballtables, pubinsert, pubupdate, pubdelete, pubtruncate,
  pubviaroot,
  md5(concat_ws('|', pubname, puballtables, pubinsert, pubupdate,
    pubdelete, pubtruncate, pubviaroot)) as publication_fingerprint
from pg_publication
order by pubname;

select
  'DETAIL_11_EXPANDED_PUBLICATION_MEMBERS'::text as result_set,
  pubname,
  schemaname as schema_name,
  tablename as table_name,
  attnames as published_columns,
  rowfilter as row_filter,
  md5(concat_ws('|', pubname, schemaname, tablename,
    attnames::text, rowfilter)) as membership_fingerprint
from pg_publication_tables
order by pubname, schemaname, tablename;

select
  'DETAIL_11_SCHEMA_PUBLICATIONS'::text as result_set,
  p.pubname,
  n.nspname as schema_name,
  md5(concat_ws('|', p.pubname, n.nspname)) as membership_fingerprint
from pg_publication_namespace pn
join pg_publication p on p.oid = pn.pnpubid
join pg_namespace n on n.oid = pn.pnnspid
order by p.pubname, n.nspname;

select
  'DETAIL_11_PROFILES_REPLICA_IDENTITY'::text as result_set,
  n.nspname as schema_name,
  c.relname as table_name,
  case c.relreplident
    when 'd' then 'DEFAULT' when 'n' then 'NOTHING'
    when 'f' then 'FULL' when 'i' then 'INDEX' else c.relreplident::text
  end as replica_identity,
  exists (
    select 1
    from pg_publication_rel pr
    join pg_publication p on p.oid = pr.prpubid
    where pr.prrelid = c.oid
  ) as profiles_is_explicit_member_any_publication,
  exists (
    select 1 from pg_publication p where p.puballtables
  ) as any_publication_includes_all_tables,
  exists (
    select 1
    from pg_publication_namespace pn
    join pg_namespace published_ns on published_ns.oid = pn.pnnspid
    where published_ns.nspname = 'public'
  ) as public_schema_is_published
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.oid = to_regclass('public.profiles');

-- 12. Catalog-only pg_graphql exposure. No GraphQL function is invoked.
select
  'DETAIL_12_GRAPHQL_EXPOSURE'::text as result_set,
  ext.extname as extension_name,
  ext.extversion as extension_version,
  ext_ns.nspname as extension_schema,
  to_regnamespace('graphql_public') is not null as graphql_public_schema_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'graphql_public' and p.proname = 'graphql'
  ) as graphql_entry_function_exists,
  obj_description(to_regclass('public.profiles'), 'pg_class') as profiles_table_comment,
  has_table_privilege('anon', 'public.profiles', 'SELECT') as anon_profiles_select,
  has_table_privilege('authenticated', 'public.profiles', 'SELECT')
    as authenticated_profiles_select,
  md5(concat_ws('|', ext.extname, ext.extversion, ext_ns.nspname,
    to_regnamespace('graphql_public') is not null,
    obj_description(to_regclass('public.profiles'), 'pg_class'),
    has_table_privilege('anon', 'public.profiles', 'SELECT'),
    has_table_privilege('authenticated', 'public.profiles', 'SELECT')))
    as graphql_catalog_fingerprint
from pg_extension ext
join pg_namespace ext_ns on ext_ns.oid = ext.extnamespace
where ext.extname = 'pg_graphql'
union all
select
  'DETAIL_12_GRAPHQL_EXPOSURE',
  'pg_graphql', null, null,
  to_regnamespace('graphql_public') is not null,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'graphql_public' and p.proname = 'graphql'
  ),
  obj_description(to_regclass('public.profiles'), 'pg_class'),
  has_table_privilege('anon', 'public.profiles', 'SELECT'),
  has_table_privilege('authenticated', 'public.profiles', 'SELECT'),
  md5('pg_graphql:not_installed')
where not exists (select 1 from pg_extension where extname = 'pg_graphql');

select
  'DETAIL_12_GRAPHQL_ENTRY_FUNCTIONS'::text as result_set,
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_function_result(p.oid) as result_type,
  p.proowner::regrole::text as owner,
  p.prosecdef as security_definer,
  p.proconfig,
  md5(pg_get_functiondef(p.oid)) as definition_fingerprint,
  acl.grantor::regrole::text as grantor,
  case when acl.grantee = 0 then 'PUBLIC'
       else acl.grantee::regrole::text end as grantee,
  acl.privilege_type,
  acl.is_grantable
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
where n.nspname = 'graphql_public'
order by function_name, identity_arguments, grantee, privilege_type;

select
  'DETAIL_12_GRAPHQL_SCHEMA_ACL'::text as result_set,
  n.nspname as schema_name,
  n.nspowner::regrole::text as owner,
  acl.grantor::regrole::text as grantor,
  case when acl.grantee = 0 then 'PUBLIC'
       else acl.grantee::regrole::text end as grantee,
  acl.privilege_type,
  acl.is_grantable,
  md5(concat_ws('|', n.nspname, n.nspowner, acl.grantor, acl.grantee,
    acl.privilege_type, acl.is_grantable)) as acl_entry_fingerprint
from pg_namespace n
cross join lateral aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) acl
where n.nspname = 'graphql_public'
order by grantee, privilege_type, grantor;

-- 13. Safe aggregate-only invariants. No IDs, handles, URLs, or row samples.
select
  'DETAIL_13_SAFE_PROFILE_AGGREGATES'::text as result_set,
  count(*)::bigint as profile_count,
  count(*) filter (where user_id is null)::bigint as null_owner_count,
  (select count(*)::bigint
   from public.profiles px
   left join auth.users au on au.id = px.user_id
   where au.id is null) as orphan_auth_owner_count,
  (select count(*)::bigint
   from public.profiles px
   left join public.users pu on pu.id = px.user_id
   where pu.id is null) as missing_public_user_owner_count,
  (
    select count(*)::bigint
    from (
      select user_id
      from public.profiles
      group by user_id
      having count(*) > 1
    ) duplicate_groups
  ) as duplicate_owner_group_count,
  count(*) filter (
    where nullif(btrim(handle), '') is not null
      and nullif(btrim(display_name), '') is not null
  )::bigint as public_response_fixture_count,
  coalesce((select rolbypassrls or rolsuper
            from pg_roles where rolname = current_user), false)
    as aggregate_visibility_complete,
  max(owner_profile_count)::bigint as maximum_profiles_per_owner,
  md5(concat_ws('|', count(*),
    count(*) filter (where user_id is null),
    (select count(*) from public.profiles px
     left join auth.users au on au.id = px.user_id where au.id is null),
    (select count(*) from public.profiles px
     left join public.users pu on pu.id = px.user_id where pu.id is null),
    (select count(*) from (
      select user_id from public.profiles group by user_id having count(*) > 1
    ) d),
    count(*) filter (
      where nullif(btrim(handle), '') is not null
        and nullif(btrim(display_name), '') is not null
    ),
    coalesce((select rolbypassrls or rolsuper
              from pg_roles where rolname = current_user), false),
    max(owner_profile_count))) as aggregate_fingerprint
from public.profiles p
cross join lateral (
  select count(*) as owner_profile_count
  from public.profiles sibling
  where sibling.user_id = p.user_id
) owner_counts;

-- 14. Frozen app-query manifest for repository revision
-- 83d35c728031ce2836246d9677aead37ad93fde0.
with app_manifest(ordinal, canonical_entry) as (
  values
    (1, 'app/[handle]/page.tsx:191	direct_read	owner_browser	change	select id,handle; filter user_id'),
    (2, 'app/[handle]/page.tsx:239	direct_read	public_browser	change	select *; filter handle'),
    (3, 'app/api/auth/signup/route.ts:49	direct_read	service_role	retain	select id; filter handle'),
    (4, 'app/festivals/[slug]/page.tsx:717	direct_read	owner_browser	change	select id; filter user_id'),
    (5, 'app/listing/[id]/edit/page.tsx:180	direct_read	owner_browser	change	select id,handle; filter user_id'),
    (6, 'app/listing/[id]/page.tsx:135	direct_read	owner_browser	change	select id; filter user_id'),
    (7, 'app/listing/[id]/page.tsx:169	direct_read	public_browser	change	select *; filter profile id'),
    (8, 'app/listing/[id]/page.tsx:186	direct_read	handle_lookup	retain	select id; filter handle'),
    (9, 'app/listings/new/page.tsx:249	direct_read	owner_browser	change	select id; filter user_id'),
    (10, 'app/messages/page.tsx:13	direct_read	owner_browser	change	select handle; filter user_id'),
    (11, 'app/page.tsx:64	direct_read	public_browser	change	select *; order created_at; limit 6'),
    (12, 'app/profile/edit/page.tsx:129	direct_read	owner_browser	change	select *; filter user_id'),
    (13, 'app/signup/page.tsx:156	direct_read	handle_lookup	retain	select id; filter handle'),
    (14, 'components/AuthModal.tsx:243	direct_read	handle_lookup	retain	select id; filter handle'),
    (15, 'components/EditProfileModal.tsx:91	direct_read	handle_lookup	retain	select id; filter handle'),
    (16, 'components/layout/Header.tsx:89	direct_read	owner_browser	change	select id,handle,display_name,avatar_url; filter user_id; limit 1'),
    (17, 'lib/posts/use-reaction-viewer.ts:28	direct_read	owner_browser	change	select id; filter user_id'),
    (18, 'lib/uploads/authorization.ts:20	direct_read	auth_server	change	select id,user_id; filter profile id'),
    (19, 'lib/uploads/trusted-upload-server.ts:153	direct_read	service_role	retain	select id,user_id; filter profile id'),
    (20, 'scripts/upload-and-create.js:14	direct_read	service_role_cli	retain	select id,user_id; filter handle'),
    (21, 'scripts/upload-r2.js:8	direct_read	service_role_cli	retain	select id,user_id; filter handle'),
    (22, 'app/[handle]/page.tsx:249	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (23, 'app/apparel/page.tsx:136	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (24, 'app/browse/page.tsx:152	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (25, 'app/festivals/[slug]/page.tsx:162	nested_read	public_browser	change	vendor_events profiles(*)'),
    (26, 'app/festivals/[slug]/page.tsx:306	nested_read	public_browser	retain	notice_posts profiles(handle,display_name,avatar_url)'),
    (27, 'app/jewellery/page.tsx:126	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (28, 'app/listing/[id]/page.tsx:171	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (29, 'app/music/page.tsx:125	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (30, 'app/page.tsx:40	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (31, 'app/page.tsx:48	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (32, 'app/page.tsx:56	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (33, 'components/MessagesInbox.tsx:72	nested_read	owner_browser	retain	conversations buyer/seller profiles(id,handle,display_name,avatar_url)'),
    (34, 'components/StandardCategoryPage.tsx:150	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (35, 'components/StreamPageClient.tsx:85	nested_read	public_browser	retain	posts profiles(id,handle,display_name,avatar_url)'),
    (36, 'lib/uploads/references-server.ts:44	generic_read	service_role	retain	select id,avatar_url,header_url'),
    (37, 'scripts/cleanup-promoted-pending.js:85	generic_read	service_role_cli	retain	select id,avatar_url,header_url'),
    (38, 'scripts/report-r2-orphans.js:65	generic_read	service_role_cli	retain	select id,avatar_url,header_url'),
    (39, 'app/api/auth/signup/route.ts:125	mutation	service_role	retain	update; filter user_id; return id'),
    (40, 'app/profile/edit/page.tsx:164	mutation	owner_browser	retain	update; filter profile id; no return'),
    (41, 'components/EditProfileModal.tsx:140	mutation	owner_browser	retain	update; filter profile id; return id')
), manifest_summary as (
  select
    count(*) as manifest_entry_count,
    count(*) filter (where canonical_entry like E'%\tdirect_read\t%')
      as direct_read_count,
    count(*) filter (where canonical_entry like E'%\tnested_read\t%')
      as nested_read_count,
    count(*) filter (where canonical_entry like E'%\tgeneric_read\t%')
      as generic_read_count,
    count(*) filter (where canonical_entry like E'%\tmutation\t%')
      as mutation_count,
    md5(string_agg(canonical_entry, E'\n' order by ordinal) || E'\n')
      as computed_md5
  from app_manifest
)
select
  'DETAIL_14_APP_QUERY_MANIFEST'::text as result_set,
  m.ordinal,
  m.canonical_entry,
  '83d35c728031ce2836246d9677aead37ad93fde0'::text
    as source_revision,
  '42a8f28024eb0ec3eb15814fe9327aabd80a8bd693d88d87fe3694bbb3dee2e6'::text
    as source_manifest_sha256,
  s.computed_md5 as computed_manifest_md5,
  'dcaea87c018d282ed4877edc1a9ea2b5'::text as expected_manifest_md5,
  s.manifest_entry_count,
  s.direct_read_count,
  s.nested_read_count,
  s.generic_read_count,
  s.mutation_count
from app_manifest m
cross join manifest_summary s
order by m.ordinal;

with app_source_blobs(source_path, git_blob_sha1) as (
  values
    ('app/[handle]/page.tsx', 'e7c7e16541a7d4ce04412113a0e941f1e4bec400'),
    ('app/api/auth/signup/route.ts', 'adf6eeaa40a2c582ddc058fdb333ceff1e9a90bb'),
    ('app/apparel/page.tsx', '3f115314ab11969688a1661c502897e1863f214c'),
    ('app/browse/page.tsx', 'b3ccf978b8ad8efcddba0ea81a2adbd33f124a29'),
    ('app/festivals/[slug]/page.tsx', '78ba1d749e471cdec4a59b6fef096e04fdba31a3'),
    ('app/jewellery/page.tsx', '6b88850a4272ac39713cee8a5cc03c97d090a5a3'),
    ('app/listing/[id]/edit/page.tsx', 'cf01e9b5a72b772128d4e79517ba1c4ee8db6f6a'),
    ('app/listing/[id]/page.tsx', 'd2d0e6e25281e0e1ae6de840a5879994d0c90d73'),
    ('app/listings/new/page.tsx', '4b6e42be96e79d4f14455df2562e49dbbdbe8231'),
    ('app/messages/page.tsx', '2c8ee2c6ce7d60ad41797d4e403be722d70a061f'),
    ('app/music/page.tsx', 'cbd70024b55709c7312ac329d89a7aeaa93591ad'),
    ('app/page.tsx', '47a40d627e9be99ff4757740767125880c922a0d'),
    ('app/profile/edit/page.tsx', '98a1e8ff191f13a4d3448e8f9b984fea4701e6be'),
    ('app/signup/page.tsx', 'e60f66b4458029e8c782dd65e9ef1a3b4416baf8'),
    ('components/AuthModal.tsx', '31bbcec54d0335fc748c3b71270cce17caef1d34'),
    ('components/EditProfileModal.tsx', 'fcebe78a3c93828e13d16b06cb450f1e833e45b6'),
    ('components/MessagesInbox.tsx', 'dd14c00505e257abfab220fed654261548dc90bf'),
    ('components/StandardCategoryPage.tsx', '15e9ac055b1f8df681f9508e352781b76d13f725'),
    ('components/StreamPageClient.tsx', 'f02f331476af7ae0f25003d488f744bf0f055a8a'),
    ('components/layout/Header.tsx', 'badefeca2448b5926ab9ad2a80f5c811814c28cf'),
    ('lib/posts/use-reaction-viewer.ts', '9ad83d3f0e755ffbfbce09d998ddcab9b12c0f92'),
    ('lib/uploads/authorization.ts', 'ad70d9b1c8dd9a35aa9be43dd99afa7d29cd8d26'),
    ('lib/uploads/references-server.ts', 'c196e4a4f71ef763f70d817e0bca610bf14405aa'),
    ('lib/uploads/trusted-upload-server.ts', '3508ca9bfcb2ef9bf88053a0f998978e4bfaf762'),
    ('scripts/cleanup-promoted-pending.js', '0dd9d44e3a625c2c81e8f85710c016e7b6a0f6b6'),
    ('scripts/report-r2-orphans.js', '5dd3d98a8c032524fd2bfdea9dd0dddb4c4afaf5'),
    ('scripts/upload-and-create.js', '83179e915655340637e51856b76f114c612d7d2d'),
    ('scripts/upload-r2.js', 'bda03e82b7c4644eb6b407db825c7515031d5e8e')
), source_blob_summary as (
  select count(*) as source_file_count,
    md5(string_agg(source_path || E'\t' || git_blob_sha1,
      E'\n' order by source_path collate "C") || E'\n') as computed_md5
  from app_source_blobs
)
select
  'DETAIL_14_APP_SOURCE_BLOBS'::text as result_set,
  b.source_path,
  b.git_blob_sha1,
  '83d35c728031ce2836246d9677aead37ad93fde0'::text as source_revision,
  '8dff6d43a19a896985d60e12585b7e2b00f0c68b667209e9b0eeceaf514f8aad'::text
    as source_blob_manifest_sha256,
  s.computed_md5 as computed_source_blob_manifest_md5,
  '20ab83d8d6bbdbe02bbf0efecf19286d'::text
    as expected_source_blob_manifest_md5,
  s.source_file_count
from app_source_blobs b
cross join source_blob_summary s
order by b.source_path collate "C";

-- FINAL RESULT SET: exactly one compact summary row.
with recursive
expected_columns(ordinal_position, column_name, type_schema, type_name,
  not_null, normalized_default, column_comment) as (
  values
    (1, 'id', 'pg_catalog', 'uuid', true, 'gen_random_uuid()', ''),
    (2, 'user_id', 'pg_catalog', 'uuid', true, '', ''),
    (3, 'type', 'public', 'profile_type', true,
      '''personal''::profile_type', ''),
    (4, 'handle', 'pg_catalog', 'text', true, '', ''),
    (5, 'display_name', 'pg_catalog', 'text', true, '', ''),
    (6, 'bio', 'pg_catalog', 'text', false, '', ''),
    (7, 'avatar_url', 'pg_catalog', 'text', false, '', ''),
    (8, 'header_url', 'pg_catalog', 'text', false, '', ''),
    (9, 'location', 'pg_catalog', 'text', false, '', ''),
    (10, 'social_links', 'pg_catalog', 'jsonb', false, '''{}''::jsonb', ''),
    (11, 'is_creator', 'pg_catalog', 'bool', true, 'false', ''),
    (12, 'is_verified', 'pg_catalog', 'bool', true, 'false', ''),
    (13, 'is_suspended', 'pg_catalog', 'bool', true, 'false', ''),
    (14, 'created_at', 'pg_catalog', 'timestamptz', true, 'now()', ''),
    (15, 'updated_at', 'pg_catalog', 'timestamptz', true, 'now()', '')
),
expected_profile_type_labels(enum_order, enum_label) as (
  values (1, 'personal'), (2, 'artist'), (3, 'label'), (4, 'festival')
),
actual_profile_type_labels as (
  select row_number() over (order by e.enumsortorder)::integer as enum_order,
    e.enumlabel::text as enum_label
  from pg_enum e
  where e.enumtypid = to_regtype('public.profile_type')
),
actual_columns as (
  select
    a.attnum::integer as ordinal_position,
    a.attname::text as column_name,
    tn.nspname::text as type_schema,
    t.typname::text as type_name,
    a.attnotnull as not_null,
    regexp_replace(
      coalesce(pg_get_expr(d.adbin, d.adrelid, true), ''),
      'public\.', '', 'g'
    ) as normalized_default,
    coalesce(col_description(a.attrelid, a.attnum), '') as column_comment,
    coalesce(pg_get_expr(d.adbin, d.adrelid, true), '') as column_default,
    a.attidentity,
    a.attgenerated
  from pg_attribute a
  join pg_type t on t.oid = a.atttypid
  join pg_namespace tn on tn.oid = t.typnamespace
  left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  where a.attrelid = to_regclass('public.profiles')
    and a.attnum > 0 and not a.attisdropped
),
profile_constraints as (
  select conname::text as object_name,
    pg_get_constraintdef(oid, true)::text as definition,
    convalidated as validated,
    condeferrable as is_deferrable,
    condeferred as initially_deferred
  from pg_constraint where conrelid = to_regclass('public.profiles')
),
expected_constraints(object_name, definition, validated, is_deferrable,
  initially_deferred) as (
  values
    ('bio_length', 'CHECK (bio IS NULL OR char_length(bio) <= 500)', true, false, false),
    ('display_name_length',
      'CHECK (char_length(display_name) >= 1 AND char_length(display_name) <= 100)',
      true, false, false),
    ('handle_format', 'CHECK (handle ~ ''^[a-zA-Z0-9_]+$''::text)',
      true, false, false),
    ('handle_length',
      'CHECK (char_length(handle) >= 3 AND char_length(handle) <= 30)',
      true, false, false),
    ('location_length',
      'CHECK (location IS NULL OR char_length(location) <= 100)',
      true, false, false),
    ('profiles_handle_key', 'UNIQUE (handle)', true, false, false),
    ('profiles_pkey', 'PRIMARY KEY (id)', true, false, false),
    ('profiles_user_id_fkey',
      'FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE',
      true, false, false)
),
profile_indexes as (
  select i.relname::text as object_name,
    pg_get_indexdef(i.oid)::text as definition,
    ix.indisunique as is_unique,
    ix.indisprimary as is_primary,
    ix.indisvalid as is_valid,
    ix.indisready as is_ready,
    coalesce(pg_get_expr(ix.indpred, ix.indrelid, true), '')::text as predicate
  from pg_index ix join pg_class i on i.oid = ix.indexrelid
  where ix.indrelid = to_regclass('public.profiles')
),
expected_indexes(object_name, definition, is_unique, is_primary,
  is_valid, is_ready, predicate) as (
  values
    ('idx_profiles_handle',
      'CREATE INDEX idx_profiles_handle ON public.profiles USING btree (handle)',
      false, false, true, true, ''),
    ('idx_profiles_user_id',
      'CREATE INDEX idx_profiles_user_id ON public.profiles USING btree (user_id)',
      false, false, true, true, ''),
    ('profiles_handle_key',
      'CREATE UNIQUE INDEX profiles_handle_key ON public.profiles USING btree (handle)',
      true, false, true, true, ''),
    ('profiles_pkey',
      'CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id)',
      true, true, true, true, ''),
    ('profiles_handle_lower_key',
      'CREATE UNIQUE INDEX profiles_handle_lower_key ON public.profiles USING btree (lower(handle))',
      true, false, true, true, ''),
    ('profiles_one_per_user_key',
      'CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)',
      true, false, true, true, '')
),
profile_triggers as (
  select tgname::text as object_name,
    pg_get_triggerdef(oid, true)::text as definition,
    tgenabled::text as enabled_code
  from pg_trigger
  where tgrelid = to_regclass('public.profiles') and not tgisinternal
),
expected_triggers(object_name, definition, enabled_code) as (
  values
    ('profiles_enforce_handle',
      'CREATE TRIGGER profiles_enforce_handle BEFORE INSERT OR UPDATE OF handle ON profiles FOR EACH ROW EXECUTE FUNCTION enforce_profile_handle()',
      'O'),
    ('tr_profiles_updated_at',
      'CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at()',
      'O')
),
profile_definition_checks as (
  select
    not exists (
      select 1 from pg_constraint
      where conrelid = to_regclass('public.profiles') and not convalidated
    ) as constraints_validated,
    coalesce((
      select conrelid = to_regclass('public.profiles')
        and confrelid = to_regclass('auth.users')
        and contype = 'f' and convalidated and confdeltype = 'c'
        and pg_get_constraintdef(oid, true)
          = 'FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE'
      from pg_constraint
      where conrelid = to_regclass('public.profiles')
        and conname = 'profiles_user_id_fkey'
    ), false) as owner_fk_exact,
    coalesce((
      select indisunique and indisvalid and indisready and indpred is null
        and pg_get_indexdef(indexrelid)
          = 'CREATE UNIQUE INDEX profiles_one_per_user_key ON public.profiles USING btree (user_id)'
      from pg_index
      where indexrelid = to_regclass('public.profiles_one_per_user_key')
    ), false) as one_owner_index_exact,
    coalesce((
      select indisunique and indisvalid and indisready and indpred is null
        and pg_get_indexdef(indexrelid)
          = 'CREATE UNIQUE INDEX profiles_handle_lower_key ON public.profiles USING btree (lower(handle))'
      from pg_index
      where indexrelid = to_regclass('public.profiles_handle_lower_key')
    ), false) as lower_handle_index_exact,
    not exists (
      select 1 from pg_index
      where indrelid = to_regclass('public.profiles')
        and (not indisvalid or not indisready)
    ) as all_indexes_ready,
    coalesce((
      select tgenabled = 'O'
        and tgfoid = to_regprocedure('public.enforce_profile_handle()')
      from pg_trigger
      where tgrelid = to_regclass('public.profiles')
        and tgname = 'profiles_enforce_handle' and not tgisinternal
    ), false) as handle_trigger_exact,
    coalesce((
      select tgenabled = 'O'
        and tgfoid = to_regprocedure('public.update_updated_at()')
      from pg_trigger
      where tgrelid = to_regclass('public.profiles')
        and tgname = 'tr_profiles_updated_at' and not tgisinternal
    ), false) as timestamp_trigger_exact
),
section_01 as (
  select
    case when current_database() <> 'postgres'
      or current_user <> 'postgres'
      or session_user <> 'postgres'
      or not coalesce((select not rolsuper and rolbypassrls
                       from pg_roles where rolname = 'postgres'), false)
      or (select count(*) from auth.instances) <> 0
      or (select count(*) from pg_roles
          where rolname in ('anon', 'authenticated', 'service_role')) <> 3
    then 'STOP' else 'GO' end as status,
    array_remove(array[
      case when current_database() <> 'postgres' then 'unexpected_database' end,
      case when current_user <> 'postgres' or session_user <> 'postgres'
        then 'not_owner_context' end,
      case when (select count(*) from auth.instances) <> 0
        then 'auth_project_instance_count_drift' end,
      case when (select count(*) from pg_roles
                 where rolname in ('anon','authenticated','service_role')) <> 3
        then 'missing_api_role' end
    ], null) as findings,
    array['project_identity_requires_owner_confirmation'::text]
      as owner_confirmation_items
),
section_02 as (
  select
    case when to_regclass('public.profiles') is not null
      and coalesce((select c.relkind = 'r'
                    and c.relowner = 'postgres'::regrole
                    and c.relrowsecurity and not c.relforcerowsecurity
                    from pg_class c
                    where c.oid = to_regclass('public.profiles')), false)
      and obj_description(to_regclass('public.profiles'), 'pg_class') is null
      and not exists (
        (select ordinal_position, column_name, type_schema, type_name, not_null,
           normalized_default, column_comment
         from actual_columns
         except
         select * from expected_columns)
        union all
        (select * from expected_columns
         except
         select ordinal_position, column_name, type_schema, type_name, not_null,
           normalized_default, column_comment
         from actual_columns)
      )
      and not exists (
        (select * from actual_profile_type_labels
         except select * from expected_profile_type_labels)
        union all
        (select * from expected_profile_type_labels
         except select * from actual_profile_type_labels)
      )
      and coalesce((select bool_and(attidentity = '' and attgenerated = '')
                    from actual_columns), false)
      and coalesce((select column_default ~ 'gen_random_uuid\(\)'
                    from actual_columns where column_name = 'id'), false)
      and coalesce((select column_default ~ '''personal''::(public\.)?profile_type'
                    from actual_columns where column_name = 'type'), false)
      and coalesce((select column_default = '''{}''::jsonb'
                    from actual_columns where column_name = 'social_links'), false)
      and coalesce((select column_default = 'false'
                    from actual_columns where column_name = 'is_creator'), false)
      and coalesce((select column_default = 'false'
                    from actual_columns where column_name = 'is_verified'), false)
      and coalesce((select column_default = 'false'
                    from actual_columns where column_name = 'is_suspended'), false)
      and coalesce((select column_default ~ 'now\(\)'
                    from actual_columns where column_name = 'created_at'), false)
      and coalesce((select column_default ~ 'now\(\)'
                    from actual_columns where column_name = 'updated_at'), false)
      and not exists (
        (select * from profile_constraints except select * from expected_constraints)
        union all
        (select * from expected_constraints except select * from profile_constraints)
      )
      and not exists (
        (select * from profile_indexes except select * from expected_indexes)
        union all
        (select * from expected_indexes except select * from profile_indexes)
      )
      and not exists (
        (select * from profile_triggers except select * from expected_triggers)
        union all
        (select * from expected_triggers except select * from profile_triggers)
      )
      and (select constraints_validated and owner_fk_exact
        and one_owner_index_exact and lower_handle_index_exact
        and all_indexes_ready and handle_trigger_exact
        and timestamp_trigger_exact
        from profile_definition_checks)
    then 'GO' else 'STOP' end as status,
    array_remove(array[
      case when to_regclass('public.profiles') is null then 'profiles_missing' end,
      case when (select count(*) from actual_columns) <> 15
        then 'profiles_column_set_drift' end,
      case when obj_description(to_regclass('public.profiles'), 'pg_class') is not null
        then 'profiles_table_comment_drift' end,
      case when exists (
        (select * from actual_profile_type_labels
         except select * from expected_profile_type_labels)
        union all
        (select * from expected_profile_type_labels
         except select * from actual_profile_type_labels)
      ) then 'profile_type_enum_drift' end,
      case when exists (
        (select * from profile_constraints except select * from expected_constraints)
        union all (select * from expected_constraints except select * from profile_constraints)
      ) then 'profiles_constraint_set_drift' end,
      case when exists (
        (select * from profile_indexes except select * from expected_indexes)
        union all (select * from expected_indexes except select * from profile_indexes)
      ) then 'profiles_index_set_drift' end,
      case when exists (
        (select * from profile_triggers except select * from expected_triggers)
        union all (select * from expected_triggers except select * from profile_triggers)
      ) then 'profiles_trigger_set_drift' end,
      case when not (select constraints_validated and owner_fk_exact
        and one_owner_index_exact and lower_handle_index_exact
        and all_indexes_ready and handle_trigger_exact
        and timestamp_trigger_exact
        from profile_definition_checks)
      then 'profiles_object_definition_drift' end,
      case when coalesce((select c.relowner <> 'postgres'::regrole
                           from pg_class c
                           where c.oid = to_regclass('public.profiles')), true)
        then 'profiles_owner_drift' end
    ], null) as findings
),
actual_table_acl as (
  select
    acl.grantor::regrole::text as grantor,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type::text,
    acl.is_grantable
  from pg_class c
  cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
  where c.oid = to_regclass('public.profiles')
),
expected_table_acl as (
  select 'postgres'::text as grantor, r.grantee, p.privilege_type,
    false as is_grantable
  from (values ('postgres'::text), ('anon'), ('authenticated'),
               ('service_role')) r(grantee)
  cross join (values ('DELETE'::text), ('INSERT'), ('MAINTAIN'),
                     ('REFERENCES'), ('SELECT'), ('TRIGGER'),
                     ('TRUNCATE'), ('UPDATE')) p(privilege_type)
  union all
  select 'postgres', 'audit_readonly', 'SELECT', false
),
section_03 as (
  select case when not exists (
    (select * from actual_table_acl except select * from expected_table_acl)
    union all
    (select * from expected_table_acl except select * from actual_table_acl)
  ) then 'GO' else 'STOP' end as status,
  case when exists (
    (select * from actual_table_acl except select * from expected_table_acl)
    union all
    (select * from expected_table_acl except select * from actual_table_acl)
  ) then array['profiles_table_acl_drift']::text[]
    else array[]::text[] end as findings
),
direct_column_acl as (
  select a.attname, acl.grantor, acl.grantee, acl.privilege_type,
    acl.is_grantable
  from pg_attribute a
  cross join lateral aclexplode(a.attacl) acl
  where a.attrelid = to_regclass('public.profiles')
    and a.attnum > 0 and not a.attisdropped
),
actual_relevant_role_memberships as (
  select granted.rolname::text as granted_role,
    member.rolname::text as member_role,
    grantor.rolname::text as grantor_role,
    m.admin_option
  from pg_auth_members m
  join pg_roles granted on granted.oid = m.roleid
  join pg_roles member on member.oid = m.member
  join pg_roles grantor on grantor.oid = m.grantor
  where granted.rolname in ('anon', 'authenticated', 'service_role')
     or member.rolname in ('anon', 'authenticated', 'service_role')
),
expected_relevant_role_memberships(
  granted_role, member_role, grantor_role, admin_option
) as (
  values
    ('anon', 'authenticator', 'supabase_admin', false),
    ('authenticated', 'authenticator', 'supabase_admin', false),
    ('service_role', 'authenticator', 'supabase_admin', false),
    ('anon', 'postgres', 'supabase_admin', true),
    ('authenticated', 'postgres', 'supabase_admin', true),
    ('service_role', 'postgres', 'supabase_admin', true)
),
api_role_inherits_privilege_role as (
  select 1
  from pg_auth_members m
  join pg_roles member on member.oid = m.member
  join pg_roles granted on granted.oid = m.roleid
  where member.rolname in ('anon', 'authenticated', 'service_role')
    and granted.rolname not in ('anon', 'authenticated', 'service_role')
),
section_04 as (
  select case when not exists (select 1 from direct_column_acl)
      and not exists (select 1 from api_role_inherits_privilege_role)
      and not exists (
        (select * from actual_relevant_role_memberships
         except select * from expected_relevant_role_memberships)
        union all
        (select * from expected_relevant_role_memberships
         except select * from actual_relevant_role_memberships)
      )
      and not exists (
        select 1 from actual_columns a
        cross join (values ('anon'), ('authenticated'), ('service_role')) r(role_name)
        where not has_table_privilege(r.role_name, 'public.profiles', 'SELECT')
           or not has_column_privilege(
             r.role_name, 'public.profiles', a.column_name, 'SELECT'
           )
      )
      and not exists (
        select 1 from actual_table_acl
        where grantee = 'PUBLIC' and privilege_type = 'SELECT'
      )
    then 'GO' else 'STOP' end as status,
    array_remove(array[
      case when exists (select 1 from direct_column_acl)
        then 'unexpected_direct_column_acl' end,
      case when exists (select 1 from api_role_inherits_privilege_role)
        then 'api_role_inherits_unexpected_role' end,
      case when exists (
        (select * from actual_relevant_role_memberships
         except select * from expected_relevant_role_memberships)
        union all
        (select * from expected_relevant_role_memberships
         except select * from actual_relevant_role_memberships)
      ) then 'api_role_membership_manifest_drift' end,
      case when exists (select 1 from actual_table_acl
                        where grantee = 'PUBLIC' and privilege_type = 'SELECT')
        then 'public_pseudo_role_has_select' end,
      case when exists (
        select 1 from actual_columns a
        cross join (values ('anon'),('authenticated'),('service_role')) r(role_name)
        where not has_column_privilege(
          r.role_name, 'public.profiles', a.column_name, 'SELECT'
        )
      ) then 'prechange_effective_column_select_drift' end
    ], null) as findings
),
relevant_default_acl as (
  select
    owner_role.rolname as object_creator,
    coalesce(n.nspname, '*ALL_SCHEMAS*') as target_schema,
    d.defaclobjtype,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type,
    acl.is_grantable,
    acl.grantor::regrole::text as grantor
  from pg_default_acl d
  join pg_roles owner_role on owner_role.oid = d.defaclrole
  left join pg_namespace n on n.oid = d.defaclnamespace
  cross join lateral aclexplode(d.defaclacl) acl
  where n.nspname = 'public' or d.defaclnamespace = 0
),
public_schema_acl as (
  select
    n.nspowner::regrole::text as schema_owner,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type,
    acl.is_grantable,
    acl.grantor::regrole::text as grantor
  from pg_namespace n
  cross join lateral aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) acl
  where n.nspname = 'public'
),
expected_default_acl as (
  select c.object_creator, 'public'::text as target_schema,
    op.defaclobjtype, g.grantee, op.privilege_type,
    false as is_grantable, c.object_creator as grantor
  from (values ('postgres'::text), ('supabase_admin')) c(object_creator)
  cross join (values ('postgres'::text), ('anon'), ('authenticated'),
                     ('service_role')) g(grantee)
  cross join (values
    ('r'::"char", 'DELETE'::text), ('r'::"char", 'INSERT'),
    ('r'::"char", 'MAINTAIN'), ('r'::"char", 'REFERENCES'),
    ('r'::"char", 'SELECT'), ('r'::"char", 'TRIGGER'),
    ('r'::"char", 'TRUNCATE'), ('r'::"char", 'UPDATE'),
    ('S'::"char", 'SELECT'), ('S'::"char", 'UPDATE'),
    ('S'::"char", 'USAGE'), ('f'::"char", 'EXECUTE')
  ) op(defaclobjtype, privilege_type)
),
expected_public_schema_acl as (
  select 'pg_database_owner'::text as schema_owner, g.grantee,
    'USAGE'::text as privilege_type, false as is_grantable,
    'pg_database_owner'::text as grantor
  from (values ('PUBLIC'::text), ('anon'), ('audit_readonly'),
               ('authenticated'), ('pg_database_owner'), ('postgres'),
               ('service_role')) g(grantee)
  union all
  select 'pg_database_owner', 'pg_database_owner', 'CREATE', false,
    'pg_database_owner'
),
section_05 as (
  select case when not exists (
      (select * from relevant_default_acl except select * from expected_default_acl)
      union all
      (select * from expected_default_acl except select * from relevant_default_acl)
    ) and not exists (
      (select * from public_schema_acl except select * from expected_public_schema_acl)
      union all
      (select * from expected_public_schema_acl except select * from public_schema_acl)
    ) then 'GO' else 'STOP' end as status,
  array_remove(array[
    case when exists (
      (select * from relevant_default_acl except select * from expected_default_acl)
      union all
      (select * from expected_default_acl except select * from relevant_default_acl)
    ) then 'default_acl_manifest_drift' end,
    case when exists (
      (select * from public_schema_acl except select * from expected_public_schema_acl)
      union all
      (select * from expected_public_schema_acl except select * from public_schema_acl)
    ) then 'public_schema_acl_manifest_drift' end
  ], null) as findings
),
actual_profile_policies as (
  select
    pol.polname::text as policy_name,
    pol.polcmd,
    pol.polpermissive,
    array(select case when role_oid = 0 then 'PUBLIC'
                      else role_oid::regrole::text end
          from unnest(pol.polroles) as r(role_oid) order by 1) as roles,
    coalesce(lower(pg_get_expr(pol.polqual, pol.polrelid, true)), '') as qual,
    coalesce(lower(pg_get_expr(pol.polwithcheck, pol.polrelid, true)), '')
      as with_check
  from pg_policy pol
  where pol.polrelid = to_regclass('public.profiles')
),
section_06 as (
  select case when (select count(*) from actual_profile_policies) = 3
      and exists (select 1 from actual_profile_policies
        where policy_name = 'Profiles are publicly readable'
          and polcmd = 'r' and polpermissive
          and roles = array['PUBLIC']::text[] and qual = 'true'
          and with_check = '')
      and exists (select 1 from actual_profile_policies
        where policy_name = 'Unbanned users insert own profiles'
          and polcmd = 'a' and polpermissive
          and roles = array['authenticated']::text[] and qual = ''
          and with_check like '%auth.uid()%user_id%'
          and with_check like '%current_user_is_banned%')
      and exists (select 1 from actual_profile_policies
        where policy_name = 'Unbanned users update own profiles'
          and polcmd = 'w' and polpermissive
          and roles = array['authenticated']::text[]
          and qual like '%auth.uid()%user_id%'
          and qual like '%current_user_is_banned%'
          and with_check like '%auth.uid()%user_id%'
          and with_check like '%current_user_is_banned%')
    then 'GO' else 'STOP' end as status,
    case when (select count(*) from actual_profile_policies) <> 3
      then array['profiles_policy_set_drift']::text[]
      else array[]::text[] end as findings
),
expected_cross_policies(table_name, policy_name) as (
  values
    ('listings', 'Active and sold listings are publicly readable'),
    ('listings', 'Unbanned owners create active listings'),
    ('listings', 'Unbanned owners update own listings'),
    ('listings', 'Unbanned owners delete own draft listings'),
    ('conversations', 'Unbanned buyers create conversations'),
    ('conversations', 'participants view visible conversations'),
    ('messages', 'Unbanned participants send messages'),
    ('messages', 'participants view messages'),
    ('vendor_events', 'Unbanned users add own RSVP'),
    ('vendor_events', 'Unbanned users remove own RSVP'),
    ('notice_posts', 'Unbanned users create own notice posts'),
    ('notice_posts', 'Unbanned users delete own notice posts'),
    ('notice_reactions', 'Unbanned users add own reactions'),
    ('notice_reactions', 'Unbanned users remove own reactions'),
    ('favorites', 'Users can read their own favorites'),
    ('favorites', 'Unbanned users manage own favorites'),
    ('follows', 'Unbanned users follow from own profile'),
    ('follows', 'Unbanned users unfollow from own profile'),
    ('event_notifications', 'Users can manage their own event notifications'),
    ('event_notifications', 'Unbanned users subscribe to event notifications'),
    ('event_notifications', 'Unbanned users unsubscribe from event notifications'),
    ('conversation_participant_state', 'Participants read own conversation state'),
    ('posts', 'Visible posts are publicly readable'),
    ('post_reactions', 'Visible reactions are publicly readable')
),
actual_cross_policies as (
  select c.relname::text as table_name, pol.polname::text as policy_name
  from pg_policy pol
  join pg_class c on c.oid = pol.polrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and pol.polrelid <> to_regclass('public.profiles')
    and lower(concat_ws(' ',
      pg_get_expr(pol.polqual, pol.polrelid, true),
      pg_get_expr(pol.polwithcheck, pol.polrelid, true)
    )) ~ '(profiles|user_id|profile_owner_is_banned|current_user_can_read_post)'
),
section_07 as (
  select case when not exists (
    (select * from actual_cross_policies except select * from expected_cross_policies)
    union all
    (select * from expected_cross_policies except select * from actual_cross_policies)
  ) then 'GO' else 'STOP' end as status,
  case when exists (
    (select * from actual_cross_policies except select * from expected_cross_policies)
    union all
    (select * from expected_cross_policies except select * from actual_cross_policies)
  ) then array['cross_table_owner_policy_set_drift']::text[]
     else array[]::text[] end as findings
),
allowed_sensitive_function_names(function_name) as (
  values
    ('append_unread_for'), ('remove_unread_for'), ('handle_new_user'),
    ('increment_view_count'), ('update_conversation_last_message'),
    ('current_user_is_banned'), ('current_user_is_admin'),
    ('current_user_is_super_admin'), ('super_admin_appoint_admin'),
    ('super_admin_remove_admin'), ('admin_ban_user'), ('admin_unban_user'),
    ('enforce_profile_handle'), ('enforce_conversation_listing_seller'),
    ('admin_unpublish_listing'), ('admin_republish_listing'),
    ('admin_delete_notice_post'), ('hide_conversation'),
    ('unhide_conversation'), ('find_and_unhide_conversation'),
    ('unhide_conversation_for_message_recipient'),
    ('enforce_listing_moderation_state'),
    ('consume_upload_intent_rate_limit'),
    ('profile_owner_is_banned'), ('current_user_can_read_post_author'),
    ('current_user_can_read_post'),
    ('current_user_can_read_post_reaction'),
    ('post_images_belong_to_profile'), ('consume_post_write_rate_limit'),
    ('enforce_post_write_invariants'), ('clear_hero_on_author_ban'),
    ('create_post'), ('update_post'), ('delete_own_post'),
    ('admin_flag_post_for_hero'), ('admin_unflag_post_for_hero'),
    ('guard_post_reaction_identity'), ('set_post_reaction'),
    ('remove_post_reaction'), ('admin_delete_post')
),
actual_sensitive_functions as (
  select p.oid, p.proname::text as function_name,
    pg_get_function_identity_arguments(p.oid) as identity_arguments,
    p.proowner, p.prosecdef, p.proconfig
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_type rt on rt.oid = p.prorettype
  join pg_namespace rtn on rtn.oid = rt.typnamespace
  where n.nspname = 'public'
    and (
      lower(p.prosrc) ~ '((^|[^a-z0-9_])user_id([^a-z0-9_]|$)|target_user_id|account_user_id)'
      or (rtn.nspname = 'public' and rt.typname in ('profiles', '_profiles'))
      or rt.typname in ('record', 'json', 'jsonb')
      or (rt.typname = 'uuid' and lower(p.prosrc) like '%auth.uid()%')
      or p.proname in ('profile_owner_is_banned',
        'current_user_can_read_post_author', 'current_user_can_read_post',
        'current_user_can_read_post_reaction')
    )
),
actual_sensitive_function_acl as (
  select
    a.function_name,
    a.identity_arguments,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type::text as privilege_type,
    acl.is_grantable,
    acl.grantor::regrole::text as grantor
  from actual_sensitive_functions a
  join pg_proc p on p.oid = a.oid
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
  where acl.grantee <> p.proowner
),
expected_sensitive_function_acl(function_name, identity_arguments, grantee,
  privilege_type, is_grantable, grantor) as (
  values
    ('handle_new_user', '', 'service_role', 'EXECUTE', false, 'postgres'),
    ('super_admin_appoint_admin', 'target_user_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('super_admin_appoint_admin', 'target_user_id uuid',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('super_admin_remove_admin', 'target_user_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('super_admin_remove_admin', 'target_user_id uuid',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('admin_ban_user', 'target_user_id uuid, reason text',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('admin_ban_user', 'target_user_id uuid, reason text',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('admin_unban_user', 'target_user_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('admin_unban_user', 'target_user_id uuid',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('append_unread_for', 'conv_id uuid, profile_id text',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('append_unread_for', 'conv_id uuid, profile_id text',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('remove_unread_for', 'conv_id uuid, profile_id text',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('remove_unread_for', 'conv_id uuid, profile_id text',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('hide_conversation', 'target_conversation_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('hide_conversation', 'target_conversation_id uuid',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('unhide_conversation', 'target_conversation_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('unhide_conversation', 'target_conversation_id uuid',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('find_and_unhide_conversation',
      'target_other_profile_id uuid, target_listing_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('find_and_unhide_conversation',
      'target_other_profile_id uuid, target_listing_id uuid',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('consume_upload_intent_rate_limit', 'target_user_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('consume_upload_intent_rate_limit', 'target_user_id uuid',
      'service_role', 'EXECUTE', false, 'postgres'),
    ('profile_owner_is_banned', 'target_profile_id uuid',
      'anon', 'EXECUTE', false, 'postgres'),
    ('profile_owner_is_banned', 'target_profile_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('current_user_can_read_post_author', 'target_profile_id uuid',
      'anon', 'EXECUTE', false, 'postgres'),
    ('current_user_can_read_post_author', 'target_profile_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('current_user_can_read_post',
      'target_profile_id uuid, target_show_in_stream boolean',
      'anon', 'EXECUTE', false, 'postgres'),
    ('current_user_can_read_post',
      'target_profile_id uuid, target_show_in_stream boolean',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('current_user_can_read_post_reaction',
      'reaction_profile_id uuid, target_post_id uuid',
      'anon', 'EXECUTE', false, 'postgres'),
    ('current_user_can_read_post_reaction',
      'reaction_profile_id uuid, target_post_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('create_post',
      'target_profile_id uuid, post_body text, post_images text[], include_in_stream boolean',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('update_post',
      'target_post_id uuid, post_body text, post_images text[], include_in_stream boolean',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('delete_own_post', 'target_post_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('set_post_reaction',
      'target_post_id uuid, target_profile_id uuid, target_reaction_code text',
      'authenticated', 'EXECUTE', false, 'postgres'),
    ('remove_post_reaction',
      'target_post_id uuid, target_profile_id uuid',
      'authenticated', 'EXECUTE', false, 'postgres')
),
required_sensitive_signatures(function_name, identity_arguments) as (
  values
    ('handle_new_user', ''),
    ('admin_ban_user', 'target_user_id uuid, reason text'),
    ('admin_unban_user', 'target_user_id uuid'),
    ('hide_conversation', 'target_conversation_id uuid'),
    ('unhide_conversation', 'target_conversation_id uuid'),
    ('find_and_unhide_conversation',
      'target_other_profile_id uuid, target_listing_id uuid'),
    ('profile_owner_is_banned', 'target_profile_id uuid'),
    ('current_user_can_read_post_author', 'target_profile_id uuid'),
    ('current_user_can_read_post',
      'target_profile_id uuid, target_show_in_stream boolean'),
    ('current_user_can_read_post_reaction',
      'reaction_profile_id uuid, target_post_id uuid'),
    ('post_images_belong_to_profile',
      'target_profile_id uuid, image_urls text[]'),
    ('create_post',
      'target_profile_id uuid, post_body text, post_images text[], include_in_stream boolean'),
    ('update_post',
      'target_post_id uuid, post_body text, post_images text[], include_in_stream boolean'),
    ('delete_own_post', 'target_post_id uuid'),
    ('set_post_reaction',
      'target_post_id uuid, target_profile_id uuid, target_reaction_code text'),
    ('remove_post_reaction',
      'target_post_id uuid, target_profile_id uuid')
),
section_08 as (
  select case when not exists (
      select 1 from actual_sensitive_functions a
      left join allowed_sensitive_function_names e
        on e.function_name = a.function_name
      where e.function_name is null
    )
    and not exists (
      select function_name from actual_sensitive_functions
      group by function_name having count(*) > 1
    )
    and not exists (
      select 1 from required_sensitive_signatures e
      left join actual_sensitive_functions a
        on a.function_name = e.function_name
       and a.identity_arguments = e.identity_arguments
      where a.oid is null
    )
    and not exists (
      select 1 from actual_sensitive_functions a
      where a.proowner <> 'postgres'::regrole
    )
    and not exists (
      (select * from actual_sensitive_function_acl
       except select * from expected_sensitive_function_acl)
      union all
      (select * from expected_sensitive_function_acl
       except select * from actual_sensitive_function_acl)
    )
    then 'GO' else 'STOP' end as status,
    array_remove(array[
      case when exists (
        select 1 from actual_sensitive_functions a
        left join allowed_sensitive_function_names e
          on e.function_name = a.function_name
        where e.function_name is null
      ) then 'unknown_sensitive_function' end,
      case when exists (
        select function_name from actual_sensitive_functions
        group by function_name having count(*) > 1
      ) then 'unexpected_sensitive_function_overload' end,
      case when exists (
        select 1 from required_sensitive_signatures e
        left join actual_sensitive_functions a
          on a.function_name = e.function_name
         and a.identity_arguments = e.identity_arguments
        where a.oid is null
      ) then 'required_sensitive_function_missing_or_signature_drift' end,
      case when exists (select 1 from actual_sensitive_functions
                        where proowner <> 'postgres'::regrole)
        then 'sensitive_function_owner_drift' end,
      case when exists (
        (select * from actual_sensitive_function_acl
         except select * from expected_sensitive_function_acl)
        union all
        (select * from expected_sensitive_function_acl
         except select * from actual_sensitive_function_acl)
      ) then 'sensitive_function_acl_drift' end
    ], null) as findings
),
dependent_views(oid, dependency_path) as (
  select distinct vc.oid, array[to_regclass('public.profiles')::oid, vc.oid]
  from pg_rewrite rw
  join pg_depend dep
    on dep.classid = 'pg_rewrite'::regclass
   and dep.objid = rw.oid
   and dep.refclassid = 'pg_class'::regclass
  join pg_class vc on vc.oid = rw.ev_class
  where dep.refobjid = to_regclass('public.profiles')
    and vc.relkind in ('v', 'm')
  union all
  select vc.oid, dv.dependency_path || vc.oid
  from dependent_views dv
  join pg_depend dep
    on dep.refclassid = 'pg_class'::regclass
   and dep.refobjid = dv.oid
   and dep.classid = 'pg_rewrite'::regclass
  join pg_rewrite rw on rw.oid = dep.objid
  join pg_class vc on vc.oid = rw.ev_class
  where vc.relkind in ('v', 'm')
    and not vc.oid = any(dv.dependency_path)
),
section_09 as (
  select case when not exists (select 1 from dependent_views)
    then 'GO' else 'STOP' end as status,
  case when exists (select 1 from dependent_views)
    then array['unexpected_profiles_dependent_view']::text[]
    else array[]::text[] end as findings
),
expected_profile_fks(constraint_name, child_table, child_column,
  delete_action_code) as (
  values
    ('conversations_buyer_profile_id_fkey', 'conversations',
      'buyer_profile_id', 'c'),
    ('conversations_seller_profile_id_fkey', 'conversations',
      'seller_profile_id', 'c'),
    ('event_notifications_profile_id_fkey', 'event_notifications',
      'profile_id', 'c'),
    ('events_created_by_fkey', 'events', 'created_by', 'a'),
    ('favorites_profile_id_fkey', 'favorites', 'profile_id', 'c'),
    ('featured_sellers_profile_id_fkey', 'featured_sellers',
      'profile_id', 'c'),
    ('follows_follower_profile_id_fkey', 'follows',
      'follower_profile_id', 'c'),
    ('follows_following_profile_id_fkey', 'follows',
      'following_profile_id', 'c'),
    ('listings_profile_id_fkey', 'listings', 'profile_id', 'c'),
    ('messages_sender_profile_id_fkey', 'messages',
      'sender_profile_id', 'c'),
    ('notice_posts_profile_id_fkey', 'notice_posts', 'profile_id', 'c'),
    ('notice_reactions_profile_id_fkey', 'notice_reactions',
      'profile_id', 'c'),
    ('vendor_events_profile_id_fkey', 'vendor_events', 'profile_id', 'c'),
    ('conversation_participant_state_profile_id_fkey',
      'conversation_participant_state', 'profile_id', 'c'),
    ('posts_profile_id_fkey', 'posts', 'profile_id', 'c'),
    ('post_reactions_profile_id_fkey', 'post_reactions',
      'profile_id', 'c')
),
actual_profile_fks as (
  select
    con.conname::text as constraint_name,
    child.relname::text as child_table,
    child_att.attname::text as child_column,
    con.confdeltype::text as delete_action_code,
    con.convalidated
  from pg_constraint con
  join pg_class child on child.oid = con.conrelid
  join pg_namespace child_ns on child_ns.oid = child.relnamespace
  join pg_attribute child_att
    on child_att.attrelid = con.conrelid
   and child_att.attnum = con.conkey[1]
  where con.contype = 'f'
    and con.confrelid = to_regclass('public.profiles')
    and child_ns.nspname = 'public'
    and cardinality(con.conkey) = 1
    and cardinality(con.confkey) = 1
),
section_10 as (
  select case when not exists (
      (select constraint_name, child_table, child_column, delete_action_code
       from actual_profile_fks
       except select * from expected_profile_fks)
      union all
      (select * from expected_profile_fks
       except select constraint_name, child_table, child_column, delete_action_code
       from actual_profile_fks)
    ) and not exists (select 1 from actual_profile_fks where not convalidated)
    then 'GO' else 'STOP' end as status,
  case when exists (
      (select constraint_name, child_table, child_column, delete_action_code
       from actual_profile_fks
       except select * from expected_profile_fks)
      union all
      (select * from expected_profile_fks
       except select constraint_name, child_table, child_column, delete_action_code
       from actual_profile_fks)
    ) then array['postgrest_profile_fk_manifest_drift']::text[]
    when exists (select 1 from actual_profile_fks where not convalidated)
      then array['unvalidated_profile_fk']::text[]
    else array[]::text[] end as findings
),
expected_realtime_tables(schema_name, table_name) as (
  values ('public', 'messages'), ('public', 'notice_posts'),
    ('public', 'notice_reactions'), ('public', 'conversations'),
    ('public', 'conversation_participant_state')
),
actual_realtime_tables as (
  select n.nspname::text as schema_name, c.relname::text as table_name
  from pg_publication_rel pr
  join pg_publication p on p.oid = pr.prpubid
  join pg_class c on c.oid = pr.prrelid
  join pg_namespace n on n.oid = c.relnamespace
  where p.pubname = 'supabase_realtime'
),
expected_publications(pubname) as (
  values ('supabase_realtime'),
    ('supabase_realtime_messages_publication')
),
actual_publications as (
  select pubname::text from pg_publication
),
expected_managed_realtime_direct_tables(schema_name, table_name) as (
  values ('realtime', 'messages')
),
actual_managed_realtime_direct_tables as (
  select n.nspname::text as schema_name, c.relname::text as table_name
  from pg_publication_rel pr
  join pg_publication p on p.oid = pr.prpubid
  join pg_class c on c.oid = pr.prrelid
  join pg_namespace n on n.oid = c.relnamespace
  where p.pubname = 'supabase_realtime_messages_publication'
),
expected_managed_realtime_expanded_tables as (
  select pt.relid
  from pg_partition_tree(to_regclass('realtime.messages')) pt
  where pt.isleaf
),
actual_managed_realtime_expanded_tables as (
  select c.oid as relid
  from pg_publication_tables pt
  join pg_namespace n on n.nspname = pt.schemaname
  join pg_class c on c.relnamespace = n.oid and c.relname = pt.tablename
  where pt.pubname = 'supabase_realtime_messages_publication'
),
section_11 as (
  select case when not exists (
      (select * from actual_publications except select * from expected_publications)
      union all
      (select * from expected_publications except select * from actual_publications)
    )
    and not exists (
      select 1 from pg_publication
      where pubname in ('supabase_realtime',
                        'supabase_realtime_messages_publication')
        and (puballtables or not pubinsert or not pubupdate or not pubdelete
             or not pubtruncate or pubviaroot)
    )
    and not exists (
      (select * from actual_realtime_tables except select * from expected_realtime_tables)
      union all
      (select * from expected_realtime_tables except select * from actual_realtime_tables)
    )
    and not exists (
      (select * from actual_managed_realtime_direct_tables
       except select * from expected_managed_realtime_direct_tables)
      union all
      (select * from expected_managed_realtime_direct_tables
       except select * from actual_managed_realtime_direct_tables)
    )
    and not exists (
      (select * from actual_managed_realtime_expanded_tables
       except select * from expected_managed_realtime_expanded_tables)
      union all
      (select * from expected_managed_realtime_expanded_tables
       except select * from actual_managed_realtime_expanded_tables)
    )
    and not exists (
      select 1 from pg_publication_rel pr
      join pg_publication p on p.oid = pr.prpubid
      where p.pubname in ('supabase_realtime',
                          'supabase_realtime_messages_publication')
        and (
          coalesce(to_jsonb(pr)->'prattrs', 'null'::jsonb) <> 'null'::jsonb
          or coalesce(to_jsonb(pr)->'prqual', 'null'::jsonb) <> 'null'::jsonb
        )
    )
    and not exists (select 1 from pg_publication_namespace)
    and coalesce((select relreplident = 'd'
                  from pg_class where oid = to_regclass('public.profiles')), false)
    and not exists (
      select 1 from pg_publication_rel pr
      where pr.prrelid = to_regclass('public.profiles')
    )
    then 'GO' else 'STOP' end as status,
  array_remove(array[
    case when not exists (select 1 from pg_publication
                          where pubname = 'supabase_realtime')
      then 'supabase_realtime_missing' end,
    case when exists (
      (select * from actual_realtime_tables except select * from expected_realtime_tables)
      union all
      (select * from expected_realtime_tables except select * from actual_realtime_tables)
    ) then 'realtime_membership_drift' end,
    case when not exists (select 1 from pg_publication
                          where pubname = 'supabase_realtime_messages_publication')
      or exists (
        (select * from actual_managed_realtime_direct_tables
         except select * from expected_managed_realtime_direct_tables)
        union all
        (select * from expected_managed_realtime_direct_tables
         except select * from actual_managed_realtime_direct_tables)
      )
      or exists (
        (select * from actual_managed_realtime_expanded_tables
         except select * from expected_managed_realtime_expanded_tables)
        union all
        (select * from expected_managed_realtime_expanded_tables
         except select * from actual_managed_realtime_expanded_tables)
      ) then 'managed_realtime_messages_publication_drift' end,
    case when exists (
      select 1 from pg_publication_rel pr
      where pr.prrelid = to_regclass('public.profiles')
    ) then 'profiles_published_to_any_publication' end,
    case when exists (
      (select * from actual_publications except select * from expected_publications)
      union all
      (select * from expected_publications except select * from actual_publications)
    ) or exists (select 1 from pg_publication where puballtables)
      or exists (select 1 from pg_publication_namespace)
      or exists (
        select 1 from pg_publication
        where pubname in ('supabase_realtime',
                          'supabase_realtime_messages_publication')
          and (not pubinsert or not pubupdate or not pubdelete
               or not pubtruncate or pubviaroot)
      ) then 'unexpected_publication_or_schema_wide_membership' end,
    case when exists (
      select 1 from pg_publication_rel pr
      join pg_publication p on p.oid = pr.prpubid
      where p.pubname in ('supabase_realtime',
                          'supabase_realtime_messages_publication')
        and (
          coalesce(to_jsonb(pr)->'prattrs', 'null'::jsonb) <> 'null'::jsonb
          or coalesce(to_jsonb(pr)->'prqual', 'null'::jsonb) <> 'null'::jsonb
        )
    ) then 'realtime_column_list_or_row_filter_drift' end,
    case when coalesce((select relreplident <> 'd'
                        from pg_class where oid = to_regclass('public.profiles')), true)
      then 'profiles_replica_identity_drift' end
  ], null) as findings
),
graphql_state as (
  select
    exists (select 1 from pg_extension where extname = 'pg_graphql') as enabled,
    to_regnamespace('graphql_public') is not null as api_schema_exists,
    (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'graphql_public' and p.proname = 'graphql')
      as entry_function_count,
    (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'graphql_public') as api_function_count,
    exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
      where n.nspname = 'graphql_public'
        and acl.grantee <> p.proowner
        and (
          case when acl.grantee = 0 then 'PUBLIC'
               else acl.grantee::regrole::text end
            not in ('PUBLIC', 'anon', 'authenticated', 'service_role')
          or acl.privilege_type <> 'EXECUTE'
          or acl.is_grantable
          or acl.grantor::regrole::text not in ('postgres', 'supabase_admin')
        )
    ) as unexpected_function_acl,
    exists (
      select 1
      from pg_namespace n
      cross join lateral aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) acl
      where n.nspname = 'graphql_public'
        and acl.grantee <> n.nspowner
        and (
          case when acl.grantee = 0 then 'PUBLIC'
               else acl.grantee::regrole::text end
            not in ('PUBLIC', 'anon', 'authenticated', 'service_role')
          or acl.privilege_type <> 'USAGE'
          or acl.is_grantable
          or acl.grantor::regrole::text not in ('postgres', 'supabase_admin')
        )
    ) as unexpected_schema_acl
),
section_12 as (
  select case when not enabled then 'GO' else 'STOP' end as status,
    array_remove(array[
      case when enabled then 'unexpected_pg_graphql_enablement' end,
      case when enabled and not api_schema_exists
        then 'pg_graphql_enabled_but_api_schema_missing' end,
      case when enabled and entry_function_count <> 1
        then 'pg_graphql_entry_function_missing_or_overloaded' end,
      case when enabled and api_function_count <> 1
        then 'unexpected_graphql_public_function' end,
      case when enabled and unexpected_function_acl
        then 'unexpected_graphql_function_acl' end,
      case when enabled and unexpected_schema_acl
        then 'unexpected_graphql_schema_acl' end
    ], null) as findings
  from graphql_state
),
aggregate_state as (
  select
    count(*)::bigint as profile_count,
    count(*) filter (where user_id is null)::bigint as null_owner_count,
    (select count(*) from public.profiles px
     left join auth.users au on au.id = px.user_id
     where au.id is null)::bigint as orphan_auth_owner_count,
    (select count(*) from public.profiles px
     left join public.users pu on pu.id = px.user_id
     where pu.id is null)::bigint as missing_public_user_owner_count,
    (select count(*) from (
      select user_id from public.profiles group by user_id having count(*) > 1
    ) d)::bigint as duplicate_owner_group_count,
    count(*) filter (
      where nullif(btrim(handle), '') is not null
        and nullif(btrim(display_name), '') is not null
    )::bigint as public_response_fixture_count,
    coalesce((select rolbypassrls or rolsuper
              from pg_roles where rolname = current_user), false)
      as aggregate_visibility_complete
  from public.profiles
),
section_13 as (
  select case
    when null_owner_count <> 0 or orphan_auth_owner_count <> 0
      or missing_public_user_owner_count <> 0
      or duplicate_owner_group_count <> 0 then 'STOP'
    when not aggregate_visibility_complete
      or public_response_fixture_count = 0 then 'UNPROVEN'
    else 'GO' end as status,
    array_remove(array[
      case when null_owner_count <> 0 then 'null_profile_owner_rows' end,
      case when orphan_auth_owner_count <> 0
        then 'orphan_auth_profile_owners' end,
      case when missing_public_user_owner_count <> 0
        then 'missing_public_user_for_profile_owner' end,
      case when duplicate_owner_group_count <> 0
        then 'duplicate_profile_owner_groups' end,
      case when not aggregate_visibility_complete
        then 'aggregate_visibility_completeness' end,
      case when public_response_fixture_count = 0
        then 'public_profile_response_fixture' end
    ], null) as findings
  from aggregate_state
),
app_manifest(ordinal, canonical_entry) as (
  values
    (1, 'app/[handle]/page.tsx:191	direct_read	owner_browser	change	select id,handle; filter user_id'),
    (2, 'app/[handle]/page.tsx:239	direct_read	public_browser	change	select *; filter handle'),
    (3, 'app/api/auth/signup/route.ts:49	direct_read	service_role	retain	select id; filter handle'),
    (4, 'app/festivals/[slug]/page.tsx:717	direct_read	owner_browser	change	select id; filter user_id'),
    (5, 'app/listing/[id]/edit/page.tsx:180	direct_read	owner_browser	change	select id,handle; filter user_id'),
    (6, 'app/listing/[id]/page.tsx:135	direct_read	owner_browser	change	select id; filter user_id'),
    (7, 'app/listing/[id]/page.tsx:169	direct_read	public_browser	change	select *; filter profile id'),
    (8, 'app/listing/[id]/page.tsx:186	direct_read	handle_lookup	retain	select id; filter handle'),
    (9, 'app/listings/new/page.tsx:249	direct_read	owner_browser	change	select id; filter user_id'),
    (10, 'app/messages/page.tsx:13	direct_read	owner_browser	change	select handle; filter user_id'),
    (11, 'app/page.tsx:64	direct_read	public_browser	change	select *; order created_at; limit 6'),
    (12, 'app/profile/edit/page.tsx:129	direct_read	owner_browser	change	select *; filter user_id'),
    (13, 'app/signup/page.tsx:156	direct_read	handle_lookup	retain	select id; filter handle'),
    (14, 'components/AuthModal.tsx:243	direct_read	handle_lookup	retain	select id; filter handle'),
    (15, 'components/EditProfileModal.tsx:91	direct_read	handle_lookup	retain	select id; filter handle'),
    (16, 'components/layout/Header.tsx:89	direct_read	owner_browser	change	select id,handle,display_name,avatar_url; filter user_id; limit 1'),
    (17, 'lib/posts/use-reaction-viewer.ts:28	direct_read	owner_browser	change	select id; filter user_id'),
    (18, 'lib/uploads/authorization.ts:20	direct_read	auth_server	change	select id,user_id; filter profile id'),
    (19, 'lib/uploads/trusted-upload-server.ts:153	direct_read	service_role	retain	select id,user_id; filter profile id'),
    (20, 'scripts/upload-and-create.js:14	direct_read	service_role_cli	retain	select id,user_id; filter handle'),
    (21, 'scripts/upload-r2.js:8	direct_read	service_role_cli	retain	select id,user_id; filter handle'),
    (22, 'app/[handle]/page.tsx:249	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (23, 'app/apparel/page.tsx:136	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (24, 'app/browse/page.tsx:152	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (25, 'app/festivals/[slug]/page.tsx:162	nested_read	public_browser	change	vendor_events profiles(*)'),
    (26, 'app/festivals/[slug]/page.tsx:306	nested_read	public_browser	retain	notice_posts profiles(handle,display_name,avatar_url)'),
    (27, 'app/jewellery/page.tsx:126	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (28, 'app/listing/[id]/page.tsx:171	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (29, 'app/music/page.tsx:125	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (30, 'app/page.tsx:40	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (31, 'app/page.tsx:48	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (32, 'app/page.tsx:56	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (33, 'components/MessagesInbox.tsx:72	nested_read	owner_browser	retain	conversations buyer/seller profiles(id,handle,display_name,avatar_url)'),
    (34, 'components/StandardCategoryPage.tsx:150	nested_read	public_browser	retain	listings profiles(handle,display_name,avatar_url)'),
    (35, 'components/StreamPageClient.tsx:85	nested_read	public_browser	retain	posts profiles(id,handle,display_name,avatar_url)'),
    (36, 'lib/uploads/references-server.ts:44	generic_read	service_role	retain	select id,avatar_url,header_url'),
    (37, 'scripts/cleanup-promoted-pending.js:85	generic_read	service_role_cli	retain	select id,avatar_url,header_url'),
    (38, 'scripts/report-r2-orphans.js:65	generic_read	service_role_cli	retain	select id,avatar_url,header_url'),
    (39, 'app/api/auth/signup/route.ts:125	mutation	service_role	retain	update; filter user_id; return id'),
    (40, 'app/profile/edit/page.tsx:164	mutation	owner_browser	retain	update; filter profile id; no return'),
    (41, 'components/EditProfileModal.tsx:140	mutation	owner_browser	retain	update; filter profile id; return id')
),
app_source_blobs(source_path, git_blob_sha1) as (
  values
    ('app/[handle]/page.tsx', 'e7c7e16541a7d4ce04412113a0e941f1e4bec400'),
    ('app/api/auth/signup/route.ts', 'adf6eeaa40a2c582ddc058fdb333ceff1e9a90bb'),
    ('app/apparel/page.tsx', '3f115314ab11969688a1661c502897e1863f214c'),
    ('app/browse/page.tsx', 'b3ccf978b8ad8efcddba0ea81a2adbd33f124a29'),
    ('app/festivals/[slug]/page.tsx', '78ba1d749e471cdec4a59b6fef096e04fdba31a3'),
    ('app/jewellery/page.tsx', '6b88850a4272ac39713cee8a5cc03c97d090a5a3'),
    ('app/listing/[id]/edit/page.tsx', 'cf01e9b5a72b772128d4e79517ba1c4ee8db6f6a'),
    ('app/listing/[id]/page.tsx', 'd2d0e6e25281e0e1ae6de840a5879994d0c90d73'),
    ('app/listings/new/page.tsx', '4b6e42be96e79d4f14455df2562e49dbbdbe8231'),
    ('app/messages/page.tsx', '2c8ee2c6ce7d60ad41797d4e403be722d70a061f'),
    ('app/music/page.tsx', 'cbd70024b55709c7312ac329d89a7aeaa93591ad'),
    ('app/page.tsx', '47a40d627e9be99ff4757740767125880c922a0d'),
    ('app/profile/edit/page.tsx', '98a1e8ff191f13a4d3448e8f9b984fea4701e6be'),
    ('app/signup/page.tsx', 'e60f66b4458029e8c782dd65e9ef1a3b4416baf8'),
    ('components/AuthModal.tsx', '31bbcec54d0335fc748c3b71270cce17caef1d34'),
    ('components/EditProfileModal.tsx', 'fcebe78a3c93828e13d16b06cb450f1e833e45b6'),
    ('components/MessagesInbox.tsx', 'dd14c00505e257abfab220fed654261548dc90bf'),
    ('components/StandardCategoryPage.tsx', '15e9ac055b1f8df681f9508e352781b76d13f725'),
    ('components/StreamPageClient.tsx', 'f02f331476af7ae0f25003d488f744bf0f055a8a'),
    ('components/layout/Header.tsx', 'badefeca2448b5926ab9ad2a80f5c811814c28cf'),
    ('lib/posts/use-reaction-viewer.ts', '9ad83d3f0e755ffbfbce09d998ddcab9b12c0f92'),
    ('lib/uploads/authorization.ts', 'ad70d9b1c8dd9a35aa9be43dd99afa7d29cd8d26'),
    ('lib/uploads/references-server.ts', 'c196e4a4f71ef763f70d817e0bca610bf14405aa'),
    ('lib/uploads/trusted-upload-server.ts', '3508ca9bfcb2ef9bf88053a0f998978e4bfaf762'),
    ('scripts/cleanup-promoted-pending.js', '0dd9d44e3a625c2c81e8f85710c016e7b6a0f6b6'),
    ('scripts/report-r2-orphans.js', '5dd3d98a8c032524fd2bfdea9dd0dddb4c4afaf5'),
    ('scripts/upload-and-create.js', '83179e915655340637e51856b76f114c612d7d2d'),
    ('scripts/upload-r2.js', 'bda03e82b7c4644eb6b407db825c7515031d5e8e')
),
app_source_blob_state as (
  select count(*) as source_file_count,
    md5(string_agg(source_path || E'\t' || git_blob_sha1,
      E'\n' order by source_path collate "C") || E'\n') as computed_md5
  from app_source_blobs
),
app_manifest_state as (
  select
    count(*) as entry_count,
    count(*) filter (where canonical_entry like E'%\tdirect_read\t%')
      as direct_read_count,
    count(*) filter (where canonical_entry like E'%\tnested_read\t%')
      as nested_read_count,
    count(*) filter (where canonical_entry like E'%\tgeneric_read\t%')
      as generic_read_count,
    count(*) filter (where canonical_entry like E'%\tmutation\t%')
      as mutation_count,
    md5(string_agg(canonical_entry, E'\n' order by ordinal) || E'\n')
      as computed_md5
  from app_manifest
),
section_14 as (
  select case when entry_count = 41 and direct_read_count = 21
      and nested_read_count = 14 and generic_read_count = 3
      and mutation_count = 3
      and m.computed_md5 = 'dcaea87c018d282ed4877edc1a9ea2b5'
      and source_file_count = 28
      and b.computed_md5 = '20ab83d8d6bbdbe02bbf0efecf19286d'
    then 'GO' else 'STOP' end as status,
    case when entry_count <> 41 or direct_read_count <> 21
      or nested_read_count <> 14 or generic_read_count <> 3
      or mutation_count <> 3
      or m.computed_md5 <> 'dcaea87c018d282ed4877edc1a9ea2b5'
      or source_file_count <> 28
      or b.computed_md5 <> '20ab83d8d6bbdbe02bbf0efecf19286d'
      then array['embedded_app_query_or_source_blob_manifest_drift']::text[]
      else array[]::text[] end as findings
  from app_manifest_state m
  cross join app_source_blob_state b
),
all_sections as (
  select 1 as section_number, status, findings from section_01 union all
  select 2, status, findings from section_02 union all
  select 3, status, findings from section_03 union all
  select 4, status, findings from section_04 union all
  select 5, status, findings from section_05 union all
  select 6, status, findings from section_06 union all
  select 7, status, findings from section_07 union all
  select 8, status, findings from section_08 union all
  select 9, status, findings from section_09 union all
  select 10, status, findings from section_10 union all
  select 11, status, findings from section_11 union all
  select 12, status, findings from section_12 union all
  select 13, status, findings from section_13 union all
  select 14, status, findings from section_14
),
final_status as (
  select case
    when (select count(*) from all_sections) <> 14 then 'STOP'
    when bool_or(status = 'STOP') then 'STOP'
    when bool_or(status = 'UNPROVEN') then 'UNPROVEN'
    else 'GO' end as overall_status,
    coalesce(array_agg(
      'S' || lpad(section_number::text, 2, '0') || ':' || finding
      order by section_number, finding
    ) filter (where status = 'STOP' and finding is not null),
      array[]::text[]) as stop_findings,
    coalesce(array_agg(
      'S' || lpad(section_number::text, 2, '0') || ':' || finding
      order by section_number, finding
    ) filter (where status = 'UNPROVEN' and finding is not null),
      array[]::text[]) as unproven_findings,
    coalesce(array_agg(finding order by finding)
      filter (where status = 'UNPROVEN'
        and finding in ('public_profile_response_fixture')),
      array[]::text[]) as unavailable_fixtures
  from all_sections
  left join lateral unnest(
    case when status <> 'GO' and cardinality(findings) = 0
      then array['unnamed_baseline_drift']::text[]
      else findings end
  ) f(finding) on true
)
select
  fs.overall_status,
  s01.status as section_01_identity_status,
  s02.status as section_02_profiles_shape_status,
  s03.status as section_03_table_acl_status,
  s04.status as section_04_effective_privileges_status,
  s05.status as section_05_default_privileges_status,
  s06.status as section_06_profiles_policies_status,
  s07.status as section_07_cross_table_policies_status,
  s08.status as section_08_functions_status,
  s09.status as section_09_dependent_views_status,
  s10.status as section_10_postgrest_relationships_status,
  s11.status as section_11_realtime_status,
  s12.status as section_12_graphql_status,
  s13.status as section_13_safe_aggregates_status,
  s14.status as section_14_app_manifest_status,
  fs.stop_findings,
  fs.unproven_findings,
  fs.unavailable_fixtures,
  s01.owner_confirmation_items,
  '83d35c728031ce2836246d9677aead37ad93fde0'::text
    as app_source_revision,
  '42a8f28024eb0ec3eb15814fe9327aabd80a8bd693d88d87fe3694bbb3dee2e6'::text
    as app_manifest_sha256,
  'dcaea87c018d282ed4877edc1a9ea2b5'::text as app_manifest_md5,
  '8dff6d43a19a896985d60e12585b7e2b00f0c68b667209e9b0eeceaf514f8aad'::text
    as app_source_blob_manifest_sha256,
  '20ab83d8d6bbdbe02bbf0efecf19286d'::text
    as app_source_blob_manifest_md5
from final_status fs
cross join section_01 s01
cross join section_02 s02
cross join section_03 s03
cross join section_04 s04
cross join section_05 s05
cross join section_06 s06
cross join section_07 s07
cross join section_08 s08
cross join section_09 s09
cross join section_10 s10
cross join section_11 s11
cross join section_12 s12
cross join section_13 s13
cross join section_14 s14;
