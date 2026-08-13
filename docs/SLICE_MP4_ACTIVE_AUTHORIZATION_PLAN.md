# Slice MP-4 — active authorization and deletion foundation plan

**Prepared:** 2026-08-13
**Status:** INVESTIGATION / PACKAGING PROPOSAL — no Slice MP-4 SQL has been authored or applied
**Current database state:** MP-3 foundations are live; `profiles_one_per_user_key` remains in force; the site remains one-profile-per-account

## 1. Purpose and evidence boundary

This document plans the proposal's **Slice MP-4 — Database active-authorization and deletion foundation**. It is a pre-authoring investigation, not an implementation record.

Authoritative inputs:

- [`MULTI_PROFILE_PROPOSAL.md`](MULTI_PROFILE_PROPOSAL.md), especially resolved decisions and Slice MP-4;
- [`DECISIONS_HANDOVER.md`](DECISIONS_HANDOVER.md) §6, especially active identity/inbox, per-profile interactions, same-account contact, and neutral deleted identity;
- [`research/PROJECT_STATUS_GROUND_TRUTH.md`](research/PROJECT_STATUS_GROUND_TRUTH.md), including all addenda;
- [`MP4_POLICY_CONVERSION_VERIFICATION.md`](MP4_POLICY_CONVERSION_VERIFICATION.md), whose 22 converted policies and 10 converted functions are the current live authorization baseline;
- [`MP3_FOUNDATION_VERIFICATION.md`](MP3_FOUNDATION_VERIFICATION.md), whose process lessons govern all future catalog pins.

Repository SQL is evidence of the reviewed live baseline only where the verification records say it was applied. The live catalog remains authoritative. No baseline fingerprint below may be reconstructed from repository history.

### Done criteria for Slice MP-4 authoring later

1. Every identity-bearing database action resolves one current session-active profile, never an arbitrary owned profile.
2. Existing one-profile behavior remains compatible while `profiles_one_per_user_key` stays in force.
3. Shared-conversation columns and dependent logic are prepared for a later retained-participant cutover, but profile deletion remains impossible and current FK delete behavior remains unchanged.
4. Account bans and account-level rate limits remain unchanged.
5. Package D column ACLs and public-profile privacy remain exact.
6. The current application at the then-approved pre-apply HEAD continues to work without a user-visible change.
7. Every package has live-derived guards, an allow/deny verifier, and a guarded rollback.

---

## 2. Authorization model

### 2.1 Ownership is not active authority

The current compatibility helper `public.current_user_owns_profile(uuid)` answers whether the authenticated account owns a profile. That remains useful for owner-only profile lists, private admin/account checks, and explicitly trusted server workflows. It is too broad for identity-bearing actions after an account can own siblings.

Slice MP-4 should add a separate primitive with semantics equivalent to:

- **read-only active ID accessor**: return the one profile currently selected for this authenticated session, or `NULL` when identity cannot be proven;
- **active-profile boolean**: return true only when the supplied profile ID equals that read-only active ID;
- **active-and-unsuspended boolean**: active equality plus the existing suspension condition where current behavior already requires it (notably listing creation).

Names and signatures are not fixed by this plan; they must be chosen during package authoring and pinned from the resulting reviewed definitions.

### 2.2 Why `get_active_profile()` must not be used in RLS

The MP-3 `public.get_active_profile()` function is deliberately `VOLATILE`. It:

- requires an authenticated session ID;
- locks the caller's `public.users` row;
- rejects banned accounts;
- lazily selects the first owned profile when no session state exists;
- writes/upserts `private.account_session_active_profiles`.

That is appropriate for an explicit application bootstrap call. It is unfit for policy-frequency evaluation: a list query may evaluate an RLS expression many times, and a read must not repeatedly acquire an account lock or cause lazy writes.

### 2.3 Proposed read-only compatibility accessor

The lighter accessor should be `STABLE`, `SECURITY DEFINER`, `search_path=''`, have the minimum authenticated-only ACL, and perform no lock and no write.

Resolution order:

1. Require `auth.uid()` and the existing private authenticated-session ID helper. Missing either returns `NULL`/false; it never guesses across sessions.
2. Read an exact `(session_id, user_id, profile_id)` row joined back to `profiles` to prove current ownership.
3. While `profiles_one_per_user_key` is still exact and valid, if no state row exists, return the caller's **only** owned profile without persisting it. This keeps the current app working before MP-5 starts explicit bootstrap.
4. If there are zero profiles, more than one profile, a stale/mismatched session row, or an invalid session claim, return `NULL`/false.
5. The compatibility fallback must be guarded by the exact one-profile index and must be removed or made unreachable before that index is dropped. There must never be a `LIMIT 1` fallback after cardinality opens.

### 2.4 Exact fail-closed matrix

| Case | Read-only active identity | Identity-bearing mutation | Existing permitted reads |
|---|---|---|---|
| anonymous / no `auth.uid()` | `NULL` / false | denied | public reads only |
| authenticated but no valid session ID | `NULL` / false | denied | only public reads; no owner/inbox scope |
| valid state row owned by caller | selected profile | allowed only when row/RPC actor equals it and all existing checks pass | active-profile private reads only |
| no state row + exact one-profile gate + exactly one owned profile | sole profile, read-only compatibility fallback | same as current one-profile behavior | same as current one-profile behavior |
| no state row with zero or multiple owned profiles | `NULL` / false | denied | no active-profile private reads |
| stale row, wrong owner, or missing selected profile | `NULL` / false | denied | no active-profile private reads |
| account banned | identity may still be resolved for retained read behavior | denied by the existing account-level ban check | current ordinary/admin read behavior is preserved |
| selected profile suspended but account ban state is absent | identity still resolves | preserve current family-specific rules; listing creation still requires active **and unsuspended**; do not silently invent a new global suspension rule | active-profile reads remain as today |

