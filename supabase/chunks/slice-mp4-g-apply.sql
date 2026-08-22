-- psy.market Slice MP-4-G: messaging RPC active authority and trigger completion
-- APPLY: guarded post-MP4-F source -> exact five-RPC/two-trigger target.
-- Exact-target rerun is a no-op. No table, policy, row, publication, or app change.
-- One-sided retained rows remain message/append read-only, but the surviving active
-- participant may clear their own unread marker as a read-side courtesy.
-- DECLARED INVALIDATIONS: slice-mp4-e-verify.sql, slice-mp4-f-verify.sql, and
-- slice-mp4-f-preflight.sql intentionally STOP after G because they pin pre-G bodies.
-- Rollback order: G before F before E.
begin;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,
 public.conversation_participant_state in share row exclusive mode;

do $mp4g$
declare source_state boolean; target_state boolean;
begin
 if current_user<>'postgres' or session_user<>'postgres' or not(select rolsuper or rolbypassrls from pg_roles where rolname=current_user) then
  raise exception 'MP4-G APPLY requires complete postgres owner context' using errcode='42501';
 end if;
 select (select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message'))
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='append_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='6023d0d555a24427a1d98f92d9d37e25')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='remove_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='ca52e0ea7f804024cf6f9f7955dc9a62')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='hide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='4e5756391924dc30ca09f7b535d36afa')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='7e7d2ce7d7cef459c1dd9a72a2eb87ab')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='find_and_unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='ad6475d6ac60d2fe451597dbe78c2453')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation_for_message_recipient' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='65000503f5c585632d5cae3282217b43')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='update_conversation_last_message' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='396ba90811a1f9ba79cbdf3bc3f5b060') into source_state;
 select (select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message'))
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='append_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='d11f82a4b1d43fe42bbe3a6423660000')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='remove_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='77188697a16d747abfb12eaf16d5a1a6')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='hide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='be76125d658a1ad3077fbc2d8b8e9c75')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='5ef5fa1296aed8f13fb52ab5cf5fdc99')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='find_and_unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='a54c515118342fae1db226b8dc09c8c8')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation_for_message_recipient' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='32ed416178cb477bfdb363eef779f10f')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='update_conversation_last_message' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='5a285350e95fb623199956f4d43b7953') into target_state;
 if target_state then
  if (select count(*)=19 and bool_and(a.grantor='postgres'::regrole and a.privilege_type='EXECUTE'and not a.is_grantable and((p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation')and a.grantee in('authenticated'::regrole,'postgres'::regrole,'service_role'::regrole))or(p.proname in('unhide_conversation_for_message_recipient','update_conversation_last_message')and a.grantee in('postgres'::regrole,'service_role'::regrole))))from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))a where n.nspname='public'and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message'))then return;end if;
  raise exception 'MP4-G APPLY target ACL drift' using errcode='55000';
 end if;
 if not source_state then raise exception 'MP4-G APPLY source drift: neither exact reviewed source nor target function family' using errcode='55000'; end if;
 if (select count(*) from pg_policy p where p.polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass)
      and (coalesce(pg_get_expr(p.polqual,p.polrelid,false),'')||coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),'')) like '%current_active_profile_id%')<>5 then
  raise exception 'MP4-G APPLY requires exact post-MP4-F active policy family' using errcode='55000';
 end if;
 if (select count(*) from pg_trigger where not tgisinternal and (tgrelid,tgname) in(
      ('public.messages'::regclass,'messages_unhide_recipient_conversation'),('public.messages'::regclass,'on_message_insert')))<>2 then
  raise exception 'MP4-G APPLY trigger binding drift' using errcode='55000';
 end if;

 execute $ddl$create or replace function public.append_unread_for(conv_id uuid,profile_id text)
 returns void language plpgsql volatile security definer set search_path=''
 as $fn$
 declare active_profile_id uuid; target_profile_id uuid; c public.conversations%rowtype;
 begin
  if public.current_user_is_banned() then raise exception 'Banned accounts cannot change unread state' using errcode='P0001'; end if;
  active_profile_id:=public.current_active_profile_id();
  if active_profile_id is null then raise exception 'Active profile selection is required' using errcode='P0001'; end if;
  target_profile_id:=profile_id::uuid;
  select * into c from public.conversations where id=conv_id;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Not a conversation participant' using errcode='P0001';
  end if;
  select * into c from public.conversations where id=conv_id for update;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Not a conversation participant' using errcode='P0001';
  end if;
  if public.current_user_owns_profile(c.buyer_profile_id) and public.current_user_owns_profile(c.seller_profile_id) then
   raise exception 'Both conversation participants belong to the caller account' using errcode='P0001';
  end if;
  if c.buyer_profile_id is null or c.seller_profile_id is null or c.buyer_profile_id=c.seller_profile_id then
   raise exception 'One-sided retained conversations are read-only' using errcode='55000';
  end if;
  if target_profile_id is distinct from (case when active_profile_id=c.buyer_profile_id then c.seller_profile_id else c.buyer_profile_id end) then
   raise exception 'Invalid unread recipient' using errcode='P0001';
  end if;
  update public.conversations set unread_for=array_append(coalesce(unread_for,'{}'::text[]),target_profile_id::text)
   where id=conv_id and not coalesce(unread_for,'{}'::text[])@>array[target_profile_id::text];
 end;$fn$;$ddl$;
 execute $ddl$create or replace function public.remove_unread_for(conv_id uuid,profile_id text)
 returns void language plpgsql volatile security definer set search_path=''
 as $fn$
 declare active_profile_id uuid; target_profile_id uuid; c public.conversations%rowtype;
 begin
  if public.current_user_is_banned() then raise exception 'Banned accounts cannot change unread state' using errcode='P0001'; end if;
  active_profile_id:=public.current_active_profile_id();
  if active_profile_id is null then raise exception 'Active profile selection is required' using errcode='P0001'; end if;
  target_profile_id:=profile_id::uuid;
  select * into c from public.conversations where id=conv_id;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Not a conversation participant' using errcode='P0001';
  end if;
  select * into c from public.conversations where id=conv_id for update;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Not a conversation participant' using errcode='P0001';
  end if;
  if public.current_user_owns_profile(c.buyer_profile_id) and public.current_user_owns_profile(c.seller_profile_id) then
   raise exception 'Both conversation participants belong to the caller account' using errcode='P0001';
  end if;
  if target_profile_id is distinct from active_profile_id then raise exception 'Users may only clear their own unread state' using errcode='P0001'; end if;
  update public.conversations set unread_for=array_remove(coalesce(unread_for,'{}'::text[]),target_profile_id::text) where id=conv_id;
 end;$fn$;$ddl$;
 execute $ddl$create or replace function public.hide_conversation(target_conversation_id uuid)
 returns void language plpgsql volatile security definer set search_path=''
 as $fn$
 declare active_profile_id uuid; c public.conversations%rowtype;
 begin
  if public.current_user_is_banned() then raise exception 'Banned accounts cannot hide conversations' using errcode='P0001'; end if;
  active_profile_id:=public.current_active_profile_id();
  if active_profile_id is null then raise exception 'Active profile selection is required' using errcode='P0001'; end if;
  select * into c from public.conversations where id=target_conversation_id;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Conversation not found or caller is not a participant' using errcode='P0001';
  end if;
  select * into c from public.conversations where id=target_conversation_id for update;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Conversation not found or caller is not a participant' using errcode='P0001';
  end if;
  if public.current_user_owns_profile(c.buyer_profile_id) and public.current_user_owns_profile(c.seller_profile_id) then
   raise exception 'Both conversation participants belong to the caller account' using errcode='P0001';
  end if;
  insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at,updated_at)
   values(target_conversation_id,active_profile_id,pg_catalog.now(),pg_catalog.now())
   on conflict(conversation_id,profile_id) do update set hidden_at=excluded.hidden_at,updated_at=excluded.updated_at;
 end;$fn$;$ddl$;
 execute $ddl$create or replace function public.unhide_conversation(target_conversation_id uuid)
 returns void language plpgsql volatile security definer set search_path=''
 as $fn$
 declare active_profile_id uuid; c public.conversations%rowtype;
 begin
  if public.current_user_is_banned() then raise exception 'Banned accounts cannot unhide conversations' using errcode='P0001'; end if;
  active_profile_id:=public.current_active_profile_id();
  if active_profile_id is null then raise exception 'Active profile selection is required' using errcode='P0001'; end if;
  select * into c from public.conversations where id=target_conversation_id;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Conversation not found or caller is not a participant' using errcode='P0001';
  end if;
  select * into c from public.conversations where id=target_conversation_id for update;
  if not found or (active_profile_id is distinct from c.buyer_profile_id and active_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Conversation not found or caller is not a participant' using errcode='P0001';
  end if;
  if public.current_user_owns_profile(c.buyer_profile_id) and public.current_user_owns_profile(c.seller_profile_id) then
   raise exception 'Both conversation participants belong to the caller account' using errcode='P0001';
  end if;
  insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at,updated_at)
   values(target_conversation_id,active_profile_id,null,pg_catalog.now())
   on conflict(conversation_id,profile_id) do update set hidden_at=null,updated_at=excluded.updated_at;
 end;$fn$;$ddl$;
 execute $ddl$create or replace function public.find_and_unhide_conversation(target_other_profile_id uuid,target_listing_id uuid default null)
 returns uuid language plpgsql volatile security definer set search_path=''
 as $fn$
 declare active_profile_id uuid; existing_conversation_id uuid;
 begin
  if public.current_user_is_banned() then raise exception 'Banned accounts cannot open conversations' using errcode='P0001'; end if;
  active_profile_id:=public.current_active_profile_id();
  if active_profile_id is null then raise exception 'Active profile selection is required' using errcode='P0001'; end if;
  if target_other_profile_id=active_profile_id or public.current_user_owns_profile(target_other_profile_id) then
   raise exception 'You can''t contact your own profile' using errcode='P0001';
  end if;
  if not exists(select 1 from public.profiles where id=target_other_profile_id) then raise exception 'Target profile does not exist' using errcode='P0001'; end if;
  if target_listing_id is not null and not exists(select 1 from public.listings where id=target_listing_id and profile_id=target_other_profile_id) then
   raise exception 'Listing does not belong to the target profile' using errcode='P0001';
  end if;
  select c.id into existing_conversation_id from public.conversations c
   where c.listing_id is not distinct from target_listing_id
    and c.buyer_profile_id is not null and c.seller_profile_id is not null and c.buyer_profile_id<>c.seller_profile_id
    and ((c.buyer_profile_id=active_profile_id and c.seller_profile_id=target_other_profile_id)
      or (c.buyer_profile_id=target_other_profile_id and c.seller_profile_id=active_profile_id))
   order by c.last_message_at desc,c.created_at desc,c.id limit 1 for update;
  if existing_conversation_id is null then return null; end if;
  insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at,updated_at)
   values(existing_conversation_id,active_profile_id,null,pg_catalog.now())
   on conflict(conversation_id,profile_id) do update set hidden_at=null,updated_at=excluded.updated_at;
  return existing_conversation_id;
 end;$fn$;$ddl$;
 execute $ddl$create or replace function public.unhide_conversation_for_message_recipient()
 returns trigger language plpgsql volatile security definer set search_path=''
 as $fn$
 declare c public.conversations%rowtype; recipient_profile_id uuid;
 begin
  if tg_when<>'AFTER' or tg_level<>'ROW' or tg_op<>'INSERT' or tg_table_schema<>'public' or tg_table_name<>'messages' then
   raise exception 'Unexpected recipient-unhide trigger context' using errcode='42501';
  end if;
  select * into c from public.conversations where id=new.conversation_id for update;
  if not found then raise exception 'Message parent conversation does not exist' using errcode='23503'; end if;
  if c.buyer_profile_id is null or c.seller_profile_id is null or c.buyer_profile_id=c.seller_profile_id then
   raise exception 'Recipient-unhide requires two present participants' using errcode='55000';
  end if;
  if new.sender_profile_id=c.buyer_profile_id then recipient_profile_id:=c.seller_profile_id;
  elsif new.sender_profile_id=c.seller_profile_id then recipient_profile_id:=c.buyer_profile_id;
  else raise exception 'Message sender is not a conversation participant' using errcode='23514'; end if;
  update public.conversation_participant_state set hidden_at=null,updated_at=pg_catalog.now()
   where conversation_id=new.conversation_id and profile_id=recipient_profile_id and hidden_at is not null;
  return new;
 end;$fn$;$ddl$;
 execute $ddl$create or replace function public.update_conversation_last_message()
 returns trigger language plpgsql volatile security definer set search_path=''
 as $fn$
 declare c public.conversations%rowtype; affected_rows bigint;
 begin
  if tg_when<>'AFTER' or tg_level<>'ROW' or tg_op<>'INSERT' or tg_table_schema<>'public' or tg_table_name<>'messages' then
   raise exception 'Unexpected update_conversation_last_message trigger context' using errcode='42501';
  end if;
  select * into c from public.conversations where id=new.conversation_id for update;
  if not found then raise exception 'Message parent conversation does not exist' using errcode='23503'; end if;
  if c.buyer_profile_id is null or c.seller_profile_id is null or c.buyer_profile_id=c.seller_profile_id then
   raise exception 'One-sided retained conversations are read-only' using errcode='55000';
  end if;
  if new.sender_profile_id is null or (new.sender_profile_id is distinct from c.buyer_profile_id and new.sender_profile_id is distinct from c.seller_profile_id) then
   raise exception 'Message sender is not a conversation participant' using errcode='23514';
  end if;
  update public.conversations set last_message_at=new.created_at,last_message_body=pg_catalog.left(new.body,120) where id=new.conversation_id;
  get diagnostics affected_rows=row_count;
  if affected_rows<>1 then raise exception 'Message parent conversation does not exist' using errcode='23503'; end if;
  return new;
 end;$fn$;$ddl$;
 alter function public.append_unread_for(uuid,text) owner to postgres;
 alter function public.remove_unread_for(uuid,text) owner to postgres;
 alter function public.hide_conversation(uuid) owner to postgres;
 alter function public.unhide_conversation(uuid) owner to postgres;
 alter function public.find_and_unhide_conversation(uuid,uuid) owner to postgres;
 alter function public.unhide_conversation_for_message_recipient() owner to postgres;
 alter function public.update_conversation_last_message() owner to postgres;
 revoke all on function public.append_unread_for(uuid,text),public.remove_unread_for(uuid,text),public.hide_conversation(uuid),public.unhide_conversation(uuid),public.find_and_unhide_conversation(uuid,uuid) from public,anon,authenticated,service_role;
 grant execute on function public.append_unread_for(uuid,text),public.remove_unread_for(uuid,text),public.hide_conversation(uuid),public.unhide_conversation(uuid),public.find_and_unhide_conversation(uuid,uuid) to authenticated,service_role;
 revoke all on function public.unhide_conversation_for_message_recipient(),public.update_conversation_last_message() from public,anon,authenticated,service_role;
 grant execute on function public.unhide_conversation_for_message_recipient(),public.update_conversation_last_message() to service_role;
