-- MP-4 post-apply catalog and transactional behavior verifier.
-- OWNER-RUN. This script performs transient DML and RPC calls, then ROLLBACK.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '180s';

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
  if drift then raise exception 'MP-4 verify guard failed: policy manifest drift'; end if;

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
  if drift then raise exception 'MP-4 verify guard failed: function manifest drift'; end if;
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

create temporary table mp4_verification_results(
  family text primary key,
  allow_status text not null,
  deny_status text not null,
  finding text
) on commit drop;
grant select,insert,update on table mp4_verification_results to authenticated;

-- Capture only opaque IDs in transaction-local settings; no row-level IDs are output.
do $fixtures$
declare owner_id uuid; other_owner_id uuid; actor_profile uuid; other_profile uuid;
begin
  select p.user_id,p.id into owner_id,actor_profile
  from public.profiles p join public.users u on u.id=p.user_id
  where u.banned_at is null order by p.created_at,p.id limit 1;
  select p.user_id,p.id into other_owner_id,other_profile
  from public.profiles p join public.users u on u.id=p.user_id
  where u.banned_at is null and p.user_id is distinct from owner_id
  order by p.created_at,p.id limit 1;
  perform set_config('app.mp4_owner',coalesce(owner_id::text,''),true);
  perform set_config('app.mp4_actor_profile',coalesce(actor_profile::text,''),true);
  perform set_config('app.mp4_other_profile',coalesce(other_profile::text,''),true);
  perform set_config('app.mp4_event',coalesce((
    select e.id::text
    from public.events e
    where actor_profile is not null
      and not exists (
        select 1
        from public.vendor_events ve
        where ve.profile_id = actor_profile
          and ve.event_id = e.id
      )
    order by e.id
    limit 1
  ),''),true);
  perform set_config('app.mp4_listing_source',coalesce((select id::text from public.listings order by id limit 1),''),true);
  if owner_id is null or other_profile is null then
    insert into mp4_verification_results values ('fixture_owners','UNPROVEN','UNPROVEN','two distinct unbanned owners unavailable');
  else
    insert into mp4_verification_results values ('fixture_owners','GO','GO',null);
  end if;
end;
$fixtures$;

-- Create isolated rows as the owner; every mutation is rolled back at the end.
do $seed$
declare actor uuid:=nullif(current_setting('app.mp4_actor_profile',true),'')::uuid;
  otherp uuid:=nullif(current_setting('app.mp4_other_profile',true),'')::uuid;
  src uuid:=nullif(current_setting('app.mp4_listing_source',true),'')::uuid;
  eventid uuid:=nullif(current_setting('app.mp4_event',true),'')::uuid;
  own_listing uuid:=gen_random_uuid(); other_listing uuid:=gen_random_uuid(); conv uuid:=gen_random_uuid(); msg uuid:=gen_random_uuid(); post uuid:=gen_random_uuid();
begin
  if actor is null or otherp is null or src is null then return; end if;
  insert into public.listings
  select (jsonb_populate_record(null::public.listings,to_jsonb(l)||jsonb_build_object('id',own_listing,'profile_id',actor,'status','draft','admin_unpublished_at',null,'admin_unpublished_by',null))).*
  from public.listings l where l.id=src;
  insert into public.listings
  select (jsonb_populate_record(null::public.listings,to_jsonb(l)||jsonb_build_object('id',other_listing,'profile_id',otherp,'status','draft','admin_unpublished_at',null,'admin_unpublished_by',null))).*
  from public.listings l where l.id=src;
  insert into public.conversations(id,buyer_profile_id,seller_profile_id,listing_id) values(conv,actor,otherp,null);
  insert into public.messages(id,conversation_id,sender_profile_id,body) values(msg,conv,actor,'MP-4 transient verification');
  insert into public.conversation_participant_state(conversation_id,profile_id,hidden_at,updated_at) values(conv,actor,null,now());
  perform set_config('app.mp4_own_listing',own_listing::text,true);
  perform set_config('app.mp4_other_listing',other_listing::text,true);
  perform set_config('app.mp4_conversation',conv::text,true);
  perform set_config('app.mp4_message',msg::text,true);
  perform set_config('app.mp4_post',post::text,true);
