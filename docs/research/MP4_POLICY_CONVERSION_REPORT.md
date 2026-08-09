# MP-4 Policy & Function Conversion Report

**Date:** 2026-08-09
**Scope:** Authorization replacement only; no database was touched outside a disposable local PostgreSQL 16 fixture.
**Package status:** **VALIDATED — owner-run only.** The package preflight/apply/verify/rollback cycle and the reconciled Chunk 11 wall verifier pass on the same disposable PostgreSQL 16 post-MP-4 state.

## 1. Verdict

- **Policy semantic-equivalence STOP findings:** none. An independent reconstruction found 24 direct-read policies in total: the 22 converted cross-table policies plus the two intentionally scoped profile-row self-policies.
- **Function semantic-equivalence STOP findings:** none. All 10 caller-authorization functions now ask ownership through Package B without changing callers or allowed operations.
- **Verifier reconciliation:** owner-approved. `chunk-11-wall-data-model-verify.sql` now checks the post-MP-4 follows policies structurally with whitespace normalization instead of hard-coded hashes. No Wall check was removed or weakened.
- **Final STOP findings:** none.

## 2. Artifacts authored

| Artifact | Purpose |
|---|---|
| `supabase/chunks/mp4-policy-conversion-preflight.sql` | Read-only, one-row `GO`/`STOP`/`UNPROVEN` summary; exact normalized policy/function manifests; Package A/B/C checks; fixture reachability. |
| `supabase/chunks/mp4-policy-conversion-apply.sql` | Transactional old-definition guards, helper/policy/function conversion, ACL reassertion, and exact postconditions. |
| `supabase/chunks/mp4-policy-conversion-verify.sql` | Exact post-apply catalog guard plus transient allow/deny behavior matrix; always ends in `ROLLBACK`. |
| `supabase/chunks/mp4-policy-conversion-rollback.sql` | Exact new-state guard followed by restoration of every original policy/function definition and ACL. |
| `supabase/chunks/chunk-11-wall-data-model-verify.sql` | Living-verifier reconciliation for the three follows policy definitions; every other Wall assertion remains unchanged. |

The four MP-4 scripts use no raw `md5(prosrc)` or raw-text function fingerprint. Function guards compare complete whitespace-normalized bodies plus identity arguments, result type/set behavior, language, owner, volatility, `SECURITY DEFINER`, strictness, leakproof/parallel flags, argument defaults, complete configuration arrays, and complete ACL/grantability. Package B's ownership helper and MP-4's additive helper receive the same exact fail-closed treatment. Policy expressions are compared as complete catalog-normalized expressions plus table, name, command, permissiveness, roles, `USING`, and `WITH CHECK`. The Chunk 11 verifier's unrelated pre-existing `clear_hero_on_author_ban()` body check remains unchanged; only its three follows-policy expectations were reconciled.

## 3. Converted policies

The source manifest contains **22 policies**. The post-apply manifest contains 23 definitions because the old mixed public/owner listing SELECT policy is split into one public visibility policy and one authenticated ownership policy. The OR-union of the two policies preserves the old result.

Four source policies run `TO PUBLIC` while their owner predicate is false for anonymous callers: listing SELECT, message SELECT, favorite SELECT, and event-notification SELECT. Package B's ownership helper is intentionally not executable by `anon`, so blindly substituting it would turn anonymous reads into permission errors. MP-4 therefore splits the mixed listing policy and narrows the three ownership-only policies to `authenticated`; anonymous and authenticated row visibility remains unchanged without broadening the helper ACL.

