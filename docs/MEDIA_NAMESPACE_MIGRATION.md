# Media namespace migration

**Status: PROPOSAL — no implementation authorized.**

This is a read-only design. It does not authorize application changes, SQL authoring or execution, R2 copy/delete operations, deployment, or a second profile. After Turgay approves the plan, every implementation or operational step below becomes its own card and sitting with its own evidence and rollback.

## 1. Decision and boundary

Public profile-attributable media must stop using the Supabase Auth account UUID (`profiles.user_id`) as an R2 path segment before profile #2 can exist. The target namespace is the public owning profile UUID (`profiles.id`). Event-owned media uses the public event UUID instead. No browser-visible URL, presigned pending key, upload token, response, or public object metadata may expose the account UUID.

This migration prevents **future** sibling-profile correlation through storage namespaces. It cannot make an old URL unknown after a third party has observed, logged, cached, indexed, or archived it. Existing one-profile accounts currently have no sibling to correlate against; that is precisely why the cutover must finish before the first second profile is created (`docs/MULTI_PROFILE_GATES.md:8-29`).

Repository evidence and the independent live audit establish that current public avatar, header, and listing URLs contain `profiles.user_id`; live counts and complete object inventories remain **NEEDS DB VERIFICATION** and **NEEDS R2 VERIFICATION** (`docs/research/OPUS_AUDIT_MULTIPROFILE_2026-08-21.md`, external audit copy at audit lines 149-168).

## 2. Current repository inventory

### 2.1 Upload purposes and keys written today

The shared policy defines five purposes (`lib/uploads/policy.json:6-12`):

| Purpose | Public folder | Limit | Current public key | Current pending key | Current writer |
|---|---|---:|---|---|---|
| `avatar` | `avatars` | 1; 5 MiB | `avatars/<auth-user-id>/<upload-uuid>.<jpg|png|webp>` | `pending/<auth-user-id>/<upload-uuid>.<ext>` | Browser and trusted CLI |
| `header` | `headers` | 1; 10 MiB | `headers/<auth-user-id>/<upload-uuid>.<ext>` | same account-scoped pending shape | Trusted CLI is reachable; no current browser `uploadToR2` caller was found |
| `listing-image` | `listings` | 5; 10 MiB each | `listings/<auth-user-id>/<upload-uuid>.<ext>` | same | Browser create/edit and trusted CLI |
| `post-image` | `posts` | 5; 10 MiB each | `posts/<auth-user-id>/<upload-uuid>.<ext>` | same | Browser only; trusted CLI rejects it |
| `event-flyer` | `festivals` | 1; 10 MiB | `festivals/<auth-user-id>/<upload-uuid>.<ext>` | same | Trusted CLI; no current browser caller was found |

`createSignedUploadIntent` derives both keys directly from `input.userId` (`lib/uploads/intent-server.ts:22-43`). `verifyUploadToken` recomputes and requires the same account-scoped shapes (`lib/uploads/token.ts:36-69`). The HMAC payload is base64url-encoded JSON, not encrypted, and includes `userId`, `ownerId`, both keys, purpose/resource/index, MIME, bytes, and expiry (`lib/uploads/token.ts:12-34,45-71`). The browser therefore receives an account UUID in both the token payload and presigned pending URL even though the pending bucket is private.

The public URL builder only appends the final key to `NEXT_PUBLIC_R2_PUBLIC_URL` (`lib/uploads/r2-server.ts:33-37`). Promotion uses the token's exact `finalKey`, verifies pending and promoted size/type/signature, and returns that URL (`lib/uploads/promotion-server.ts:68-110`). No client independently constructs a final URL: `uploadToR2` obtains presign data, PUTs to the supplied URL, finalizes with the token, and returns `publicUrl` (`lib/uploads/client.ts:110-152`).

The repository also contains non-owner, presentation-only R2 keys:

- `festivals/ai-generated/<timestamp>.jpg` for five hard-coded homepage ticket showpieces (`app/page.tsx:18-24`);
- `listings/ai-generated/<timestamp>.jpg` for the Apparel hero (`app/apparel/page.tsx:174-177`);
- `accessories/ai-generated/<timestamp>.jpg` for the Jewellery hero (`app/jewellery/page.tsx:171-174`).

These do not contain an account identifier and are not profile-attributable database media. They stay outside this re-keying package. Bundled assets such as `/music-hero.jpg` likewise stay in Git; the prior R2 manifest made that boundary explicit (`docs/R2_MIGRATION_STEP_8_MANIFEST.md:162-169`).