end;
$seed$;

set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('app.mp4_owner',true),true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('app.mp4_owner',true),'role','authenticated','aud','authenticated')::text,true);

-- SELECT policy families: the owner must see its row and not the other profile's private row.
do $select_matrix$
declare own_listing uuid:=nullif(current_setting('app.mp4_own_listing',true),'')::uuid;
  other_listing uuid:=nullif(current_setting('app.mp4_other_listing',true),'')::uuid;
  conv uuid:=nullif(current_setting('app.mp4_conversation',true),'')::uuid;
  msg uuid:=nullif(current_setting('app.mp4_message',true),'')::uuid;
  actor uuid:=nullif(current_setting('app.mp4_actor_profile',true),'')::uuid;
begin
  if own_listing is null then
    insert into mp4_verification_results values ('listings','UNPROVEN','UNPROVEN','listing fixture unavailable');
  elsif exists(select 1 from public.listings where id=own_listing)
    and not exists(select 1 from public.listings where id=other_listing) then
    insert into mp4_verification_results values ('listings','GO','GO',null);
  else insert into mp4_verification_results values ('listings','STOP','STOP','private listing select matrix mismatch'); end if;

  if conv is null then insert into mp4_verification_results values ('conversations','UNPROVEN','UNPROVEN','conversation fixture unavailable');
  elsif exists(select 1 from public.conversations where id=conv) then insert into mp4_verification_results values ('conversations','GO','GO',null);
  else insert into mp4_verification_results values ('conversations','STOP','STOP','participant conversation hidden unexpectedly'); end if;

  if msg is null then insert into mp4_verification_results values ('messages','UNPROVEN','UNPROVEN','message fixture unavailable');
  elsif exists(select 1 from public.messages where id=msg) then insert into mp4_verification_results values ('messages','GO','GO',null);
  else insert into mp4_verification_results values ('messages','STOP','STOP','participant message hidden unexpectedly'); end if;

  if conv is not null and actor is not null and exists(select 1 from public.conversation_participant_state where conversation_id=conv and profile_id=actor)
  then insert into mp4_verification_results values ('conversation_participant_state','GO','GO',null);
  else insert into mp4_verification_results values ('conversation_participant_state','UNPROVEN','UNPROVEN','participant-state fixture unavailable'); end if;
end;
$select_matrix$;

-- Write-policy families. Every allow is actual DML; every deny expects RLS rejection.
do $write_matrix$
declare actor uuid:=nullif(current_setting('app.mp4_actor_profile',true),'')::uuid;
  otherp uuid:=nullif(current_setting('app.mp4_other_profile',true),'')::uuid;
  eventid uuid:=nullif(current_setting('app.mp4_event',true),'')::uuid;
  listingid uuid:=nullif(current_setting('app.mp4_own_listing',true),'')::uuid;
  otherlisting uuid:=nullif(current_setting('app.mp4_other_listing',true),'')::uuid;
  conv uuid:=nullif(current_setting('app.mp4_conversation',true),'')::uuid;
  np uuid:=gen_random_uuid(); nr uuid:=gen_random_uuid(); ve uuid:=gen_random_uuid(); fav uuid:=gen_random_uuid(); fol uuid:=gen_random_uuid(); en uuid:=gen_random_uuid(); m uuid:=gen_random_uuid();
  newlisting uuid:=gen_random_uuid(); newconv uuid:=gen_random_uuid(); affected bigint;
  allow_ok boolean; deny_ok boolean; allow_finding text;
