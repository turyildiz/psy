\set ON_ERROR_STOP on
-- DISPOSABLE POSTGRESQL ONLY. Proves the §4.3 future-shape matrix without
-- enabling profile deletion or changing live FK actions. Final ROLLBACK removes fixtures.
begin;
create function pg_temp.assert_true(name text,ok boolean) returns void language plpgsql as $$begin if ok is not true then raise exception '% failed',name using errcode='XX000'; end if; raise notice 'PASS %',name; end$$;
create function pg_temp.expect_state(name text,want text,sql_text text) returns void language plpgsql as $$declare got text;begin begin execute sql_text;exception when others then got:=sqlstate;end;if got is distinct from want then raise exception '% expected %, got %',name,want,coalesce(got,'SUCCESS') using errcode='XX000';end if;raise notice 'PASS % SQLSTATE %',name,got;end$$;
create function pg_temp.claims(uid uuid,sid uuid) returns void language plpgsql as $$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated','session_id',sid)::text,true);end$$;

insert into public.profiles(id,user_id,handle) values
 ('a1000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000001','mp4e_a'),
 ('a1000000-0000-4000-8000-000000000002','aa000000-0000-4000-8000-000000000001','mp4e_a_sibling'),
 ('b2000000-0000-4000-8000-000000000001','bb000000-0000-4000-8000-000000000001','mp4e_b'),
 ('c3000000-0000-4000-8000-000000000001','cc000000-0000-4000-8000-000000000001','mp4e_c');
insert into private.account_session_active_profiles(session_id,user_id,profile_id) values
 ('aa000000-0000-4000-8000-000000000011','aa000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'),
 ('bb000000-0000-4000-8000-000000000011','bb000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001');
select pg_temp.claims('aa000000-0000-4000-8000-000000000001','aa000000-0000-4000-8000-000000000011');
set local role authenticated;
insert into public.conversations(buyer_profile_id,seller_profile_id) values('a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001') returning id as conv \gset
insert into public.messages(conversation_id,sender_profile_id,body) values(:'conv','a1000000-0000-4000-8000-000000000001','normal send') returning id as msg \gset
select pg_temp.assert_true('current all-present send updates summary',(select last_message_body='normal send' from public.conversations where id=:'conv'));
select pg_temp.expect_state('inactive sibling sender denied','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)',:'conv','a1000000-0000-4000-8000-000000000002','deny'));
select pg_temp.expect_state('nonparticipant sender denied','42501',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)',:'conv','c3000000-0000-4000-8000-000000000001','deny'));
select pg_temp.expect_state('ordinary null sender denied','23514',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,null,%L)',:'conv','deny'));
select pg_temp.expect_state('ordinary null buyer denied','23514',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(null,%L)', 'b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect_state('same participant conversation denied','23514',format('insert into public.conversations(buyer_profile_id,seller_profile_id) values(%L,%L)','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'));
reset role;

-- Emulate the HELD future FK cleanup under owner control. This is not a deletion.
alter table public.conversations disable trigger conversations_guard_participants;
update public.conversations set buyer_profile_id=null where id=:'conv';
alter table public.conversations enable trigger conversations_guard_participants;
alter table public.messages disable trigger messages_guard_active_participant;
update public.messages set sender_profile_id=null where id=:'msg';
alter table public.messages enable trigger messages_guard_active_participant;
select pg_temp.assert_true('survivor reads one-sided conversation',(select seller_profile_id='b2000000-0000-4000-8000-000000000001' and buyer_profile_id is null from public.conversations where id=:'conv'));
select pg_temp.assert_true('null sender history remains readable',(select sender_profile_id is null and body='normal send' from public.messages where id=:'msg'));
insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at) values(:'conv','b2000000-0000-4000-8000-000000000001',clock_timestamp());
update public.conversation_participant_state set hidden_at=null where conversation_id=:'conv' and profile_id='b2000000-0000-4000-8000-000000000001';
select pg_temp.assert_true('survivor hide-unhide state preserved',(select hidden_at is null from public.conversation_participant_state where conversation_id=:'conv' and profile_id='b2000000-0000-4000-8000-000000000001'));
select pg_temp.expect_state('deleted side state recreation denied','23514',format('insert into public.conversation_participant_state(conversation_id,profile_id) values(%L,%L)',:'conv','a1000000-0000-4000-8000-000000000001'));
select pg_temp.expect_state('missing side unread recreation denied','23514',format('update public.conversations set unread_for=array[%L] where id=%L','a1000000-0000-4000-8000-000000000001',:'conv'));
select pg_temp.expect_state('one-sided conversation message denied','55000',format('insert into public.messages(conversation_id,sender_profile_id,body) values(%L,%L,%L)',:'conv','b2000000-0000-4000-8000-000000000001','deny'));

-- Held cleanup-helper semantics: remove deleted UUIDs, preserve survivor markers.
alter table public.conversations disable trigger conversations_guard_unread;
update public.conversations set unread_for=array['a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001'] where id=:'conv';
alter table public.conversations enable trigger conversations_guard_unread;
create function pg_temp.future_cleanup_unread(target_conversation uuid,deleted_profile uuid) returns void language sql as $$
 update public.conversations set unread_for=array_remove(coalesce(unread_for,'{}'::text[]),deleted_profile::text) where id=target_conversation
$$;
select pg_temp.future_cleanup_unread(:'conv','a1000000-0000-4000-8000-000000000001');
select pg_temp.assert_true('future unread cleanup removes only deleted identifier',(select unread_for=array['b2000000-0000-4000-8000-000000000001'] from public.conversations where id=:'conv'));
update public.profiles set handle='mp4e_a_retired' where id='a1000000-0000-4000-8000-000000000001';
insert into public.profiles(id,user_id,handle) values('d4000000-0000-4000-8000-000000000001','dd000000-0000-4000-8000-000000000001','mp4e_a');
select pg_temp.assert_true('handle reuse does not attach new identity',not exists(select 1 from public.conversations where id=:'conv' and 'd4000000-0000-4000-8000-000000000001' in(buyer_profile_id,seller_profile_id)));
select pg_temp.assert_true('current FK delete actions remain held/live CASCADE',
 (select count(*)=5 from pg_constraint where conname in('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey'))
 and not exists(select 1 from pg_constraint where conname in('conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey','messages_sender_profile_id_fkey','conversation_participant_state_profile_id_fkey','account_session_active_profiles_profile_owner_fkey') and confdeltype<>'c'));
rollback;
\echo MP4E_FUTURE_SHAPE_MATRIX=PASS