### 2.2 Construction and authorization paths

**Browser path.** `/api/r2/presign` validates purpose/type/size/index, authenticates, consumes the shared account rate limit, authorizes the target profile/resource, then passes `user.id` and the client-supplied public `ownerId` into the key builder (`app/api/r2/presign/route.ts:17-76`). `/api/r2/finalize` verifies the token, requires the authenticated user to equal `intent.userId`, re-runs authorization, and promotes (`app/api/r2/finalize/route.ts:10-47`). The browser token and presigned URL are therefore linkage surfaces even before the returned public URL is stored.

Browser callers are:

- avatars: `app/profile/edit/page.tsx:148-154` and `components/EditProfileModal.tsx:120-126`;
- listing create/edit: `app/listings/new/page.tsx:270-276`, `components/NewListingModal.tsx:205-211`, `app/listing/[id]/edit/page.tsx:225-231`, and `components/EditListingModal.tsx:208-214`;
- Wall post create/edit: `components/ProfileWall.tsx:202-210`.

`lib/uploads/client.ts:110-152` is the sole browser upload/URL-return wrapper found. There is no current browser caller for `header` or `event-flyer`.

**Browser authorization.** `authorizeUpload` checks the account ban and `current_user_owns_profile(ownerId)`, then resource ownership for listings, posts, and events (`lib/uploads/authorization.ts:11-65`). It currently proves any-owned-profile authority, not active-profile authority. Event flyers require an existing `events.id` whose `created_by` equals the owner profile (`lib/uploads/authorization.ts:51-62`).

**Trusted CLI path.** `scripts/lib/validated-r2-upload.js:90-105` passes both the private owner user ID and public profile ID into `uploadTrustedImage`. `scripts/upload-r2.js:7-50` resolves `profiles.id,user_id`, supports avatar/header/listing/event-flyer, and checks listing/event ownership. `scripts/upload-and-create.js:14-46` uploads one listing image before creating the listing. The shared trusted server reauthorizes `profiles.id,user_id`, consumes the same account quota, constructs the same intent, writes only to private quarantine, verifies the token, reauthorizes, and promotes (`lib/uploads/trusted-upload-server.ts:72-127,139-214`). It intentionally rejects post images (`lib/uploads/trusted-upload-server.ts:50-52,187-189`).

The external Telegram event importer is a separate writer boundary. Repository code proves only the trusted scripts above; its current workspace, generator, and credentials require a separate audit before this migration can claim all writers converted.

### 2.3 Shape and content validation

| Layer | Current enforcement |
|---|---|
| Shared policy | Exact purpose registry, JPEG/PNG/WebP, MIME-derived extension, byte limits and slot/index bounds (`lib/uploads/policy.ts:12-62`). |
| Browser preprocessing | Decode, longest edge at most 2000 px, WebP or JPEG re-encode, then declaration validation (`lib/uploads/client.ts:41-108`). |
| Token | Signed payload structure, expiry, allowed type/purpose/index, and exact account-scoped pending/final keys (`lib/uploads/token.ts:36-75`). |
| Promotion | Pending HEAD size/type/ETag, magic bytes, ETag-bound read/copy, create-only public PUT, promoted HEAD/signature (`lib/uploads/promotion-server.ts:68-113`; `lib/uploads/r2-server.ts:102-122`). |
| Cleanup parser | Only `pending/<uuid>/<uuid>.<ext>` is recognized; every purpose folder is generated as a possible public counterpart using the same first UUID (`lib/uploads/cleanup-policy.ts:1-36`). The UUID's meaning is not encoded by the regex, but current construction makes it `user_id`. |
| Reference parser | Same-origin URL parsing only; it compares decoded keys exactly and does not validate owner/type shape (`lib/uploads/cleanup-policy.ts:6-28`). |
| Listing DB constraint | `listings_images_max_5` enforces only array cardinality ≤5, not URL host, key shape, uniqueness, or ownership (`supabase/chunks/chunk-3-tickets-validation-apply.sql:198-216`). |
| Post DB constraints/trigger | `posts.images` is non-null; `posts_images_check` enforces array uniqueness, while the write trigger and create/update RPCs call the owner-namespace validator (`supabase/chunks/chunk-11b-wall-posts-apply.sql:55-96,121-176`). |
| Post URL validator | `post_images_belong_to_profile(profile_id, urls)` reads `profiles.user_id` and requires every URL to match `https://images.psy.market/posts/<owner-user-id>/<v4-uuid>.<jpg|png|webp>` (`supabase/chunks/chunk-11a-wall-foundation-apply.sql:315-353`). This is the only repository-defined database URL/key-shape validator found. |
| Profile/event columns | No repository CHECK found that constrains URL host, shape, owner, or MIME for `profiles.avatar_url`, `profiles.header_url`, `events.cover_image_url`, `events.logo_url`, or dormant `featured_sellers.image_url`. Current live definitions remain **NEEDS DB VERIFICATION**. |