Bans remain authoritative on `public.users.banned_at`; active identity must not replace or weaken `current_user_is_banned()`. The standalone `is_suspended` compatibility flag is not promoted into a new product-level ban system in this slice.

---

## 3. Complete actor inventory

### 3.1 Live RLS policies

The current live conversion baseline contains the following actor-sensitive policies. Public visibility helpers/policies that do not choose the caller's identity are noted separately.

| Table / live policy | Current behavior | Target active-profile behavior | Failure at two profiles if unchanged |
|---|---|---|---|
| `profiles` — `Unbanned users update own profiles` | Any profile whose `user_id=auth.uid()` can be updated by the account. | Update only the active profile; preserve ban and owner-immutability triggers. | A stale/inactive sibling page or request could edit another sibling without switching. |
| `profiles` — `Unbanned users insert own profiles` | Direct insert accepts caller ownership subject to ban and the live unique gate/cap triggers. | Remove authenticated direct-INSERT authority now (exact policy/grant cutover), while preserving SECURITY DEFINER signup and the unexposed dedicated creation RPC. | If the one-profile index were later removed while this stayed open, direct client inserts could bypass the reviewed creation flow. |
| `listings` — `Owners can read own private listings` | Any caller-owned profile exposes its private listings. | Private listing reads only for the active profile. | One session sees drafts/admin-unpublished rows for every sibling. |
| `listings` — `Unbanned owners create active listings` | Any owned unsuspended `profile_id` can create. | `profile_id` must equal active and be unsuspended; existing status/moderation checks stay. | A stale form can publish as an inactive sibling. |
| `listings` — `Unbanned owners update own listings` | Any owned listing may be updated. | Resource owner must equal active profile in both `USING` and `WITH CHECK`. | Cross-sibling edits and ownership-by-stale-state become possible. |
| `listings` — `Unbanned owners delete own draft listings` | Any owned profile's eligible draft can be deleted. | Draft owner must equal active profile. | Active A can delete sibling B's draft. |
| `conversations` — `Unbanned buyers create conversations` | Any owned `buyer_profile_id` may be supplied; listing seller integrity is checked. | Buyer must be active; additionally reject seller profiles owned by the same account, with neutral private failure. | Caller can contact as an inactive sibling and can create sibling-to-sibling conversations. |
| `conversations` — `participants view visible conversations` | A conversation is visible if either participant is any caller-owned profile and that owned participant has not hidden it. | Only the active participant side authorizes read; hide state is evaluated only for that active participant. Nullable deleted counterpart remains readable to survivor. | Inbox merges all siblings and one sibling's state can affect another's view. |
| `conversation_participant_state` — `Participants read own conversation state` | Reads state for any caller-owned profile. | Read state only for active participant. | Hidden/read state leaks across sibling inboxes. |
| `messages` — `Unbanned participants send messages` | Any owned `sender_profile_id` that is a participant may send. | Sender must be active, be the surviving participant, and conversation must have two present participants. | Caller sends as inactive sibling; deleted-counterpart threads could remain writable. |
| `messages` — `participants view messages` | Reads messages in conversations involving any owned profile. | Read only messages in conversations involving active profile; retained rows with null sender remain readable to survivor. | All sibling histories merge. |
| `vendor_events` — add/remove RSVP policies | Any owned profile can add/remove its RSVP. | RSVP actor must equal active profile. Preserve per-profile uniqueness and sibling-different-role decision. | One session can mutate every sibling's RSVP without switching. |
| `notice_posts` — create/delete policies | Any owned profile can create/delete its notice post. | Actor/resource profile must equal active. | Cross-sibling posting/deletion. |
| `notice_reactions` — add/remove policies | Any owned profile can add/remove its per-profile/per-emoji reaction. | Reaction profile must equal active. | Cross-sibling reactions; account can choose identity per request without switch. |
| `favorites` — read/manage policies | Any caller-owned profile's private favorites are readable/mutable. | Restrict to active profile; keep feature unexpanded/outside V1. | Private favorites merge and can be mutated across siblings. |
| `follows` — follow/unfollow policies | Any owned follower profile can mutate graph. | `follower_profile_id` must be active; exact self-follow remains blocked by existing database mechanics; sibling follow remains allowed. | Caller can mutate every sibling's feed identity. |
| `event_notifications` — read/subscribe/unsubscribe policies | Any owned profile can manage subscription rows. | Restrict row actor to active profile; delivery preference remains account-level. | Sibling subscription state merges or is silently changed. |

Public `listings` active/sold reads, visible `posts`, visible `post_reactions`, and their current visibility helper functions do not select the caller's actor identity. They remain in the guard manifest because policy interactions and Package D privacy must not drift, but active-profile conversion does not narrow public content visibility.

### 3.2 Live RPCs/functions and triggers

