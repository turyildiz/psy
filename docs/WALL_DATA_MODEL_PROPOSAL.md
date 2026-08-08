# Wall, Stream & Posts (V1) — Data Model Proposal

## Document status and authority

This document began as a design proposal. Chunk 11A–11D are now owner-applied and verified; the text below records the resulting V1 model and retains historical design context. The 2026-08-07 visibility amendment supersedes the earlier “hidden only from Stream” model.

The binding product requirements come from the **Wall, Stream & Posts (V1)** section of `docs/V1_DECISIONS.md`:

- Every profile has a **Wall** containing its own posts.
- **Stream** is the site-wide page for posts whose authors allow Stream inclusion.
- The festival tab currently called **The Wall** becomes **Notice Board** as a label-only change; its existing data remains unchanged.
- Every finalized profile type may post: personal, artist, label, festival, and vendor (**Shop / Brand**).
- A post contains up to 2,000 characters of text, inline auto-linked URLs, and up to five images. It contains no videos.
- There is no daily post limit, but short-window burst protection applies.
- V1 supports one reaction per profile per post and no comments. Reactions store fixed allowlisted codes rather than Unicode characters; the app maps codes to visuals so custom psytrance artwork can replace them later without a database change. Festival Notice Board reactions remain unchanged.
- Authors may edit and physically delete their own posts.
- Post deletion must make image references disappear from the database so the images can enter the manual orphan-report process. Status-only soft deletion is prohibited.
- `Make this post public` defaults on. Checked posts are publicly readable, including by logged-out visitors. Unchecked posts are readable only by signed-in members on the author's Wall and are excluded from Stream; reactions inherit the parent post's visibility.
- A post excluded from Stream cannot be flagged for the Homepage Hero.
- Following is part of V1. The owner-only Following tab is absent while the owner follows nobody.
- Profile tabs have their own URLs and Wall is the default.
- Homepage Hero shows only admin-flagged posts, side by side, without rotation or recent-post backfilling. With no flagged posts, a fixed psy.market introduction is shown.
- Posts publish immediately. There is no AI pre-check; only a link blocklist applies. Removal is reactive.
- Banning an author hides their already published posts from ordinary users while active admins retain inline-moderation access. The ban clears the author's Hero flags; unbanning makes the posts reappear automatically without restoring those flags.
- There are no post or new-follower emails.
- Comments, profile Calendar, admin-written articles, a separate admin area, and reporting UI are later scope. V1 admin actions are inline.

# Part I — Current-system findings

## 1. Existing follows table

### Finding and verdict

The live `follows` table is structurally suitable for the V1 follow graph and should **be retained, not replaced**. It supports public reads, authenticated follow/unfollow, duplicate and self-follow prevention, ban-gated writes, and indexed lookups in both directions.

It is not currently used by application code, so the follow controls and Following feed remain unimplemented.

### Live definition

The table is an ordinary database table owned by the database owner. Row-level security is enabled but not forced. It has no custom triggers.

| Column | Type | Null? | Default |
|---|---|---:|---|
| `id` | UUID | No | Generated UUID |
| `follower_profile_id` | UUID | No | None |
| `following_profile_id` | UUID | No | None |
| `created_at` | Timestamp with timezone | **Yes** | Current time |

### Constraints

| Constraint | Definition |
|---|---|
| Primary key | `id` |
| Unique relationship | `(follower_profile_id, following_profile_id)` |
| No self-follow | Follower and followed profile IDs must differ |
| Follower foreign key | References profile ID; cascades when the profile is deleted |
| Following foreign key | References profile ID; cascades when the profile is deleted |

All constraints are validated and immediate.

### Indexes

| Index | Purpose |
|---|---|
| Unique primary-key index on `id` | Row identity |
| Unique index on `(follower_profile_id, following_profile_id)` | Duplicate prevention and ownership-side lookup |
| Index on `follower_profile_id` | Profiles followed by one profile; Following feed join |
| Index on `following_profile_id` | Followers of one profile and follower counts |

No additional feed index is required initially.

### Current RLS policies

All current policies are permissive.