The complete-reference checker keyset-paginates `profiles`, `listings`, `posts`, and `events`, covering profile avatar/header, listing/post arrays, and event cover/logo (`lib/uploads/references-server.ts:22-61`). The operational orphan report and promoted-pending cleanup duplicate the same four-table field list (`scripts/report-r2-orphans.js:64-73`; `scripts/cleanup-promoted-pending.js:84-93`). A future media-bearing column that is missing from any one of these scans can cause a false orphan classification.

Private deletion is limited to a verified pending intent after two fresh complete reference checks (`lib/uploads/cleanup-server.ts:6-23`). Public objects remain report-only for at least 14 days (`lib/uploads/lifecycle.ts:1-22`).

### 2.4 Database storage locations

Repository SQL/capture evidence identifies these media-bearing locations:

| Table.column | Type/ownership | Current use | Migration class |
|---|---|---|---|
| `profiles.avatar_url` | nullable text; row is the owning public profile | Public avatar | Profile-scoped |
| `profiles.header_url` | nullable text; row is the owning public profile | Public profile header | Profile-scoped |
| `listings.images` | non-null text array; listing has `profile_id` | Up to five public listing images | Profile-scoped, with listing ownership checked |
| `posts.images` | non-null text array; post has `profile_id` | Up to five Wall images | Profile-scoped, with post ownership checked |
| `events.cover_image_url` | nullable text; event has `created_by` profile | Festival/event cover or flyer | Event-scoped |
| `events.logo_url` | nullable text; event has `created_by` profile | Festival/event logo | Event-scoped |
| `featured_sellers.image_url` | nullable text; dormant table has `profile_id` | No runtime consumer; separately deferred | Do not migrate under this proposal; preserve for its separately approved dead-schema/legacy disposition |

The captured columns prove profile/listing/event/featured-seller fields (`supabase/captured/columns.csv:263-283,294-300,330-336`); the applied Wall chunk adds `posts.images` (`supabase/chunks/chunk-11b-wall-posts-apply.sql:55-71`).

`notice_posts` has no image/media column in the repository capture or applied chunks. Notice Board currently renders the event cover as its background and author avatars from `profiles.avatar_url` (`app/festivals/[slug]/page.tsx:343-368,586,643-646,838`). Therefore there is no current Notice attachment object to migrate. A later Notice-image feature must add its purpose, database field, authorization, reference/orphan scans, and tests as one lifecycle-governed slice; it must not silently reuse `post-image`.

The Step-10 profile-media package inventoried profile avatar/header, listing arrays, event cover/logo, and dormant featured-seller image (`supabase/chunks/step-10-profile-media-switch-preflight.sql:121-138`). It predates `posts`, so it is not a complete current inventory template by itself.

### 2.5 Rendering/read surfaces

Stored URLs are provider-agnostic and render directly in browser image requests. The migration must preserve every read surface without client-side URL rewriting.

- Profile header/avatar and profile listings: `app/[handle]/page.tsx:72,324-338`.
- Header account avatar: `components/layout/Header.tsx:230,373`.
- Profile edit previews: `app/profile/edit/page.tsx:214`; `components/EditProfileModal.tsx:207`.
- Listing cards/rails: `app/page.tsx:39-57`; `app/apparel/page.tsx:47,69,92,106`; `app/jewellery/page.tsx:42,64,87,101`; `app/music/page.tsx:39,61,83,92`; `components/StandardCategoryPage.tsx:57-59,85,108,117`; `components/BrowsePageClient.tsx:79,89`; `components/ProductCard.tsx:48-49,125`; `components/SellerCard.tsx:41`.
- Listing detail gallery, thumbnails, lightbox, and seller avatar: `app/listing/[id]/page.tsx:329-366,474,514-516`; shared lightbox at `components/ImageLightbox.tsx:114-147`.
- Listing create/edit previews: `app/listings/new/page.tsx:151-154,414`; `app/listing/[id]/edit/page.tsx:119-132`; `components/NewListingModal.tsx:116-119,273`; `components/EditListingModal.tsx:130-143`.
- Messaging participant avatars and listing thumbnail: `components/MessagesInbox.tsx:72-76,171,176,250`.
- Wall/Stream post images, lightbox, highlight preview, and author avatars: `components/ProfileWall.tsx:121-128,271-274,544,575-583,610-612`; `components/StreamPageClient.tsx:105-108`.
- Festival cards/detail cover/logo and Notice Board event-cover art/author avatars: `components/FestivalSection.tsx:85-97`; `app/festivals/page.tsx:19-21,383-386`; `app/festivals/[slug]/page.tsx:28-30,586,645,795-838`.

