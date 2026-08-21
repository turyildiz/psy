-- psy.market Slice MP-4-F ROLLBACK VERIFY — owner-run, read-only source proof.
begin transaction isolation level repeatable read read only;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,public.conversation_participant_state in share mode;

do $assert$
declare failures text;
begin
 with p as(select c.relname,p.polname,p.polcmd::text cmd,p.polpermissive,p.polroles,
  coalesce(pg_get_expr(p.polqual,p.polrelid,false),'') q,coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),'') w
  from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')),
 checks(name,ok) as(values
  ('owner_context',current_user='postgres' and session_user='postgres' and (select rolsuper or rolbypassrls from pg_roles where rolname=current_user)),
  -- Five is derived: conversation INSERT+SELECT, message INSERT+SELECT, state SELECT.
  ('source_policy_family',(select count(*)=5 and bool_and(polpermissive and polroles=array['authenticated'::regrole::oid]) and count(*) filter(where q||w like '%current_user_owns_profile%')=5 and count(*) filter(where q||w like '%current_active_profile_id%')=0 from p)),
  ('source_names_commands',not exists((select relname,polname,cmd from p) except(values('conversation_participant_state','Participants read own conversation state','r'),('conversations','Unbanned buyers create conversations','a'),('conversations','participants view visible conversations','r'),('messages','Unbanned participants send messages','a'),('messages','participants view messages','r')))),
  ('post_e_schema_retained',(select count(*)=3 from pg_attribute where attrelid in('public.conversations'::regclass,'public.messages'::regclass) and attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and not attnotnull)),
  ('post_e_guards_retained',(select count(*)=4 from pg_trigger where not tgisinternal and (tgrelid,tgname) in(('public.conversations'::regclass,'conversations_guard_participants'),('public.conversations'::regclass,'conversations_guard_unread'),('public.messages'::regclass,'messages_guard_active_participant'),('public.conversation_participant_state'::regclass,'conversation_participant_state_guard')))),
  ('publication_retained',(select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in('conversations','messages','conversation_participant_state')))
 )select string_agg(name,E'\n' order by name collate "C") into failures from checks where not ok;
 if failures is not null then raise exception 'MP4-F ROLLBACK VERIFY STOP:%',E'\n'||failures using errcode='55000';end if;
end$assert$;
-- Six is derived from the six named checks in the assertion CTE above.
select 'SLICE_MP4_F_ROLLBACK_VERIFY' package,'GO' verdict,6::int passed,6::int total,'{}'::text[] findings,'Exact post-E any-owned policy family restored; MP4-E nullable schema/guards remain and F must precede E rollback.'::text boundary;
rollback;
