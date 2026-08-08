# Multi-Profile (Umbrella Model) — V1 Proposal

## Document status and authority

**Status:** Product direction decided; implementation proposal only.
**Date:** 2026-08-08
**Implementation state:** Not implemented. No database or application change is authorized by this document alone.

This document proposes the coordinated database, authorization, privacy, application, migration, deletion, and verification work required to move Multi-Profile from V2 into V1. Launch delay is accepted.

The fixed product decisions in **Resolved decisions** are binding for this proposal. The implementation details, migration SQL, rollback SQL, deletion mechanics, and open questions still require review before code or database work begins.

This proposal treats the owner-applied and verified database state through Chunk 11D as the baseline. New work must be delivered in separately guarded chunks and application slices; historical applied chunks must not be rewritten as if Multi-Profile existed when they were first applied.

The research basis is `docs/research/MULTI_IDENTITY_RESEARCH.md`. Existing frozen V1 documents that still say “one profile per user” become superseded on this topic only after the eventual coordinated decision-document amendment; this proposal does not edit them.

---

## Executive recommendation

Adopt the original Umbrella Model with these boundaries:

- one private auth account owns between one and five public profiles;
- public profiles remain independent personas with no public ownership link;
- the authenticated session has one active profile;
- every identity-bearing read or write is scoped to that active profile;
- the database remains the final authority for profile ownership, bans, the five-profile cap, handle rules, and mutation authorization;
- account-wide concerns—login, ban state, email preference, upload/post burst limits, recovery, and account deletion—remain on the auth/application account;
- profile-scoped concerns—public identity, listings, posts, messages, follows, RSVPs, and reactions—remain on the profile, subject to the unresolved anti-inflation questions listed at the end;
- public database/API surfaces must stop exposing `profiles.user_id`;
- public R2 object keys must stop embedding auth user IDs before a second profile can be created;
- profile deletion must not hard-delete another participant's conversation history; current conversation foreign keys must therefore be redesigned before profile deletion is enabled.

The safest implementation is a staged sequence: privacy foundation first, profile-cap and active-session database foundation second, then client identity state, then each mutation family, then deletion/account deletion, followed by full staging and privacy verification.

---

# Part I — Resolved decisions

The following product decisions are fixed.

1. **Maximum five profiles.** One auth account may own no more than five profiles. The hard cap is enforced by the database on every insert path, including trusted/service writes.
2. **Fifth profile type.** `profile_type` gains exactly one value: `vendor`, displayed approximately as **Shop / Brand**. No other new profile type is added.
3. **Signup remains simple.** Signup still auto-creates one `personal` profile. Additional profiles are created voluntarily after signup. Profile type remains editable.
4. **Public identities are unlinked.** No public UI, API response, Realtime payload, object-key pattern, metadata field, or error oracle may reveal that two profiles share one owner. Only the owner in private profile-management/switcher UI and authorized admins may see the relationship.
5. **Bans remain account-level.** `public.users.banned_at` remains authoritative. A ban affects the account and all profiles it owns, consistent with current ban enforcement and the Wall Hero-clearing trigger.
6. **One active profile per authenticated session.** The Header avatar menu switches it. Listings, messages, posts, reactions, follows, RSVPs, uploads, and every other identity-bearing action use the active profile.
7. **Creation forms identify the actor.** Listing-create and post-create forms show a read-only **Posting as @handle (switch)** hint.
8. **Inbox is profile-scoped.** The inbox displays only conversations belonging to the active profile. Switching profiles switches and resets the inbox.
9. **One email-notification switch per account.** V1 retains one account-level new-message email preference. The email identifies which profile was contacted.
10. **Profile deletion is real deletion.** It requires a removal summary and type-the-handle confirmation. Listings and posts are physically removed under established Wall deletion/orphan rules. Public images become report-only orphans; no public-object deletion path is introduced. Conversations retain the existing per-participant soft-delete principle and must not be hard-deleted for the other participant. Handles return to the ordinary free pool. The last profile cannot be deleted through profile deletion.
11. **Account deletion is V1 scope.** Attempting to delete the last profile redirects to account deletion. Account deletion removes the account and all remaining profiles while preserving shared-conversation semantics for other participants. A detailed account-deletion specification may follow, but implementation cannot launch without it.

---

# Part II — Captured baseline and principal blockers

## 1. Current cardinality and signup

Chunk 2 currently enforces one profile per auth user:

```sql
create unique index profiles_one_per_user_key
  on public.profiles (user_id);
```

The same chunk's `handle_new_user()` trigger creates the `public.users` row and exactly one `personal` profile. That signup behavior remains correct; only the uniqueness rule changes.

Current profile types are:

```text
personal
artist
label
festival
```

The additive `vendor` enum value is required before any application can write it.

## 2. Current privacy blocker: `profiles.user_id`

The current profile policy is conceptually:

```text
Profiles are publicly readable
USING (true)
```

Row-level security chooses rows, not columns. If `anon` or `authenticated` has ordinary table `SELECT`, direct PostgREST callers can request `user_id`. That makes co-ownership directly discoverable as soon as one account owns two profiles.

This is a launch blocker. Hiding the field in React components is insufficient.

## 3. Current privacy blocker: public R2 keys

`lib/uploads/intent-server.ts` currently derives:

```text
pending/<auth-user-id>/<upload-id>.<ext>
<public-folder>/<auth-user-id>/<upload-id>.<ext>
```

Pending keys are private, but final keys appear in public URLs. If two profiles share an account, the repeated auth-user UUID publicly links their avatars, headers, listings, and posts. Chunk 11A's `post_images_belong_to_profile(...)` also validates post URLs against the owner's auth-user UUID.

Public final keys must become profile-scoped or use an equally unlinkable per-profile namespace before additional-profile creation is enabled.

## 4. Current active-profile blocker

The application repeatedly resolves one profile by `user_id` using `.single()`, `.maybeSingle()`, `.limit(1)`, or equivalent. There is no active-profile provider, session record, or switcher.

Several database policies correctly authorize “any profile owned by the caller.” That remains an ownership boundary, but by itself it does not implement the product rule that identity-bearing actions occur as the current active profile.

## 5. Current deletion blocker: shared conversations

The captured foreign keys include:

| Reference | Current delete behavior |
|---|---|
| `conversations.buyer_profile_id → profiles.id` | `ON DELETE CASCADE` |
| `conversations.seller_profile_id → profiles.id` | `ON DELETE CASCADE` |
| `messages.sender_profile_id → profiles.id` | `ON DELETE CASCADE` |
| `conversation_participant_state.profile_id → profiles.id` | `ON DELETE CASCADE` |

Deleting a profile today can physically delete shared conversations and messages. That conflicts with the fixed soft-delete semantics. Profile deletion must not ship until these relationships have a reviewed replacement.

## 6. Current account-wide foundations that are compatible

These current choices are compatible and should remain account-scoped:

- `public.users.banned_at`, `ban_reason`, and `banned_by`;
- `public.users.email_notifications`;
- `current_user_is_banned()` and admin-role helpers;
- post-write burst limits keyed by auth user;
- upload-intent rate limits keyed by auth user;
- auth confirmation, password recovery, and session revocation;
- one `public.users` row per `auth.users` row.

Account-level rate limits must not be changed to profile-level limits, because switching profiles must not multiply the allowed burst rate.

---

# Part III — Proposed target model

## 7. Account and profile cardinality

Target relationship:

```text
auth.users 1 ── 1 public.users
public.users/auth.users 1 ── 1..5 public.profiles
public.profiles 1 ── N identity-bearing content rows
```

Invariants:

- every active account has at least one profile;
- ordinary profile creation is rejected at five;
- `profiles.user_id` is immutable through ordinary profile updates;
- account deletion is the only ordinary path that removes the final profile;
- profile handles remain globally and case-insensitively unique;
- blocked and actively reserved handles remain unavailable;
- deleting a profile frees its handle unless that handle remains independently blocked or reserved.