| Object | Current behavior | Target | Failure at two profiles if unchanged |
|---|---|---|---|
| `current_user_owns_profile(uuid)` | True for any sibling owned by account. | Keep as ownership primitive; remove it from identity-bearing policy/RPC decisions. | If reused as actor authority, every sibling is simultaneously authorized. |
| `current_user_owns_unsuspended_profile(uuid)` | Ownership plus target not suspended. | Keep ownership meaning or replace policy use with active-and-unsuspended primitive. | Listing create can target inactive sibling. |
| `append_unread_for(uuid,text)` | Derives caller side using owned participant checks and marks supplied other participant unread. | Derive caller strictly from active profile; require buyer/seller non-null and distinct, active caller equal one participant, and recipient equal the other participant. | Ambiguous if both conversation participants are sibling-owned; inactive sibling can mutate unread state. |
| `remove_unread_for(uuid,text)` | Derives an owned participant and clears only that supplied participant. | Active profile must be participant and supplied profile must equal active. | Clears sibling unread marker. |
| `hide_conversation(uuid)` / `unhide_conversation(uuid)` | Derive one caller-owned participant side. Older definitions used `LIMIT 1`; live conversion uses any-owned checks. | Use active profile only; nullable counterpart does not affect survivor state. | Wrong sibling's participant state is changed. |
| `get_my_profiles()` | Returns the complete ordered owner-only profile set; `find_and_unhide_conversation` currently takes the first ordered row only after counting and rejects when count exceeds one. | Keep as owner-management/list contract, never as actor selection. | Existing singleton consumers fail closed/outage at two profiles until active selection replaces them; they do not silently authorize an arbitrary sibling. |
| `find_and_unhide_conversation(uuid,uuid)` | Uses `get_my_profiles()`, deterministically selects the first ordered owned profile only when the count is exactly one, and rejects counts above one. | Caller is active profile; reject same-account target, deleted target, and preserve listing-target integrity. | Deterministic fail-closed outage at two profiles; contact cannot proceed until active selection is used. |
| `create_post(uuid,...)` | Target may be any owned profile. | Target must equal active; existing ban, content, URL/image and account rate-limit checks stay. | Posts as inactive sibling. |
| `update_post(uuid,...)` / `delete_own_post(uuid)` | Resource author may be any owned profile. | Resource author must equal active. | Edits/deletes sibling posts. |
| `set_post_reaction(uuid,uuid,text)` / `remove_post_reaction(uuid,uuid)` | Supplied reaction profile may be any owned profile. | Supplied/resource reaction profile must equal active. | Reacts as arbitrary sibling. |
| `guard_post_reaction_identity()` trigger | Prevents changing reaction `post_id`/`profile_id`; does not choose caller actor. | Keep unchanged and pinned; RPC remains mutation boundary. | No direct actor ambiguity, but omission from guards could permit identity drift. |
| `enforce_post_write_invariants()` and post rate-limit path | Enforces post invariants/rate limit keyed to account. | Preserve account-level rate limit; active equality belongs at RPC boundary. | Changing limiter to profile would create a fivefold bypass. |
| `enforce_conversation_listing_seller()` trigger | Enforces linked listing's seller profile. | Keep exact-parent/listing rule; make null-safe for future deleted participant and prohibit new/changed listing link when seller is absent. | Nullable foundation could break trigger assumptions or allow malformed retained rows. |
| `unhide_conversation_for_message_recipient()` trigger | New message clears only recipient hidden state. | Require valid sender participant and non-null other participant; no trigger path may recreate state for a deleted profile. | Null participant errors or stale participant-state recreation. |
| `update_conversation_last_message()` / `on_message_insert` | Trigger copies inserted body/time to exact parent conversation. | Preserve exact-parent guard and behavior; accept nullable historical `sender_profile_id`, but new inserts still require non-null active sender. | Deletion schema can break trigger assumptions; unsafe relaxation could update wrong parent. |
| profile cap and owner-immutability triggers | Enforce five cap and immutable `user_id`. | Preserve exactly. | Weakening would bypass MP-3 foundation. |

All other admin/moderation functions remain profile-targeted administrative operations, not caller-public identity selection. They must be included in package drift checks when touched by FK/nullability dependencies, but must not be converted to active-profile authority.

### 3.3 Application query and mutation paths

The current app deliberately uses the one-profile compatibility bridge `getMyProfiles()` + `getOnlyProfileForCurrentAccount()`, which throws if more than one row appears. Slice MP-4 does **not** modify the app; this inventory identifies the MP-5+ consumers that the database cutovers must prepare.

