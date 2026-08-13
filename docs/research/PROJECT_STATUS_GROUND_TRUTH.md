# Psy.market project status — verified ground truth

**Audit date:** 2026-08-10 (Europe/Berlin)
**Repository:** `/home/repos/psy`, branch `main`
**Pre-report audited HEAD:** `d818dd2a2db6928e243b7a574d0e2712afef9392`
**Method:** executable route and component inspection, fresh production build and tests, local staging browser/HTTP checks, process/cgroup inspection, Git inspection, anonymous Supabase REST probes, and direct read-only PostgreSQL catalog/data queries. Documentation is cited only where current code/catalog evidence agrees with it.

## Executive ground truth

Psy.market is a working, pre-launch, contact-only marketplace plus a festival calendar, profile Walls, a public Stream, reactions, messaging, and festival Notice Boards. The public staging UI renders real database content. Authenticated write paths exist in code for profiles, listings, posts/reactions, messages, RSVPs, and notices, but this audit had no authenticated browser session. Selected auth, upload, listing-validation, profile-contract, Wall/Stream and reaction logic is test-covered; messaging, RSVP and Notice Board journeys were code-inspected but were not substantively automated or browser-reverified here.

There is **no admin UI** in the application. Moderation is live database machinery only. Multi-Profile is **not enabled**: live still enforces one profile per account, has no `vendor` profile type, no active-profile/session objects, no switcher, and no profile-creation management UI. The recently published MP-4 SQL is **authored and validated but not applied**.

The largest privacy qualification is that Package C stopped the deployed application from requesting `profiles.user_id`, but the live anonymous PostgREST API still permits `select=id,user_id` and returned both fields. Client discipline is deployed; database-enforced owner-ID privacy is not.

---

## 1. What the app actually is

### 1.1 Routes present in the production build

A fresh `npm run build` produced the following route set:

| Route | Actual implementation |
|---|---|
| `/` | Marketplace homepage with live listings, category/navigation content, featured/event sections, auth entry points. |
| `/stream` | Public newest-first post feed with local-date range filter, cursor pagination, image lightbox and reaction counts. |
| `/apparel`, `/art`, `/jewellery`, `/music`, `/tickets`, `/vintage`, `/new-arrivals` | Database-backed category pages. Tickets includes face-value/barcode safety copy. |
| `/browse` | Implemented but clothing-only: it hard-codes `category = clothing`; `?q=` from the header is ignored. Filters/sort are client-side over the loaded result set. |
| `/listing/[id]` | Listing detail, images/lightbox, seller card, related listings and login/contact flow. |
| `/listings/new` | Protected listing creation flow with R2 upload pipeline and immediate active publication. |
| `/listing/[id]/edit` | Listing-owner edit page. Not protected by middleware; ownership is checked after page load. |
| `/[handle]` | Public profile with Wall and Active Listings tabs. Invalid reserved-looking paths also fall into this dynamic route and render a profile-not-found state rather than a true legal/admin page. |
| `/seller/[handle]` | Redirect to `/[handle]`. |
| `/profile/edit` | Protected substantive profile editing, including media upload. |
| `/messages`, `/messages/[id]` | Protected inbox/thread UI backed by profile-scoped conversation state. |
| `/festivals` | Live timeline/calendar; browser rendered 21 current event cards in this audit. |
| `/festivals/[slug]` | Event details, Who's Going RSVP UI, listings and Notice Board. |
| `/login`, `/signup` | Standalone auth pages; auth modal also exists in shared UI. |
| `/forgot-password`, `/auth/recovery`, `/update-password`, `/auth/callback` | Recovery/callback routes. `/update-password` is a retired guard page, not the active recovery implementation. |
| `/api/auth/signup` | Server-side signup endpoint. |
| `/api/auth/recovery/update` | Isolated recovery update endpoint. |
| `/api/r2/presign`, `/api/r2/finalize` | Signed quarantine upload and finalize/promotion endpoints. |