## 8. Robust database enforcement of the five-profile cap

A `CHECK` constraint cannot safely count sibling rows. A plain `BEFORE INSERT` count without locking is race-prone: two concurrent inserts can both see four profiles and both succeed.

Recommended enforcement:

1. Keep or create a non-unique index on `profiles(user_id)`.
2. Add a trigger-owned, locked cap check for `INSERT`.
3. In the trigger, lock the parent `public.users` row for `NEW.user_id` before counting profiles.
4. Reject when the locked account already owns five profiles.
5. Reject ordinary `UPDATE OF user_id`; ownership transfer must not be a client operation.
6. Apply the trigger to privileged/service inserts too.
7. Create additional profiles through a dedicated authenticated RPC that repeats auth, ban, handle, type, and ownership checks.
8. Only after the cap trigger and verifier are present, drop `profiles_one_per_user_key`.

Locking the stable parent account row serializes concurrent profile creation for the same account without serializing unrelated accounts.

Conceptual trigger logic:

```text
require NEW.user_id exists
lock public.users row for NEW.user_id
count profiles for NEW.user_id
if count >= 5: reject
otherwise allow insert
```

The migration must prove all current accounts have between one and five profiles before dropping the unique index.

## 9. Enum addition

Add:

```sql
alter type public.profile_type add value if not exists 'vendor';
```

Application display copy is **Shop / Brand**; the stored value is `vendor`.

PostgreSQL enum-value removal is not a simple rollback. The package must state one of two rollback levels explicitly:

- operational rollback disables creation/use of `vendor` but leaves the unused enum label; or
- exact rollback creates a replacement enum type and rewrites dependent columns, which is much more invasive.

The additive label itself does not expose data and is safe to leave unused during an operational rollback.

## 10. Additional-profile creation

Use a dedicated trusted mutation rather than unrestricted client table inserts, conceptually:

```text
create_additional_profile(handle, display_name, profile_type)
```

It must:

- derive the account from `auth.uid()`;
- require an authenticated, unbanned account;
- lock the account row;
- enforce the five-profile cap;
- allow only the five enum values;
- normalize and validate the handle;
- enforce `blocked_handles` and active reserved-profile rules;
- insert with `user_id = auth.uid()`;
- set safe defaults;
- return only the new profile's public fields;
- never return sibling owner identifiers;
- optionally make the new profile active through the separate session-scoped operation.

Normal signup remains unchanged and continues using the trigger-created personal profile. The signup completion route must update the exact trigger-created profile ID, not every row matching `user_id`.

## 11. Active profile: server-backed session state with a client mirror

### Recommended representation

Because the decision is **one active profile per authenticated session**, the authoritative state should be server-backed and keyed by the stable Supabase auth-session identifier, not by account alone.

Conceptual private table:

```text
account_session_active_profiles
- session_id        primary key
- user_id           account owner
- profile_id        active profile
- created_at
- updated_at
```

Properties:

- no public/anonymous access;
- owner can read only their current session state through a narrow RPC;
- admin access is not required for normal switching;
- `(profile_id, user_id)` ownership is validated in trusted code;
- the active row is removed or invalidated when the auth session/profile disappears;
- stale session rows are periodically or opportunistically cleaned;
- profile deletion updates or clears every affected active-session row;
- account deletion removes all active-session rows.

The implementation must first confirm the exact live JWT session claim and lifecycle. If Supabase's stable `session_id` claim cannot be relied upon in every current auth path, use an opaque server-issued app-session identifier bound to the authenticated Supabase session. Do not fall back silently to an account-global `users.active_profile_id`, because that would make switching on one device unexpectedly switch every device.

### Client mirror

A root authenticated `ActiveProfileProvider` mirrors the server-selected profile and supplies:

- `activeProfile`;
- the private owner-only list of up to five profiles;
- loading/error states;
- `switchProfile(profileId)`;
- auth-transition clearing;
- cross-tab synchronization for tabs sharing the same auth session.

Local or session storage may cache UI state but is not authoritative. It must be namespaced by auth user/session, cleared on sign-out/account replacement, and validated against the owner-only profile list before use.

### Initial selection

For a session without a valid active row:

1. choose the account's oldest profile (the signup-created profile under normal history);
2. persist that selection for the session;
3. return it to the client;
4. if the profile is later deleted, choose the oldest remaining profile;
5. never infer selection from a public profile page without an explicit owner action.

### Switch behavior

Switching through the Header avatar menu must:

1. call a trusted switch RPC/endpoint;
2. verify the target profile belongs to `auth.uid()`;
3. update the current session only;
4. atomically replace the client context after success;
5. cancel or generation-invalidate identity-bound requests;
6. clear prior inbox, composer, reaction, owner-action, and upload state;
7. refetch active-profile counts and inbox;
8. notify other tabs sharing the same auth session.

## 12. Server-side verification rule

No server route, RPC, RLS policy, upload intent, or Realtime-sensitive mutation may trust a client-supplied profile ID alone.

Every identity-bearing write must establish:

```text
authenticated caller
AND caller account is not banned
AND acting profile belongs to auth.uid()
AND acting profile equals the current session's active profile
AND target resource belongs to or is valid for that acting profile
```

The ownership predicate remains the critical security boundary. Active-profile equality enforces the product's global identity context and prevents stale tabs from acting after a switch.

Recommended shared helpers:

- private `current_session_id()`;
- private `current_active_profile_id()`;
- private `current_user_owns_profile(profile_id)`;
- private `current_user_can_act_as(profile_id)` combining ownership, active selection, and ban state.

They must be `SECURITY DEFINER` only where needed, use `search_path = ''`, schema-qualify all objects, revoke `PUBLIC`, expose only necessary signatures, and never return owner user IDs to public callers.

Public reads remain profile-based and do not need active-profile state. Owner/admin reads and every mutation do.

---

# Part IV — Database impact audit, Chunks 0–11D

## 13. Impact matrix

