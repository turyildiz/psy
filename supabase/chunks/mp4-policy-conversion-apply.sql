begin;
set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- Exact old-state guard; no raw prosrc hashes.
do $guard$
declare drift boolean;
begin
  with
expected_policies(table_name,policy_name,command,permissive,roles,using_expression,check_expression) as (
  values
    ('conversation_participant_state', 'Participants read own conversation state', 'r'::"char", true, array['authenticated']::text[], $q01$(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q01$, $c01$$c01$),
    ('conversations', 'Unbanned buyers create conversations', 'a'::"char", true, array['authenticated']::text[], $q02$$q02$, $c02$notcurrent_user_is_banned()and(buyer_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))andbuyer_profile_id<>seller_profile_idand(listing_idisnullorseller_profile_id=((selectprofile_idfromlistingswhereid=listing_id)))$c02$),
    ('conversations', 'participants view visible conversations', 'r'::"char", true, array['authenticated']::text[], $q03$((buyer_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))or(seller_profile_idin(selectidfromprofileswhereuser_id=auth.uid())))andnot(exists(select1fromconversation_participant_statejoinprofilesonid=profile_idwhereconversation_id=idanduser_id=auth.uid()andhidden_atisnotnull))$q03$, $c03$$c03$),
    ('event_notifications', 'Unbanned users subscribe to event notifications', 'a'::"char", true, array['authenticated']::text[], $q04$$q04$, $c04$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c04$),
    ('event_notifications', 'Unbanned users unsubscribe from event notifications', 'd'::"char", true, array['authenticated']::text[], $q05$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q05$, $c05$$c05$),
    ('event_notifications', 'Users can manage their own event notifications', 'r'::"char", true, array['PUBLIC']::text[], $q06$(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q06$, $c06$$c06$),
    ('favorites', 'Unbanned users manage own favorites', '*'::"char", true, array['authenticated']::text[], $q07$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q07$, $c07$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c07$),
    ('favorites', 'Users can read their own favorites', 'r'::"char", true, array['PUBLIC']::text[], $q08$(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q08$, $c08$$c08$),
    ('follows', 'Unbanned users follow from own profile', 'a'::"char", true, array['authenticated']::text[], $q09$$q09$, $c09$notcurrent_user_is_banned()and(follower_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c09$),
    ('follows', 'Unbanned users unfollow from own profile', 'd'::"char", true, array['authenticated']::text[], $q10$notcurrent_user_is_banned()and(follower_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q10$, $c10$$c10$),
    ('listings', 'Active and sold listings are publicly readable', 'r'::"char", true, array['PUBLIC']::text[], $q11$(status=any(array['active'::listing_status,'sold'::listing_status]))or(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q11$, $c11$$c11$),
    ('listings', 'Unbanned owners create active listings', 'a'::"char", true, array['authenticated']::text[], $q12$$q12$, $c12$notcurrent_user_is_banned()andstatus='active'::listing_statusandadmin_unpublished_atisnullandadmin_unpublished_byisnulland(profile_idin(selectidfromprofileswhereuser_id=auth.uid()andis_suspended=false))$c12$),
    ('listings', 'Unbanned owners delete own draft listings', 'd'::"char", true, array['authenticated']::text[], $q13$notcurrent_user_is_banned()andstatus='draft'::listing_statusandadmin_unpublished_atisnulland(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q13$, $c13$$c13$),
    ('listings', 'Unbanned owners update own listings', 'w'::"char", true, array['authenticated']::text[], $q14$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q14$, $c14$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))and(admin_unpublished_atisnullorstatus='draft'::listing_status)$c14$),
    ('messages', 'Unbanned participants send messages', 'a'::"char", true, array['authenticated']::text[], $q15$$q15$, $c15$notcurrent_user_is_banned()and(sender_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))and(conversation_idin(selectidfromconversationswheresender_profile_id=buyer_profile_idorsender_profile_id=seller_profile_id))$c15$),
    ('messages', 'participants view messages', 'r'::"char", true, array['PUBLIC']::text[], $q16$(conversation_idin(selectidfromconversationswhere(buyer_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))or(seller_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))))$q16$, $c16$$c16$),
    ('notice_posts', 'Unbanned users create own notice posts', 'a'::"char", true, array['authenticated']::text[], $q17$$q17$, $c17$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c17$),
    ('notice_posts', 'Unbanned users delete own notice posts', 'd'::"char", true, array['authenticated']::text[], $q18$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q18$, $c18$$c18$),
    ('notice_reactions', 'Unbanned users add own reactions', 'a'::"char", true, array['authenticated']::text[], $q19$$q19$, $c19$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c19$),
    ('notice_reactions', 'Unbanned users remove own reactions', 'd'::"char", true, array['authenticated']::text[], $q20$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q20$, $c20$$c20$),
    ('vendor_events', 'Unbanned users add own RSVP', 'a'::"char", true, array['authenticated']::text[], $q21$$q21$, $c21$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c21$),
    ('vendor_events', 'Unbanned users remove own RSVP', 'd'::"char", true, array['authenticated']::text[], $q22$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q22$, $c22$$c22$)
),
actual_policies as (
  select c.relname::text as table_name, pol.polname::text as policy_name,
    pol.polcmd as command, pol.polpermissive as permissive,
    array(select case when role_oid = 0 then 'PUBLIC' else role_oid::regrole::text end
          from unnest(pol.polroles) as r(role_oid) order by 1) as roles,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as using_expression,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as check_expression
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
)
  select exists ((select * from actual_policies where (table_name,policy_name) in (select table_name,policy_name from expected_policies) except select * from expected_policies) union all (select * from expected_policies except select * from actual_policies)) into drift;
  if drift then raise exception 'MP-4 precondition guard failed: policy manifest drift'; end if;

  with
