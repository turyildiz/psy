-- psy.market Slice MP-4-F ROLLBACK — exact target -> exact post-MP4-E source.
-- Roll back F before E. No row/schema/function/ACL/publication mutation.
begin;
set local row_security=off;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.profiles,public.listings,public.conversations,public.messages,
 public.conversation_participant_state in share row exclusive mode;

do $mp4f_rollback$
declare source_state boolean;target_state boolean;
begin
 if current_user<>'postgres' or session_user<>'postgres' or not(select rolsuper or rolbypassrls from pg_roles where rolname=current_user) then raise exception 'MP4-F ROLLBACK requires complete postgres owner context' using errcode='42501';end if;
 select count(*)=5 and count(*) filter(where (coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'')) like '%current_user_owns_profile%')=5 and count(*) filter(where (coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'')) like '%current_active_profile_id%')=0 into source_state from pg_policy where polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass);
 if source_state then return;end if;
 select count(*)=5 and count(*) filter(where (coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'')) like '%current_active_profile_id%')=5 and count(*) filter(where polname='Unbanned buyers create conversations' and regexp_replace(pg_get_expr(polwithcheck,polrelid,false),'public\.','','g') like '%NOT current_user_owns_profile(seller_profile_id)%')=1 into target_state from pg_policy where polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass);
 if not target_state then raise exception 'MP4-F ROLLBACK target drift' using errcode='55000';end if;
 if (select count(*) from pg_attribute where attrelid in('public.conversations'::regclass,'public.messages'::regclass) and attname in('buyer_profile_id','seller_profile_id','sender_profile_id') and not attnotnull)<>3 then raise exception 'MP4-F ROLLBACK requires post-E nullable schema' using errcode='55000';end if;

 drop policy "Participants read own conversation state" on public.conversation_participant_state;
 drop policy "Unbanned buyers create conversations" on public.conversations;
 drop policy "participants view visible conversations" on public.conversations;
 drop policy "Unbanned participants send messages" on public.messages;
 drop policy "participants view messages" on public.messages;

 create policy "Participants read own conversation state" on public.conversation_participant_state for select to authenticated using(public.current_user_owns_profile(profile_id));
 create policy "Unbanned buyers create conversations" on public.conversations for insert to authenticated with check(
  not public.current_user_is_banned() and public.current_user_owns_profile(buyer_profile_id) and buyer_profile_id<>seller_profile_id
  and(listing_id is null or seller_profile_id=(select l.profile_id from public.listings l where l.id=conversations.listing_id)));
 create policy "participants view visible conversations" on public.conversations for select to authenticated using(
  (public.current_user_owns_profile(buyer_profile_id) or public.current_user_owns_profile(seller_profile_id))
  and not exists(select 1 from public.conversation_participant_state s where s.conversation_id=conversations.id and public.current_user_owns_profile(s.profile_id) and s.hidden_at is not null));
 create policy "Unbanned participants send messages" on public.messages for insert to authenticated with check(
  not public.current_user_is_banned() and public.current_user_owns_profile(sender_profile_id)
  and conversation_id in(select c.id from public.conversations c where sender_profile_id=c.buyer_profile_id or sender_profile_id=c.seller_profile_id));
 create policy "participants view messages" on public.messages for select to authenticated using(
  conversation_id in(select c.id from public.conversations c where public.current_user_owns_profile(c.buyer_profile_id) or public.current_user_owns_profile(c.seller_profile_id)));
end$mp4f_rollback$;

do $post$
begin
 -- Five is derived from the five restored policies above.
 if (select count(*) from pg_policy where polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass))<>5 then raise exception 'MP4-F rollback postcondition: policy count';end if;
 if (select count(*) from pg_policy where polrelid in('public.conversations'::regclass,'public.messages'::regclass,'public.conversation_participant_state'::regclass) and (coalesce(pg_get_expr(polqual,polrelid,false),'')||coalesce(pg_get_expr(polwithcheck,polrelid,false),'')) like '%current_user_owns_profile%')<>5 then raise exception 'MP4-F rollback postcondition: source authority missing';end if;
end$post$;
commit;
