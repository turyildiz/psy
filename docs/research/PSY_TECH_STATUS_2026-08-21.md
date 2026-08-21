# Psy.market technical re-baseline — 2026-08-21

## 0. Verdict, baseline, and evidence limits

**Verdict:** the repository contains a working single-profile marketplace/community application with real browse, category, listing, profile Wall, public Stream, messaging, festival, authentication, and hardened R2 upload code. It is not yet a V1-complete Multi-Profile product. Search/browse and Wall highlights are the most recently completed product slices; Multi-Profile database foundations have advanced through Slice MP4-D, but MP4-E through MP4-H and every user-visible Multi-Profile slice remain pending (`docs/SLICE_MP4_EXECUTION_RECORD.md:14-23`, `docs/DECISIONS_HANDOVER.md:97-98`). Reports, Following UI, application new-message email, account settings/deletion, legal/safety pages, and admin UI remain absent (`docs/V1_PUNCHLIST.md:38-68`; route and component inventory below).

### Inspected baseline

- Repository baseline: `origin/main` at `37ac75fa23a1d16403fc8e032f2c974fb80dae7e` (`Merge branch 'kanban/t_c98399ae'`), inspected on branch `wt/t_5f7ddbee`. Git history claims below cite commit IDs because commits, unlike source files, have no repository-relative line numbers.
- The route/component/lib/test inventory is from that exact tree. `package.json:5-13` defines the available build/test scripts; `package.json:15-35` defines the installed runtime and development dependencies.
- No staging request, service operation, build, database operation, credential read, or live API probe was performed. `npm run build` was deliberately not run because it writes `.next/`, outside this commission's one-file write boundary.
- The only runtime validation run was the repository's existing read-only Node test command, `npm test`; it returned **210 tests, 210 pass, 0 fail, 0 skipped/cancelled/todo**. The command is defined at `package.json:9`.
- Repository execution records can establish what an owner-run sitting recorded. They cannot independently re-query the database today. Any present-tense database fact not explicitly established by a cited execution record is marked **NEEDS DB VERIFICATION**.
- Historical snapshots are retained as evidence even when later addenda supersede them. In particular, the 2026-08-10 body of `docs/research/PROJECT_STATUS_GROUND_TRUTH.md:1-311` must be read with its dated addenda at lines 315-372 and the newer rolling execution record.

### Classification rules

- Inventory `complete`: the item is wired and internally coherent for its current stated purpose, not necessarily the whole V1 product.
- Inventory `partial`: executable code exists, but a binding V1 behavior, active-profile conversion, error surface, or supporting route is missing.
- Inventory `dead code`: no production import/caller was found or the UI is intentionally inert.
- Feature `done`: current code and repository records satisfy the cited V1 slice.
- Feature `partial`: substantial code exists, with exact omissions listed.
- Feature `not started`: no product implementation was found.
- Feature `stale-doc-claims-otherwise`: the cited document's status statement is behind current code/records.

## 1. Repository inventory

### 1.1 App Router surfaces

No `loading.tsx`, `error.tsx`, `global-error.tsx`, `not-found.tsx`, `template.tsx`, `default.tsx`, `robots.ts`, or `sitemap.ts` exists under `app/`; the only nested layout is the recovery metadata layout (`app/auth/recovery/layout.tsx:1-9`). Therefore route-local loading/error/not-found handling and SEO robots/sitemap surfaces are absent. The broad dynamic `app/[handle]/page.tsx` also means unknown single-segment paths reach the profile-not-found UI rather than a dedicated 404 (`app/[handle]/page.tsx:240-290`).

| Route/file | Boundary | State | What it does / exact limitation |
|---|---|---:|---|
| `app/layout.tsx` | Server layout | partial | Loads fonts and one global title/description, then wraps all pages in `AuthBackdropShell`; it has no `metadataBase`, canonical, Open Graph, route-specific metadata, robots, or sitemap integration (`app/layout.tsx:1-46`; `docs/V1_PUNCHLIST.md:60-62`). |
| `app/globals.css` | Global stylesheet | complete | Central global/responsive styles consumed by the app; current source is the sole global CSS import (`app/layout.tsx:3-4`). |
| `app/page.tsx` (`/`) | Client page | partial | Loads three active-listing categories and seller spotlight from Supabase (`app/page.tsx:35-84`) and renders category/festival sections. It still renders a hard-coded five-ticket carousel (`app/page.tsx:18-24,107-114`), contrary to the decision to remove the hard-coded homepage ticket section (`docs/V1_DECISIONS.md:9`). It also has no post Hero implementation. |
| `app/browse/page.tsx` (`/browse`) | Server wrapper | complete | Supplies a Suspense boundary around the URL-backed client catalogue (`app/browse/page.tsx:1-11`); all behavior lives in `BrowsePageClient`. |
| `app/apparel/page.tsx` (`/apparel`) | Client page | complete | Active clothing listings with tag/price/sort filtering, featured rail, loading/empty states (`app/apparel/page.tsx:130-285`). |
| `app/jewellery/page.tsx` (`/jewellery`) | Client page | complete | Active accessories listing category with the same legacy category UI pattern (`app/jewellery/page.tsx:125-281`). |
| `app/music/page.tsx` (`/music`) | Client page | complete | Active gear/music listing category with the same pattern (`app/music/page.tsx:119-281`). |
| `app/art/page.tsx` (`/art`) | Server page | complete | Configures `StandardCategoryPage` for category `art` (`app/art/page.tsx:1-17`). |
| `app/tickets/page.tsx` (`/tickets`) | Server page | partial | Configures a real ticket category and safety banner (`app/tickets/page.tsx:1-18`), but TypeScript's canonical category union still omits `ticket` (`types/marketplace.ts:7-8`) and the homepage retains the obsolete hard-coded ticket rail (`app/page.tsx:18-24,107-114`). |
| `app/vintage/page.tsx` (`/vintage`) | Server page | complete | Configures `StandardCategoryPage` for vintage-condition listings (`app/vintage/page.tsx:1-17`). |
| `app/new-arrivals/page.tsx` (`/new-arrivals`) | Server page | complete | Configures all active listings, newest first, without a featured section (`app/new-arrivals/page.tsx:1-16`; `tests/category-pages.test.ts:347-356`). |
| `app/stream/page.tsx` (`/stream`) | Server page | partial | Server-normalizes `from`/`to` search parameters and passes them to the client (`app/stream/page.tsx:1-18`). The all-post chronological Stream is implemented, but the binding Following view/toggle is absent (`docs/DECISIONS_HANDOVER.md:44`; `components/StreamPageClient.tsx:237-382`). |
| `app/[handle]/page.tsx` (`/[handle]`) | Client dynamic page | partial | Public profile, Wall, active listings, owner edit/create controls, contact flow, and owner inbox (`app/[handle]/page.tsx:141-264,444-604`). It selects exactly one account profile (`app/[handle]/page.tsx:184-211`), directly “deletes” listings by setting `status='draft'` (`app/[handle]/page.tsx:49-62`), and tab buttons do not update distinct URLs (`app/[handle]/page.tsx:444-474`), contrary to `docs/V1_DECISIONS.md:30`. |
| `app/seller/[handle]/page.tsx` (`/seller/[handle]`) | Server dynamic redirect | complete | Permanent compatibility redirect to canonical `/${handle}` (`app/seller/[handle]/page.tsx:1-5`). |
| `app/listing/[id]/page.tsx` (`/listing/[id]`) | Client dynamic page | partial | Listing detail, gallery/lightbox, seller/related listings, auth gate, and contact-to-conversation flow (`app/listing/[id]/page.tsx:101-224,580-963`). Buyer identity still comes from the singleton compatibility bridge (`app/listing/[id]/page.tsx:119-146`), so active-profile and same-account-contact app behavior are pending. |
| `app/listing/[id]/edit/page.tsx` (`/listing/[id]/edit`) | Client dynamic page | partial | Auth/owner-gated edit with validation and uploads (`app/listing/[id]/edit/page.tsx:154-258`). It requires exactly one account profile (`app/listing/[id]/edit/page.tsx:175-185`) and has no dirty-switch behavior. |
| `app/listings/new/page.tsx` (`/listings/new`) | Client page | partial | Three-step direct-publish listing creation, image cover ordering, price parsing, validation, and R2 upload (`app/listings/new/page.tsx:198-441`). It resolves one profile at publish time (`app/listings/new/page.tsx:263-284`) and lacks the required “Posting as @handle (switch)”/dirty-switch semantics (`docs/V1_PUNCHLIST.md:28-33`). |
| `app/profile/edit/page.tsx` (`/profile/edit`) | Client page | partial | Owner profile editor with avatar/header upload and handle checks (`app/profile/edit/page.tsx:107-336`). It redirects through the singleton profile bridge (`app/profile/edit/page.tsx:128-133`) and exposes only the pre-vendor type union (`types/marketplace.ts:10-11`). |
| `app/messages/page.tsx` (`/messages`) | Client redirect | partial | Authenticates, selects the only profile, and redirects to its profile inbox query (`app/messages/page.tsx:1-21`); no active-profile provider exists. |
| `app/messages/[id]/page.tsx` (`/messages/[id]`) | Client dynamic redirect | partial | Redirects old thread URLs to `/messages` rather than selecting the requested thread (`app/messages/[id]/page.tsx:1-11`). |
| `app/festivals/page.tsx` (`/festivals`) | Client page | partial | Database-backed festival timeline/list/calendar UI (`app/festivals/page.tsx:32-719`). Current season seed completeness is **NEEDS DB VERIFICATION**; no repository test exercises its queries or interactions end to end. |
| `app/festivals/[slug]/page.tsx` (`/festivals/[slug]`) | Client dynamic page | partial | Event info, per-profile RSVP, Notice Board CRUD/reactions, search/filter/sort, and Realtime (`app/festivals/[slug]/page.tsx:155-686,734-844`). Actor identity is still the singleton profile (`app/festivals/[slug]/page.tsx:744-753`); no report control or admin transfer/moderation UI exists. |
| `app/login/page.tsx` (`/login`) | Client modal route | partial | App-owned email/password validation, safe next target, and modal route shell (`app/login/page.tsx:78-210`). Terms/privacy links point to absent routes (`app/login/page.tsx:197-202`). |
| `app/signup/page.tsx` (`/signup`) | Client modal route | partial | Signup form with handle availability and server API (`app/signup/page.tsx:124-218`). It creates only the initial personal profile and links to absent legal routes (`app/signup/page.tsx:293-298`); additional-profile onboarding is absent. |
| `app/forgot-password/page.tsx` (`/forgot-password`) | Client modal route | complete | Requests password recovery using the approved browser-origin redirect flow (`app/forgot-password/page.tsx:1-79`). |
| `app/auth/callback/page.tsx` (`/auth/callback`) | Client token page | complete | Scrubs callback credentials, handles implicit confirmation, and requires explicit signup-token confirmation (`app/auth/callback/page.tsx:15-102`). |
| `app/auth/recovery/layout.tsx` | Server nested layout | complete | Prevents referrer leakage for the recovery route via metadata (`app/auth/recovery/layout.tsx:1-9`). |
| `app/auth/recovery/page.tsx` (`/auth/recovery`) | Client token page | complete | Fragment-only recovery token intake and one-request password update UI (`app/auth/recovery/page.tsx:39-229`). |
| `app/update-password/page.tsx` (`/update-password`) | Client page | complete | Compatibility destination forwarding into the active recovery route while preserving query/hash (`app/update-password/page.tsx:1-18`). |
| `app/reset-password/page.tsx` (`/reset-password`) | Client page | complete | Legacy redirect to `/update-password` preserving query/hash (`app/reset-password/page.tsx:1-14`). |
| `app/api/auth/signup/route.ts` | Node API POST | partial | Validates signup, blocks reserved/taken handles, calls Supabase Auth, and completes/cleans profile creation (`app/api/auth/signup/route.ts:15-160`). Completion updates by `profiles.user_id` then `.single()` (`app/api/auth/signup/route.ts:124-129`), explicitly unsafe once one account can own siblings (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:156`). |
| `app/api/auth/recovery/update/route.ts` | Node API POST | complete | Force-dynamic wrapper enforcing origin and delegating the isolated recovery operation (`app/api/auth/recovery/update/route.ts:1-20`). |
| `app/api/r2/presign/route.ts` | Node API POST | partial | Validates declaration/index, authenticates, rate-limits, authorizes owner/resource, signs an intent, and presigns a private-bucket PUT (`app/api/r2/presign/route.ts:15-78`). Authorization proves account ownership, not active profile, until MP4-H/MP-6 (`lib/uploads/authorization.ts:11-66`; `docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:391-410`). |
| `app/api/r2/finalize/route.ts` | Node API POST/DELETE | partial | Re-verifies signed intent/auth/ownership, promotes or cleans quarantine (`app/api/r2/finalize/route.ts:10-55`). The same active-profile gap remains at finalize (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:157`). |