### 2.6 What R2 Steps 8–10 did and did not do

Steps 8–10 reused the production account namespace by explicit decision (`docs/R2_MIGRATION_STEP_8_MANIFEST.md:31-43`), copied three exact objects create-only (`docs/R2_MIGRATION_STEP_9_EXECUTION_RECORD.md:43-67`), and owner-switched three profile fields through a committed guarded SQL package (`docs/R2_MIGRATION_STEP_10_EXECUTION_RECORD.md:23-42`). That provider migration did **not** solve public unlinkability.

Step 10's switched-scope table correctly has separate “Profile row ID” and “Owning user ID” columns (`docs/R2_MIGRATION_STEP_10_EXECUTION_RECORD.md:46-52`), but the UUID embedded after `avatars/` or `headers/` is the **owning user ID**, not the profile ID. Any description of that path UUID as a profile ID is a mislabel. This proposal does not rewrite the historical execution record; it records the correction so a later reviewer does not treat the namespace work as complete.

## 3. Target namespace and privacy rules

### 3.1 Canonical keys

| Media | Target public key | Reason |
|---|---|---|
| Avatar | `avatars/<profile_id>/<upload_uuid>.<ext>` | Avatar is attributable to exactly one public profile. |
| Header | `headers/<profile_id>/<upload_uuid>.<ext>` | Header is attributable to exactly one public profile. |
| Listing image | `listings/<profile_id>/<upload_uuid>.<ext>` | The listing already publicly identifies its `profile_id`; no account linkage is added. Keep listing ID in the signed resource contract, not necessarily the key. |
| Wall post image | `posts/<profile_id>/<upload_uuid>.<ext>` | Wall posts are authored and authorized per profile. |
| Event cover/flyer/logo | `events/<event_id>/<upload_uuid>.<ext>` | Festival/event media belongs to the event/admin workflow. Event scope avoids implying that an event image is reusable by every profile of its creator and does not expose account ownership. `events.created_by` remains the private authorization input. |
| Future Notice image | `notices/<notice_id>/<upload_uuid>.<ext>` | A Notice row is the public attributable object. This is future-only: no current field/purpose exists. Creation needs a durable notice/upload reservation or a create-then-upload flow before public promotion. |

Pending keys become `pending/<profile_id>/<upload_uuid>.<ext>` for profile media and `pending/events/<event_id>/<upload_uuid>.<ext>` for event media, or an equally opaque random intent namespace. They must never contain `user_id`. A public profile/event ID is already disclosed by the resource itself; using it does not reveal sibling ownership.

The browser upload token must not contain `userId` or a user-scoped key. Prefer a short opaque server-side intent identifier bound to server-stored auth session, active profile, switch generation, purpose/resource/index, keys, MIME, bytes, and expiry. If a self-contained HMAC token is retained, its browser-readable payload may contain only approved public IDs plus an opaque session binding/digest; authentication and account equality are re-derived server-side at finalize.

### 3.2 No shared-account media reuse

A public object URL may belong to one profile or one event only. A sibling cannot attach an old account-scoped object merely because both profiles share `user_id`, and cannot attach another sibling's profile-scoped URL. “Reuse” must create a distinct create-only destination in the receiving profile/event namespace after explicit authorization and byte verification; metadata must reference that new URL.

This prevents namespace correlation, but it cannot hide intentional reuse of visibly identical media. Third parties can compare pixels or hashes of two public files. The UI and documentation must not promise unlinkability when the owner deliberately publishes the same image or identifying content on sibling profiles.

### 3.3 Transition validator rule