| Baseline area | Current assumption | Multi-Profile treatment |
|---|---|---|
| Chunk 0 captured profiles | Public profiles expose all readable columns; policies often accept any caller-owned profile | Hide `user_id` from public APIs; retain owner relation internally; active-scope identity writes |
| Chunk 0 conversations/messages | Participant policies resolve any profile owned by `auth.uid()` | Reads/writes become active-profile-only; retained deleted-participant history requires FK redesign |
| Chunk 0 favorites | Unique `(profile_id, listing_id)` and own-profile RLS | Active-profile identity; verify whether favorites remain V1/out-of-scope, but do not leak sibling ownership |
| Chunk 0 festival RSVP (`vendor_events`) | Unique `(profile_id, event_id)` and own-profile RLS | Active-profile RSVP; account-vs-profile attendance inflation remains an open question |
| Chunk 0 Notice Board | Post/reaction ownership uses caller-owned profiles | Require active profile; preserve event/public visibility; resolve account-level duplicate reactions question |
| Chunk 0 event notifications | Unique `(profile_id, event_id)` | If retained, active-profile operation; email delivery still resolves one owning account |
| Chunk 0 follows | Profile-to-profile graph | Active-profile follower; sibling/count-abuse rules require explicit decision |
| Chunk 1 roles/bans | Ban state is on `public.users`; admin ban updates every profile by `user_id` | Fundamentally compatible; wrappers/UI must target profile without exposing `user_id`; verify all profiles suspend/unsuspend |
| Chunk 2 handles/profiles | Unique `profiles(user_id)`; signup creates one profile | Replace unique index with locked five-cap; keep signup; add additional-profile RPC and immutable owner guard |
| Chunk 2 handle trigger | Normalizes and blocks route handles | Reuse for every additional profile; integrate reserved-profile exceptions only through trusted claim logic |
| Chunk 3 tickets/validation | Conversation seller must own linked listing | Compatible profile identity; active buyer must be explicit |
| Chunk 4 moderation | Admin operations target listing/post IDs | Mostly compatible; ban entry points must resolve account privately from target profile |
| Chunk 5 conversation hiding | Several RPCs choose one caller profile using `LIMIT 1`; SELECT sees all owned profiles | Must be rewritten to current active profile; deletion retention redesign required |
| Chunk 6 ban enforcement | Many policies authorize any caller-owned profile; messaging RPCs choose `LIMIT 1` | Preserve account ban, add active-profile equality, remove ambiguous profile selection |
| Chunk 7 Realtime | Publishes messages, notices, conversations, participant state | Re-audit payload columns and active-profile RLS; profiles/session-active table must not be publicly published |
| Chunk 10 view count | Service-only listing ID update, no caller profile | No identity change; verify no public/user UUID leakage in endpoint/logging when wired |
| Chunk 10 message trigger | Updates parent conversation from inserted message | Keep; participant/sender nullable-deletion redesign must retain exact-parent guard |
| Chunk 11A follows | Own-profile policies and profile graph | Add active-profile actor requirement; public graph remains profile-only |
| Chunk 11A ban helper | Resolves profile → owner internally | Compatible and desirable; function must remain a boolean, not expose owner ID |
| Chunk 11A post rate limiter | Keyed by auth user | Keep account-level to prevent fivefold burst bypass |
| Chunk 11A image helper | Accepts public URLs under auth-user-ID namespace | Replace with profile-scoped namespace; migrate existing references first |
| Chunk 11B posts | RPC accepts owned target profile | Require target equals active profile; edits/deletes also protect resource's author profile |
| Chunk 11B ban trigger | Clears Hero for all profiles where `profile.user_id = banned user` | Already correctly account-wide; verifier must include multiple-profile fixture |
| Chunk 11C reactions | One row per `(post_id, profile_id)` | Active-profile actor; whether one account may react through multiple profiles is open |
| Chunk 11C moderation audit | Stores author profile and deleting auth user | Compatible; admin-only output may retain both identity levels where required |
| Chunk 11D visibility | Post/reaction visibility is profile/parent based | Compatible; public visibility must never require or return profile owner ID |

### Complete identity-sensitive object inventory

The implementation preflight must match and version every current object below rather than relying only on name-based source searches.

| Family | Objects requiring replacement, compatibility proof, or explicit no-change verdict |
|---|---|
| Profiles/handles | `profiles_one_per_user_key`, `idx_profiles_user_id`, `profiles_handle_lower_key`, public profile SELECT policy/grants, own-profile INSERT/UPDATE policies, `enforce_profile_handle()`, `profiles_enforce_handle`, `handle_new_user()` |
| Account/admin/ban | `current_user_is_banned()`, `current_user_is_admin()`, `current_user_is_super_admin()`, `admin_ban_user(uuid,text)`, `admin_unban_user(uuid)`, profile suspension compatibility updates, Auth-ban server path |
| Listings | owner INSERT/UPDATE/DELETE policies, `enforce_listing_moderation_state()`, `listings_enforce_moderation_state`, admin unpublish/republish RPCs, listing ownership checks in upload authorization |
| Conversations | conversation participant SELECT policy; active-buyer INSERT policy; `hide_conversation()`, `unhide_conversation()`, `find_and_unhide_conversation()`; buyer/seller/profile-state FKs and indexes |
| Messages | message SELECT path through conversations; sender INSERT policy; `append_unread_for()`, `remove_unread_for()`, `unhide_conversation_for_message_recipient()`, `messages_unhide_recipient_conversation`, `update_conversation_last_message()`, `on_message_insert`, sender/profile FKs and `unread_for` cleanup |
| Festival/community | `vendor_events` RSVP INSERT/DELETE policies and uniqueness; Notice post INSERT/DELETE policies; Notice reaction INSERT/DELETE policies and uniqueness; event-notification policies/uniqueness; events `created_by` FK |
| Social graph | follows public read policy, own-profile follow/unfollow policies, self-follow check, pair uniqueness, both profile FKs; favorites own-profile policies/uniqueness even while favorites remain out of V1 |
| Wall/posts | `profile_owner_is_banned()`, `current_user_can_read_post_author()`, `current_user_can_read_post()`, `post_images_belong_to_profile()`, `consume_post_write_rate_limit()`, `create_post()`, `update_post()`, `delete_own_post()`, post visibility policy, `enforce_post_write_invariants()`, its trigger, `clear_hero_on_author_ban()`, and its users trigger |
| Wall reactions/moderation | `current_user_can_read_post_reaction()`, reaction read policy, `set_post_reaction()`, `remove_post_reaction()`, `(post_id,profile_id)` uniqueness, `guard_post_reaction_identity()`, its trigger, and admin post deletion/audit outputs |
| Uploads/rates | `consume_upload_intent_rate_limit()`, account-keyed limiter table, browser presign/finalize authorization, trusted CLI authorization, signed token fields, pending/final key derivation, promoted-key cleanup candidates |
| Realtime/views | `supabase_realtime` memberships for messages, conversations, participant state, Notice posts/reactions; replica identity settings; service-only `increment_view_count(uuid)` |

Objects that remain semantically compatible must still be included in exact preflight/verify expected sets so an unreviewed overload, policy, trigger, grant, or publication cannot survive unnoticed.

## 14. Policies that are structurally multi-profile but not active-profile-safe

Patterns such as:

```sql
profile_id in (
  select p.id from public.profiles p where p.user_id = auth.uid()
)
```

correctly prevent cross-account writes, but permit any of the caller's profiles. They must be classified per operation:

- **Owner management/listing of own profiles:** any owned profile is appropriate.
- **Identity-bearing action:** require the active profile.
- **Account-wide action:** use `auth.uid()` and do not accept a profile as authority.
- **Public read:** profile ownership should not be consulted or exposed except inside narrow ban/visibility helpers.

Affected families include listings, conversations, messages, conversation participant state, favorites, follows, event notifications, RSVPs, Notice Board posts/reactions, Wall posts/reactions, and uploads.

## 15. Ambiguous `LIMIT 1` database functions

Chunk 5 and Chunk 6 currently use `LIMIT 1` to select a caller profile in functions including:

- `hide_conversation(uuid)`;
- `unhide_conversation(uuid)`;
- `find_and_unhide_conversation(uuid, uuid)`;
- `append_unread_for(uuid, text)`;
- `remove_unread_for(uuid, text)`.

With multiple profiles, “first profile owned by the account that participates” is not a valid identity decision. Each function must resolve the current active profile or accept an acting profile and verify it equals the session-active profile. Conversation IDs must not allow a caller to operate another owned profile's inbox accidentally.

## 16. Ban enforcement

The authoritative account ban remains `public.users.banned_at`.

Already compatible behavior:

- `current_user_is_banned()` evaluates `auth.uid()`;
- admin ban/unban updates `profiles.is_suspended` for every row with the target `user_id`;
- `profile_owner_is_banned(profile_id)` resolves the owner internally;
- the Chunk 11B trigger clears Hero flags for posts from every profile owned by the banned account.

Required review:

- ban/unban UI and browser RPC calls must not obtain public `profiles.user_id`;
- prefer an admin-only `admin_ban_profile(target_profile_id, reason)` wrapper that resolves the account internally, or an admin-only owner-management response;
- admin profile/account results must never enter public page payloads or cached public responses;
- verify every mutation family still calls account-ban logic after active-profile changes;
- verify Auth `banned_until` synchronization remains one operation per account.

## 17. Rate limiters

Keep these account-level:

- upload-intent limiter;
- post create/update burst limiter;
- auth/signup/recovery limits;
- future profile-creation limiters.

Add a short-window additional-profile creation limit so a caller cannot repeatedly race failing inserts or abuse handle checks. The hard five-cap remains the final database invariant.

## 18. View counts

`increment_view_count(uuid)` is currently service-role-only and updates an active listing by listing ID. It neither resolves a caller profile nor returns profile ownership. No cardinality change is required.