begin
  -- Listings INSERT/UPDATE/DELETE: actual allow plus cross-owner deny.
  if listingid is null then
    insert into mp4_verification_results values ('listings_write','UNPROVEN','UNPROVEN','listing fixture unavailable');
  else
    allow_ok:=false; deny_ok:=false; allow_finding:=null;
    begin
      insert into public.listings
      select (jsonb_populate_record(null::public.listings,to_jsonb(l)||jsonb_build_object('id',newlisting,'profile_id',actor,'status','active','admin_unpublished_at',null,'admin_unpublished_by',null))).*
      from public.listings l where l.id=listingid;
      update public.listings set updated_at=updated_at where id=newlisting;
      update public.listings set status='draft' where id=newlisting;
      delete from public.listings where id=newlisting;
      get diagnostics affected=row_count;
      allow_ok:=affected=1;
    exception when others then allow_ok:=false; allow_finding:='allow SQLSTATE '||sqlstate; end;
    begin
      insert into public.listings
      select (jsonb_populate_record(null::public.listings,to_jsonb(l)||jsonb_build_object('id',gen_random_uuid(),'profile_id',otherp,'status','active','admin_unpublished_at',null,'admin_unpublished_by',null))).*
      from public.listings l where l.id=listingid;
    exception when sqlstate '42501' then deny_ok:=true; end;
    insert into mp4_verification_results values ('listings_write',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);
  end if;

  -- Conversation INSERT allow/deny.
  allow_ok:=false; deny_ok:=false; allow_finding:=null;
  begin insert into public.conversations(id,buyer_profile_id,seller_profile_id,listing_id) values(newconv,actor,otherp,null); allow_ok:=true; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
  begin insert into public.conversations(id,buyer_profile_id,seller_profile_id,listing_id) values(gen_random_uuid(),otherp,actor,null); exception when sqlstate '42501' then deny_ok:=true; end;
  insert into mp4_verification_results values ('conversations_write',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);

  -- Messaging INSERT allow/deny.
  allow_ok:=false; deny_ok:=false; allow_finding:=null;
  begin insert into public.messages(id,conversation_id,sender_profile_id,body) values(m,conv,actor,'MP-4 allow'); allow_ok:=true; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
  begin insert into public.messages(id,conversation_id,sender_profile_id,body) values(gen_random_uuid(),conv,otherp,'MP-4 deny'); exception when sqlstate '42501' then deny_ok:=true; end;
  insert into mp4_verification_results values ('messages_write',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);

  if eventid is null then
    insert into mp4_verification_results values ('rsvp','UNPROVEN','UNPROVEN','event fixture unavailable');
    insert into mp4_verification_results values ('notice_posts','UNPROVEN','UNPROVEN','event fixture unavailable');
    insert into mp4_verification_results values ('notice_reactions','UNPROVEN','UNPROVEN','event fixture unavailable');
    insert into mp4_verification_results values ('event_notifications','UNPROVEN','UNPROVEN','event fixture unavailable');
  else
    -- RSVP INSERT/DELETE allow and cross-owner INSERT deny.
    allow_ok:=false; deny_ok:=false; allow_finding:=null;
    begin insert into public.vendor_events(id,profile_id,event_id) values(ve,actor,eventid); delete from public.vendor_events where id=ve; get diagnostics affected=row_count; allow_ok:=affected=1; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
    begin insert into public.vendor_events(id,profile_id,event_id) values(gen_random_uuid(),otherp,eventid); exception when sqlstate '42501' then deny_ok:=true; end;
    insert into mp4_verification_results values ('rsvp',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);

    -- Notice post INSERT/DELETE allow and cross-owner deny.
    allow_ok:=false; deny_ok:=false; allow_finding:=null;
    begin insert into public.notice_posts(id,event_id,profile_id,category,title,body) values(np,eventid,actor,'shoutout','MP-4','MP-4 transient'); allow_ok:=true; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
    begin insert into public.notice_posts(id,event_id,profile_id,category,title,body) values(gen_random_uuid(),eventid,otherp,'shoutout','MP-4','deny'); exception when sqlstate '42501' then deny_ok:=true; end;
    insert into mp4_verification_results values ('notice_posts',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);

    -- Notice reaction INSERT/DELETE allow and cross-owner deny.
    allow_ok:=false; deny_ok:=false; allow_finding:=null;
    if exists(select 1 from public.notice_posts where id=np) then
      begin insert into public.notice_reactions(id,post_id,profile_id,emoji) values(nr,np,actor,'🔥'); delete from public.notice_reactions where id=nr; get diagnostics affected=row_count; allow_ok:=affected=1; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
      begin insert into public.notice_reactions(id,post_id,profile_id,emoji) values(gen_random_uuid(),np,otherp,'🔥'); exception when sqlstate '42501' then deny_ok:=true; end;
      delete from public.notice_posts where id=np;
    else
      allow_finding:='notice post allow fixture unavailable';
    end if;
    insert into mp4_verification_results values ('notice_reactions',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);

    -- Event notification INSERT/SELECT/DELETE allow and cross-owner deny.
    allow_ok:=false; deny_ok:=false; allow_finding:=null;
    begin insert into public.event_notifications(id,profile_id,event_id) values(en,actor,eventid); perform 1 from public.event_notifications where id=en; delete from public.event_notifications where id=en; get diagnostics affected=row_count; allow_ok:=affected=1; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
    begin insert into public.event_notifications(id,profile_id,event_id) values(gen_random_uuid(),otherp,eventid); exception when sqlstate '42501' then deny_ok:=true; end;
    insert into mp4_verification_results values ('event_notifications',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);
  end if;

  -- Favorites INSERT/SELECT/DELETE allow and cross-owner deny.
  if listingid is null then insert into mp4_verification_results values ('favorites','UNPROVEN','UNPROVEN','listing fixture unavailable');
  else
    allow_ok:=false; deny_ok:=false; allow_finding:=null;
    begin insert into public.favorites(id,profile_id,listing_id) values(fav,actor,listingid); perform 1 from public.favorites where id=fav; delete from public.favorites where id=fav; get diagnostics affected=row_count; allow_ok:=affected=1; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
    begin insert into public.favorites(id,profile_id,listing_id) values(gen_random_uuid(),otherp,listingid); exception when sqlstate '42501' then deny_ok:=true; end;
    insert into mp4_verification_results values ('favorites',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);
  end if;

  -- Follows INSERT/DELETE allow and cross-owner deny.
  allow_ok:=false; deny_ok:=false; allow_finding:=null;
  begin insert into public.follows(id,follower_profile_id,following_profile_id) values(fol,actor,otherp); delete from public.follows where id=fol; get diagnostics affected=row_count; allow_ok:=affected=1; exception when others then allow_finding:='allow SQLSTATE '||sqlstate; end;
  begin insert into public.follows(id,follower_profile_id,following_profile_id) values(gen_random_uuid(),otherp,actor); exception when sqlstate '42501' then deny_ok:=true; end;
  insert into mp4_verification_results values ('follows',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);
