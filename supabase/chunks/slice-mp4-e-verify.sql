-- psy.market Slice MP-4-E VERIFY — owner-run, read-only behavior-neutral proof.
-- WINGMAN LIVE RECOMPUTE REQUIRED for every LIVE_PIN before the sitting.
begin;
set local row_security=off;
lock table public.profiles, public.listings, public.conversations,
 public.messages, public.conversation_participant_state in share mode;

do $assert$
declare failures text;
begin
with checks(name,ok,detail) as (values
('nullable_columns_exact',(
 select count(*)=3 and bool_and(not a.attnotnull and a.atttypid='uuid'::regtype and d.oid is null and a.attidentity='' and a.attgenerated='')
 from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
 where n.nspname='public' and (c.relname,a.attname) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id'))),'LIVE_PIN: exact nullable UUID columns/default/identity/generated state'),
('differ_constraint_target_exact',(
 select count(*)=1 and bool_and(convalidated and not condeferrable and not condeferred and lower(regexp_replace(pg_get_constraintdef(oid,false),'[[:space:]]+',' ','g'))=
 'check ((((buyer_profile_id is not null) and (seller_profile_id is not null) and (buyer_profile_id <> seller_profile_id)) or ((buyer_profile_id is null) and (seller_profile_id is not null)) or ((buyer_profile_id is not null) and (seller_profile_id is null))))')
 from pg_constraint where conrelid='public.conversations'::regclass and conname='conversations_buyer_seller_differ'),'LIVE_PIN: target null-safe differ CHECK renderer'),
('fk_actions_unchanged',(
 select count(*)=8 and bool_and(convalidated and not condeferrable and not condeferred and confdeltype=expected)
 from pg_constraint c join (values
 ('conversations_buyer_profile_id_fkey','c'::"char"),('conversations_seller_profile_id_fkey','c'::"char"),('conversations_listing_id_fkey','n'::"char"),
 ('messages_sender_profile_id_fkey','c'::"char"),('messages_conversation_id_fkey','c'::"char"),
 ('conversation_participant_state_profile_id_fkey','c'::"char"),('conversation_participant_state_conversation_id_fkey','c'::"char"),
 ('account_session_active_profiles_profile_owner_fkey','c'::"char")) e(name,expected) on e.name=c.conname),'LIVE_PIN: all FK actions including private profile-owner cascade'),
('complete_index_names_exact',not exists(
 (select c.relname,i.relname from pg_index x join pg_class c on c.oid=x.indrelid join pg_class i on i.oid=x.indexrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('conversations','messages','conversation_participant_state'))
 except (values ('conversations','conversations_pkey'),('conversations','idx_conversations_buyer'),('conversations','idx_conversations_last_message'),('conversations','idx_conversations_seller'),('conversations','unique_conversation'),('messages','idx_messages_conversation'),('messages','messages_pkey'),('conversation_participant_state','conversation_participant_state_pkey'),('conversation_participant_state','conversation_participant_state_hidden_profile_idx')))
 and not exists((values ('conversations','conversations_pkey'),('conversations','idx_conversations_buyer'),('conversations','idx_conversations_last_message'),('conversations','idx_conversations_seller'),('conversations','unique_conversation'),('messages','idx_messages_conversation'),('messages','messages_pkey'),('conversation_participant_state','conversation_participant_state_pkey'),('conversation_participant_state','conversation_participant_state_hidden_profile_idx')) except
 (select c.relname,i.relname from pg_index x join pg_class c on c.oid=x.indrelid join pg_class i on i.oid=x.indexrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('conversations','messages','conversation_participant_state'))),'LIVE_PIN: complete retained index-name set; definitions must be wingman-byte-reviewed'),
('guard_trigger_bindings_exact',(
 select count(*)=7 and bool_and(t.tgenabled='O') from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_proc p on p.oid=t.tgfoid where not t.tgisinternal and
 (c.relname,t.tgname,p.proname) in (('conversations','conversations_enforce_listing_seller','enforce_conversation_listing_seller'),('conversations','conversations_guard_participants','guard_conversation_participants'),('conversations','conversations_guard_unread','guard_conversation_unread_participants'),('messages','messages_guard_active_participant','guard_message_active_participant'),('messages','messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient'),('messages','on_message_insert','update_conversation_last_message'),('conversation_participant_state','conversation_participant_state_guard','guard_conversation_participant_state'))),'LIVE_PIN: exact seven trigger bindings'),
('trigger_function_attributes_and_acl_exact',
 (select count(*)=7 and bool_and(p.prosecdef and l.lanname='plpgsql' and p.provolatile='v' and not p.proisstrict and not p.proleakproof and p.proparallel='u' and p.proowner::regrole::text='postgres' and p.proconfig in (array['search_path='],array['search_path=""']))
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang where n.nspname='public' and p.proname in ('enforce_conversation_listing_seller','guard_conversation_participants','guard_conversation_unread_participants','guard_message_active_participant','guard_conversation_participant_state','unhide_conversation_for_message_recipient','update_conversation_last_message'))
 and (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in ('enforce_conversation_listing_seller','guard_conversation_participants','guard_conversation_unread_participants','guard_message_active_participant','guard_conversation_participant_state','unhide_conversation_for_message_recipient','update_conversation_last_message') and (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end) not in ('postgres','service_role'))=0,'LIVE_PIN: complete attributes/defaults/settings/body serializers + exploded ACLs'),
('policy_names_commands_unchanged',not exists(
 (select c.relname,p.polname,case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT' else p.polcmd::text end from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('conversations','messages','conversation_participant_state'))
 except (values ('conversation_participant_state','Participants read own conversation state','SELECT'),('conversations','Unbanned buyers create conversations','INSERT'),('conversations','participants view visible conversations','SELECT'),('messages','Unbanned participants send messages','INSERT'),('messages','participants view messages','SELECT'))),'LIVE_PIN: exact five policy names/commands; plain pg_get_expr manifests must be recomputed'),
('no_live_nulls_or_invalid_rows',not exists(select 1 from public.conversations where buyer_profile_id is null or seller_profile_id is null or buyer_profile_id=seller_profile_id) and not exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id where m.sender_profile_id is null or m.sender_profile_id not in(c.buyer_profile_id,c.seller_profile_id)),'LIVE_PIN: package rewrote no participant/sender value'),
('unread_and_state_valid',not exists(select 1 from public.conversations c cross join lateral unnest(coalesce(c.unread_for,'{}'::text[])) u(v) where case when u.v~*'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then u.v::uuid not in(c.buyer_profile_id,c.seller_profile_id) else true end) and not exists(select 1 from public.conversation_participant_state s join public.conversations c on c.id=s.conversation_id where s.profile_id not in(c.buyer_profile_id,c.seller_profile_id)),'LIVE_PIN: current unread/state remains participant-valid'),
('realtime_replica_identity_unchanged',(select count(*)=3 and bool_and(c.relreplident='d') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('conversations','messages','conversation_participant_state')) and (select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in ('conversations','messages','conversation_participant_state')),'LIVE_PIN: publication and replica identity unchanged'),
('package_d_privacy_intact',not has_column_privilege('anon','public.profiles','user_id','SELECT') and not has_column_privilege('authenticated','public.profiles','user_id','SELECT'),'LIVE_PIN: Package D owner-column privacy unchanged'))
 select string_agg(name||': '||detail,E'\n' order by name collate "C") into failures from checks where not ok;
 if failures is not null then raise exception 'MP4-E VERIFY STOP:%',E'\n'||failures using errcode='55000'; end if;
end$assert$;

with counts as (select (select count(*) from public.conversations) conversations,(select count(*) from public.messages) messages,(select count(*) from public.conversation_participant_state) participant_states)
select 'SLICE_MP4_E_VERIFY' package,'GO' verdict,11::int passed,11::int total,'{}'::text[] findings,conversations,messages,participant_states,
 'Dormant nullability only: current rows remain all-present; FK delete actions remain live CASCADE/SET NULL as before; profile deletion and retained-row cutover are NOT live.'::text boundary from counts;
rollback;
