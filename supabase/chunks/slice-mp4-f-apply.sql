-- psy.market Slice MP-4-F: conversation policy active authority
-- APPLY: guarded post-MP4-E source -> exact five-policy target; exact-target rerun is a no-op.
-- No function, trigger, table ACL, publication, replica-identity, or row change is made.
begin;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,
 public.conversation_participant_state in share row exclusive mode;

do $mp4f$
declare source_state boolean; target_state boolean;
begin
 if current_user<>'postgres' or session_user<>'postgres' or not(select rolsuper or rolbypassrls from pg_roles where rolname=current_user) then
  raise exception 'MP4-F APPLY requires complete postgres owner context' using errcode='42501';
 end if;

 -- The count is derived from the package scope: conversation INSERT+SELECT,
 -- message INSERT+SELECT, and participant-state SELECT = exactly five policies.
 select count(*)=5
   and count(*) filter(where polname='Unbanned buyers create conversations' and polcmd='a')=1
   and count(*) filter(where polname='participants view visible conversations' and polcmd='r')=1
   and count(*) filter(where polname='Unbanned participants send messages' and polcmd='a')=1
   and count(*) filter(where polname='participants view messages' and polcmd='r')=1
   and count(*) filter(where polname='Participants read own conversation state' and polcmd='r')=1
   and bool_and(polpermissive and polroles=array['authenticated'::regrole::oid])
   and count(*) filter(where coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'') like '%current_user_owns_profile%')=5
   and count(*) filter(where coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'') like '%current_active_profile_id%')=0
 into source_state
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state');

 select count(*)=5
   and bool_and(polpermissive and polroles=array['authenticated'::regrole::oid])
   and count(*) filter(where coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'') like '%current_active_profile_id%')=5
   and count(*) filter(where polname='Unbanned buyers create conversations' and regexp_replace(pg_get_expr(polwithcheck,polrelid,false),'public\.','','g') like '%NOT current_user_owns_profile(seller_profile_id)%')=1
   and count(*) filter(where (coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'')) like '%current_user_owns_profile%')=2
 into target_state
 from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state');

 if target_state then return; end if;
 if not source_state then raise exception 'MP4-F APPLY source drift: neither reviewed source nor target policy family' using errcode='55000'; end if;
 if (select count(*) from pg_attribute where attrelid in('public.conversations'::regclass,'public.messages'::regclass) and attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and not attnotnull)<>3
    or to_regprocedure('public.guard_conversation_participants()') is null
    or to_regprocedure('public.guard_message_active_participant()') is null
    or to_regprocedure('public.guard_conversation_unread_participants()') is null
    or to_regprocedure('public.guard_conversation_participant_state()') is null then
  raise exception 'MP4-F APPLY requires exact post-MP4-E nullable/guard foundation' using errcode='55000';
 end if;

 drop policy "Participants read own conversation state" on public.conversation_participant_state;
 drop policy "Unbanned buyers create conversations" on public.conversations;
 drop policy "participants view visible conversations" on public.conversations;
 drop policy "Unbanned participants send messages" on public.messages;
 drop policy "participants view messages" on public.messages;

 create policy "Participants read own conversation state"
 on public.conversation_participant_state for select to authenticated
 using (profile_id = (select public.current_active_profile_id()));

 create policy "Unbanned buyers create conversations"
 on public.conversations for insert to authenticated
 with check (
  not public.current_user_is_banned()
  and buyer_profile_id = (select public.current_active_profile_id())
  and buyer_profile_id is not null and seller_profile_id is not null
  and buyer_profile_id <> seller_profile_id
  -- Existing hardened boolean ownership helper supplies same-account denial without
  -- granting or returning profiles.user_id. RLS emits only its neutral generic denial.
  and not public.current_user_owns_profile(seller_profile_id)
  and (listing_id is null or seller_profile_id=(select l.profile_id from public.listings l where l.id=conversations.listing_id))
 );

 create policy "participants view visible conversations"
 on public.conversations for select to authenticated
 using (
  (buyer_profile_id=(select public.current_active_profile_id()) or seller_profile_id=(select public.current_active_profile_id()))
  and not exists(
   select 1 from public.conversation_participant_state s
   where s.conversation_id=conversations.id
    and s.profile_id=(select public.current_active_profile_id())
    and s.hidden_at is not null
  )
 );

 create policy "Unbanned participants send messages"
 on public.messages for insert to authenticated
 with check (
  not public.current_user_is_banned()
  and sender_profile_id=(select public.current_active_profile_id())
  and exists(
   select 1 from public.conversations c
   where c.id=messages.conversation_id
    and c.buyer_profile_id is not null and c.seller_profile_id is not null
    and c.buyer_profile_id<>c.seller_profile_id
    and messages.sender_profile_id in(c.buyer_profile_id,c.seller_profile_id)
    and not public.current_user_owns_profile(
      case when messages.sender_profile_id=c.buyer_profile_id then c.seller_profile_id else c.buyer_profile_id end
    )
  )
 );

 create policy "participants view messages"
 on public.messages for select to authenticated
 using (exists(
  select 1 from public.conversations c
  where c.id=messages.conversation_id
   and (c.buyer_profile_id=(select public.current_active_profile_id()) or c.seller_profile_id=(select public.current_active_profile_id()))
 ));
end
$mp4f$;

do $post$
begin
 if (select count(*) from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in('conversations','messages','conversation_participant_state'))<>5 then raise exception 'MP4-F postcondition: policy count'; end if;
 if (select count(*) from pg_policy p where p.polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass) and (coalesce(pg_get_expr(p.polqual,p.polrelid,false),'')||coalesce(pg_get_expr(p.polwithcheck,p.polrelid,false),'')) like '%current_active_profile_id%')<>5 then raise exception 'MP4-F postcondition: active authority missing'; end if;
 if not exists(select 1 from pg_policy where polrelid='public.conversations'::regclass and polname='Unbanned buyers create conversations' and regexp_replace(pg_get_expr(polwithcheck,polrelid,false),'public\.','','g') like '%NOT current_user_owns_profile(seller_profile_id)%') then raise exception 'MP4-F postcondition: same-account policy denial missing'; end if;
 if not exists(select 1 from pg_policy where polrelid='public.messages'::regclass and polname='Unbanned participants send messages' and regexp_replace(pg_get_expr(polwithcheck,polrelid,false),'public\.','','g') ~ 'NOT current_user_owns_profile\([[:space:]]*CASE') then raise exception 'MP4-F postcondition: same-account message denial missing'; end if;
end$post$;
commit;