| Path / files | Current actor behavior | Target behavior / later consumer | Failure at two profiles if unchanged |
|---|---|---|---|
| Header auth/counts — `components/layout/Header.tsx` | Loads the only profile; avatar and unread query use it. | MP-5 active provider; unread count active-only. | Throws/clears auth or shows wrong identity/counts. |
| Profile/reaction identity hook — `lib/posts/use-reaction-viewer.ts`, `StreamPageClient`, `ProfileWall` | Resolves only profile and supplies it to reaction RPCs. | MP-5/MP-7 active profile; reset stale optimistic state on switch. | Reactions use arbitrary/stale sibling. |
| Profile edit — `app/profile/edit/page.tsx`, `components/EditProfileModal.tsx` | Loads/updates one profile directly. | MP-6 active-only editing, with MP-5 providing the active provider/inactive-page switch action and MP-6 enforcing dirty-form switching. | Edits inactive sibling or breaks on two rows. |
| Listing create/edit/manage — `app/listings/new/page.tsx`, `NewListingModal`, `app/listing/[id]/edit/page.tsx`, `EditListingModal`, `app/[handle]/page.tsx` `ListingCard.handleDelete` | Uses only profile or passed profile ID for create/edit/upload; profile-page “delete” directly updates listing status to `draft` by listing ID. | MP-6 active identity, posting-as hint, stale switch rejection, and active-owner authorization for every create/edit/status transition. | Publishes/edits/uploads as inactive sibling or changes a sibling listing to draft. |
| Contact flows — `app/listing/[id]/page.tsx`, `app/[handle]/page.tsx` | Only profile becomes buyer; calls find/unhide then inserts conversation. | MP-8 active buyer; neutral same-account denial. | Contacts as inactive sibling or contacts sibling. |
| Inbox — `app/messages/page.tsx`, `components/MessagesInbox.tsx`, Header | Redirects to only profile; filters conversation/read/unread/send/hide state by supplied profile ID. | MP-8 active-scoped inbox and reset on switch. | Mixed inbox, wrong sender, wrong unread/hide state. |
| Festivals/notices — `app/festivals/[slug]/page.tsx` | One `myProfileId` drives RSVP, notice posts/reactions, and local reaction state. | MP-9 active profile. | Mutates arbitrary sibling identity. |
| Wall posts — `components/ProfileWall.tsx` | Owner page/passed profile drives create/update/delete and upload. | MP-7 active author; inactive owner page offers switch, never auto-switches. | Manages inactive sibling. |
| Follows / Following feed | Database graph is profile-scoped; user-facing active consumer is a later slice. | MP-9 active follower and active feed. | Feed/graph merges sibling identity. |
| Favorites | Database rows exist but feature is outside V1. | Keep active-ready and private; no UI expansion. | Any future client would expose/mutate sibling rows. |
| Event notifications | Profile rows exist; email preference remains account-level. | Active row operations; delivery identifies contacted profile where relevant. | Sibling subscriptions are changed. |
| Signup completion — `app/api/auth/signup/route.ts` `updateProfile` | Service-role update filters by `profiles.user_id` and then calls `.single()`; safe only while one profile exists. | Before MP-10 cardinality opens, target the exact trigger-created profile by a deterministic returned/pinned profile ID or equally exact signup contract; never update every sibling or depend on one row per account. | At two profiles the query becomes multi-row ambiguous/fails, or an unsafe rewrite could modify siblings during signup completion. |
| Browser upload presign/finalize — `app/api/r2/presign`, `app/api/r2/finalize`, `lib/uploads/authorization.ts` | Token binds account + caller-supplied owned profile/resource and rechecks ownership at finalize. | MP-6 requires owner ID = current active profile at presign **and** finalize; resource must belong to it. | A valid session can mint/finalize uploads for inactive sibling. |
| Trusted CLI upload — `lib/uploads/trusted-upload-server.ts` and scripts | Service-role path verifies explicit account/profile ownership; no browser session active state exists. | Per the proposal's trusted-import boundary, keep it separate from browser active semantics; continue explicit approved owner/resource checks and account rate limit, and prove browser clients cannot reach it. | Forcing session-active semantics would break approved imports; failing to prove separation could leave a browser bypass. |

Read-only public listing/profile/Stream/category queries do not select a caller actor and are not active-authorization conversions. They remain regression surfaces for Package D safe-column and public visibility checks.

---

## 4. Deletion foundations — decision #20 / proposal neutral identity

### 4.1 Compatibility-safe groundwork now

The current live profile FKs for both conversation participants, message sender, and participant state are `ON DELETE CASCADE`. A future profile deletion would therefore destroy shared history. However, changing those FK actions to `SET NULL` now is **not** behavior-neutral: any privileged, dashboard, Auth-cascade, or other existing profile deletion would immediately create retained null-participant rows before the current UI, unread cleanup, uniqueness, and account-deletion semantics can handle them.

Slice MP-4 should therefore apply only the dormant groundwork that cannot create a null row by itself:

1. Make `conversations.buyer_profile_id`, `conversations.seller_profile_id`, and `messages.sender_profile_id` nullable, while retaining their current live FK delete actions. No existing value changes and current deletion behavior does not change.
2. Keep `conversation_participant_state.profile_id` non-null with its current cascade behavior; the future deleted participant state should disappear while survivor state remains.
3. Replace/adjust `conversations_buyer_seller_differ` only as needed so two present participants must be non-null and distinct for every ordinary write, while a future one-null retained row is structurally representable only after the held cutover. Package E must install a structural message-write guard that independently requires: buyer and seller both non-null and distinct; sender non-null; sender equals the active profile; and sender equals one of those two participants.
4. Make conversation/listing-seller, recipient-unhide, message-parent, policy, and RPC definitions null-safe. Package E itself must prevent ordinary null participant/sender creation and prevent unread or participant-state recreation for a missing side; this cannot be deferred to F/G.
5. Prepare—but **do not apply yet**—the exact guarded FK cutover from `ON DELETE CASCADE` to `ON DELETE SET NULL`, unread cleanup, retained-row uniqueness treatment, and neutral rendering consumption. The held design must specify that deletion of the second/final participant cannot leave a survivorless both-null conversation: single-profile deletion is already barred for the last profile, and later account-deletion orchestration must remove the deleting account's remaining conversation/content side while preserving only history needed by a genuinely surviving external participant.
6. Define the future neutral contract: a null counterpart or null historical sender means **Deleted profile**, with no handle, avatar, or link. No handle snapshot or generic tombstone profile is stored, so a later user of the freed handle cannot be linked to old history.
7. Verify Realtime and PostgREST contracts for the nullable schema now; re-verify actual retained-row behavior at the later FK cutover.