| Operation | Policy |
|---|---|
| Read | Publicly readable without a row filter |
| Follow | Authenticated caller must be unbanned and act through a profile they own |
| Unfollow | Authenticated caller must be unbanned and act through a profile they own |
| Update | No update policy; ordinary API updates are denied by RLS |

### Grants

Anonymous, authenticated, service, and owner roles currently have broader table grants than the feature requires. RLS supplies the effective API boundary, but least-privilege hardening is still advisable. In particular, broad direct grants such as update and truncate are unnecessary for normal user-facing access.

### Row count

The live table contains **one row**. This was confirmed through both a non-bypass read-only database role with RLS enabled and a service-level aggregate count without exporting row contents. Because the public read policy has no row filter, the read-only count represents the complete table.

### Application references

No runtime TypeScript or JavaScript under the application, component, or library code currently queries the table or references its follower/following columns.

### Stale destructive proposal

The deferred Chunk 9 section in `supabase/migrations-proposal.md` still classifies Following as dead/out-of-V1 and proposes deleting the follows table. That is obsolete and conflicts with the newer binding V1 decision.

Before any Chunk 9 work:

- remove Following from its deletion scope;
- remove the out-of-V1 characterization;
- preserve the existing row and table; and
- re-review the entire destructive manifest against the current V1 decisions.

### Recommendation

Keep the table. Before launch, make `created_at` non-null and narrow grants to the operations actually required. These are hardening changes, not reasons to replace the model.

## 2. Existing ban enforcement

### Authoritative state

The authoritative account ban is stored on the application user record. The existing admin ban action also marks the associated profile as suspended as a compatibility bridge.

The central current-user helper answers whether the **caller** is banned. It does not answer whether the **author of a content row** is banned.

### Current RLS coverage

Current user-facing mutation policies block banned callers from:

- creating or editing profiles;
- creating, editing, or deleting listings;
- creating conversations;
- sending messages;
- changing conversation read/hidden state through the protected operations;
- adding or removing favorites;
- following or unfollowing;
- subscribing to or removing event notifications;
- creating or deleting festival Notice Board posts;
- adding or removing festival Notice Board reactions; and
- adding or removing festival attendance.

Admin and super-admin actions rely on helpers that stop recognizing a banned admin as an active admin.

Upload authorization separately rejects banned users before quarantine and promotion.

### Current limitation

The existing design mainly prevents **future mutations**. Public read policies generally do not hide already published content:

- profiles remain publicly readable;
- active and sold listings remain publicly readable;
- festival Notice Board posts remain publicly readable; and
- festival Notice Board reactions remain publicly readable.

### Required post equivalent

Posts need an author-side visibility mechanism in addition to the caller-side write ban.

The proposed mechanism is a narrowly scoped, locked-down database helper that determines whether the owner of a specified profile is banned. Public post reads use that author result. Stream, Wall, Following, and Hero then inherit the same base visibility rule.

The current caller-ban helper must not be used alone for post reads because that would test the viewer rather than the author.

Settled post behavior:

- ordinary users cannot read posts by banned authors;
- active admins retain read access for inline moderation;
- all post and reaction mutations independently reject a banned caller;
- banning hides posts but does not delete them, and clears their Hero flags;
- unbanning makes those posts visible again automatically;
- physical admin or author deletion removes the post row and image references; and
- all privileged server or database operations repeat authorization because trusted operations may bypass ordinary RLS.

## 3. Existing upload policy and post-image implications

### Current policy

The centralized upload policy currently provides:

| Rule | Current value |
|---|---|
| Accepted formats | JPEG, PNG, WebP |
| Browser longest edge | Approximately 2,000 pixels |
| Browser image quality | Approximately 0.8 |
| Avatar limit | 5 MB, one image |
| Header limit | 10 MB, one image |
| Listing-image limit | 10 MB each, five images |
| Event-flyer limit | 10 MB, one image |
| Public-orphan retention | 14 days, report-only |

### Proposed post-image purpose

| Setting | Proposed value |
|---|---|
| Purpose | `post-image` |
| Public folder | Dedicated posts folder |
| Maximum size | 10 MB per image |
| Maximum count | 5 |
| Label | Post images |
| Client label | Post image |
| Accepted formats | Existing JPEG, PNG, WebP set |
| Browser preparation | Existing resize and re-encode policy |