When view counting is eventually wired, the endpoint must not include auth-user IDs in deduplication keys, public responses, URLs, analytics payloads, or logs that reach clients. This is a privacy verification item, not a reason to change Chunk 10 now.

---

# Part V — Application flow inventory and conversion

## 19. One-profile lookup inventory

The following current runtime flows use `.eq("user_id", ...).single()`, `.maybeSingle()`, `.limit(1)`, or an equivalent one-row assumption.

| Current file/surface | Current behavior | Required behavior |
|---|---|---|
| `components/layout/Header.tsx` | Loads newest owned profile with `.limit(1)` | Load private owner-only profile list and current session-active profile; render switcher and cap state |
| `lib/posts/use-reaction-viewer.ts` | Resolves one profile by user ID with `.maybeSingle()` | Consume active-profile context; invalidate on switch |
| `app/[handle]/page.tsx` | Resolves one current profile by user ID; derives owner, inbox, composer, edit actions | Distinguish account ownership privately from current active profile; active profile drives actions/inbox; owner may be offered a private switch-to-manage action |
| `app/listing/[id]/page.tsx` | Resolves one profile for contact-seller flow | Use active profile; reset stale contact state on switch |
| `app/listing/[id]/edit/page.tsx` | Resolves one profile then compares listing owner | Authorize listing against active profile and database ownership; owned-but-inactive listing requires explicit switch |
| `app/listings/new/page.tsx` | Resolves one profile at publish time | Use active profile and display **Posting as @handle (switch)**; uploads and insert bind to that profile |
| `app/profile/edit/page.tsx` | Loads one profile with `.single()` | Edit active profile; switcher/profile manager selects another profile explicitly |
| `app/messages/page.tsx` | Redirects to the one profile's inbox | Redirect to active profile's inbox route/state |
| `app/festivals/[slug]/page.tsx` | Resolves one profile for RSVP and Notice Board behavior | Use active profile for RSVP, Notice post/reaction, and ownership UI |
| `app/api/auth/signup/route.ts` | Updates every/one profile by `user_id` after trigger signup | Capture/update the exact trigger-created profile ID or use a signup-attempt-bound trusted function; never match an established multi-profile account broadly |
| `lib/uploads/authorization.ts` | Reads `profiles.user_id` to verify `ownerId` | Call private ownership/active helper; do not grant client/server RLS clients public owner-column access |
| `lib/uploads/trusted-upload-server.ts` | Compares profile owner to supplied user | Preserve server-side ownership check and add active-profile requirement where the trusted operation represents a user session |

Public profile lookups by handle or ID are not one-profile-per-account assumptions, but every `select("*")` must become an explicit safe public column selection once `user_id` is hidden.

`types/marketplace.ts` currently includes `userId` in the general public `Profile` type. That type must be split: the normal public profile contract must not contain an account owner ID, while a separately named private admin/account contract may contain ownership data. The shared `PROFILE_TYPES` list and the duplicated selector arrays in `components/EditProfileModal.tsx` and `app/profile/edit/page.tsx` must add `vendor` with the display label **Shop / Brand**.

## 20. Other identity-bearing application flows

### Listings

- New listing modal/page uses the active profile.
- Edit, unpublish, mark-sold, and real-delete actions require the listing's `profile_id` to equal the current active profile.
- An owner viewing a listing of an inactive sibling profile may receive a private **Switch to @handle to manage** action; controls do not silently act as that sibling.
- Listing forms show the fixed read-only actor hint.
- Switching while a form contains unsaved work requires confirmation; the form must not silently publish under either the old or new identity.

### Wall posts

- Composer renders only when the Wall profile is active, or offers a private switch action to an owner of an inactive sibling profile.
- New-post form shows the fixed actor hint.
- Post edit/delete is active-author-profile-only.
- An in-flight upload or RPC is identity-bound; switch invalidates or blocks completion.

### Reactions

- Viewer reaction identity comes from active-profile context.
- Optimistic rows reset/recompute on switch.
- Trusted RPCs verify active profile and ownership.
- Public reaction rows continue to expose reacting profile IDs, not account IDs.
- Account-versus-profile uniqueness is an open decision.

### Follows

- Follow/unfollow acts from active profile.
- Following tab/feed belongs to active profile.
- Switching changes the graph and feed.
- Public follow rows remain profile-to-profile and reveal no owner ID.
- Sibling/self-account and count-inflation behavior requires a decision.

### Festival RSVPs and Notice Board

- RSVP, Notice post, and Notice reaction act as active profile.
- Switch resets `myRsvp`, current reaction state, composer ownership, and any in-flight request.
- Public attendees and posts show only public profile data.
- Account-versus-profile attendance/reaction multiplicity requires a decision.

### Uploads

- Every upload intent carries active `ownerId = profile.id`.
- Presign and finalization independently verify account ownership, account ban, active-profile equality, purpose, resource ownership, index, MIME, size, and expiry.
- Switching invalidates pending UI intents. Finalization repeats current authorization and cannot rely on authorization performed before the switch.
- Account-level rate limiting remains shared.

### Profile editing and creation

- Profile edit operates on the active profile.
- Additional-profile creation appears in the private Header/profile-management surface, with current count and five-profile cap.
- Type remains editable among exactly five values.
- A profile may not change `user_id`.
- Public profile pages never show “other profiles by this owner.”

---

# Part VI — Messaging and email

## 21. Profile-scoped inbox

The database must enforce the fixed inbox rule, not merely filter in React.

For ordinary authenticated clients:

- conversation `SELECT` returns only rows where the active profile is buyer or seller and the active profile has not hidden the row;
- message `SELECT` resolves through those active-visible conversations;
- message `INSERT` requires `sender_profile_id = active_profile_id` and active participation;
- unread add/remove functions operate on the active participant only;
- hide/unhide/find-or-create functions use the active profile deterministically;
- switching profiles closes the current thread, removes old subscriptions, clears prior rows/counts, and loads the new inbox;
- a direct URL to another owned profile's conversation does not open until the user explicitly switches.

This prevents the current broad “any profile owned by `auth.uid()`” policy from merging all sibling inboxes.

## 22. Realtime

Current Realtime publication includes messages, conversations, participant state, Notice posts, and Notice reactions. Profiles are not intended to be published.

Required safeguards:

- active-profile RLS applies to delivered conversation/message rows;
- switch unsubscribes before subscribing to the new profile/thread;
- stale callbacks are generation-guarded;
- payloads never add `user_id` or sibling-profile lists;
- the private active-session table is not added to public Realtime publication;
- profile deletion retains default/minimal delete-event exposure and does not switch to `REPLICA IDENTITY FULL` without a separate privacy review;
- tests verify no old-profile event mutates the new-profile inbox after a switch.

## 23. New-message email

Keep `public.users.email_notifications` as the single account-level switch.

A server-side new-message notifier must:

1. receive or derive the accepted message/conversation ID;
2. identify the recipient profile from conversation participants;
3. resolve its owner privately;
4. read that one account's notification preference and auth email server-side;
5. include the contacted public profile's `@handle` in the subject/body;
6. link to the conversation with an authenticated post-login flow that prompts/switches to the recipient profile only after owner verification;
7. never include sibling profiles or owner IDs;
8. avoid duplicate email on trigger retries;
9. suppress or define email for same-account sibling conversations according to the open decision below.

No per-profile email preference is added in V1.

---

# Part VII — Privacy and unlinkability audit

## 24. Public profile API

### Required boundary

Public and ordinary member callers may read only safe public profile columns, such as:

```text
id
handle
type
display_name
bio
location
avatar_url
header_url
social_links
created_at (only if retained as public)
```

They must not receive:

```text
user_id
private/admin ownership metadata
account role
ban reason
email preference
active-session state
sibling profile count/list
```

### Recommended mechanism

Do not rely on UI omission. Use one reviewed database boundary:

- revoke broad public table `SELECT` and grant only safe profile columns; or
- expose a safe public view/API and revoke direct public profile-table reads.

