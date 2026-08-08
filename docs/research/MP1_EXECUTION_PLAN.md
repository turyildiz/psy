# MP-1 — Read-Only Preflight and Public Unlinkability Package Design

**Status:** Planning only; not approved for implementation or application
**Date:** 2026-08-08
**Authority:** [`docs/MULTI_PROFILE_PROPOSAL.md`](../MULTI_PROFILE_PROPOSAL.md)
**Safety mode:** Repository analysis and package design only. This plan does not add or execute schema, SQL, application code, tests, service changes, or live-data changes.

---

## 1. Executive decision

Use **column-level `SELECT` privileges on `public.profiles`**, not a public view, as the public profile contract:

1. revoke broad/table-level `SELECT` from PostgreSQL `PUBLIC`, `anon`, and `authenticated` at the coordinated cutover;
2. grant `anon` and `authenticated` `SELECT` only on the reviewed public profile columns;
3. keep the existing public row-visibility RLS policy as the row gate;
4. preserve full direct access only for legitimate trusted roles, primarily `service_role` and database-internal owners;
5. route owner-only and admin-only needs through narrow hardened RPC contracts that do not expose owner UUIDs to ordinary callers.

This is recommended because RLS cannot hide columns, the application already uses `public.profiles` relationships extensively, and exact column grants preserve those relationship names without adding a second view-backed public model. A view would create duplicate query/type paths and would still require a carefully reviewed security-owner/RLS design.

The restrictive grant change is **not safe to activate in the initial additive package**. Current browser queries use `select("*")`, current owner lookups filter on `profiles.user_id`, and current cross-table RLS policies query `profiles.user_id`. Under PostgreSQL privileges, a caller cannot rely on a column in a direct filter or policy subquery after losing access unless the authorization path has been replaced by a hardened helper. The proposal therefore deliberately holds the revocation until the MP-4 database authorization work and MP-5 compatible client cutover are ready.

### Planned inventory count

**16 application locations require a privacy-cutover change:** 14 executable production query locations—13 browser sites plus one authenticated server upload-authorization site—and two shared public contract/mapping files. Four trusted/service-role profile-owner reads are retained and separately verified, not counted as public-client changes.

One dormant fixture file, `lib/mock-data.ts`, also needs a compatibility cleanup when the public `Profile` type loses `userId`. The count is therefore **16 production locations across 13 files**, or **17 source locations including the dormant fixture**.

Passing this database/application contract milestone does **not** prove complete public unlinkability: browser-readable upload tokens and current public media keys/URLs still carry the Auth user UUID until MP-6. The one-profile uniqueness gate must remain in force through those later gates.

---

## 2. Proposal scope and naming reconciliation

### Exact proposal slice definition

The proposal defines MP-1 exactly as follows:

> ## Slice MP-1 — Fresh read-only preflight and package design
>
> - Capture exact live catalog/data/media state.
> - Produce guarded preflight, apply, verify, and rollback SQL packages for every database slice before app implementation.
> - Inventory every table, constraint, policy, function/overload, trigger, grant, and publication dependency.
> - Produce media copy/switch manifests without writing data.
> - Record which restrictive changes are additive now and which are held for a coordinated cutover.
>
> **Verification:** preflight returns explicit `GO` or `STOP`; unavailable fixtures are `UNPROVEN`; every expected object has exact definition/ACL guards.

The public-profile database contract is formally defined by the next proposal slice:

> ## Slice MP-2 — Database privacy and public-profile contracts
>
> - Add a safe public profile view/API or exact safe-column grant contract excluding `user_id` and private ownership state.
> - Add owner-only profile-list and admin-only account-grouping RPC contracts.
> - Add private ownership/active-profile boolean helpers so server code no longer needs public owner-column access.
> - Audit function outputs and Realtime publication/replica identity.
> - Prepare the guarded revocation of broad profile-table reads, but do not activate a revocation that would break current `select("*")` clients until MP-5.
>
> **Verification:** direct database/API probes against new contracts cannot reveal owner IDs; owner/admin paths return only their approved shapes; existing one-profile app remains operational before cutover.

The proposal then assigns client conversion and activation to MP-5:

> - Convert every public profile query from `*` to explicit safe fields/view.
> - Split public `Profile` types from private owner/admin contracts.
> - Activate the pre-reviewed MP-2 public owner-column revocation only after the compatible client is staged.

### Interpretation for this deliverable

The user-facing label **MP-1 — Privacy foundation** is treated as the planning package for that foundation. It does not renumber or collapse the proposal:

- **MP-1 now:** read-only inventory, design, and four-artifact package specification.
- **MP-2 later:** additive database privacy contracts and a prepared restrictive ACL cutover.
- **MP-4 dependency:** replace policies/RPCs that currently query owner columns under caller privileges.
- **MP-5 later:** compatible client cutover, followed by activation of the restrictive profile-column ACL.

This document designs those later changes but authorizes none of them.

---

## 3. In scope