### 1.2 Components

| Component | State | Responsibility / evidence |
|---|---:|---|
| `components/layout/Header.tsx` | partial | Global desktop/mobile navigation, search, auth cache, avatar and unread badge (`components/layout/Header.tsx:15-40,70-124,185-395`). It calls `getOnlyProfileForCurrentAccount`, so multiple rows clear auth UI rather than offering the required active-profile switcher (`components/layout/Header.tsx:80-105`). |
| `components/layout/Footer.tsx` | partial | Shared footer shell. Newsletter input/button has no submit handler (`components/layout/Footer.tsx:22-33`); most links are inert spans, Contact points to a missing `/contact`, and legal labels are inert (`components/layout/Footer.tsx:6-10,36-68`). |
| `components/AuthBackdropShell.tsx` | complete | Preserves/restores scroll position around auth route transitions and provides the global backdrop shell (`components/AuthBackdropShell.tsx:1-48`). |
| `components/AuthModalFrame.tsx` | complete | Shared accessible visual modal frame and close behavior (`components/AuthModalFrame.tsx:1-39`). |
| `components/AuthRouteModal.tsx` | complete | Wraps route-based auth pages with dismiss navigation (`components/AuthRouteModal.tsx:1-20`). |
| `components/AuthModal.tsx` | partial | Inline login/signup modal with app validation and server signup (`components/AuthModal.tsx:1-431`); signup remains initial-profile-only and its legal links depend on absent routes. |
| `components/BrowsePageClient.tsx` | complete | Full-text `search_vector` query, active-only filter, category counts, price/sort filters, URL state, keyset pagination, loading/error/empty/end states (`components/BrowsePageClient.tsx:96-131,134-258,259-383`). |
| `components/Carousel.tsx` | complete | Generic responsive carousel used on the homepage (`components/Carousel.tsx:1-106`). |
| `components/CategoryFilterToolbar.tsx` | complete | Shared tag/sort/price popover toolbar for category routes (`components/CategoryFilterToolbar.tsx:1-207`). |
| `components/CategoryGrid.tsx` | complete | Homepage category grid with independent loading/empty behavior (`components/CategoryGrid.tsx:1-97`). |
| `components/EditListingModal.tsx` | partial | Profile-page listing edit modal, validation, cover ordering and R2 upload (`components/EditListingModal.tsx:164-308`); actor comes from a passed singleton profile ID. |
| `components/EditProfileModal.tsx` | partial | Profile-page edit modal with handle checks and exact-row update (`components/EditProfileModal.tsx:59-288`); no inactive-profile switch action or vendor option. |
| `components/FeaturedCategoryRail.tsx` | complete | Overflow-aware category featured rail with arrow/motion handling (`components/FeaturedCategoryRail.tsx:1-120`). |
| `components/FestivalSection.tsx` | complete | Homepage event section backed by `events` (`components/FestivalSection.tsx:72-180`). |
| `components/ImageLightbox.tsx` | complete | Shared keyboard/swipe image lightbox used by listings and posts (`components/ImageLightbox.tsx:1-163`; `tests/posts.test.ts:150-188`). |
| `components/MessagesInbox.tsx` | partial | Conversation list, unread clearing, Realtime thread inserts, text send, and per-profile hide (`components/MessagesInbox.tsx:43-158,160-316`). Participant/sender types are non-null and rendering assumes an available counterpart (`components/MessagesInbox.tsx:8-24,171-176`), so neutral deleted-profile history is not implemented. Send has no displayed failure/length-validation path (`components/MessagesInbox.tsx:117-138`). |
| `components/NewListingModal.tsx` | partial | Profile-page direct-publish modal with validation, price parsing, cover ordering, and uploads (`components/NewListingModal.tsx:144-293`); passed singleton actor and no switch semantics. |
| `components/PageHero.tsx` | complete | Shared fixed-height photo hero for Browse, Stream, and categories (`components/PageHero.tsx:1-51`). |
| `components/ProductCard.tsx` | complete | Shared listing card and canonical price display (`components/ProductCard.tsx:1-132`). |
| `components/ProfileAvatar.tsx` | complete | Shared image/fallback avatar with image error handling (`components/ProfileAvatar.tsx:1-69`). |
| `components/ProfileWall.tsx` | partial | Wall post mapping/cards, trusted RPC create/edit/delete/reactions, image uploads/lightbox, keyset pagination, members/public states, and highlight row/overlay (`components/ProfileWall.tsx:46-89,320-683,685-1000`). It uses the singleton reaction viewer and owner-page identity; inactive-profile switch/manage behavior remains absent. |
| `components/ScrollToTopButton.tsx` | complete | Shared threshold-based, reduced-motion-aware scroll-to-top control that hides behind overlays (`components/ScrollToTopButton.tsx:1-125`). |
| `components/SellerCard.tsx` | complete | Homepage seller spotlight card (`components/SellerCard.tsx:1-79`). |
| `components/StandardCategoryPage.tsx` | complete | Shared active-listing category loader, local tag/price/sort filtering, featured rail, loading and empty states (`components/StandardCategoryPage.tsx:139-337`). |
| `components/StreamPageClient.tsx` | partial | Public chronological Stream with server-validated local date presets/custom range, keyset pagination, post cards, reactions, and terminal states (`components/StreamPageClient.tsx:62-235,237-486`). No Following view, profile-follow toggle, or scoped post search exists. |
| `components/TicketCard.tsx` | dead code | Production import exists only to render the obsolete hard-coded homepage ticket carousel (`app/page.tsx:9,18-24,107-114`; `components/TicketCard.tsx:1-57`). Removing that carousel per `docs/V1_DECISIONS.md:9` removes this component's only production purpose. |
| `components/Waveform.tsx` | complete | Shared decorative/semantic SVG terminal marker used by Browse (`components/Waveform.tsx:1-48`). |