expected_policies(table_name,policy_name,command,permissive,roles,using_expression,check_expression) as (
  values
    ('conversation_participant_state', 'Participants read own conversation state', 'r'::"char", true, array['authenticated']::text[], $q01$(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q01$, $c01$$c01$),
    ('conversations', 'Unbanned buyers create conversations', 'a'::"char", true, array['authenticated']::text[], $q02$$q02$, $c02$notcurrent_user_is_banned()and(buyer_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))andbuyer_profile_id<>seller_profile_idand(listing_idisnullorseller_profile_id=((selectprofile_idfromlistingswhereid=listing_id)))$c02$),
    ('conversations', 'participants view visible conversations', 'r'::"char", true, array['authenticated']::text[], $q03$((buyer_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))or(seller_profile_idin(selectidfromprofileswhereuser_id=auth.uid())))andnot(exists(select1fromconversation_participant_statejoinprofilesonid=profile_idwhereconversation_id=idanduser_id=auth.uid()andhidden_atisnotnull))$q03$, $c03$$c03$),
    ('event_notifications', 'Unbanned users subscribe to event notifications', 'a'::"char", true, array['authenticated']::text[], $q04$$q04$, $c04$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c04$),
    ('event_notifications', 'Unbanned users unsubscribe from event notifications', 'd'::"char", true, array['authenticated']::text[], $q05$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q05$, $c05$$c05$),
    ('event_notifications', 'Users can manage their own event notifications', 'r'::"char", true, array['PUBLIC']::text[], $q06$(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q06$, $c06$$c06$),
    ('favorites', 'Unbanned users manage own favorites', '*'::"char", true, array['authenticated']::text[], $q07$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q07$, $c07$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c07$),
    ('favorites', 'Users can read their own favorites', 'r'::"char", true, array['PUBLIC']::text[], $q08$(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q08$, $c08$$c08$),
    ('follows', 'Unbanned users follow from own profile', 'a'::"char", true, array['authenticated']::text[], $q09$$q09$, $c09$notcurrent_user_is_banned()and(follower_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c09$),
    ('follows', 'Unbanned users unfollow from own profile', 'd'::"char", true, array['authenticated']::text[], $q10$notcurrent_user_is_banned()and(follower_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q10$, $c10$$c10$),
    ('listings', 'Active and sold listings are publicly readable', 'r'::"char", true, array['PUBLIC']::text[], $q11$(status=any(array['active'::listing_status,'sold'::listing_status]))or(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q11$, $c11$$c11$),
    ('listings', 'Unbanned owners create active listings', 'a'::"char", true, array['authenticated']::text[], $q12$$q12$, $c12$notcurrent_user_is_banned()andstatus='active'::listing_statusandadmin_unpublished_atisnullandadmin_unpublished_byisnulland(profile_idin(selectidfromprofileswhereuser_id=auth.uid()andis_suspended=false))$c12$),
    ('listings', 'Unbanned owners delete own draft listings', 'd'::"char", true, array['authenticated']::text[], $q13$notcurrent_user_is_banned()andstatus='draft'::listing_statusandadmin_unpublished_atisnulland(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q13$, $c13$$c13$),
    ('listings', 'Unbanned owners update own listings', 'w'::"char", true, array['authenticated']::text[], $q14$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q14$, $c14$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))and(admin_unpublished_atisnullorstatus='draft'::listing_status)$c14$),
    ('messages', 'Unbanned participants send messages', 'a'::"char", true, array['authenticated']::text[], $q15$$q15$, $c15$notcurrent_user_is_banned()and(sender_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))and(conversation_idin(selectidfromconversationswheresender_profile_id=buyer_profile_idorsender_profile_id=seller_profile_id))$c15$),
    ('messages', 'participants view messages', 'r'::"char", true, array['PUBLIC']::text[], $q16$(conversation_idin(selectidfromconversationswhere(buyer_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))or(seller_profile_idin(selectidfromprofileswhereuser_id=auth.uid()))))$q16$, $c16$$c16$),
    ('notice_posts', 'Unbanned users create own notice posts', 'a'::"char", true, array['authenticated']::text[], $q17$$q17$, $c17$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c17$),
    ('notice_posts', 'Unbanned users delete own notice posts', 'd'::"char", true, array['authenticated']::text[], $q18$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q18$, $c18$$c18$),
    ('notice_reactions', 'Unbanned users add own reactions', 'a'::"char", true, array['authenticated']::text[], $q19$$q19$, $c19$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c19$),
    ('notice_reactions', 'Unbanned users remove own reactions', 'd'::"char", true, array['authenticated']::text[], $q20$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q20$, $c20$$c20$),
    ('vendor_events', 'Unbanned users add own RSVP', 'a'::"char", true, array['authenticated']::text[], $q21$$q21$, $c21$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$c21$),
    ('vendor_events', 'Unbanned users remove own RSVP', 'd'::"char", true, array['authenticated']::text[], $q22$notcurrent_user_is_banned()and(profile_idin(selectidfromprofileswhereuser_id=auth.uid()))$q22$, $c22$$c22$)
),
actual_policies as (
  select c.relname::text as table_name, pol.polname::text as policy_name,
    pol.polcmd as command, pol.polpermissive as permissive,
    array(select case when role_oid = 0 then 'PUBLIC' else role_oid::regrole::text end
          from unnest(pol.polroles) as r(role_oid) order by 1) as roles,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as using_expression,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as check_expression
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
)
  select exists ((select function_name,identity_arguments,language_name,owner_name,volatility,security_definer,
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
      where function_name in (select function_name from expected_functions))) into drift;
  if drift then raise exception 'MP-4 precondition guard failed: function manifest drift'; end if;
end;
$guard$;

do $package_b_helper_guard$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    join pg_language l on l.oid=p.prolang
    where n.nspname='public' and p.proname='current_user_owns_profile'
      and pg_get_function_identity_arguments(p.oid)='target_profile_id uuid'
      and pg_get_function_result(p.oid)='boolean'
      and l.lanname='sql' and p.proowner::regrole::text='postgres'
      and p.provolatile='s' and p.prosecdef and not p.proretset and not p.proisstrict
      and not p.proleakproof and p.proparallel='u' and p.pronargdefaults=0
      and array(select case when cfg in ('search_path=', 'search_path=""') then 'search_path=' else cfg end
                from unnest(coalesce(p.proconfig,'{}'::text[])) cfg order by 1)=array['search_path=']::text[]
      and array(select (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)
                       ||':'||a.privilege_type||':'||a.is_grantable::text
                from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a order by 1)
          =array['authenticated:EXECUTE:false','postgres:EXECUTE:false']::text[]
      and pg_catalog.btrim(pg_catalog.regexp_replace(p.prosrc,E'\\s+',' ','g'))
          =pg_catalog.btrim(pg_catalog.regexp_replace($pb_body$
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
$pb_body$,E'\\s+',' ','g'))
  ) then raise exception 'MP-4 guard failed: Package B ownership helper definition/ACL drift'; end if;
