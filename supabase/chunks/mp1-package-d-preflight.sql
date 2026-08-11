-- psy.market MP-1 Package D: database-enforced public-profile privacy
-- PREFLIGHT — READ ONLY; OWNER-RUN IN SUPABASE SQL EDITOR.
--
-- Purpose
-- -------
-- Remove table-level SELECT from anon/authenticated and grant those roles only
-- the 12-column PUBLIC_PROFILE_SELECT contract. RLS is deliberately unchanged:
-- this package changes which profile columns client roles may select, not which
-- profile rows they may see.
--
-- Investigation baseline (repository revision 282b011; 2026-08-11)
-- ----------------------------------------------------------------
-- PUBLIC_PROFILE_SELECT / PUBLIC_PROFILE_EMBED in lib/db.ts contain exactly:
-- id, type, handle, display_name, bio, avatar_url, header_url, location,
-- social_links, is_creator, is_verified, created_at.
--
-- Every current executable profile read was inspected:
-- * direct public/client reads:
--   app/[handle]/page.tsx (12-column profile by handle);
--   app/listing/[id]/page.tsx (12-column seller by id; id by handle);
--   app/page.tsx (12-column seller list);
--   app/signup/page.tsx, components/AuthModal.tsx and
--   components/EditProfileModal.tsx (id-only handle availability);
--   components/EditProfileModal.tsx (id-only UPDATE return).
-- * trusted service-role reads, intentionally unaffected by this package:
--   app/api/auth/signup/route.ts (id lookup; user_id-filtered UPDATE returning id),
--   lib/uploads/trusted-upload-server.ts, scripts/upload-and-create.js and
--   scripts/upload-r2.js (id/user_id owner checks), plus the safe media-reference
--   scans in lib/uploads/references-server.ts,
--   scripts/cleanup-promoted-pending.js and scripts/report-r2-orphans.js
--   (id/avatar_url/header_url only).
-- * explicit profile embeds:
--   listings -> profiles in app/[handle]/page.tsx, app/apparel/page.tsx,
--   app/browse/page.tsx, app/jewellery/page.tsx,
--   app/listing/[id]/page.tsx, app/music/page.tsx, app/page.tsx (three queries)
--   and components/StandardCategoryPage.tsx;
--   vendor_events -> profiles in app/festivals/[slug]/page.tsx;
--   notice_posts -> profiles in app/festivals/[slug]/page.tsx;
--   conversations -> buyer/seller profiles in components/MessagesInbox.tsx;
--   posts -> profiles in components/StreamPageClient.tsx.
-- All embeds request only allowed public columns. Their six exact FK bindings are
-- guarded below and exercised by VERIFY.
--
-- Owner/private reads use the existing SECURITY DEFINER contracts:
-- * get_my_profiles() is called through lib/db.ts by app/messages/page.tsx,
--   components/layout/Header.tsx, app/listings/new/page.tsx,
--   app/profile/edit/page.tsx, app/listing/[id]/page.tsx,
--   app/listing/[id]/edit/page.tsx, lib/posts/use-reaction-viewer.ts,
--   app/festivals/[slug]/page.tsx and app/[handle]/page.tsx;
-- * current_user_owns_profile(uuid) is called through lib/db.ts by
--   lib/uploads/authorization.ts;
-- * admin_get_profile_account(uuid) has the server-only wrapper
--   lib/db.private.server.ts (and no browser import/caller).
-- They are postgres-owned, fixed-search-path definers with exact bodies/ACLs and
-- therefore retain owner-column access after client column grants are narrowed.
-- APPLY rechecks this complete dependency.
--
-- tests/profile-contract.test.ts scans tracked/untracked TS/TSX/JS and proves no
-- direct profiles select=* or nested profiles(*) exists and only the four trusted
-- service-role files that need owner linkage read/filter profiles.user_id. The
-- focused suite passed 6/6 on 2026-08-11 before this package was authored. Its
-- regex guard is not a substitute for a fresh inventory: future generic table
-- variables or multiline FK-qualified/aliased embeds must be reviewed explicitly.
--
-- PostgREST caveat: after APPLY, any ad-hoc profiles select=* (including an
-- embedded profiles(*)) fails because the expansion includes denied columns.
-- The application never relies on that shape. This is an intentional compatibility
-- risk for unreviewed/ad-hoc callers; they must use explicit allowed columns.
--
-- Exact approved pre-cutover ACL captured read-only from live on 2026-08-11:
-- * grantor postgres, grant option false;
-- * postgres, anon, authenticated, service_role: every table privilege available
--   on the target PostgreSQL major (including MAINTAIN on PostgreSQL 17);
-- * audit_readonly: SELECT only;
-- * no PUBLIC table ACL and no direct column ACL rows.
-- APPLY preserves every non-SELECT privilege exactly. Package D deliberately does
-- not normalize the existing TRUNCATE/TRIGGER/REFERENCES/MAINTAIN grants: the
-- approved scope is a column-read cutover only, and changing unrelated privileges
-- would make this package broader than its reviewed goal. ROLLBACK restores this
-- exact manifest rather than granting an assumed default.
--
-- PREFLIGHT also refuses unless every VERIFY fixture class is present: ordinary,
-- unrelated, active-admin and visible-conversation callers plus at least one
-- currently visible listing, RSVP, Notice, post and conversation relationship.
-- This prevents a clean ACL apply followed by a fixture-only VERIFY STOP.