No existing row should be rewritten to null in this slice. Compatibility comes from dormant nullability plus strict current writes, not from enabling a new deletion consequence.

### 4.2 What remains impossible after this slice

Even after these foundations are applied:

- no profile deletion RPC, UI, route, or grant exists;
- no caller can delete a profile;
- the last-profile/account-deletion routing is not implemented;
- created-event transfer/blocker orchestration is not implemented;
- deletion summary and type-the-handle confirmation are not implemented;
- listings/posts/RSVPs/follows/favorites/notices/media cleanup is not orchestrated;
- active-session replacement after deletion is not implemented;
- no public object is deleted and no public-object deletion path is added;
- account deletion, Auth identity deletion, tombstone retention, and banned-account deletion remain later work;
- the current UI is not yet required to render an actual null participant because this slice creates none.

### 4.3 Compatibility fixture requirement

Disposable PostgreSQL verification must create synthetic two-profile/two-account conversations, then emulate one participant becoming null inside a rolled-back fixture. It must prove:

- survivor can read conversation and messages;
- deleted side cannot authorize anything;
- null sender history remains readable;
- both buyer and seller are non-null and distinct, sender is non-null, sender equals active profile, and sender is one of those participants for every new message;
- one-sided retained conversations are read-only; a survivor can read history and preserve independent hide/unhide state, but no unread/participant state is recreated for the null side;
- unread arrays cannot retain/restore the deleted identifier after the future cleanup helper is exercised;
- a new profile reusing the old handle/UUID-independent identity does not attach to history;
- current all-non-null rows behave exactly as before.

---

## 5. Explicit non-goals and invariants

- **Bans remain account-level.** No profile-only ban is introduced.
- **Rate limits remain account-level.** Post and upload limits are not multiplied by profile count.
- **`profiles_one_per_user_key` remains exact and in force.** No second profile can be created.
- **`create_additional_profile` remains unreachable by client roles.**
- **Package D ACLs are untouched.** No broad `profiles` column/table grant is added; owner IDs remain private.
- **No user-visible change.** No switcher, vendor selector, new-profile UI, deletion UI, posting-as hint, or inbox redesign.
- **The app at current HEAD keeps running unmodified.** Slice MP-4 is database foundation and cutover preparation only.
- Signup still creates exactly one personal profile.
- Existing public visibility and admin/moderation semantics stay unchanged.
- No live data deletion, migration of actor ownership, or public media deletion.
- No direct SQL package is authored until this plan and its live-evidence requests are independently approved.

---

## 6. Packaging proposal

Packages are serial and intentionally small. Each package gets its own preflight/apply/verify/rollback set, live-derived exact manifests, disposable PostgreSQL behavior suite, and owner-run sitting. A later package pins the exact after-state of every dependency.

### Package `slice-mp4-a` — read-only active-authority primitives

**Scope**

- Add the read-only active ID/equality primitives and active-unsuspended variant.
- Require policy consumers to use a statement-initplan shape such as `(select active_accessor())` where applicable, rather than invoking the accessor per candidate row; require supporting indexes for exact session/user/profile lookup and the guarded sole-profile fallback.
- Keep MP-3 get/switch/create helpers and private table unchanged.
- Encode the one-profile compatibility fallback guarded by the exact unique index.

**Dependency:** MP-3 live state and Package D privacy.

**Verify must prove**

- current one-profile authenticated session with/without an initialized state row resolves the sole profile;
- two synthetic sessions select independently;
- wrong session, stale row, wrong owner, zero/multiple profiles without state, anonymous, and malformed/missing session all return null/false;
- banned identity resolution preserves permitted read semantics while mutation composites deny;
- suspended behavior follows the matrix above;
- no function locks/writes, no lazy state mutation, exact ACLs, no public owner output;
- representative `EXPLAIN (ANALYZE, BUFFERS)` plus function/call-count evidence on realistic table sizes proves statement-level evaluation rather than one accessor/catalog lookup per candidate row.

**Rollback:** exact-after-state gate, then remove only new primitives. Fully reversible.

**Risk:** medium-high because every later policy depends on semantic correctness and performance.

**Blocks:** all later MP-4 packages; MP-5 active provider contract; MP-6–MP-9 mutation slices.

### Package `slice-mp4-b` — profile/listing ownership and private-row authorization

**Scope**

- Convert profile update and all four actor-sensitive listing policies to active authority.
- Remove/restrict authenticated direct profile INSERT authority so dropping the one-profile index later cannot expose a bypass; preserve the exact SECURITY DEFINER signup path and keep additional creation available only through the dedicated currently-unexposed RPC.
- Preserve moderation, status, suspension, and public listing reads.

**Verify must prove**

- active allow and inactive-sibling deny for profile edit, private listing read, listing create/update/draft delete;
- direct authenticated profile INSERT is denied before and after a simulated one-profile-index removal, while SECURITY DEFINER signup still creates exactly one profile and the additional-profile RPC remains unexposed;
- ban deny; suspended listing-create deny; stale/missing active deny;
- public active/sold visibility unchanged; admin-unpublished/private behavior unchanged;
- owner immutability, cap, one-profile index, signup, and Package D ACLs unchanged.