end;
$package_b_helper_guard$;

create function public.current_user_owns_unsuspended_profile(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    public.current_user_owns_profile(target_profile_id)
    and coalesce((
      select not p.is_suspended
      from public.profiles as p
      where p.id = target_profile_id
    ), false);
$function$;
alter function public.current_user_owns_unsuspended_profile(uuid) owner to postgres;
revoke all on function public.current_user_owns_unsuspended_profile(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.current_user_owns_unsuspended_profile(uuid)
  to authenticated;
comment on function public.current_user_owns_unsuspended_profile(uuid) is
  'Private ownership-and-suspension boolean used by listing creation authorization; returns no owner identifier.';

drop policy "Active and sold listings are publicly readable" on public.listings;
create policy "Active and sold listings are publicly readable"
on public.listings
for select
to public
using (status = any (array['active'::public.listing_status, 'sold'::public.listing_status]));
create policy "Owners can read own private listings"
on public.listings
for select
to authenticated
using (public.current_user_owns_profile(profile_id));

drop policy "Unbanned owners create active listings" on public.listings;
create policy "Unbanned owners create active listings"
on public.listings
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and status = 'active'::public.listing_status
  and admin_unpublished_at is null
  and admin_unpublished_by is null
  and public.current_user_owns_unsuspended_profile(profile_id)
);

drop policy "Unbanned owners update own listings" on public.listings;
create policy "Unbanned owners update own listings"
on public.listings
for update
to authenticated
using (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
)
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
  and (
    admin_unpublished_at is null
    or status = 'draft'::public.listing_status
  )
);

drop policy "Unbanned owners delete own draft listings" on public.listings;
create policy "Unbanned owners delete own draft listings"
on public.listings
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and status = 'draft'::public.listing_status
  and admin_unpublished_at is null
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned buyers create conversations" on public.conversations;
create policy "Unbanned buyers create conversations"
on public.conversations
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(buyer_profile_id)
  and buyer_profile_id <> seller_profile_id
  and (
    listing_id is null
    or seller_profile_id = (
      select l.profile_id from public.listings l where l.id = listing_id
    )
  )
);

drop policy "Unbanned participants send messages" on public.messages;
create policy "Unbanned participants send messages"
on public.messages
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(sender_profile_id)
  and conversation_id in (
    select c.id
    from public.conversations c
    where sender_profile_id in (c.buyer_profile_id, c.seller_profile_id)
  )
);