A dual-format transition is allowed only for **reads of already-referenced legacy values**, never as authority to attach a legacy account-scoped URL to new metadata.

- New create/upload/finalize results are new-scheme-only.
- Existing profile/listing/event scalar or array values continue rendering unchanged until their guarded switch.
- A post update may carry forward an unchanged old URL already present on that exact post, but may not add an old URL from another post/profile. A post create accepts only new-profile keys.
- The migration manifest binds every old URL/key to exactly one destination resource/profile. It is not enough that the old key's account UUID owns the target profile, because siblings share that UUID.
- Any helper that cannot distinguish “unchanged exact existing reference” from “new attachment” must be redesigned or must remain new-only. A broad regex accepting both `<user_id>` and `<profile_id>` would violate Gate 1 (`docs/MULTI_PROFILE_GATES.md:16-19`).

## 4. Guarded migration sittings

Each sitting has a settled artifact, independent review, exact evidence, and no implicit authorization for the next sitting.

### Sitting 0 — fresh read-only manifest

**Owner/wingman action:** owner-authorized read-only DB/API and R2 capture; no writes.

1. Enumerate the live catalog for every text/text-array/JSON media-bearing location, including `profiles`, `listings`, `posts`, `events`, Notice/festival tables, and dormant/deferred locations.
2. Keyset-paginate all live references. For each reference record exact table/row/field/array position, owning profile/resource, old URL/key, MIME, bytes, ETag, SHA-256, destination key/URL, and destination absence.
3. Paginate both public and quarantine R2 inventories and reconcile referenced, unreferenced, legacy, and unexpected keys. Do not classify “not new format” as orphan.
4. Require one and only one owning profile/event for every included reference; zero unmapped or multiply mapped objects.
5. Audit the external event importer and every credentialed writer before declaring writer completeness.

**Stop conditions:** any unknown media column, noncanonical host, missing object, key collision, shared old object referenced by more than one target, or incomplete/RLS-filtered count.

**Rollback:** none; read-only.

### Sitting 1 — additive transition validator package

**Owner action:** owner applies a separately authored/reviewed guarded SQL package. This proposal contains no SQL.

- Add new profile/event shape helpers while retaining only exact-existing legacy carry-forward behavior.
- Convert post create to new-only and post update/trigger logic to permit an unchanged legacy subset for the same row while requiring every added/replaced URL to be profile-scoped.
- Do not alter existing rows.
- Preflight exact live function/trigger/constraint definitions, `FORCE RLS`, ACLs, row-owner/BYPASSRLS prerequisites, and zero unexpected URL states. Use `search_path=''` and schema-qualified objects for `SECURITY DEFINER` helpers.
- Provide preflight/apply/verify/rollback as separate owner-reviewed artifacts. Rollback restores exact prior definitions only while Sitting 2 has not produced new-scheme references.

**Rollback:** exact catalog-definition rollback before any new-key metadata is accepted. After Sitting 2, rollback must preserve both proven formats or first roll app writers back and prove no new references remain.

### Sitting 2 — application new-write cutover

**Application slice:** behavior-neutral for existing data; no R2 copy and no DB row rewrite.

- Change intent construction and token verification from `userId` to the authorized profile/event namespace.
- Remove account UUIDs from pending keys, public keys, browser tokens, presign/finalize network bodies/responses, logs, and tests.
- At presign and finalize, re-derive the authenticated account server-side and authorize `ownerId`; for browser calls also require exact active profile and switch generation under MP4-H.
- Keep trusted CLI/external import explicit-owner/resource authorization; it does not pretend to have a browser active session.
- Update cleanup candidate derivation, complete reference scanners, orphan scripts, trusted scripts, and every expected-key test fixture.
- Add tests that reject another sibling's profile key, an old account key as a new attachment, arbitrary event keys, and tokens/URLs containing the account UUID.

**Rollout gate:** Sitting 1 is live and verified; all constructors/validators agree; tests/typecheck pass; staging browser uploads cover each reachable purpose. No second profile exists.

**Rollback:** deploy the prior app only if Sitting 1 still accepts old writes and no new reference has been persisted, or retain dual-read and stop uploads while a guarded reverse reference plan is reviewed. Never point existing new URLs back to old keys by string substitution.

### Sitting 3 — exact-byte R2 copy