No video purpose is introduced.

### Policy-derived behavior

Adding a purpose automatically extends:

- the upload-purpose type and purpose recognition;
- MIME and byte-limit validation;
- browser image preprocessing;
- final public-key derivation;
- promotion size, content-type, signature, and create-only checks;
- promoted-key candidate generation; and
- the existing retention and cleanup-reason policy.

### Special-cased behavior requiring explicit work

A policy entry alone is insufficient. Multi-image index handling is currently special-cased for listing images in three places:

- browser presign validation;
- signed-token verification; and
- trusted upload validation.

These checks must be centralized or generalized so any approved multi-image purpose requires an integer index from zero through one less than its configured maximum. Single-image purposes continue to accept no index or zero only.

Without that work, post index zero could pass while indexes one through four would be rejected.

### Authorization and resource semantics

The signed intent already carries:

| Field | Meaning for posts |
|---|---|
| User ID | Authenticated account and key namespace owner |
| Owner ID | Profile under which the post is authored |
| Resource ID | Optional during creation; existing post ID during editing |
| Index | Intended image slot from 0 through 4 |
| Purpose | Post-image purpose |
| Pending and final keys | Derived by trusted code, never caller-selected |
| Type and size | Signed declaration |
| Expiry | Short-lived intent validity |

Base authorization already proves that the profile belongs to the authenticated user and rejects banned users.

For a new post, the resource ID remains optional because the post row does not exist before its images are uploaded. For an existing post, presign and finalization must verify that the supplied post belongs to the owner profile.

Finalization already repeats signed-token and authorization checks. No separate direct write to the public bucket is permitted.

The image index is signed metadata, not a reservation and not part of the object key. Concurrent intents can therefore promote distinct objects for the same slot. The eventual database maximum protects post metadata, while failed metadata writes can leave report-only public orphans. This is the accepted V1 promotion-before-commit race; durable upload reservations remain deferred.

### Trusted CLI exclusion

Post-image uploads are **not supported by the CLI in V1**. They are available only through the authenticated browser/server post flow.

This creates an explicit guard requirement: because the trusted preprocessing helper is policy-derived and will recognize the new purpose automatically, the user-facing CLI must keep its own purpose allowlist and reject `post-image` before authorization, upload, or promotion. Its help text must not advertise the purpose, and no post lookup, slot derivation, URL attachment, or create-post CLI path is added.

### Reference scanners

All complete media-reference paths must know about posts before the purpose is enabled.

#### Server reference checker

Add complete paginated reads of post image arrays and include them in both fresh reference checks used before an owned quarantine object can be deleted.

#### Public orphan reporter

Add every live post image URL to the referenced-key set. Otherwise all post images would be falsely reported as public orphans.

#### Promoted-pending cleanup

Add post image references to both the initial scan and the fresh pre-delete scan. Candidate folder generation is already policy-derived, but it can identify a unique referenced promotion only after posts are included in the reference set.

### Required upload regression coverage

The existing tests include one explicit assertion that post images are unsupported. That fixture must change when the purpose is introduced.

Coverage must prove:

- indexes 0 and 4 succeed;
- missing, negative, fractional, and index 5 fail;
- post ownership is checked for existing resources;
- arbitrary final keys are rejected;
- policy limits and exact size boundaries are enforced;
- every paginated reference scanner includes post images;
- cleanup candidate expectations include the posts folder;
- the authenticated browser/server path cannot attach a sixth image;
- the user-facing CLI rejects `post-image` before upload; and
- existing promotion/finalization behavior remains unchanged.

### Rollout requirement

Policy, index validation, browser and trusted-server authorization, reference scanners, the CLI rejection guard, and tests must be deployed as one coordinated unit. The post-image purpose must not become usable while any scanner is unaware of post references.

## 4. Current profile tabs and routing

### Current profile implementation

The canonical profile page is one responsive client-rendered page shared by personal, artist, label, and festival profiles. There are no separate desktop and mobile profile implementations.

Current tabs are:

- Active Listings; and
- Inbox, visible only to the owner.