drop policy "Unbanned users add own RSVP" on public.vendor_events;
create policy "Unbanned users add own RSVP"
on public.vendor_events
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users remove own RSVP" on public.vendor_events;
create policy "Unbanned users remove own RSVP"
on public.vendor_events
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users create own notice posts" on public.notice_posts;
create policy "Unbanned users create own notice posts"
on public.notice_posts
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users delete own notice posts" on public.notice_posts;
create policy "Unbanned users delete own notice posts"
on public.notice_posts
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users add own reactions" on public.notice_reactions;
create policy "Unbanned users add own reactions"
on public.notice_reactions
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users remove own reactions" on public.notice_reactions;
create policy "Unbanned users remove own reactions"
on public.notice_reactions
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Users can read their own favorites" on public.favorites;
create policy "Users can read their own favorites"
on public.favorites
for select
to authenticated
using (
  public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users manage own favorites" on public.favorites;
create policy "Unbanned users manage own favorites"
on public.favorites
for all
to authenticated
using (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
)
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users follow from own profile" on public.follows;
create policy "Unbanned users follow from own profile"
on public.follows
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(follower_profile_id)
);

drop policy "Unbanned users unfollow from own profile" on public.follows;
create policy "Unbanned users unfollow from own profile"
on public.follows
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(follower_profile_id)
);

