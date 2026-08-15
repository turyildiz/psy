-- psy.market Slice MP-4-C: social/event active authorization
-- Policy fingerprints use plain two-argument pg_get_expr(), matching admitted pg_policies evidence.
-- APPLY — OWNER-RUN IN SUPABASE SQL EDITOR.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
lock table public.event_notifications,public.favorites,public.follows,public.notice_posts,public.notice_reactions,public.vendor_events in access exclusive mode;
do $transition$
declare source_ok boolean; target_ok boolean;
begin
 if current_user<>'postgres' or session_user<>'postgres' then raise exception 'Slice MP4-C APPLY refused: owner SQL Editor context required' using errcode='42501'; end if;
 with relation_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||c.relowner::regrole::text||'|'||c.relkind::text||'|'||c.relpersistence::text||'|'||case when c.relrowsecurity then 't' else 'f' end||'|'||case when c.relforcerowsecurity then 't' else 'f' end||'|'||c.relreplident::text,E'\n' order by c.relname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
column_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||a.attnum||'|'||a.attname||'|'||regexp_replace(format_type(a.atttypid,a.atttypmod),'public\.','','g')||'|'||case when a.attnotnull then 't' else 'f' end||'|'||regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'public\.','','g'),E'\n' order by c.relname collate "C",a.attnum,a.attname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events') and a.attnum>0 and not a.attisdropped
),
constraint_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||x.conname||'|'||x.contype::text||'|'||regexp_replace(pg_get_constraintdef(x.oid,true),'public\.','','g')||'|'||case when x.convalidated then 't' else 'f' end||'|'||case when x.condeferrable then 't' else 'f' end||'|'||case when x.condeferred then 't' else 'f' end,E'\n' order by c.relname collate "C",x.conname collate "C"),'')) h
 from pg_constraint x join pg_class c on c.oid=x.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