Tab state is inline local state and defaults to Listings. Buttons change local state without navigation. A limited query parameter can initialize Inbox, but clicking tabs does not update the URL, and URL and state can diverge.

There is no central tab registry.

### Existing related routes

- The legacy seller route redirects to the canonical profile route.
- Profile editing is a separate page and returns to the base profile URL.
- Desktop and mobile headers each link Profile and Messages separately.
- The generic Messages route redirects into the profile Inbox.
- Conversation deep linking is currently disconnected: a conversation ID can be lost during the redirect into the profile Inbox, and the Inbox component does not read it.

### Festival tabs

Festival detail uses a separate route and data model. Its Info, Who's Going, and The Wall tabs are also inline local state with no tab URLs.

The old festival name remains visible in both the tab label and board heading. The component is already named as a Notice Board internally. The V1 change is to rename both visible labels to **Notice Board**, without altering festival Notice Board data.

The festival tables are not a reusable general-post model because each festival post requires an event and uses festival-specific categories.

### URL implications

The proposed route shape is:

| URL | Tab or page |
|---|---|
| `/{handle}` | Canonical profile URL and default Wall |
| `/{handle}/listings` | Listings |
| `/{handle}/following` | Owner-only Following feed, only while at least one follow exists |
| `/stream` | Site-wide Stream |
| `/messages` | Inbox, fully outside the profile-tab taxonomy |
| `/messages/{conversation-id}` | Stable conversation deep link |

This preserves existing profile links while giving every non-default tab a stable URL.

Implementation implications:

1. Introduce one shared profile-tab registry.
2. Make tab controls links or route navigation, not local-state-only buttons.
3. Derive active content from the route.
4. Share the profile header and tab bar through a reusable profile shell.
5. Load only the selected tab's data.
6. Return not found for unknown profile-tab path segments.
7. Enforce owner-only routes at the route/data boundary, not only by hiding buttons.
8. Hide Following while the owner follows nobody and redirect a direct empty request to Wall.
9. Preserve layout-matching loading states.
10. Reserve the top-level Stream route against profile handles.
11. Update desktop and mobile Profile/Messages links together.
12. Move Inbox fully under Messages, remove it from the profile-tab taxonomy, update all related redirects/links, and repair conversation deep links in the same routing change.

# Part II — Proposed V1 data model

## 5. Separation from the festival Notice Board

Retain the existing festival Notice Board tables and rows unchanged. General Wall and Stream posts use new tables.

Renaming or repurposing the festival tables would violate the label-only decision and couple festival-specific event/category requirements to the site-wide post model.

## 6. Posts table

### Columns

| Column | Type | Null? | Default | Purpose |
|---|---|---:|---|---|
| `id` | UUID | No | Generated UUID | Post identity |
| `profile_id` | UUID | No | None | Author profile |
| `body` | Text | No | None | Post text and inline links, maximum 2,000 characters |
| `images` | Text array | No | Empty array | Ordered full promoted image URLs |
| `show_in_stream` | Boolean | No | True | Author-controlled Stream inclusion |
| `is_hero_featured` | Boolean | No | False | Admin-controlled Hero flag |
| `hero_featured_at` | Timestamp with timezone | Yes | Null | Hero ordering and audit time |
| `hero_featured_by` | UUID | Yes | Null | Admin user who last flagged the post |
| `created_at` | Timestamp with timezone | No | Current time | Publication time |
| `updated_at` | Timestamp with timezone | No | Current time | Last author/admin update time |

Deliberately absent:

- no status column;
- no soft-delete flag;
- no deletion timestamp;
- no separate link field;
- no video field;
- no comment count;
- no daily-post counter; and
- no AI moderation state.

### Foreign keys

| Column | Reference | Delete behavior |
|---|---|---|
| `profile_id` | Profile ID | Cascade post deletion when the profile is deleted |
| `hero_featured_by` | Application user ID | Set null if the acting admin record is deleted |

The Hero timestamp remains authoritative audit metadata if the acting admin reference becomes null.

### Constraints

