# Post-Image Upload Purpose Report

## Status

The authenticated browser/server upload pipeline now supports the `post-image` purpose. No post composer or other UI was added. No database objects were changed.

The implementation:

- accepts JPEG, PNG, and WebP inputs through the existing centralized allowlist;
- uses the existing browser image preparation path, which resizes to a maximum 2,000-pixel longest edge and attempts WebP conversion at quality `0.8` (with the existing JPEG fallback when browser WebP encoding is unavailable);
- allows five signed image slots, numbered `0` through `4`;
- uses the existing private-quarantine, signed-intent, verification, create-only promotion, and finalization pipeline;
- verifies ownership when an existing post ID is supplied;
- includes post image arrays in all three complete media-reference scanners; and
- keeps post-image uploads explicitly prohibited through the trusted CLI path.

The changes are present only in the working tree. They have not been committed or pushed.

## Key-pattern comparison

### Database-enforced pattern

The URL validator is defined by the Chunk 11A `post_images_belong_to_profile` helper and is enforced by Chunk 11B for post inserts and updates. Its exact pattern is:

```sql
'^https://images[.]psy[.]market/posts/'
|| owner_user_id::text
|| '/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}[.](jpg|png|webp)$'
```

Here, `owner_user_id` is `profiles.user_id`, which is the authenticated Supabase user ID associated with the post's author profile.

### Upload key builder

The existing upload builder remains:

```ts
finalKey: `${policy.folder}/${input.userId}/${uploadId}.${extension}`
```

For `post-image`, the policy folder is `posts`, `input.userId` is the authenticated user ID, and production `randomUUID()` supplies a UUID-v4 upload ID.

The actual builder output verified during this change was:

```text
posts/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.webp
```

With the configured public origin, the complete URL is:

```text
https://images.psy.market/posts/11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.webp
```

| Comparison point | Database | Upload builder |
|---|---|---|
| Folder | `posts` | `posts` |
| Namespace identifier | `profiles.user_id` | authenticated `input.userId` |
| Filename | UUID v4 | `randomUUID()` UUID v4 |
| Extensions | `jpg`, `png`, `webp` | MIME-derived `jpg`, `png`, `webp` |
| Result | Full URL under `https://images.psy.market/` | Matching object key under the configured public origin |

**Result: the generated public URL matches the database-enforced pattern.** No database adjustment was needed or made.

## Changed files

- `app/api/r2/presign/route.ts` — replaces listing-only index checks with the shared policy-derived index validator, allowing post slots `0–4` through the browser presign flow.
- `lib/uploads/authorization.ts` — verifies that a supplied existing post belongs to the authenticated owner's profile during both presign and finalization authorization.
- `lib/uploads/policy.json` — registers `post-image` with folder `posts`, a 10 MB per-image limit, and a maximum count of five.
- `lib/uploads/policy.ts` — adds shared policy-derived slot validation for every single-image and multi-image upload purpose.
- `lib/uploads/references-server.ts` — paginates all `posts.images` arrays and includes them in fresh server-side reference checks.
- `lib/uploads/token.ts` — validates signed post-image slots with the shared `0–4` rule and continues to recompute the exact final key from signed fields.
- `lib/uploads/trusted-upload-server.ts` — keeps explicit early rejection of `post-image` in trusted/CLI upload entry points and uses shared slot validation for allowed purposes.
- `scripts/cleanup-promoted-pending.js` — includes every paginated post image URL in both initial and fresh pre-delete reference scans.
- `scripts/report-r2-orphans.js` — includes every paginated post image URL in the public orphan report's referenced-key set.
- `scripts/upload-r2.js` — rejects `post-image` before owner lookup, authorization, file processing, or storage activity.
- `tests/trusted-cli-upload.test.ts` — proves the post-image CLI rejection happens before authorization or storage and remains present in the user-facing CLI.
- `tests/upload-cleanup.test.ts` — proves the `posts` promotion candidate exists and all three scanners read and flatten post image arrays.
- `tests/upload-intent.test.ts` — covers valid post slots `0` and `4`, missing/negative/fractional/out-of-range slots, posts-key derivation, and arbitrary-key rejection.
- `tests/upload-policy.test.ts` — covers the post policy, exact size boundary, generalized slot rules, and existing-post ownership checks.

## Reference scanner behavior

### `lib/uploads/references-server.ts`

