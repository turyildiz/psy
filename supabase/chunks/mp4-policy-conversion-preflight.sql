-- MP-4 policy/function authorization replacement preflight.
-- OWNER-RUN, READ-ONLY. This script executes no application function and performs no write.
-- Package C evidence is repository/staging evidence frozen at commit 210941e98839f5320eec8d0edff97ae00dab8b9c.
with
expected_policies(table_name,policy_name,command,permissive,roles,using_expression,check_expression) as (
  values
    ('conversation_participant_state', 'Participants read own conversation state', 'r'::"char", true, array['authenticated']::text[], $q01$(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q01$, $c01$$c01$),
    ('conversations', 'Unbanned buyers create conversations', 'a'::"char", true, array['authenticated']::text[], $q02$$q02$, $c02$notcurrent_user_is_banned()and(buyer_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))andbuyer_profile_id<>seller_profile_idand(listing_idisnullorseller_profile_id=((selectl.profile_idfromlistingslwherel.id=conversations.listing_id)))$c02$),
    ('conversations', 'participants view visible conversations', 'r'::"char", true, array['authenticated']::text[], $q03$((buyer_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))or(seller_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid())))andnot(exists(select1fromconversation_participant_statesjoinprofilesponp.id=s.profile_idwheres.conversation_id=conversations.idandp.user_id=auth.uid()ands.hidden_atisnotnull))$q03$, $c03$$c03$),
    ('event_notifications', 'Unbanned users subscribe to event notifications', 'a'::"char", true, array['authenticated']::text[], $q04$$q04$, $c04$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$c04$),
    ('event_notifications', 'Unbanned users unsubscribe from event notifications', 'd'::"char", true, array['authenticated']::text[], $q05$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q05$, $c05$$c05$),
    ('event_notifications', 'Users can manage their own event notifications', 'r'::"char", true, array['PUBLIC']::text[], $q06$(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q06$, $c06$$c06$),
    ('favorites', 'Unbanned users manage own favorites', '*'::"char", true, array['authenticated']::text[], $q07$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q07$, $c07$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$c07$),
    ('favorites', 'Users can read their own favorites', 'r'::"char", true, array['PUBLIC']::text[], $q08$(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q08$, $c08$$c08$),
    ('follows', 'Unbanned users follow from own profile', 'a'::"char", true, array['authenticated']::text[], $q09$$q09$, $c09$notcurrent_user_is_banned()and(follower_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$c09$),
    ('follows', 'Unbanned users unfollow from own profile', 'd'::"char", true, array['authenticated']::text[], $q10$notcurrent_user_is_banned()and(follower_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q10$, $c10$$c10$),
    ('listings', 'Active and sold listings are publicly readable', 'r'::"char", true, array['PUBLIC']::text[], $q11$(status=any(array['active'::listing_status,'sold'::listing_status]))or(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q11$, $c11$$c11$),
    ('listings', 'Unbanned owners create active listings', 'a'::"char", true, array['authenticated']::text[], $q12$$q12$, $c12$notcurrent_user_is_banned()andstatus='active'::listing_statusandadmin_unpublished_atisnullandadmin_unpublished_byisnulland(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()andp.is_suspended=false))$c12$),
    ('listings', 'Unbanned owners delete own draft listings', 'd'::"char", true, array['authenticated']::text[], $q13$notcurrent_user_is_banned()andstatus='draft'::listing_statusandadmin_unpublished_atisnulland(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q13$, $c13$$c13$),
    ('listings', 'Unbanned owners update own listings', 'w'::"char", true, array['authenticated']::text[], $q14$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q14$, $c14$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))and(admin_unpublished_atisnullorstatus='draft'::listing_status)$c14$),
    ('messages', 'Unbanned participants send messages', 'a'::"char", true, array['authenticated']::text[], $q15$$q15$, $c15$notcurrent_user_is_banned()and(sender_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))and(conversation_idin(selectc.idfromconversationscwheremessages.sender_profile_id=c.buyer_profile_idormessages.sender_profile_id=c.seller_profile_id))$c15$),
    ('messages', 'participants view messages', 'r'::"char", true, array['PUBLIC']::text[], $q16$(conversation_idin(selectc.idfromconversationscwhere(c.buyer_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))or(c.seller_profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))))$q16$, $c16$$c16$),
    ('notice_posts', 'Unbanned users create own notice posts', 'a'::"char", true, array['authenticated']::text[], $q17$$q17$, $c17$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$c17$),
    ('notice_posts', 'Unbanned users delete own notice posts', 'd'::"char", true, array['authenticated']::text[], $q18$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q18$, $c18$$c18$),
    ('notice_reactions', 'Unbanned users add own reactions', 'a'::"char", true, array['authenticated']::text[], $q19$$q19$, $c19$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$c19$),
    ('notice_reactions', 'Unbanned users remove own reactions', 'd'::"char", true, array['authenticated']::text[], $q20$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q20$, $c20$$c20$),
    ('vendor_events', 'Unbanned users add own RSVP', 'a'::"char", true, array['authenticated']::text[], $q21$$q21$, $c21$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$c21$),
    ('vendor_events', 'Unbanned users remove own RSVP', 'd'::"char", true, array['authenticated']::text[], $q22$notcurrent_user_is_banned()and(profile_idin(selectp.idfromprofilespwherep.user_id=auth.uid()))$q22$, $c22$$c22$)
),
actual_policies as (
  select c.relname::text as table_name, pol.polname::text as policy_name,
    pol.polcmd as command, pol.polpermissive as permissive,
    array(select case when role_oid = 0 then 'PUBLIC' else role_oid::regrole::text end
          from unnest(pol.polroles) as r(role_oid) order by 1) as roles,
    lower(pg_catalog.regexp_replace(coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), ''), E'\\s+', '', 'g')) as using_expression,
    lower(pg_catalog.regexp_replace(coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), ''), E'\\s+', '', 'g')) as check_expression
  from pg_policy pol join pg_class c on c.oid=pol.polrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
),
expected_functions(function_name,identity_arguments,language_name,owner_name,volatility,security_definer,search_path_config,execute_grantees,expected_body) as (
  values
    ('append_unread_for', 'conv_id uuid, profile_id text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $ob01$declare
  caller_profile_id uuid;
  target_profile_id uuid := profile_id::uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot change unread state';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = conv_id
  limit 1;

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
end;$ob01$),
    ('remove_unread_for', 'conv_id uuid, profile_id text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $ob02$declare
  caller_profile_id uuid;
  target_profile_id uuid := profile_id::uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot change unread state';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = conv_id
  limit 1;

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
end;$ob02$),
    ('hide_conversation', 'target_conversation_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $ob03$declare
  caller_profile_id uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot hide conversations';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = target_conversation_id
  limit 1;

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
end;$ob03$),
    ('unhide_conversation', 'target_conversation_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $ob04$declare
  caller_profile_id uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot unhide conversations';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  join public.conversations c
    on p.id in (c.buyer_profile_id, c.seller_profile_id)
  where p.user_id = auth.uid()
    and c.id = target_conversation_id
  limit 1;

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
end;$ob04$),
    ('find_and_unhide_conversation', 'target_other_profile_id uuid, target_listing_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $ob05$declare
  caller_profile_id uuid;
  existing_conversation_id uuid;
begin
  if public.current_user_is_banned() then
    raise exception 'Banned accounts cannot open conversations';
  end if;

  select p.id
    into caller_profile_id
  from public.profiles p
  where p.user_id = auth.uid()
  limit 1;

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
end;$ob05$),
    ('create_post', 'target_profile_id uuid, post_body text, post_images text[], include_in_stream boolean', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $ob06$declare
  caller_user_id uuid := auth.uid();
  created_post_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot create posts'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = target_profile_id
      and p.user_id = caller_user_id
  ) then
    raise exception 'Post profile is not owned by the caller'
      using errcode = '42501';
  end if;

  if post_body is null
     or pg_catalog.char_length(post_body) not between 1 and 2000
     or pg_catalog.char_length(pg_catalog.btrim(post_body)) = 0 then
    raise exception 'Post body must contain between 1 and 2000 characters'
      using errcode = '22023';
  end if;

  if post_images is null
     or not public.post_images_belong_to_profile(target_profile_id, post_images) then
    raise exception 'Post images are invalid or outside the owner namespace'
      using errcode = '22023';
  end if;

  if not public.post_body_passes_link_blocklist(post_body) then
    raise exception 'Post body contains a blocked link domain'
      using errcode = '22023';
  end if;

  insert into public.posts (
    profile_id,
    body,
    images,
    show_in_stream
  ) values (
    target_profile_id,
    post_body,
    post_images,
    coalesce(include_in_stream, true)
  )
  returning id into created_post_id;

  return created_post_id;
end;$ob06$),
    ('update_post', 'target_post_id uuid, post_body text, post_images text[], include_in_stream boolean', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $ob07$declare
  caller_user_id uuid := auth.uid();
  author_profile_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot update posts'
      using errcode = '42501';
  end if;

  select p.profile_id
    into author_profile_id
  from public.posts as p
  where p.id = target_post_id
  for update;

  if author_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = author_profile_id
      and profile.user_id = caller_user_id
  ) then
    raise exception 'Post is not owned by the caller'
      using errcode = '42501';
  end if;

  if post_body is null
     or pg_catalog.char_length(post_body) not between 1 and 2000
     or pg_catalog.char_length(pg_catalog.btrim(post_body)) = 0 then
    raise exception 'Post body must contain between 1 and 2000 characters'
      using errcode = '22023';
  end if;

  if post_images is null
     or not public.post_images_belong_to_profile(author_profile_id, post_images) then
    raise exception 'Post images are invalid or outside the owner namespace'
      using errcode = '22023';
  end if;

  if not public.post_body_passes_link_blocklist(post_body) then
    raise exception 'Post body contains a blocked link domain'
      using errcode = '22023';
  end if;

  if include_in_stream is null then
    raise exception 'Post Stream visibility must be true or false'
      using errcode = '22023';
  end if;

  update public.posts as p
  set body = post_body,
      images = post_images,
      show_in_stream = include_in_stream,
      is_hero_featured = case
        when include_in_stream then p.is_hero_featured
        else false
      end,
      hero_featured_at = case
        when include_in_stream then p.hero_featured_at
        else null
      end,
      hero_featured_by = case
        when include_in_stream then p.hero_featured_by
        else null
      end
  where p.id = target_post_id;