No route exists for `/admin`, `/following`, reports, settings, account deletion, legal/safety pages, sitemap or robots. Because `/[handle]` catches unknown one-segment paths, `/admin`, `/privacy-policy`, `/terms-of-service`, `/impressum`, `/following`, etc. can return an HTTP 200 shell while not implementing those products.

### 1.2 Signed-out behavior actually rendered

The audit browser rendered, against the running local staging service:

- the public Stream with four visible real posts and reaction totals;
- public listing detail with title, price, media, description, tags, shipping, seller and related listings;
- the festival timeline with 21 event cards;
- the Tickets category and its safety guidance;
- a public profile header with Wall and Active Listings tabs;
- login/signup entry points and login-required seller contact behavior.

The Stream's direct anonymous REST request returned HTTP 200. Public content is therefore not mock-only.

Signed-out users can browse listings/profiles/events/public posts, inspect reactions, search via the header shell, and begin login/signup. Attempting to react or contact requires authentication.

### 1.3 Signed-in functionality present in executable code

The following is wired to live Supabase tables/RPCs. Automated coverage is not uniform: selected auth, upload, listing-validation, profile-contract, Wall/Stream and reaction behavior is covered, while messaging, RSVP and Notice Board journeys are code-inspected rather than substantively automated/end-to-end verified:

- edit a profile and upload avatar/header media;
- create and edit active listings with up to five images;
- owner listing removal by changing status to `draft`;
- contact another profile, create/open a conversation, send text messages, maintain unread state, and hide/unhide conversations per profile;
- create/edit/permanently delete Wall posts with text and up to five images;
- choose public/Stream visibility or members-only visibility for a post;
- add/remove one of six custom post reactions;
- RSVP to festivals as attending or selling;
- create/filter/search/sort Notice Board posts and react to them;
- delete own Notice Board posts; edit and permanently delete own Wall posts.

**Runtime verification boundary:** no reusable staging user credential was available to this audit. These signed-in paths were not clicked end-to-end in an authenticated browser now. Their live success is therefore **unverified in this audit**, even where code/tests/catalog objects are present.

### 1.4 Partial, inert or absent product surfaces

There are no feature flags in the executable source; incompleteness is exposed directly in the UI/code.

- Header search navigates to `/browse?q=...`, but `/browse` does not read the query and always fetches clothing.
- Search-overlay quick links for Tickets, Vintage and New Arrivals are inert (`href: null`), even though proper top-nav routes exist.
- `Save Draft` is a visible no-op in both listing creation implementations: it has no click handler.
- Listing “Delete”/remove is actually an update to `status = draft`; there is no genuine delete distinction and no Mark Sold control.
- Footer newsletter Join has no handler. Most footer shop/support/company/legal labels are inert. Only Contact has an `href`, but `/contact` has no page and is caught by `/[handle]`.
- Privacy/Terms/Cookie labels are not links and legal/safety routes do not exist.
- Favorites exist in the database but are explicitly outside V1 and have no UI.
- Follows exist in the database but there is no Follow/Unfollow control or Following feed/tab in current application code.
- No content-report submission UI, API or reports table exists.
- No new-message email sender or account-level email setting exists.
- No account settings, password-management hub, profile creation/switching, profile deletion or account deletion UI exists.
- No admin controls exist, including no post Hero flag button, post moderation button, user ban button, admin appointment screen, or listing moderation button.
- Profile tabs are stateful buttons on one URL; Wall/Listings do not have their own URLs despite the binding decision document saying they should.
- Homepage Hero database machinery exists, but admin flagging is not exposed in the app.
- Inline post links are not a separately verified complete auto-linkification feature in this audit.

---

## 2. Admin capabilities

### 2.1 What an admin can do through the application UI today

**Nothing admin-specific was found.**

There is no admin route, dashboard, role-aware navigation, account-linkage panel or inline admin action in `app/` or `components/`. Application code does not invoke the admin RPCs. `lib/db.private.server.ts` contains a server-only wrapper for `admin_get_profile_account`, but no production route/component imports it; tests enforce that the private helper is not imported into public UI modules.