index_state as (
 select count(*)::int n,md5(coalesce(string_agg(t.relname||'|'||i.relname||'|'||regexp_replace(pg_get_indexdef(i.oid),'public\.','','g')||'|'||case when x.indisunique then 't' else 'f' end||'|'||case when x.indisprimary then 't' else 'f' end||'|'||case when x.indisvalid then 't' else 'f' end||'|'||case when x.indisready then 't' else 'f' end,E'\n' order by t.relname collate "C",i.relname collate "C"),'')) h
 from pg_index x join pg_class t on t.oid=x.indrelid join pg_class i on i.oid=x.indexrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and t.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
trigger_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||t.tgname||'|'||regexp_replace(pg_get_triggerdef(t.oid,true),'public\.','','g')||'|'||t.tgenabled::text,E'\n' order by c.relname collate "C",t.tgname collate "C"),'')) h
 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events') and not t.tgisinternal
),
policy_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.polname||'|'||(case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE' when 'd' then 'DELETE' when '*' then 'ALL' end)||'|'||(case when p.polpermissive then 'PERMISSIVE' else 'RESTRICTIVE' end)||'|'||lower(coalesce((select array_agg(case when x=0 then 'public' else x::regrole::text end order by (case when x=0 then 'public' else x::regrole::text end) collate "C")::text from unnest(p.polroles) x),'{}'))||'|'||(case when p.polqual is null then '<null>' else lower(regexp_replace(regexp_replace(regexp_replace(pg_get_expr(p.polqual,p.polrelid),'public\.','','g'),'[[:space:]]+AS[[:space:]]+(current_active_profile_id|current_user_is_banned)','','gi'),'[[:space:]]+','','g')) end)||'|'||(case when p.polwithcheck is null then '<null>' else lower(regexp_replace(regexp_replace(regexp_replace(pg_get_expr(p.polwithcheck,p.polrelid),'public\.','','g'),'[[:space:]]+AS[[:space:]]+(current_active_profile_id|current_user_is_banned)','','gi'),'[[:space:]]+','','g')) end),E'\n' order by c.relname collate "C",p.polname collate "C"),'')) h
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end||'|'||a.grantor::regrole::text,E'\n' order by c.relname collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C",a.grantor::regrole::text collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
colacl_state as (
 select count(*)::int n from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute att on att.attrelid=c.oid cross join lateral aclexplode(att.attacl) a where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events') and att.attnum>0 and not att.attisdropped
),
publication_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.pubname,E'\n' order by c.relname collate "C",p.pubname collate "C"),'')) h from pg_publication_rel pr join pg_publication p on p.oid=pr.prpubid join pg_class c on c.oid=pr.prrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
mp4a_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
mp4a_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
legacy_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
legacy_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
membership_state as (
 select count(*)::int n,md5(coalesce(string_agg(member.rolname||'|'||granted.rolname||'|'||case when m.admin_option then 't' else 'f' end||'|'||case when m.inherit_option then 't' else 'f' end||'|'||case when m.set_option then 't' else 'f' end||'|'||grantor.rolname,E'\n' order by member.rolname collate "C",granted.rolname collate "C",grantor.rolname collate "C"),'')) h from pg_auth_members m join pg_roles member on member.oid=m.member join pg_roles granted on granted.oid=m.roleid join pg_roles grantor on grantor.oid=m.grantor where member.rolname in ('anon','authenticated','service_role','authenticator','postgres')
),
manifest as (
 select r.n relation_n,r.h relation_h,c.n column_n,c.h column_h,co.n constraint_n,co.h constraint_h,i.n index_n,i.h index_h,t.n trigger_n,t.h trigger_h,p.n policy_n,p.h policy_h,a.n acl_n,a.h acl_h,ca.n colacl_n,pu.n publication_n,pu.h publication_h,mf.n mp4a_function_n,mf.h mp4a_function_h,ma.n mp4a_acl_n,ma.h mp4a_acl_h,lf.n legacy_function_n,lf.h legacy_function_h,la.n legacy_acl_n,la.h legacy_acl_h,ms.n membership_n,ms.h membership_h from relation_state r cross join column_state c cross join constraint_state co cross join index_state i cross join trigger_state t cross join policy_state p cross join acl_state a cross join colacl_state ca cross join publication_state pu cross join mp4a_function_state mf cross join mp4a_acl_state ma cross join legacy_function_state lf cross join legacy_acl_state la cross join membership_state ms
) select ((m.relation_n=6 and m.relation_h='95b0d6bfa747399c5b7d9d412813ed53'
 and m.column_n=31 and m.column_h='f856c2e4647a77101952938c138cc904'
 and m.constraint_n=28 and m.constraint_h='99e20f84d2c518d4d36ea0bc27378de7'
 and m.index_n=23 and m.index_h='6e2c9273517aa80d33966f4c6d135b27'
 and m.trigger_n=0 and m.trigger_h='d41d8cd98f00b204e9800998ecf8427e'
 and m.acl_n=(case when current_setting('server_version_num')::int>=170000 then 179 else 158 end)
 and m.acl_h=(case when current_setting('server_version_num')::int>=170000 then '2ec9147114c9244d781efd89d882c747' else '2bf7e55e8822beea4b57864c5fb9bd49' end)
 and m.colacl_n=0 and m.publication_n=2 and m.publication_h='fde620f9d09de68cf14e62cffdb7c493'
 and m.mp4a_function_n=4 and m.mp4a_function_h='165eb4bc928f79c5ba10124209af4db4'
 and m.mp4a_acl_n=7 and m.mp4a_acl_h='1a9bc3c64d199fbfe7463dc80a3f7fb1'
 and m.legacy_function_n=4 and m.legacy_function_h='0259776e2bcc6a144ac3bf3787245497'
 and m.legacy_acl_n=8 and m.legacy_acl_h='6736d5d9cb627a2c79a7d2a84fb8f7d2'
 and m.membership_n=13 and m.membership_h='2c5626f6dd72493cd1f6b18bd20a6036'
 and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)))
 and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5) and (m.policy_n=17 and m.policy_h='88b11cfcc7f9dc11e40259cfc5c67dd3')),((m.relation_n=6 and m.relation_h='95b0d6bfa747399c5b7d9d412813ed53'
 and m.column_n=31 and m.column_h='f856c2e4647a77101952938c138cc904'
 and m.constraint_n=28 and m.constraint_h='99e20f84d2c518d4d36ea0bc27378de7'
 and m.index_n=23 and m.index_h='6e2c9273517aa80d33966f4c6d135b27'
 and m.trigger_n=0 and m.trigger_h='d41d8cd98f00b204e9800998ecf8427e'
 and m.acl_n=(case when current_setting('server_version_num')::int>=170000 then 179 else 158 end)
 and m.acl_h=(case when current_setting('server_version_num')::int>=170000 then '2ec9147114c9244d781efd89d882c747' else '2bf7e55e8822beea4b57864c5fb9bd49' end)
 and m.colacl_n=0 and m.publication_n=2 and m.publication_h='fde620f9d09de68cf14e62cffdb7c493'
 and m.mp4a_function_n=4 and m.mp4a_function_h='165eb4bc928f79c5ba10124209af4db4'
 and m.mp4a_acl_n=7 and m.mp4a_acl_h='1a9bc3c64d199fbfe7463dc80a3f7fb1'
 and m.legacy_function_n=4 and m.legacy_function_h='0259776e2bcc6a144ac3bf3787245497'
 and m.legacy_acl_n=8 and m.legacy_acl_h='6736d5d9cb627a2c79a7d2a84fb8f7d2'
 and m.membership_n=13 and m.membership_h='2c5626f6dd72493cd1f6b18bd20a6036'
 and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)))
 and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5) and (m.policy_n=17 and m.policy_h='84def60822028f0e6206c1ab4e780cb3')) into source_ok,target_ok from manifest m;
 if target_ok then return; end if;
 if not source_ok then raise exception 'Slice MP4-C APPLY refused: exact source/target manifest not found' using errcode='55000'; end if;
 alter policy "Unbanned users manage own favorites" on public.favorites using (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id())) with check (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Users can read their own favorites" on public.favorites using (profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users follow from own profile" on public.follows with check (not (select public.current_user_is_banned()) and follower_profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users unfollow from own profile" on public.follows using (not (select public.current_user_is_banned()) and follower_profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users add own RSVP" on public.vendor_events with check (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users remove own RSVP" on public.vendor_events using (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users create own notice posts" on public.notice_posts with check (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users delete own notice posts" on public.notice_posts using (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users add own reactions" on public.notice_reactions with check (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users remove own reactions" on public.notice_reactions using (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users subscribe to event notifications" on public.event_notifications with check (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Unbanned users unsubscribe from event notifications" on public.event_notifications using (not (select public.current_user_is_banned()) and profile_id=(select public.current_active_profile_id()));
alter policy "Users can manage their own event notifications" on public.event_notifications using (profile_id=(select public.current_active_profile_id()));
end
$transition$;
do $post$
declare ok boolean;
begin
 with relation_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||c.relowner::regrole::text||'|'||c.relkind::text||'|'||c.relpersistence::text||'|'||case when c.relrowsecurity then 't' else 'f' end||'|'||case when c.relforcerowsecurity then 't' else 'f' end||'|'||c.relreplident::text,E'\n' order by c.relname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
column_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||a.attnum||'|'||a.attname||'|'||regexp_replace(format_type(a.atttypid,a.atttypmod),'public\.','','g')||'|'||case when a.attnotnull then 't' else 'f' end||'|'||regexp_replace(coalesce(pg_get_expr(d.adbin,d.adrelid,true),''),'public\.','','g'),E'\n' order by c.relname collate "C",a.attnum,a.attname collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute a on a.attrelid=c.oid left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events') and a.attnum>0 and not a.attisdropped
),
constraint_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||x.conname||'|'||x.contype::text||'|'||regexp_replace(pg_get_constraintdef(x.oid,true),'public\.','','g')||'|'||case when x.convalidated then 't' else 'f' end||'|'||case when x.condeferrable then 't' else 'f' end||'|'||case when x.condeferred then 't' else 'f' end,E'\n' order by c.relname collate "C",x.conname collate "C"),'')) h
 from pg_constraint x join pg_class c on c.oid=x.conrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
index_state as (
 select count(*)::int n,md5(coalesce(string_agg(t.relname||'|'||i.relname||'|'||regexp_replace(pg_get_indexdef(i.oid),'public\.','','g')||'|'||case when x.indisunique then 't' else 'f' end||'|'||case when x.indisprimary then 't' else 'f' end||'|'||case when x.indisvalid then 't' else 'f' end||'|'||case when x.indisready then 't' else 'f' end,E'\n' order by t.relname collate "C",i.relname collate "C"),'')) h
 from pg_index x join pg_class t on t.oid=x.indrelid join pg_class i on i.oid=x.indexrelid join pg_namespace n on n.oid=t.relnamespace where n.nspname='public' and t.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
trigger_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||t.tgname||'|'||regexp_replace(pg_get_triggerdef(t.oid,true),'public\.','','g')||'|'||t.tgenabled::text,E'\n' order by c.relname collate "C",t.tgname collate "C"),'')) h
 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events') and not t.tgisinternal
),
policy_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.polname||'|'||(case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' when 'w' then 'UPDATE' when 'd' then 'DELETE' when '*' then 'ALL' end)||'|'||(case when p.polpermissive then 'PERMISSIVE' else 'RESTRICTIVE' end)||'|'||lower(coalesce((select array_agg(case when x=0 then 'public' else x::regrole::text end order by (case when x=0 then 'public' else x::regrole::text end) collate "C")::text from unnest(p.polroles) x),'{}'))||'|'||(case when p.polqual is null then '<null>' else lower(regexp_replace(regexp_replace(regexp_replace(pg_get_expr(p.polqual,p.polrelid),'public\.','','g'),'[[:space:]]+AS[[:space:]]+(current_active_profile_id|current_user_is_banned)','','gi'),'[[:space:]]+','','g')) end)||'|'||(case when p.polwithcheck is null then '<null>' else lower(regexp_replace(regexp_replace(regexp_replace(pg_get_expr(p.polwithcheck,p.polrelid),'public\.','','g'),'[[:space:]]+AS[[:space:]]+(current_active_profile_id|current_user_is_banned)','','gi'),'[[:space:]]+','','g')) end),E'\n' order by c.relname collate "C",p.polname collate "C"),'')) h
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end||'|'||a.grantor::regrole::text,E'\n' order by c.relname collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C",a.grantor::regrole::text collate "C"),'')) h
 from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
colacl_state as (
 select count(*)::int n from pg_class c join pg_namespace n on n.oid=c.relnamespace join pg_attribute att on att.attrelid=c.oid cross join lateral aclexplode(att.attacl) a where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events') and att.attnum>0 and not att.attisdropped
),
publication_state as (
 select count(*)::int n,md5(coalesce(string_agg(c.relname||'|'||p.pubname,E'\n' order by c.relname collate "C",p.pubname collate "C"),'')) h from pg_publication_rel pr join pg_publication p on p.oid=pr.prpubid join pg_class c on c.oid=pr.prrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('event_notifications','favorites','follows','notice_posts','notice_reactions','vendor_events')
),
mp4a_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
mp4a_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where (n.nspname='private' and p.proname='current_active_profile_id') or (n.nspname='public' and p.proname in ('current_active_profile_id','current_user_is_active_profile','current_user_is_active_unsuspended_profile'))
),
legacy_function_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'|'||p.proname||'|'||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||'|'||p.proowner::regrole::text||'|'||l.lanname||'|'||p.provolatile::text||'|'||case when p.prosecdef then 't' else 'f' end||'|'||case when p.proisstrict then 't' else 'f' end||'|'||case when p.proleakproof then 't' else 'f' end||'|'||p.proparallel::text||'|'||p.pronargdefaults||'|'||coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by (case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end) collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>')||'|'||regexp_replace(pg_get_function_result(p.oid),'public\.','','g')||'|'||md5(btrim(regexp_replace(p.prosrc,'[[:space:]]+',' ','g'))),E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
legacy_acl_state as (
 select count(*)::int n,md5(coalesce(string_agg(n.nspname||'.'||p.proname||'('||regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g')||')|'||a.grantor::regrole::text||'|'||(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)||'|'||a.privilege_type||'|'||case when a.is_grantable then 't' else 'f' end,E'\n' order by n.nspname collate "C",p.proname collate "C",regexp_replace(pg_get_function_identity_arguments(p.oid),'public\.','','g') collate "C",a.grantor::regrole::text collate "C",(case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) collate "C",a.privilege_type collate "C"),'')) h from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('create_additional_profile','current_user_is_banned','current_user_owns_profile','current_user_owns_unsuspended_profile')
),
membership_state as (
 select count(*)::int n,md5(coalesce(string_agg(member.rolname||'|'||granted.rolname||'|'||case when m.admin_option then 't' else 'f' end||'|'||case when m.inherit_option then 't' else 'f' end||'|'||case when m.set_option then 't' else 'f' end||'|'||grantor.rolname,E'\n' order by member.rolname collate "C",granted.rolname collate "C",grantor.rolname collate "C"),'')) h from pg_auth_members m join pg_roles member on member.oid=m.member join pg_roles granted on granted.oid=m.roleid join pg_roles grantor on grantor.oid=m.grantor where member.rolname in ('anon','authenticated','service_role','authenticator','postgres')
),
manifest as (
 select r.n relation_n,r.h relation_h,c.n column_n,c.h column_h,co.n constraint_n,co.h constraint_h,i.n index_n,i.h index_h,t.n trigger_n,t.h trigger_h,p.n policy_n,p.h policy_h,a.n acl_n,a.h acl_h,ca.n colacl_n,pu.n publication_n,pu.h publication_h,mf.n mp4a_function_n,mf.h mp4a_function_h,ma.n mp4a_acl_n,ma.h mp4a_acl_h,lf.n legacy_function_n,lf.h legacy_function_h,la.n legacy_acl_n,la.h legacy_acl_h,ms.n membership_n,ms.h membership_h from relation_state r cross join column_state c cross join constraint_state co cross join index_state i cross join trigger_state t cross join policy_state p cross join acl_state a cross join colacl_state ca cross join publication_state pu cross join mp4a_function_state mf cross join mp4a_acl_state ma cross join legacy_function_state lf cross join legacy_acl_state la cross join membership_state ms
) select ((m.relation_n=6 and m.relation_h='95b0d6bfa747399c5b7d9d412813ed53'
 and m.column_n=31 and m.column_h='f856c2e4647a77101952938c138cc904'
 and m.constraint_n=28 and m.constraint_h='99e20f84d2c518d4d36ea0bc27378de7'
 and m.index_n=23 and m.index_h='6e2c9273517aa80d33966f4c6d135b27'
 and m.trigger_n=0 and m.trigger_h='d41d8cd98f00b204e9800998ecf8427e'
 and m.acl_n=(case when current_setting('server_version_num')::int>=170000 then 179 else 158 end)
 and m.acl_h=(case when current_setting('server_version_num')::int>=170000 then '2ec9147114c9244d781efd89d882c747' else '2bf7e55e8822beea4b57864c5fb9bd49' end)
 and m.colacl_n=0 and m.publication_n=2 and m.publication_h='fde620f9d09de68cf14e62cffdb7c493'
 and m.mp4a_function_n=4 and m.mp4a_function_h='165eb4bc928f79c5ba10124209af4db4'
 and m.mp4a_acl_n=7 and m.mp4a_acl_h='1a9bc3c64d199fbfe7463dc80a3f7fb1'
 and m.legacy_function_n=4 and m.legacy_function_h='0259776e2bcc6a144ac3bf3787245497'
 and m.legacy_acl_n=8 and m.legacy_acl_h='6736d5d9cb627a2c79a7d2a84fb8f7d2'
 and m.membership_n=13 and m.membership_h='2c5626f6dd72493cd1f6b18bd20a6036'
 and not exists((select rolname,rolsuper,rolinherit,rolbypassrls from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role')) except (values ('anon'::name,false,true,false),('audit_readonly'::name,false,false,false),('authenticated'::name,false,true,false),('postgres'::name,false,true,true),('service_role'::name,false,true,true)))
 and (select count(*) from pg_roles where rolname in ('anon','audit_readonly','authenticated','postgres','service_role'))=5) and (m.policy_n=17 and m.policy_h='84def60822028f0e6206c1ab4e780cb3')) into ok from manifest m;
 if not ok then raise exception 'Slice MP4-C APPLY postcondition failed' using errcode='55000'; end if;
end
$post$;
commit;
