# MP-1 Package C — Application Public/Private Profile Contract Report

**Status:** APPROVED by Turgay after the complete authenticated staging click-round and an independent browser-side response-body privacy audit.

## Scope and invariants

Package C changes application code only. It contains no SQL, migration, schema, policy, ACL, RLS, publication, data, profile-cap, active-profile-state, or R2-key change.

The binding privacy invariant remains:

> sibling profiles must remain publicly unlinked

The browser-safe `PublicProfile` contract contains exactly these 12 database columns:

1. `id`
2. `type`
3. `handle`
4. `display_name`
5. `bio`
6. `avatar_url`
7. `header_url`
8. `location`
9. `social_links`
10. `is_creator`
11. `is_verified`
12. `created_at`

It excludes `user_id`, `is_suspended`, and `updated_at`. The owner-list mapper adds only the latter two private fields returned by `public.get_my_profiles()`; it never adds an account-owner UUID. The admin account-grouping output is isolated in `lib/db.private.server.ts` and is not passed to a component.

## Shared contract implementation

- `types/marketplace.ts`
  - Added `PublicProfile` with exactly the approved 12 safe fields.
  - Removed `userId` from the public profile shape.
  - Retained `Profile` only as a safe compatibility alias to `PublicProfile`; it contains no private field.
- `lib/db.ts`
  - Added the canonical `PUBLIC_PROFILE_COLUMNS`, literal `PUBLIC_PROFILE_SELECT`, and nested `PUBLIC_PROFILE_EMBED` selectors.
  - Replaced `toProfile()` with `toPublicProfile()`.
  - Added `OwnerProfile` and `toOwnerProfile()` without any owner UUID.
  - Added `getMyProfiles()` over `public.get_my_profiles()`.
  - Added `currentUserOwnsProfile()` over `public.current_user_owns_profile(uuid)`.
  - Added `getOnlyProfileForCurrentAccount()` as the temporary one-profile compatibility boundary. It consumes a set, returns zero/one today, and fails closed instead of silently selecting a sibling if multiple profiles appear before active-profile selection exists.
- `lib/db.private.server.ts`
  - Added the separately named `AdminProfileAccount` mapper and `adminGetProfileAccount()` accessor over `public.admin_get_profile_account(uuid)`.
  - Added a runtime browser guard; a static test also rejects any application UI import of this module.

## Converted inventory — 16 production locations across 13 files

| # | Location | Change |
|---:|---|---|
| 1 | `app/page.tsx` | Replaced seller `profiles.select("*")` with the canonical 12-column selector and public mapper. |
| 2 | `app/[handle]/page.tsx` public load | Replaced public profile wildcard selection with the canonical selector and `toPublicProfile()`. |
| 3 | `app/listing/[id]/page.tsx` seller load | Replaced seller wildcard selection with the canonical selector and public mapper. |
| 4 | `app/festivals/[slug]/page.tsx` RSVP embed | Replaced `profiles(*)` with the canonical explicit 12-column nested embed and public mapper. |
| 5 | `app/profile/edit/page.tsx` owner edit load | Replaced wildcard plus `user_id` filter with the owner-list RPC set; edit fields are populated from the private owner result without an owner UUID. |
| 6 | `components/layout/Header.tsx` | Replaced the account-owner-column lookup and `LIMIT 1` query with the owner-list RPC set and compatibility boundary. |
| 7 | `app/messages/page.tsx` | Replaced the account-owner-column lookup with the owner-list RPC set before redirecting to the inbox handle. |
| 8 | `lib/posts/use-reaction-viewer.ts` | Replaced viewer profile lookup by `user_id` with the owner-list RPC set. |
| 9 | `app/[handle]/page.tsx` owner state | Replaced the owner lookup by `user_id`; owner UI now compares the private caller profile ID with the public route profile ID. |
| 10 | `app/listing/[id]/page.tsx` contact actor | Replaced the contact actor lookup by `user_id` with the owner-list RPC set. |
| 11 | `app/listing/[id]/edit/page.tsx` | Replaced the owner lookup by `user_id` with the owner-list RPC set; the existing explicit listing/profile comparison remains. |
| 12 | `app/listings/new/page.tsx` | Replaced the publishing-profile lookup by `user_id` with the owner-list RPC set. |
| 13 | `app/festivals/[slug]/page.tsx` actor | Replaced the RSVP/Notice actor lookup by `user_id` with the owner-list RPC set. |
| 14 | `types/marketplace.ts` | Split and narrowed the public profile type; removed public `userId`. |
| 15 | `lib/db.ts` | Centralized the public selector/mapper and private owner/ownership RPC accessors. |
| 16 | `lib/uploads/authorization.ts` | Replaced the authenticated `id,user_id` read and UUID comparison with `public.current_user_owns_profile(uuid)`; ban and resource checks remain unchanged. |

