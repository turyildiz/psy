# Multi-Profile gates

**Status:** Authoritative gate checklist for enabling the Umbrella Model
**Authority boundary:** Product decisions remain binding in [`MULTI_PROFILE_PROPOSAL.md`](MULTI_PROFILE_PROPOSAL.md). Recorded execution truth remains solely in [`SLICE_MP4_EXECUTION_RECORD.md`](SLICE_MP4_EXECUTION_RECORD.md). This checklist defines the evidence that must exist before each irreversible or user-visible boundary.

A gate is not satisfied by authored code, repository SQL, a passing static test, or an inferred live state. Every item below requires the named acceptance evidence. Missing, filtered, stale, or contradictory evidence is `UNPROVEN` and stops the boundary.

## Gate 1 — before the first second profile can be created

The irreversible boundary is the first successful creation of a second profile row, not the drop of `profiles_one_per_user_key`. Dropping the index may be operationally reversible while every account still has one profile; after a second row exists, restoring one-profile uniqueness would require destructive consolidation. Additional-profile RPC access and every UI or claim path that can create that row must remain disabled until all Gate 1 items pass and Turgay explicitly approves the first controlled second-profile creation.

### 1. Public media and R2 namespaces are profile-scoped

Required state:

- Migrate every referenced public object and database URL from an auth `user_id` namespace to its owning `profile_id` namespace across avatars, headers, listing images, Wall post images, and festival/event flyers.
- Change public-key generation, signed-intent validation, promotion, cleanup-candidate derivation, reference scanning, and every URL-validation helper to the profile namespace. This includes the database post-image validator and any avatar, header, listing, post, festival, or event helper that parses or constructs a public URL.
- Do not accept a temporary dual-format validator that lets one sibling attach media belonging to another sibling.
- Leave replaced public objects under the established report-only orphan process; this gate does not authorize public-object deletion.

Why this blocks the first second row: current public `avatar_url`, `header_url`, and `listings.images` values embed `user_id`. The account UUID is publicly recoverable from those URLs. Once a second profile publishes similarly namespaced media, sibling ownership can be observed and cannot be made unobserved by rollback.

Acceptance evidence:

1. A fresh, owner-run read-only manifest maps every referenced avatar, header, listing, post, festival, and event object to exactly one owning profile, with zero unmapped or multiply mapped references.
2. Reviewed create-only copy and guarded reference-switch records prove byte, content-type, size, destination uniqueness, and exact old/new reference counts.
3. Repository inventory proves every final-key constructor, validator, promotion path, cleanup/reference scanner, and database URL helper uses `profile_id`, not `user_id`.
4. Fresh database/API checks prove no value in public profile-media fields, `listings.images`, post images, or event/festival image fields contains any value present in `profiles.user_id`.
5. Anonymous DOM/network checks across all affected public surfaces reveal no auth-user UUID in public URLs or payloads.

### 2. Messaging uses exact active-profile authority

Required state:

- Complete MP4-E, MP4-F, and MP4-G for `conversations`, `messages`, and `conversation_participant_state`.
- Convert conversation and message reads/writes, participant-state reads, hide/unhide, unread add/remove, and find-and-unhide behavior from any-owned-profile authority to exact equality with the current session's active profile.
- Remove every first-branch-wins actor choice. If both sibling branches could match, the operation must fail closed rather than prefer buyer or seller.
- Block same-account contact at the policy layer before any conversation or message row is created. RPC and UI handling provide only the neutral owner-facing error presentation, **you can't contact your own profile**; they are not the security boundary and must reveal no owner-link detail to another caller.

Acceptance evidence:

1. Fresh owner-hosted preflight/apply-rerun/verify records for MP4-E/F/G match exact reviewed policy, function, trigger, constraint, ACL, and publication manifests.
2. Direct authenticated tests prove profile A cannot read, send, hide, unhide, clear unread state, or find/open profile B's conversations after a switch, even when A and B share an account.
3. A sibling-contact test proves the policy rejects the write with zero conversation/message/email side effects, while the approved UI presents only the neutral error.
4. Ambiguity fixtures prove no RPC chooses the first owned participant branch.