1. Fresh catalog and repository inventory for every public path capable of returning a profile owner UUID.
2. A safe public `profiles` column contract that excludes `user_id` and private moderation/ownership state.
3. Exact table/column privilege transition design for `PUBLIC`, `anon`, `authenticated`, and `service_role`.
4. Compatibility analysis for the public profile SELECT RLS policy and every policy/function that internally reads `profiles.user_id`.
5. Owner-only profile-list, private ownership-check, and admin-only grouping contracts required to remove ordinary direct owner-column reads.
6. Application conversion inventory for direct profile reads, nested relations, public types/mappers, client state, and authenticated upload authorization.
7. Read-only verification design for REST, filters/order, nested relations, RPCs, Realtime, GraphQL if enabled, rendered HTML, client network payloads, and TypeScript contracts.
8. Guarded preflight/apply/verify/rollback package structure and coordinated app/database cutover order.
9. Preservation and verification of legitimate trusted access for uploads, moderation/admin resolution, signup completion, and operational scripts.

### System-generated owner information covered

The preflight must enumerate every public-schema column, view, function output, JSON constructor, composite return, publication column, and relation embed that can reveal an auth/public account UUID. The known primary blocker is `public.profiles.user_id`.

The known `profiles.is_suspended` field is also excluded from the ordinary public profile contract. It is private moderation state and can create an account-level correlation signal when all sibling profiles change together. User-authored public content such as matching websites or social links may naturally correlate identities; preventing users from voluntarily publishing the same information is not part of this system-level unlinkability boundary.

---

## 4. Out of scope

The following are explicitly excluded from MP-1 planning execution and from the first privacy package:

- adding `vendor` or changing `profile_type`;
- dropping `profiles_one_per_user_key` or enabling more than one profile;
- implementing the five-profile cap or owner immutability trigger;
- adding session-active-profile tables, selection state, providers, switchers, or active-profile equality;
- converting identity-bearing mutations to the active profile, except documenting the dependency;
- changing R2/public object-key namespaces, copying media, or switching references; that is MP-6;
- changing upload token/final-key formats or Chunk 11A post-image validation; that is MP-6;
- adding profile creation, claim execution, or reserved-profile claim SQL;
- changing signup's one-personal-profile trigger behavior;
- profile deletion, account deletion, tombstones, or conversation FK changes;
- message/follow/RSVP/reaction behavior;
- Realtime Broadcast migration; only read-only exposure verification is planned here;
- broad admin analytics/reporting;
- executing a live preflight, DDL, DML, rollback test, or schema-cache reload in this planning step;
- deploying or refreshing staging in this planning step.

The proposal MP-1 mentions media manifests. For this privacy topic, MP-1 may inventory the existing auth-user-based key risk, but the copy/switch manifest and any R2 key migration remain owned by MP-6.

---

## 5. Captured baseline to re-prove before implementation

Repository evidence currently records 15 `public.profiles` columns:

| Column | Proposed public status | Reason |
|---|---|---|
| `id` | public | Public profile identity and FK target |
| `user_id` | **private** | Direct account-owner link; primary leak |
| `type` | public | Public persona type |
| `handle` | public | Public route identity |
| `display_name` | public | Public presentation |
| `bio` | public | Public presentation |
| `avatar_url` | public | Public presentation |
| `header_url` | public | Public presentation |
| `location` | public | Public presentation |
| `social_links` | public | User-authored public presentation |
| `is_creator` | public | Existing public presentation flag |
| `is_verified` | public | Public verification badge |
| `is_suspended` | **private** | Moderation state/account-correlation signal |
| `created_at` | public | Existing public chronology/sorting |
| `updated_at` | **not granted publicly** | No current public client requirement; least privilege |

The exact initial safe column set is therefore:

```text
id, type, handle, display_name, bio, avatar_url, header_url,
location, social_links, is_creator, is_verified, created_at
```

Adding a column later must require an explicit contract review and ACL migration; new profile columns must not become public merely because they exist.

### Known baseline objects

Repository captures and applied chunks currently show:

- RLS enabled, not forced, on `public.profiles`;
- public SELECT policy `Profiles are publicly readable` with `USING (true)`;
- authenticated INSERT/UPDATE policies that compare `auth.uid()` with `profiles.user_id` and enforce the account ban;
- many policies on listings, conversations, messages, follows, RSVPs, notices, favorites, and event notifications that subquery `profiles.user_id`;
- `profiles_one_per_user_key` and `idx_profiles_user_id`;
- `handle_new_user()` writes the owner relation internally;
- `admin_ban_user(uuid,text)` and `admin_unban_user(uuid)` update all profiles for a target owner internally;
- `profile_owner_is_banned(uuid)` and public-read helpers return booleans, not owner IDs;
- Profiles are not intended to be in the `supabase_realtime` publication;
- no captured public view or RPC is known to return a `profiles` composite row.

The repository-backed current publication members are `messages`, `notice_posts`, `notice_reactions`, `conversations`, and `conversation_participant_state`. They contain public/profile identities rather than `profiles.user_id`; fresh catalog capture must still prove the live set.

The old capture's grant export was taken through a restricted audit role and does not prove the current effective API ACL. MP-1 implementation must not infer live `anon`/`authenticated`/`service_role` privileges from that file. A fresh owner-run catalog preflight is mandatory.

---

## 6. Recommended database design

### 6.1 Public reads: exact column privileges on the base table

Keep `public.profiles` as the relation used by PostgREST and nested foreign-key embeds. At the coordinated cutover:

- remove table-level `SELECT` inherited directly or through PostgreSQL `PUBLIC` from `anon` and `authenticated`;
- remove any existing column grant for `user_id`, `is_suspended`, or `updated_at` from those roles;
- grant those roles SELECT only on the 12-column public set;
- preserve the exact existing non-SELECT ACLs (`INSERT`, `UPDATE`, and any other reviewed privilege); this cutover must not accidentally change mutation capability;
- preserve the existing public row policy unless the fresh preflight finds drift;
- preserve direct full-table SELECT for `service_role` only if the live ACL confirms that this is the intended trusted path;
- preserve database-owner/function-owner internal access;
- do not grant direct table-wide SELECT to an admin browser role. Admin linkage uses a hardened RPC.