Because current code contains `select("*")` and nested `profiles(...)` relations, the selected mechanism must be tested across every public profile, listing, conversation, post, reaction, RSVP, Notice Board, and homepage query.

Owners obtain their complete profile list through a dedicated owner-only RPC that returns public/editable profile fields but still need not return `user_id`. Admins use a separate admin-only response that may reveal account grouping.

## 25. RLS and helper oracles

Review every function executable by `anon` or `authenticated` for responses that can test co-ownership.

Rules:

- public helpers may answer only the public question they exist for;
- ownership helpers return to trusted/internal callers only;
- handle availability returns available/unavailable, not who owns or reserved it;
- profile-cap errors are visible only to the owner;
- trying to follow/message a sibling must not return “same account” to another caller;
- no function returns `profiles.user_id` to public roles;
- admin-only owner grouping is guarded by active-admin checks and excluded from public caches/logs.

## 26. Public R2 namespace

Recommended final-key shape:

```text
avatars/<profile-id>/<upload-id>.<ext>
headers/<profile-id>/<upload-id>.<ext>
listings/<profile-id>/<upload-id>.<ext>
posts/<profile-id>/<upload-id>.<ext>
festivals/<owner-profile-id>/<upload-id>.<ext>
```

Using a public profile UUID links media belonging to that profile, which is intended, but does not link sibling profiles.

Private pending keys may remain account-scoped, but public URL construction, token validation, promotion candidates, cleanup candidate derivation, and post image validation must use the profile namespace. If cleanup requires both account and profile context, encode both only in the private pending key or use trusted intent data; never put the auth user ID into the final public key.

### Existing media

Existing public URLs use auth-user namespaces. Before enabling additional profiles:

1. produce an exact read-only manifest of every referenced avatar, header, listing image, post image, and event flyer;
2. map each reference to its owning profile;
3. copy objects create-only into profile-scoped keys;
4. verify bytes, content type, size, and destination uniqueness;
5. update database references in a guarded transaction/slice;
6. verify every public and authenticated page;
7. leave replaced public objects as report-only orphans for at least the established 14-day process;
8. do not introduce or execute public-object deletion through this proposal.

Chunk 11A's post-image helper must accept only the new profile-scoped namespace after migration. A temporary dual-format validator must not allow a new sibling profile to attach media from another owned profile.

## 27. Realtime, caches, logs, analytics, and errors

Audit for indirect links in:

- Realtime row payloads;
- Next.js server-rendered props and hydration data;
- browser network responses;
- sitemap/SEO structured data;
- error messages and support diagnostics;
- analytics/event payloads;
- upload tokens and public errors;
- email links;
- admin data accidentally embedded in public pages;
- public object metadata and key prefixes.

Operational logs may retain auth user IDs where required for security, but they must remain private and must not be returned to clients or analytics products accessible as public product data.

Behavioral inference—similar writing, shared external social links, or profiles following each other—cannot be technically eliminated. The requirement is that Psy's own UI/API/schema does not assert or expose co-ownership.

---

# Part VIII — Reactions, follows, RSVPs, and adjacent edge cases

## 28. Post reactions

Current database semantics are one row per `(post_id, profile_id)`, while product wording historically said one reaction per profile per post and colloquially “one reaction per person.” With up to five profiles, those are no longer equivalent.

Two coherent models exist:

### Profile-level model

- every profile may react once;
- switching profiles shows that profile's reaction;
- one account can contribute up to five public reactions to one post;
- simplest schema, but enables count inflation.

### Account-level model

- one auth account contributes one reaction per post;
- the active profile is the public reactor identity;
- reacting through another owned profile replaces/moves the account's prior reaction;
- requires atomic account-level enforcement through trusted RPCs and locking because the owner is reached through `profiles`;
- preserves “one real person, one reaction” but switching can change the public identity attached to the reaction.

This is an open product decision. Direct post-reaction DML is already revoked, so either model can be enforced in the trusted RPC/trigger package.

Festival Notice Board reactions need the same decision; their current unique key includes `(post_id, profile_id, emoji)` and can allow more than one emoji per profile.

## 29. Follows

The active profile is the follower identity. Existing `(follower_profile_id, following_profile_id)` uniqueness remains valid for profile-level follows.

Still to decide:

- whether sibling profiles may follow one another;
- whether several profiles from one account may all follow the same target and increase public follower counts;
- whether Following feeds are independent for each profile (recommended by the active-profile model) or account-shared.

Regardless, no public follow row includes account ownership.

## 30. RSVPs and event notifications

Current `vendor_events` uniqueness is `(profile_id, event_id)`. Therefore five profiles could create five attendance entries for one human.

Still to decide:

- RSVP is a persona presence (profile-level), or physical attendance by one person (account-level);
- whether one account may mark different profiles as `attending` and `selling` for the same event;
- whether public attendee counts deduplicate by account without revealing ownership (deduplicated counts would need a trusted aggregate and could diverge from visible profile rows).

Event-notification subscriptions are similarly profile-keyed while email is account-owned. If retained, delivery must deduplicate per account and not reveal sibling subscriptions.

## 31. Favorites

Favorites are outside the current frozen V1 scope but remain in the live schema. Do not accidentally expose or expand them while changing generic ownership helpers. If later reactivated, decide whether favorites are active-profile-private or account-private; they must never become an ownership-link oracle.

## 32. Same-account interactions

A user could discover and interact with another profile they own. The system must decide whether to allow:

- sibling-profile direct messages;
- sibling-profile reactions;
- sibling follows;
- buying/contacting a sibling's listing;
- multiple RSVPs.

Blocking these can reduce abuse, but error copy must be private/neutral and must not create a public API that reveals co-ownership.

---

# Part IX — Reserved-profile claims and hidden Auth identities

## 33. Reserved-profile claim workflow

`docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md` currently says an existing account with a profile is ineligible. That is superseded by the fixed Multi-Profile direction.

The claim transaction must instead:

- derive `auth.uid()`;
- require verified, unbanned authentication;
- lock the account and invitation/reservation rows;
- allow the claim when current profile count is below five;
- reject at five without consuming the invitation;
- create/attach exactly one profile using the reserved handle and intended allowed type, including `vendor`;
- preserve global handle normalization/uniqueness;
- mark reservation and invitation atomically;
- return only safe profile data;
- optionally switch the current session to the claimed profile after success;
- never expose the claimant's sibling profiles to the inviter or public claim page.

The proposal for reservations remains separately approval-gated and unimplemented. Its one-profile assumptions must be revised before use.

## 34. Hidden or soft-deleted Auth identity finding

The captured Auth schema includes `auth.users.deleted_at`, and Supabase administration supports deletion paths whose treatment of identities must be explicit. Application-row absence is not sufficient proof that the Auth login identity is gone.

Before account-deletion implementation, perform a read-only inventory of:

- active and `deleted_at` Auth users;
- `auth.identities` rows for deleted/active users;
- `public.users` rows without matching active Auth users;
- profiles whose owner Auth identity is deleted or missing;
- whether a supposedly deleted email can register again under the configured Auth behavior.

Account deletion must explicitly choose and verify hard Auth deletion rather than accidentally leaving a hidden soft-deleted login identity. If policy requires retaining a deletion tombstone, it must be separate from a usable Auth identity and must not retain public profile ownership.

The final account-deletion spec must define retries for the non-transactional boundary between PostgreSQL cleanup and the Auth Admin API.

---

# Part X — Profile deletion and account deletion

## 35. Profile-deletion confirmation

The owner-only deletion screen must show a fresh server-derived summary, including at least:

- profile handle and type;
- listing count by relevant status;
- post count;
- avatar/header/listing/post image reference count;
- conversation count;
- follow/follower rows;
- RSVP/event-notification rows;
- Notice Board posts/reactions;
- any event rows whose `created_by` would block deletion;
- whether the profile is active in this or another current session.