| Constraint | Rule |
|---|---|
| Primary key | `id` |
| Body | Trimmed body is non-empty and no longer than 2,000 characters |
| Image count | Zero through five images |
| Image nullability | No null array entries |
| Image duplication | The same promoted URL may not appear twice in one post |
| Image namespace | Every URL must point to an approved promoted post-image location owned by the author account |
| Hero requires Stream | `is_hero_featured` cannot be true while `show_in_stream` is false |
| Hero timestamp consistency | Featured posts have a feature timestamp; unfeatured posts do not retain one |
| Hero actor consistency | An unfeatured post cannot retain a feature actor |
| Updated time | Updated automatically on accepted edits |

### Stream/Hero database enforcement

The rule “a post excluded from Stream cannot be flagged for Hero” is enforced at multiple database boundaries:

1. A row constraint makes the invalid state impossible to store.
2. The admin flag operation refuses a post whose Stream flag is off.
3. Authors cannot directly set Hero fields.
4. If an author turns Stream visibility off on a featured post, the controlled update clears the Hero flag, timestamp, and actor in the same operation.
5. Banned-author visibility is checked by all read paths, so a flagged post by a banned author cannot appear in Hero.
6. The ban action clears that author's Hero flags in the same protected ban operation. Unbanning later restores ordinary post visibility but does not restore Hero flags.

The UI mirrors these rules but is not the enforcement boundary.

### Visibility semantics

The centralized base RLS rule first preserves the author-ban and active-admin behavior, then applies the public/member boundary: `show_in_stream = true` is readable by everyone, while `show_in_stream = false` is readable only when `auth.role() = 'authenticated'`. Reaction readability uses the same parent-post visibility rule and retains the reactor-ban predicate.

| Surface | Additional filter after base visible-post policy |
|---|---|
| Author Wall | Matching `profile_id` |
| Following feed | Author profile is followed by the current profile; members-only rows still require authentication |
| Stream | `show_in_stream` is true |
| Homepage Hero | `show_in_stream` and `is_hero_featured` are both true |

`show_in_stream` is therefore both the public-versus-members-only RLS input and the explicit Stream/Hero query filter. The application keeps the explicit Stream filter even though RLS also enforces anonymous visibility.

### Indexes

| Index | Purpose |
|---|---|
| Primary-key index on `id` | Row identity |
| `(profile_id, created_at descending, id descending)` | Wall and Following-feed joins |
| Partial `(created_at descending, id descending)` where Stream is enabled | Reverse-chronological Stream pagination |
| Partial `(hero_featured_at descending, id descending)` where Hero is enabled and Stream is enabled | Homepage Hero query |

No image-array index is required initially. Stream and feed pagination should use timestamp plus ID keysets rather than offsets.

## 7. Image storage

### Settled V1 choice: array on the post row

An ordered text array of full promoted URLs is the V1 model because it:

- matches the existing listing-media shape;
- naturally preserves image order;
- supports a direct zero-to-five constraint;
- keeps post creation and editing simple;
- needs one additional paginated scanner source; and
- removes every reference when the post row is physically deleted.

Removing one image during editing removes its URL from the array, making the public object unreferenced. Deleting the post physically removes the row, so all its image URLs disappear from reference scans and become eligible for the manual orphan-report path after the retention period.

A status-only soft delete would leave the row and image array visible to service-level scanners, exactly reproducing the listing problem. It is therefore prohibited.

Banning is not deletion: a banned author's row remains, its images remain intentionally referenced, and the read policy hides the post. If an admin later deletes the post, the references disappear.

### Rejected V1 alternative: child table

A child table could store post ID, image URL or key, position, and creation time, with cascade deletion and a unique post/position pair. It is not part of V1. It may be reconsidered only if a later approved scope adds per-image metadata, captions, independent moderation, or durable upload reservations.

For V1 it adds transactional writes, another RLS surface, and another scanner table without a current product benefit.

## 8. Post reaction codes table

General post reactions store stable short codes, not Unicode emoji characters. The application maps each allowlisted code to its current visual. Custom psytrance reaction artwork can therefore replace those visuals later without changing stored rows or the database constraint. Festival Notice Board reactions keep their existing Unicode values and current table unchanged.

### Columns