An admin who signs in sees the same ordinary user surfaces unless database policies happen to authorize an ordinary action. The normal UI does not expose admin powers.

### 2.2 Live database-only admin machinery

Read-only catalog inspection confirms live functions for:

- `super_admin_appoint_admin` and `super_admin_remove_admin`;
- `admin_ban_user` and `admin_unban_user`;
- `admin_unpublish_listing` and `admin_republish_listing`;
- `admin_delete_post`;
- `admin_set_post_hero_featured` and `clear_hero_on_author_ban`;
- `admin_delete_notice_post`;
- `admin_get_profile_account` for private account/profile linkage;
- `current_user_is_admin`, `current_user_is_super_admin`, and `current_user_is_banned`;
- blocklisted-domain maintenance/checking.

The live `users` policies also include admin-only application-user reading. These are database capabilities, not product UI. Supabase Auth ban synchronization is also not implemented by this Next.js app; a database ban RPC alone cannot prove Auth `banned_until` synchronization.

---

## 3. Live database state

### 3.1 Inspection boundary

The direct connection ran PostgreSQL 17 in a read-only transaction. It can inspect catalogs and publicly visible rows but does **not** bypass RLS. In particular, `public.users` returned zero visible rows to the audit role; that does not mean the table is empty. Banned-user/admin-role counts are therefore **unverified**, not zero.

The owner-run MP-4 preflight reported `banned_profile_owner = UNPROVEN`, but this audit could not independently distinguish “no banned owner exists” from RLS-hidden user state. Temporarily banning `@darktribo` through Turgay's owner-operated admin procedure remains the proposed deny-path fixture, not an already verified ban. That procedure is external to this Next.js app: no ban UI exists here.

### 3.2 Current catalog

Live public tables include:

`blocked_handles`, `reserved_handles`, `users`, `profiles`, `listings`, `conversations`, `conversation_participant_state`, `messages`, `events`, `vendor_events`, `event_notifications`, `notice_posts`, `notice_reactions`, `favorites`, `follows`, `posts`, `post_reactions`, `post_upload_rate_limits`, and `upload_intent_rate_limits`.

All have RLS enabled. The catalog also contains the expected conversation-state, moderation, Wall, post-visibility and shared upload-rate-limit triggers/functions/indexes.

### 3.3 Package application truth

| Package/artifact | Live status | Direct evidence |
|---|---|---|
| Historical database Chunks 0–7 | **Applied** | Their tables/constraints/policies/functions/triggers are present: ban/role foundations, blocked/reserved handles and one-profile enforcement, tickets support, moderation RPCs, conversation hiding/state, durable ban checks and Realtime-oriented objects. |
| Chunks 8–9 | **Not applied / deferred proposal** | No upload reservation/session ledger exists. Current upload design remains state-free plus rate limit. |
| Chunk 10 security-definer hardening | **Applied** | `increment_view_count` and `update_conversation_last_message` are `SECURITY DEFINER`, have `search_path=""`, deny anon/authenticated execution and permit service role. |
| Item 3 shared upload-intent rate limiter | **Applied** | `upload_intent_rate_limits`, `consume_upload_intent_quota`, prune trigger/function and grants are present. |
| Chunk 11A–11C Wall | **Applied** | `posts`, `post_reactions`, rate-limit table, Hero index, validation/moderation triggers and post/reaction RPCs exist. |
| Chunk 11D post visibility | **Applied** | Visibility helper functions and public/member-aware post/reaction policies exist. |
| MP-1 Package A | **Read-only authored artifact; not an apply package** | It is a preflight/baseline file only. |
| MP-1 Package B | **Applied** | Exact live functions include `get_my_profiles()`, `current_user_owns_profile(uuid)`, and private `admin_get_profile_account(uuid)`. |
| MP-1 Package C | **Deployed application code** | Current app source uses safe public-profile projections and Package B ownership helper wrappers. It is not a separate DB migration. |
| MP-4 policy conversion | **Authored/validated/published; not applied** | `current_user_owns_unsuspended_profile(uuid)` is absent. All 22 targeted live policies still directly inspect `profiles.user_id`, which is the approved old state. |
| R2 profile URL switch | **Current data uses R2, exact historic apply attribution unverified here** | Visible current hosts: 5 profile avatars, 1 non-empty header and all 17 listing image references use `images.psy.market`. A catalog inspection cannot prove the historical three-row execution ritual by itself. |