**Executor:** an owner-approved operational agent using the established Step-9 mechanism: reviewed manifest, fresh DB/source/destination preflight, provider credentials kept out of artifacts, create-only public writes, exact source bytes, and independent public HTTP/metadata/hash verification (`docs/R2_MIGRATION_STEP_9_EXECUTION_RECORD.md:43-67`).

- Copy only manifest-approved referenced objects to their exact profile/event destinations.
- Use `If-None-Match: *` or provider-equivalent create-only semantics.
- Verify source and destination HTTP status, normalized MIME, byte count, SHA-256, and byte equality.
- Leave every DB reference and old R2 object unchanged.
- Stop all further copies on drift. Preserve successful create-only destinations and record partial state rather than deleting them.

Object count and bytes are **NEEDS R2 VERIFICATION**.

**Rollback:** no database rollback is needed because references are unchanged. Unreferenced new copies stay report-only unless a separate exact deletion manifest is approved.

### Sitting 4 — guarded database URL switch

**Executor:** Turgay applies an owner-reviewed SQL package; the agent authors exact preflight/apply/verify/rollback in a later authorized card and does not execute it.

Reuse the Step-10 package standard (`docs/R2_MIGRATION_STEP_10_EXECUTION_RECORD.md:36-42`):

- exact old→new mapping by table, row ID, field/array position, owning profile/resource, and complete expected old/new state;
- fresh external destination verification immediately before handoff;
- deterministic row locks, one serializable transaction, complete old-state guards, exact affected row/field counts, and unhandled abort on drift;
- one-row consolidated owner preflight and post-apply summary;
- symmetric guarded rollback requiring every old object to remain valid;
- no schema changes and no source deletion in the switch package.

Switch all included profile, listing, post, and event references. Preserve array order exactly. Dormant `featured_sellers.image_url` remains in its separately governed legacy track unless a new owner decision includes it.

Live row/reference counts are **NEEDS DB VERIFICATION**.

**Rollback:** owner-applied exact new→old reference package while old objects remain intact. Rollback restores compatibility, not secrecy: already observed old account UUIDs remain known.

### Sitting 5 — new-only tightening and acceptance

After every reference switched:

- tighten app/token/cleanup and DB validators to new-scheme-only;
- remove transition-only legacy carry-forward code;
- prove no public media field contains any exact `profiles.user_id` value;
- prove every final-key constructor, pending-key parser, validator, promotion path, scanner, operational writer, and fixture uses profile/event IDs;
- run anonymous DOM/network checks on all surfaces in §2.5 and authenticated browser uploads for every reachable purpose;
- verify cached/Realtime payloads cannot re-persist old URLs;
- retain old objects and document the rollback window.

**Rollback:** restore the reviewed dual-read validator and prior app only while old objects remain. Do not restore account-scoped new writes after a second profile exists.

### Sitting 6 — old-key retirement, last and destructive

Old public-key deletion is a separate future card, exact manifest, independent review, and explicit Turgay approval. It is not part of Gate-1 implementation authorization.

Use a **minimum 30-day grace period after Sitting 5**, and longer when required by the measured CDN/browser cache maximum. Retirement requires: measured cache TTL plus 48 hours elapsed; no database references; complete fresh R2/DB scans; successful rendered acceptance; old objects no longer needed for rollback; and, if request telemetry is available without collecting sensitive data, no old-key requests for seven consecutive days. If cache policy or inventory completeness is unproven, do not delete.

The existing 14-day orphan rule remains the floor for ordinary report-only candidates (`lib/uploads/policy.json:5`; `lib/uploads/lifecycle.ts:20-22`), but it is not sufficient evidence for a namespace-wide irreversible retirement where cached pages, old Realtime payloads, browser history, and external links may still carry old URLs.

**Rollback:** deletion has no guaranteed rollback. Require a verified backup/source or accept irreversibility explicitly. Third-party archives remain outside operator control regardless.

## 5. Interaction with other Multi-Profile work

### MP4-H active browser authorization

The namespace cutover and MP4-H touch the same presign/finalize/token/authorization files. Recommended order:

1. land the additive transition validator;
2. author MP4-H and namespace construction as one coordinated application contract, but keep review findings separable;
3. enable new-key writes only after both active-profile/generation authorization and key-schema compatibility pass;
4. finish object/reference migration and tighten validators;
5. only then permit a controlled second profile.