Why this approach:

- RLS filters rows and cannot mask `user_id`.
- Column privileges protect direct requests, nested embeds, filters, and ordering at the PostgreSQL boundary.
- Existing safe `profiles(handle, display_name, avatar_url)` embeds continue to use the same relationship.
- `select("*")` can no longer return the full row. Depending on PostgREST schema-cache/expansion behavior it may fail or expose only allowed columns; the app must not rely on either behavior, and static checks remove every wildcard.
- There is one canonical public profile schema rather than a base table plus a parallel public view.

### 6.2 Critical dependency: current policy subqueries

The restrictive ACL must not be applied while current policies execute caller-visible subqueries such as:

```text
SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
```

A revoked owner column can cause unrelated listing/message/follow/RSVP operations to fail with a permission error. MP-4 must replace those paths with reviewed hardened ownership/active-profile helpers before MP-5 activates the ACL.

The privacy package therefore has two states:

1. **Additive state:** new private contracts exist; broad SELECT remains temporarily for compatibility.
2. **Cutover state:** compatible app and MP-4 policy replacements are verified; broad SELECT is revoked and exact safe columns are granted.

The preflight and verifier must fingerprint the complete policy set. An unknown policy containing `profiles.user_id` is `STOP`, not an assumed no-change.

### 6.3 Owner-only contract

Add an authenticated owner-only profile-list RPC in the later MP-2 package. The proposed signature is `public.get_my_profiles()` with an explicit typed table result containing the 12 public columns plus owner-only `is_suspended` and `updated_at`; it does not return `user_id`. The preflight must `STOP` on an unexpected same-name overload rather than replacing it.

Its contract should:

- derive ownership from `auth.uid()`;
- return only profiles owned by the caller;
- return profile IDs plus the public profile fields needed by the Header/management UI;
- optionally return private owner-management flags only when justified, but never return `user_id` because ownership is implicit;
- order deterministically by `created_at`, then `id`;
- use `SECURITY DEFINER` only if required to bypass the public column ACL;
- set `search_path = ''` and schema-qualify every object;
- revoke `PUBLIC` and `anon`; grant only `authenticated`;
- enforce its internal authorization even if an operational role can execute it;
- expose no sibling list through public profile routes or public-adjacent moderation cards.

This RPC is additive and can be introduced before Multi-Profile cardinality changes; today it returns one row.

### 6.4 Ownership boolean for server/authenticated paths

Add `public.current_user_owns_profile(target_profile_id uuid) returns boolean`:

- derives the account from `auth.uid()`;
- accepts only a target profile UUID;
- returns boolean, not the owning user UUID;
- is `SECURITY DEFINER` only where necessary;
- uses `search_path = ''` and schema-qualified objects;
- revokes `PUBLIC`/`anon` and grants only reviewed callers;
- is not an active-profile authorization helper yet; MP-3/MP-4 later adds current-session active equality.

`lib/uploads/authorization.ts` should use this boolean after separately checking account ban and resource ownership. The later MP-6 upload slice adds active-profile equality and profile-scoped object keys.

### 6.5 Admin-only account grouping

Add a separate admin-only RPC contract, not an elevated table grant. The proposed signature is `public.admin_get_profile_account(target_profile_id uuid)` with an explicit typed table result—`account_user_id`, `profile_id`, `handle`, `display_name`, `type`, `is_suspended`, and `created_at`—rather than open-ended JSON. The preflight must reject an unexpected same-name overload. Given a target profile ID it may return the private account identifier and sibling profile list only after an internal `current_user_is_admin()` check. It must:

- be callable only by `authenticated` at the ACL layer, with authorization repeated internally;
- return a deliberately named private admin shape;
- never be called by a public profile/listing/Wall card;
- keep broad admin analytics out of scope;
- preserve the existing account-level ban model.

Existing `admin_ban_user`/`admin_unban_user` functions may continue to resolve/update `profiles.user_id` internally. Their outputs are `void`; they do not justify public owner-column access.

### 6.6 Legitimate trusted paths

| Path | Required access after cutover | Plan |
|---|---|---|
| Browser/public profile queries | Safe columns only | Exact column grants and explicit selects |
| Authenticated owner list/Header | Owner's profile rows, no owner UUID | Owner-only RPC |
| Browser-session upload authorization | Ownership boolean, no owner UUID | Hardened boolean RPC via server route |
| `lib/uploads/trusted-upload-server.ts` | Full owner relation | Keep service-role direct read; server-only |
| `scripts/upload-r2.js` | Full owner relation | Keep service-role direct read; trusted CLI only |
| `scripts/upload-and-create.js` | Full owner relation | Keep service-role direct read; trusted CLI only |
| Signup API route | Filter/update trigger-created profile under service role | Preserve now; exact-profile completion is later Multi-Profile work |
| Admin ban/unban DB RPCs | Internal account/profile relation | Preserve hardened internal access |
| Future admin linkage panel | Private account and sibling list | Admin-only RPC, never public table grant |

The apply package must verify that server-only modules are not bundled into browser code and that service credentials remain absent from client output.