### 3.4 Current row-level facts visible through RLS

- 7 public profiles are visible: `crystalweaver`, `darktribo`, `kaba`, `otis`, `solarbeing`, `suntribe`, `turgay`.
- The visible profiles reference 7 distinct Auth owner IDs and the one-profile unique index is live.
- 17 active listings are visible; none visible in other statuses.
- 21 events, 4 RSVPs/vendor-event rows, 3 Notice Board posts, 2 Notice reactions, 1 visible follow, 0 visible favorites and 0 visible conversation/message rows were returned.
- The audit role could not read `posts` directly, but the anonymous staging browser's Stream API returned four public posts.
- Members-only post count is unverified without an authenticated read.
- Admin and banned-user counts are unverified because `users` rows are hidden by RLS.

### 3.5 Privacy state

Package C's client queries use explicit public profile columns and avoid owner IDs. However, a direct anonymous PostgREST probe to `profiles?select=id,user_id&limit=1` returned HTTP 200 with both `id` and `user_id`. The live policy remains `Profiles are publicly readable`, and broad column access has not been cut over.

Consequences:

1. Current one-profile-per-account state means there are no sibling profiles to correlate today.
2. The deployed UI/normal network requests avoid exposing owner IDs.
3. The database/API privacy boundary required before enabling multiple profiles is **not complete**; a caller can explicitly request owner IDs.
4. Multi-Profile cardinality must not be enabled until this is corrected and re-audited.

---

## 4. Multi-Profile / MP package status

The proposal defines slices MP-0 through MP-14. Recent artifact names do not map one-for-one to complete proposal slices; “MP-4 package” currently means a compatibility authorization-policy conversion, not completion of every item listed under proposal Slice MP-4.

| Proposal slice | Ground-truth status |
|---|---|
| MP-0 decision/document reconciliation | **Completed as documentation.** Final decisions and reconciliation report are committed. Some surrounding context files remain stale, as listed below. |
| MP-1 fresh preflight/package design | **Substantially authored.** Package A preflight exists; Package B contracts, Package C client conversion and MP-4 conversion artifacts were designed and validated. This is package work, not feature enablement. |
| MP-2 DB privacy/public-profile contracts | **Partial, not complete.** Package B is live and Package C app queries are deployed, but anonymous REST can still select `profiles.user_id`; there is no enforced safe public view/column-grant cutover. |
| MP-3 cardinality/type/active-session foundation | **Not authored/applied as a complete slice.** Live profile types are only `personal`, `artist`, `label`, `festival`; no `vendor`. `profiles_one_per_user_key` remains. No active-profile/session/switch functions exist. |
| MP-4 active authorization/deletion foundation | **Compatibility package authored, not applied; full slice not complete.** The published SQL would convert 22 policies and 10 functions to helper-based ownership without changing who may act. It has not been run live, and active-profile/deletion foundations described in the proposal are absent. |
| MP-5 public-profile client cutover and active Header | **Partial application cutover deployed.** Public client projections are safe by convention. Header still requires exactly one profile and has no active-profile switcher. No DB grant cutover. |
| MP-6 profile namespaces/listings/editing/uploads | **Not implemented as an MP slice.** Existing single-profile R2 listing/profile flows remain. |
| MP-7 Wall/posts/reactions | **Existing single-profile feature works; MP conversion not implemented.** No active-profile switching exists. |
| MP-8 messaging/email | **Existing single-profile messaging exists; MP conversion and email do not.** |
| MP-9 follows/Following/festivals/notices | **Existing single-profile festival/notices exist; follows are DB-only; Following UI and MP conversion do not exist.** |
| MP-10 multi-profile enablement/reserved claims | **Not implemented.** One-profile uniqueness remains; no additional-profile creation or claim UI. |
| MP-11 retained conversations on profile deletion | **Not implemented as the MP deletion model.** Conversation hiding exists, but profile-deletion retention/tombstone flow does not. |
| MP-12 profile deletion | **Not implemented.** |
| MP-13 account deletion | **Not implemented.** |
| MP-14 full launch gate | **Not started as a completed gate.** Current tests pass, but the product and multi-profile matrices are not complete. |