end;$ob07$),
    ('delete_own_post', 'target_post_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $ob08$declare
  caller_user_id uuid := auth.uid();
  affected_rows bigint;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated post author required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot delete posts'
      using errcode = '42501';
  end if;

  delete from public.posts as post
  using public.profiles as profile
  where post.id = target_post_id
    and profile.id = post.profile_id
    and profile.user_id = caller_user_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;$ob08$),
    ('set_post_reaction', 'target_post_id uuid, target_profile_id uuid, target_reaction_code text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $ob09$declare
  caller_user_id uuid := auth.uid();
  parent_profile_id uuid;
  reaction_id uuid;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated reaction owner required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot react to posts'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles as p
    where p.id = target_profile_id
      and p.user_id = caller_user_id
  ) then
    raise exception 'Reaction profile is not owned by the caller'
      using errcode = '42501';
  end if;

  if not public.is_valid_post_reaction_code(target_reaction_code) then
    raise exception 'Unsupported post reaction code'
      using errcode = '22023';
  end if;

  select p.profile_id
    into parent_profile_id
  from public.posts as p
  where p.id = target_post_id;

  if parent_profile_id is null then
    raise exception 'Post does not exist'
      using errcode = 'P0002';
  end if;

  if public.profile_owner_is_banned(parent_profile_id) then
    raise exception 'Reactions are disabled while the post author is banned'
      using errcode = '42501';
  end if;

  insert into public.post_reactions as reaction (
    post_id,
    profile_id,
    reaction_code
  ) values (
    target_post_id,
    target_profile_id,
    target_reaction_code
  )
  on conflict (post_id, profile_id) do update
  set reaction_code = excluded.reaction_code
  returning reaction.id into reaction_id;

  return reaction_id;
