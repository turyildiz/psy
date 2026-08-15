\set ON_ERROR_STOP on
-- DISPOSABLE POSTGRESQL ONLY. Every fixture mutation is enclosed by the final ROLLBACK.
-- Requires the exact MP4-D source fixture plus the applied Slice MP4-A helpers.
begin;
set local check_function_bodies=off;
create or replace function auth.role() returns text language sql stable as $$select auth.jwt()->>'role'$$;
create or replace function public.profile_owner_is_banned(target_profile_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p join public.users u on u.id=p.user_id where p.id=$1 and u.banned_at is not null)
$$;
create table public.post_link_blocklist(domain text primary key);

drop index public.profiles_one_per_user_key;
insert into auth.users(id,raw_user_meta_data,email) values
 ('a1000000-0000-0000-0000-000000000001','{}','a@fixture.test'),
 ('b2000000-0000-0000-0000-000000000002','{}','b@fixture.test'),
 ('c3000000-0000-0000-0000-000000000003','{}','c@fixture.test');

select id as a1 from public.profiles where user_id='a1000000-0000-0000-0000-000000000001' \gset
select id as b1 from public.profiles where user_id='b2000000-0000-0000-0000-000000000002' \gset
select id as c1 from public.profiles where user_id='c3000000-0000-0000-0000-000000000003' \gset
insert into public.profiles(id,user_id,type,handle,display_name)
values ('a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-000000000001','personal','mp4d_sibling','Sibling A2');
\set a2 'a1000000-0000-0000-0000-000000000012'
update public.users set banned_at=clock_timestamp() where id='c3000000-0000-0000-0000-000000000003';

insert into private.account_session_active_profiles(session_id,user_id,profile_id) values
 ('aa000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',:'a1'),
 ('bb000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002',:'b1'),
 ('cc000000-0000-0000-0000-000000000003','c3000000-0000-0000-0000-000000000003',:'c1');

create function pg_temp.expect_state(test_name text,expected_state text,statement_text text) returns void language plpgsql as $$
declare got text; begin
 begin execute statement_text; exception when others then got:=sqlstate; end;
 if got is distinct from expected_state then raise exception '% expected %, got %',test_name,expected_state,coalesce(got,'SUCCESS') using errcode='XX000'; end if;
 raise notice 'PASS % SQLSTATE %',test_name,got;
end$$;
create function pg_temp.assert_true(test_name text,ok boolean) returns void language plpgsql as $$begin
 if ok is not true then raise exception '% failed',test_name using errcode='XX000'; end if;
 raise notice 'PASS %',test_name;
end$$;
create function pg_temp.claims(uid uuid,sid uuid) returns void language plpgsql as $$begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated','session_id',sid)::text,true);
end$$;

set local role authenticated;
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');
select public.create_post(:'a1','active create',array[]::text[],true) as post_main \gset
select public.create_post(:'a1','active update target',array[]::text[],true) as post_update \gset
select public.create_post(:'a1','active delete target',array[]::text[],true) as post_delete \gset
select public.create_post(:'a1','inactive delete target',array[]::text[],true) as post_inactive_delete \gset
select public.update_post(:'post_update','active update passed',array[]::text[],true);
select public.delete_own_post(:'post_delete');
select pg_temp.expect_state('create inactive sibling','42501',format('select public.create_post(%L::uuid,%L,array[]::text[],true)',:'a2','deny'));
select pg_temp.expect_state('create foreign','42501',format('select public.create_post(%L::uuid,%L,array[]::text[],true)',:'b1','deny'));
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000099');
select pg_temp.expect_state('create missing active','42501',format('select public.create_post(%L::uuid,%L,array[]::text[],true)',:'a1','deny'));
select pg_temp.claims('c3000000-0000-0000-0000-000000000003','cc000000-0000-0000-0000-000000000003');
select pg_temp.expect_state('create banned','42501',format('select public.create_post(%L::uuid,%L,array[]::text[],true)',:'c1','deny'));

select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');
reset role;
update private.account_session_active_profiles set profile_id=:'a2' where session_id='aa000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.expect_state('update inactive sibling','42501',format('select public.update_post(%L::uuid,%L,array[]::text[],true)',:'post_update','deny'));
select pg_temp.expect_state('delete inactive sibling','42501',format('select public.delete_own_post(%L::uuid)',:'post_inactive_delete'));
select pg_temp.claims('b2000000-0000-0000-0000-000000000002','bb000000-0000-0000-0000-000000000002');
select pg_temp.expect_state('update foreign','42501',format('select public.update_post(%L::uuid,%L,array[]::text[],true)',:'post_update','deny'));
select pg_temp.expect_state('delete foreign','42501',format('select public.delete_own_post(%L::uuid)',:'post_inactive_delete'));
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000099');
select pg_temp.expect_state('update missing active','42501',format('select public.update_post(%L::uuid,%L,array[]::text[],true)',:'post_update','deny'));
select pg_temp.expect_state('delete missing active','42501',format('select public.delete_own_post(%L::uuid)',:'post_inactive_delete'));
select pg_temp.claims('c3000000-0000-0000-0000-000000000003','cc000000-0000-0000-0000-000000000003');
select pg_temp.expect_state('update banned','42501',format('select public.update_post(%L::uuid,%L,array[]::text[],true)',:'post_update','deny'));
select pg_temp.expect_state('delete banned','42501',format('select public.delete_own_post(%L::uuid)',:'post_inactive_delete'));

