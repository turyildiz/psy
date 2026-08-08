-- MP-1 Package A owner-review extract (S02-S05 only).
-- One read-only statement; every output row maps 1:1 to a Package A detail row.
-- The common export shape is three text columns. detail_row preserves every
-- original named detail field and value as JSON text.

with recursive
detail_02_profiles_columns as (
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
),
detail_02_profile_type_enum as (
  select
    'DETAIL_02_PROFILE_TYPE_ENUM'::text as result_set,
    e.enumsortorder,
    e.enumlabel,
    md5(concat_ws('|', e.enumsortorder, e.enumlabel)) as enum_value_fingerprint
  from pg_enum e
  where e.enumtypid = to_regtype('public.profile_type')
),
detail_02_profiles_objects as (
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
),
detail_03_profiles_table_acl as (
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
),
detail_04_profiles_direct_column_acl as (
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
),
principals(principal_name, role_exists) as (
  values
    ('PUBLIC'::text, true),
    ('anon', to_regrole('anon') is not null),
    ('authenticated', to_regrole('authenticated') is not null),
    ('service_role', to_regrole('service_role') is not null)
),
public_table_select as (
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
),
detail_04_effective_privileges as (
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
),
detail_04_relevant_role_memberships as (
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
),
membership_paths(
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
),
detail_04_role_membership_closure as (
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
),
detail_05_default_privileges as (
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
),
detail_05_public_schema_acl as (
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
  cross join lateral aclexplode(
    coalesce(n.nspacl, acldefault('n', n.nspowner))
  ) acl
  where n.nspname = 'public'
),
owner_review_rows(section_order, detail_order, section_label, result_set,
  detail_row) as (
  select 2, 1, 'S02'::text, d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_02_profiles_columns d
  union all
  select 2, 2, 'S02', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_02_profile_type_enum d
  union all
  select 2, 3, 'S02', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_02_profiles_objects d
  union all
  select 3, 1, 'S03', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_03_profiles_table_acl d
  union all
  select 4, 1, 'S04', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_04_profiles_direct_column_acl d
  union all
  select 4, 2, 'S04', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_04_effective_privileges d
  union all
  select 4, 3, 'S04', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_04_relevant_role_memberships d
  union all
  select 4, 4, 'S04', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_04_role_membership_closure d
  union all
  select 5, 1, 'S05', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_05_default_privileges d
  union all
  select 5, 2, 'S05', d.result_set,
    (to_jsonb(d) - 'result_set')::text
  from detail_05_public_schema_acl d
)
select
  section_label::text,
  result_set::text,
  detail_row::text
from owner_review_rows
order by section_order, detail_order, detail_row;