Confirmation requires typing the exact normalized handle. The trusted request re-reads all facts; it does not trust displayed counts or a client “confirmed” boolean alone.

## 36. Trusted profile-deletion operation

Conceptually:

```text
delete_owned_profile(target_profile_id, typed_handle)
```

It must:

1. derive `auth.uid()` and current session;
2. lock the account and target profile;
3. verify ownership and exact typed handle;
4. count current profiles under the lock;
5. if count is one, return a typed result requiring account deletion without deleting anything;
6. resolve blockers such as created events according to the open decision;
7. prepare retained-conversation participant semantics;
8. physically delete profile listings and posts so image references disappear;
9. delete/cascade profile-local follows, reactions, RSVPs, notices, and participant state according to approved rules;
10. physically delete the profile row, freeing the handle;
11. replace/clear active-session rows that selected it;
12. return the replacement active profile and exact deletion result;
13. commit atomically for database state.

Banned-account access to deletion is an open policy question. Privacy/legal deletion may need to remain available even when ordinary mutations are banned.

## 37. Shared-conversation redesign

The fixed requirement prohibits profile deletion from destroying shared history for another participant.

Recommended concept:

- change buyer/seller profile FKs from `ON DELETE CASCADE` to a retained-participant design, most likely nullable `ON DELETE SET NULL` references;
- change `messages.sender_profile_id` to nullable `ON DELETE SET NULL`;
- remove the deleted profile's unread identifier and participant-state row;
- keep the conversation/messages visible to the surviving participant under existing hide semantics;
- prohibit new messages when the other participant no longer exists;
- render a neutral, non-linkable **Deleted profile** participant rather than reusing a freed handle;
- ensure a later profile that claims the freed handle is not linked to the old conversation;
- update unique constraints, triggers, RLS, Realtime, and TypeScript null handling;
- preserve the existing rule that one participant hiding/deleting does not remove the other participant's history.

A detailed messaging-deletion specification is required before SQL because nullable participant columns affect uniqueness, participant authorization, unread state, new-message triggers, and UI rendering.

## 38. Other delete cascades

| Child data | Proposed profile-deletion result |
|---|---|
| Listings | Physical delete; images become report-only orphans |
| Wall posts | Physical delete; post reactions cascade; images become report-only orphans |
| Follows | Cascade/remove both outgoing and incoming relationships involving the deleted profile |
| Favorites | Cascade/remove profile-owned rows |
| Festival RSVPs (`vendor_events`) | Cascade/remove profile attendance |
| Event notifications | Cascade/remove profile subscriptions |
| Notice Board posts | Physical delete; notice reactions on those posts cascade |
| Notice reactions by profile | Cascade/remove |
| Featured-seller rows | Cascade/remove |
| Conversation participant state | Remove deleted participant state; preserve survivor state |
| Shared conversations/messages | Preserve for surviving participant using redesigned nullable/tombstone semantics |
| Moderation audit | Preserve metadata-only audit according to current design; do not retain public content/image references |
| Events created by profile | Current non-cascading FK blocks deletion; requires product decision |

## 39. Public media after deletion

No public object is deleted during profile or account deletion.

Physical database deletion removes avatar/header/listing/post references so objects become candidates for the existing report-only orphan process. The orphan scanner must include all current reference sources and profile-scoped key patterns. Quarantine cleanup remains separate and intent-authorized.

## 40. Account deletion concept

The account-deletion flow is not “delete the final profile.” It is a distinct high-assurance operation covering:

- every profile owned by the account;
- all profile-local content under the rules above;
- retained shared conversations for other participants;
- `public.users` account state and notification preference;
- active-profile session state;
- Supabase Auth user and identities;
- session/token revocation;
- report-only public media orphaning;
- idempotent retry and support recovery if Auth deletion fails after database cleanup.

Recommended conceptual orchestration:

1. require a fresh authenticated/re-authenticated session and explicit account confirmation;
2. show a summary across all profiles;
3. set a private `deletion_requested_at`/equivalent idempotency marker on `public.users` and make every account mutation helper fail closed while it is set;
4. execute the guarded database cleanup transaction while retaining the marked `public.users` row so an Auth-API failure cannot restore ordinary account access;
5. call the server-only Auth Admin API for explicit hard deletion; successful Auth deletion then cascades/removes the application-user marker;
6. verify Auth user/identity removal and session invalidation;
7. if the Auth call fails, keep the marked account fail-closed and retry safely rather than restoring partial public content or leaving a usable hidden identity.

No browser receives the service-role credential. The detailed account-deletion spec must define reauthentication, legal retention, retries, email reuse, and support recovery before implementation.

---

# Part XI — Existing/demo-data migration

## 41. Data migration principle

Existing demo profiles and listings must remain available throughout development. No demo-data purge is part of Multi-Profile.

Current accounts already have one profile, so no ownership split or synthetic profile creation is needed.

## 42. Required preflight

The owner-applied read-only preflight must report at least:

- profile counts per auth account, with exact distribution from zero through greater than five;
- orphan profiles and application users;
- current `profile_type` values and dependencies;
- exact indexes/constraints on `profiles.user_id` and handles;
- current profile table grants and column exposure for `anon`/`authenticated`;
- all functions/policies/views exposing `user_id`;
- Realtime publication and replica identity state;
- every `LIMIT 1` or one-profile function definition expected to change;
- all child FKs and delete actions from profiles;
- current events grouped by `created_by`;
- current shared conversations/messages by profile;
- existing hidden/soft-deleted Auth users and identities;
- every referenced public R2 URL grouped by purpose, namespace UUID, and owning profile;
- zero/mismatch checks proving each media reference can be mapped to exactly one profile;
- suitable fixtures for account ban across multiple profiles, profile switching, and deletion; if unavailable, mark verification branches `UNPROVEN`, not passed.

## 43. Migration sequence for current rows

1. Do not rewrite profile ownership.
2. Add `vendor` enum label.
3. Introduce privacy-safe profile reads and update application queries before allowing multiple rows.
4. Migrate referenced public media from auth-user to profile namespaces using an exact manifest and create-only copies.
5. Switch database references in guarded batches/transactional units.
6. Verify all references and leave old public objects report-only.
7. Add active-session/profile helpers and five-cap trigger.
8. Replace ambiguous policies/RPCs.
9. Drop the one-profile unique index only when all privacy and authorization prerequisites are live.
10. Enable additional-profile creation last.

This ordering prevents a period where a second profile can be created while APIs or media URLs still reveal its owner.

## 44. Rollback posture

Rollback must be slice-specific:

- disabling additional-profile creation is safe without deleting profiles;
- once accounts own multiple profiles, recreating `profiles_one_per_user_key` is impossible without destructive consolidation and must not be an automated rollback;
- rollback after the cardinality gate opens should preserve all profiles and instead disable switch/create/mutations until a forward fix;
- copied public objects are not deleted during rollback;
- database reference switches can roll back only while exact old/new manifests and references remain valid;
- `vendor` may remain as an unused enum label in operational rollback;
- conversation FK changes need dedicated reversible guards but cannot reconstruct rows already cascade-deleted, so deletion UI must remain disabled until the new model is proven.

The irreversible boundary is **first successful creation of a second profile**. It requires explicit owner approval after all prior slices pass.

---

# Part XII — Ordered implementation slices

Each slice gets its own scope, preflight, apply/rollback/verify package where applicable, focused tests, full static checks, staging review, and separate commit. No later slice starts until the previous slice is verified.

**Database-first discipline:** MP-1 through MP-4 author, review, and where compatibility permits apply the complete database/privacy foundation before feature application work starts. If a restrictive grant/policy cannot be activated without breaking the current client, its exact SQL is still finalized and verified as a staged cutover package before the dependent app slice. Application slices may consume those pre-reviewed contracts; they may not invent schema ad hoc. The one-profile unique index remains in force until the final enablement gate, so no second profile can exist while privacy or identity flows are incomplete.