### 3. Signup completion targets one exact trigger-created profile

Required state:

- Signup completion updates the exact profile ID created for that signup. It must never use `.eq("user_id", userId).single()` or any account-wide profile update.
- Reserved-handle selection and consumption are part of the same atomic signup/claim outcome. A reservation must not be consumed and then silently overwritten by the route.
- The trigger and route must agree on the display-name metadata contract rather than relying on a broad post-trigger repair.

Acceptance evidence:

1. Static and runtime tests prove completion can update only the returned/signup-bound profile ID and cannot modify an existing sibling row.
2. Fresh signup fixtures cover ordinary, reserved-handle, duplicate, retry, and cleanup paths; each leaves exactly the intended profile and reservation state.
3. Failure injection proves no consumed reservation or partially rewritten profile remains after a failed completion.

### 4. Active-profile bootstrap is proven without the sole-profile fallback

Required state:

- The active-profile provider/bootstrap runs for every real authenticated session, calls the trusted active-profile contract, and creates or reads its row in `private.account_session_active_profiles`.
- Authorization remains functional when the sole-profile compatibility fallback is unavailable. Missing, malformed, stale, or mismatched session state fails closed and enters the explicit bootstrap/recovery path; it never falls back to an account-global selection.
- Before MP4-F applies, test an authenticated Realtime subscriber whose JWT/session-active state is authoritative. PostgREST success alone does not prove Realtime can evaluate active-profile RLS.

Acceptance evidence:

1. Real authenticated browser sessions on two sessions/devices create or read distinct state rows and retain correct authorization with the sole-profile fallback disabled in an owner-approved controlled fixture.
2. The owner measurement below accounts for active auth sessions versus active-profile state rows, with every gap explained and resolved before the gate closes.
3. Missing/malformed session-claim and stale-row tests fail closed without an identity-bearing write or cross-profile read.
4. An authenticated Realtime test proves the active profile receives only its allowed conversation/message events, receives no sibling events, and a switch removes the old subscription before the new one becomes authoritative.

### 5. Browser uploads are bound at presign and finalize

Required state:

- MP4-H is limited to browser-upload active authorization. It must bind the acting profile and current switch generation at both presign and finalize.
- Finalize independently rechecks authentication, account ban, ownership, exact active-profile equality, selection generation, purpose, resource ownership, object index, MIME/size/signature, and expiry. A successful presign is never sufficient after a switch.
- Trusted external event/flyer imports retain their explicit approved-owner contract and must not pretend to use browser session-active semantics.
- The profile switcher remains feature-flagged and unavailable to users until this behavior is proven.

Acceptance evidence:

1. Tests prove active-profile uploads pass for every browser purpose and inactive, cross-account, stale-generation, replayed, or switched-mid-upload intents fail at both relevant boundaries.
2. A real switch-between-presign-and-finalize staging test leaves no promoted public object or database reference for the inactive profile.
3. Network evidence shows both endpoints receive and validate the approved identity/generation contract without exposing account-owner IDs.

### 6. Switching invalidates every identity-bound cache and request

Required state:

- Namespace and validate `sessionStorage["psy_auth"]` by auth user/session and active profile; clear it on sign-out, account replacement, and invalid ownership.
- Extend `lib/auth/ui-transition.ts` identity from auth user only to auth user, active profile, and switch generation.
- On switch, synchronously reset Header identity/counts, inbox rows, selected thread, messages, drafts/composer, unread state, Wall/reaction state, upload/form state, and Realtime subscriptions. Late requests and callbacks from the previous generation must be rejected.
- Dirty listing, post, and profile forms require **Stay** or **Discard and switch**; no pending operation may publish under either identity without that resolution.