Doing namespace first without MP4-H would let an authenticated account request a valid profile-scoped key for an inactive sibling because `authorizeUpload` currently proves only any-owned-profile authority (`lib/uploads/authorization.ts:20-27`). Doing MP4-H first while retaining account-scoped public keys would close stale-switch authorization but preserve the public correlation leak. Neither alone closes Gate 1 items 1 and 5 (`docs/MULTI_PROFILE_GATES.md:78-91`).

Browser finalize must independently recheck authentication, ban, ownership, exact active profile, selection generation, purpose/resource/index, MIME/size/signature, and expiry. Trusted event imports keep explicit approved owner/event authority and must not be forced through browser session-active semantics.

### Trusted upload paths and the four-file owner-read allowlist

`tests/profile-contract.test.ts:117-154` pins exactly four trusted code locations allowed to select/filter `profiles.user_id`:

1. `app/api/auth/signup/route.ts`;
2. `lib/uploads/trusted-upload-server.ts`;
3. `scripts/upload-and-create.js`;
4. `scripts/upload-r2.js`.

The upload files may still need private account reads to verify profile ownership and consume the account-level rate limit. The migration does **not** require removing those trusted server-side reads. It requires that `user_id` stop influencing any browser-visible token/key/URL or public metadata. Update the test so it distinguishes approved private ownership/rate-limit use from forbidden key construction, serialization, logging, or response propagation. The signup allowlist entry is unrelated to media and remains governed by the signup Gate-1 item.

### Upload-intent rate limit

The installed RPC is intentionally account-scoped: 20 accepted intents per rolling ten minutes per `auth.users.id`; authenticated callers cannot choose a target identity and service-role callers must supply a verified target (`supabase/chunks/item-3-commit-3-upload-intent-rate-limit-apply.sql:86-105,116-195`). Keep this account-level anti-abuse boundary. Profile-scoping quota would let one account multiply its allowance with sibling profiles. The account UUID stays internal to the RPC/table and must not enter object keys or browser payloads.

### Package D privacy invariant

Package D denies direct ordinary-client reads of `profiles.user_id`, while allowing public avatar/header fields (`tests/profile-contract.test.ts:17-63,117-166`). Account-scoped public URLs currently bypass the behavioral intent of that protection. Acceptance must test both directions:

- denied columns remain denied and public contracts remain exact;
- no allowed media value, network request, token, DOM attribute, or public R2 key contains any value from `profiles.user_id`.

The admin-only account-grouping RPC may reveal linkage only inside its private authorized boundary; it must never supply a public media namespace.

### Tests requiring updates

At minimum update/add coverage in:

- `tests/upload-intent.test.ts`: profile/event pending/final key derivation, no `userId` serialization, arbitrary sibling/event key rejection;
- `tests/upload-server-pipeline.test.ts` and `tests/trusted-cli-upload.test.ts`: expected keys/URLs and retained trusted private ownership checks;
- `tests/upload-cleanup.test.ts`: new pending parser, all purpose destinations, complete field scans, legacy read-only transition fixtures, and no sibling legacy attachment;
- `tests/upload-policy.test.ts`: MP4-H active/inactive/stale-generation authorization and event ownership;
- `tests/upload-rate-limit-server.test.ts`: preserve account-scoped browser/service-role quota semantics;
- `tests/profile-contract.test.ts`: preserve the four-file private-read allowlist while adding a repository-wide prohibition on using `user_id` in upload key templates or browser-visible payloads;
- post/Wall tests: DB helper source contract, create new-only, update unchanged-old-only during transition, then new-only tightening;
- rendering tests: old and new URLs read equivalently before the switch; all public routes render after the exact DB rewrite.

Tests must use real UUID shapes because the database post validator requires version/variant-constrained UUIDs; placeholder `user-1/profile-1` fixtures currently hide schema-compatibility errors.

## 6. Risks and stop conditions