| Column | Type | Null? | Default | Purpose |
|---|---|---:|---|---|
| `id` | UUID | No | Generated UUID | Reaction identity |
| `post_id` | UUID | No | None | Reacted-to post |
| `profile_id` | UUID | No | None | Reacting profile |
| `reaction_code` | Text | No | None | Stable approved V1 reaction code |
| `created_at` | Timestamp with timezone | No | Current time | Reaction time |

### Foreign keys

| Column | Reference | Delete behavior |
|---|---|---|
| `post_id` | Post ID | Cascade reactions when the post is deleted |
| `profile_id` | Profile ID | Cascade reactions when the profile is deleted |

### Constraints

| Constraint | Proposed rule |
|---|---|
| Primary key | `id` |
| One reaction per profile per post | Unique `(post_id, profile_id)`; sibling profiles remain independent and no account-level deduplication applies |
| Reaction code | Must be a short normalized code in the fixed V1 allowlist; Unicode reaction characters are not stored |

Changing a reaction updates `reaction_code` on the existing row. It does not insert a second reaction. No comments table is created.

### Indexes

| Index | Purpose |
|---|---|
| Primary-key index on `id` | Row identity |
| Unique index on `(post_id, profile_id)` | One reaction per profile per post |
| Index on `(post_id, reaction_code)` | Reaction aggregation by stable code |

No user-side reaction-history index is included in V1 because no such product query is in scope.

## 9. Link blocklist table

The repository has no existing post-link blocklist. Posts still store links only inline in `body`; the blocklist is moderation data, not a separate per-post link field.

### Proposed columns

| Column | Type | Null? | Default | Purpose |
|---|---|---:|---|---|
| `domain` | Text | No | None | Normalized blocked hostname and primary key |
| `reason` | Text | Yes | Null | Internal moderation context |
| `created_at` | Timestamp with timezone | No | Current time | Audit time |
| `created_by` | UUID | Yes | Null | Admin user who added the domain |

### Constraints and indexes

| Item | Rule |
|---|---|
| Primary key/index | Normalized `domain` |
| Domain normalization | Lowercase, trimmed hostname without scheme, path, query, fragment, or trailing dot |
| Actor foreign key | References application user; set null if the actor is deleted |
| Reason | Optional bounded internal text |

No additional index is required initially because the primary key supports exact normalized-domain checks.

The trusted post create/update path extracts inline URLs, normalizes hostnames, and rejects blocked domains. Direct table mutation must not provide a bypass around this check.

## 10. Admin post deletion audit table

Admin deletion physically removes the post and its image references, but keeps one minimal metadata-only moderation record. The audit record never stores post text, image URLs, image keys, excerpts, or any other value that could keep media referenced.

### Columns

| Column | Type | Null? | Default | Purpose |
|---|---|---:|---|---|
| `id` | UUID | No | Generated UUID | Audit record identity |
| `post_id` | UUID | No | None | Identifier of the physically deleted post; intentionally not a foreign key |
| `author_profile_id` | UUID | No | None | Author profile identifier at deletion time; intentionally not a foreign key |
| `deleted_by` | UUID | Yes | Null | Admin user who performed the deletion |
| `reason` | Text | No | None | Mandatory internal moderation reason |
| `created_at` | Timestamp with timezone | No | Current time | Deletion time |

### Constraints and indexes

| Item | Rule |
|---|---|
| Primary key/index | `id` |
| Actor foreign key | `deleted_by` references the application user and becomes null if that user is deleted |
| Reason | Trimmed length from 3 through 500 characters |
| Post identity | No foreign key to the deleted post, because the post must cease to exist |
| Author identity | No profile foreign key, so later profile deletion does not erase the audit record or cascade anything |
| Post lookup index | Index on `post_id` |
| Chronological moderation index | Index on `(created_at descending, id descending)` |
| Admin audit index | Index on `(deleted_by, created_at descending)` |

The privileged admin-delete operation validates the active admin and bounded reason, inserts this metadata record, and physically deletes the post in one transaction. Reaction rows cascade from the post. The image objects remain in public storage but become unreferenced because neither the post nor the audit table retains their URLs or keys.

# Part III — Proposed RLS and privileged actions