## Slice MP-0 — Decision/document reconciliation

- Approve this proposal and answer open questions.
- Amend `V1_DECISIONS.md`, `REFINED_PRD.md`, `USER_ROLES.md`, `RESERVED_PROFILE_CLAIM_WORKFLOW.md`, punch list, and launch checklist.
- Mark prior one-profile V1 statements superseded without erasing historical context.
- Define detailed account/profile deletion and messaging tombstone behavior.

**Verification:** documentation cross-reference and contradiction scan.

## Slice MP-1 — Fresh read-only preflight and package design

- Capture exact live catalog/data/media state.
- Produce guarded preflight, apply, verify, and rollback SQL packages for every database slice before app implementation.
- Inventory every table, constraint, policy, function/overload, trigger, grant, and publication dependency.
- Produce media copy/switch manifests without writing data.
- Record which restrictive changes are additive now and which are held for a coordinated cutover.

**Verification:** preflight returns explicit `GO` or `STOP`; unavailable fixtures are `UNPROVEN`; every expected object has exact definition/ACL guards.

## Slice MP-2 — Database privacy and public-profile contracts

- Add a safe public profile view/API or exact safe-column grant contract excluding `user_id` and private ownership state.
- Add owner-only profile-list and admin-only account-grouping RPC contracts.
- Add private ownership/active-profile boolean helpers so server code no longer needs public owner-column access.
- Audit function outputs and Realtime publication/replica identity.
- Prepare the guarded revocation of broad profile-table reads, but do not activate a revocation that would break current `select("*")` clients until MP-5.

**Verification:** direct database/API probes against new contracts cannot reveal owner IDs; owner/admin paths return only their approved shapes; existing one-profile app remains operational before cutover.

## Slice MP-3 — Database cardinality, type, and active-session foundation

- Add `vendor` enum value.
- Add immutable ordinary profile-owner guard.
- Add locked five-profile cap trigger and ensure a non-unique owner lookup index exists.
- Add private session-active-profile state and hardened get/switch helpers.
- Add but do not expose the trusted additional-profile creation RPC.
- Keep `profiles_one_per_user_key` in force; this slice does not yet permit a second profile.
- Keep signup auto-creation unchanged and verify exact-profile signup completion.

**Verification:** session-active helpers work on current one-profile accounts; cap trigger/package passes synthetic transaction tests; signup still creates exactly one personal profile; no public owner leak; additional-profile execution remains unavailable.

## Slice MP-4 — Database active-authorization and deletion foundation

- Author active-profile-aware replacements for listings, messages, conversations, posts, reactions, follows, RSVPs, notices, event notifications, favorites, and upload authorization.
- Replace every ambiguous database `LIMIT 1` actor selection with current active profile semantics.
- Apply compatibility-safe conversation FK/nullability and deleted-participant foundations without enabling profile deletion.
- Prepare exact restrictive policy/RPC/ACL cutovers for dependent app slices.
- Preserve account-level bans and rate limits.
- Keep second-profile creation disabled by the unique index.

**Verification:** catalog definitions and ACLs match exact expected sets; old one-profile behavior remains compatible; nullable/deleted-participant fixtures preserve surviving conversations; no deletion UI or profile-creation path is enabled.

## Slice MP-5 — Public-profile client cutover and active Header

- Convert every public profile query from `*` to explicit safe fields/view.
- Split public `Profile` types from private owner/admin contracts.
- Build the root active-profile provider.
- Add owner-only up-to-five profile menu and switch action in the Header.
- Add auth-transition, cross-tab, stale-request, and deleted-profile handling.
- Convert Header counts/navigation.
- Activate the pre-reviewed MP-2 public owner-column revocation only after the compatible client is staged.
- Keep additional-profile creation unavailable.

**Verification:** switch is session-scoped, separate sessions remain independent, stale data never crosses identities, public DOM/network has no sibling list or owner ID, and all public pages work after grant cutover.

## Slice MP-6 — Profile media namespace, listings, editing, and uploads

- Change public final-key derivation to profile namespace.
- Update token/promotion/cleanup validation and Chunk 11A post-image validation.
- Copy existing referenced objects create-only and switch exact references.
- Retain old objects as report-only orphans.
- Convert listing create/edit/manage/delete and profile editing to active profile.
- Add **Posting as @handle (switch)** to listing creation.
- Bind upload presign/finalize to active profile and resource.
- Implement switch-with-unsaved-work behavior.

**Verification:** byte/type/size parity, exact reference counts, no auth-user UUID in new public keys, all upload purposes pass, stale/cross-profile writes fail, active writes pass, orphan report remains correct.

## Slice MP-7 — Wall posts and reactions

- Convert composer/edit/delete/reactions to active profile.
- Add fixed post actor hint.
- Implement the resolved account-vs-profile reaction model in the pre-reviewed RPC package.
- Activate active-profile post/reaction authorization.
- Preserve 11D visibility, account ban, Hero, rate-limit, and orphan rules.

**Verification:** all visibility matrices, account-wide ban behavior, account-level rate sharing, switch races, reaction uniqueness, and public unlinkability.

## Slice MP-8 — Messaging and notification email

- Activate active-profile-only conversation/inbox/read/send/hide/unhide contracts.
- Reset Realtime and thread state on switch.
- Implement one account-level email preference with contacted-profile handle.
- Verify nullable/deleted-participant handling in normal inbox code.
- Do not enable profile deletion yet.

**Verification:** identity-isolated inboxes under database RLS, stale subscriptions cannot leak, notification targets the correct account/profile without duplicates, and retained conversation fixtures render safely.

## Slice MP-9 — Follows, Following, festivals, RSVPs, and notices

- Implement resolved actor/count semantics.
- Activate the pre-reviewed active-profile policies/RPCs for every mutation and private feed.
- Preserve public profile-only presentation and account bans.

**Verification:** sibling-abuse cases, count semantics, switch state, public privacy, and direct RLS probes.

## Slice MP-10 — Multi-Profile enablement and reserved-profile claims

This is the irreversible cardinality gate and requires explicit owner approval.

- Confirm MP-2 through MP-9 are staging-verified.
- Drop `profiles_one_per_user_key` under exact guards while retaining the locked five-cap trigger and non-unique owner index.
- Grant/enable trusted additional-profile creation and UI.
- Replace reserved-claim one-profile eligibility with below-five eligibility.
- Make claim atomic with account/profile cap locks.
- Preserve invitation privacy and handle protections.
- Create the first reviewed second-profile staging fixture only after apply verification passes.

**Verification:** one-through-five creation works; sixth fails; concurrent four-to-five creates permit exactly one success; fifth-to-sixth claim fails without consuming invitation; full app matrices rerun with real multi-profile fixtures.

## Slice MP-11 — Conversation retention under profile deletion

- Complete the reviewed nullable/tombstone participant model in UI and database.
- Update RLS, triggers, unique constraints, Realtime, unread state, and null rendering.
- Verify surviving participant history before enabling deletion.

**Verification:** deleting a controlled test profile preserves survivor conversation/messages and removes deleted participant access; no freed-handle relinking; no public owner leak.

## Slice MP-12 — Profile deletion

- Add fresh summary and typed-handle confirmation.
- Add trusted real-deletion operation.
- Redirect last-profile attempt to account deletion.
- Preserve report-only media orphan policy.

**Verification:** exact cascade matrix, last-profile guard, concurrent delete/create behavior, active-session fallback, orphan report, and created-event blockers.

## Slice MP-13 — Account deletion

- Implement the separately approved detailed account-deletion specification.
- Add reauthentication, fail-closed/idempotent database/Auth orchestration, retry state, session revocation, and hard Auth identity verification.
- Preserve counterpart conversation history.

**Verification:** successful deletion, Auth failure/retry, hidden/soft-deleted identity probe, re-registration policy, multi-session revocation, and orphan report.

## Slice MP-14 — Full launch gate