end;
$write_matrix$;

-- Converted RPCs: real allow and deny calls where the current fixtures permit them.
do $rpc_matrix$
declare actor uuid:=nullif(current_setting('app.mp4_actor_profile',true),'')::uuid;
  otherp uuid:=nullif(current_setting('app.mp4_other_profile',true),'')::uuid;
  conv uuid:=nullif(current_setting('app.mp4_conversation',true),'')::uuid;
  created_post uuid;
  allow_ok boolean:=false; deny_ok boolean:=false;
  allow_finding text;
  denied_count integer:=0;
begin
  -- All five converted conversation RPCs: owned-participant allow and unrelated-account deny.
  allow_finding:=null;
  begin
    perform public.append_unread_for(conv,otherp::text);
    perform public.remove_unread_for(conv,actor::text);
    perform public.hide_conversation(conv);
    perform public.unhide_conversation(conv);
    perform public.find_and_unhide_conversation(otherp,null);
    allow_ok:=true;
  exception when others then allow_ok:=false; allow_finding:='allow SQLSTATE '||sqlstate;
  end;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin perform public.append_unread_for(conv,otherp::text); exception when others then if sqlstate='P0001' then denied_count:=denied_count+1; end if; end;
  begin perform public.remove_unread_for(conv,actor::text); exception when others then if sqlstate='P0001' then denied_count:=denied_count+1; end if; end;
  begin perform public.hide_conversation(conv); exception when others then if sqlstate='P0001' then denied_count:=denied_count+1; end if; end;
  begin perform public.unhide_conversation(conv); exception when others then if sqlstate='P0001' then denied_count:=denied_count+1; end if; end;
  begin perform public.find_and_unhide_conversation(otherp,null); exception when others then if sqlstate='P0001' then denied_count:=denied_count+1; end if; end;
  deny_ok:=denied_count=5;
  perform set_config('request.jwt.claim.sub',current_setting('app.mp4_owner',true),true);
  insert into mp4_verification_results values ('conversation_rpcs',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);

  -- All five converted Wall mutation RPCs: owned-profile allow and cross-account deny.
  allow_ok:=false; deny_ok:=false; allow_finding:=null; denied_count:=0;
  begin
    created_post:=public.create_post(actor,'MP-4 transient post',array[]::text[],true);
    perform public.update_post(created_post,'MP-4 transient post updated',array[]::text[],true);
    perform public.set_post_reaction(created_post,actor,'love');
    perform public.remove_post_reaction(created_post,actor);
    allow_ok:=created_post is not null;
  exception when others then allow_ok:=false; allow_finding:='allow SQLSTATE '||sqlstate;
  end;

  begin perform public.create_post(otherp,'MP-4 denied post',array[]::text[],true); exception when sqlstate '42501' then denied_count:=denied_count+1; end;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin perform public.update_post(created_post,'MP-4 denied update',array[]::text[],true); exception when sqlstate '42501' then denied_count:=denied_count+1; end;
  begin perform public.delete_own_post(created_post); exception when sqlstate '42501' then denied_count:=denied_count+1; end;
  begin perform public.set_post_reaction(created_post,actor,'love'); exception when sqlstate '42501' then denied_count:=denied_count+1; end;
  begin perform public.remove_post_reaction(created_post,actor); exception when sqlstate '42501' then denied_count:=denied_count+1; end;
  deny_ok:=denied_count=5;
  perform set_config('request.jwt.claim.sub',current_setting('app.mp4_owner',true),true);
  begin perform public.delete_own_post(created_post); exception when others then allow_ok:=false; allow_finding:=coalesce(allow_finding,'allow cleanup SQLSTATE '||sqlstate); end;
  insert into mp4_verification_results values ('wall_post_reaction_rpcs',case when allow_ok then 'GO' else 'STOP' end,case when deny_ok then 'GO' else 'STOP' end,allow_finding);
end;
$rpc_matrix$;

reset role;

select
  'MP4_POLICY_CONVERSION_VERIFY'::text as result_set,
  case when count(*) filter(where allow_status='STOP' or deny_status='STOP')>0 then 'STOP'
       when count(*) filter(where allow_status='UNPROVEN' or deny_status='UNPROVEN')>0 then 'UNPROVEN'
       else 'GO' end as overall_status,
  count(*) filter(where allow_status='GO' and deny_status='GO') as proven_family_count,
  count(*) filter(where allow_status='UNPROVEN' or deny_status='UNPROVEN') as unproven_family_count,
  jsonb_agg(jsonb_build_object('family',family,'allow',allow_status,'deny',deny_status,'finding',finding) order by family) as family_results
from mp4_verification_results;

rollback;
