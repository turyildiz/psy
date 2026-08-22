\set ON_ERROR_STOP on
-- DISPOSABLE POSTGRESQL ONLY: policy-isolating active/inactive/foreign/ban/null matrix.
begin;
create function pg_temp.assert_true(name text,ok boolean) returns void language plpgsql as $$begin if ok is not true then raise exception '% failed',name using errcode='XX000';end if;raise notice 'PASS %',name;end$$;
create function pg_temp.claims(uid uuid,sid uuid) returns void language plpgsql as $$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated','session_id',sid)::text,true);end$$;
create function pg_temp.expect_error(name text,want text,sql_text text,neutral boolean default false) returns void language plpgsql as $$declare got text;msg text;begin begin execute sql_text;exception when others then get stacked diagnostics got=returned_sqlstate,msg=message_text;end;if got is distinct from want then raise exception '% expected %, got %',name,want,coalesce(got,'SUCCESS') using errcode='XX000';end if;if want='42501' and msg not like 'new row violates row-level security policy for table %' then raise exception '% expected isolated RLS denial, got message %',name,msg using errcode='XX000';end if;if neutral and (msg~*'(owner|sibling|same[- ]account|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') then raise exception '% leaked linkage: %',name,msg using errcode='XX000';end if;raise notice 'PASS % SQLSTATE % neutral=%',name,got,neutral;end$$;