### 6.7 Existing database objects: touch versus no-change proof

The direct privacy change set is intentionally narrow:

- **altered at restrictive cutover:** only the table/column `SELECT` ACL of `public.profiles`;
- **added in the additive package:** one owner-list RPC, one ownership-boolean RPC, and one admin-grouping RPC with exact signatures selected after fresh preflight;
- **not altered by the privacy package:** existing RLS policy definitions, trigger/function bodies, constraints, indexes, enum, profile rows, and Realtime membership;
- **hard cutover dependency:** any ordinary-caller RLS/RPC path that still reads `profiles.user_id` must already have its separately reviewed MP-4 replacement. The privacy package verifies that state but does not absorb MP-4.

| Object/family | MP privacy action |
|---|---|
| `public.profiles` table ACL | **Change at cutover** to exact safe-column SELECT for anon/authenticated |
| `public.profiles` column ACLs | **Change/normalize** to exact allowlist; no owner/private fields |
| `Profiles are publicly readable` SELECT policy | Preserve exact row predicate; verify no second permissive policy broadens a future row rule |
| `Unbanned users insert own profiles` | No privacy semantic change; verify it still works after helper/ACL changes |
| `Unbanned users update own profiles` | No privacy semantic change; verify owner updates do not require public owner-column reads |
| Cross-table owner policies/RPCs using `profiles.user_id` | MP-4 replacement dependency; cutover is blocked until exact replacements pass |
| `handle_new_user()` | Preserve internal write access and exact trigger binding/ACL |
| `profile_owner_is_banned(uuid)` | Preserve boolean output under the proposal; verify no owner UUID is returned, record its direct-execution ACL, and treat any deterministic sibling-link oracle as `STOP` rather than assuming every boolean is harmless |
| `current_user_can_read_post_author(uuid)` and related visibility helpers | Preserve boolean outputs; verify no owner UUID/record output |
| `admin_ban_user` / `admin_unban_user` | Preserve internal account-wide profile updates; verify admin-only execution |
| New owner-list/ownership/admin-group RPCs | Add in MP-2 with exact signatures, owners, search paths, bodies, and ACLs |
| Views returning profile/account data | Fresh preflight; any unapproved owner field is `STOP` |
| Realtime publication/replica identity | Profiles must remain unpublished; audit published payload columns and replica identity |
| PostgREST/GraphQL schema cache | Reload only during owner-approved apply if new RPCs require it; verify exposed schema afterward |
| Default privileges | Audit and guard so later profile columns do not silently receive broad public access |

---

## 7. Fresh preflight requirements

The preflight is read-only and returns one final summary row with `GO`, `STOP`, or `UNPROVEN`. It must capture and fingerprint:

1. Current database/project identity without printing credentials.
2. `public.profiles` owner, RLS/FORCE RLS flags, all 15 live columns, defaults, generated/identity state, comments, constraints, and indexes.
3. Exact table ACL exploded by grantor/grantee/privilege/grant option.
4. Exact column ACLs, effective `has_table_privilege` and `has_column_privilege` for `PUBLIC`, `anon`, `authenticated`, and `service_role`, plus relevant role memberships.
5. Relevant default privileges that could restore broad access on future objects.
6. Every `profiles` policy by name, command, role array, permissive/restrictive mode, `USING`, and `WITH CHECK`.
7. Every policy on another table whose expression references `profiles`, `user_id`, or an ownership helper.
8. Every function/overload that reads `profiles.user_id`, returns `profiles`, returns `record`/`json`/`jsonb`, or constructs output containing account IDs; include owner, language, volatility, `SECURITY DEFINER`, `proconfig`, complete body, and exploded ACL.
9. Every view/materialized view depending on `profiles` and its security options/owner/grants.
10. All foreign-key relationships used by PostgREST embeds.
11. `supabase_realtime` publication membership, column lists if supported, publication event flags, and `profiles` replica identity.
12. Any GraphQL exposure if `pg_graphql` is enabled.
13. Safe aggregate data checks only: null/duplicate owner invariants and whether any public response fixture exists. No row-level owner data is written to the repository.
14. Exact app-query manifest hash/list for all profile reads so the SQL/app packages are reviewed against one revision.

`GO` requires every expected object and ACL to match the reviewed baseline and every necessary fixture to be available. Missing fixture coverage is `UNPROVEN`; unknown ACL/policy/function/view/publication drift is `STOP`.

The repository-backed relationship manifest to re-prove includes profile FKs from `conversations` (buyer and seller), `event_notifications`, `events`, `favorites`, `featured_sellers`, `follows` (follower and following), `listings`, `messages`, `notice_posts`, `notice_reactions`, `vendor_events`, `conversation_participant_state`, `posts`, and `post_reactions`. Any additional live relationship is added to the probe matrix before `GO`.

---

## 8. Application change inventory

A tracked-file sweep covered **115 TS/TSX/JS files** and found **38 executable profile-read locations** (21 direct, 14 nested, 3 generic/service-role) plus **3 direct profile mutations**. Fourteen production queries block the safe-column cutover; adding the two shared public contract/mapping locations gives the 16-location production change count. The tables below count a physical query once even when it has both a wildcard and an owner-column filter.

### 8.1 Locations requiring change — 16

#### A. Unsafe wildcard or nested wildcard reads — 5

