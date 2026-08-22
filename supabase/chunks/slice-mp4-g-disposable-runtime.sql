\set ON_ERROR_STOP on
-- DISPOSABLE POSTGRESQL ONLY: exact RPC/trigger allow-deny and nullable matrix.
begin;
create function pg_temp.assert_true(name text,ok boolean)returns void language plpgsql as $$begin if ok is not true then raise exception '% failed',name using errcode='XX000';end if;raise notice 'PASS %',name;end$$;
create function pg_temp.claims(uid uuid,sid uuid)returns void language plpgsql as $$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated','session_id',sid)::text,true);end$$;
create function pg_temp.expect(name text,want_state text,want_message text,sql_text text)returns void language plpgsql as $$declare got_state text;got_message text;begin begin execute sql_text;exception when others then get stacked diagnostics got_state=returned_sqlstate,got_message=message_text;end;if got_state is distinct from want_state or got_message is distinct from want_message then raise exception '% expected [%] %, got [%] %',name,want_state,want_message,coalesce(got_state,'SUCCESS'),coalesce(got_message,'') using errcode='XX000';end if;raise notice 'PASS % SQLSTATE % message %',name,got_state,got_message;end$$;
create function pg_temp.expect_active_required(prefix text)returns void language plpgsql as $$begin
 perform pg_temp.expect(prefix||' append','P0001','Active profile selection is required',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
 perform pg_temp.expect(prefix||' remove','P0001','Active profile selection is required',format('select public.remove_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'));
 perform pg_temp.expect(prefix||' hide','P0001','Active profile selection is required',format('select public.hide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));
 perform pg_temp.expect(prefix||' unhide','P0001','Active profile selection is required',format('select public.unhide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));
 perform pg_temp.expect(prefix||' find','P0001','Active profile selection is required',format('select public.find_and_unhide_conversation(%L,null)','b2000000-0000-4000-8000-000000000001'));
end$$;

-- Current one-profile live write shapes through all five RPCs, using sole-profile fallback.
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');set local role authenticated;
select public.append_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
select public.hide_conversation('e0000000-0000-4000-8000-000000000001');
select public.unhide_conversation('e0000000-0000-4000-8000-000000000001');
select pg_temp.assert_true('sole-profile find/unhide exact',public.find_and_unhide_conversation('b2000000-0000-4000-8000-000000000001',null)='e0000000-0000-4000-8000-000000000001');reset role;
select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');set local role authenticated;
select public.remove_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');reset role;
select pg_temp.assert_true('sole-profile five-RPC write shapes pass',(select unread_for='{}'::text[] from public.conversations where id='e0000000-0000-4000-8000-000000000001'));

-- Trigger completion: recipient alone is unhidden; sender state and exact parent summary are preserved/updated.
insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at)values
 ('e0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',clock_timestamp()),
 ('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001',clock_timestamp())
on conflict(conversation_id,profile_id)do update set hidden_at=excluded.hidden_at;
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');
insert into public.messages(id,conversation_id,sender_profile_id,body,created_at)values('91000000-0000-4000-8000-000000000001','e0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','trigger summary exact','2026-08-22 12:00:00+00');
select pg_temp.assert_true('recipient unhidden sender hidden unchanged',(select hidden_at is not null from public.conversation_participant_state where conversation_id='e0000000-0000-4000-8000-000000000001'and profile_id='a1000000-0000-4000-8000-000000000001')and(select hidden_at is null from public.conversation_participant_state where conversation_id='e0000000-0000-4000-8000-000000000001'and profile_id='b2000000-0000-4000-8000-000000000001'));
select pg_temp.assert_true('parent summary exact',(select last_message_at='2026-08-22 12:00:00+00'::timestamptz and last_message_body='trigger summary exact' from public.conversations where id='e0000000-0000-4000-8000-000000000001'));

-- Future shape and explicit active rows.
drop index public.profiles_one_per_user_key;
insert into public.users(id,banned_at)values('dd000000-0000-4000-8000-000000000001',now()),('ee000000-0000-4000-8000-000000000001',null);
insert into public.profiles(id,user_id,handle,created_at)values
 ('a1000000-0000-4000-8000-000000000002','aa000000-0000-4000-8000-000000000001','mp4g_a_sibling',now()),
 ('d4000000-0000-4000-8000-000000000001','dd000000-0000-4000-8000-000000000001','mp4g_banned',now()),
 ('e5000000-0000-4000-8000-000000000001','ee000000-0000-4000-8000-000000000001','mp4g_missing_active',now());
insert into private.account_session_active_profiles(session_id,user_id,profile_id)values
 ('aa000000-0000-4000-8000-000000000011','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'),
 ('aa000000-0000-4000-8000-000000000012','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002'),
 ('bb000000-0000-4000-8000-000000000011','bb000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'),
 ('cc000000-0000-4000-8000-000000000011','cc000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001'),
 ('dd000000-0000-4000-8000-000000000011','dd000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001');
-- Future stale/mismatched rows are impossible under the FK today; bypass only
-- the disposable fixture trigger to prove the resolver still fails closed.
alter table private.account_session_active_profiles disable trigger all;
insert into private.account_session_active_profiles(session_id,user_id,profile_id)values
 ('ee000000-0000-4000-8000-000000000012','ee000000-0000-4000-8000-000000000001','ff000000-0000-4000-8000-000000000001'),
 ('ee000000-0000-4000-8000-000000000013','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001');
alter table private.account_session_active_profiles enable trigger all;

-- Inactive sibling and foreign denial for every scoped RPC.
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000012');set local role authenticated;
select pg_temp.expect('inactive append','P0001','Not a conversation participant',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect('inactive remove','P0001','Not a conversation participant',format('select public.remove_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002'));
select pg_temp.expect('inactive hide','P0001','Conversation not found or caller is not a participant',format('select public.hide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));
select pg_temp.expect('inactive unhide','P0001','Conversation not found or caller is not a participant',format('select public.unhide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));
select pg_temp.assert_true('inactive find cannot open sibling conversation',public.find_and_unhide_conversation('b2000000-0000-4000-8000-000000000001',null)is null);reset role;
select pg_temp.claims('cc000000-0000-4000-8000-000000000001','cc000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect('foreign append','P0001','Not a conversation participant',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect('foreign remove','P0001','Not a conversation participant',format('select public.remove_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001'));
select pg_temp.expect('foreign hide','P0001','Conversation not found or caller is not a participant',format('select public.hide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));
select pg_temp.expect('foreign unhide','P0001','Conversation not found or caller is not a participant',format('select public.unhide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));reset role;

-- Missing, stale, mismatched, malformed-session, and banned paths across every RPC.
select pg_temp.claims('ee000000-0000-4000-8000-000000000001','ee000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect_active_required('missing active');reset role;
select pg_temp.claims('ee000000-0000-4000-8000-000000000001','ee000000-0000-4000-8000-000000000012');set local role authenticated;select pg_temp.expect_active_required('stale active');reset role;
select pg_temp.claims('ee000000-0000-4000-8000-000000000001','ee000000-0000-4000-8000-000000000013');set local role authenticated;select pg_temp.expect_active_required('mismatched active');reset role;
select set_config('request.jwt.claims','{"sub":"ee000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"not-a-uuid"}',true);set local role authenticated;select pg_temp.expect_active_required('malformed session');reset role;
select pg_temp.claims('dd000000-0000-4000-8000-000000000001','dd000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect('banned append','P0001','Banned accounts cannot change unread state',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect('banned remove','P0001','Banned accounts cannot change unread state',format('select public.remove_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001'));
select pg_temp.expect('banned hide','P0001','Banned accounts cannot hide conversations',format('select public.hide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));
select pg_temp.expect('banned unhide','P0001','Banned accounts cannot unhide conversations',format('select public.unhide_conversation(%L)','e0000000-0000-4000-8000-000000000001'));
select pg_temp.expect('banned find','P0001','Banned accounts cannot open conversations',format('select public.find_and_unhide_conversation(%L,null)','b2000000-0000-4000-8000-000000000001'));reset role;

-- Malformed/wrong targets and contact denials assert exact guard messages.
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');set local role authenticated;
select pg_temp.expect('malformed append target','22P02','invalid input syntax for type uuid: "bad-uuid"',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','bad-uuid'));
select pg_temp.expect('malformed remove target','22P02','invalid input syntax for type uuid: "bad-uuid"',format('select public.remove_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','bad-uuid'));
select pg_temp.expect('wrong append participant','P0001','Invalid unread recipient',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001'));
select pg_temp.expect('wrong remove participant','P0001','Users may only clear their own unread state',format('select public.remove_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect('same profile contact','P0001','You can''t contact your own profile',format('select public.find_and_unhide_conversation(%L,null)','a1000000-0000-4000-8000-000000000001'));
select pg_temp.expect('sibling contact','P0001','You can''t contact your own profile',format('select public.find_and_unhide_conversation(%L,null)','a1000000-0000-4000-8000-000000000002'));
select pg_temp.expect('deleted target contact','P0001','Target profile does not exist',format('select public.find_and_unhide_conversation(%L,null)','ff000000-0000-4000-8000-000000000001'));
select pg_temp.expect('malformed listing ownership','P0001','Listing does not belong to the target profile',format('select public.find_and_unhide_conversation(%L,%L)','b2000000-0000-4000-8000-000000000001','ff000000-0000-4000-8000-000000000002'));reset role;

-- Historical impossible dual-owned row: fail explicitly, never choose buyer first.
insert into public.conversations(id,buyer_profile_id,seller_profile_id)values('90000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002');
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000012');set local role authenticated;
select pg_temp.expect('dual-owned append explicit fail','P0001','Both conversation participants belong to the caller account',format('select public.append_unread_for(%L,%L)','90000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001'));
select pg_temp.expect('dual-owned remove explicit fail','P0001','Both conversation participants belong to the caller account',format('select public.remove_unread_for(%L,%L)','90000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002'));
select pg_temp.expect('dual-owned hide explicit fail','P0001','Both conversation participants belong to the caller account',format('select public.hide_conversation(%L)','90000000-0000-4000-8000-000000000002'));
select pg_temp.expect('dual-owned unhide explicit fail','P0001','Both conversation participants belong to the caller account',format('select public.unhide_conversation(%L)','90000000-0000-4000-8000-000000000002'));reset role;
select pg_temp.assert_true('dual-owned fail created no participant state',not exists(select 1 from public.conversation_participant_state where conversation_id='90000000-0000-4000-8000-000000000002'));

-- Retained one-sided row: survivor may hide/unhide and clear only their own unread
-- marker; append/message remain read-only and no deleted state is recreated.
alter table public.conversations disable trigger conversations_guard_participants;
update public.conversations set buyer_profile_id=null,unread_for=array['b2000000-0000-4000-8000-000000000001']::text[] where id='e0000000-0000-4000-8000-000000000001';
alter table public.conversations enable trigger conversations_guard_participants;
delete from public.conversation_participant_state where conversation_id='e0000000-0000-4000-8000-000000000001';
select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');set local role authenticated;
select public.hide_conversation('e0000000-0000-4000-8000-000000000001');select public.unhide_conversation('e0000000-0000-4000-8000-000000000001');
select pg_temp.expect('retained append read-only','55000','One-sided retained conversations are read-only',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'));
select public.remove_unread_for('e0000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
select pg_temp.assert_true('retained survivor unread cleared',(select unread_for='{}'::text[] from public.conversations where id='e0000000-0000-4000-8000-000000000001'));
select pg_temp.assert_true('retained find cannot attach deleted side',public.find_and_unhide_conversation('a1000000-0000-4000-8000-000000000001',null)is null);reset role;
select pg_temp.assert_true('retained state only survivor',(select count(*)=1 and bool_and(profile_id='b2000000-0000-4000-8000-000000000001')from public.conversation_participant_state where conversation_id='e0000000-0000-4000-8000-000000000001'));

select pg_temp.assert_true('trigger functions not client-callable',not has_function_privilege('anon','public.unhide_conversation_for_message_recipient()','EXECUTE')and not has_function_privilege('authenticated','public.unhide_conversation_for_message_recipient()','EXECUTE')and not has_function_privilege('anon','public.update_conversation_last_message()','EXECUTE')and not has_function_privilege('authenticated','public.update_conversation_last_message()','EXECUTE'));
rollback;
\echo MP4G_RPC_TRIGGER_BEHAVIOR_MATRIX=PASS
\echo SESSION_COVERAGE=UNPROVEN
\echo REALTIME_WORKER_DELIVERY_OWNER_GATE=UNPROVEN