**Rollback:** restore exact live policy set/definitions from live-derived before pins. Fully reversible.

**Risk:** medium; wrong private-read conversion can hide current drafts or expose siblings.

**Blocks:** MP-5 active-provider prerequisite and MP-6 profile editing/listings/uploads.

### Package `slice-mp4-c` — per-profile social/event row policies

**Scope**

- Convert favorites, follows, RSVPs, notice posts/reactions, and event-notification policies.
- Preserve exact uniqueness/counting semantics and exact self-follow rule.

**Verify must prove**

- for every family: active allow, inactive sibling deny, foreign deny, missing/stale active deny, banned mutation deny;
- reads are active-only where private; public notice/RSVP/follow visibility unchanged;
- sibling follow is allowed, exact self-follow denied;
- sibling RSVP roles and per-profile reactions can coexist in disposable fixtures;
- favorites remain private/unexpanded; account notification preference unchanged.

**Rollback:** exact policy restoration; fully reversible.

**Risk:** medium, broad family count but shallow independent policies.

**Blocks:** MP-9; active favorites foundation for any later feature.

### Package `slice-mp4-d` — Wall post and reaction RPC authority

**Scope**

- Convert create/update/delete post and set/remove reaction RPCs to active authority.
- Preserve direct-DML fail-closed design, visibility helpers, reaction identity trigger, moderation, Hero behavior, image validation, and account rate limit.

**Verify must prove**

- active allow/inactive sibling/foreign/missing-active/banned denials for all five RPCs, with expected SQLSTATEs;
- public visible-post/reaction reads unchanged;
- exact one-reaction-per-profile mechanics preserved; siblings can independently react in disposable fixtures;
- account limiter cannot be bypassed by profile switching;
- direct reaction DML remains denied and trigger identities immutable.

**Rollback:** exact function/ACL restoration gated on after-state. Fully reversible; test-created disposable data rolled back.

**Risk:** high because SECURITY DEFINER RPCs combine identity, content, media, moderation, and rate limiting.

**Blocks:** MP-7.

### Package `slice-mp4-e` — dormant conversation nullability foundation

**Scope**

- Make participant/sender columns nullable while retaining current live FK delete actions; adjust the differ constraint and install null-safe conversation/message triggers.
- Install inside E—not deferred to F/G—structural guards that reject ordinary conversation/message writes unless buyer and seller are present/distinct and sender is the active participant, and that prevent unread/participant-state recreation for a missing side.
- Prepare but hold the `SET NULL`, unread cleanup, retained uniqueness, and both-deleted cutover artifacts.
- Add no deletion callable path and rewrite no live participant value.

**Verify must prove**

- exact constraint/index/trigger/ACL manifests, including unchanged live FK delete actions and the `private.account_session_active_profiles` profile-owner FK/cascade;
- complete before/after null and row counts collected in one lock-protected sitting that excludes concurrent profile/conversation/message writes; no newly introduced nulls;
- current conversation insert/listing-seller/message-parent behavior unchanged; ordinary null writes, inactive senders, nonparticipant senders, and missing-side unread/state writes denied;
- disposable future-shape fixtures prove the proposed later retained-conversation matrix in §4.3 without claiming that deletion behavior is live;
- Realtime publication/replica identity remain reviewed and Package D privacy is intact.

**Rollback:** restore NOT NULL only if the exact after-state gate proves zero null participant/sender values and no dependent definition drift. The applied nullability groundwork is reversible. The separately held future `SET NULL` cutover becomes honestly irreversible once any real deletion creates retained null rows.

**Risk:** high but behavior-neutral if live delete actions remain unchanged; the held cutover is very high risk.

**Blocks:** MP-8 messaging null handling and the later coordinated FK cutover required by MP-12/MP-13 deletion.

### Package `slice-mp4-f` — conversation policies and participant-state reads

**Scope**

- Convert conversation create/read, message read/insert, and participant-state read policies to active authority and nullable-survivor semantics.
- Add same-account contact denial at the database boundary without exposing sibling linkage.

**Verify must prove**

- active participant reads only its inbox; inactive sibling and foreign actor see nothing;
- active buyer creates valid conversation; inactive/foreign/same-account/deleted-target/banned/missing-active paths deny;
- survivor reads retained history; deleted side and nonparticipant deny;
- message insert requires active sender and two present participants;
- hide state applies only to active participant;
- neutral same-account failure contains no owner ID/sibling details.

**Rollback:** restore exact policy set only while package E schema remains; rollback ordering is F before E. Fully reversible at policy level.

**Risk:** very high; confidentiality boundary for private messages.

**Blocks:** MP-8 and deletion slices.

### Package `slice-mp4-g` — conversation/unread/contact RPCs and trigger completion

**Scope**

- Convert append/remove unread, hide/unhide, and find-and-unhide to active semantics.
- Finalize recipient-unhide and parent-summary triggers for nullable counterpart behavior.
- Preserve account-level ban and service-role ACL intent.

**Verify must prove**

- per-RPC active allow plus inactive sibling, foreign, same-account where relevant, missing/stale active, banned, deleted-counterpart, and malformed-target denials;
- unread marker can only be changed for the correct active/other participant;
- sender hidden state remains unchanged when recipient is unhidden;
- one-sided retained conversations are read-only and cannot recreate deleted participant state;
- exact ACLs prevent direct trigger-function invocation by clients;
- concurrent message/unread/hide behavior does not cross profile identity.

