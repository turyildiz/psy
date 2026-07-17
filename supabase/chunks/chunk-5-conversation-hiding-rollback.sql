begin;

-- Remove the new-message restoration trigger before its function.
drop trigger if exists messages_unhide_recipient_conversation
  on public.messages;

drop function if exists public.unhide_conversation_for_message_recipient();
drop function if exists public.find_and_unhide_conversation(uuid, uuid);
drop function if exists public.unhide_conversation(uuid);
drop function if exists public.hide_conversation(uuid);

-- Restore the captured participant visibility policy before dropping state.
drop policy if exists "participants view visible conversations"
  on public.conversations;

create policy "participants view conversations"
on public.conversations
for select
to public
using (
  buyer_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
  or seller_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

-- Restore the captured destructive participant DELETE capability.
grant delete on table public.conversations
  to anon, authenticated;

create policy "participants delete conversations"
on public.conversations
for delete
to public
using (
  buyer_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
  or seller_profile_id in (
    select p.id from public.profiles p where p.user_id = auth.uid()
  )
);

drop table if exists public.conversation_participant_state;

commit;
