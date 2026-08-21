-- psy.market Slice MP-4-E ROLLBACK VERIFY — owner-run, read-only exact-source proof.
begin transaction isolation level repeatable read read only;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,public.conversation_participant_state in share mode;

do $assert$
declare failures text;
begin
with trigger_state as (
 select c.relname,t.tgname,p.proname,t.tgenabled::text,lower(regexp_replace(regexp_replace(pg_get_triggerdef(t.oid,false),'(public|private)\.','','g'),'[[:space:]]+',' ','g')) definition
 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace join pg_proc p on p.oid=t.tgfoid
 where not t.tgisinternal and n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state')
), checks(name,ok) as (values
 ('owner_context',current_user='postgres' and session_user='postgres' and (select rolsuper or rolbypassrls from pg_roles where rolname=current_user)),
 ('not_null_columns_restored',(select count(*)=3 from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and (c.relname,a.attname) in(('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id')) and a.attnotnull and a.atttypid='uuid'::regtype and a.attcollation=0 and a.attidentity='' and a.attgenerated='')),
 ('source_differ_restored',exists(select 1 from pg_constraint where conrelid='public.conversations'::regclass and conname='conversations_buyer_seller_differ' and convalidated and not condeferrable and not condeferred and lower(regexp_replace(pg_get_constraintdef(oid,false),'[[:space:]]+',' ','g'))='check ((buyer_profile_id <> seller_profile_id))')),
 ('target_guards_absent',to_regprocedure('public.guard_conversation_participants()') is null and to_regprocedure('public.guard_conversation_unread_participants()') is null and to_regprocedure('public.guard_message_active_participant()') is null and to_regprocedure('public.guard_conversation_participant_state()') is null),
 ('source_triggers_exact',not exists((select * from trigger_state) except (values
   ('conversations','conversations_enforce_listing_seller','enforce_conversation_listing_seller','O','create trigger conversations_enforce_listing_seller before insert or update of listing_id, seller_profile_id on conversations for each row execute function enforce_conversation_listing_seller()'),
   ('messages','messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient','O','create trigger messages_unhide_recipient_conversation after insert on messages for each row execute function unhide_conversation_for_message_recipient()'),
   ('messages','on_message_insert','update_conversation_last_message','O','create trigger on_message_insert after insert on messages for each row execute function update_conversation_last_message()')))
   and not exists((values
   ('conversations','conversations_enforce_listing_seller','enforce_conversation_listing_seller','O','create trigger conversations_enforce_listing_seller before insert or update of listing_id, seller_profile_id on conversations for each row execute function enforce_conversation_listing_seller()'),
   ('messages','messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient','O','create trigger messages_unhide_recipient_conversation after insert on messages for each row execute function unhide_conversation_for_message_recipient()'),
   ('messages','on_message_insert','update_conversation_last_message','O','create trigger on_message_insert after insert on messages for each row execute function update_conversation_last_message()')) except select * from trigger_state)),
 ('source_function_bodies_exact',(select count(*)=3 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname,md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))) in(
   ('enforce_conversation_listing_seller','0dff735e21efc845ee166e57f902136a'),('unhide_conversation_for_message_recipient','66074618fc4aefdc17cd2b6c0274950a'),('update_conversation_last_message','45c2da17ae8a0272b0fd3e1fbb3d388e')))),
 ('source_function_settings_exact',(select count(*)=3 and bool_and(p.prosecdef and l.lanname='plpgsql' and p.provolatile='v' and not p.proisstrict and not p.proleakproof and p.proparallel='u' and p.proowner='postgres'::regrole and pg_get_function_identity_arguments(p.oid)='' and pg_get_function_arguments(p.oid)='' and p.pronargdefaults=0 and ((p.proname in('enforce_conversation_listing_seller','unhide_conversation_for_message_recipient') and p.proconfig=array['search_path=pg_catalog, public']) or(p.proname='update_conversation_last_message' and p.proconfig in(array['search_path='],array['search_path=""'])))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in('enforce_conversation_listing_seller','unhide_conversation_for_message_recipient','update_conversation_last_message'))),
 ('source_function_acls_exact',(select count(*)=6 and bool_and(a.grantor='postgres'::regrole and a.grantee in('postgres'::regrole,'service_role'::regrole) and a.privilege_type='EXECUTE' and not a.is_grantable) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in('enforce_conversation_listing_seller','unhide_conversation_for_message_recipient','update_conversation_last_message'))),
 ('fk_actions_restored',(select count(*)=8 and bool_and(c.confdeltype=e.action and c.convalidated and not c.condeferrable and not c.condeferred) from pg_constraint c join(values('conversations_buyer_profile_id_fkey','c'::"char"),('conversations_seller_profile_id_fkey','c'::"char"),('conversations_listing_id_fkey','n'::"char"),('messages_sender_profile_id_fkey','c'::"char"),('messages_conversation_id_fkey','c'::"char"),('conversation_participant_state_profile_id_fkey','c'::"char"),('conversation_participant_state_conversation_id_fkey','c'::"char"),('account_session_active_profiles_profile_owner_fkey','c'::"char"))e(name,action) on e.name=c.conname))
) select string_agg(name,E'\n' order by name collate "C") into failures from checks where not ok;
if failures is not null then raise exception 'MP4-E ROLLBACK VERIFY STOP:%',E'\n'||failures using errcode='55000';end if;
end$assert$;
select 'SLICE_MP4_E_ROLLBACK_VERIFY' package,'GO' verdict,9::int passed,9::int total,'{}'::text[] findings,'Exact reviewed source bodies/settings/triggers/nullability/FKs restored; no target guard remains.'::text boundary;
rollback;