- Run complete static/type/test suite.
- Run direct PostgREST RLS/privacy matrix for anon, each profile/session, banned account, admin, and service role.
- Run browser matrix across two accounts, five profiles, two sessions, and multiple tabs.
- Inspect DOM, network, Realtime, emails, public R2 URLs, logs, sitemap/SEO output, and error text for co-ownership leaks.
- Complete the standing manual launch checklist.

**Verification:** owner acceptance on staging before commit/push of each coordinated app slice and before production cutover.

---



## 45. Profile cap matrix

| Existing count | Operation | Expected |
|---:|---|---|
| 0 | Signup/bootstrap repair only | Exactly one personal profile; ordinary zero-profile account is exceptional |
| 1–3 | Create one | Success |
| 4 | Two concurrent creates | Exactly one success; final count five |
| 5 | Create/claim one | Rejected; no partial reservation consumption |
| Any | Banned account create | Rejected |
| Any | Cross-account owner ID | Rejected |
| 2+ | Delete one non-last profile | Success after confirmation |
| 1 | Delete profile | No deletion; typed result redirects to account deletion |

## 46. Active-profile authorization matrix

For two profiles A and B owned by one account:

| Session active | Submitted actor | Owned? | Expected identity write |
|---|---|---:|---|
| A | A | Yes | Allowed if resource/payload valid |
| A | B | Yes | Rejected as stale/inactive |
| A | Other account C | No | Rejected |
| B | B | Yes | Allowed |
| Missing/invalid | A or B | Yes | Fail closed, initialize/switch before action |
| Any | Any | Banned account | Rejected |

Public reads remain governed by existing content visibility and ban rules, not active-profile state.

## 47. Unlinkability matrix

An anonymous or ordinary authenticated caller must not be able to derive common ownership from:

- profile table fields;
- public views or nested relations;
- errors/availability endpoints;
- follower/RSVP/reaction helper outputs;
- Realtime payloads;
- public R2 key prefixes;
- HTML/React hydration;
- structured data/sitemaps;
- email links visible to unrelated users;
- API response timing or count endpoints explicitly grouped by owner.

An owner must see all own profiles in private switcher/management surfaces. An active admin may see account grouping only through admin-authorized surfaces.

## 48. Ban matrix

Banning any one public profile resolves its account and must:

- set one account ban state;
- suspend all owned profile compatibility flags;
- reject writes as every owned profile;
- hide posts from every owned profile under current Wall rules;
- clear Hero flags from every owned profile's posts;
- synchronize one Auth ban;
- preserve ordinary/admin read behavior already decided;
- unban all owned profiles together.

## 49. Deletion matrix

Verify profile deletion independently for:

- no content;
- active/draft/sold/admin-unpublished listings;
- public and members-only posts with reactions;
- avatars, headers, listing images, and post images;
- incoming/outgoing follows;
- RSVP and event notifications;
- Notice Board posts/reactions;
- surviving-party conversations and messages;
- active sessions on deleted profile;
- created events;
- freed handle reuse by another account without historical conversation relinking;
- banned account and admin-owned profile cases.

---

# Part XIV — Risks and non-goals

## 50. Highest risks

1. **Direct privacy leak:** `profiles.user_id` is currently publicly queryable under broad profile reads.
2. **Media correlation:** current public R2 paths embed auth-user IDs.
3. **Shared-message loss:** current profile FKs cascade-delete conversations/messages.
4. **Stale identity writes:** a switch during an upload/form/RPC can publish under the wrong profile without generation and server-active checks.
5. **Count inflation:** reactions, follows, and RSVPs currently key uniqueness by profile, not real account/person.
6. **Rollback boundary:** after a second profile exists, restoring one-profile uniqueness is destructive and not an acceptable automatic rollback.
7. **Auth/database partial deletion:** account deletion spans PostgreSQL and Supabase Auth and needs idempotent failure recovery.
8. **Admin leak:** existing moderation may rely on public `user_id`; replacing it incorrectly can embed sibling ownership in public responses.

## 51. Non-goals

This proposal does not add:

- more than five profiles;
- profile types beyond `vendor`;
- public links between sibling profiles;
- team/shared management of one profile by multiple auth accounts;
- per-profile email preferences;
- public-object automatic deletion;
- a status-only soft-delete for listings/posts/profile content;
- payments, reviews, or other unrelated scope;
- schema SQL or application implementation in this document.

---

# Part XV — Open questions for Turgay

The fixed decisions answer the core architecture. These remaining product decisions are required before the relevant slices:

1. **Post reactions:** Is “one reaction per person per post” one per auth account, or may each of up to five profiles react separately? Recommendation: one per account, displayed through the active profile; switching identity moves/replaces the account's reaction.
2. **Festival Notice Board reactions:** Should they follow the same account-level rule as Wall reactions, and should one profile still be limited to one emoji rather than the current per-emoji uniqueness?
3. **RSVPs:** Is attendance one per real account/person, one per public profile, or may one account use one attending profile plus one selling/vendor profile at the same festival?
4. **Follows:** May sibling profiles follow each other, and may several profiles from one account all count as followers of the same target? Recommendation: feeds are per profile; block sibling follows and decide whether follower counts deduplicate accounts.
5. **Same-account messaging/listing contact:** May one owned profile message or contact another owned profile? Recommendation: block it with neutral owner-only feedback and send no email.
6. **Profile types:** May one account create multiple profiles of the same type, including multiple `personal` profiles? The fixed decisions set the total cap but not per-type limits. Recommendation: allow duplicates; identity names/handles are the distinction.
7. **Own inactive profile pages:** When an owner visits a sibling profile that is not active, should the page show a private **Switch to @handle to manage** action automatically, or require switching only from the Header? Recommendation: show the private action but never auto-switch.
8. **Unsaved work:** Should switching profiles be blocked while a listing/post/profile form has unsaved changes, or allowed after confirmation? Recommendation: confirmation with “Stay” and “Discard and switch.”
9. **Created events on profile deletion:** Current `events.created_by` blocks profile deletion. Should events transfer to the hidden technical `@turgay` owner, remain with a non-public tombstone, or block deletion pending admin handling? Recommendation: block and require reviewed admin transfer; never delete public festival data silently.
10. **Deleted conversation identity:** Should surviving participants see only **Deleted profile**, or retain a historical display name/avatar? Recommendation: neutral **Deleted profile**, no handle link or avatar, so freed handles cannot be confused with history.
11. **Banned-account deletion:** May a banned user delete profiles/account through self-service, or must support/admin process it? Recommendation: allow high-assurance account deletion for privacy while keeping all ordinary mutations blocked; profile-only deletion may remain support-gated while banned.
12. **Account-deletion retention:** What minimal private moderation/legal audit, if any, survives account deletion, and for how long? Public content and Auth identity behavior are fixed by the deletion decision, but legal retention needs owner/legal confirmation.
13. **Email reuse after account deletion:** May the same email register immediately after verified hard deletion? Recommendation: yes unless a legally required private abuse tombstone blocks it without retaining a usable Auth identity.
14. **New-profile onboarding:** Which fields are mandatory beyond handle, display name, and type, and should the new profile become active immediately? Recommendation: those three only; switch to it after successful creation.
15. **Admin presentation:** Should admins see sibling profiles inline on every moderation card, or only in a dedicated private account panel? Recommendation: dedicated panel to reduce accidental exposure and UI confusion.

---

## Final proposal verdict

Multi-Profile is feasible without replacing the profile-centered marketplace model, but it is not a small switch. The profile foreign keys provide a useful foundation; the one-profile assumptions remain embedded in public column exposure, media namespaces, auth lookup code, messaging RPCs/policies, and delete cascades.

The privacy and conversation-deletion blockers must be solved before the first second profile is created. The five-profile cap, active-session identity, and account-level ban model can then be added safely in guarded slices. Additional-profile creation should be the final enablement step after public unlinkability, profile-scoped media, active-profile authorization, and deletion-compatible messaging have all passed independent verification.