| # | Location | Current shape | Required replacement |
|---:|---|---|---|
| 1 | `app/page.tsx:64` | `profiles.select("*")` for sellers | Explicit 12-column public set; map with public mapper |
| 2 | `app/[handle]/page.tsx:239` | `profiles.select("*")` by handle | Explicit public set; owner state resolved privately |
| 3 | `app/listing/[id]/page.tsx:169` | `profiles.select("*")` by seller ID | Explicit public set |
| 4 | `app/festivals/[slug]/page.tsx:162` | nested `profiles(*)` in RSVPs | `profiles(id,type,handle,display_name,bio,avatar_url,header_url,location,social_links,is_creator,is_verified,created_at)` or the smaller fields actually rendered |
| 5 | `app/profile/edit/page.tsx:129` | `profiles.select("*").eq("user_id", ...)` | Owner-only RPC/private contract; exact edit fields, no owner UUID |

#### B. Browser owner lookups filtering on `user_id` — 8 additional locations

These do not necessarily select the owner column, but PostgreSQL column privileges also affect direct filters. They must stop querying the base owner column before revocation.

| # | Location | Current purpose | Required replacement |
|---:|---|---|---|
| 6 | `components/layout/Header.tsx:88-94` | Load one account profile | Owner-only profile-list RPC; later active selection |
| 7 | `app/messages/page.tsx:13` | Resolve inbox handle | Owner-only profile list/current-profile compatibility path; later active profile |
| 8 | `lib/posts/use-reaction-viewer.ts:27-31` | Resolve viewer profile ID | Owner-only compatibility result; later active context |
| 9 | `app/[handle]/page.tsx:190-194` | Determine owner/current profile | Private ownership boolean/list; never public `user_id` |
| 10 | `app/listing/[id]/page.tsx:134-138` | Resolve contact actor | Private owner-list compatibility path; later active profile |
| 11 | `app/listing/[id]/edit/page.tsx:180` | Resolve owner profile | Private owner list and explicit profile/listing comparison; later active profile |
| 12 | `app/listings/new/page.tsx:249` | Resolve publishing profile | Private owner-list compatibility path; later active profile |
| 13 | `app/festivals/[slug]/page.tsx:717` | Resolve RSVP/Notice actor | Private owner-list compatibility path; later active profile |

`app/profile/edit/page.tsx:129` is counted once under wildcard reads even though it also filters on `user_id`.

#### C. Public contract and mapper split — 2

| # | Location | Current leak | Required replacement |
|---:|---|---|---|
| 14 | `types/marketplace.ts:32-46` | General public `Profile` includes `userId` | Remove it from `PublicProfile`; add separately named private owner/admin shapes only where needed |
| 15 | `lib/db.ts:3-18` | `toProfile()` maps `row.user_id` into client objects | Replace with `toPublicProfile()` over exact safe fields; private mappers live in server-only modules |

#### D. Authenticated server upload authorization — 1

| # | Location | Current leak dependency | Required replacement |
|---:|---|---|---|
| 16 | `lib/uploads/authorization.ts:19-26` | User-session client selects `id,user_id` and compares owner UUID | Call the hardened ownership boolean; retain ban/resource checks. Active-profile equality and key migration remain MP-6. |

### 8.2 Trusted/service-role reads retained — 4

These are inventory findings but are not public-client cutover changes:

| Location | Current shape | MP-1/MP-2 treatment |
|---|---|---|
| `lib/uploads/trusted-upload-server.ts:152-159` | service-role `id,user_id` | Preserve server-only direct access; verify no client import/bundle |
| `scripts/upload-r2.js:8-10` | service-role `id,user_id` | Preserve trusted operational path |
| `scripts/upload-and-create.js:14-16` | service-role `id,user_id` | Preserve trusted operational path |
| `app/api/auth/signup/route.ts:123-129` | service-role filter/update by `user_id` | Preserve for this privacy cutover; later change to exact trigger-created profile ID before multiple profiles |

### 8.3 Dormant fixture cleanup — 1 non-production location

`lib/mock-data.ts:9,23,37` populates `userId` in three mock profile literals. No tracked runtime import was found, but the file must be updated with the public type split so typechecking cannot retain or normalize the stale owner field. It is excluded from the 16-location production count and included in the 17-location source total.

### 8.4 Safe public reads reviewed but not changed for privacy

The following already request explicit safe profile fields and should remain explicit:

- listing embeds in `app/page.tsx`, category pages, `components/StandardCategoryPage.tsx`, `app/[handle]/page.tsx`, and `app/listing/[id]/page.tsx`;
- buyer/seller profile embeds in `components/MessagesInbox.tsx`;
- Wall stream embed in `components/StreamPageClient.tsx`;
- Notice Board embed in `app/festivals/[slug]/page.tsx`;
- ID-only handle availability checks in signup/auth/edit surfaces;
- seller profile ID lookup by public handle in listing contact flow;
- profile mutations in `app/profile/edit/page.tsx` and `components/EditProfileModal.tsx`; their `UPDATE` capability is preserved by the SELECT-only ACL cutover, the modal returns only `id`, and active-profile authorization remains later work;
- service-role generic profile media-reference reads in `lib/uploads/references-server.ts`, `scripts/report-r2-orphans.js`, and `scripts/cleanup-promoted-pending.js`, which request only `id`, `avatar_url`, and `header_url`.

Static verification must nevertheless scan all tracked TS/TSX/JS again at the implementation revision; this list is not permission to skip newly added queries.

### 8.5 Client serialization audit

