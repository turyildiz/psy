-- psy.market MP-1 Package B
-- GUARDED ROLLBACK — OWNER-RUN ONLY; NOT EXECUTED BY THE REPOSITORY AGENT.
--
-- This removes only the three additive Package B functions. DROP defaults to
-- RESTRICT so any later Package C/MP-4 dependency blocks rollback rather than
-- cascading into an existing object.

begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $preconditions$
begin
  if current_database() <> 'postgres'
     or current_user <> 'postgres'
     or session_user <> 'postgres' then
    raise exception 'Package B rollback requires project-owner context';
  end if;

  if (select count(*)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in (
          'get_my_profiles',
          'current_user_owns_profile',
          'admin_get_profile_account'
        )) <> 3
     or to_regprocedure('public.get_my_profiles()') is null
     or to_regprocedure('public.current_user_owns_profile(uuid)') is null
     or to_regprocedure('public.admin_get_profile_account(uuid)') is null then
    raise exception 'Package B rollback precondition failed: partial or overloaded function set';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname = 'public'
      and p.proname in (
        'get_my_profiles',
        'current_user_owns_profile',
        'admin_get_profile_account'
      )
      and (
        p.proowner <> 'postgres'::regrole
        or not p.prosecdef
        or p.provolatile <> 's'
        or p.proparallel <> 'u'
        or p.prokind <> 'f'
        or p.proconfig not in (array['search_path=""'], array['search_path='])
        or p.proisstrict
        or p.proleakproof
        or p.proretset <> (p.proname in (
          'get_my_profiles', 'admin_get_profile_account'
        ))
        or p.prorettype <> case p.proname
          when 'current_user_owns_profile' then 'boolean'::regtype
          else 'record'::regtype
        end
        or p.proargnames is distinct from case p.proname
          when 'get_my_profiles' then array[
            'id', 'type', 'handle', 'display_name', 'bio', 'avatar_url',
            'header_url', 'location', 'social_links', 'is_creator',
            'is_verified', 'created_at', 'is_suspended', 'updated_at'
          ]
          when 'current_user_owns_profile' then array['target_profile_id']
          when 'admin_get_profile_account' then array[
            'target_profile_id', 'account_user_id', 'profile_id', 'handle',
            'display_name', 'type', 'is_suspended', 'created_at'
          ]
        end
        or p.proargmodes is distinct from case p.proname
          when 'get_my_profiles' then array[
            't'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char"
          ]
          when 'current_user_owns_profile' then null::"char"[]
          when 'admin_get_profile_account' then array[
            'i'::"char", 't'::"char", 't'::"char", 't'::"char",
            't'::"char", 't'::"char", 't'::"char", 't'::"char"
          ]
        end
        or p.proallargtypes is distinct from case p.proname
          when 'get_my_profiles' then array[
            'uuid'::regtype::oid, 'public.profile_type'::regtype::oid,
            'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
            'text'::regtype::oid, 'text'::regtype::oid, 'text'::regtype::oid,
            'jsonb'::regtype::oid, 'boolean'::regtype::oid,
            'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid,
            'boolean'::regtype::oid, 'timestamp with time zone'::regtype::oid
          ]
          when 'current_user_owns_profile' then null::oid[]
          when 'admin_get_profile_account' then array[
            'uuid'::regtype::oid, 'uuid'::regtype::oid,
            'uuid'::regtype::oid, 'text'::regtype::oid,
            'text'::regtype::oid, 'public.profile_type'::regtype::oid,
            'boolean'::regtype::oid,
            'timestamp with time zone'::regtype::oid
          ]
        end
        or l.lanname <> case p.proname
          when 'admin_get_profile_account' then 'plpgsql'
          else 'sql'
        end
        or md5(btrim(regexp_replace(p.prosrc, E'\\s+', ' ', 'g'))) <>
          case p.proname
          when 'get_my_profiles' then '068d419cf900e4bde1bd36b73433c2b3'
          when 'current_user_owns_profile' then 'b18b8e4f01df72097d092352423ab8af'
          when 'admin_get_profile_account' then '1b1617031aa49512a692d706462e4f18'
        end
      )
  ) then
    raise exception 'Package B rollback precondition failed: function definition drift';
  end if;

  if exists (
    with actual(function_name, grantee, privilege_type, is_grantable, grantor) as (
      select p.proname,
        case when acl.grantee = 0 then 'PUBLIC'
             else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable,
        acl.grantor::regrole::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral aclexplode(
        coalesce(p.proacl, acldefault('f', p.proowner))
      ) acl
      where n.nspname = 'public'
        and p.proname in (
          'get_my_profiles',
          'current_user_owns_profile',
          'admin_get_profile_account'
        )
    ), expected as (
      values
        ('get_my_profiles'::name, 'postgres'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('get_my_profiles'::name, 'authenticated'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('current_user_owns_profile'::name, 'postgres'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('current_user_owns_profile'::name, 'authenticated'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('admin_get_profile_account'::name, 'postgres'::text, 'EXECUTE'::text,
          false, 'postgres'::text),
        ('admin_get_profile_account'::name, 'authenticated'::text, 'EXECUTE'::text,
          false, 'postgres'::text)
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Package B rollback precondition failed: function ACL drift';
  end if;
end;
$preconditions$;

drop function public.admin_get_profile_account(uuid) restrict;
drop function public.current_user_owns_profile(uuid) restrict;
drop function public.get_my_profiles() restrict;

do $postconditions$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname = 'public'
      and p.proname in (
        'get_my_profiles',
        'current_user_owns_profile',
        'admin_get_profile_account'
      )
  ) then
    raise exception 'Package B rollback postcondition failed: helper remains';
  end if;

  if not exists (
    select 1 from pg_index i
    where i.indexrelid = to_regclass('public.profiles_one_per_user_key')
      and i.indrelid = to_regclass('public.profiles')
      and i.indisunique and i.indisvalid and i.indisready
  ) then
    raise exception 'Package B rollback postcondition failed: one-profile guard drift';
  end if;

  if exists (
    with actual(grantor, grantee, privilege_type, is_grantable) as (
      select acl.grantor::regrole::text,
        case when acl.grantee = 0 then 'PUBLIC'
             else acl.grantee::regrole::text end,
        acl.privilege_type,
        acl.is_grantable
      from pg_class c
      cross join lateral aclexplode(
        coalesce(c.relacl, acldefault('r', c.relowner))
      ) acl
      where c.oid = to_regclass('public.profiles')
    ), expected as (
      select 'postgres'::text, r.grantee, p.privilege_type, false
      from (values ('postgres'::text), ('anon'), ('authenticated'),
                   ('service_role')) r(grantee)
      cross join (values ('DELETE'::text), ('INSERT'), ('MAINTAIN'),
                         ('REFERENCES'), ('SELECT'), ('TRIGGER'),
                         ('TRUNCATE'), ('UPDATE')) p(privilege_type)
      union all
      select 'postgres', 'audit_readonly', 'SELECT', false
    )
    (select * from actual except select * from expected)
    union all
    (select * from expected except select * from actual)
  ) then
    raise exception 'Package B rollback postcondition failed: profiles ACL drift';
  end if;
end;
$postconditions$;

commit;