## 11. Posts RLS

### Read policy

Read access requires the existing author visibility rule: an unbanned author, or the existing active-admin exception for inline moderation. The centralized visibility helper then allows `show_in_stream = true` to everyone and `show_in_stream = false` only to authenticated members. The posts table has one permissive read policy so no broader policy can leak members-only rows through PostgreSQL policy `OR` composition.

Stream and Hero retain their explicit `show_in_stream` query filters. Reaction reads call the same parent-post visibility rule and preserve the reactor-ban predicate.

### Insert policy

Authenticated author only:

- caller is not banned;
- `profile_id` belongs to the caller;
- body is non-empty and no longer than 2,000 characters;
- body and image constraints pass;
- each image belongs to the approved hardened post-image namespace for that owner;
- the link blocklist passes;
- Hero flag is false; and
- Hero timestamp and actor are null.

### Update policy

Authenticated author only:

- caller is not banned;
- existing post belongs to caller;
- resulting post still belongs to caller;
- profile identity cannot change;
- author cannot forge or clear admin Hero metadata except through the controlled automatic unflag when Stream is turned off;
- body, image, ownership, and blocklist checks pass; and
- updated time is refreshed.

RLS ownership checks must exist on both the existing and resulting row. All author creation and editing goes through trusted authenticated actions, while RLS and database constraints remain defense in depth. A database guard or controlled write operation handles old/new Hero transitions that ownership-only RLS cannot safely express.

The trusted create/update boundary also applies short-window per-account burst protection. No daily counter, daily quota column, or daily quota table is introduced.

### Delete policy

Authenticated author only:

- caller is not banned;
- post belongs to caller; and
- the operation physically deletes the row.

No policy or application operation may implement author deletion by changing status.

### Admin actions

Use narrowly scoped privileged operations for:

- flagging a post for Hero;
- removing the Hero flag; and
- physically deleting a post with a mandatory reason and metadata-only audit record.

Every action verifies that the caller is an active admin. Hero flagging also verifies Stream inclusion and an unbanned author. Admin deletion atomically records the bounded reason and identifiers without content or media references, then physically deletes the post. Admins should not receive unrestricted direct update rights over all author content.

All privileged helpers follow the project's hardened security-definer rules: empty search path, fully qualified references, explicit execution grants, and internal authorization.

## 12. Reactions RLS

### Read policy

A reaction is readable only when its parent post is readable, and reactions by banned profiles are hidden.

### Insert policy

Authenticated caller only:

- caller is not banned;
- reacting profile belongs to caller;
- parent post is visible;
- reaction code is approved; and
- no reaction already exists for that profile/post pair.

### Update policy

Authenticated owner only:

- caller is not banned;
- reaction profile belongs to caller;
- parent post remains visible; and
- replacement reaction code is approved.

### Delete policy

Authenticated owner only:

- caller is not banned; and
- reaction profile belongs to caller.

No separate admin reaction deletion is needed for V1 because deleting a post cascades its reactions.

## 13. Admin deletion audit RLS

- No anonymous or ordinary authenticated-user access.
- Active admins may read audit records.
- Inserts occur only inside the narrowly scoped privileged admin-delete operation.
- Ordinary API update and delete operations are not permitted, preserving the audit record.
- Trusted service access remains limited to explicit operational needs.

## 14. Link blocklist RLS

- No anonymous access.
- Authenticated non-admin users do not read or mutate the list directly.
- Active admins may read it for inline moderation.
- Mutations occur only through a narrowly scoped admin operation or the owner-applied process.
- Trusted post creation/update may check it without exposing the list publicly.

## 15. Existing follows RLS

Retain the current public read, authenticated unbanned own-profile insert, and authenticated unbanned own-profile delete policies.

Narrow table grants separately. No update path is needed.

# Part IV — Settled application behavior and implementation plan

## 16. Feed behavior

- Wall is reverse chronological for one profile and is the default profile view.
- Stream is reverse chronological across posts whose authors enabled Stream.
- Following is reverse chronological across visible posts by followed profiles, regardless of each post's Stream flag.
- Banned-author posts are excluded from all ordinary surfaces.
- Unchecked posts remain directly readable on Wall and through Following.
- No ranking algorithm, comments, videos, daily cap, email notification, or AI pre-check is introduced. Short-window burst protection applies to post creation and editing without becoming a daily quota.

