\set ON_ERROR_STOP on
begin;
set local check_function_bodies=off;
create or replace function auth.role() returns text language sql stable as $$select auth.jwt()->>'role'$$;
create or replace function public.profile_owner_is_banned(target_profile_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p join public.users u on u.id=p.user_id where p.id=$1 and u.banned_at is not null)
$$;
create table if not exists public.post_link_blocklist(domain text primary key);
drop index if exists public.profiles_one_per_user_key;
insert into auth.users(id,raw_user_meta_data,email) values
 ('a1000000-0000-0000-0000-000000000001','{}','a@fixture.test'),
 ('b2000000-0000-0000-0000-000000000002','{}','b@fixture.test'),
 ('c3000000-0000-0000-0000-000000000003','{}','c@fixture.test');
select id as a1 from public.profiles where user_id='a1000000-0000-0000-0000-000000000001' \gset
select id as b1 from public.profiles where user_id='b2000000-0000-0000-0000-000000000002' \gset
select id as c1 from public.profiles where user_id='c3000000-0000-0000-0000-000000000003' \gset
insert into public.profiles(id,user_id,type,handle,display_name)
values ('a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-000000000001','personal','highlights_sibling','Sibling A2');
\set a2 'a1000000-0000-0000-0000-000000000012'
update public.users set banned_at=clock_timestamp() where id='c3000000-0000-0000-0000-000000000003';
insert into private.account_session_active_profiles(session_id,user_id,profile_id) values
 ('aa000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001',:'a1'),
 ('bb000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000002',:'b1'),
 ('cc000000-0000-0000-0000-000000000003','c3000000-0000-0000-0000-000000000003',:'c1');
create function pg_temp.expect_state(test_name text,expected_state text,statement_text text) returns void language plpgsql as $$
declare got text; begin begin execute statement_text; exception when others then got:=sqlstate; end;
if got is distinct from expected_state then raise exception '% expected %, got %',test_name,expected_state,coalesce(got,'SUCCESS') using errcode='XX000'; end if;
raise notice 'PASS % SQLSTATE %',test_name,got; end$$;
create function pg_temp.assert_true(test_name text,ok boolean) returns void language plpgsql as $$begin
if ok is not true then raise exception '% failed',test_name using errcode='XX000'; end if; raise notice 'PASS %',test_name; end$$;
create function pg_temp.claims(uid uuid,sid uuid) returns void language plpgsql as $$begin
perform set_config('request.jwt.claims',jsonb_build_object('sub',uid,'role','authenticated','session_id',sid)::text,true); end$$;

set local role authenticated;
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');
select public.create_post(:'a1','highlight one',array[]::text[],true) p1 \gset
select public.create_post(:'a1','highlight two',array[]::text[],true) p2 \gset
select public.create_post(:'a1','highlight three',array[]::text[],true) p3 \gset
select public.create_post(:'a1','highlight four',array[]::text[],true) p4 \gset
select public.create_post(:'a1','highlight five',array[]::text[],true) p5 \gset
select public.create_post(:'a1','highlight six',array[]::text[],true) p6 \gset
select public.create_post(:'a1','members only highlight control',array[]::text[],false) pmembers \gset
reset role;
insert into public.posts(profile_id,body) values (:'a2','inactive post') returning id as pinactive \gset
insert into public.posts(profile_id,body) values (:'b1','foreign post') returning id as pforeign \gset
set local role authenticated;
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');

select public.toggle_post_highlight(:'p1',true);
select public.toggle_post_highlight(:'p2',true);
select public.toggle_post_highlight(:'p3',true);
select public.toggle_post_highlight(:'p4',true);
select public.toggle_post_highlight(:'p5',true);
select pg_temp.expect_state('sixth highlight blocked','P5005',format('select public.toggle_post_highlight(%L::uuid,true)',:'p6'));
select pg_temp.assert_true('exactly five highlighted',count(*)=5) from public.posts where profile_id=:'a1' and is_highlighted;
select pg_temp.assert_true('highlight timestamps populated',count(*)=5) from public.posts where profile_id=:'a1' and is_highlighted and highlighted_at is not null;
select pg_temp.assert_true('same-transaction highlight timestamps order newest first',
  (select highlighted_at from public.posts where id=:'p5') >
  (select highlighted_at from public.posts where id=:'p4'));
select pg_temp.assert_true('highlight query order newest first',
  (select array_agg(id order by highlighted_at desc,id desc) from public.posts where profile_id=:'a1' and is_highlighted)
  = array[:'p5'::uuid,:'p4'::uuid,:'p3'::uuid,:'p2'::uuid,:'p1'::uuid]);
select public.toggle_post_highlight(:'p1',true);
select pg_temp.assert_true('idempotent true keeps five',count(*)=5) from public.posts where profile_id=:'a1' and is_highlighted;
select public.toggle_post_highlight(:'p1',false);
select public.toggle_post_highlight(:'p6',true);
select pg_temp.assert_true('unhighlight frees one slot',count(*)=5 and bool_and(highlighted_at is not null)) from public.posts where profile_id=:'a1' and is_highlighted;
select pg_temp.expect_state('inactive sibling denied','42501',format('select public.toggle_post_highlight(%L::uuid,true)',:'pinactive'));
select pg_temp.expect_state('foreign post denied','42501',format('select public.toggle_post_highlight(%L::uuid,true)',:'pforeign'));
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000099');
select pg_temp.expect_state('missing active denied','42501',format('select public.toggle_post_highlight(%L::uuid,false)',:'p2'));
select pg_temp.claims('c3000000-0000-0000-0000-000000000003','cc000000-0000-0000-0000-000000000003');
select pg_temp.expect_state('banned caller denied','42501',format('select public.toggle_post_highlight(%L::uuid,true)',:'pforeign'));
select pg_temp.claims('a1000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001');
select pg_temp.expect_state('null state rejected','22023',format('select public.toggle_post_highlight(%L::uuid,null)',:'p2'));
select pg_temp.expect_state('direct client highlight insert denied','42501',format('insert into public.posts(profile_id,body,is_highlighted) values (%L::uuid,%L,true)',:'a1','direct denied'));
select pg_temp.expect_state('direct client highlight denied','42501',format('update public.posts set is_highlighted=true where id=%L::uuid',:'p1'));
set local role anon;
select set_config('request.jwt.claims','{}',true);
select pg_temp.assert_true('anon public post read unchanged',count(*)=1) from public.posts where id=:'p2';
select pg_temp.assert_true('anon members-only post remains hidden',count(*)=0) from public.posts where id=:'pmembers';
reset role;
set local role authenticated;
select pg_temp.claims('b2000000-0000-0000-0000-000000000002','bb000000-0000-0000-0000-000000000002');
select pg_temp.assert_true('authenticated members-only post read unchanged',count(*)=1) from public.posts where id=:'pmembers';
reset role;
select pg_temp.expect_state('timestamp trigger owned','42501',format('update public.posts set highlighted_at=clock_timestamp() where id=%L::uuid',:'p2'));
select pg_temp.expect_state('owner sixth also fenced','P5005',format('update public.posts set is_highlighted=true where id=%L::uuid',:'p1'));
rollback;
\echo HIGHLIGHTS_BEHAVIOR=PASS