| # | Table / policy | Before | After |
|---:|---|---|---|
| 1 | `listings` / `Active and sold listings are publicly readable` | Public sees active/sold; authenticated owners additionally see their own private rows through a direct `profiles.user_id` subquery. | Public active/sold branch remains under the same name; owner-only branch moves to authenticated policy `Owners can read own private listings` using `current_user_owns_profile(profile_id)`. |
| 2 | `listings` / `Unbanned owners create active listings` | Direct owner lookup plus `profiles.is_suspended = false`. | `current_user_owns_unsuspended_profile(profile_id)`, which composes Package B ownership with a private suspension read; ban/status/moderation checks unchanged. |
| 3 | `listings` / `Unbanned owners update own listings` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; every other check unchanged. |
| 4 | `listings` / `Unbanned owners delete own draft listings` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; draft/moderation checks unchanged. |
| 5 | `conversations` / `Unbanned buyers create conversations` | Direct buyer-profile owner lookup. | `current_user_owns_profile(buyer_profile_id)`; seller/listing and ban checks unchanged. |
| 6 | `conversations` / `participants view visible conversations` | Direct buyer/seller owner lookups and direct owner lookup for hidden participant state. | Buyer, seller, and hidden-state ownership all use `current_user_owns_profile`. |
| 7 | `messages` / `Unbanned participants send messages` | Direct sender-profile owner lookup. | `current_user_owns_profile(sender_profile_id)`; participant and ban checks unchanged. |
| 8 | `messages` / `participants view messages` | Public-role policy whose direct owner predicates are false for anonymous callers. | Authenticated-role policy using owner helpers for buyer/seller; anonymous still sees no rows, authenticated semantics unchanged. |
| 9 | `conversation_participant_state` / `Participants read own conversation state` | Direct profile-owner lookup. | `current_user_owns_profile(profile_id)`. |
| 10 | `vendor_events` / `Unbanned users add own RSVP` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 11 | `vendor_events` / `Unbanned users remove own RSVP` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 12 | `notice_posts` / `Unbanned users create own notice posts` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 13 | `notice_posts` / `Unbanned users delete own notice posts` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 14 | `notice_reactions` / `Unbanned users add own reactions` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 15 | `notice_reactions` / `Unbanned users remove own reactions` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 16 | `favorites` / `Users can read their own favorites` | Public-role policy whose direct owner predicate is false for anonymous callers. | Authenticated-role policy using `current_user_owns_profile(profile_id)`; effective caller behavior unchanged. |
| 17 | `favorites` / `Unbanned users manage own favorites` | Direct owner lookup in both `USING` and `WITH CHECK`. | Both expressions use `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 18 | `follows` / `Unbanned users follow from own profile` | Direct follower-profile owner lookup. | `current_user_owns_profile(follower_profile_id)`; self-follow and ban checks unchanged. |
| 19 | `follows` / `Unbanned users unfollow from own profile` | Direct follower-profile owner lookup. | `current_user_owns_profile(follower_profile_id)`; ban check unchanged. |
| 20 | `event_notifications` / `Unbanned users subscribe to event notifications` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 21 | `event_notifications` / `Unbanned users unsubscribe from event notifications` | Direct owner lookup. | `current_user_owns_profile(profile_id)`; ban check unchanged. |
| 22 | `event_notifications` / `Users can manage their own event notifications` | Public-role policy whose direct owner predicate is false for anonymous callers. | Authenticated-role policy using `current_user_owns_profile(profile_id)`; effective caller behavior unchanged. |

## 4. Converted functions

The package converts **10 existing functions** and adds one narrow helper.

| Function | Before | After |
|---|---|---|
| `append_unread_for(uuid,text)` | Finds the caller's participant profile through `profiles.user_id` plus `LIMIT 1`. | Checks buyer then seller with `current_user_owns_profile`; unread behavior and ACL unchanged. |
| `remove_unread_for(uuid,text)` | Same direct participant lookup. | Same helper-based participant resolution; unread behavior and ACL unchanged. |
| `hide_conversation(uuid)` | Direct participant lookup. | Helper-based buyer/seller resolution; upsert behavior unchanged. |
| `unhide_conversation(uuid)` | Direct participant lookup. | Helper-based buyer/seller resolution; update behavior unchanged. |
| `find_and_unhide_conversation(uuid,uuid)` | Reads the caller profile directly with `LIMIT 1`. | Reads Package B's set-returning `get_my_profiles()`; current one-profile behavior is identical and cardinality above one fails closed pending active-profile selection. |
| `create_post(uuid,text,text[],boolean)` | Direct target-profile owner lookup. | `current_user_owns_profile(target_profile_id)`; all validation/rate/ban behavior unchanged. |
| `update_post(uuid,text,text[],boolean)` | Loads author then directly compares author profile owner. | Loads author then calls `current_user_owns_profile(author_profile_id)`; all mutation behavior unchanged. |
| `delete_own_post(uuid)` | Atomic DELETE joined to `profiles.user_id`. | Atomic DELETE predicate calls `current_user_owns_profile(post.profile_id)`. |
| `set_post_reaction(uuid,uuid,text)` | Direct target-profile owner lookup. | `current_user_owns_profile(target_profile_id)`; reaction and visibility checks unchanged. |
| `remove_post_reaction(uuid,uuid)` | Atomic DELETE joined to `profiles.user_id`. | Atomic DELETE predicate calls `current_user_owns_profile(reaction.profile_id)`. |

### Additive helper

`current_user_owns_unsuspended_profile(uuid)` is `STABLE`, `SECURITY DEFINER`, owned by `postgres`, has `search_path = ''`, returns only a boolean, and is executable only by `authenticated`. It preserves the listing-insert policy's independent profile-suspension condition without exposing `is_suspended` or `user_id` after Package D.

The proposal's later active-profile authorization is deliberately not introduced here. Replacing “any caller-owned profile” with “the active profile” would narrow authorization and violate this package's semantics-identical requirement. The current one-profile uniqueness gate makes ownership-only conversion the exact Package-D compatibility bridge; active-profile behavior remains a later separately reviewed migration.

## 5. Scoped out direct owner reads

These are deliberate trusted boundaries or deferred scope, not caller-side authorization consumers:

| Object/path | Reason |
|---|---|
| `get_my_profiles`, `current_user_owns_profile`, `admin_get_profile_account` | Package B's hardened private boundary. These functions must internally map authenticated accounts to profiles after broad `user_id` readability is revoked. |
| `handle_new_user` | Trusted auth trigger that creates the initial profile. |
| `admin_ban_user`, `admin_unban_user` | Trusted admin account-level moderation; target account identity is deliberate. |
| `profile_owner_is_banned` | Hardened boolean boundary for public visibility; returns no owner identifier. |
| `clear_hero_on_author_ban` | Trusted internal ban trigger that acts on the banned account, not the current caller's profile. |
| `post_images_belong_to_profile` | Existing account-UUID media-path validation is accepted until MP-6. |
| Profile table's own INSERT/UPDATE policies | These compare the row's own `user_id`; they are not cross-table reads and do not depend on broad caller SELECT privilege. |
| Trusted signup/service-role application path | Explicitly retained by Package C/plan scope. |
| Post and post-reaction visibility RLS policies | Already delegate to hardened visibility helpers and do not directly read `profiles.user_id`. |

No Package D ACL, column, FK, delete behavior, one-profile constraint, or schema cutover is included.

## 6. Preflight behavior

The preflight returns one row and sets:

- `STOP` for Package A/B drift, exact source-definition drift, unexpected direct-owner consumers, or pre-existing MP-4 helper state;
- `UNPROVEN` when required behavioral fixtures are absent;
- `GO` only when the exact old manifest, relevant baseline, Package B lane, Package C evidence, and fixture classes are present.

The one row contains the exact current policy and function definitions as JSON manifests without returning application row data.

Package C evidence is frozen to approved/pushed commit `210941e98839f5320eec8d0edff97ae00dab8b9c`; the SQL cannot independently inspect a deployed application revision.

## 7. Verification and fixture reachability

### Disposable PostgreSQL 16 smoke actually run

The local fixture used the approved profile enum (`personal`, `artist`, `label`, `festival`), approved listing enums, the current one-profile uniqueness gate, Package B's exact ownership-helper body/metadata/ACL, 22 old cross-table policies, 10 old function definitions, two unbanned owners, one banned owner, and event/listing/post fixtures.

Results:

| Step | Result |
|---|---|
| Static test before artifacts | RED: missing package files, as intended. |
| MP-4 preflight | `GO`; Package A/B/C, policy manifest, function manifest, and fixtures all `GO`. |
| MP-4 apply | PASS, including old-state guards and exact postconditions. |
| Updated Chunk 11 verifier on pre-MP-4 state | Correctly failed its new follows-policy expectations: Chunk 11A `false`, overall `false`; Chunk 11B/11C remained `true`. |
| MP-4 verify on post-MP-4 state | `GO`: 16 policy/function families had actual allow+deny checks `GO`; 0 `UNPROVEN`; 0 `STOP`. All five conversation RPCs and all five Wall mutation RPCs were exercised. |
| Updated Chunk 11 verifier on the same post-MP-4 state | PASS: Chunk 11A, 11B, 11C, and overall all `true`. |
| Deliberately tampered post-MP-4 follows INSERT policy | Correctly failed: Chunk 11A `false`, overall `false`; unaffected Chunk 11B/11C checks remained `true`. |
| Package B helper granted to `anon` in scratch | Preflight correctly returned `STOP`; revoking the drift restored `GO`. |
| MP-4 helper granted to `anon` in scratch | Both verify and rollback guards correctly failed before behavior execution or helper removal. |
| Converted `create_post` changed to `STRICT` in scratch | Verify's complete function manifest correctly failed; restoring `CALLED ON NULL INPUT` restored verify `GO`. |
| MP-4 rollback | PASS, including exact new-state guard and exact old-state restoration. |
| Post-rollback preflight | `GO` again. |

### Fixture boundary

The baseline still enforces `profiles_one_per_user_key`, so a true owned-but-inactive sibling branch cannot exist in this fixture. That later active-profile behavior is outside this semantics-identical Package-D compatibility conversion. Every branch in the current MP-4 authorization scope is proven.

## 8. Exact owner run order

1. Run `supabase/chunks/mp4-policy-conversion-preflight.sql`.
2. Continue only if the one-row result is `GO`. Review every exact manifest and any `UNPROVEN` fixture item.
3. Run `supabase/chunks/mp4-policy-conversion-apply.sql` once.
4. Run `supabase/chunks/mp4-policy-conversion-verify.sql`.
5. Require `overall_status = 'GO'`, `proven_family_count = 16`, and `unproven_family_count = 0`.
6. Run the reconciled `supabase/chunks/chunk-11-wall-data-model-verify.sql`; require Chunk 11A/11B/11C and overall all `true`.
7. Run `supabase/chunks/chunk-11d-post-visibility-verify.sql` unchanged when performing the complete Wall regression round.
8. Proceed toward Package D only after all required results are `GO`/`true`.
9. If apply succeeds but verification fails, inspect the failure first; run `supabase/chunks/mp4-policy-conversion-rollback.sql` only while the database still matches the exact MP-4 post-apply manifest.
10. Re-run the MP-4 preflight after rollback; it must return to the exact old-manifest `GO` state.

## 9. Publication state

The package, report, and living-verifier reconciliation are published together. A post-publication independent review's fail-closed guard findings were corrected and revalidated in a follow-up commit; Git is authoritative for both hashes.