**Rollback:** exact functions/ACLs/triggers restored; order G before F/E. Reversible while package E has not been consumed by real deletion.

**Risk:** very high due shared mutable state, SECURITY DEFINER functions, and concurrency.

**Blocks:** MP-8 and message-email work that depends on exact contacted profile.

### Package `slice-mp4-h` — upload active-authorization contract (database preparation only)

**Scope**

- Add/review the minimum authenticated active-profile boolean contract needed by browser presign/finalize.
- Do not modify TypeScript routes or trusted CLI behavior in this database slice.
- Pin existing upload rate-limit function, browser helper ACLs, and Package D owner privacy.

**Verify must prove**

- browser-role helper: active allow; inactive sibling/foreign/missing-active/banned deny; listing/post resource owner equality is expressible without owner-ID exposure;
- no service-role/trusted CLI regression;
- account-level upload limiter unchanged;
- no public key, token, quarantine, promotion, or cleanup behavior changes.

**Rollback:** remove only new contract if unused; fully reversible.

**Risk:** medium. Real browser enforcement remains an MP-6 app cutover and must recheck both presign and finalize.

**Blocks:** MP-6.

### Recommended run order

`mp4-a → mp4-b → mp4-c → mp4-d → mp4-e → mp4-f → mp4-g → mp4-h`

The high-risk messaging work is split into schema, policy, and RPC/trigger sittings. No package should be combined merely to reduce file count.

---

## 7. Live-evidence request list

### 7.1 Rules for every request

Before authoring each package, the wingman must query the live catalog and return machine-copyable evidence. Psy must pin exactly that evidence after independent review. Never infer a pin from an old migration or reconstructed schema.

Every function/policy/constraint/index/trigger fingerprint must use the MP-3 environment-neutral standards:

- normalize LF/CRLF and all whitespace classes in function bodies;
- canonicalize function identity arguments, result types, and settings independent of caller `search_path`;
- explode ACLs into sorted `(grantee, privilege, grantable, grantor where relevant)` sets; never hash raw `aclitem[]` text or PG17 `MAINTAIN` rendering;
- strip irrelevant `public.`/`private.` qualification from normalized constraint, trigger, policy, and index expressions where the canonical formula specifies it;
- run render-invariance probes under default and `search_path=pg_catalog`;
- include owner, language, volatility, security-definer, strictness, parallel/leakproof/defaults, complete settings, and complete ACLs—not body hash alone.

Every named function request must include a complete overload inventory in its schema, not only the expected signature, so an unexpected overload cannot escape the guard.

Completeness-sensitive live aggregates—row/null/orphan/violation counts—must record the executing role, that role's `rolsuper`/`rolbypassrls`, current `row_security` setting, and the exact proof that the read path is complete. If owner/BYPASSRLS or an equivalently proven complete service path is unavailable, report `UNPROVEN`; never pin a potentially RLS-filtered zero.

### 7.2 Package-specific evidence

**Before `mp4-a`:**

- exact `private.account_session_active_profiles` columns/defaults/nullability, PK/unique/FKs/checks/indexes, owner, RLS/force-RLS, policies, grants and publication status;
- exact definitions/ACLs/settings of `private.current_auth_session_id`, `get_active_profile`, `switch_active_profile`, `create_additional_profile`, `current_user_owns_profile`, `current_user_owns_unsuspended_profile`, `current_user_is_banned`;
- exact `profiles_one_per_user_key` anatomy as a bare unique index, `idx_profiles_user_id`, profile owner FK, profile cap/owner triggers/functions;
- relevant role attributes (`BYPASSRLS`) and table owners required to reason about SECURITY DEFINER access;
- non-secret supported-token evidence for session-claim presence, UUID/type validity, rotation/logout lifecycle, and malformed/missing-claim behavior across the current browser/server flows.

**Before `mp4-b`:**

- all live `profiles` and `listings` policy texts/roles/commands/permissiveness;
- complete `profiles`/`listings` grants including column ACLs, owners, RLS/FORCE RLS;
- listing enum/status/moderation constraints, indexes, FKs and trigger definitions;
- exact signup/profile mutation functions and profile triggers so compatibility pins are live-derived;
- exact table/column INSERT privileges, direct-insert policy/grant interaction, default privileges, and complete SECURITY DEFINER signup trigger/function execution path, including proof signup survives while authenticated direct INSERT is denied.

**Before `mp4-c`:**

- complete policy manifests for `favorites`, `follows`, `vendor_events`, `notice_posts`, `notice_reactions`, `event_notifications`;
- every table's columns/nullability/defaults, PK/unique/check/FK/index definitions, owners/RLS/ACLs;
- exact self-follow enforcement object and allowed Notice category/reaction values;
- public-read policies/helpers and Realtime membership for notices.

**Before `mp4-d`:**

- exact definitions/settings/ACLs of `create_post`, `update_post`, `delete_own_post`, `set_post_reaction`, `remove_post_reaction`, all post visibility/image/rate-limit helpers, admin post functions, and reaction/post triggers;
- complete `posts`, `post_reactions`, moderation-audit schema/policies/constraints/indexes/ACLs;
- live account rate-limit function/table anatomy and role attributes.