### 1.3 Library modules

| Module | State | Responsibility / evidence |
|---|---:|---|
| `lib/auth/callback-flow.ts` | complete | Parses/executes supported automatic callback credentials and explicit signup verification (`lib/auth/callback-flow.ts:1-70`). |
| `lib/auth/initial-snapshot-gate.ts` | complete | Prevents stale initial auth snapshots from overwriting later auth events and coordinates Wall refresh modes (`lib/auth/initial-snapshot-gate.ts:1-56`). |
| `lib/auth/recovery-update.ts` | complete | Isolated verify → revoke others → update password → cleanup orchestration with safe errors (`lib/auth/recovery-update.ts:1-137`). |
| `lib/auth/safety.ts` | complete | Exact origin/redirect policy, fragment token/callback parsing, email/handle validation, availability, and friendly provider errors (`lib/auth/safety.ts:7-261`). |
| `lib/auth/signup-completion.ts` | partial | Distinguishes duplicate/new users and fail-closed cleanup (`lib/auth/signup-completion.ts:3-75`), but caller completion still targets one profile per account (`app/api/auth/signup/route.ts:124-129`). |
| `lib/auth/ui-transition.ts` | complete | Coordinates auth UI refresh participants so modal transitions wait for registered surfaces (`lib/auth/ui-transition.ts:1-113`). |
| `lib/browse-hero.ts` | complete | Rotation-ready Browse hero image configuration (`lib/browse-hero.ts:1-7`). |
| `lib/browse-state.ts` | complete | Enum-backed URL parsing, href building, price bounds, query plan, deterministic keyset cursors (`lib/browse-state.ts:1-130`). Note: it includes `ticket` at line 4 while the canonical marketplace type omits it (`types/marketplace.ts:7-8`). |
| `lib/constants.ts` | partial | Shared listing category/condition labels and featured badges (`lib/constants.ts:1-19`); category typing inherits the missing `ticket` union. |
| `lib/db.private.server.ts` | dead code | Server-only wrapper for `admin_get_profile_account` (`lib/db.private.server.ts:1-40`); no application route/component imports it, and the dedicated admin account-linkage panel is absent. |
| `lib/db.ts` | partial | Public 12-column profile contract, mappers, owner-list/ownership RPC wrappers, singleton bridge, listing mapper (`lib/db.ts:4-113`). `getOnlyProfileForCurrentAccount` deliberately throws for multiple rows (`lib/db.ts:71-80`), making it a compatibility stopgap rather than active-profile support. |
| `lib/email-templates/reset-password.html` | complete | Repository copy of the reset-password HTML body (`lib/email-templates/reset-password.html:1-11`); dashboard use is owner-managed, not loaded by application code. |
| `lib/homepage/categories.ts` | complete | Independent async category loading and loading/empty-state helpers (`lib/homepage/categories.ts:1-33`). |
| `lib/listings/images.ts` | complete | Immutable cover-selection helper moving a selected image to array index zero (`lib/listings/images.ts:1-4`). |
| `lib/listings/price.ts` | complete | Strict comma/dot price parser and two-decimal EUR formatter (`lib/listings/price.ts:1-18`). |
| `lib/listings/validation.ts` | complete | Shared 20–2,000-character listing description validation and safe write error mapping (`lib/listings/validation.ts:1-25`). |
| `lib/mock-data.ts` | dead code | Large mock profile/listing catalogue (`lib/mock-data.ts:1-430`) with no production/test import found; current pages query Supabase. |
| `lib/navigation/scroll-reset.ts` | complete | Shared full-navigation scroll marker/reload/assign/restore helpers (`lib/navigation/scroll-reset.ts:1-52`). |
| `lib/posts/date-range-presets.ts` | complete | Resolves all/7-day/30-day/year presets using viewer-local calendar arithmetic (`lib/posts/date-range-presets.ts:1-27`). |
| `lib/posts/date-range.ts` | complete | Validates date-only URL inputs, corrects reversed ranges, computes local inclusive/exclusive bounds, serializes query (`lib/posts/date-range.ts:1-65`). |
| `lib/posts/highlights.ts` | complete | Highlight limit message, timestamp ordering, error translation, 80-character preview (`lib/posts/highlights.ts:1-35`). |
| `lib/posts/reactions.ts` | complete | Canonical six-reaction SVG/code set, row normalization, counts, and optimistic mutation (`lib/posts/reactions.ts:1-111`). |
| `lib/posts/use-reaction-viewer.ts` | partial | Auth-aware hook supplying a reaction actor (`lib/posts/use-reaction-viewer.ts:1-57`); it uses the singleton bridge at lines 26-31 rather than active profile. |
| `lib/posts/validation.ts` | complete | Post length/error handling and HTTP(S)-only auto-link tokenization (`lib/posts/validation.ts:1-81`). |
| `lib/rail-scroll-animation.ts` | complete | Reduced-jump target calculation and custom eased rail scrolling with behavior restoration (`lib/rail-scroll-animation.ts:1-61`). |
| `lib/stream-hero.ts` | complete | Rotation-ready Stream hero image configuration (`lib/stream-hero.ts:1-7`). |
| `lib/supabase/client.ts` | complete | Browser Supabase SSR client factory (`lib/supabase/client.ts:1-8`). |
| `lib/supabase/server.ts` | complete | Cookie-aware server Supabase client factory (`lib/supabase/server.ts:1-24`). |
| `lib/supabase/recovery-server.ts` | complete | Isolated anon-key recovery provider client with required config checks (`lib/supabase/recovery-server.ts:1-17`). |
| `lib/uploads/auth-server.ts` | complete | Cookie-aware upload-route auth client (`lib/uploads/auth-server.ts:1-16`). |
| `lib/uploads/authorization.ts` | partial | Ban and profile/resource ownership checks for profile/listing/post/event uploads (`lib/uploads/authorization.ts:1-66`). It proves account ownership through `current_user_owns_profile`, not session-active identity. |
| `lib/uploads/cleanup-policy.ts` | complete | Canonical public URL/key reference matching and controlled promoted-key candidates (`lib/uploads/cleanup-policy.ts:1-36`). |
| `lib/uploads/cleanup-server.ts` | complete | Double-checks complete references before deleting an owned quarantine object (`lib/uploads/cleanup-server.ts:1-24`). |
| `lib/uploads/client.ts` | complete | Browser decode/downscale/re-encode, presign/private PUT/finalize client flow (`lib/uploads/client.ts:1-153`). |
| `lib/uploads/intent-server.ts` | complete | Constructs signed owner/resource/index-bound upload intents and keys (`lib/uploads/intent-server.ts:1-49`). |
| `lib/uploads/lifecycle.ts` | complete | Encodes 14-day report-only orphan policy and the two private immediate-delete reasons (`lib/uploads/lifecycle.ts:1-22`). |
| `lib/uploads/policy.json` | complete | Central MIME, resize/quality, size, folder, and count configuration (`lib/uploads/policy.json:1-13`). |
| `lib/uploads/policy.ts` | complete | Typed accessors and declaration/index/MIME/signature/resize validation over policy JSON (`lib/uploads/policy.ts:1-89`). |
| `lib/uploads/promotion-server.ts` | complete | Head/signature verification, create-only public promotion, public verification, and quarantine cleanup (`lib/uploads/promotion-server.ts:1-136`). |
| `lib/uploads/r2-server.ts` | complete | Server-only R2 clients/config, private/public object operations, signatures, copy/delete/presign (`lib/uploads/r2-server.ts:1-123`). |
| `lib/uploads/rate-limit-server.ts` | complete | Fail-closed wrapper for account-level database upload-intent quota with safe diagnostics (`lib/uploads/rate-limit-server.ts:1-59`). |
| `lib/uploads/references-server.ts` | complete | Paginated complete media-reference reads across profiles/listings/posts/events and canonical key test (`lib/uploads/references-server.ts:1-62`). |
| `lib/uploads/token.ts` | complete | HMAC upload-token issue/verification with timing-safe signature, expiry, purpose/key reconstruction (`lib/uploads/token.ts:1-75`). |
| `lib/uploads/trusted-upload-server.ts` | complete | Separate service-role trusted import path with explicit account/profile/resource authorization, shared quota, private upload and promotion (`lib/uploads/trusted-upload-server.ts:1-222`). It intentionally does not use browser session-active semantics (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:158`). |

### 1.4 Relevant shared types and server/client boundary observations

- `types/marketplace.ts:32-49` keeps the browser public profile contract free of owner/account fields; `lib/db.ts:4-57` maps the exact public/owner contracts.
- Current TypeScript profile types omit the database-authored `vendor` label (`types/marketplace.ts:10-11` versus `supabase/chunks/mp3-foundation-apply.sql:26`), and listing categories omit `ticket` (`types/marketplace.ts:7-8` versus `lib/browse-state.ts:3-4`). These are dormant/latent mismatches while user-visible Multi-Profile/vendor enablement remains absent.
- Most pages are client components and query Supabase from the browser. The server boundaries are the root/recovery layouts, thin Browse/Stream/config routes, redirect routes, and four API handlers listed above. Server-only sensitive helpers live in `lib/db.private.server.ts`, `lib/supabase/*server.ts`, and `lib/uploads/*server.ts`; static tests prohibit importing the private admin helper into UI (`tests/profile-contract.test.ts:169-188`).

## 2. Multi-Profile / Umbrella Model re-baseline

### 2.1 Document reconciliation

| Source | What it is authoritative for | Current reading |
|---|---|---|
| `docs/MULTI_PROFILE_PROPOSAL.md` | Binding product decisions and MP-0…MP-14 target/ordering (`docs/MULTI_PROFILE_PROPOSAL.md:38-74,1004-1179`) | Its header still says “implementation proposal only / Not implemented” (`docs/MULTI_PROFILE_PROPOSAL.md:3-11`). Treat that as the proposal's original status, not current execution truth. |
| `docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md` | Package design, ordering, actor/app inventory, evidence gates (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:88-160,228-416`) | Scope remains useful; header and final disposition are stale at A+B (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:3-5,552-562`). |
| `docs/SLICE_MP4_EXECUTION_RECORD.md` | Single running source for what owner-run Slice MP4 sittings recorded (`docs/SLICE_MP4_EXECUTION_RECORD.md:8-12`) | Records MP4-A, B, C, D live/verified and E-H not authored/applied (`docs/SLICE_MP4_EXECUTION_RECORD.md:14-23`). This is the current repository execution truth. |
| `docs/DECISIONS_HANDOVER.md` | Product/business decisions; explicitly not implementation authority (`docs/DECISIONS_HANDOVER.md:1-6`) | Correctly summarizes A-D of eight and all visible Multi-Profile UI as unimplemented (`docs/DECISIONS_HANDOVER.md:89-98`). |

Repository record conclusion: MP-3 foundation and Slice MP4-A…D have owner-run live/verified records; the one-profile unique index remains in force and user-visible Multi-Profile remains disabled (`docs/MP3_FOUNDATION_VERIFICATION.md:1-12`; `docs/SLICE_MP4_EXECUTION_RECORD.md:14-23`; `docs/DECISIONS_HANDOVER.md:95-98`). Current catalog confirmation is **NEEDS DB VERIFICATION**.

### 2.2 Relevant SQL package inventory

Every apply package below is paired with guards/verification and rollback; repository presence is not itself live-state proof.

| Package/files | Repository-authored contents | Recorded status |
|---|---|---|
| MP-1 Package A: `supabase/chunks/mp1-package-a-preflight.sql`, `mp1-package-a-owner-review-extract.sql` | Read-only baseline/catalog/ACL extraction and guards; no apply artifact (`supabase/chunks/mp1-package-a-preflight.sql:1-2319`; `supabase/chunks/mp1-package-a-owner-review-extract.sql:1-311`). | Authored read-only evidence package; not an apply package (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:145-158`). |
| MP-1 Package B: `mp1-package-b-{preflight,apply,verify,rollback}.sql` | Adds `get_my_profiles`, `current_user_owns_profile`, private admin account grouping and exact ACLs (`supabase/chunks/mp1-package-b-apply.sql:112-239`). | Repository records say applied (`docs/DECISIONS_HANDOVER.md:91-93`; `docs/research/PROJECT_STATUS_GROUND_TRUTH.md:326-334` for later privacy context). Current catalog: **NEEDS DB VERIFICATION**. |
| MP-1 Package D/privacy: `mp1-package-d-{preflight,apply,verify,rollback}.sql` | Database-enforces the 12-column public profile contract via table/column ACL cutover (`supabase/chunks/mp1-package-d-apply.sql:1-550`; `lib/db.ts:4-21`). | Owner-run GO 33/33 and REST denial/safe-read record (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:326-334`). Current catalog: **NEEDS DB VERIFICATION**. |
| Legacy compatibility conversion: `mp4-policy-conversion-{preflight,apply,verify,rollback}.sql` plus `mp4-darktribo-ban-fixture-*` | Converts 22 policy/10 function ownership checks to reviewed helper-based compatibility authorization; fixture proves banned-owner denial (`supabase/chunks/mp4-policy-conversion-apply.sql:1-3284`; fixture files `supabase/chunks/mp4-darktribo-ban-fixture-preflight.sql:1-271`, `...-apply.sql:1-303`, `...-verify.sql:1-93`, `...-unban.sql:1-159`, `...-unban-verify.sql:1-115`). | Owner-run applied/verified 2026-08-11 record (`docs/DECISIONS_HANDOVER.md:94`; `docs/research/PROJECT_STATUS_GROUND_TRUTH.md:315-322`). Current catalog: **NEEDS DB VERIFICATION**. |
| MP-3 foundation: `mp3-foundation-{preflight,apply,verify,rollback}.sql` | Adds dormant `vendor`, five-cap/owner immutability, private per-session active-profile state, get/switch/create helpers while retaining one-profile uniqueness (`supabase/chunks/mp3-foundation-apply.sql:26,156-320`; rollback boundaries `supabase/chunks/mp3-foundation-rollback.sql:80-104`). | Owner-run GO 19/19 2026-08-13; one-profile lock retained (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:339-350`; `docs/DECISIONS_HANDOVER.md:96`). Current catalog: **NEEDS DB VERIFICATION**. |
| Slice MP4-A: `slice-mp4-a-{preflight,apply,verify,rollback}.sql` | Adds private read-only active resolver and three authenticated public active/equality/active-unsuspended helpers (`supabase/chunks/slice-mp4-a-apply.sql:98-181`). | Live/verified record, 2026-08-15 (`docs/SLICE_MP4_EXECUTION_RECORD.md:27-71`). Current catalog: **NEEDS DB VERIFICATION**. |
| Slice MP4-B: `slice-mp4-b-{preflight,apply,verify,rollback}.sql` | Converts five profile/listing policies to active authority and revokes authenticated direct profile INSERT while preserving public reads/signup (`docs/SLICE_MP4_EXECUTION_RECORD.md:75-123`; package files `supabase/chunks/slice-mp4-b-apply.sql:1-311`). | Live/verified record, 2026-08-15 (`docs/SLICE_MP4_EXECUTION_RECORD.md:97-123`). Current catalog: **NEEDS DB VERIFICATION**. |
| Slice MP4-C: `slice-mp4-c-{preflight,apply,verify,rollback}.sql` | Alters favorites, follows, RSVPs, Notice Board posts/reactions, and event notification actor policies to active identity (`supabase/chunks/slice-mp4-c-apply.sql:94-106`). | Live/verified record, 2026-08-15 (`docs/SLICE_MP4_EXECUTION_RECORD.md:127-173`). Current catalog: **NEEDS DB VERIFICATION**. |
| Slice MP4-D: `slice-mp4-d-{preflight,apply,verify,rollback}.sql`, `slice-mp4-d-disposable-{harness.sh,runtime.sql}` | Replaces five Wall post/reaction RPCs with active-authority implementations; runtime harness drops the one-profile index only in a disposable fixture (`supabase/chunks/slice-mp4-d-apply.sql:105-356`; `supabase/chunks/slice-mp4-d-disposable-runtime.sql:1-136`). | Live/verified record, 2026-08-15, plus app-layer staging proof recorded 2026-08-16 (`docs/SLICE_MP4_EXECUTION_RECORD.md:177-208`). Current catalog: **NEEDS DB VERIFICATION**. |
| Slice MP4-E/F/G/H | Planned dormant messaging nullability, messaging policies, messaging RPCs/triggers, and browser upload active-authorization contract (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:323-410`). | No corresponding package files exist; execution table says not authored/applied (`docs/SLICE_MP4_EXECUTION_RECORD.md:20-23`). |
| Wall highlights: `wall-highlights-{preflight,apply,verify,rollback}.sql`, disposable runtime/harness/concurrency shell | Adds post highlight columns, active-profile toggle RPC, maximum-five fence, locking/quota/rate-limit verification and disposable concurrency proof (`supabase/chunks/wall-highlights-apply.sql:1-333`; harnesses `supabase/chunks/wall-highlights-disposable-runtime.sql:1-128`, `...-concurrency.sh:1-41`). | Execution/verification record says database foundation and app slice complete/live/verified (`docs/DECISIONS_HANDOVER.md:146-158`; `docs/WALL_HIGHLIGHTS_FOUNDATION_VERIFICATION.md:1-91`). Current catalog: **NEEDS DB VERIFICATION**. |

### 2.3 App locations that still assume one profile per account

The compatibility function intentionally rejects more than one row rather than selecting arbitrarily (`lib/db.ts:59-80`; `tests/profile-contract.test.ts:65-81`). Every current consumer therefore becomes unavailable or incomplete when cardinality opens:

1. Header identity, avatar, unread badge/cache: `components/layout/Header.tsx:70-105`.
2. Reaction viewer used by Wall and Stream: `lib/posts/use-reaction-viewer.ts:18-40`.
3. Canonical profile owner/contact/inbox state: `app/[handle]/page.tsx:184-220`.
4. Listing-detail contact buyer: `app/listing/[id]/page.tsx:119-146`.
5. Standalone listing creation actor: `app/listings/new/page.tsx:263-284`.
6. Standalone listing editing owner: `app/listing/[id]/edit/page.tsx:175-185`.
7. Profile editing target: `app/profile/edit/page.tsx:128-133`.
8. Messages root redirect: `app/messages/page.tsx:8-18`.
9. Festival RSVP/Notice actor: `app/festivals/[slug]/page.tsx:744-753`.
10. Signup completion's `.eq('user_id').single()` target: `app/api/auth/signup/route.ts:124-129`.
11. Browser upload authorization accepts any owned profile rather than current active profile: `lib/uploads/authorization.ts:11-29`; presign/finalize both call it (`app/api/r2/presign/route.ts:41-68`; `app/api/r2/finalize/route.ts:21-37`).
12. Passed-ID modal flows inherit the singleton caller: `components/NewListingModal.tsx:144-293`, `components/EditListingModal.tsx:164-308`, and `components/EditProfileModal.tsx:59-288`.
13. Inbox state is parameterized by one `myProfileId`, but has no global active-profile source/reset and non-null counterpart assumptions (`components/MessagesInbox.tsx:43-110`).
14. Profile Wall owner authority is derived from page ownership and singleton reaction hook, not a global active profile (`app/[handle]/page.tsx:264,470-472`; `components/ProfileWall.tsx:685-1000`).

### 2.4 What remains before Multi-Profile is usable

- MP4-E through H must be freshly evidenced/authored/reviewed/owner-applied; their exact scope is messaging retention/authorization and browser-upload active enforcement (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:323-410`; `docs/SLICE_MP4_EXECUTION_RECORD.md:20-23`).
- MP-5 through MP-14 application/deletion/launch slices remain after the database foundation (`docs/MULTI_PROFILE_PROPOSAL.md:1062-1179`).
- Required visible product work includes active Header/provider, five-profile create/switch/manage, vendor typing/onboarding, posting-as hints, dirty-form switch confirmation, per-profile inbox/Following/festivals, same-account contact denial, neutral retained conversations, profile deletion, account deletion, admin sibling panel, and full privacy/Realtime/email/R2 verification (`docs/DECISIONS_HANDOVER.md:55-87`; `docs/V1_PUNCHLIST.md:45-69`).
- Whether recorded database packages still match the current live catalog is **NEEDS DB VERIFICATION**.

## 3. Feature-by-feature V1 status

| Feature | Status | Implemented evidence | Exact missing work |
|---|---:|---|---|
| Search / browse | **done** for listing search slice | Header submits `q` to Browse (`components/layout/Header.tsx:156-161,287-313`); Browse uses full-text `search_vector`, category/price/sort, URL state, keyset pagination and honest terminal states (`components/BrowsePageClient.tsx:96-131,134-258,315-358`); tests cover all (`tests/browse-page.test.ts:8-191`, `tests/browse-state.test.ts:13-107`). | Global “search everything” and scoped post search are V1.1 decisions, not current V1 listing-search scope (`docs/DECISIONS_HANDOVER.md:50-53`). Owner-requested visual polish is subjective/open in docs (`docs/DECISIONS_HANDOVER.md:197-202`). |
| Category pages | **partial** | Seven routed categories/new arrivals use database active listings and shared/legacy filters (`app/art/page.tsx:1-17`, `app/tickets/page.tsx:1-18`, `app/vintage/page.tsx:1-17`, `components/StandardCategoryPage.tsx:139-337`; legacy pages cited above). | Canonical TypeScript categories omit `ticket` (`types/marketplace.ts:7-8`); homepage still has hard-coded ticket cards (`app/page.tsx:18-24,107-114`); final taxonomy remains a punch-list dependency (`docs/V1_PUNCHLIST.md:35-43`). |
| Stream | **partial** | Chronological public `show_in_stream=true` posts, local-date presets/custom range, keyset pagination and reactions (`components/StreamPageClient.tsx:89-147,189-235,237-382`). | Following/all toggle, active-profile follows, friendly no-follows state and URL view are absent (`docs/DECISIONS_HANDOVER.md:44`; `components/StreamPageClient.tsx:237-382`). |
| Wall / posts | **partial** | Post create/edit/hard-delete, public/members visibility, images, auto-links, reactions, pagination, highlights (`components/ProfileWall.tsx:320-1000`; `lib/posts/validation.ts:1-81`). | Active-profile management/switch hint and inactive-owner “Switch to manage” are absent; profile tabs do not have distinct URLs (`app/[handle]/page.tsx:444-474`; `docs/V1_DECISIONS.md:30`; `docs/DECISIONS_HANDOVER.md:64-75`). Inline admin Hero/delete controls and report controls are absent. |
| Wall highlights | **done** | App toggle, circles, overlay, limit handling (`components/ProfileWall.tsx:488-567,685-837`); repository execution record marks foundation/app complete (`docs/DECISIONS_HANDOVER.md:146-158`; `docs/WALL_HIGHLIGHTS_FOUNDATION_VERIFICATION.md:1-91`). | Current live catalog/staging recheck: **NEEDS DB VERIFICATION**. |
| Messaging | **partial** | Contact-to-thread creation, inbox, text send, unread markers, Realtime insert subscription, per-profile hide (`app/listing/[id]/page.tsx:119-224`; `components/MessagesInbox.tsx:43-158`). | MP4-E/F/G; active-profile source/reset; same-account neutral block; nullable deleted counterpart/sender rendering; stronger send failure/length UX; active-profile route/thread selection; product notification email (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:323-389`; `docs/V1_PUNCHLIST.md:45-49`). |
| Listings | **partial** | Direct active create/edit, description validation, price parser/formatter, up-to-five images, cover reordering, R2 quarantine pipeline (`app/listings/new/page.tsx:198-441`; `components/EditListingModal.tsx:164-308`; `lib/listings/images.ts:1-4`; `lib/listings/price.ts:1-18`). | Active-profile posting/switch protection; truthful Unpublish/Delete distinction; Mark Sold; dead/legacy homepage ticket removal; canonical ticket type; full server-side active ownership after MP4-H/MP-6 (`app/[handle]/page.tsx:49-62`; `docs/V1_PUNCHLIST.md:28-36`). |
| Festivals | **partial** | Timeline/detail, RSVP, Notice Board create/delete/reactions/search/filter/Realtime (`app/festivals/page.tsx:581-719`; `app/festivals/[slug]/page.tsx:155-686,734-844`). MP4-C's execution record establishes owner-run active-policy application (`docs/SLICE_MP4_EXECUTION_RECORD.md:127-173`). | Active app identity, sibling journey testing, admin moderation/created-event transfer, report control, and final season seed. Current data/seed: **NEEDS DB VERIFICATION** (`docs/V1_PUNCHLIST.md:51-55`). |
| Follows / Following | **not started** in application | Database policy package is authored and recorded applied through MP4-C (`supabase/chunks/slice-mp4-c-apply.sql:96-97`; `docs/SLICE_MP4_EXECUTION_RECORD.md:127-173`). | No follow/unfollow UI, count surface, Stream Following view, active-profile feed, or app tests. `StreamPageClient` has only time range and all-post query (`components/StreamPageClient.tsx:105-114,237-382`). Current DB rows/catalog: **NEEDS DB VERIFICATION**. |
| Reports / flags | **not started** | Product decision specifies logged-in reports for posts/listings/profiles/conversations/notices, dedup, burst limit, admin email, reason email, and public report address (`docs/DECISIONS_HANDOVER.md:35-43`). | No route, component, API, lib module, test, or SQL package for a report submission/case flow appears in the inventories. |
| Moderation / admin | **partial** | Versioned SQL contains role/ban, listing moderation, notice deletion, Wall moderation/Hero and private account-linkage functions (`supabase/chunks/chunk-1-admin-ban-apply.sql:1-332`; `supabase/chunks/chunk-4-admin-moderation-apply.sql:1-104`; `supabase/chunks/chunk-11c-wall-reactions-moderation-apply.sql:1-590`; `lib/db.private.server.ts:1-40`). | No admin route, role-aware UI, inline moderation/Hero controls, Auth `banned_until` synchronization, appointment UI, or dedicated sibling panel. Current live DB functions/roles: **NEEDS DB VERIFICATION**. |
| Account settings | **not started** | `User` type includes an email-notification boolean (`types/marketplace.ts:16-22`), but no route/consumer exists. | Settings hub, application-email opt-out, password links, multi-profile management, profile deletion, account deletion, tombstone and final-super-admin safeguards (`docs/V1_PUNCHLIST.md:54-55`). |
| Legal / safety | **not started** | Auth pages link to intended terms/privacy paths (`app/login/page.tsx:197-202`; `app/signup/page.tsx:293-298`). | No Impressum, privacy, terms/AGB, cookie, contact, or safety route exists; footer labels are inert/misdirected (`components/layout/Footer.tsx:6-10,36-68`; `docs/V1_PUNCHLIST.md:57-58`). |
| Email | **partial** | Auth signup/recovery application flows exist (`app/api/auth/signup/route.ts:15-160`; `app/api/auth/recovery/update/route.ts:1-20`). Repository owner checklist records live Supabase→All-Inkl DKIM/SPF/DMARC pass for recovery (`docs/ITEM_2_AUTH_SMTP_DNS_OWNER_CHECKLIST.md:142-155`). | New-message application SMTP sender, unread delay/throttle/idempotency, contacted-profile naming, opt-out setting, same-account suppression, Gmail launch gate, DMARC hardening (`docs/V1_DECISIONS.md:11-12`; `docs/V1_PUNCHLIST.md:48-49`; `docs/ITEM_2_AUTH_SMTP_DNS_OWNER_CHECKLIST.md:103,155`). Current mail/DNS/dashboard state: **NEEDS DB VERIFICATION** where database-backed settings are concerned; non-database owner systems also require fresh owner verification. |
| Authentication / recovery | **done** in code, launch-gated operationally | Safe redirect/origin/token handling and isolated recovery ordering are implemented/tested (`lib/auth/safety.ts:7-261`; `lib/auth/recovery-update.ts:46-137`; `tests/auth-safety.test.ts:168-1012`). | Full owner launch checklist remains partially unchecked (`docs/ITEM_2_AUTH_SMTP_DNS_OWNER_CHECKLIST.md:207-225`). |
| Homepage / discovery | **partial** | Active category rows, seller spotlight, events (`app/page.tsx:35-105`). | Binding post Hero/fallback is absent (`docs/V1_DECISIONS.md:31`; `app/page.tsx:86-119`), and hard-coded tickets remain contrary to decision. |
| SEO / launch operations | **not started** beyond global metadata | One global title/description (`app/layout.tsx:30-34`). | `metadataBase`, canonical/dynamic metadata, OG, robots, sitemap, monitoring, Vercel production setup and launch acceptance (`docs/V1_PUNCHLIST.md:60-70`). |

## 4. Test suite inventory

### 4.1 Actual run

`npm test` (`package.json:9`) executed all `tests/*.test.ts` through Node's built-in test runner with TypeScript stripping. Result on the inspected tree: **210 tests; 210 passed; 0 failed; 0 cancelled; 0 skipped; 0 todo**. This updates the earlier 145-test snapshot at `docs/research/PROJECT_STATUS_GROUND_TRUTH.md:259-270`.

### 4.2 Complete suite by file

| Test file | Tests | Kind | Coverage |
|---|---:|---|---|
| `tests/app-polish.test.ts` | 9 | Static/source assertions | Spotlight query, auth form validation/copy, recovery UI, festival RSVP/button/Notice naming/delete isolation, legacy reset redirect, QA handover (`tests/app-polish.test.ts:16-124`). |
| `tests/auth-safety.test.ts` | 50 | Unit + dependency-injected orchestration + static source | Auth snapshot/transition concurrency, safe redirects/origins, callback/token handling, email/handle validation, signup completion cleanup, isolated recovery order/errors/session cleanup, route/modal/link styling (`tests/auth-safety.test.ts:46-1012`). |
| `tests/browse-page.test.ts` | 14 | Static/source assertions | Browse query wiring, counts, cents, terminal states, toolbar/accessibility/mobile layout, Suspense, hero and header entry (`tests/browse-page.test.ts:8-191`). |
| `tests/browse-state.test.ts` | 9 | Pure unit | URL parsing/building, category enum, price bounds, query plans and three keyset order/cursor modes (`tests/browse-state.test.ts:13-107`). |
| `tests/category-pages.test.ts` | 12 | Static/source assertions | Art/tickets/vintage/new arrivals routes, shared category behavior, card containment, grids/heroes/rails/toolbars/nav, ticket banner (`tests/category-pages.test.ts:29-356`). |
| `tests/homepage-categories.test.ts` | 4 | Unit + async fakes | Independent loading/empty/rejection/cancellation behavior (`tests/homepage-categories.test.ts:13-118`). |
| `tests/listing-price.test.ts` | 6 | Pure unit + static source | Cover reorder, comma/dot parsing/rejection, create preview/storage formatting, cover controls; explicitly asserts `Save Draft` is absent (`tests/listing-price.test.ts:8-45`). |
| `tests/listing-validation.test.ts` | 4 | Unit + static source | Description bounds, safe DB errors, form limits, validation before upload intent (`tests/listing-validation.test.ts:13-70`). |
| `tests/post-reactions.test.ts` | 4 | Pure unit + static source | Canonical reaction map, normalization/count/viewer state, optimistic toggles, trusted RPC wiring (`tests/post-reactions.test.ts:22-107`). |
| `tests/posts.test.ts` | 19 | Unit + static/source contract | Highlight helpers/order, post validation/error/linkification, Wall trusted RPC/upload/visibility/pagination/concurrency/editor/lightbox/highlights/layout, Stream query/pagination/date/author/nav (`tests/posts.test.ts:19-338`). |
| `tests/price-format.test.ts` | 2 | Unit + repository source scan | Exact EUR cents and enforcement of shared formatter at price display sites (`tests/price-format.test.ts:20-33`). |
| `tests/profile-contract.test.ts` | 6 | Unit + repository source scan | Exact 12-column public contract, singleton fail-closed bridge, owner/admin RPC wrappers, wildcard/private-column bans, UI import boundary (`tests/profile-contract.test.ts:50-188`). |
| `tests/scroll-reset.test.ts` | 5 | Unit + static source | Reload/assign/restore marker and navigation integration (`tests/scroll-reset.test.ts:52-120`). |
| `tests/scroll-to-top.test.ts` | 5 | Static/source assertions | Shared placement, threshold/motion, blocker states, Header drawer behavior, visual/sticky constraints (`tests/scroll-to-top.test.ts:8-87`). |
| `tests/stream-date-range.test.ts` | 9 | Pure unit | Presets, DST/local arithmetic, invalid/reversed/one-sided inputs, inclusive local bounds and years below 100 (`tests/stream-date-range.test.ts:17-109`). |
| `tests/stream-page-layout.test.ts` | 4 | Static/source assertions | Stream hero, preset/custom popover, focus ring, retained URL/query predicates (`tests/stream-page-layout.test.ts:8-78`). |
| `tests/trusted-cli-upload.test.ts` | 11 | Dependency-injected unit + static source | Private upload/promotion ordering, quota fail-closed, non-injectable production wrapper, token/resource/owner/replay controls, post rejection, description-before-upload, no public cleanup (`tests/trusted-cli-upload.test.ts:73-256`). |
| `tests/upload-cleanup.test.ts` | 3 | Pure unit + static source | Canonical references, promoted candidates, complete post-image scanners (`tests/upload-cleanup.test.ts:14-46`). |
| `tests/upload-intent.test.ts` | 5 | Pure unit | Token round-trip/tamper/expiry/key reconstruction and bounded listing/post slots (`tests/upload-intent.test.ts:22-68`). |
| `tests/upload-policy.test.ts` | 10 | Pure unit + dependency-injected authorization + static source | Central limits, bounded slots, resource ownership, declaration/MIME/signature/selection/resize, immediate cleanup conditions (`tests/upload-policy.test.ts:27-186`). |
| `tests/upload-rate-limit-server.test.ts` | 11 | Dependency-injected unit + static SQL/source | Auth/service identity arguments, allowed/limited/unavailable behavior, safe diagnostics, malformed/thrown failures, process-local removal, 20/10-minute SQL quota (`tests/upload-rate-limit-server.test.ts:30-196`). |
| `tests/upload-server-config.test.ts` | 2 | Unit | Private bucket and dedicated high-entropy token-secret fail-closed checks (`tests/upload-server-config.test.ts:21-43`). |
| `tests/upload-server-pipeline.test.ts` | 6 | Dependency-injected unit + static source | Shared intent and promotion order/errors/replay wrapper, production non-injectability and route delegation (`tests/upload-server-pipeline.test.ts:29-151`). |
| **Total** | **210** |  | Matches actual runner output. |

### 4.3 Test-type reality and largest gaps

- **Static/source tests dominate UI coverage.** Many suites read source text and assert patterns; they do not render React, execute a browser, or prove user interactions. Examples: `tests/browse-page.test.ts:8-191`, `tests/category-pages.test.ts:29-356`, and substantial portions of `tests/posts.test.ts:75-338`.
- **Pure unit coverage is strongest** for browse state, auth safety helpers/orchestration, post/listing validation, date ranges, reactions, and upload policy/token/pipeline (`tests/browse-state.test.ts:13-107`; `tests/auth-safety.test.ts:168-862`; upload suites cited above).
- **No browser/E2E runner is configured.** `package.json:5-13` lists only Next build/start and Node test scripts; there is no Playwright/Cypress dependency at `package.json:15-35`.
- **No live Supabase/R2/SMTP integration test runs under `npm test`.** Database clients and storage operations are faked or inspected by source. Current database, R2, mail and staging behavior therefore remain outside this run.
- **Database harnesses exist but are separate.** SQL preflight/apply/verify/rollback packages and disposable PostgreSQL shell/runtime harnesses are not selected by `tests/*.test.ts`; e.g. `supabase/chunks/slice-mp4-d-disposable-harness.sh:1-100` and `supabase/chunks/wall-highlights-disposable-harness.sh:1-22`. No database operation was authorized/run here.
- **Largest weak/untested product areas:** messaging network/error/Realtime/hide journeys (`components/MessagesInbox.tsx:43-316`); festival timeline/RSVP/Notice Board interactions (`app/festivals/[slug]/page.tsx:155-686`); homepage data/rendering beyond loader helpers (`app/page.tsx:26-119`); profile/listing detail/edit full journeys; admin/report/follow/settings/legal/email features because they are absent; multi-profile switch/deletion/privacy matrix because app slices are absent (`docs/PRE_LAUNCH_TEST_LIST.md:1-131`).
- **Build/type validation boundary:** this commission did not run `npx tsc --noEmit` or `npm run build`; the fresh result here proves the Node suite only. The older report's 2026-08-10 type/build pass at `docs/research/PROJECT_STATUS_GROUND_TRUTH.md:259-270` is historical and predates current HEAD.

## 5. `origin/main` history from 2026-08-15 through 2026-08-21

### 5.1 Coherent shipped-to-repository batches

“Shipped” below means committed/merged into inspected `origin/main`, not deployed to staging or production.

| Date/batch | Commits | Repository change | Documentation coverage |
|---|---|---|---|
| 2026-08-15 — Slice MP4 A-D database authorization | `4f97c89`, `51e9507`, `1775f44`, `4089f59`, `55c5f0b`, `2966b0b`, `b6f3247`, `edd30b5`, merge `1471d82` | Recorded MP4-A; authored/corrected/applied-recorded MP4-B; authored/applied-recorded MP4-C; authored MP4-D and then recorded its sitting. Files are the `slice-mp4-*` families and execution/decision/status docs listed in §2. | MP4-A-D status is consolidated in `docs/SLICE_MP4_EXECUTION_RECORD.md:14-208`; the plan header was not advanced beyond A+B (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:3-5`). |
| 2026-08-15 — authenticated journey polish | `82deb4c`, `6f1276b`, `993938c`, merge `1471d82` | Seller spotlight filtering, RSVP button contrast, recovery/password guidance, consent copy, app-owned email/handle validation and availability hardening (`app/page.tsx:63-76`; auth/festival files and tests cited in inventory). | Summarized in `docs/SLICE_MP4_EXECUTION_RECORD.md:212-214`. |
| 2026-08-16 — Notice Board/reset polish | `0aa5bab`, merge `758ee77`, docs `e068a37` | Isolated per-note delete confirmation, “Notice Board” label, reset compatibility redirect (`app/festivals/[slug]/page.tsx:294-325,784-838`; `app/reset-password/page.tsx:1-14`). | Summarized at `docs/SLICE_MP4_EXECUTION_RECORD.md:216-220` and `docs/DECISIONS_HANDOVER.md:160-166`. |
| 2026-08-16 — Wall highlights foundation/app | `5d9d8c5`, `98e5d89`, `cc3ea86`, merge `3860e9e`; docs `0eb0291`; app `c283e38`, `aeec2a5`, `84f0574`, `8e2c82f` with merges | Guarded DB package, ban/quota/locking/concurrency correction, then highlight toggle/circles/overlay and UI refinements (`supabase/chunks/wall-highlights-*`; `components/ProfileWall.tsx:488-567,685-837`). | Current completion in `docs/DECISIONS_HANDOVER.md:146-158` and `docs/WALL_HIGHLIGHTS_FOUNDATION_VERIFICATION.md:1-91`. |
| 2026-08-16 — test runner completeness | `9da25c7` | Changed `npm test` from an incomplete file list to all `tests/*.test.ts` (`package.json:9`). | Not a product-status item; directly visible in manifest. |
| 2026-08-17 — real listing search/browse | `62a145e`, `1902e76`, merges `ffa9296`, `50d6571`; docs `463c6c6` | Replaced old Browse with full-text/filters/URL/keyset client and aligned visuals/header (`components/BrowsePageClient.tsx:96-383`; `lib/browse-state.ts:1-130`). | Recorded in `docs/DECISIONS_HANDOVER.md:195-202` and `docs/V1_PUNCHLIST.md:41-43`. |
| 2026-08-17 — listing price/cover and hardening | `ce212dd`, `65ac0d2` | Comma/dot price correctness, image cover ordering across create/edit modals, browse filters and highlight timestamp ordering (`lib/listings/price.ts:1-18`; `lib/listings/images.ts:1-4`; `lib/posts/highlights.ts:1-35`). | Punchlist still describes price preview and cover as missing at `docs/V1_PUNCHLIST.md:31-32`; this batch is undocumented/stale there. |
| 2026-08-18 — price consistency and Browse/category UI system | `f3b48d0`, `04ffd62`, then `2e040a4` through `1a5dae2` with merge commits | Unified shared EUR formatting; repeatedly refined Browse toolbar/grid/mobile/terminal states; brought category toolbars/cards/featured rows toward the same system; added shared Waveform (`components/BrowsePageClient.tsx:259-383`; `components/CategoryFilterToolbar.tsx:1-207`; `components/Waveform.tsx:1-48`). | Only `docs/README.md` received a four-line Waveform note in `1a5dae2`; current status/decision docs do not summarize the substantial UI batch. |
| 2026-08-20 — category/Browse hero, rails, scrolling and Stream UI | `4b9fd39` through `2d7fe69` with merges | Unified category grids/mobile rails; refined category heroes; reset client scroll; shared Browse/Stream photo heroes; expanded/fixed featured rails and reduced-motion scroll; Stream time-range toolbar; shared scroll-to-top with blocker correction (`components/StandardCategoryPage.tsx:216-337`; `components/FeaturedCategoryRail.tsx:1-120`; `components/StreamPageClient.tsx:237-486`; `components/ScrollToTopButton.tsx:1-125`). | Not summarized in `docs/DECISIONS_HANDOVER.md` (last additions are dated 2026-08-17 at lines 195-207) or `docs/V1_PUNCHLIST.md`; repository/code/tests are the only current record. |
| 2026-08-21 — final rail/preset refinements | `af35d2b`, merge `6edadd9`; `ad85975`, merge `37ac75f` | Centered featured carousel arrows and added Stream All/7/30/year/custom preset UI with local-date tests (`components/FeaturedCategoryRail.tsx:1-120`; `components/StreamPageClient.tsx:24-32,189-235`; `lib/posts/date-range-presets.ts:1-27`). | Not yet reflected in status/decision docs. |

### 5.2 Merged but undocumented or under-documented

1. Price-preview and cover-selection work is merged (`ce212dd`) and tested (`tests/listing-price.test.ts:8-45`), but `docs/V1_PUNCHLIST.md:31-32` still calls both missing.
2. Save Draft controls were removed—the test asserts no `Save Draft` text (`tests/listing-price.test.ts:26-36`)—while `docs/V1_PUNCHLIST.md:60-62` still names them as dead UI.
3. Browse/category visual convergence, shared toolbars, grid/hero/rail behavior and Waveform work from 2026-08-18/20 is largely absent from current status docs; the handover stops at the 2026-08-17 Browse note (`docs/DECISIONS_HANDOVER.md:195-202`).
4. Shared scroll-to-top, route scroll reset, Stream hero/time-range popover, local-date presets and their tests are not mentioned in `docs/V1_PUNCHLIST.md` or `docs/DECISIONS_HANDOVER.md`; implementation is at `components/ScrollToTopButton.tsx:1-125`, `components/StreamPageClient.tsx:24-32,189-486`, and related tests.
5. `docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:3-5,562` was not advanced after MP4-C/D execution records were added; current record is A-D (`docs/SLICE_MP4_EXECUTION_RECORD.md:14-23`).

## 6. Documentation drift and contradictions

### 6.1 True contradictions (two current requirements/claims disagree)

| Conflict | Side A | Side B / repository reality | Resolution needed |
|---|---|---|---|
| Following placement | `docs/V1_DECISIONS.md:29` says Following is a tab on the active profile and hidden when following nobody. | Later handover says Following is a Stream-page toggle, always visible to logged-in users with a friendly no-follows state and URL view (`docs/DECISIONS_HANDOVER.md:44`). | Amend the binding decision file or explicitly declare precedence before implementation. Current app implements neither (`components/StreamPageClient.tsx:237-382`; `app/[handle]/page.tsx:444-474`). |
| Ticket homepage removal | Binding decision says remove hard-coded homepage ticket section (`docs/V1_DECISIONS.md:9`). | Homepage still imports `TicketCard`, defines five hard-coded tickets, and renders the rail (`app/page.tsx:9,18-24,107-114`). | Remove/replace the obsolete rail; then `TicketCard` becomes deletable dead code. |
| Profile tab URLs | Binding decision requires profile tabs to have their own URLs (`docs/V1_DECISIONS.md:30`). | Wall/Listings use local `setTab` buttons; only inbox reads a query value and button clicks do not update URL (`app/[handle]/page.tsx:157-159,444-474`). | Define and implement stable Wall/Listings/Inbox URLs. |
| V1 reports | Decision handover says report/flag is V1 and specifies surfaces/behavior (`docs/DECISIONS_HANDOVER.md:35-43`). | Frozen/amended `docs/V1_DECISIONS.md:1-44` does not mention reports, while punchlist moderation/settings sections do not contain an implementation item dedicated to report submission. | Add the report decision to the binding V1 source and punchlist; currently not implemented. |
| Type/schema taxonomy | MP-3 SQL adds `vendor` (`supabase/chunks/mp3-foundation-apply.sql:26`) and ticket SQL/category query planning includes `ticket` (`supabase/chunks/chunk-3-tickets-validation-apply.sql:175-221`; `lib/browse-state.ts:3-4`). | Canonical app unions omit both (`types/marketplace.ts:7-11`). | Update app types only within the correct MP/ticket slice and verify forms/mappers. Current live enum values: **NEEDS DB VERIFICATION**. |

### 6.2 Stale status claims

| Stale claim | Current evidence |
|---|---|
| Multi-Profile proposal header says “Not implemented” (`docs/MULTI_PROFILE_PROPOSAL.md:3-11`). | Repository execution records now establish MP-3 and Slice MP4-A-D sittings while visible Multi-Profile remains disabled (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:339-350`; `docs/SLICE_MP4_EXECUTION_RECORD.md:14-23`). Preserve header as historical proposal status or add a prominent current-status pointer. |
| Slice MP4 plan says A+B live/current (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:3-5,562`). | Rolling execution record says A-D live/verified, E-H pending (`docs/SLICE_MP4_EXECUTION_RECORD.md:14-23`). |
| Ground-truth addenda stop at MP4-B and conclude A+B of eight (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:354-372`). | Newer execution record includes MP4-C/D (`docs/SLICE_MP4_EXECUTION_RECORD.md:127-208`). |
| Punchlist says recovery is deployed but inactive pending dashboard activation and real-mail/DKIM testing (`docs/V1_PUNCHLIST.md:14-16`). | Owner checklist records a live Supabase→All-Inkl password-reset message with DKIM/SPF/DMARC pass and inbox placement (`docs/ITEM_2_AUTH_SMTP_DNS_OWNER_CHECKLIST.md:142-155`). Other unchecked recovery gates still remain (`docs/ITEM_2_AUTH_SMTP_DNS_OWNER_CHECKLIST.md:207-225`). |
| Punchlist's accepted upload mitigation names a process-local presign limiter (`docs/V1_PUNCHLIST.md:18-25`). | Current code uses `consume_upload_intent_rate_limit` RPC and fails closed (`lib/uploads/rate-limit-server.ts:30-59`); tests explicitly require process-local removal (`tests/upload-rate-limit-server.test.ts:177-196`). |
| Punchlist calls comma-decimal preview and cover selection missing (`docs/V1_PUNCHLIST.md:31-32`). | Shared parser/formatter and cover reorder are implemented (`lib/listings/price.ts:1-18`; `lib/listings/images.ts:1-4`) and source tests cover all create/edit flows (`tests/listing-price.test.ts:8-45`). |
| Punchlist says Save Draft buttons are visible no-ops (`docs/V1_PUNCHLIST.md:60-62`). | The full source search found no `Save Draft`; the regression test requires its absence (`tests/listing-price.test.ts:26-36`). |
| Older ground-truth test count says 145 (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:259-270`). | Current manifest runs every test file (`package.json:9`); actual 2026-08-21 run produced 210/210. |
| Older ground-truth says Browse is clothing-only/query ignored (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:24-45,79-97`). | Later 2026-08-17 code implements full Browse (`components/BrowsePageClient.tsx:96-258`), and handover records it (`docs/DECISIONS_HANDOVER.md:195-202`). |

### 6.3 Historical statements explicitly superseded (not current contradictions)

1. `docs/research/PROJECT_STATUS_GROUND_TRUTH.md:10-14,145-180,188-204` is an audit-date snapshot that said Multi-Profile/MP-4/privacy were not live. Its dated addenda explicitly supersede MP-4 compatibility, privacy, and MP-3 statements (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:315-350`), followed by Slice MP4-A/B (`docs/research/PROJECT_STATUS_GROUND_TRUTH.md:354-372`) and the newer rolling record for C/D.
2. `docs/SLICE_MP4_EXECUTION_RECORD.md:206` explains that a 2026-08-15 click-round exercised the festival Notice Board under the mistaken “Wall” name; the later exact Wall app proof at lines 200-202 and Notice Board rename at lines 216-220 supersede that mistaken interpretation.
3. `docs/V1_PUNCHLIST.md:72-83` explicitly labels approval-queue, hard conversation deletion, prelaunch message images/full receipts, payment integration, VPS production hardening, and optional-festival assumptions obsolete. They should remain historical “do not implement” notes, not be counted as open work.
4. `docs/MULTI_PROFILE_PROPOSAL.md:5-15` is an implementation proposal status statement dated before packages landed; its product decisions/slice model remain binding, but execution status comes from the rolling record (`docs/SLICE_MP4_EXECUTION_RECORD.md:8-23`).

### 6.4 Claims requiring live/database confirmation

The following cannot be established from current source alone and are **NEEDS DB VERIFICATION**:

- Current catalog still matches MP-1 privacy, MP-3, legacy MP-4, Slice MP4-A-D, MP4-C social/event policy counts, and Wall-highlight package fingerprints/ACLs/policies.
- `profiles_one_per_user_key` is still exact/valid, no account has multiple profiles, and additional-profile RPC remains unreachable.
- Current profile/listing/post/message/event/report/follow/favorite data counts, festival-season seed completeness, banned/admin roles, active-session rows, null/orphan counts, and RLS-visible/private rows.
- Current Supabase dashboard URLs/templates/SMTP/rate limits/JWT lifetime and current mail DNS/selector beyond the dated owner record.
- Current staging build SHA, route health, authenticated journeys, Realtime behavior, R2 bucket/config/object state, and production/deployment state.

No inference about those states is made in this report.

## 7. Prioritized technical re-baseline

### Launch-blocking foundations

1. Finish Slice MP4-E/F/G/H in serial guarded owner-applied sittings before opening cardinality (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:323-416`; `docs/SLICE_MP4_EXECUTION_RECORD.md:20-23`).
2. Implement MP-5+ active-profile provider/Header and replace every singleton bridge consumer listed in §2.3 (`docs/MULTI_PROFILE_PROPOSAL.md:1062-1124`).
3. Implement messaging retained-participant semantics and same-account denial before profile deletion/cardinality (`docs/V1_DECISIONS.md:10,17`; `docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:164-208`).
4. Implement profile/account management/deletion and narrow admin sibling panel (`docs/V1_PUNCHLIST.md:38-40,54-55`).
5. Implement V1 reports, new-message email/settings, legal/safety routes, moderation UI/Auth-ban synchronization, Following Stream view, and launch SEO/operations (`docs/DECISIONS_HANDOVER.md:35-45`; `docs/V1_PUNCHLIST.md:38-70`).

### Smaller code/doc consistency work

1. Reconcile Following placement between binding decisions and handover before coding (`docs/V1_DECISIONS.md:29`; `docs/DECISIONS_HANDOVER.md:44`).
2. Remove the obsolete homepage hard-coded ticket carousel and then `TicketCard` (`docs/V1_DECISIONS.md:9`; `app/page.tsx:18-24,107-114`).
3. Update stale punchlist claims for price/cover/Save Draft/upload limiter/recovery proof (`docs/V1_PUNCHLIST.md:14-16,18-25,31-32,60-62`).
4. Update Slice MP4 plan/status pointers and ground-truth addendum through MP4-D (`docs/SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md:3-5,562`; `docs/research/PROJECT_STATUS_GROUND_TRUTH.md:364-372`; `docs/SLICE_MP4_EXECUTION_RECORD.md:14-23`).
5. Add a current changelog/status summary for the 2026-08-18 through 2026-08-21 Browse/category/Stream UX batches; code/test evidence is listed in §5.

## 8. Validation record for this report

- Inspected baseline: `origin/main` / worktree HEAD `37ac75fa23a1d16403fc8e032f2c974fb80dae7e` before report creation.
- Test: `npm test` — PASS, 210 tests, 210 pass, 0 fail.
- No Markdown links were added; repository citations use inline code paths and line ranges, so there are no relative link targets to resolve.
- Required final checks before commit: `git diff --check`; verify this report is the only tracked change; verify the commit contains only `docs/research/PSY_TECH_STATUS_2026-08-21.md`.
- No build, staging, database, R2, SMTP, DNS, service, push, merge, rebase, or amend action was performed.