-- Current shape: ordinary accounts have one profile; the sole-profile fallback is real.
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');
set local role authenticated;
insert into public.conversations(id,buyer_profile_id,seller_profile_id) values('f0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
insert into public.messages(id,conversation_id,sender_profile_id,body) values('f1000000-0000-4000-8000-000000000001','f0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','active sender');
select pg_temp.assert_true('active buyer creates and reads inbox',(select count(*)=1 from public.conversations where id='f0000000-0000-4000-8000-000000000001') and (select count(*)=1 from public.messages where conversation_id='f0000000-0000-4000-8000-000000000001'));
reset role;
-- Exercise all five legacy conversation RPC paths after F while the current one-profile
-- compatibility shape still holds. Their final state must match the setup-time baseline.
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');set local role authenticated;
select public.append_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
reset role;select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');set local role authenticated;
select public.remove_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
reset role;select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');set local role authenticated;
select public.hide_conversation('e0000000-0000-4000-8000-000000000001');
select public.unhide_conversation('e0000000-0000-4000-8000-000000000001');
select public.find_and_unhide_conversation('b2000000-0000-4000-8000-000000000001',null);
reset role;
select pg_temp.assert_true('five post-apply RPC paths preserve baseline',(select row(last_message_body,unread_for,hidden_at) from private.mp4e_before_behavior)=(select row(c.last_message_body,c.unread_for,s.hidden_at) from public.conversations c left join public.conversation_participant_state s on s.conversation_id=c.id and s.profile_id='a1000000-0000-4000-8000-000000000001' where c.id='e0000000-0000-4000-8000-000000000001'));
insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at) values('f0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',now()),('f0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001',null)
on conflict(conversation_id,profile_id) do update set hidden_at=excluded.hidden_at;
set local role authenticated;
select pg_temp.assert_true('active participant hide filters only own inbox',(select count(*)=0 from public.conversations where id='f0000000-0000-4000-8000-000000000001') and (select count(*)=1 from public.conversation_participant_state where conversation_id='f0000000-0000-4000-8000-000000000001' and profile_id='a1000000-0000-4000-8000-000000000001'));
reset role;
select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.assert_true('other participant hide is independent',(select count(*)=1 from public.conversations where id='f0000000-0000-4000-8000-000000000001') and (select count(*)=1 from public.conversation_participant_state where conversation_id='f0000000-0000-4000-8000-000000000001' and profile_id='b2000000-0000-4000-8000-000000000001'));
reset role;
select pg_temp.claims('cc000000-0000-4000-8000-000000000001','cc000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.assert_true('foreign actor reads no conversation message or state',(select count(*)=0 from public.conversations where id='f0000000-0000-4000-8000-000000000001') and (select count(*)=0 from public.messages where conversation_id='f0000000-0000-4000-8000-000000000001') and (select count(*)=0 from public.conversation_participant_state where conversation_id='f0000000-0000-4000-8000-000000000001'));
reset role;

-- Future shape begins only after explicit one-profile index drop.
drop index public.profiles_one_per_user_key;
insert into public.profiles(id,user_id,handle,created_at) values
 ('a1000000-0000-4000-8000-000000000002','aa000000-0000-4000-8000-000000000001','mp4f_a_sibling',now()),
 ('e5000000-0000-4000-8000-000000000001','ee000000-0000-4000-8000-000000000001','mp4f_missing_active',now());
insert into public.users(id,banned_at) values('dd000000-0000-4000-8000-000000000001',now()),('ee000000-0000-4000-8000-000000000001',null);
insert into public.profiles(id,user_id,handle,created_at) values('d4000000-0000-4000-8000-000000000001','dd000000-0000-4000-8000-000000000001','mp4f_banned',now());
insert into private.account_session_active_profiles(session_id,user_id,profile_id) values
 ('aa000000-0000-4000-8000-000000000011','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'),
 ('aa000000-0000-4000-8000-000000000012','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002'),
 ('bb000000-0000-4000-8000-000000000011','bb000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'),
 ('cc000000-0000-4000-8000-000000000011','cc000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001'),
 ('dd000000-0000-4000-8000-000000000011','dd000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001');

-- Disable structural guards only around denial probes: this proves RLS policy denial,
-- not a shared 42501 emitted by an MP4-E trigger.
alter table public.conversations disable trigger conversations_guard_participants;
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect_error('inactive sibling buyer policy deny','42501',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','a1000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect_error('same-account conversation policy deny neutral','42501',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002'),true);
select pg_temp.expect_error('deleted target FK deny after policy checks','23503',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','a1000000-0000-4000-8000-000000000001','ff000000-0000-4000-8000-000000000001'),true);
reset role;
select pg_temp.claims('cc000000-0000-4000-8000-000000000001','cc000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect_error('foreign buyer policy deny','42501',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
reset role;
select pg_temp.claims('dd000000-0000-4000-8000-000000000001','dd000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect_error('banned buyer policy deny','42501',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','d4000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
reset role;
select pg_temp.claims('ee000000-0000-4000-8000-000000000001','ee000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect_error('missing active buyer policy deny','42501',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','e5000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
reset role;alter table public.conversations enable trigger conversations_guard_participants;

-- Seed a historical future-shape both-owned row as owner. Reads/state must choose exact
-- active equality; writes must never choose the buyer branch and must deny same-account.
insert into public.conversations(id,buyer_profile_id,seller_profile_id) values('f0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at) values('f0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001',now()),('f0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002',null);
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000012');set local role authenticated;
select pg_temp.assert_true('both-owned row resolves active seller not first buyer',(select count(*)=1 from public.conversations where id='f0000000-0000-4000-8000-000000000002') and (select count(*)=1 from public.conversation_participant_state where conversation_id='f0000000-0000-4000-8000-000000000002' and profile_id='a1000000-0000-4000-8000-000000000002'));
select pg_temp.expect_error('find RPC caller_profile_count greater than one fails closed','P0001',format('select public.find_and_unhide_conversation(%L,null)','b2000000-0000-4000-8000-000000000001'));
reset role;

alter table public.messages disable trigger messages_guard_active_participant;
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect_error('inactive sibling sender active participant policy deny','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','f0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','deny'));
reset role;select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000012');set local role authenticated;
select pg_temp.expect_error('nonparticipant sender policy deny','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','f0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','deny'));
select pg_temp.expect_error('same-account message policy deny neutral','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','f0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','deny'),true);
reset role;
-- Emulate retained one-sided shape under owner-controlled guard disable.
alter table public.conversations disable trigger conversations_guard_participants;
update public.conversations set buyer_profile_id=null where id='f0000000-0000-4000-8000-000000000001';
alter table public.conversations enable trigger conversations_guard_participants;
update public.messages set sender_profile_id=null where id='f1000000-0000-4000-8000-000000000001';
select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.assert_true('survivor reads retained conversation and null-sender history',(select count(*)=1 from public.conversations where id='f0000000-0000-4000-8000-000000000001') and (select count(*)=1 from public.messages where id='f1000000-0000-4000-8000-000000000001'));
select pg_temp.expect_error('one-sided message policy deny','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','f0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','deny'));
reset role;alter table public.messages enable trigger messages_guard_active_participant;
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.assert_true('deleted side reads no retained history',(select count(*)=0 from public.conversations where id='f0000000-0000-4000-8000-000000000001') and (select count(*)=0 from public.messages where id='f1000000-0000-4000-8000-000000000001'));
reset role;

-- Strongest local Realtime-adjacent proof: the exact authenticated JWT/session GUC shape
-- resolves active identity under the policy role and all three tables remain published.
-- Logical decoding itself bypasses subscriber RLS and cannot prove Supabase Realtime worker
-- JWT propagation; that remains the explicit owner Gate-1 verification.
select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.assert_true('Realtime JWT policy context resolves active profile',public.current_active_profile_id()='b2000000-0000-4000-8000-000000000001');
reset role;
select pg_temp.assert_true('Realtime publication remains exact',(select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in('conversations','messages','conversation_participant_state')));
rollback;
\echo MP4F_POLICY_BEHAVIOR_MATRIX=PASS
\echo REALTIME_JWT_POLICY_CONTEXT_DATABASE=PASS
\echo REALTIME_WORKER_DELIVERY_OWNER_GATE=UNPROVEN
