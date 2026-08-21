\set ON_ERROR_STOP on
-- DISPOSABLE POSTGRESQL ONLY. Proves current live-shape compatibility and the
-- §4.3 future-shape matrix without enabling deletion or changing live FK actions.
begin;
create function pg_temp.assert_true(name text,ok boolean) returns void language plpgsql as $$begin if ok is not true then raise exception '% failed',name using errcode='XX000';end if;raise notice 'PASS %',name;end$$;
create function pg_temp.expect_state(name text,want text,sql_text text) returns void language plpgsql as $$declare got text;begin begin execute sql_text;exception when others then got:=sqlstate;end;if got is distinct from want then raise exception '% expected %, got %',name,want,coalesce(got,'SUCCESS') using errcode='XX000';end if;raise notice 'PASS % SQLSTATE %',name,got;end$$;
create function pg_temp.claims(uid uuid,sid uuid) returns void language plpgsql as $$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated','session_id',sid)::text,true);end$$;

-- Current Gate-1 shape: one profile per account, no explicit active-state row.
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');
select pg_temp.assert_true('sole-profile fallback resolves current actor',public.current_active_profile_id()='a1000000-0000-4000-8000-000000000001' and not exists(select 1 from private.account_session_active_profiles where session_id='aa000000-0000-4000-8000-000000000011'));
set local role authenticated;
insert into public.conversations(id,buyer_profile_id,seller_profile_id) values('e0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
insert into public.messages(id,conversation_id,sender_profile_id,body) values('e1000000-0000-4000-8000-000000000002','e0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001','after behavior');
select public.append_unread_for('e0000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001');
select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');
select public.remove_unread_for('e0000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001');
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');
select public.hide_conversation('e0000000-0000-4000-8000-000000000002');
select public.unhide_conversation('e0000000-0000-4000-8000-000000000002');
select pg_temp.assert_true('find-and-unhide current path returns same conversation',public.find_and_unhide_conversation('b2000000-0000-4000-8000-000000000001',null)='e0000000-0000-4000-8000-000000000002');
reset role;
select pg_temp.assert_true('real before-after current-shape differential',
 (select last_message_body='before behavior' and unread_for='{}'::text[] and hidden_at is null from private.mp4e_before_behavior)
 and (select last_message_body='after behavior' and unread_for='{}'::text[] from public.conversations where id='e0000000-0000-4000-8000-000000000002')
 and (select hidden_at is null from public.conversation_participant_state where conversation_id='e0000000-0000-4000-8000-000000000002' and profile_id='a1000000-0000-4000-8000-000000000001'));
\echo CURRENT_BEFORE_AFTER_DIFFERENTIAL=PASS

-- Explicitly labelled future multi-profile fixture begins only after current-shape proof.
drop index public.profiles_one_per_user_key;
insert into public.profiles(id,user_id,handle) values('a1000000-0000-4000-8000-000000000002','aa000000-0000-4000-8000-000000000001','mp4e_a_sibling');
insert into private.account_session_active_profiles(session_id,user_id,profile_id) values
 ('aa000000-0000-4000-8000-000000000011','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'),
 ('bb000000-0000-4000-8000-000000000011','bb000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'),
 ('cc000000-0000-4000-8000-000000000011','cc000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001');
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');
set local role authenticated;
select pg_temp.expect_state('inactive sibling sender denied by active guard','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','e0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','deny'));
select pg_temp.expect_state('ordinary null sender denied','23514',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,null,%L)','e0000000-0000-4000-8000-000000000002','deny'));
select pg_temp.expect_state('ordinary null buyer denied','23514',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(null,%L)','b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect_state('same participant conversation denied','23514',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'));
reset role;
select pg_temp.expect_state('canonical UUID duplicate unread denied','23514',format('update public.conversations set unread_for=array[%L,%L] where id=%L','b2000000-0000-4000-8000-000000000001','B2000000-0000-4000-8000-000000000001','e0000000-0000-4000-8000-000000000002'));
select pg_temp.expect_state('noncanonical unread identifier denied','23514',format('update public.conversations set unread_for=array[%L] where id=%L','{b2000000-0000-4000-8000-000000000001}','e0000000-0000-4000-8000-000000000002'));
select pg_temp.claims('cc000000-0000-4000-8000-000000000001','cc000000-0000-4000-8000-000000000011');
set local role authenticated;
select pg_temp.expect_state('nonparticipant sender denied','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','e0000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000001','deny'));
reset role;
select set_config('request.jwt.claims','{}',true);
select pg_temp.expect_state('JWT-less trusted message writer boundary','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','e0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001','deny'));
insert into public.conversations(id,buyer_profile_id,seller_profile_id) values('e0000000-0000-4000-8000-000000000003','a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
select pg_temp.assert_true('conversation guard is structural not active-authority',(select count(*)=1 from public.conversations where id='e0000000-0000-4000-8000-000000000003'));

-- Emulate only the HELD future FK cleanup under owner-controlled trigger disable.
alter table public.conversations disable trigger conversations_guard_participants;
update public.conversations set buyer_profile_id=null where id='e0000000-0000-4000-8000-000000000002';
alter table public.conversations enable trigger conversations_guard_participants;
alter table public.messages disable trigger messages_guard_active_participant;
update public.messages set sender_profile_id=null where id='e1000000-0000-4000-8000-000000000002';
alter table public.messages enable trigger messages_guard_active_participant;

-- Survivor proof executes as survivor B through live-equivalent RLS/JWT.
select pg_temp.claims('bb000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000011');
set local role authenticated;
select pg_temp.assert_true('survivor reads one-sided conversation under RLS',(select seller_profile_id='b2000000-0000-4000-8000-000000000001' and buyer_profile_id is null from public.conversations where id='e0000000-0000-4000-8000-000000000002'));
select pg_temp.assert_true('survivor reads null-sender history under RLS',(select sender_profile_id is null and body='after behavior' from public.messages where id='e1000000-0000-4000-8000-000000000002'));
select public.hide_conversation('e0000000-0000-4000-8000-000000000002');
select public.unhide_conversation('e0000000-0000-4000-8000-000000000002');
select pg_temp.expect_state('missing-side unread RPC denied','P0001',format('select public.append_unread_for(%L,%L)','e0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001'));
select pg_temp.expect_state('one-sided conversation message denied','55000',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)','e0000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001','deny'));
reset role;
\echo SURVIVOR_RLS_READ=PASS

-- The removed/deleted-side identity A can no longer authorize retained history.
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');
set local role authenticated;
select pg_temp.expect_state('deleted-side authorization denied','P0001',format('select public.hide_conversation(%L)','e0000000-0000-4000-8000-000000000002'));
reset role;
select pg_temp.expect_state('deleted side state recreation denied','23514',format('insert into public.conversation_participant_state(conversation_id,profile_id) values(%L,%L)','e0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001'));
select pg_temp.expect_state('missing side unread recreation denied','23514',format('update public.conversations set unread_for=array[%L] where id=%L','a1000000-0000-4000-8000-000000000001','e0000000-0000-4000-8000-000000000002'));

-- Held cleanup-helper semantics: remove only the deleted UUID.
alter table public.conversations disable trigger conversations_guard_unread;
update public.conversations set unread_for=array['a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'] where id='e0000000-0000-4000-8000-000000000002';
alter table public.conversations enable trigger conversations_guard_unread;
create function pg_temp.future_cleanup_unread(target_conversation uuid,deleted_profile uuid) returns void language sql as $$update public.conversations set unread_for=array_remove(coalesce(unread_for,'{}'::text[]),deleted_profile::text) where id=target_conversation$$;
select pg_temp.future_cleanup_unread('e0000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000001');
select pg_temp.assert_true('future unread cleanup removes only deleted identifier',(select unread_for=array['b2000000-0000-4000-8000-000000000001'] from public.conversations where id='e0000000-0000-4000-8000-000000000002'));

-- Non-tautological handle-reuse proof: new D actively queries/contact-restores using
-- A's old handle, yet UUID-based history remains invisible and unattached.
update public.profiles set handle='mp4e_a_retired' where id='a1000000-0000-4000-8000-000000000001';
insert into public.users(id) values('dd000000-0000-4000-8000-000000000001');
insert into public.profiles(id,user_id,handle) values('d4000000-0000-4000-8000-000000000001','dd000000-0000-4000-8000-000000000001','mp4e_a');
insert into private.account_session_active_profiles(session_id,user_id,profile_id) values('dd000000-0000-4000-8000-000000000011','dd000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000001');
select pg_temp.claims('dd000000-0000-4000-8000-000000000001','dd000000-0000-4000-8000-000000000011');
set local role authenticated;
select pg_temp.assert_true('reused handle contact lookup does not return retained history',public.find_and_unhide_conversation('b2000000-0000-4000-8000-000000000001',null) is null);
select pg_temp.assert_true('reused handle principal cannot read retained history',(select count(*)=0 from public.conversations where id='e0000000-0000-4000-8000-000000000002'));
reset role;
select pg_temp.assert_true('current FK delete actions remain held live CASCADE',(select count(*)=5 from pg_constraint where conname in('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey')) and not exists(select 1 from pg_constraint where conname in('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey') and confdeltype<>'c'));
rollback;
\echo MP4E_FUTURE_SHAPE_MATRIX=PASS