drop policy "Unbanned users subscribe to event notifications" on public.event_notifications;
create policy "Unbanned users subscribe to event notifications"
on public.event_notifications
for insert
to authenticated
with check (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Unbanned users unsubscribe from event notifications" on public.event_notifications;
create policy "Unbanned users unsubscribe from event notifications"
on public.event_notifications
for delete
to authenticated
using (
  not public.current_user_is_banned()
  and public.current_user_owns_profile(profile_id)
);

drop policy "Participants read own conversation state" on public.conversation_participant_state;
create policy "Participants read own conversation state"
on public.conversation_participant_state
for select
to authenticated
using (
  public.current_user_owns_profile(profile_id)
);

drop policy "participants view visible conversations" on public.conversations;
create policy "participants view visible conversations"
on public.conversations
for select
to authenticated
using (
  (
    public.current_user_owns_profile(buyer_profile_id)
    or public.current_user_owns_profile(seller_profile_id)
  )
  and not exists (
    select 1
    from public.conversation_participant_state s
    where s.conversation_id = conversations.id
      and public.current_user_owns_profile(s.profile_id)
      and s.hidden_at is not null
  )
);

drop policy "participants view messages" on public.messages;
create policy "participants view messages"
on public.messages
for select
to authenticated
using (
  conversation_id in (
    select c.id
    from public.conversations c
    where public.current_user_owns_profile(c.buyer_profile_id) or public.current_user_owns_profile(c.seller_profile_id)
  )
);

drop policy "Users can manage their own event notifications" on public.event_notifications;
create policy "Users can manage their own event notifications"
on public.event_notifications
for select
to authenticated
using (
  public.current_user_owns_profile(profile_id)
);

create or replace function public.append_unread_for(
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
$$;

create or replace function public.remove_unread_for(
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
$$;

create or replace function public.hide_conversation(
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
$$;

create or replace function public.unhide_conversation(
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
$$;

create or replace function public.find_and_unhide_conversation(
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
$$;

create or replace function public.create_post(
  target_profile_id uuid,
  post_body text,
  post_images text[] default '{}'::text[],
  include_in_stream boolean default true
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
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

  if not public.current_user_owns_profile(target_profile_id) then
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
end;
$function$;

create or replace function public.update_post(
  target_post_id uuid,
  post_body text,
  post_images text[],
  include_in_stream boolean
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
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

  if not public.current_user_owns_profile(author_profile_id) then
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
end;
$function$;

create or replace function public.delete_own_post(
  target_post_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
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
  where post.id = target_post_id
    and public.current_user_owns_profile(post.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;
$function$;

create or replace function public.set_post_reaction(
  target_post_id uuid,
  target_profile_id uuid,
  target_reaction_code text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
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

  if not public.current_user_owns_profile(target_profile_id) then
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
end;
$function$;

create or replace function public.remove_post_reaction(
  target_post_id uuid,
  target_profile_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
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
  where reaction.post_id = target_post_id
    and reaction.profile_id = target_profile_id
    and public.current_user_owns_profile(reaction.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Reaction does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;
$function$;

alter function public.append_unread_for(uuid,text) owner to postgres;
alter function public.remove_unread_for(uuid,text) owner to postgres;
alter function public.hide_conversation(uuid) owner to postgres;
alter function public.unhide_conversation(uuid) owner to postgres;
alter function public.find_and_unhide_conversation(uuid,uuid) owner to postgres;
alter function public.create_post(uuid,text,text[],boolean) owner to postgres;
alter function public.update_post(uuid,text,text[],boolean) owner to postgres;
alter function public.delete_own_post(uuid) owner to postgres;
alter function public.set_post_reaction(uuid,uuid,text) owner to postgres;
alter function public.remove_post_reaction(uuid,uuid) owner to postgres;
revoke all on function public.append_unread_for(uuid,text), public.remove_unread_for(uuid,text), public.hide_conversation(uuid), public.unhide_conversation(uuid), public.find_and_unhide_conversation(uuid,uuid) from public, anon, authenticated, service_role;
grant execute on function public.append_unread_for(uuid,text), public.remove_unread_for(uuid,text), public.hide_conversation(uuid), public.unhide_conversation(uuid), public.find_and_unhide_conversation(uuid,uuid) to authenticated, service_role;
revoke all on function public.create_post(uuid,text,text[],boolean), public.update_post(uuid,text,text[],boolean), public.delete_own_post(uuid), public.set_post_reaction(uuid,uuid,text), public.remove_post_reaction(uuid,uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_post(uuid,text,text[],boolean), public.update_post(uuid,text,text[],boolean), public.delete_own_post(uuid), public.set_post_reaction(uuid,uuid,text), public.remove_post_reaction(uuid,uuid) to authenticated;

-- Exact new-state postcondition.
do $guard$
declare drift boolean;
begin
  with
expected_policies(table_name,policy_name,command,permissive,roles,using_expression,check_expression) as (
  values
    ('conversation_participant_state', 'Participants read own conversation state', 'r'::"char", true, array['authenticated']::text[], $q01$current_user_owns_profile(profile_id)$q01$, $c01$$c01$),
    ('conversations', 'Unbanned buyers create conversations', 'a'::"char", true, array['authenticated']::text[], $q02$$q02$, $c02$notcurrent_user_is_banned()andcurrent_user_owns_profile(buyer_profile_id)andbuyer_profile_id<>seller_profile_idand(listing_idisnullorseller_profile_id=((selectprofile_idfromlistingswhereid=listing_id)))$c02$),
    ('conversations', 'participants view visible conversations', 'r'::"char", true, array['authenticated']::text[], $q03$(current_user_owns_profile(buyer_profile_id)orcurrent_user_owns_profile(seller_profile_id))andnot(exists(select1fromconversation_participant_statewhereconversation_id=idandcurrent_user_owns_profile(profile_id)andhidden_atisnotnull))$q03$, $c03$$c03$),
    ('event_notifications', 'Unbanned users subscribe to event notifications', 'a'::"char", true, array['authenticated']::text[], $q04$$q04$, $c04$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c04$),
    ('event_notifications', 'Unbanned users unsubscribe from event notifications', 'd'::"char", true, array['authenticated']::text[], $q05$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q05$, $c05$$c05$),
    ('event_notifications', 'Users can manage their own event notifications', 'r'::"char", true, array['authenticated']::text[], $q06$current_user_owns_profile(profile_id)$q06$, $c06$$c06$),
    ('favorites', 'Unbanned users manage own favorites', '*'::"char", true, array['authenticated']::text[], $q07$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q07$, $c07$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c07$),
    ('favorites', 'Users can read their own favorites', 'r'::"char", true, array['authenticated']::text[], $q08$current_user_owns_profile(profile_id)$q08$, $c08$$c08$),
    ('follows', 'Unbanned users follow from own profile', 'a'::"char", true, array['authenticated']::text[], $q09$$q09$, $c09$notcurrent_user_is_banned()andcurrent_user_owns_profile(follower_profile_id)$c09$),
    ('follows', 'Unbanned users unfollow from own profile', 'd'::"char", true, array['authenticated']::text[], $q10$notcurrent_user_is_banned()andcurrent_user_owns_profile(follower_profile_id)$q10$, $c10$$c10$),
    ('listings', 'Active and sold listings are publicly readable', 'r'::"char", true, array['PUBLIC']::text[], $q11$status=any(array['active'::listing_status,'sold'::listing_status])$q11$, $c11$$c11$),
    ('listings', 'Owners can read own private listings', 'r'::"char", true, array['authenticated']::text[], $q12$current_user_owns_profile(profile_id)$q12$, $c12$$c12$),
    ('listings', 'Unbanned owners create active listings', 'a'::"char", true, array['authenticated']::text[], $q13$$q13$, $c13$notcurrent_user_is_banned()andstatus='active'::listing_statusandadmin_unpublished_atisnullandadmin_unpublished_byisnullandcurrent_user_owns_unsuspended_profile(profile_id)$c13$),
    ('listings', 'Unbanned owners delete own draft listings', 'd'::"char", true, array['authenticated']::text[], $q14$notcurrent_user_is_banned()andstatus='draft'::listing_statusandadmin_unpublished_atisnullandcurrent_user_owns_profile(profile_id)$q14$, $c14$$c14$),
    ('listings', 'Unbanned owners update own listings', 'w'::"char", true, array['authenticated']::text[], $q15$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q15$, $c15$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)and(admin_unpublished_atisnullorstatus='draft'::listing_status)$c15$),
    ('messages', 'Unbanned participants send messages', 'a'::"char", true, array['authenticated']::text[], $q16$$q16$, $c16$notcurrent_user_is_banned()andcurrent_user_owns_profile(sender_profile_id)and(conversation_idin(selectidfromconversationswheresender_profile_id=buyer_profile_idorsender_profile_id=seller_profile_id))$c16$),
    ('messages', 'participants view messages', 'r'::"char", true, array['authenticated']::text[], $q17$(conversation_idin(selectidfromconversationswherecurrent_user_owns_profile(buyer_profile_id)orcurrent_user_owns_profile(seller_profile_id)))$q17$, $c17$$c17$),
    ('notice_posts', 'Unbanned users create own notice posts', 'a'::"char", true, array['authenticated']::text[], $q18$$q18$, $c18$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c18$),
    ('notice_posts', 'Unbanned users delete own notice posts', 'd'::"char", true, array['authenticated']::text[], $q19$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q19$, $c19$$c19$),
    ('notice_reactions', 'Unbanned users add own reactions', 'a'::"char", true, array['authenticated']::text[], $q20$$q20$, $c20$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c20$),
    ('notice_reactions', 'Unbanned users remove own reactions', 'd'::"char", true, array['authenticated']::text[], $q21$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q21$, $c21$$c21$),
    ('vendor_events', 'Unbanned users add own RSVP', 'a'::"char", true, array['authenticated']::text[], $q22$$q22$, $c22$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c22$),
    ('vendor_events', 'Unbanned users remove own RSVP', 'd'::"char", true, array['authenticated']::text[], $q23$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q23$, $c23$$c23$)
),
actual_policies as (
  select c.relname::text as table_name, pol.polname::text as policy_name,
    pol.polcmd as command, pol.polpermissive as permissive,
    array(select case when role_oid = 0 then 'PUBLIC' else role_oid::regrole::text end
          from unnest(pol.polroles) as r(role_oid) order by 1) as roles,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as using_expression,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as check_expression
  from pg_policy pol join pg_class c on c.oid=pol.polrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
),
expected_functions(function_name,identity_arguments,language_name,owner_name,volatility,security_definer,search_path_config,execute_grantees,expected_body) as (
  values
    ('append_unread_for', 'conv_id uuid, profile_id text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb01$declare
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
end;$nb01$),
    ('remove_unread_for', 'conv_id uuid, profile_id text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb02$declare
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
end;$nb02$),
    ('hide_conversation', 'target_conversation_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb03$declare
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
end;$nb03$),
    ('unhide_conversation', 'target_conversation_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb04$declare
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
end;$nb04$),
    ('find_and_unhide_conversation', 'target_other_profile_id uuid, target_listing_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb05$declare
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
end;$nb05$),
    ('create_post', 'target_profile_id uuid, post_body text, post_images text[], include_in_stream boolean', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb06$declare
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

  if not public.current_user_owns_profile(target_profile_id) then
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
end;$nb06$),
    ('update_post', 'target_post_id uuid, post_body text, post_images text[], include_in_stream boolean', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb07$declare
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

  if not public.current_user_owns_profile(author_profile_id) then
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
end;$nb07$),
    ('delete_own_post', 'target_post_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb08$declare
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
  where post.id = target_post_id
    and public.current_user_owns_profile(post.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;$nb08$),
    ('set_post_reaction', 'target_post_id uuid, target_profile_id uuid, target_reaction_code text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb09$declare
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

  if not public.current_user_owns_profile(target_profile_id) then
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
end;$nb09$),
    ('remove_post_reaction', 'target_post_id uuid, target_profile_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb10$declare
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
  where reaction.post_id = target_post_id
    and reaction.profile_id = target_profile_id
    and public.current_user_owns_profile(reaction.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Reaction does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;$nb10$)
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
)
  select exists ((select * from actual_policies where (table_name,policy_name) in (select table_name,policy_name from expected_policies) except select * from expected_policies) union all (select * from expected_policies except select * from actual_policies)) into drift;
  if drift then raise exception 'MP-4 postcondition guard failed: policy manifest drift'; end if;

  with
expected_policies(table_name,policy_name,command,permissive,roles,using_expression,check_expression) as (
  values
    ('conversation_participant_state', 'Participants read own conversation state', 'r'::"char", true, array['authenticated']::text[], $q01$current_user_owns_profile(profile_id)$q01$, $c01$$c01$),
    ('conversations', 'Unbanned buyers create conversations', 'a'::"char", true, array['authenticated']::text[], $q02$$q02$, $c02$notcurrent_user_is_banned()andcurrent_user_owns_profile(buyer_profile_id)andbuyer_profile_id<>seller_profile_idand(listing_idisnullorseller_profile_id=((selectprofile_idfromlistingswhereid=listing_id)))$c02$),
    ('conversations', 'participants view visible conversations', 'r'::"char", true, array['authenticated']::text[], $q03$(current_user_owns_profile(buyer_profile_id)orcurrent_user_owns_profile(seller_profile_id))andnot(exists(select1fromconversation_participant_statewhereconversation_id=idandcurrent_user_owns_profile(profile_id)andhidden_atisnotnull))$q03$, $c03$$c03$),
    ('event_notifications', 'Unbanned users subscribe to event notifications', 'a'::"char", true, array['authenticated']::text[], $q04$$q04$, $c04$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c04$),
    ('event_notifications', 'Unbanned users unsubscribe from event notifications', 'd'::"char", true, array['authenticated']::text[], $q05$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q05$, $c05$$c05$),
    ('event_notifications', 'Users can manage their own event notifications', 'r'::"char", true, array['authenticated']::text[], $q06$current_user_owns_profile(profile_id)$q06$, $c06$$c06$),
    ('favorites', 'Unbanned users manage own favorites', '*'::"char", true, array['authenticated']::text[], $q07$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q07$, $c07$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c07$),
    ('favorites', 'Users can read their own favorites', 'r'::"char", true, array['authenticated']::text[], $q08$current_user_owns_profile(profile_id)$q08$, $c08$$c08$),
    ('follows', 'Unbanned users follow from own profile', 'a'::"char", true, array['authenticated']::text[], $q09$$q09$, $c09$notcurrent_user_is_banned()andcurrent_user_owns_profile(follower_profile_id)$c09$),
    ('follows', 'Unbanned users unfollow from own profile', 'd'::"char", true, array['authenticated']::text[], $q10$notcurrent_user_is_banned()andcurrent_user_owns_profile(follower_profile_id)$q10$, $c10$$c10$),
    ('listings', 'Active and sold listings are publicly readable', 'r'::"char", true, array['PUBLIC']::text[], $q11$status=any(array['active'::listing_status,'sold'::listing_status])$q11$, $c11$$c11$),
    ('listings', 'Owners can read own private listings', 'r'::"char", true, array['authenticated']::text[], $q12$current_user_owns_profile(profile_id)$q12$, $c12$$c12$),
    ('listings', 'Unbanned owners create active listings', 'a'::"char", true, array['authenticated']::text[], $q13$$q13$, $c13$notcurrent_user_is_banned()andstatus='active'::listing_statusandadmin_unpublished_atisnullandadmin_unpublished_byisnullandcurrent_user_owns_unsuspended_profile(profile_id)$c13$),
    ('listings', 'Unbanned owners delete own draft listings', 'd'::"char", true, array['authenticated']::text[], $q14$notcurrent_user_is_banned()andstatus='draft'::listing_statusandadmin_unpublished_atisnullandcurrent_user_owns_profile(profile_id)$q14$, $c14$$c14$),
    ('listings', 'Unbanned owners update own listings', 'w'::"char", true, array['authenticated']::text[], $q15$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q15$, $c15$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)and(admin_unpublished_atisnullorstatus='draft'::listing_status)$c15$),
    ('messages', 'Unbanned participants send messages', 'a'::"char", true, array['authenticated']::text[], $q16$$q16$, $c16$notcurrent_user_is_banned()andcurrent_user_owns_profile(sender_profile_id)and(conversation_idin(selectidfromconversationswheresender_profile_id=buyer_profile_idorsender_profile_id=seller_profile_id))$c16$),
    ('messages', 'participants view messages', 'r'::"char", true, array['authenticated']::text[], $q17$(conversation_idin(selectidfromconversationswherecurrent_user_owns_profile(buyer_profile_id)orcurrent_user_owns_profile(seller_profile_id)))$q17$, $c17$$c17$),
    ('notice_posts', 'Unbanned users create own notice posts', 'a'::"char", true, array['authenticated']::text[], $q18$$q18$, $c18$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c18$),
    ('notice_posts', 'Unbanned users delete own notice posts', 'd'::"char", true, array['authenticated']::text[], $q19$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q19$, $c19$$c19$),
    ('notice_reactions', 'Unbanned users add own reactions', 'a'::"char", true, array['authenticated']::text[], $q20$$q20$, $c20$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c20$),
    ('notice_reactions', 'Unbanned users remove own reactions', 'd'::"char", true, array['authenticated']::text[], $q21$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q21$, $c21$$c21$),
    ('vendor_events', 'Unbanned users add own RSVP', 'a'::"char", true, array['authenticated']::text[], $q22$$q22$, $c22$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$c22$),
    ('vendor_events', 'Unbanned users remove own RSVP', 'd'::"char", true, array['authenticated']::text[], $q23$notcurrent_user_is_banned()andcurrent_user_owns_profile(profile_id)$q23$, $c23$$c23$)
),
actual_policies as (
  select c.relname::text as table_name, pol.polname::text as policy_name,
    pol.polcmd as command, pol.polpermissive as permissive,
    array(select case when role_oid = 0 then 'PUBLIC' else role_oid::regrole::text end
          from unnest(pol.polroles) as r(role_oid) order by 1) as roles,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polqual, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as using_expression,
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            lower(coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), '')),
            '(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]*[.]', '', 'g'),
          '[[:<:]](p|c|l|s)[[:>:]][[:space:]]*[.]', '', 'g'),
        '([[:<:]]from|[[:<:]]join)[[:space:]]+(public[.])?(conversation_participant_state|event_notifications|notice_reactions|notice_posts|vendor_events|conversations|profiles|listings|favorites|follows|messages)[[:space:]]+(as[[:space:]]+)?(p|c|l|s)[[:>:]]', '\1 \3', 'g'),
      '[[:space:]]+', '', 'g') as check_expression
  from pg_policy pol join pg_class c on c.oid=pol.polrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
),
expected_functions(function_name,identity_arguments,language_name,owner_name,volatility,security_definer,search_path_config,execute_grantees,expected_body) as (
  values
    ('append_unread_for', 'conv_id uuid, profile_id text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb01$declare
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
end;$nb01$),
    ('remove_unread_for', 'conv_id uuid, profile_id text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb02$declare
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
end;$nb02$),
    ('hide_conversation', 'target_conversation_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb03$declare
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
end;$nb03$),
    ('unhide_conversation', 'target_conversation_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb04$declare
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
end;$nb04$),
    ('find_and_unhide_conversation', 'target_other_profile_id uuid, target_listing_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=pg_catalog, public, auth', array['authenticated','postgres','service_role']::text[], $nb05$declare
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
end;$nb05$),
    ('create_post', 'target_profile_id uuid, post_body text, post_images text[], include_in_stream boolean', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb06$declare
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

  if not public.current_user_owns_profile(target_profile_id) then
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
end;$nb06$),
    ('update_post', 'target_post_id uuid, post_body text, post_images text[], include_in_stream boolean', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb07$declare
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

  if not public.current_user_owns_profile(author_profile_id) then
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
end;$nb07$),
    ('delete_own_post', 'target_post_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb08$declare
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
  where post.id = target_post_id
    and public.current_user_owns_profile(post.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Post does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;$nb08$),
    ('set_post_reaction', 'target_post_id uuid, target_profile_id uuid, target_reaction_code text', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb09$declare
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

  if not public.current_user_owns_profile(target_profile_id) then
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
end;$nb09$),
    ('remove_post_reaction', 'target_post_id uuid, target_profile_id uuid', 'plpgsql', 'postgres', 'v'::"char", true, 'search_path=', array['authenticated','postgres']::text[], $nb10$declare
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
  where reaction.post_id = target_post_id
    and reaction.profile_id = target_profile_id
    and public.current_user_owns_profile(reaction.profile_id);

  get diagnostics affected_rows = row_count;
  if affected_rows <> 1 then
    raise exception 'Reaction does not exist or is not owned by the caller'
      using errcode = '42501';
  end if;
end;$nb10$)
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
)
  select exists ((select function_name,identity_arguments,language_name,owner_name,volatility,security_definer,
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
      where function_name in (select function_name from expected_functions))) into drift;
  if drift then raise exception 'MP-4 postcondition guard failed: function manifest drift'; end if;
end;
$guard$;

do $package_b_helper_guard$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    join pg_language l on l.oid=p.prolang
    where n.nspname='public' and p.proname='current_user_owns_profile'
      and pg_get_function_identity_arguments(p.oid)='target_profile_id uuid'
      and pg_get_function_result(p.oid)='boolean'
      and l.lanname='sql' and p.proowner::regrole::text='postgres'
      and p.provolatile='s' and p.prosecdef and not p.proretset and not p.proisstrict
      and not p.proleakproof and p.proparallel='u' and p.pronargdefaults=0
      and array(select case when cfg in ('search_path=', 'search_path=""') then 'search_path=' else cfg end
                from unnest(coalesce(p.proconfig,'{}'::text[])) cfg order by 1)=array['search_path=']::text[]
      and array(select (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)
                       ||':'||a.privilege_type||':'||a.is_grantable::text
                from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a order by 1)
          =array['authenticated:EXECUTE:false','postgres:EXECUTE:false']::text[]
      and pg_catalog.btrim(pg_catalog.regexp_replace(p.prosrc,E'\\s+',' ','g'))
          =pg_catalog.btrim(pg_catalog.regexp_replace($pb_body$
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
$pb_body$,E'\\s+',' ','g'))
  ) then raise exception 'MP-4 guard failed: Package B ownership helper definition/ACL drift'; end if;
end;
$package_b_helper_guard$;

do $mp4_helper_guard$
begin
  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    join pg_language l on l.oid=p.prolang
    where n.nspname='public' and p.proname='current_user_owns_unsuspended_profile'
      and pg_get_function_identity_arguments(p.oid)='target_profile_id uuid'
      and pg_get_function_result(p.oid)='boolean'
      and l.lanname='sql' and p.proowner::regrole::text='postgres'
      and p.provolatile='s' and p.prosecdef and not p.proretset and not p.proisstrict
      and not p.proleakproof and p.proparallel='u' and p.pronargdefaults=0
      and array(select case when cfg in ('search_path=', 'search_path=""') then 'search_path=' else cfg end
                from unnest(coalesce(p.proconfig,'{}'::text[])) cfg order by 1)=array['search_path=']::text[]
      and array(select (case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end)
                       ||':'||a.privilege_type||':'||a.is_grantable::text
                from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a order by 1)
          =array['authenticated:EXECUTE:false','postgres:EXECUTE:false']::text[]
      and pg_catalog.btrim(pg_catalog.regexp_replace(p.prosrc,E'\\s+',' ','g'))
          =pg_catalog.btrim(pg_catalog.regexp_replace($mp4_body$
  select
    public.current_user_owns_profile(target_profile_id)
    and coalesce((
      select not p.is_suspended
      from public.profiles as p
      where p.id = target_profile_id
    ), false);
$mp4_body$,E'\\s+',' ','g'))
  ) then raise exception 'MP-4 guard failed: unsuspended-owner helper definition/ACL drift'; end if;
end;
$mp4_helper_guard$;

do $postcondition$
begin
  if to_regprocedure('public.current_user_owns_unsuspended_profile(uuid)') is null
     or exists (select 1 from pg_policy pol where lower(coalesce(pg_get_expr(pol.polqual,pol.polrelid,true),'')||coalesce(pg_get_expr(pol.polwithcheck,pol.polrelid,true),'')) ~ 'profiles.*user_id' and pol.polrelid<>to_regclass('public.profiles'))
     or exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('append_unread_for','remove_unread_for','hide_conversation','unhide_conversation','find_and_unhide_conversation','create_post','update_post','delete_own_post','set_post_reaction','remove_post_reaction') and lower(p.prosrc) ~ 'profiles[\s\S]{0,180}user_id|user_id[\s\S]{0,180}profiles')
  then raise exception 'MP-4 postcondition failed: direct owner lane remains or helper ACL drift'; end if;
end;
$postcondition$;
commit;