**Before `mp4-e`:**

- exact columns/nullability/defaults for `conversations`, `messages`, `conversation_participant_state`, and the relevant `private.account_session_active_profiles` profile reference;
- complete FK/check/unique/index manifests, including delete actions, validation/deferrability and backing-index anatomy; explicitly pin the already-live `conversations.listing_id` nullability and listing FK `ON DELETE SET NULL` state rather than treating it as new scope;
- exact bodies/settings/ACLs and trigger definitions for listing-seller enforcement, recipient unhide, conversation last-message update, and every trigger on the three tables;
- live null counts, orphan counts, participant equality violations, unread UUID validity/duplication, participant-state completeness, and conversations/messages row counts;
- Realtime publication, replica identity, logical replication settings relevant to these tables;
- dependent views/functions/policies/PostgREST relationships that reference participant/sender columns;
- exact lock plan and the role/transaction used to collect before/after null and row counts while excluding concurrent profile/conversation/message writes.

**Before `mp4-f`:**

- all live policies on `conversations`, `messages`, and `conversation_participant_state`, after `mp4-e`;
- exact table ACLs/RLS/FORCE RLS/owners and relevant profile visibility/ownership helpers;
- live evidence sufficient to construct non-destructive fixture candidates; unavailable fixtures must be reported `UNPROVEN`, never invented.

**Before `mp4-g`:**

- exact after-`mp4-f` definitions/settings/ACLs for five conversation RPCs and both message triggers/functions;
- all dependent triggers, policies, indexes, and participant-state constraints;
- evidence on service-role usage/callers so ACLs are not narrowed by assumption;
- concurrency-relevant uniqueness and lock behavior.

**Before `mp4-h`:**

- exact active/ownership/ban/rate-limit helper definitions and ACLs after prior packages;
- any database functions called by browser upload authorization and trusted CLI;
- table/column ACLs needed for resource-owner checks on profiles/listings/posts/events;
- no secrets, tokens, R2 credentials, or environment values—catalog contracts only.

---

## 8. Open questions for Turgay

### Product-level questions

**None.** The authoritative proposal states that all Multi-Profile product questions are resolved. Slice MP-4 must not reopen account-level bans, per-profile interactions, trusted import semantics, neutral deleted identity, handle reuse, or deletion retention.

### Technical evidence/design gates

#### Gate 1. Standalone suspension invariant

**Evidence needed:** determine whether any live `profiles.is_suspended=true` row can exist while its owning `public.users.banned_at` is null and classify any divergence.

**Recommendation:** preserve current family semantics—listing creation keeps its existing unsuspended requirement; other writes keep the account-ban rule—and treat unexplained divergence as an invariant problem, not a new profile-ban product.

**Consequence:** no accidental product change.

#### Gate 2. Existing listing-linked conversation behavior

**Evidence needed:** pin the already-live `conversations.listing_id` nullability and `ON DELETE SET NULL` FK, uniqueness, trigger behavior, and current UI assumptions.

**Recommendation:** treat absent listing context as an existing structural possibility and carry it into the later messaging client specification; never delete shared history because listing context vanished.

**Consequence:** package E guards/preserves existing behavior rather than presenting it as a new decision.

#### Gate 3. Trusted non-browser upload proof

**Resolved behavior:** per the proposal, trusted service/Telegram imports use explicit approved profile/resource ownership rather than browser session-active semantics.

**Evidence needed:** prove that entry point is unreachable to browser clients and enumerate every caller/credential boundary; no credentials enter this document.

**Consequence:** MP-6 can preserve the trusted path without creating an inactive-sibling browser bypass.

#### Gate 4. Session-claim compatibility

**Evidence needed:** prove supported authenticated staging/live request tokens carry the existing MP-3 session claim, including presence/type, rotation/logout lifecycle, and malformed/missing behavior.

**Recommendation:** require a valid session ID and fail closed without it. Do not fall back merely on `auth.uid()`.

**Consequence:** if a supported token flow lacks the claim, land the MP-5 bootstrap/provider before activating dependent policies rather than weakening session isolation.

#### Gate 5. Retained-conversation cutover specification

**Evidence needed before authoring or applying participant/sender `ON DELETE SET NULL`:** exact unread cleanup, nullable uniqueness/find-or-create, second/final-participant cleanup, sender-null history, hide/unhide, account deletion, and every current privileged/Auth profile-deletion path.

**Recommendation:** apply dormant nullability and independent null-write guards in package E, but hold profile FK delete-action changes until the messaging client can render nulls and deletion orchestration can atomically enforce the fixed neutral-history decisions.

**Consequence:** Slice MP-4 lays compatibility foundations without silently enabling incomplete deletion behavior.

---

## 9. Review gates before SQL authoring

1. Turgay confirms or amends the five technical gates above; no fixed product decision is reopened.
2. Independent review confirms the actor inventory is complete against current HEAD and the live-baseline manifest.
3. Wingman supplies the `mp4-a` live-evidence bundle only; later evidence is requested just before each package, not precomputed and allowed to stale.
4. Psy drafts `mp4-a` preflight/apply/verify/rollback from live evidence, runs disposable PostgreSQL and static render-invariance tests, commits locally, and waits for independent review/push approval.
5. Packages remain serial. No later package is authored against an unreviewed predecessor.

Until those gates pass, Slice MP-4 remains a planning decision, not an implementation claim.