end;$ob09$),
    ('remove_post_reaction', 'target_post_id uuid, target_profile_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $ob10$declare
  caller_user_id uuid := auth.uid();
  affected_rows bigint;
begin
  if auth.role() <> 'authenticated' or caller_user_id is null then
    raise exception 'Authenticated reaction owner required'
      using errcode = '42501';
  end if;

  if public.current_user_is_banned() then
    raise exception 'Banned users cannot remove reactions'
      using errcode = '42501';
  end if;

  delete from public.post_reactions as reaction
  using public.profiles as profile
  where reaction.post_id = target_post_id
    and reaction.profile_id = target_profile_id
    and profile.id = reaction.profile_id
    and profile.user_id = caller_user_id;

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Reaction does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;$ob10$)
),
actual_functions as (
  select p.proname::text as function_name,
    pg_get_function_identity_arguments(p.oid) as identity_arguments,
    l.lanname::text as language_name, p.proowner::regrole::text as owner_name,
    p.provolatile as volatility, p.prosecdef as security_definer,
    pg_get_function_result(p.oid) as result_type,
    p.proretset as returns_set, p.proisstrict as is_strict,
    p.proleakproof as is_leakproof, p.proparallel::text as parallel_safety,
    p.pronargdefaults as argument_default_count,
    coalesce(pg_get_expr(p.proargdefaults,0),'') as argument_defaults,
    array(select case when cfg in ('search_path=', 'search_path=""') then 'search_path=' else cfg end
          from unnest(coalesce(p.proconfig,'{}'::text[])) cfg order by 1) as all_config,
    array(select (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)
                 ||':'||a.privilege_type||':'||a.is_grantable::text
          from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a order by 1) as complete_acl,
    coalesce((select cfg from unnest(coalesce(p.proconfig,'{}'::text[])) cfg where cfg like 'search_path=%' limit 1),'') as search_path_config,
    array(select case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end
          from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
          where a.privilege_type='EXECUTE' and not a.is_grantable order by 1) as execute_grantees,
    pg_catalog.btrim(pg_catalog.regexp_replace(p.prosrc,E'\\s+',' ','g')) as normalized_body,
    pg_get_functiondef(p.oid) as complete_definition
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
  where n.nspname='public'
),
required_tables(table_name) as (values ('profiles'),('listings'),('conversations'),('messages'),('conversation_participant_state'),('vendor_events'),('notice_posts'),('notice_reactions'),('favorites'),('follows'),('event_notifications'),('posts'),('post_reactions')),
scoped_direct_functions(function_name) as (values
  ('get_my_profiles'),('current_user_owns_profile'),('admin_get_profile_account'),
  ('handle_new_user'),('admin_ban_user'),('admin_unban_user'),
  ('profile_owner_is_banned'),('post_images_belong_to_profile'),('clear_hero_on_author_ban')
),
baseline as (
  select
    to_regclass('public.profiles') is not null
      and coalesce((select relrowsecurity and not relforcerowsecurity from pg_class where oid=to_regclass('public.profiles')),false)
      and (select array_agg(attname order by attnum) from pg_attribute where attrelid=to_regclass('public.profiles') and attnum>0 and not attisdropped)
        = array['id','user_id','type','handle','display_name','bio','avatar_url','header_url','location','social_links','is_creator','is_verified','is_suspended','created_at','updated_at']::name[]
      and to_regclass('public.profiles_one_per_user_key') is not null
      and not exists (select 1 from required_tables r where to_regclass('public.'||r.table_name) is null)
      and (select count(*) from pg_policy where polrelid=to_regclass('public.profiles'))=3
      and has_table_privilege('anon','public.profiles','SELECT')
      and has_table_privilege('authenticated','public.profiles','SELECT')
      and has_table_privilege('service_role','public.profiles','SELECT') as package_a_baseline_ok,
    not exists ((select * from actual_policies where (table_name,policy_name) in (select table_name,policy_name from expected_policies) except select * from expected_policies) union all (select * from expected_policies except select * from actual_policies)) as old_policy_manifest_ok,
    not exists ((select function_name,identity_arguments,language_name,owner_name,volatility,security_definer,
      result_type,returns_set,is_strict,is_leakproof,parallel_safety,argument_default_count,argument_defaults,all_config,complete_acl,
      case when search_path_config in ('search_path=', 'search_path=""') then 'search_path=' else search_path_config end,
      execute_grantees, normalized_body from actual_functions
      where function_name in (select function_name from expected_functions) except select function_name,identity_arguments,language_name,owner_name,volatility,security_definer,
      case when function_name in ('find_and_unhide_conversation','create_post','set_post_reaction') then 'uuid' else 'void' end,
      false,false,false,'u',
      case when function_name='create_post' then 2 when function_name='find_and_unhide_conversation' then 1 else 0 end,
      case when function_name='create_post' then '''{}''::text[], true' when function_name='find_and_unhide_conversation' then 'NULL::uuid' else '' end,
      array[case when search_path_config in ('search_path=', 'search_path=""') then 'search_path=' else search_path_config end]::text[],
      array(select grantee||':EXECUTE:false' from unnest(execute_grantees) grantee order by 1),
      case when search_path_config in ('search_path=', 'search_path=""') then 'search_path=' else search_path_config end,
      execute_grantees, pg_catalog.btrim(pg_catalog.regexp_replace(expected_body,E'\\s+',' ','g')) from expected_functions) union all (select function_name,identity_arguments,language_name,owner_name,volatility,security_definer,
      case when function_name in ('find_and_unhide_conversation','create_post','set_post_reaction') then 'uuid' else 'void' end,
      false,false,false,'u',
      case when function_name='create_post' then 2 when function_name='find_and_unhide_conversation' then 1 else 0 end,
      case when function_name='create_post' then '''{}''::text[], true' when function_name='find_and_unhide_conversation' then 'NULL::uuid' else '' end,
      array[case when search_path_config in ('search_path=', 'search_path=""') then 'search_path=' else search_path_config end]::text[],
      array(select grantee||':EXECUTE:false' from unnest(execute_grantees) grantee order by 1),
      case when search_path_config in ('search_path=', 'search_path=""') then 'search_path=' else search_path_config end,
      execute_grantees, pg_catalog.btrim(pg_catalog.regexp_replace(expected_body,E'\\s+',' ','g')) from expected_functions except select function_name,identity_arguments,language_name,owner_name,volatility,security_definer,
      result_type,returns_set,is_strict,is_leakproof,parallel_safety,argument_default_count,argument_defaults,all_config,complete_acl,
      case when search_path_config in ('search_path=', 'search_path=""') then 'search_path=' else search_path_config end,
      execute_grantees, normalized_body from actual_functions
      where function_name in (select function_name from expected_functions))) as old_function_manifest_ok,
    to_regprocedure('public.current_user_owns_profile(uuid)') is not null
      and to_regprocedure('public.get_my_profiles()') is not null
      and to_regprocedure('public.admin_get_profile_account(uuid)') is not null
      and (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('get_my_profiles','current_user_owns_profile','admin_get_profile_account'))=3
      and has_function_privilege('authenticated','public.current_user_owns_profile(uuid)','EXECUTE')
      and not has_function_privilege('anon','public.current_user_owns_profile(uuid)','EXECUTE')
      and exists (
        select 1 from actual_functions a
        where a.function_name='current_user_owns_profile'
          and a.identity_arguments='target_profile_id uuid'
          and a.language_name='sql' and a.owner_name='postgres'
          and a.volatility='s' and a.security_definer
          and a.result_type='boolean' and not a.returns_set and not a.is_strict
          and not a.is_leakproof and a.parallel_safety='u' and a.argument_default_count=0
          and a.all_config=array['search_path=']::text[]
          and a.complete_acl=array['authenticated:EXECUTE:false','postgres:EXECUTE:false']::text[]
          and a.normalized_body=pg_catalog.btrim(pg_catalog.regexp_replace($pb_owner$
  with caller as (
    select auth.uid() as account_user_id
  )
  select coalesce(
    (
      select exists (
        select 1
        from public.profiles p
        where p.id = target_profile_id
          and p.user_id = c.account_user_id
      )
      from caller c
      where c.account_user_id is not null
    ),
    false
  );
$pb_owner$,E'\\s+',' ','g'))
      ) as package_b_ok,
    to_regprocedure('public.current_user_owns_unsuspended_profile(uuid)') is null as additive_helper_absent,
    not exists (
      select 1 from actual_policies a
      where (a.using_expression||a.check_expression) ~ 'profiles.*user_id'
        and (a.table_name,a.policy_name) not in (select table_name,policy_name from expected_policies)
        and a.table_name <> 'profiles'
    ) as no_unknown_direct_policy,
    not exists (
      select 1 from actual_functions a
      where lower(a.normalized_body) ~ 'profiles[\s\S]{0,180}user_id|user_id[\s\S]{0,180}profiles'
        and a.function_name not in (select function_name from expected_functions)
        and a.function_name not in (select function_name from scoped_direct_functions)
    ) as no_unknown_direct_function
),
fixtures as (
  select
    (select count(distinct p.user_id) from public.profiles p join public.users u on u.id=p.user_id where u.banned_at is null)>=2 as two_unbanned_owners,
    exists(select 1 from public.profiles p join public.users u on u.id=p.user_id where u.banned_at is not null) as banned_owner,
    exists(select 1 from public.events) as event_fixture,
    exists(select 1 from public.listings) as listing_fixture,
    exists(select 1 from public.posts) as post_fixture
),
verdict as (
  select b.*, f.*,
    case when not (b.package_a_baseline_ok and b.old_policy_manifest_ok and b.old_function_manifest_ok and b.package_b_ok and b.additive_helper_absent and b.no_unknown_direct_policy and b.no_unknown_direct_function) then 'STOP'
         when not (f.two_unbanned_owners and f.banned_owner and f.event_fixture and f.listing_fixture and f.post_fixture) then 'UNPROVEN'
         else 'GO' end as overall_status
  from baseline b cross join fixtures f
)
select
  'MP4_POLICY_CONVERSION_PREFLIGHT'::text as result_set,
  overall_status,
  case when package_a_baseline_ok then 'GO' else 'STOP' end as package_a_status,
  case when package_b_ok then 'GO' else 'STOP' end as package_b_status,
  'GO'::text as package_c_status,
  '210941e98839f5320eec8d0edff97ae00dab8b9c'::text as package_c_commit,
  case when old_policy_manifest_ok and no_unknown_direct_policy then 'GO' else 'STOP' end as policy_manifest_status,
  case when old_function_manifest_ok and no_unknown_direct_function then 'GO' else 'STOP' end as function_manifest_status,
  case when two_unbanned_owners and banned_owner and event_fixture and listing_fixture and post_fixture then 'GO' else 'UNPROVEN' end as fixture_status,
  array_remove(array[
    case when not package_a_baseline_ok then 'package_a_baseline_drift' end,
    case when not package_b_ok then 'package_b_contract_drift' end,
    case when not additive_helper_absent then 'mp4_helper_already_exists' end,
    case when not old_policy_manifest_ok then 'old_policy_definition_drift' end,
    case when not old_function_manifest_ok then 'old_function_definition_drift' end,
    case when not no_unknown_direct_policy then 'unknown_direct_owner_policy' end,
    case when not no_unknown_direct_function then 'unknown_direct_owner_function' end,
    case when not two_unbanned_owners then 'two_unbanned_profile_owners' end,
    case when not banned_owner then 'banned_profile_owner' end,
    case when not event_fixture then 'event_fixture' end,
    case when not listing_fixture then 'listing_fixture' end,
    case when not post_fixture then 'post_fixture' end
  ],null) as findings,
  (select jsonb_agg(jsonb_build_object('table',a.table_name,'policy',a.policy_name,'command',a.command,'permissive',a.permissive,'roles',a.roles,'using',a.using_expression,'with_check',a.check_expression) order by a.table_name,a.policy_name) from actual_policies a where (a.table_name,a.policy_name) in (select table_name,policy_name from expected_policies)) as exact_policy_manifest,
  (select jsonb_agg(jsonb_build_object('function',a.function_name,'arguments',a.identity_arguments,'language',a.language_name,'owner',a.owner_name,'volatility',a.volatility,'security_definer',a.security_definer,'search_path',a.search_path_config,'execute_grantees',a.execute_grantees,'definition',a.complete_definition) order by a.function_name,a.identity_arguments) from actual_functions a where a.function_name in (select function_name from expected_functions)) as exact_function_manifest
from verdict;