-- Reaction matrix and exact one-row-per-profile mechanics.
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');
select public.set_post_reaction(:'post_main',:'a2','love') as reaction_a2 \gset
select public.set_post_reaction(:'post_main',:'a2','fire') as reaction_a2_updated \gset
select pg_temp.assert_true('same profile reaction upserts stable row',:'reaction_a2'=:'reaction_a2_updated');
reset role;
update private.account_session_active_profiles set profile_id=:'a1' where session_id='aa000000-0000-0000-0000-000000000001';
set local role authenticated;
select public.set_post_reaction(:'post_main',:'a1','love') as reaction_a1 \gset
select pg_temp.expect_state('set inactive sibling','42501',format('select public.set_post_reaction(%L::uuid,%L::uuid,%L)',:'post_main',:'a2','love'));
select pg_temp.expect_state('set foreign','42501',format('select public.set_post_reaction(%L::uuid,%L::uuid,%L)',:'post_main',:'b1','love'));
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000099');
select pg_temp.expect_state('set missing active','42501',format('select public.set_post_reaction(%L::uuid,%L::uuid,%L)',:'post_main',:'a1','love'));
select pg_temp.claims('c3000000-0000-0000-0000-000000000003','cc000000-0000-0000-0000-000000000003');
select pg_temp.expect_state('set banned','42501',format('select public.set_post_reaction(%L::uuid,%L::uuid,%L)',:'post_main',:'c1','love'));
reset role;
select profile_id,reaction_code from public.post_reactions where post_id=:'post_main' order by profile_id;
select pg_temp.assert_true('siblings independently react',count(*)=2 and count(distinct profile_id)=2) from public.post_reactions where post_id=:'post_main';
insert into public.post_reactions(post_id,profile_id,reaction_code) values (:'post_main',:'b1','love') returning id as reaction_b1 \gset
insert into public.post_reactions(post_id,profile_id,reaction_code) values (:'post_main',:'c1','love') returning id as reaction_c1 \gset
set local role authenticated;
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');
select public.remove_post_reaction(:'post_main',:'a1');
select pg_temp.expect_state('remove inactive sibling','42501',format('select public.remove_post_reaction(%L::uuid,%L::uuid)',:'post_main',:'a2'));
select pg_temp.expect_state('remove foreign','42501',format('select public.remove_post_reaction(%L::uuid,%L::uuid)',:'post_main',:'b1'));
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000099');
select pg_temp.expect_state('remove missing active','42501',format('select public.remove_post_reaction(%L::uuid,%L::uuid)',:'post_main',:'a2'));
select pg_temp.claims('c3000000-0000-0000-0000-000000000003','cc000000-0000-0000-0000-000000000003');
select pg_temp.expect_state('remove banned','42501',format('select public.remove_post_reaction(%L::uuid,%L::uuid)',:'post_main',:'c1'));

-- Direct reaction DML remains closed to authenticated; trigger identity is immutable for owner paths.
select pg_temp.claims('b2000000-0000-0000-0000-000000000002','bb000000-0000-0000-0000-000000000002');
select pg_temp.expect_state('direct reaction insert denied','42501',format('insert into public.post_reactions(post_id,profile_id,reaction_code) values (%L::uuid,%L::uuid,%L)',:'post_main',:'b1','fire'));
select pg_temp.expect_state('direct reaction update denied','42501',format('update public.post_reactions set reaction_code=%L where id=%L::uuid','fire',:'reaction_b1'));
select pg_temp.expect_state('direct reaction delete denied','42501',format('delete from public.post_reactions where id=%L::uuid',:'reaction_b1'));
reset role;
select pg_temp.expect_state('reaction post identity immutable','42501',format('update public.post_reactions set post_id=%L::uuid where id=%L::uuid',:'post_update',:'reaction_b1'));
select pg_temp.expect_state('reaction profile identity immutable','42501',format('update public.post_reactions set profile_id=%L::uuid where id=%L::uuid',:'a2',:'reaction_b1'));

-- Account-level limiter cannot be bypassed by switching profile.
update public.post_write_rate_limits set attempts=array(select clock_timestamp()-interval '1 minute' from generate_series(1,19)) where user_id='a1000000-0000-0000-0000-000000000001';
update private.account_session_active_profiles set profile_id=:'a1' where session_id='aa000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');
select public.create_post(:'a1','quota twentieth',array[]::text[],true);
reset role;
update private.account_session_active_profiles set profile_id=:'a2' where session_id='aa000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.expect_state('profile switch cannot bypass account limiter','P0001',format('select public.create_post(%L::uuid,%L,array[]::text[],true)',:'a2','quota blocked'));
reset role;
select pg_temp.assert_true('one account limiter row remains at twenty',count(*)=1 and max(cardinality(attempts))=20) from public.post_write_rate_limits where user_id='a1000000-0000-0000-0000-000000000001';

-- Public visible post/reaction reads stay successful for anon.
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.assert_true('anon visible post read',count(*)>=1) from public.posts where id=:'post_main';
select pg_temp.assert_true('anon visible reaction read',count(*)>=1) from public.post_reactions where post_id=:'post_main';
reset role;

rollback;
\echo MP4D_BEHAVIOR=PASS