No separate rendered `profile.userId` UI consumer was found in the current source. The current leak is nevertheless real: wildcard REST/nested responses carry `user_id`, and `toProfile()` copies it into the general client `Profile` object even when no component visibly prints it.

The app slice must prove:

- no `PublicProfile` member named `userId`, `user_id`, `ownerId`, or equivalent;
- no `toPublicProfile` read of owner/moderation fields;
- no profile owner UUID in React props, state, server-component payloads, route loaders, JSON responses, `__NEXT_DATA__`/RSC payloads, logs, analytics events, or error messages;
- private owner/admin contracts are defined in server-only or explicitly private modules and cannot be passed to public components wholesale;
- sibling profile lists appear only in the private Header/management UI when that later slice is enabled.

---

## 9. Verification plan after implementation

### 9.1 Catalog and ACL verification

The read-only verifier must establish exact state, not sample it:

- broad table SELECT is absent for PostgreSQL `PUBLIC`, `anon`, and `authenticated`;
- effective SELECT on `user_id`, `is_suspended`, and `updated_at` is false for both API roles, including inherited privileges;
- effective SELECT on every allowed public column is true;
- `service_role` has the exact intended direct access and no privilege was accidentally inherited only through `PUBLIC`;
- the complete policy/function/view/ACL/publication manifest matches the reviewed package;
- no same-name RPC overload or alternate view bypass exists;
- default privileges cannot silently restore broad access;
- profiles remain absent from Realtime publication.

### 9.2 PostgREST REST probes — anonymous

Using the public API identity and a known public profile fixture, run read-only requests that prove:

| Probe | Expected result |
|---|---|
| Select exact safe columns from `profiles` | `200`; only requested safe fields |
| Select `user_id` directly | Permission failure; no data |
| Select `is_suspended` or `updated_at` | Permission failure; no data |
| `select=*` | Must not return any private field. Record whether the deployed PostgREST version rejects it or expands only role-visible columns; the app never relies on it. |
| Filter by `user_id` while selecting `id` | Permission failure, not empty/nonempty oracle |
| Order by `user_id` | Permission failure |
| Request `listings(...,profiles(user_id))` | Permission failure; no embedded value |
| Request `vendor_events(...,profiles(*))` | Permission failure |
| Request nested exact safe fields | `200`; no private keys |
| Use count/head variants with owner-column filter | Permission failure; no count oracle |

Repeat the safe/forbidden embed pair over every relationship in the preflight manifest, using the exact PostgREST FK hint where a table has two links to `profiles`. Testing only `listings` and `vendor_events` is insufficient.

Record status, PostgREST error code, and response key set without persisting owner UUID values.

### 9.3 PostgREST REST probes — authenticated ordinary user

Repeat every anonymous probe using an ordinary existing account session. Additionally prove:

- the caller cannot read `user_id` even for their own profile;
- the owner-only list returns only caller-owned profiles and contains no `user_id`;
- the ownership boolean returns only true/false for owned/unowned/unknown targets without revealing the owner;
- ordinary users cannot execute the admin grouping RPC;
- owner profile edit still loads and saves allowed fields;
- listing/message/follow/RSVP/Wall reads do not fail because an old RLS path still depends on inaccessible `user_id`.

Use approved existing demo users only; do not create auth users or profile rows for verification.

### 9.4 RPC, view, and GraphQL output audit

- Enumerate every API-executable function and overload.
- Reject any ordinary-callable function returning `public.profiles`, `SETOF profiles`, an untyped record/JSON payload containing owner IDs, or an account-grouping shape.
- Call representative ordinary-executable RPC success paths and inspect exact JSON keys.
- Verify boolean helpers remain boolean and cannot be used to recover the owner UUID.
- Verify admin-only linkage RPC fails for anon and ordinary authenticated users and succeeds only for an authorized admin fixture.
- Enumerate every view/materialized view and test direct access to any profile-derived owner field.
- If `pg_graphql` is enabled/exposed, run equivalent anonymous/authenticated field and relationship queries and verify private columns are unavailable. If GraphQL is unavailable, record `UNPROVEN` until its exposure status is established rather than assuming it is disabled.

### 9.5 Realtime verification

- Confirm `public.profiles` is not a member of `supabase_realtime` and no publication includes it through an unexpected schema-wide rule.
- Confirm no publication column list or replica-identity payload can include profile owner columns.
- Inspect every currently published table for direct auth/account UUID fields and verify its SELECT RLS/ACL.
- Establish anon and ordinary authenticated subscriptions without mutating data and confirm the channel cannot subscribe to a published `profiles` change source. The read-only proof is the exact publication/catalog state. Any behavioral emission test requiring a profile update is a separate approval-gated runtime test, not part of the MP-1 read-only verifier.
- Realtime DELETE leakage remains a later MP-8 gate for private messaging tables; do not introduce Broadcast here.

### 9.6 DOM and network unlinkability verification

With a known owner UUID held only in the verifier process:

- visit home, a profile, a listing, a festival RSVP list, Notice Board, and Wall/stream anonymously;
- inspect document HTML, RSC/Next payloads, XHR/fetch responses, WebSocket frames, and browser storage;
- assert the known owner UUID and keys `user_id`, `userId`, `owner_id`, `ownerId` are absent from public profile payloads;
- sign in as the owner and repeat public routes, confirming private sibling data appears only in the approved owner surface;
- sign in as an unrelated user and repeat;
- inspect errors for forbidden owner-column requests to ensure they reveal no value or sibling count.