end$mp4g$;

do $post$
begin
 if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation') and p.prosrc like '%current_active_profile_id%')<>5 then raise exception 'MP4-G postcondition: active RPC family incomplete'; end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where n.nspname='public' and p.proname in('unhide_conversation_for_message_recipient','update_conversation_last_message') and (a.grantee=0 or a.grantee in('anon'::regrole,'authenticated'::regrole))) then raise exception 'MP4-G postcondition: trigger function client EXECUTE remains'; end if;
 if not(select count(*)=19 and bool_and(a.grantor='postgres'::regrole and a.privilege_type='EXECUTE'and not a.is_grantable and((p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation')and a.grantee in('authenticated'::regrole,'postgres'::regrole,'service_role'::regrole))or(p.proname in('unhide_conversation_for_message_recipient','update_conversation_last_message')and a.grantee in('postgres'::regrole,'service_role'::regrole))))from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner)))a where n.nspname='public'and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message'))then raise exception 'MP4-G postcondition: exact function ACL mismatch';end if;
 if (select count(*) from pg_trigger where not tgisinternal and (tgrelid,tgname) in(('public.messages'::regclass,'messages_unhide_recipient_conversation'),('public.messages'::regclass,'on_message_insert')))<>2 then raise exception 'MP4-G postcondition: trigger binding drift'; end if;
end$post$;
commit;