Acceptance evidence:

1. A multi-tab staging matrix proves a switch changes only the intended authenticated session and follows the approved cross-tab behavior for tabs sharing it.
2. Forced late-response and stale-Realtime fixtures prove old-profile data cannot repopulate any new-profile surface.
3. A browser test proves Header, inbox/thread/draft/unread, Wall/reactions, and uploads/forms reset within the approved transition, with no stale identity briefly actionable.
4. Dirty-form tests prove **Stay** preserves the current identity/work and **Discard and switch** clears it before the new identity becomes actionable.

## Gate 2 — before profile deletion ships

Gate 2 is separate from Gate 1. Messaging active authority must be safe before a second profile row exists, but retained-conversation deletion semantics need not delay cardinality if profile deletion remains impossible.

Required state:

- Complete and verify the retained-conversation model: nullable/deleted participant and sender semantics, constraints, find-or-create behavior, unread cleanup, participant state, triggers, RLS, Realtime behavior, and account-deletion interaction.
- Deleting one profile preserves the surviving participant's conversation and message history while permanently removing the deleted participant's access.
- Every surviving UI and email/deep-link surface renders **Deleted profile** with no handle, avatar, link, owner clue, or association with a later profile that reuses the handle.
- Profile deletion remains blocked for created events until a separately reviewed admin transfer completes, and the last-profile path routes to the distinct account-deletion flow.

Acceptance evidence:

1. Reviewed owner-hosted package records and controlled deletion fixtures cover buyer deletion, seller deletion, sender deletion, hidden/unread states, final participant/account deletion, and retries.
2. Browser and network evidence proves neutral deleted-participant rendering and no retained owner/profile identifiers beyond the approved nullable references.
3. A freed-handle reuse fixture proves the new profile cannot inherit or link to historical conversations.
4. Realtime tests prove unauthorized or stale subscribers cannot observe private delete identifiers; use authorized Broadcast only if direct testing proves it is required.
5. Exact cascade/reference and media-orphan reports match the approved profile-deletion summary before the deletion UI is enabled.

## Gate 3 — before V1 launch

Gate 3 is independent of Multi-Profile enablement. These launch requirements remain blocking even if Gates 1 and 2 pass.

### Column privileges and public listing contracts

Required state:

- After the two owner-run staging PATCH probes below, replace broad profile UPDATE authority with explicit editable columns so owners cannot set `is_verified`, `is_creator`, or protected suspension/moderation fields.
- Replace broad listing UPDATE authority with explicit editable columns so owners cannot set `is_featured`, `view_count`, or `admin_notes`.
- Remove `admin_notes` from anonymous/ordinary authenticated SELECT and from every browser payload; homepage and category-page wildcard queries ship it today.
- Replace homepage/category/detail and all other listing `select("*")` queries with explicit reviewed public columns.

Acceptance evidence:

1. Owner-run probes establish the actual before-state; the reviewed fix then proves allowed edits still pass and every protected-column PATCH fails.
2. Anonymous/member API, DOM, and network checks across homepage, category, browse, profile, and listing detail contain no `admin_notes`.
3. Static inventory shows no wildcard listing selection in production browser paths.

### Session-state lifecycle

Required state:

- Define and implement TTL/cleanup for `private.account_session_active_profiles`, including logout/session expiry, profile deletion, and account deletion.
- Do not assume a cron exists. The owner must inspect `cron.job` with an authorized read-only query first.

Acceptance evidence:

1. The cron measurement below records current jobs without treating an RLS-filtered or denied result as zero.
2. Reviewed lifecycle tests prove stale rows expire or are removed, active rows remain valid, and profile/account deletion clears affected mappings.
3. Retention and retry behavior are documented and bounded to the approved session lifetime.

### Remaining security and V1 product gates

Required state and acceptance evidence:

- Review and explicitly decide the remaining anonymous `INSERT` grant on `profiles`; direct anonymous insertion must remain impossible at both privilege and policy boundaries, proven by an anonymous API probe.
- Ship the V1 reports feature for profiles, listings, posts, conversations, and Notice Board content with the approved deduplication, burst-limit, admin-email, reason, and public-contact behavior; verify each surface and abuse limit end to end.
- Publish the approved legal, privacy, terms/AGB, Impressum/contact, cookie, and safety pages; verify routes, footer/auth links, content approval, status codes, metadata, and indexability.
- Ship server-side new-message email with unread-aware delay, idempotency, per-conversation throttling, correct contacted-profile naming/deep link, account-level opt-out, and same-account suppression; verify with real mail and authenticated deep-link journeys.
- Ship the approved Following view and profile-scoped follow/unfollow behavior according to Turgay's resolved Stream-placement ruling below; verify active-profile isolation, no-follows state, URL behavior, sibling follows, exact self-follow denial, and public counts.

## Owner measurements

These measurements do not authorize an apply. They are owner-run evidence inputs. SQL Editor measurements are read-only; denied or RLS-filtered results are `UNPROVEN`, never zero.

### SQL Editor — read-only

1. **Active auth sessions versus state rows.** Under an owner-authorized role that can read both sources, report current active Supabase auth sessions and matching distinct `private.account_session_active_profiles.session_id` rows, plus missing, stale, wrong-owner, and wrong-profile joins. Include the exact session-active definition and observation timestamp. Gate 1 requires every supported active session to be covered or to have a proven immediate bootstrap path.
2. **`cron.job` inventory.** List job ID/name, schedule, active state, and command purpose sufficient to determine whether any active-profile-state cleanup exists. Redact secrets if commands contain them. A permission denial or filtered result is `UNPROVEN`.

### Staging — authenticated PATCH probes

Run these with a controlled owner profile/listing, capture status and response, and immediately restore any accepted value. Do not probe production data.

1. **Profile self-elevation probe:** attempt to change `is_verified` and `is_creator` on the caller's active profile. Expected secure result after remediation: denied, with no row change. Record the before-state separately because catalog evidence currently predicts the write may succeed.
2. **Listing self-elevation probe:** attempt to change `is_featured`, `view_count`, and `admin_notes` on a listing owned by the caller's active profile. Expected secure result after remediation: denied, with no row change and no public `admin_notes` read. Record and restore any accepted before-state.

## Resolved product decisions

These rulings record product outcomes only. Their implementation belongs to separate future work.

1. **Following placement — resolved by Turgay on 2026-08-21:** Following lives on the Stream page as an **All / Following** toggle, always visible to logged-in users, with a friendly empty state when the active profile follows nobody. For this placement, the `docs/DECISIONS_HANDOVER.md` wording takes precedence over `docs/V1_DECISIONS.md` line 29.
2. **Homepage tickets — resolved by Turgay on 2026-08-21:** Remove the five hard-coded ticket cards. Keep the section location reserved and, once ticket-category listings exist, display the **most recent ten** in a carousel using the same rail mechanics as Featured Pieces on `/apparel` through the shared `FeaturedCategoryRail`: three visible plus peek, conditional arrows, snap, eased motion, and mobile swipe. Keep the section hidden/empty until such listings exist.

## Fact pins

These facts prevent stale packages and reviews from reopening completed or differently scoped work:

- Exactly **18** current policies use the active-profile accessor, not 19: 13 from the social/event conversion plus 5 profile/listing policies.
- The `vendor` enum value is **already live in the database**. MP4-H must not add or re-add it. Remaining vendor work is application-contract work only: update the three TypeScript lists (`types/marketplace.ts`, `app/profile/edit/page.tsx`, and `components/EditProfileModal.tsx`) and add a drift test that binds them to the reviewed enum contract.
- MP4-H scope is **browser-upload active authorization**. Trusted external import authorization remains a separate explicitly approved ownership/resource boundary.