The server-side reference checker now performs a complete ordered, keyset-paginated read of:

```ts
fetchAllRows<MediaReferenceRows["posts"][number]>("posts", "images")
```

It passes every post image array into the canonical URL-to-key reference matcher:

```ts
posts.map((row) => row.images ?? [])
```

This affects the complete reference checks used by server-side private-pending cleanup decisions.

### `scripts/report-r2-orphans.js`

The read-only public orphan reporter now fetches all `posts.images` rows with the same deterministic pagination used for other media tables. Each URL is converted to its canonical R2 key and added to the referenced-key set:

```js
for (const row of posts) for (const value of row.images || []) {
  const key = keyFromPublicUrl(value);
  if (key) keys.add(key);
}
```

A live post image therefore does not appear as an unreferenced public object solely because it belongs to a post.

### `scripts/cleanup-promoted-pending.js`

The promoted-pending cleanup script now includes all post image URLs in `referencedKeys()`. That function is called for:

1. the initial complete reference scan used to identify a unique referenced promoted counterpart; and
2. the fresh complete reference scan immediately before any approved private-pending deletion.

The script still deletes only verified private quarantine objects. This change does not introduce a public-object deletion path.

## CLI rejection guard

Post-image uploads remain prohibited through the CLI at two boundaries.

The user-facing command rejects the purpose before owner authorization:

```js
if (purpose === "post-image") {
  throw new Error("Post image uploads are not supported by the CLI.");
}
```

The trusted upload implementation also rejects it before its normal purpose validation, file handling, authorization, intent creation, private upload, or promotion:

```ts
if (input.purpose === "post-image") {
  throw new Error("Post image uploads are not supported by the CLI.");
}
```

The CLI help text continues to advertise only:

```text
avatar|header|listing-image|event-flyer
```

## Verification performed

| Check | Result |
|---|---|
| Upload test suite | 48 tests passed, 0 failed |
| TypeScript `npx tsc --noEmit` | Passed |
| `scripts/report-r2-orphans.js` syntax | Passed |
| `scripts/cleanup-promoted-pending.js` syntax | Passed |
| `scripts/upload-r2.js` syntax | Passed |
| `git diff --check` | Passed |
| Actual post-image key construction | Produced the expected `posts/{authenticated-user-id}/{uuid-v4}.webp` key |
| Database changes | None |
| UI changes | None |
| Commit or push | None |

## Caveat and review point

The signed image index is intent metadata, matching the existing listing-image behavior. Slots are restricted to integers `0–4`, but they are not durable capacity reservations. Concurrent or repeated requests can obtain separate upload IDs for the same slot and can promote multiple objects before a post write occurs.

The database maximum protects the stored post's image array, but a failed or abandoned metadata write can still leave a report-only public orphan. This is the previously accepted V1 promotion-before-commit behavior; durable upload reservations remain deferred.

No live R2 upload, browser interaction, staging refresh, or database mutation was performed during this change. Verification covered the code path, tests, type checking, script parsing, key construction, and the checked-in SQL pattern.

## Full diff