Public profile IDs are expected and must not be mistaken for auth-account IDs.

---

## 10. Test plan and failure detection

### Static/application tests

1. Fail on `.from("profiles").select("*")` and equivalent quote/whitespace variants.
2. Fail on nested `profiles(*)`.
3. Allow explicit public column selectors only from one shared constant/builder where practical.
4. Fail if the public profile type/mapper contains `userId`, `user_id`, `ownerId`, `isSuspended`, or unreviewed columns.
5. Fail if browser code filters/orders on `profiles.user_id`.
6. Permit direct owner-column access only from an explicit server/trusted allowlist; each allowlisted file must use a service credential and be impossible to import client-side.
7. Test owner-list, ownership-boolean, and admin-grouping result shapes and denied callers.
8. Test upload presign/finalize authorization after replacement of the owner-column query.
9. Run project typecheck/lint/tests/build in the later app implementation slice; no such command is run for this plan.

### Database package tests

- deterministic static parity across preflight/apply/verify/rollback;
- exact old/new ACL and policy manifests in both directions;
- apply guards fail on any unreviewed drift;
- rollback guards require the complete new state before restoring the exact old ACL;
- no unguarded blanket grant such as `GRANT SELECT ON profiles` to public API roles;
- no function uses an unsafe search path or retains default `PUBLIC` execution;
- no live DDL syntax test during the planning/read-only phase.

### Integration tests

- anonymous and authenticated REST matrix above;
- nested relationship matrix;
- owner helper and admin helper authorization matrix;
- existing public page data mapping with missing owner fields;
- staging upload presign/finalize for avatar, header, listing image, and post image without changing R2 namespaces;
- signup route unit/integration tests with mocked trusted dependencies and exact-profile assertions; do not create an Auth user/profile merely for testing;
- admin target-resolution and ban/unban authorization tests with mocked/transactional fixtures. Any live ban-state mutation requires separate exact approval and restoration steps.

---

## 11. Risk register

| Risk | Impact | Detection/mitigation |
|---|---|---|
| `select("*")` fails or changes shape after column revocation | Blank or partially mapped home/profile/listing/festival/edit UI | Static query scan, typecheck, REST test, staging click-round before cutover |
| Direct `.eq("user_id", ...)` loses column privilege | Header, inbox redirect, reactions, listing actions, RSVP fail | Replace all 9 browser owner lookups with private contracts; negative static test |
| Cross-table RLS policy subquery loses `user_id` access | Seemingly unrelated reads/writes fail | MP-4 dependency gate; complete policy/function manifest; authenticated behavior matrix |
| `toProfile()` still expects `row.user_id` | Undefined value or silent client ownership bug | Split mapper/type, compile-time tests, no fallback owner field |
| Public nested relation uses `profiles(*)` | Festival RSVP request fails | Explicit nested fields; REST nested tests |
| Service-role access was inherited only through broad `PUBLIC` grant | Upload/signup/admin operational break after revoke | Exact exploded ACL preflight; explicit trusted grant only if intended; server smoke |
| Owner/admin helper is over-granted | New RPC becomes a stronger owner-link leak | Internal authorization, narrow return type, ACL expansion, anon/ordinary negative calls |
| `is_suspended` remains publicly queryable | Account-ban correlation signal | Exclude from column allowlist and all public contracts |
| View/RPC/GraphQL bypass remains | Direct API still leaks owner IDs | Complete dependency/output inventory and direct probes, not source search alone |
| Profiles accidentally enter Realtime publication | Owner field can appear in payloads | Publication/column-list guard and subscription test |
| PostgREST schema cache is stale | New RPC missing or old API shape persists temporarily | Planned schema reload only in owner-applied package; verify after reload |
| App rollback occurs after restrictive DB cutover | Old wildcard client cannot run | Rollback order is DB ACL first, then app; document as coordinated emergency action |
| Privacy rollback re-exposes values | UUIDs seen during rollback cannot be “unseen” | Rollback is emergency compatibility only; log duration/reason and reapply promptly |
| Server-only private profile object reaches client props | Owner UUID appears in RSC/network/DOM despite DB ACL | Separate server-only types/modules, serialization tests, network/HTML UUID scan |
| User-authored social links correlate siblings | Perceived unlinkability mismatch | Document that system ownership links are prohibited; voluntary identical public content is not rewritten |

---

## 12. Staging click-round for Turgay

After the later app slice is staged and before the restrictive ACL is applied:

1. **Signed out:** home seller cards load; browse/category grids load; profile header/Wall/listings load; listing seller card and related listings load; festival attendees and Notice Board load.
2. **Signup/login:** handle availability works; an existing account can sign in and the Header shows the expected current profile. The agent does not create an Auth user/profile for testing; any real human signup acceptance is separately owner-run.
3. **Profile:** profile edit opens with all expected fields and the existing public profile remains correct after reload; no save is required for this privacy click-round.
4. **Listings:** create page identifies/uses the expected profile; existing listing edit opens; listing detail contact flow opens normally.
5. **Wall:** stream and profile Wall load; reaction viewer state resolves; public post/profile cards have no missing avatar/name.
6. **Festival:** RSVP state and Notice composer/reaction state resolve for the signed-in profile.
7. **Messages:** `/messages` reaches the expected inbox; unread Header state works.
8. **Uploads:** avatar, header, listing-image, and post-image controls initialize without permission errors. Presign/finalize allow/deny behavior is covered by automated/mocked authorization tests; do not create a public object merely for this privacy click-round. No key migration is expected yet.
9. **Admin:** approved admin target-resolution/permission checks still work without exposing account linkage in public cards. Do not change ban state merely for this click-round.
10. **Privacy inspection:** browser Network/response/DOM review shows no auth owner UUID on public routes.

