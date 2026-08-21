-- psy.market Slice MP-4-E: dormant conversation nullability foundation
-- PREFLIGHT: owner-run, no DML/DDL. The SHARE locks exclude concurrent writes
-- while the row/null invariants and repository-derived catalog pins are read.
-- WINGMAN LIVE RECOMPUTE REQUIRED before sitting: every check labelled LIVE_PIN.
begin;
set local row_security = off;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
lock table public.profiles, public.listings, public.conversations,
  public.messages, public.conversation_participant_state in share mode;

with
columns as (
  select c.relname table_name, a.attname column_name,
         regexp_replace(pg_catalog.format_type(a.atttypid,a.atttypmod),'^(public|private)\.','','g') data_type,
         a.attnotnull, coalesce(pg_catalog.pg_get_expr(d.adbin,d.adrelid,true),'<null>') default_expr,
         a.attcollation, a.attidentity::text attidentity, a.attgenerated::text attgenerated
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  join pg_catalog.pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
  left join pg_catalog.pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum
  where n.nspname in ('public','private') and
    (c.relname,a.attname) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),
      ('conversations','listing_id'),('conversations','unread_for'),('messages','sender_profile_id'),
      ('messages','conversation_id'),('conversation_participant_state','profile_id'),
      ('conversation_participant_state','conversation_id'),('account_session_active_profiles','profile_id'),
      ('account_session_active_profiles','user_id'))
),
constraints as (
  select c.relname table_name, x.conname, x.contype::text contype,
    lower(regexp_replace(regexp_replace(pg_catalog.pg_get_constraintdef(x.oid,false),'(public|private)\.','','g'),'[[:space:]]+',' ','g')) definition,
    x.convalidated, x.condeferrable, x.condeferred,
    case x.confdeltype when 'a' then 'NO ACTION' when 'r' then 'RESTRICT' when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' else null end delete_action
  from pg_catalog.pg_constraint x join pg_catalog.pg_class c on c.oid=x.conrelid
  join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname in ('public','private') and x.conname in (
    'conversations_buyer_profile_id_fkey','conversations_seller_profile_id_fkey',
    'conversations_listing_id_fkey','conversations_buyer_seller_differ','unique_conversation',
    'messages_sender_profile_id_fkey','messages_conversation_id_fkey',
    'conversation_participant_state_profile_id_fkey','conversation_participant_state_conversation_id_fkey',
    'account_session_active_profiles_profile_owner_fkey')
),
triggers as (
 select c.relname table_name,t.tgname,p.proname,t.tgenabled::text enabled,
   lower(regexp_replace(regexp_replace(pg_catalog.pg_get_triggerdef(t.oid,false),'(public|private)\.','','g'),'[[:space:]]+',' ','g')) definition
 from pg_catalog.pg_trigger t join pg_catalog.pg_class c on c.oid=t.tgrelid
 join pg_catalog.pg_namespace n on n.oid=c.relnamespace join pg_catalog.pg_proc p on p.oid=t.tgfoid
 where n.nspname='public' and c.relname in ('conversations','messages','conversation_participant_state') and not t.tgisinternal
),
function_state as (
 select n.nspname,p.proname,regexp_replace(pg_catalog.pg_get_function_identity_arguments(p.oid),'(public|private)\.','','g') args,
   regexp_replace(pg_catalog.pg_get_function_arguments(p.oid),'(public|private)\.','','g') arguments,
   p.proowner::regrole::text owner,l.lanname,p.provolatile::text volatility,p.prosecdef,p.proisstrict,p.proleakproof,p.proparallel::text parallel,
   p.pronargdefaults,coalesce((select string_agg(case when cfg in ('search_path=','search_path=""') then 'search_path=<empty>' else cfg end,',' order by cfg collate "C") from unnest(coalesce(p.proconfig,array[]::text[])) cfg),'<none>') settings,
   regexp_replace(pg_catalog.pg_get_function_result(p.oid),'(public|private)\.','','g') result,
   md5(btrim(regexp_replace(replace(p.prosrc,E'\r\n',E'\n'),'[[:space:]]+',' ','g'))) body_hash
 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace join pg_catalog.pg_language l on l.oid=p.prolang
 where (n.nspname='public' and p.proname in ('enforce_conversation_listing_seller','unhide_conversation_for_message_recipient','update_conversation_last_message','current_active_profile_id','current_user_is_active_profile'))
    or (n.nspname='private' and p.proname='current_active_profile_id')
),
function_acl as (
 select n.nspname,p.proname,regexp_replace(pg_catalog.pg_get_function_identity_arguments(p.oid),'(public|private)\.','','g') args,
   a.grantor::regrole::text grantor,case when a.grantee=0 then 'PUBLIC' else a.grantee::regrole::text end grantee,a.privilege_type,a.is_grantable
 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
 cross join lateral pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) a
 where (n.nspname='public' and p.proname in ('enforce_conversation_listing_seller','unhide_conversation_for_message_recipient','update_conversation_last_message','current_active_profile_id','current_user_is_active_profile'))
    or (n.nspname='private' and p.proname='current_active_profile_id')
),
row_facts as (
 select
   (select count(*) from public.conversations) conversation_rows,
   (select count(*) from public.messages) message_rows,
   (select count(*) from public.conversation_participant_state) participant_state_rows,
   (select count(*) from public.conversations where buyer_profile_id is null) buyer_nulls,
   (select count(*) from public.conversations where seller_profile_id is null) seller_nulls,
   (select count(*) from public.messages where sender_profile_id is null) sender_nulls,
   (select count(*) from public.conversations where buyer_profile_id=seller_profile_id) equal_participants,
   (select count(*) from public.messages m join public.conversations c on c.id=m.conversation_id where m.sender_profile_id is distinct from c.buyer_profile_id and m.sender_profile_id is distinct from c.seller_profile_id) nonparticipant_senders,
   (select count(*) from public.conversations c cross join lateral unnest(coalesce(c.unread_for,'{}'::text[])) u(v)
      where case when u.v ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then u.v::uuid is distinct from c.buyer_profile_id and u.v::uuid is distinct from c.seller_profile_id else true end) invalid_unread,
   (select count(*) from public.conversations c where cardinality(coalesce(c.unread_for,'{}'::text[]))<>(select count(distinct case when v ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then v::uuid end) from unnest(coalesce(c.unread_for,'{}'::text[])) u(v))) duplicate_unread,
   (select count(*) from public.conversation_participant_state s left join public.conversations c on c.id=s.conversation_id where c.id is null or (s.profile_id is distinct from c.buyer_profile_id and s.profile_id is distinct from c.seller_profile_id)) invalid_state
),
checks(name,ok,detail) as (
 select * from (values
 ('owner_complete_context',current_user='postgres' and session_user='postgres' and (select rolsuper or rolbypassrls from pg_roles where rolname=current_user),'LIVE_PIN: owner/BYPASSRLS completeness'),
 ('source_column_nullability',
   (select count(*)=3 from columns where (table_name,column_name) in (('conversations','buyer_profile_id'),('conversations','seller_profile_id'),('messages','sender_profile_id')) and data_type='uuid' and attnotnull and default_expr='<null>' and attcollation=0 and attidentity='' and attgenerated=''),
   'LIVE_PIN: three UUID actor columns are NOT NULL with no default/identity/generation'),
 ('listing_and_state_columns_unchanged',
   (select count(*)=7 from columns where (table_name,column_name) in (('conversations','listing_id'),('conversations','unread_for'),('messages','conversation_id'),('conversation_participant_state','profile_id'),('conversation_participant_state','conversation_id'),('account_session_active_profiles','profile_id'),('account_session_active_profiles','user_id'))),
   'LIVE_PIN: listing/unread/parent/participant/private-owner columns'),
 ('fk_actions_exact',
   (select count(*)=8 and bool_and(convalidated and not condeferrable and not condeferred and delete_action=expected_action) from constraints c join (values
    ('conversations_buyer_profile_id_fkey','CASCADE'),('conversations_seller_profile_id_fkey','CASCADE'),('conversations_listing_id_fkey','SET NULL'),
    ('messages_sender_profile_id_fkey','CASCADE'),('messages_conversation_id_fkey','CASCADE'),
    ('conversation_participant_state_profile_id_fkey','CASCADE'),('conversation_participant_state_conversation_id_fkey','CASCADE'),
    ('account_session_active_profiles_profile_owner_fkey','CASCADE')) e(name,expected_action) on e.name=c.conname),
   'LIVE_PIN: all eight FK delete actions including private profile-owner cascade'),
 ('source_differ_constraint_exact',
   (select count(*)=1 and bool_and(convalidated and definition='check ((buyer_profile_id <> seller_profile_id))') from constraints where conname='conversations_buyer_seller_differ'),
   'LIVE_PIN: old differ CHECK renderer'),
 ('unique_conversation_retained',(select count(*)=1 from constraints where conname='unique_conversation' and contype='u'),'LIVE_PIN: retained uniqueness is present and unchanged'),
 ('source_trigger_bindings_exact',
   not exists((select table_name,tgname,proname,enabled,definition from triggers) except (values
    ('conversations','conversations_enforce_listing_seller','enforce_conversation_listing_seller','O','create trigger conversations_enforce_listing_seller before insert or update of listing_id, seller_profile_id on conversations for each row execute function enforce_conversation_listing_seller()'),
    ('messages','messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient','O','create trigger messages_unhide_recipient_conversation after insert on messages for each row execute function unhide_conversation_for_message_recipient()'),
    ('messages','on_message_insert','update_conversation_last_message','O','create trigger on_message_insert after insert on messages for each row execute function update_conversation_last_message()')))
   and not exists((values
    ('conversations','conversations_enforce_listing_seller','enforce_conversation_listing_seller','O','create trigger conversations_enforce_listing_seller before insert or update of listing_id, seller_profile_id on conversations for each row execute function enforce_conversation_listing_seller()'),
    ('messages','messages_unhide_recipient_conversation','unhide_conversation_for_message_recipient','O','create trigger messages_unhide_recipient_conversation after insert on messages for each row execute function unhide_conversation_for_message_recipient()'),
    ('messages','on_message_insert','update_conversation_last_message','O','create trigger on_message_insert after insert on messages for each row execute function update_conversation_last_message()')) except select table_name,tgname,proname,enabled,definition from triggers),
   'LIVE_PIN: exact three source trigger definitions including UPDATE OF columns'),
 ('source_functions_and_acls_captured',(select count(*)=6 from function_state)
   and (select count(*)=3 from function_state where (proname,body_hash) in (('enforce_conversation_listing_seller','0dff735e21efc845ee166e57f902136a'),('unhide_conversation_for_message_recipient','66074618fc4aefdc17cd2b6c0274950a'),('update_conversation_last_message','45c2da17ae8a0272b0fd3e1fbb3d388e')))
   and not exists(
   (select proname,grantor,grantee,privilege_type,is_grantable from function_acl where proname in ('enforce_conversation_listing_seller','unhide_conversation_for_message_recipient','update_conversation_last_message'))
   except (values ('enforce_conversation_listing_seller','postgres','postgres','EXECUTE',false),('enforce_conversation_listing_seller','postgres','service_role','EXECUTE',false),('unhide_conversation_for_message_recipient','postgres','postgres','EXECUTE',false),('unhide_conversation_for_message_recipient','postgres','service_role','EXECUTE',false),('update_conversation_last_message','postgres','postgres','EXECUTE',false),('update_conversation_last_message','postgres','service_role','EXECUTE',false)))
   and not exists((values ('enforce_conversation_listing_seller','postgres','postgres','EXECUTE',false),('enforce_conversation_listing_seller','postgres','service_role','EXECUTE',false),('unhide_conversation_for_message_recipient','postgres','postgres','EXECUTE',false),('unhide_conversation_for_message_recipient','postgres','service_role','EXECUTE',false),('update_conversation_last_message','postgres','postgres','EXECUTE',false),('update_conversation_last_message','postgres','service_role','EXECUTE',false)) except
   select proname,grantor,grantee,privilege_type,is_grantable from function_acl where proname in ('enforce_conversation_listing_seller','unhide_conversation_for_message_recipient','update_conversation_last_message')),'LIVE_PIN: complete overload/default/attribute/body and exact exploded ACL sets'),
 ('rows_have_current_shape',(select buyer_nulls=0 and seller_nulls=0 and sender_nulls=0 and equal_participants=0 and nonparticipant_senders=0 and invalid_unread=0 and duplicate_unread=0 and invalid_state=0 from row_facts),'LIVE_PIN: lock-protected current row/null/unread/state invariants'),
 ('realtime_replica_identity_exact',
   (select count(*)=3 and bool_and(c.relreplident='d') from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('conversations','messages','conversation_participant_state'))
   and (select count(*)=3 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in ('conversations','messages','conversation_participant_state')),
   'LIVE_PIN: all three tables published and REPLICA IDENTITY DEFAULT'),
 ('package_d_privacy_intact',not has_column_privilege('anon','public.profiles','user_id','SELECT') and not has_column_privilege('authenticated','public.profiles','user_id','SELECT'),'LIVE_PIN: profiles.user_id remains hidden from browser roles')
 ) v(name,ok,detail)
), summary as (select bool_and(ok) all_ok,count(*) filter(where ok)::int passed,count(*)::int total,coalesce(array_agg(name||': '||detail order by name collate "C") filter(where not ok),'{}'::text[]) findings from checks), facts as (select * from row_facts)
select 'SLICE_MP4_E_PREFLIGHT' package,case when all_ok then 'GO' else 'STOP' end verdict,passed,total,findings,
 conversation_rows,message_rows,participant_state_rows,buyer_nulls,seller_nulls,sender_nulls,
 'All LIVE_PIN predicates and displayed function/policy/index/ACL manifests must be recomputed by the wingman against live immediately before the owner sitting. No pin is claimed from this repository alone.'::text boundary
from summary cross join facts;
rollback;
