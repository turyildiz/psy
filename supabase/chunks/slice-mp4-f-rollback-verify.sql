-- psy.market Slice MP-4-F ROLLBACK VERIFY — owner-run, read-only source proof.
begin transaction isolation level repeatable read read only;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,public.conversation_participant_state in share mode;

select 'RESTORED_POLICY_ROW' record_type,c.relname table_name,p.polname,p.polcmd::text command,p.polpermissive,
 array(select case when r=0 then 'PUBLIC' else r::regrole::text end from unnest(p.polroles) r order by(case when r=0 then 'PUBLIC' else r::regrole::text end)collate "C") roles,
 lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) using_expr,
 lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) check_expr
from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state') order by c.relname collate "C",p.polname collate "C";

do $assert$
declare failures text;
begin
 with p as(select c.relname,p.polname,p.polcmd::text cmd,p.polpermissive,array(select case when r=0 then 'PUBLIC' else r::regrole::text end from unnest(p.polroles)r order by(case when r=0 then 'PUBLIC' else r::regrole::text end)collate "C")polroles,
  lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) q,
  lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g')) w
  from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')),
 expected(relname,polname,cmd,polpermissive,polroles,q,w) as(values
  ('conversation_participant_state','Participants read own conversation state','r',true,array['authenticated'],'current_user_owns_profile(profile_id)',''),
  ('conversations','Unbanned buyers create conversations','a',true,array['authenticated'],'','((notcurrent_user_is_banned())andcurrent_user_owns_profile(buyer_profile_id)and(buyer_profile_id<>seller_profile_id)and((listing_idisnull)or(seller_profile_id=(selectl.profile_idfromlistingslwhere(l.id=conversations.listing_id)))))'),
  ('conversations','participants view visible conversations','r',true,array['authenticated'],'((current_user_owns_profile(buyer_profile_id)orcurrent_user_owns_profile(seller_profile_id))and(not(exists(select1fromconversation_participant_stateswhere((s.conversation_id=conversations.id)andcurrent_user_owns_profile(s.profile_id)and(s.hidden_atisnotnull))))))',''),
  ('messages','Unbanned participants send messages','a',true,array['authenticated'],'','((notcurrent_user_is_banned())andcurrent_user_owns_profile(sender_profile_id)and(conversation_idin(selectc.idfromconversationscwhere((messages.sender_profile_id=c.buyer_profile_id)or(messages.sender_profile_id=c.seller_profile_id)))))'),
  ('messages','participants view messages','r',true,array['authenticated'],'(conversation_idin(selectc.idfromconversationscwhere(current_user_owns_profile(c.buyer_profile_id)orcurrent_user_owns_profile(c.seller_profile_id))))','')
 ),
 checks(name,ok) as(values
  ('owner_context',current_user='postgres' and session_user='postgres' and (select rolsuper or rolbypassrls from pg_roles where rolname=current_user)),
  ('source_policy_family_exact',not exists((select * from p except select * from expected)union all(select * from expected except select * from p))),
  ('source_policy_digest_exact',(select md5(coalesce(string_agg(relname||'|'||polname||'|'||cmd||'|'||polpermissive||'|'||array_to_string(polroles,',')||'|'||q||'|'||w,E'\n' order by relname collate "C",polname collate "C"),''))='1d826818e61c36ca3e2316f9ba7a3239' from p)),
  ('post_e_schema_retained',(select count(*)=3 from pg_attribute where attrelid in('public.conversations'::regclass,'public.messages'::regclass) and attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and not attnotnull)),
  ('post_e_guards_retained',(select count(*)=4 from pg_trigger where not tgisinternal and (tgrelid,tgname) in(('public.conversations'::regclass,'conversations_guard_participants'),('public.conversations'::regclass,'conversations_guard_unread'),('public.messages'::regclass,'messages_guard_active_participant'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard')))),
  ('publication_retained',(select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in('conversations','messages','conversation_participant_state')))
 )select string_agg(name,E'\n' order by name collate "C") into failures from checks where not ok;
 if failures is not null then raise exception 'MP4-F ROLLBACK VERIFY STOP:%',E'\n'||failures using errcode='55000';end if;
end$assert$;
with p as(select c.relname,p.polname,p.polcmd::text cmd,p.polpermissive,array(select case when r=0 then 'PUBLIC' else r::regrole::text end from unnest(p.polroles)r order by(case when r=0 then 'PUBLIC' else r::regrole::text end)collate "C")roles,lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polqual,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g'))q,lower(regexp_replace(regexp_replace(coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),''),'public\.','','g'),'[[:space:]]+','','g'))w from pg_policy p join pg_class c on c.oid=p.polrelid where p.polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass)),
check_names(name)as(values('owner_context'),('source_policy_family_exact'),('source_policy_digest_exact'),('post_e_schema_retained'),('post_e_guards_retained'),('publication_retained'))
select 'SLICE_MP4_F_ROLLBACK_VERIFY' package,'GO' verdict,(select count(*)::int from check_names)passed,(select count(*)::int from check_names)total,'{}'::text[] findings,
 md5(coalesce(string_agg(relname||'|'||polname||'|'||cmd||'|'||polpermissive||'|'||array_to_string(roles,',')||'|'||q||'|'||w,E'\n' order by relname collate "C",polname collate "C"),'')) restored_plain_policy_md5,
 '1d826818e61c36ca3e2316f9ba7a3239'::text expected_preflight_plain_policy_md5,
 'Exact post-E any-owned policy rows and normalized digest restored; active-authority count returns to 18. MP4-E nullable schema/guards remain and F must precede E rollback.'::text boundary from p;
rollback;
