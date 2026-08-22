-- psy.market Slice MP-4-G ROLLBACK — exact target -> exact post-MP4-F source.
-- Run before MP4-F and MP4-E rollback. Refuses any function/trigger drift.
begin;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,public.conversation_participant_state in share row exclusive mode;

do $mp4g_rollback$
declare source_state boolean;target_state boolean;
begin
 if current_user<>'postgres' or session_user<>'postgres' or not(select rolsuper or rolbypassrls from pg_roles where rolname=current_user) then raise exception 'MP4-G ROLLBACK requires complete postgres owner context' using errcode='42501';end if;
 select (select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message'))
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='append_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='6023d0d555a24427a1d98f92d9d37e25')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='remove_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='ca52e0ea7f804024cf6f9f7955dc9a62')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='hide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='4e5756391924dc30ca09f7b535d36afa')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='7e7d2ce7d7cef459c1dd9a72a2eb87ab')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='find_and_unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='ad6475d6ac60d2fe451597dbe78c2453')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation_for_message_recipient' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='65000503f5c585632d5cae3282217b43')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='update_conversation_last_message' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='396ba90811a1f9ba79cbdf3bc3f5b060') into source_state;
 if source_state then return;end if;
 select (select count(*)=7 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','unhide_conversation_for_message_recipient','update_conversation_last_message'))
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='append_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='ea719f14fbf39105240148d58aa8a38b')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='remove_unread_for' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='8ed649f894edd22265efbf940201ac8d')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='hide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='59ffc3792e4e13f0f12b1f1e8ad9fe24')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='93e51e3b852e1a68cec74c935f4ee5b2')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='find_and_unhide_conversation' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='a54c515118342fae1db226b8dc09c8c8')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='unhide_conversation_for_message_recipient' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='ce0b71a177cf61cdcbc25244df096d14')
  and exists(select 1 from pg_proc p join pg_namespace nsp on nsp.oid=p.pronamespace where nsp.nspname='public' and p.proname='update_conversation_last_message' and md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))='5a285350e95fb623199956f4d43b7953') into target_state;
 if not target_state then raise exception 'MP4-G ROLLBACK target drift' using errcode='55000';end if;
 if (select count(*) from pg_policy p where p.polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass) and (coalesce(pg_get_expr(p.polqual,p.polrelid,false),'')||coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),'')) like '%current_active_profile_id%')<>5 then raise exception 'MP4-G ROLLBACK requires post-MP4-F policy state' using errcode='55000';end if;

 execute $ddl$create or replace function public.append_unread_for(
   conv_id uuid,
   profile_id text
 )
 returns void
 language plpgsql
 security definer
 set search_path = pg_catalog, public, auth
 as $$
 declare
   caller_profile_id uuid;
   target_profile_id uuid := profile_id::uuid;
 begin
   if public.current_user_is_banned() then
     raise exception 'Banned accounts cannot change unread state';
   end if;

   select case
            when public.current_user_owns_profile(c.buyer_profile_id)
              then c.buyer_profile_id
            when public.current_user_owns_profile(c.seller_profile_id)
              then c.seller_profile_id
          end
     into caller_profile_id
   from public.conversations c
   where c.id = conv_id;

   if caller_profile_id is null then
     raise exception 'Not a conversation participant';
   end if;

   if not exists (
     select 1
     from public.conversations c
     where c.id = conv_id
       and target_profile_id in (
         c.buyer_profile_id,
         c.seller_profile_id
       )
       and target_profile_id <> caller_profile_id
   ) then
     raise exception 'Invalid unread recipient';
   end if;

   update public.conversations c
   set unread_for = array_append(
     coalesce(c.unread_for, '{}'::text[]),
     target_profile_id::text
   )
   where c.id = conv_id
     and not (
       coalesce(c.unread_for, '{}'::text[])
       @> array[target_profile_id::text]
     );
 end;
 $$;$ddl$;
 execute $ddl$create or replace function public.remove_unread_for(
   conv_id uuid,
   profile_id text
 )
 returns void
 language plpgsql
 security definer
 set search_path = pg_catalog, public, auth
 as $$
 declare
   caller_profile_id uuid;
   target_profile_id uuid := profile_id::uuid;
 begin
   if public.current_user_is_banned() then
     raise exception 'Banned accounts cannot change unread state';
   end if;

   select case
            when public.current_user_owns_profile(c.buyer_profile_id)
              then c.buyer_profile_id
            when public.current_user_owns_profile(c.seller_profile_id)
              then c.seller_profile_id
          end
     into caller_profile_id
   from public.conversations c
   where c.id = conv_id;

   if caller_profile_id is null then
     raise exception 'Not a conversation participant';
   end if;

   if target_profile_id <> caller_profile_id then
     raise exception 'Users may only clear their own unread state';
   end if;

   update public.conversations c
   set unread_for = array_remove(
     coalesce(c.unread_for, '{}'::text[]),
     target_profile_id::text
   )
   where c.id = conv_id;
 end;
 $$;$ddl$;
 execute $ddl$create or replace function public.hide_conversation(
   target_conversation_id uuid
 )
 returns void
 language plpgsql
 security definer
 set search_path = pg_catalog, public, auth
 as $$
 declare
   caller_profile_id uuid;
 begin
   if public.current_user_is_banned() then
     raise exception 'Banned accounts cannot hide conversations';
   end if;

   select case
            when public.current_user_owns_profile(c.buyer_profile_id)
              then c.buyer_profile_id
            when public.current_user_owns_profile(c.seller_profile_id)
              then c.seller_profile_id
          end
     into caller_profile_id
   from public.conversations c
   where c.id = target_conversation_id;

   if caller_profile_id is null then
     raise exception 'Conversation not found or caller is not a participant';
   end if;

   insert into public.conversation_participant_state (
     conversation_id,
     profile_id,
     hidden_at,
     updated_at
   )
   values (
     target_conversation_id,
     caller_profile_id,
     now(),
     now()
   )
   on conflict (conversation_id, profile_id)
   do update
     set hidden_at = excluded.hidden_at,
         updated_at = excluded.updated_at;
 end;
 $$;$ddl$;
 execute $ddl$create or replace function public.unhide_conversation(
   target_conversation_id uuid
 )
 returns void
 language plpgsql
 security definer
 set search_path = pg_catalog, public, auth
 as $$
 declare
   caller_profile_id uuid;
 begin
   if public.current_user_is_banned() then
     raise exception 'Banned accounts cannot unhide conversations';
   end if;

   select case
            when public.current_user_owns_profile(c.buyer_profile_id)
              then c.buyer_profile_id
            when public.current_user_owns_profile(c.seller_profile_id)
              then c.seller_profile_id
          end
     into caller_profile_id
   from public.conversations c
   where c.id = target_conversation_id;

   if caller_profile_id is null then
     raise exception 'Conversation not found or caller is not a participant';
   end if;

   insert into public.conversation_participant_state (
     conversation_id,
     profile_id,
     hidden_at,
     updated_at
   )
   values (
     target_conversation_id,
     caller_profile_id,
     null,
     now()
   )
   on conflict (conversation_id, profile_id)
   do update
     set hidden_at = null,
         updated_at = excluded.updated_at;
 end;
 $$;$ddl$;
 execute $ddl$create or replace function public.find_and_unhide_conversation(
   target_other_profile_id uuid,
   target_listing_id uuid default null
 )
 returns uuid
 language plpgsql
 security definer
 set search_path = pg_catalog, public, auth
 as $$
 declare
   caller_profile_id uuid;
   existing_conversation_id uuid;
   caller_profile_count bigint;
 begin
   if public.current_user_is_banned() then
     raise exception 'Banned accounts cannot open conversations';
   end if;

   select (array_agg(owned.id order by owned.created_at, owned.id))[1], count(*)
     into caller_profile_id, caller_profile_count
   from public.get_my_profiles() as owned;

   if caller_profile_count > 1 then
     raise exception 'Active profile selection is required';
   end if;

   if caller_profile_id is null then
     raise exception 'Caller profile not found';
   end if;

   if target_other_profile_id = caller_profile_id then
     raise exception 'Cannot open a conversation with the same profile';
   end if;

   if not exists (
     select 1
     from public.profiles p
     where p.id = target_other_profile_id
   ) then
     raise exception 'Target profile does not exist';
   end if;

   if target_listing_id is not null
      and not exists (
        select 1
        from public.listings l
        where l.id = target_listing_id
          and l.profile_id = target_other_profile_id
      ) then
     raise exception 'Listing does not belong to the target profile';
   end if;

   select c.id
     into existing_conversation_id
   from public.conversations c
   where c.listing_id is not distinct from target_listing_id
     and (
       (
         c.buyer_profile_id = caller_profile_id
         and c.seller_profile_id = target_other_profile_id
       )
       or (
         c.buyer_profile_id = target_other_profile_id
         and c.seller_profile_id = caller_profile_id
       )
     )
   order by c.last_message_at desc, c.created_at desc
   limit 1;

   if existing_conversation_id is null then
     return null;
   end if;

   insert into public.conversation_participant_state (
     conversation_id,
     profile_id,
     hidden_at,
     updated_at
   )
   values (
     existing_conversation_id,
     caller_profile_id,
     null,
     now()
   )
   on conflict (conversation_id, profile_id)
   do update
     set hidden_at = null,
         updated_at = excluded.updated_at;

   return existing_conversation_id;
 end;
 $$;$ddl$;
 execute $ddl$create or replace function public.unhide_conversation_for_message_recipient()
   returns trigger language plpgsql volatile security definer set search_path=''
   as $fn$
   declare affected_rows bigint;
   begin
     if tg_when<>'AFTER' or tg_level<>'ROW' or tg_op<>'INSERT' or tg_table_schema<>'public' or tg_table_name<>'messages' then raise exception 'Unexpected recipient-unhide trigger context' using errcode='42501'; end if;
     update public.conversation_participant_state s set hidden_at=null,updated_at=pg_catalog.now()
     from public.conversations c where c.id=new.conversation_id and c.buyer_profile_id is not null and c.seller_profile_id is not null and c.buyer_profile_id<>c.seller_profile_id
       and new.sender_profile_id in(c.buyer_profile_id,c.seller_profile_id) and s.conversation_id=c.id and s.hidden_at is not null
       and s.profile_id=case when new.sender_profile_id=c.buyer_profile_id then c.seller_profile_id else c.buyer_profile_id end;
     get diagnostics affected_rows=row_count;
     return new;
   end$fn$;$ddl$;
 execute $ddl$create or replace function public.update_conversation_last_message()
   returns trigger language plpgsql volatile security definer set search_path=''
   as $fn$
   declare affected_rows bigint;
   begin
     if tg_when<>'AFTER' or tg_level<>'ROW' or tg_op<>'INSERT' or tg_table_schema<>'public' or tg_table_name<>'messages' then raise exception 'Unexpected update_conversation_last_message trigger context' using errcode='42501'; end if;
     update public.conversations c set last_message_at=new.created_at,last_message_body=pg_catalog.left(new.body,120)
     where c.id=new.conversation_id and c.buyer_profile_id is not null and c.seller_profile_id is not null and c.buyer_profile_id<>c.seller_profile_id
       and new.sender_profile_id is not null and new.sender_profile_id in(c.buyer_profile_id,c.seller_profile_id);
     get diagnostics affected_rows=row_count;
     if affected_rows <> 1 then raise exception 'Message parent conversation does not exist' using errcode='23503'; end if;
     return new;
   end$fn$;$ddl$;
 alter function public.append_unread_for(uuid,text) owner to postgres;alter function public.remove_unread_for(uuid,text) owner to postgres;alter function public.hide_conversation(uuid) owner to postgres;alter function public.unhide_conversation(uuid) owner to postgres;alter function public.find_and_unhide_conversation(uuid,uuid) owner to postgres;alter function public.unhide_conversation_for_message_recipient() owner to postgres;alter function public.update_conversation_last_message() owner to postgres;
 revoke all on function public.append_unread_for(uuid,text),public.remove_unread_for(uuid,text),public.hide_conversation(uuid),public.unhide_conversation(uuid),public.find_and_unhide_conversation(uuid,uuid) from public,anon,authenticated,service_role;
 grant execute on function public.append_unread_for(uuid,text),public.remove_unread_for(uuid,text),public.hide_conversation(uuid),public.unhide_conversation(uuid),public.find_and_unhide_conversation(uuid,uuid) to authenticated,service_role;
 revoke all on function public.unhide_conversation_for_message_recipient(),public.update_conversation_last_message() from public,anon,authenticated,service_role;
 grant execute on function public.unhide_conversation_for_message_recipient(),public.update_conversation_last_message() to service_role;
end$mp4g_rollback$;

do $post$ begin
 if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and (p.proname,md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g')))) in(('append_unread_for','6023d0d555a24427a1d98f92d9d37e25'),('remove_unread_for','ca52e0ea7f804024cf6f9f7955dc9a62'),('hide_conversation','4e5756391924dc30ca09f7b535d36afa'),('unhide_conversation','7e7d2ce7d7cef459c1dd9a72a2eb87ab'),('find_and_unhide_conversation','ad6475d6ac60d2fe451597dbe78c2453'),('unhide_conversation_for_message_recipient','65000503f5c585632d5cae3282217b43'),('update_conversation_last_message','396ba90811a1f9ba79cbdf3bc3f5b060')))<>7 then raise exception 'MP4-G rollback postcondition: source body mismatch';end if;
end$post$;
commit;