## 17. Homepage Hero behavior

- Query only visible posts with both Stream and Hero flags enabled.
- Order by `hero_featured_at` descending, so the most recently flagged post appears first.
- Return only flagged posts; never fill empty slots with recent posts.
- Never include listings.
- If no rows qualify, render the fixed psy.market introduction.
- Render as many qualifying posts as the responsive layout can display side by side, without rotation.

## 18. Proposed implementation sequence

1. Correct the stale Chunk 9 proposal so it cannot remove Following.
2. Prepare a separate owner-reviewed database package with read-only preflight, apply, rollback, privilege review, and read-only verification.
3. Add post references to every complete media scanner before enabling post-image uploads.
4. Add the post-image purpose, centralized multi-image index validation, browser/trusted-server authorization, explicit CLI rejection, and tests as one unit.
5. Implement posts, coded reactions, the database-managed link blocklist, trusted write actions, short-window burst protection, ban visibility, and Hero/Stream database invariants.
6. Implement atomic admin deletion with a mandatory 3–500 character reason, metadata-only audit insertion, and physical post deletion.
7. Introduce the shared route-driven profile shell and tab registry.
8. Add Wall, Listings, Following, and Stream routes; use Wall at the base profile URL, redirect an unavailable Following route to Wall, and return not found for invalid tab names.
9. Move Inbox fully under Messages, coordinate desktop/mobile links and redirects, and repair conversation deep links.
10. Add inline author and admin controls.
11. Add the most-recently-flagged Homepage Hero query, responsive layout, and fixed-introduction fallback.
12. Verify Wall, Stream, Following, coded reaction updates, author opt-out, banned-author hiding/admin visibility, Hero clearing on ban and Stream opt-out, unban reappearance, physical deletion, audit metadata, image-reference disappearance, CLI rejection, burst protection, and orphan reporting with database and browser evidence.

# Resolved decisions

All previously open V1 design choices in this proposal are settled as follows.

| Decision | Settled V1 rule |
|---|---|
| Post body limit | Maximum 2,000 characters, matching listing descriptions |
| Image model | Ordered text array on the post row |
| Stored image value | Full promoted URL with strict owner-namespace validation |
| Reaction cardinality | One reaction per profile per post; changing it updates the existing row |
| Reaction representation | Store a short fixed-allowlist reaction code, never a Unicode visual; the app maps codes to visuals so custom psytrance artwork can change without a database migration |
| Festival reactions | Festival Notice Board reactions remain unchanged and continue using their existing representation |
| Banned-author visibility | Hidden from ordinary users but readable by active admins for inline moderation |
| Reactions by banned profiles | Hidden |
| Unban behavior | Posts reappear automatically |
| Hero state on ban | Clear all Hero flags on the banned author's posts during the protected ban operation |
| Hero order | Most recently flagged first |
| Hero capacity | Responsive layout; the database returns only flagged posts and never fills with recent posts |
| Stream opt-out while featured | Automatically clear Hero flag, timestamp, and actor in the same operation |
| Follow graph visibility | Public |
| Profile tab URLs | Path segments; the base profile URL is Wall |
| Empty Following direct URL | Redirect to Wall |
| Invalid profile-tab name | Return not found |
| Inbox | Move fully under Messages, outside profile tabs; repair conversation deep links in the same routing work |
| Link blocklist | Database-managed normalized domains |
| Post write boundary | Trusted authenticated create/update actions plus RLS and database constraints |
| New-post upload binding | Owner-bound V1 flow with no hidden draft rows and no durable reservations |
| Post-image CLI | Not supported in V1; the CLI rejects the purpose before any upload work |
| Rate limiting | No daily cap; apply short-window burst protection |
| Admin deletion | Atomically write a minimal metadata-only moderation audit record and physically delete the post |
| Admin deletion reason | Mandatory trimmed reason from 3 through 500 characters |
| Audit media rule | Never store post text, excerpts, image URLs, image keys, or other media references in the audit record |