with
safe_columns(ordinal_position, column_name, data_type, is_not_null) as (
  values
    (1, 'id'::text, 'uuid'::text, true),
    (2, 'user_id', 'uuid', true),
    (3, 'type', 'profile_type', true),
    (4, 'handle', 'text', true),
    (5, 'display_name', 'text', true),
    (6, 'bio', 'text', false),
    (7, 'avatar_url', 'text', false),
    (8, 'header_url', 'text', false),
    (9, 'location', 'text', false),
    (10, 'social_links', 'jsonb', false),
    (11, 'is_creator', 'boolean', true),
    (12, 'is_verified', 'boolean', true),
    (13, 'is_suspended', 'boolean', true),
    (14, 'created_at', 'timestamp with time zone', true),
    (15, 'updated_at', 'timestamp with time zone', true)
),
actual_columns as (
  select a.attnum::integer, a.attname::text,
    pg_catalog.format_type(a.atttypid, a.atttypmod)::text,
    a.attnotnull
  from pg_catalog.pg_attribute a
  where a.attrelid = pg_catalog.to_regclass('public.profiles')
    and a.attnum > 0 and not a.attisdropped
),
available_table_privileges(privilege_type) as (
  values ('DELETE'::text), ('INSERT'), ('REFERENCES'), ('SELECT'),
    ('TRIGGER'), ('TRUNCATE'), ('UPDATE')
  union all
  select 'MAINTAIN'
  where pg_catalog.current_setting('server_version_num')::integer >= 170000
),
expected_table_acl(grantor, grantee, privilege_type, is_grantable) as (
  select 'postgres'::text, r.grantee, p.privilege_type, false
  from (values ('postgres'::text), ('anon'), ('authenticated'),
               ('service_role')) r(grantee)
  cross join available_table_privileges p
  union all
  select 'postgres', 'audit_readonly', 'SELECT', false
),
actual_table_acl as (
  select acl.grantor::regrole::text as grantor,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type::text, acl.is_grantable
  from pg_catalog.pg_class c
  cross join lateral pg_catalog.aclexplode(
    coalesce(c.relacl, pg_catalog.acldefault('r', c.relowner))
  ) acl
  where c.oid = pg_catalog.to_regclass('public.profiles')
),
actual_column_acl as (
  select a.attname::text as column_name,
    acl.grantor::regrole::text as grantor,
    case when acl.grantee = 0 then 'PUBLIC'
         else acl.grantee::regrole::text end as grantee,
    acl.privilege_type::text, acl.is_grantable
  from pg_catalog.pg_attribute a
  cross join lateral pg_catalog.aclexplode(a.attacl) acl
  where a.attrelid = pg_catalog.to_regclass('public.profiles')
    and a.attnum > 0 and not a.attisdropped and a.attacl is not null
),
expected_helper_acl(function_name, grantee, privilege_type, is_grantable, grantor) as (
  values
    ('get_my_profiles'::text, 'postgres'::text, 'EXECUTE'::text, false, 'postgres'::text),
    ('get_my_profiles', 'authenticated', 'EXECUTE', false, 'postgres'),
    ('current_user_owns_profile', 'postgres', 'EXECUTE', false, 'postgres'),
    ('current_user_owns_profile', 'authenticated', 'EXECUTE', false, 'postgres'),
    ('admin_get_profile_account', 'postgres', 'EXECUTE', false, 'postgres'),
    ('admin_get_profile_account', 'authenticated', 'EXECUTE', false, 'postgres')
),
actual_helper_acl as (
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
),
helper_shape as (
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
    ) as ok
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  join pg_catalog.pg_language l on l.oid = p.prolang
  where n.nspname = 'public'
    and p.proname in (
      'get_my_profiles',
      'current_user_owns_profile',
      'admin_get_profile_account'
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
checks(check_name, ok) as (
  values
    ('owner_sql_editor_context',
      current_user = 'postgres'
      and session_user = 'postgres'),
    ('profiles_relation_shape', exists (
      select 1 from pg_catalog.pg_class c
      where c.oid = pg_catalog.to_regclass('public.profiles')
        and c.relkind = 'r'
        and c.relowner = 'postgres'::regrole
        and c.relrowsecurity and not c.relforcerowsecurity
    )),
    ('profiles_columns_exact', not exists (
      (select * from actual_columns except select * from safe_columns)
      union all
      (select * from safe_columns except select * from actual_columns)
    )),
    ('profiles_select_policy_exact', (
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
    )),
    ('roles_and_inheritance_safe',
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
        where m.member in ('anon'::regrole, 'authenticated'::regrole)
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
      )
    ),
    ('profiles_table_acl_exact_old', not exists (
      (select * from actual_table_acl except select * from expected_table_acl)
      union all
      (select * from expected_table_acl except select * from actual_table_acl)
    )),
    ('profiles_column_acl_empty_old', not exists (
      select 1 from actual_column_acl
    )),
    ('client_broad_select_present',
      pg_catalog.has_table_privilege('anon', 'public.profiles', 'SELECT')
      and pg_catalog.has_table_privilege(
        'authenticated', 'public.profiles', 'SELECT'
      )
      and pg_catalog.has_column_privilege(
        'anon', 'public.profiles', 'user_id', 'SELECT'
      )
      and pg_catalog.has_column_privilege(
        'authenticated', 'public.profiles', 'user_id', 'SELECT'
      )
    ),
    ('private_helpers_exact', (select ok from helper_shape)
      and not exists (
        (select * from actual_helper_acl except select * from expected_helper_acl)
        union all
        (select * from expected_helper_acl except select * from actual_helper_acl)
      )
      and not exists (
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
            or pg_catalog.has_function_privilege(
              'service_role', p.oid, 'EXECUTE'
            )
          )
      )
    ),
    ('embed_foreign_keys_exact', not exists (
      (select * from actual_embed_fks except select * from expected_embed_fks)
      union all
      (select * from expected_embed_fks except select * from actual_embed_fks)
    )),
    ('profile_fixture_available', exists (
      select 1 from public.profiles
    )),
    ('verification_fixtures_available',
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
    )
),
summary as (
  select pg_catalog.bool_and(ok) as all_ok,
    coalesce(
      pg_catalog.array_agg(check_name order by check_name)
        filter (where not ok),
      array[]::text[]
    ) as findings
  from checks
),
table_acl_json as (
  select coalesce(
    pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'grantor', grantor,
      'grantee', grantee,
      'privilege', privilege_type,
      'grantable', is_grantable
    ) order by grantee, privilege_type),
    '[]'::jsonb
  ) as value
  from actual_table_acl
),
column_acl_json as (
  select coalesce(
    pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'column', column_name,
      'grantor', grantor,
      'grantee', grantee,
      'privilege', privilege_type,
      'grantable', is_grantable
    ) order by column_name, grantee, privilege_type),
    '[]'::jsonb
  ) as value
  from actual_column_acl
)
select
  'MP1_PACKAGE_D_PROFILE_PRIVACY_PREFLIGHT'::text as package,
  case when summary.all_ok then 'GO' else 'STOP' end::text as status,
  summary.findings,
  table_acl_json.value as complete_profiles_table_acl,
  column_acl_json.value as complete_profiles_column_acl,
  array[
    'id', 'type', 'handle', 'display_name', 'bio', 'avatar_url',
    'header_url', 'location', 'social_links', 'is_creator',
    'is_verified', 'created_at'
  ]::text[] as post_cutover_public_columns,
  array['user_id', 'is_suspended', 'updated_at']::text[]
    as post_cutover_denied_columns,
  'Ad-hoc PostgREST profiles select=* / profiles(*) callers will fail; use explicit allowed columns.'::text
    as residual_compatibility_risk
from summary
cross join table_acl_json
cross join column_acl_json;