1. **Permanent historical disclosure.** Re-keying cannot erase already observed account UUIDs.
2. **Broad dual-format acceptance.** A regex accepting any legacy key owned by the same account lets siblings attach each other's media and fails Gate 1.
3. **Hidden writer.** The external event importer or another credentialed script may continue creating account-scoped keys after app conversion.
4. **Incomplete media inventory.** Missing a JSON/array/legacy column can create dangling references or false orphan candidates.
5. **Shared object references.** One old object referenced by multiple profiles/events has no safe automatic owner; stop for an explicit copy/ownership decision.
6. **Token leakage.** Changing only `finalKey` still leaves `userId` exposed in the base64 token and pending presigned URL.
7. **App/DB validator mismatch.** New post uploads fail or become public orphans if the application writes profile keys before the live DB accepts them.
8. **Copy collision or drift.** Never overwrite a destination and never regenerate a mapping after review without invalidating all evidence.
9. **Array-order drift.** Listing/post image order controls covers and galleries; SQL rewrite must preserve ordinality exactly.
10. **Post-finalize metadata failure.** A promoted object can remain unreferenced; public deletion stays report-only.
11. **Cache/Realtime stale writes.** Old URLs in forms, cached payloads, or late subscriptions can be re-saved unless new attachments are validated server-side and stale generations fail.
12. **Rollback after profile #2.** Restoring account-scoped writes would recreate a public linkage leak; after the irreversible boundary, disable writes and forward-fix instead.
13. **Content-level correlation.** Distinct keys cannot hide identical images, logos, names, or other self-identifying media.
14. **Historical docs ambiguity.** R2 Step 10 is provider-migration evidence, not namespace-migration completion.

Any unmapped reference, RLS-filtered count, unknown bucket key, unverified external writer, unexpected live validator, or mismatch between reviewed Git and live definitions is `UNPROVEN` and stops the next boundary.

## 7. Open questions for approval

1. Approve `events/<event_id>/<upload_uuid>.<ext>` for both event cover/flyer and logo, replacing the current `festivals/<user_id>/...` writer.
2. Approve `notices/<notice_id>/<upload_uuid>.<ext>` as a future-only namespace, with no Notice media purpose/column added in this migration.
3. Approve removing `userId` from browser-readable upload tokens, preferably by moving to an opaque server-side intent record; if no durable intent record is approved, approve the reduced self-contained payload described in §3.1.
4. Confirm whether exact same-image reuse across sibling profiles should be allowed with distinct copied keys and an explicit warning that content itself remains correlatable, or prohibited by product policy.
5. Approve the 30-day minimum old-key grace period and telemetry/cache evidence gate, superseding the generic 14-day orphan floor for this retirement only.
6. Confirm whether dormant `featured_sellers.image_url` remains entirely in its existing dead-schema/legacy retirement track.

## 8. Required wingman/owner verification list

Before implementation authoring:

- **NEEDS DB VERIFICATION:** fresh live catalog list of every media-bearing text, array, and JSON column; exact types, nullability, CHECKs, triggers, validators, RLS, ACLs, and effective definitions.
- **NEEDS DB VERIFICATION:** live URL-shape counts per table/column: null, non-R2, old account-scoped R2, already profile-scoped R2, event/admin-scoped R2, malformed, and duplicate/shared references; count rows and URL elements separately.
- **NEEDS DB VERIFICATION:** prove whether any avatar, header, listing, post, event/festival, Notice, or dormant media already uses a profile-scoped key.
- **NEEDS DB VERIFICATION:** map every included reference to exactly one `profile_id` or `event_id`; prove zero unmapped/multiply mapped references.
- **NEEDS DB VERIFICATION:** confirm current `post_images_belong_to_profile`, post trigger/RPC definitions, listing constraints, and upload-rate-limit RPC match the cited repository artifacts.
- **NEEDS R2 VERIFICATION:** complete paginated public and quarantine object counts/bytes by prefix and shape; referenced/unreferenced reconciliation; source HEAD/MIME/bytes/ETag/SHA-256; proposed destination absence.
- **NEEDS R2 VERIFICATION:** current CDN `Cache-Control`, cache rules, and effective maximum TTL for old public objects.
- **NEEDS R2 VERIFICATION:** verify no object metadata or custom headers expose account IDs after copy.
- Audit every executable writer, especially the external Telegram event importer, and prove which profile/event identity and key builder it uses.
- Recompute the rendering inventory against the settled implementation revision and run anonymous DOM/network checks across profile, listing, Browse/category/home, inbox, Wall/Stream, festivals, and Notice Board.
- Verify no auth-user UUID appears in presign/finalize request/response bodies, tokens, presigned paths, public URLs, logs, DOM, Realtime payloads, or public API payloads.

## 9. Approval consequence

Approval of this proposal authorizes only decomposition into individual cards/sittings. It does not authorize code, SQL, R2 operations, deployment, old-object deletion, or profile #2. Gate 1 item 1 closes only after the owner-run manifest, reviewed copies/reference switch, complete repository conversion, live DB/R2 proof, and anonymous browser/network acceptance all pass (`docs/MULTI_PROFILE_GATES.md:23-29`).