## Dormant fixture cleanup

- `lib/mock-data.ts`
  - Changed the fixture array to `PublicProfile[]`.
  - Removed all three dormant `userId` values.

## Explicitly scoped-out trusted paths

These four owner-column paths are intentionally unchanged because the plan classifies them as trusted service-role/operational access:

1. `lib/uploads/trusted-upload-server.ts` — service-role upload authorization.
2. `scripts/upload-r2.js` — trusted operational upload path.
3. `scripts/upload-and-create.js` — trusted operational upload/create path.
4. `app/api/auth/signup/route.ts` — server-side service-role signup completion update.

The static contract test uses this as an exact allowlist and fails if another tracked or untracked TS/TSX/JS file introduces a profile owner-column query.

The existing explicit safe profile reads listed in the execution plan remain unchanged: safe listing/message/Wall/Notice embeds, handle-availability checks, profile mutations, seller-ID-by-public-handle lookup, and service-role media-reference scans.

## Tests and verification

### Added or updated

- `tests/profile-contract.test.ts`
  - exact 12-column contract;
  - public mapper serialization excludes private fields;
  - owner-list set mapping and no account UUID;
  - fail-closed multiple-profile compatibility behavior;
  - exact Package B RPC names/arguments for owner, ownership, and admin accessors;
  - repository-wide wildcard/owner-filter scan with an exact trusted allowlist;
  - public type/mapper private-field regression checks;
  - browser-import exclusion for the admin account-grouping module.
- `tests/upload-policy.test.ts`
  - upload authorization now proves the ban RPC is followed by `current_user_owns_profile` with the exact profile argument;
  - existing post-resource ownership behavior remains covered.
- `package.json`
  - added `npm run test:profiles`.

### Results

- `npx tsc --noEmit` — **PASS**.
- Full Node test suite (`tests/*.test.ts`) — **PASS: 145 tests, 0 failures**.
- `npm run test:uploads` — **PASS: 48 tests, 0 failures**.
- `npm run test:profiles` — **PASS: 6 tests, 0 failures**.
- `npm run build` — **PASS**, Next.js production build compiled, typechecked, and generated all pages successfully.
- `git diff --check` — **PASS**.

### Staging refresh verification

- Turgay confirmed the `claude` service owner completed stop → build → start.
- A new `claude`-owned Next.js 14.2.35 process started after the Package C build.
- `http://127.0.0.1:3030/` returned **200** and rendered the expected Psy.market home shell, live listing cards, and seller carousel in a browser check.
- A signed-out listing detail and its linked public profile both rendered the expected seller/profile content.
- The checked public-profile DOM contained none of `user_id`, `userId`, `owner_id`, or `ownerId`.
- The local rendered pages produced no browser console or JavaScript errors in the signed-out smoke.
- `https://psy.heyturgay.com/` returned **401** to this agent because this session does not hold the staging credentials.
- Turgay completed the full authenticated click-round; every behavior surface passed.
- An independent browser-side audit inspected actual response bodies on `/turgay`, `/stream`, and a listing detail page. Profile data contained zero owner-ID traces: `/rest/v1/profiles` returned exactly the 12-column public contract, `get_my_profiles` added only `is_suspended` and `updated_at`, and application references were profile-ID-based. The only observed `user_id` was Supabase's expected `/auth/v1/user` session response.