### What staging actually contains

The currently running app contains the Package C public-query/client changes and all earlier single-profile features. It does **not** contain a profile switcher, profile manager, additional-profile creation, `vendor` onboarding, active-profile session state, per-profile Following UI, profile deletion or account deletion. Live DB remains safely one-profile-per-account.

---

## 5. Staging state

### Runtime and health

- Process: `next-server`, PID observed as `1121491`, user `claude`.
- Cgroup: `/user.slice/.../app.slice/psy.service` — confirms the running process belongs to the `claude`-owned user service.
- Process start: **2026-08-09 13:06:58 CEST**.
- Local listener: `0.0.0.0:3030`.
- Local `/`: HTTP 200.
- Key local pages checked after the fresh audit build: HTTP 200; Stream made a successful live REST request and rendered data.
- Public `https://psy.heyturgay.com/`: HTTP 401 from the staging access gate. This proves the tunnel/front door responds; it does not expose app content without the staging password.
- Current user cannot query/manage the `claude` user service through `systemctl --user`; service health is inferred from process/cgroup/listener and application responses, not from a service-manager `active` property.

### Revision and rebuild truth

The service does not expose a commit SHA, so an exact Git revision cannot be read from the running process. Before this audit's build, the tracked runtime-source modification time was **2026-08-09 12:59:40 CEST**, the old `.next` BUILD_ID was `yogisw-kV1wFIwdXBJ6Iq`, and the service started minutes later. Package C was committed after those source files were built; every commit after Package C changed only SQL/docs. Therefore the running app's tracked runtime source is **source-equivalent to `d818dd2`**, but the exact build commit identity is unverified because no revision marker is embedded.

This audit ran a successful fresh production build at current HEAD, generating ignored `.next` BUILD_ID `jsdrNbgOxs4O79CcLWmnw` on 2026-08-10. The `psy.service` process was **not restarted**. Read-only browser checks after the build remained healthy. A normal owner-controlled staging refresh is still advisable so process start/build identity is unambiguous.

---

## 6. Git truth — approximately the last three weeks

At audit start, local `main`, `origin/main`, and remote `main` all matched `d818dd2`; the tracked worktree was clean. Significant actual changes:

| Date | Commit(s) | Actual change |
|---|---|---|
| 2026-07-27 | `19b0fdf`, `89e0c77`, `8eb44cb`, `a316fb1`, `90c6809` | Corrected staging-runtime instructions, recorded Chunks 0–7 as live, preserved Step 11 decisions/handover and reconciled current project context. This is the first repository activity in the audited three-week window; there are no July 25–26 commits. |
| 2026-07-27 | `1636737` | Added the exact Chunk 10 security-definer hardening package and its review/smoke/verification records. Live catalog independently confirms its hardened state. |
| 2026-07-27–28 | `cd7d12f`, `b5bc53c`, `e255c62` | Implemented and then simplified/hardened password-recovery session revocation and cleanup. |
| 2026-07-30 | `c2bd41f` | Hardened server-side signup confirmation/callback behavior and auth-safety tests. |
| 2026-08-01 | `5e2d4ec`, `ec51d32`, `a21da7d`, `13b57af`, `9274027`, `d083915`, `fd1a034`, `820bf27`, `5b2be7c`, `634302b`, `cb3ad29`, `0d7f64a` | Auth presentation/navigation fixes, validation styling, upload feedback and pre-upload listing-description validation. |
| 2026-08-02 | `6863495`, `d0da78d`, `25ea47a`, `a2ca01e` | Extracted the shared quarantine pipeline, routed trusted CLI uploads through it, added the shared persistent upload-intent rate limiter, and logged limiter RPC failures. Live objects confirm the shared limiter is applied. |
| 2026-08-03 | `2158058`, `17c3572` | Applied/verified Wall DB package and deployed profile Wall composer, posts and lightbox. |
| 2026-08-06 | `1b5c86d`, `8e1b8b9` | Public Stream, active nav, art/tickets/vintage/new-arrivals pages and tests. |
| 2026-08-07 | `e8e948f`, `7562e94` | Stream date filter; applied 11D public/members-only post visibility and auth-transition polish. |
| 2026-08-08 | `9904dec`, `2e13d7d`, `f37498f` | Custom post reactions; finalized Multi-Profile decisions; broad MP-0 documentation reconciliation. |
| 2026-08-08 | `8bb891e` | MP-1 Package A read-only preflight artifact. |
| 2026-08-09 | `99ff1c0`, `bbbb942` | MP-1 Package B private profile contracts, then corrected helper definitions. Live functions confirm application. |
| 2026-08-09 | `210941e` | Package C app conversion to explicit public profile projections/private ownership contracts, plus tests. |
| 2026-08-09 | `d42050b`, `2e78806` | MP-4 conversion package for 22 policies/10 functions, Wall verifier reconciliation and hardened exact guards. Not live-applied. |
| 2026-08-10 | `d818dd2` | Reconciled PostgreSQL 16/17 policy rendering in the MP-4 package after a safe live preflight STOP. Still not live-applied. |

No source code or database change was uncommitted before this report was created. `.next` build output and `/tmp` audit evidence are ignored/not part of Git.

---

## 7. Tests and build run now

Fresh on 2026-08-10:

| Check | Result |
|---|---|
| `node --no-warnings --test --experimental-strip-types tests/*.test.ts` | **PASS — 145 tests, 145 pass, 0 fail** |
| `npx tsc --noEmit` | **PASS** |
| `npm run build` | **PASS** |
| Build route generation | **PASS**, covering 26 page files and four API route handlers, plus middleware, as listed above |

The successful build proves current tracked source compiles. It does not substitute for authenticated browser acceptance, email delivery, admin UI testing, or the multi-profile launch matrix.

---

## 8. Open work and documentation conflicts

### 8.1 Genuinely in progress / next guarded operation

1. **MP-4 live ritual:** package is published and scratch-validated (`verify GO 16/16`, Wall checks green, rollback restored old preflight GO) but remains unapplied. A demo account must first be temporarily banned through Turgay's owner-operated admin procedure to make the deny fixture provable; rerun preflight and require full GO before apply; unban after verification. The current Next.js app does not expose that procedure.
2. **Database-enforced public-profile privacy:** anonymous owner-ID access must be removed through a separately guarded grant/view/API cutover before additional profiles are enabled.
3. **MP-3 onward:** vendor type, five-profile cap, active-profile/session state, switcher and all dependent active-profile conversions remain future work.
4. **Authenticated staging acceptance:** current signed-in listing/post/message/festival/upload/recovery paths require fresh click-rounds; this audit did not have credentials.

### 8.2 Planned but absent product work

- all admin UI and Auth-ban synchronization;
- follows/Following UI;
- content reporting;
- search that actually consumes the query, complete browse filters/pagination/URL state;
- new-message All-Inkl SMTP flow and opt-out;
- account settings, profile/account deletion and reserved claims;
- legal/safety pages and real legal operator data;
- listing cover reordering, truthful delete/unpublish semantics, Mark Sold, price-preview correction;
- dead control/link cleanup;
- SEO metadata/canonical/robots/sitemap, monitoring, Vercel production setup and launch acceptance.