Repeat the same short round immediately after Turgay applies the restrictive ACL package. Any blank state, permission error, failed nested relation, or owner UUID in public payloads is a release `STOP` and triggers the reviewed rollback sequence.

---

## 13. Proposed delivery structure and order

### Package A — Fresh read-only preflight and manifest (proposal MP-1)

Deliver a one-row owner SQL Editor preflight plus repository manifest. No changes. It captures exact columns, ACLs, role inheritance, policies, functions/overloads, views, grants, publications, replica identity, GraphQL status, and app-query revision. Result is `GO`/`STOP`/`UNPROVEN`.

### Package B — Additive privacy contracts (proposal MP-2)

Four separately reviewed artifacts:

1. **preflight** — exact old-state guards and compatibility manifest;
2. **apply** — add owner-list, ownership-boolean, and admin-grouping contracts with hardened ACLs; broad profile SELECT remains temporarily;
3. **verify** — exact definitions/owners/search paths/ACLs plus caller/output behavior;
4. **rollback** — guarded removal/restoration of only objects introduced by this package.

Turgay applies the reviewed package in SQL Editor. The agent then performs independent read-only verification. The existing app must remain operational.

### Package C — Application public-contract slice

After Package B verifies:

- change the 16 listed production locations and remove the dormant `userId` fixture field;
- centralize the safe public selector/mapper;
- replace browser owner queries with private contracts;
- preserve trusted service-role paths;
- add static, contract, upload, and serialization tests;
- run typecheck/tests/build;
- arrange service-owner staging refresh and complete the pre-cutover click-round.

This app slice can be prepared while broad SELECT remains in place. It must not activate additional profiles, active-profile state, or R2 key changes.

### Dependency package — MP-4 authorization replacement

Before restrictive revocation, every policy/RPC that reads `profiles.user_id` under ordinary caller privileges must be replaced by the reviewed MP-4 authorization foundation and independently verified. This is a hard dependency, not work to smuggle into MP-1.

### Package D — Restrictive public-column cutover (proposal MP-5 activation)

A second four-artifact database package:

1. **preflight** — require verified Package B objects, exact MP-4 policy/function state, compatible deployed/staged app revision, and exact old ACL;
2. **apply** — revoke broad table SELECT and grant only the 12 safe profile columns to anon/authenticated; preserve exact trusted access;
3. **verify** — catalog/ACL plus complete anon/auth REST/RPC/nested/Realtime behavior matrix;
4. **rollback** — restore the exact captured pre-cutover ACL only after verifying the complete expected new state.

Turgay applies Package D only during the coordinated cutover. Run the post-cutover click-round and unlinkability probes immediately.

### Rollback order

If the restrictive ACL breaks runtime behavior:

1. Turgay applies the reviewed database ACL rollback first.
2. Read-only verification proves old access is restored.
3. Only then may the app slice be rolled back.
4. Additive private contracts may remain safely in place or be removed later through their separate rollback.

---

## 14. Safe parallelization

This plan used three read-only sub-agents for independent application, database-artifact, and API/privacy reviews. Their high-impact findings were reconciled into the 16-production-location count, exact column recommendation, service-role exceptions, relationship/publication inventories, and MP-6 limitation. They did not access secrets, run SQL/builds/tests, modify files, or commit. Live catalog/API behavior remains `UNPROVEN` until the future owner-run MP-1 preflight.

Up to three read-only sub-agents can safely run in parallel before package authoring:

1. **Database agent:** live catalog/ACL/policy/function/view/publication inventory and exact manifest only.
2. **Application agent:** exhaustive AST/source inventory of direct/nested profile selects, client serialization, types, and server-only exceptions.
3. **API/privacy agent:** REST/RPC/GraphQL/Realtime leak-path matrix and test fixture requirements.

They must not write files, execute SQL (including rolled-back DDL), build, test against live mutations, inspect secrets, or commit. Their outputs are location reports only. The primary agent must reconcile overlaps, independently verify high-impact findings, and treat all three results as a report/package commit barrier.

Package authoring itself should not be split across independent writers. One primary owner must maintain preflight/apply/verify/rollback object parity and app/database cutover ordering.

---

## 15. Definition of ready for implementation

MP-1 planning is ready to hand off only when:

- [ ] this plan is accepted;
- [ ] fresh owner-run preflight reports `GO`, with every unavailable fixture explicitly `UNPROVEN`;
- [ ] exact public and trusted column sets are approved;
- [ ] all profile policies/functions/views/grants/publications are versioned;
- [ ] the 16-production-location app inventory plus the dormant `lib/mock-data.ts` cleanup is rechecked against the implementation revision;
- [ ] Package B and Package D each have preflight/apply/verify/rollback parity;
- [ ] MP-4 policy dependencies are named and scheduled before restrictive cutover;
- [ ] no package changes profile cap, enum, active session, R2 keys, deletion, or live data;
- [ ] Turgay has the pre- and post-cutover staging click-round;
- [ ] rollback order and the privacy limitation of rollback are accepted.

Only then should implementation be separately authorized.