## Ambiguities and dependencies

1. Package C deliberately does not invent active-profile state. Every browser owner lookup consumes the full RPC set and then crosses one centralized compatibility boundary protected by the still-active one-profile constraint. If more than one profile appears unexpectedly, the boundary fails closed rather than choosing the first row.
2. The admin grouping accessor is added as a server-only contract but no current application call site required conversion; existing admin feature behavior is therefore unchanged.
3. Turgay confirmed Package B was applied before the staging refresh. This agent did not execute database SQL; Package C never falls back to direct `profiles.user_id` access if an RPC fails.
4. Turgay approved Package C for commit and push after the staging and privacy checks.
5. The staging service is owned by the `claude` account. Turgay coordinated the approved service-owner refresh; this agent performed only read-only process, HTTP, and browser verification afterward.

## Completed Turgay pre-cutover browser click-round

### Highest-priority first three

1. **Sign in and Header:** confirm the expected avatar/handle appears, unread-message state loads, and `/messages` reaches the expected inbox.
2. **Profile surfaces:** open the signed-in profile, open Edit Profile without saving, then open another public profile; confirm headers, avatars, Wall, listings, and owner-only controls are correct.
3. **Listing + upload initialization:** open an existing listing, test the contact flow, open one owned listing’s edit page, and open New Listing; confirm profile resolution and image controls initialize without permission errors.

### Complete touched-surface checklist

#### Signed out

- [x] Home seller carousel loads public sellers.
- [x] A public profile route loads header, social links, Wall, and listings.
- [x] A listing detail loads seller card, listing count, and related listings.
- [x] A festival “Who’s Going” tab loads attendee/seller profiles.
- [x] Browser Network responses for those surfaces contain no `user_id`, `userId`, `owner_id`, or `ownerId` profile field.

#### Signed in — identity/navigation

- [x] Header resolves the expected profile, avatar, handle, and unread count.
- [x] `/messages` redirects to the expected profile inbox.
- [x] Sign out and sign back in once; Header state refreshes without a stale profile.

#### Signed in — profile/Wall

- [x] Own profile shows owner controls; an unrelated profile does not.
- [x] Edit Profile opens with the expected display name, handle, bio, location, type, avatar, and social links. No save is required.
- [x] Profile Wall loads and reaction viewer state resolves.

#### Signed in — listings

- [x] Listing detail contact flow opens/restores the expected conversation.
- [x] Existing owned listing edit page opens; an unowned listing edit route redirects away.
- [x] New Listing reaches the form and resolves the expected profile.
- [x] Listing image controls initialize; no upload is required for this privacy click-round.

#### Signed in — festival

- [x] RSVP state correctly identifies the signed-in profile.
- [x] Notice composer/reaction state initializes.
- [x] Attendee/seller profile cards remain complete after reload.

#### Upload authorization

- [x] Avatar and header controls initialize without authorization errors.
- [x] Listing and post image controls initialize without authorization errors.
- [x] Do not create a public object solely for this click-round; automated tests cover allow/deny plumbing.

#### Admin/privacy

- [x] Existing admin target-resolution/permission surfaces still load; do not change ban state.
- [x] Public cards and network responses contain public profile IDs only, never an Auth account UUID.
- [x] Inspect HTML/RSC/XHR/browser storage for `user_id`, `userId`, `owner_id`, and `ownerId`; any profile-owner value is a release **STOP**.

## Non-blocking follow-ups

1. Public media URLs under `images.psy.market` still carry the account UUID in their object path. This is the known accepted state until MP-6; Package C takes no action. Existing authenticated upload-intent tokens also continue to bind the verified session identity under the separately scoped upload design.
2. One transient HTTP 503 was observed on an `_rsc` prefetch request for `/stream`, and one on `/turgay?tab=inbox`; direct navigation worked. A read-only journal query from this account exposed no `psy.service` entries, so there is no evidence here of a persistent server error. Recheck only if it recurs.

## Approval

Turgay approved Package C after the full authenticated staging click-round and independent browser privacy audit.