### 8.3 Documentation/assumption discrepancies found

1. **“Multi-Profile/privacy foundation is complete” is false if read as a live security boundary.** Package C is deployed and Package B is live, but anonymous REST can still request `profiles.user_id`; MP-4 is not applied; one-profile cardinality remains. The work is staged foundation, not completed Multi-Profile privacy.
2. **Admin capability is commonly described as if it were a usable product.** The RPCs/policies are live, but there is no admin page or inline admin control anywhere in the app.
3. **`.agent-context/NEXT_STEPS.md` is explicitly historical but still says profile/listing edit pages are unbuilt and Posts are future.** Both edit pages and Wall/Stream posts exist. Its festival sprint and restart choices are also obsolete.
4. **`.agent-context/CURRENT_STATE.md` is internally stale.** Its route inventory omits Stream, art, tickets, vintage and new-arrivals; it says Posts scope is unconfirmed even though current `V1_DECISIONS.md` defines Wall/Stream/Posts; it retains a pre-Chunk-10 warning that the two security-definer functions lack fixed search paths, while live catalog proves Chunk 10 fixed them.
5. **`docs/V1_PUNCHLIST.md` says the accepted upload mitigation includes a process-local presign limiter.** Current code/tests removed the process-local limiter, and live uses the shared `upload_intent_rate_limits` database object/RPC instead.
6. **Binding Following placement and current product differ.** `V1_DECISIONS.md` says a Following tab belongs on the active profile; there is no Following UI at all. Any newer assumption that it is on Stream is not reflected in repository truth either.
7. **Legal/footer links can look present while routes are absent.** Most are inert spans; unknown top-level paths are swallowed by `/[handle]` and can return HTTP 200 without legal content.
8. **Exact staging revision is not currently observable.** Runtime source equivalence can be established, but no commit marker is embedded and service build/process timestamps are the only evidence.

---

## Bottom line for planning

Treat the product as a working **single-profile** marketplace/community staging app with real public data and substantial signed-in code, not as a Multi-Profile product. Treat admin/moderation as **database-only**, not UI-complete. Treat MP-4 as **published but unapplied**. Do not enable multiple profiles until anonymous owner-ID access is closed, active-profile/cardinality foundations are live, and the full privacy/authorization matrices pass against real fixtures.

---

## Addendum — 2026-08-11: MP-4 live application

This dated note updates the 2026-08-10 snapshot without rewriting its audit body.

- The full owner-run MP-4 ritual completed on the live database: the reviewed `@darktribo` temporary-ban fixture made `banned_profile_owner` provable, MP-4 preflight returned full GO, and the policy/function conversion apply committed cleanly. See the [dated application and verification record](../MP4_POLICY_CONVERSION_VERIFICATION.md).
- The first post-apply verify returned STOP 13/16 because of three live-data assumptions in the verify harness, not authorization defects: an invalid Notice category, an invalid Notice reaction emoji and an RSVP pair that already existed under the live unique key. The verify-only correction in `b85b20f` passed independent review; the live rerun returned GO 16/16, including banned-account denial.
- Fixture unban and unban-verify returned GO. `@darktribo` was restored with zero Hero posts affected; only the accepted `updated_at` timestamp advances remained.
- Therefore §8.1 item 1 is complete: **MP-4 is live and verified as of 2026-08-11.** Section 8.1 item 2 remains the next open guarded operation: Package D/database-enforced public-profile privacy must remove anonymous owner-ID exposure before additional profiles are enabled.

---

## Addendum — 2026-08-12: Package D live privacy cutover

This dated note updates the 2026-08-10 snapshot and the 2026-08-11 addendum without rewriting either historical record.