```diff
diff --git a/app/api/r2/presign/route.ts b/app/api/r2/presign/route.ts
index ea5d71e..9b18f2c 100644
--- a/app/api/r2/presign/route.ts
+++ b/app/api/r2/presign/route.ts
@@ -4,10 +4,10 @@ import { createUploadAuthClient } from "@/lib/uploads/auth-server";
 import { createSignedUploadIntent } from "@/lib/uploads/intent-server";
 import {
   getSafeExtension,
-  getUploadPolicy,
   isUploadPurpose,
   type AllowedImageType,
   validateUploadDeclaration,
+  validateUploadIndex,
 } from "@/lib/uploads/policy";
 import { createPresignedPut } from "@/lib/uploads/r2-server";
 import { consumeUploadIntentRateLimit } from "@/lib/uploads/rate-limit-server";
@@ -29,13 +29,8 @@ export async function POST(req: NextRequest) {
   if (resourceId !== undefined && typeof resourceId !== "string") {
     return NextResponse.json({ error: "Invalid upload resource." }, { status: 400 });
   }
-  const policy = getUploadPolicy(purpose);
-  if (purpose === "listing-image" && (!Number.isInteger(index) || (index as number) < 0 || (index as number) >= policy.maxCount)) {
-    return NextResponse.json({ error: `Listing image index must be between 0 and ${policy.maxCount - 1}.` }, { status: 400 });
-  }
-  if (purpose !== "listing-image" && index !== undefined && index !== 0) {
-    return NextResponse.json({ error: "This upload purpose accepts one image only." }, { status: 400 });
-  }
+  const indexError = validateUploadIndex(purpose, index);
+  if (indexError) return NextResponse.json({ error: indexError }, { status: 400 });
 
   const declarationError = validateUploadDeclaration(purpose, contentType, size as number);
   if (declarationError) return NextResponse.json({ error: declarationError }, { status: 400 });
diff --git a/lib/uploads/authorization.ts b/lib/uploads/authorization.ts
index 36f539f..ad70d9b 100644
--- a/lib/uploads/authorization.ts
+++ b/lib/uploads/authorization.ts
@@ -37,6 +37,17 @@ export async function authorizeUpload(
     }
   }
 
+  if (authorization.purpose === "post-image" && authorization.resourceId) {
+    const { data: post, error } = await supabase
+      .from("posts")
+      .select("id, profile_id")
+      .eq("id", authorization.resourceId)
+      .maybeSingle();
+    if (error || !post || post.profile_id !== authorization.ownerId) {
+      return { ok: false as const, status: 403, error: "You do not own this post." };
+    }
+  }
+
   if (authorization.purpose === "event-flyer") {
     if (!authorization.resourceId) {
       return { ok: false as const, status: 400, error: "An event is required for event flyers." };
diff --git a/lib/uploads/policy.json b/lib/uploads/policy.json
index 4b023fa..16cc02d 100644
--- a/lib/uploads/policy.json
+++ b/lib/uploads/policy.json
@@ -7,6 +7,7 @@
     "avatar": { "folder": "avatars", "maxBytes": 5242880, "maxCount": 1, "label": "Avatar images", "clientLabel": "avatar" },
     "header": { "folder": "headers", "maxBytes": 10485760, "maxCount": 1, "label": "Header images", "clientLabel": "header" },
     "listing-image": { "folder": "listings", "maxBytes": 10485760, "maxCount": 5, "label": "Listing images", "clientLabel": "listing image" },
+    "post-image": { "folder": "posts", "maxBytes": 10485760, "maxCount": 5, "label": "Post images", "clientLabel": "post image" },
     "event-flyer": { "folder": "festivals", "maxBytes": 10485760, "maxCount": 1, "label": "Event flyers", "clientLabel": "event flyer" }
   }
 }
diff --git a/lib/uploads/policy.ts b/lib/uploads/policy.ts
index 7908665..60e4726 100644
--- a/lib/uploads/policy.ts
+++ b/lib/uploads/policy.ts
@@ -22,6 +22,18 @@ export function isAllowedImageType(value: unknown): value is AllowedImageType {
   return typeof value === "string" && ALLOWED_IMAGE_TYPES.includes(value as AllowedImageType);
 }
 
+export function validateUploadIndex(purpose: UploadPurpose, index: unknown) {
+  const policy = getUploadPolicy(purpose);
+  if (policy.maxCount > 1) {
+    if (!Number.isInteger(index) || (index as number) < 0 || (index as number) >= policy.maxCount) {
+      return `${config.purposes[purpose].label.replace(/s$/, "")} index must be between 0 and ${policy.maxCount - 1}.`;
+    }
+    return null;
+  }
+  if (index !== undefined && index !== 0) return "This upload purpose accepts one image only.";
+  return null;
+}
+
 export function selectAllowedImageFiles<T extends { type: unknown }>(files: Iterable<T>, limit: number) {
   const selected = Array.from(files);
   return {
diff --git a/lib/uploads/references-server.ts b/lib/uploads/references-server.ts
index 127493b..c196e4a 100644
--- a/lib/uploads/references-server.ts
+++ b/lib/uploads/references-server.ts
@@ -6,6 +6,7 @@ const PAGE_SIZE = 1000;
 type MediaReferenceRows = {
   profiles: Array<{ avatar_url: string | null; header_url: string | null }>;
   listings: Array<{ images: string[] | null }>;
+  posts: Array<{ images: string[] | null }>;
   events: Array<{ cover_image_url: string | null; logo_url: string | null }>;
 };
 
@@ -39,21 +40,23 @@ async function fetchAllRows<T>(table: string, columns: string): Promise<T[]> {
 }
 
 export async function readAllMediaReferences(): Promise<MediaReferenceRows> {
-  const [profiles, listings, events] = await Promise.all([
+  const [profiles, listings, posts, events] = await Promise.all([
     fetchAllRows<MediaReferenceRows["profiles"][number]>("profiles", "avatar_url, header_url"),
     fetchAllRows<MediaReferenceRows["listings"][number]>("listings", "images"),
+    fetchAllRows<MediaReferenceRows["posts"][number]>("posts", "images"),
     fetchAllRows<MediaReferenceRows["events"][number]>("events", "cover_image_url, logo_url"),
   ]);
-  return { profiles, listings, events };
+  return { profiles, listings, posts, events };
 }
 
 export async function isMediaKeyReferenced(key: string) {
   const publicBaseUrl = process.env.NEXT_PUBLIC_R2_PUBLIC_URL;
   if (!publicBaseUrl) throw new Error("R2 public URL is not configured.");
-  const { profiles, listings, events } = await readAllMediaReferences();
+  const { profiles, listings, posts, events } = await readAllMediaReferences();
   return mediaValuesReferenceKey([
     profiles.flatMap((row) => [row.avatar_url, row.header_url]),
     listings.map((row) => row.images ?? []),
+    posts.map((row) => row.images ?? []),
     events.flatMap((row) => [row.cover_image_url, row.logo_url]),
   ], key, publicBaseUrl);
 }
diff --git a/lib/uploads/token.ts b/lib/uploads/token.ts
index 4db935e..a03cbb0 100644
--- a/lib/uploads/token.ts
+++ b/lib/uploads/token.ts
@@ -4,6 +4,7 @@ import {
   getUploadPolicy,
   isAllowedImageType,
   isUploadPurpose,
+  validateUploadIndex,
   type AllowedImageType,
   type UploadPurpose,
 } from "./policy.ts";
@@ -60,8 +61,7 @@ export function verifyUploadToken(token: string, secret: string, now = Date.now(
 
     const extension = getSafeExtension(value.contentType!);
     const policy = getUploadPolicy(value.purpose!);
-    if (value.purpose === "listing-image" && (value.index === undefined || value.index < 0 || value.index >= policy.maxCount)) return null;
-    if (value.purpose !== "listing-image" && value.index !== undefined && value.index !== 0) return null;
+    if (validateUploadIndex(value.purpose!, value.index)) return null;
     if (
       !extension ||
       value.key !== `pending/${value.userId}/${value.uploadId}.${extension}` ||
diff --git a/lib/uploads/trusted-upload-server.ts b/lib/uploads/trusted-upload-server.ts
index fb95293..3508ca9 100644
--- a/lib/uploads/trusted-upload-server.ts
+++ b/lib/uploads/trusted-upload-server.ts
@@ -7,6 +7,7 @@ import {
   isAllowedImageType,
   isUploadPurpose,
   validateUploadDeclaration,
+  validateUploadIndex,
 } from "./policy.ts";
 import { cleanupUploadIntent, promoteUploadIntent } from "./promotion-server.ts";
 import { consumeUploadIntentRateLimit, type UploadIntentRateLimitResult } from "./rate-limit-server.ts";
@@ -47,6 +48,7 @@ export type TrustedUploadDependencies = {
 };
 
 function validatePreparedInput(input: TrustedUploadPreparedInput) {
+  if (input.purpose === "post-image") throw new Error("Post image uploads are not supported by the CLI.");
   if (!isUploadPurpose(input.purpose)) throw new Error("Unknown upload purpose.");
   if (!input.userId || !input.ownerId) throw new Error("A verified owner user and profile are required.");
   if (!(input.body instanceof Uint8Array) || input.body.byteLength !== input.size) {
@@ -59,16 +61,8 @@ function validatePreparedInput(input: TrustedUploadPreparedInput) {
     throw new Error("The prepared image content did not match its upload declaration.");
   }
 
-  const policy = getUploadPolicy(input.purpose);
-  if (
-    input.purpose === "listing-image" &&
-    (!Number.isInteger(input.index) || input.index! < 0 || input.index! >= policy.maxCount)
-  ) {
-    throw new Error(`Listing image index must be between 0 and ${policy.maxCount - 1}.`);
-  }
-  if (input.purpose !== "listing-image" && input.index !== undefined && input.index !== 0) {
-    throw new Error("This upload purpose accepts one image only.");
-  }
+  const indexError = validateUploadIndex(input.purpose, input.index);
+  if (indexError) throw new Error(indexError);
   if (input.resourceId !== undefined && typeof input.resourceId !== "string") {
     throw new Error("Invalid upload resource.");
   }
@@ -191,6 +185,7 @@ async function authorizeTrustedUpload(
 }
 
 export async function uploadTrustedImage(input: TrustedUploadInput) {
+  if (input.purpose === "post-image") throw new Error("Post image uploads are not supported by the CLI.");
   if (!isUploadPurpose(input.purpose)) throw new Error("Unknown upload purpose.");
   const policy = getUploadPolicy(input.purpose);
   const fileStat = await stat(input.localFile);
diff --git a/scripts/cleanup-promoted-pending.js b/scripts/cleanup-promoted-pending.js
index cdeb1a4..0dd9d44 100644
--- a/scripts/cleanup-promoted-pending.js
+++ b/scripts/cleanup-promoted-pending.js
@@ -81,13 +81,15 @@ function keyFromPublicUrl(value) {
 
 async function referencedKeys() {
   const keys = new Set();
-  const [profiles, listings, events] = await Promise.all([
+  const [profiles, listings, posts, events] = await Promise.all([
     fetchAllRows("profiles", "avatar_url, header_url"),
     fetchAllRows("listings", "images"),
+    fetchAllRows("posts", "images"),
     fetchAllRows("events", "cover_image_url, logo_url"),
   ]);
   for (const row of profiles) for (const value of [row.avatar_url, row.header_url]) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
   for (const row of listings) for (const value of row.images || []) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
+  for (const row of posts) for (const value of row.images || []) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
   for (const row of events) for (const value of [row.cover_image_url, row.logo_url]) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
   return keys;
 }
diff --git a/scripts/report-r2-orphans.js b/scripts/report-r2-orphans.js
index fbd211f..5dd3d98 100644
--- a/scripts/report-r2-orphans.js
+++ b/scripts/report-r2-orphans.js
@@ -61,13 +61,15 @@ async function fetchAllRows(table, columns) {
 
 async function referencedKeys() {
   const keys = new Set();
-  const [profiles, listings, events] = await Promise.all([
+  const [profiles, listings, posts, events] = await Promise.all([
     fetchAllRows("profiles", "avatar_url, header_url"),
     fetchAllRows("listings", "images"),
+    fetchAllRows("posts", "images"),
     fetchAllRows("events", "cover_image_url, logo_url"),
   ]);
   for (const row of profiles) for (const value of [row.avatar_url, row.header_url]) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
   for (const row of listings) for (const value of row.images || []) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
+  for (const row of posts) for (const value of row.images || []) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
   for (const row of events) for (const value of [row.cover_image_url, row.logo_url]) { const key = keyFromPublicUrl(value); if (key) keys.add(key); }
   return keys;
 }
diff --git a/scripts/upload-r2.js b/scripts/upload-r2.js
index 3f14ad1..bda03e8 100644
--- a/scripts/upload-r2.js
+++ b/scripts/upload-r2.js
@@ -18,6 +18,9 @@ async function run() {
   if (!localFile || !purpose || !ownerHandle) {
     throw new Error("Usage: node scripts/upload-r2.js <file> <avatar|header|listing-image|event-flyer> <owner-handle> [listing-title|event-id]");
   }
+  if (purpose === "post-image") {
+    throw new Error("Post image uploads are not supported by the CLI.");
+  }
 
   const owner = await requireActiveOwner(ownerHandle);
   const resourceArg = titleParts.join(" ");
diff --git a/tests/trusted-cli-upload.test.ts b/tests/trusted-cli-upload.test.ts
index 02da2f5..50caef5 100644
--- a/tests/trusted-cli-upload.test.ts
+++ b/tests/trusted-cli-upload.test.ts
@@ -148,11 +148,11 @@ test("mandatory token verification blocks promotion and cleans only pending stat
   ]);
 });
 
-test("unsupported purposes fail before authorization or storage", async () => {
+test("post-image CLI uploads are explicitly rejected before authorization or storage", async () => {
   const testHarness = harness();
   await assert.rejects(
     uploadTrustedPreparedImageWithDependenciesForTests({ ...baseInput, purpose: "post-image" }, testHarness.dependencies),
-    /unknown upload purpose/i
+    /post image uploads are not supported by the CLI/i
   );
   assert.deepEqual(testHarness.calls, []);
 });
@@ -238,6 +238,11 @@ test("trusted CLI production path exposes no direct public PUT or public cleanup
   assert.doesNotMatch(helper, /PutObjectCommand|R2_BUCKET_NAME|HeadObjectCommand|GetObjectCommand/);
   assert.match(helper, /uploadTrustedImage\(/);
   assert.match(uploadScript, /ownerId: owner\.id/);
+  assert.ok(
+    uploadScript.indexOf('purpose === "post-image"') >= 0
+      && uploadScript.indexOf('purpose === "post-image"') < uploadScript.indexOf("await requireActiveOwner"),
+    "post-image CLI rejection must run before owner authorization"
+  );
   assert.match(uploadScript, /resourceId: listing\?\.id/);
   assert.match(createScript, /ownerId: profile\.id/);
   assert.match(createScript, /index: 0/);
diff --git a/tests/upload-cleanup.test.ts b/tests/upload-cleanup.test.ts
index 2288008..93b5adc 100644
--- a/tests/upload-cleanup.test.ts
+++ b/tests/upload-cleanup.test.ts
@@ -1,5 +1,6 @@
 import test from "node:test";
 import assert from "node:assert/strict";
+import { readFileSync } from "node:fs";
 
 import {
   mediaValuesReferenceKey,
@@ -24,8 +25,22 @@ test("pending cleanup derives only controlled promoted-key candidates", () => {
     `avatars/${USER}/${UPLOAD}.webp`,
     `headers/${USER}/${UPLOAD}.webp`,
     `listings/${USER}/${UPLOAD}.webp`,
+    `posts/${USER}/${UPLOAD}.webp`,
     `festivals/${USER}/${UPLOAD}.webp`,
   ]);
   assert.deepEqual(promotedKeyCandidatesForPending(`pending/${USER}/bad.webp`), []);
   assert.deepEqual(promotedKeyCandidatesForPending(`pending/../${UPLOAD}.webp`), []);
 });
+
+test("all complete reference scanners include post image arrays", () => {
+  const scanners = [
+    "../lib/uploads/references-server.ts",
+    "../scripts/report-r2-orphans.js",
+    "../scripts/cleanup-promoted-pending.js",
+  ];
+  for (const file of scanners) {
+    const source = readFileSync(new URL(file, import.meta.url), "utf8");
+    assert.match(source, /fetchAllRows(?:<[^>]+>)?\("posts", "images"\)/, file);
+    assert.match(source, /posts\.map\(\(row\) => row\.images \?\? \[\]\)|row of posts[^\n]*row\.images \|\| \[\]/, file);
+  }
+});
diff --git a/tests/upload-intent.test.ts b/tests/upload-intent.test.ts
index c535f9a..7fad713 100644
--- a/tests/upload-intent.test.ts
+++ b/tests/upload-intent.test.ts
@@ -42,3 +42,27 @@ test("listing slot index is part of the signed intent and remains bounded", () =
   const invalidIndex = createUploadToken({ ...payload, index: 5 }, secret);
   assert.equal(verifyUploadToken(invalidIndex, secret, 1_900_000_000_000), null);
 });
+
+test("post-image tokens require slots zero through four and derive the posts key", () => {
+  const postPayload = {
+    ...payload,
+    purpose: "post-image" as const,
+    resourceId: "post-123",
+    finalKey: "posts/user-123/upload-123.webp",
+  };
+  for (const index of [0, 4]) {
+    const candidate = { ...postPayload, index };
+    const token = createUploadToken(candidate, secret);
+    assert.deepEqual(verifyUploadToken(token, secret, 1_900_000_000_000), candidate);
+  }
+  for (const index of [undefined, -1, 1.5, 5]) {
+    const candidate = { ...postPayload, index };
+    const token = createUploadToken(candidate, secret);
+    assert.equal(verifyUploadToken(token, secret, 1_900_000_000_000), null);
+  }
+  const arbitraryKey = createUploadToken({
+    ...postPayload,
+    finalKey: "posts/another-user/upload-123.webp",
+  }, secret);
+  assert.equal(verifyUploadToken(arbitraryKey, secret, 1_900_000_000_000), null);
+});
diff --git a/tests/upload-policy.test.ts b/tests/upload-policy.test.ts
index 7a60594..041fd6f 100644
--- a/tests/upload-policy.test.ts
+++ b/tests/upload-policy.test.ts
@@ -1,6 +1,7 @@
 import test from "node:test";
 import assert from "node:assert/strict";
 import { readFileSync } from "node:fs";
+import { authorizeUpload } from "../lib/uploads/authorization.ts";
 
 import {
   ALLOWED_IMAGE_TYPES,
@@ -13,6 +14,7 @@ import {
   getClientResizeDimensions,
   selectAllowedImageFiles,
   UNSUPPORTED_IMAGE_TYPE_MESSAGE,
+  validateUploadIndex,
 } from "../lib/uploads/policy.ts";
 import {
   IMMEDIATE_DELETE_REASONS,
@@ -31,6 +33,11 @@ test("approved upload policy limits are centralized", () => {
     maxBytes: 10 * MiB,
     maxCount: 5,
   });
+  assert.deepEqual(getUploadPolicy("post-image"), {
+    folder: "posts",
+    maxBytes: 10 * MiB,
+    maxCount: 5,
+  });
   assert.deepEqual(getUploadPolicy("avatar"), {
     folder: "avatars",
     maxBytes: 5 * MiB,
@@ -40,11 +47,55 @@ test("approved upload policy limits are centralized", () => {
   assert.equal(getUploadPolicy("event-flyer").maxBytes, 10 * MiB);
 });
 
+test("multi-image purposes require a bounded integer slot", () => {
+  for (const purpose of ["listing-image", "post-image"] as const) {
+    assert.equal(validateUploadIndex(purpose, 0), null);
+    assert.equal(validateUploadIndex(purpose, 4), null);
+    assert.match(validateUploadIndex(purpose, undefined) ?? "", /between 0 and 4/);
+    assert.match(validateUploadIndex(purpose, -1) ?? "", /between 0 and 4/);
+    assert.match(validateUploadIndex(purpose, 1.5) ?? "", /between 0 and 4/);
+    assert.match(validateUploadIndex(purpose, 5) ?? "", /between 0 and 4/);
+  }
+  assert.equal(validateUploadIndex("avatar", undefined), null);
+  assert.equal(validateUploadIndex("avatar", 0), null);
+  assert.equal(validateUploadIndex("avatar", 1), "This upload purpose accepts one image only.");
+});
+
+test("existing post resources must belong to the upload owner", async () => {
+  function client(postProfileId: string) {
+    return {
+      rpc: async () => ({ data: false, error: null }),
+      from: (table: string) => ({
+        select: () => ({
+          eq: () => ({
+            maybeSingle: async () => table === "profiles"
+              ? { data: { id: "profile-1", user_id: "user-1" }, error: null }
+              : { data: { id: "post-1", profile_id: postProfileId }, error: null },
+          }),
+        }),
+      }),
+    };
+  }
+
+  assert.deepEqual(await authorizeUpload(client("profile-1") as never, "user-1", {
+    purpose: "post-image",
+    ownerId: "profile-1",
+    resourceId: "post-1",
+  }), { ok: true });
+  assert.deepEqual(await authorizeUpload(client("profile-2") as never, "user-1", {
+    purpose: "post-image",
+    ownerId: "profile-1",
+    resourceId: "post-1",
+  }), { ok: false, status: 403, error: "You do not own this post." });
+});
+
 test("declaration validation rejects unapproved MIME types and oversize files", () => {
   assert.equal(validateUploadDeclaration("avatar", "image/webp", 5 * MiB), null);
   assert.equal(validateUploadDeclaration("avatar", "image/svg+xml", 100), "Only JPEG, PNG, and WebP images are allowed.");
   assert.equal(validateUploadDeclaration("avatar", "image/jpeg", 5 * MiB + 1), "Avatar images must be 5 MB or smaller.");
   assert.equal(validateUploadDeclaration("listing-image", "image/png", 10 * MiB + 1), "Listing images must be 10 MB or smaller.");
+  assert.equal(validateUploadDeclaration("post-image", "image/webp", 10 * MiB), null);
+  assert.equal(validateUploadDeclaration("post-image", "image/png", 10 * MiB + 1), "Post images must be 10 MB or smaller.");
   assert.equal(validateUploadDeclaration("listing-image", "image/jpeg", 0), "The image file is empty.");
 });
 
```