- The full owner-run Package D ritual completed on the live database. Preflight returned GO with no findings and captured the complete 33-entry pre-cutover ACL, matching the package's pinned expectation exactly. Apply committed cleanly on its first live run with no refusal. See the [dated application and verification record](../PACKAGE_D_PRIVACY_CUTOVER_VERIFICATION.md).
- Live verify returned **GO 33/33**. For both `anon` and `authenticated`, the 12 approved `PUBLIC_PROFILE_SELECT` columns remained readable, while `user_id`, `is_suspended`, `updated_at` and wildcard `select=*` attempts were denied with SQLSTATE `42501`. Embedded profile reads, owner/admin helpers and `service_role` access remained intact.
- An independent VPS REST probe reconfirmed before apply that `profiles?select=id,user_id` returned HTTP 200 with data. After apply, the same request returned HTTP 401 / SQLSTATE `42501` with `permission denied for table profiles`; safe-column requests continued to return HTTP 200.
- Turgay's authenticated staging click-round passed across the homepage, listing, profile, Stream, festival, inbox and profile-edit surfaces. Rollback was available but not needed.
- Therefore the privacy qualification in §3.5 and §8.1 item 2 are resolved: **anonymous/authenticated owner-ID exposure is closed at the database level, and the public `profiles` read surface is exactly the 12 `PUBLIC_PROFILE_SELECT` columns.** The precondition “do not enable multiple profiles until anonymous owner-ID access is closed” is **MET**.
- Multi-Profile remains disabled. The MP-3 cardinality, `vendor` type and active-profile/session foundations are still open. The next guarded database operation is now the **MP-3 foundation slice**.

---

## Addendum — 2026-08-13: MP-3 foundation live application

This dated note updates the 2026-08-10 snapshot and the 2026-08-11/12 addenda without rewriting those historical records.

- The full owner-run MP-3 foundation ritual completed on the live database. Before any live execution, wingman pre-review found two stale reconstructed baseline pins in `d704cdb`: the live one-profile guard is a bare unique index rather than a constraint row, and the reconstructed signup function differed from the live body. `af0b2dd` corrected both from wingman-read live evidence. See the [dated application and verification record](../MP3_FOUNDATION_VERIFICATION.md).
- Live preflight returned GO with no findings. Apply completed cleanly: the guarded non-transactional `vendor` enum step ran first, followed by the all-or-nothing transaction.
- The first live verify returned STOP 17/19. All behavior checks passed; the two failures were environment/session-dependent catalog renderings in fingerprints, not state defects. Wingman read-only diagnosis confirmed the applied state was functionally exact, so rollback was not needed. `eadd83b` and `01f8382` normalized settings, ACL privilege sets, schema qualification and function-body whitespace; wingman recomputed every corrected pin against live and all matched before rerun.
- The corrected live verifier returned **GO 19/19**, including fail-closed session denials and client-role denial of additional-profile creation with SQLSTATE `42501`. Package D privacy was re-verified intact.
- The first Claude-in-Chrome QA mission under handover §11 passed on the homepage, public profile, profile-edit edit/revert round trip and Stream. Both profile writes saved through the new triggers; `vendor` remained correctly absent from the profile-type UI. The wingman evaluated the findings.
- Therefore the §3.3 row and §8.1 item 3 statements that MP-3 was not authored/applied or remained future work are superseded: **MP-3 foundations are live and verified as of 2026-08-13.** The dormant `vendor` label, locked five-profile-cap trigger, owner-immutability trigger, private per-session active-profile state and authenticated helpers are live; the trusted additional-profile RPC remains unreachable by client roles.
- Multi-Profile remains disabled because `profiles_one_per_user_key` is still in force. No profile creation/switching/deletion UI is enabled. The next guarded database operation is the proposal's **Slice MP-4 — Database active-authorization and deletion foundation**.
- The operational rollback remains available and gates on the exact after-state. It deliberately retains the `vendor` enum label because PostgreSQL has no supported safe in-place enum-value removal.
