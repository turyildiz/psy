# R2 Migration Step 9 — Object-Copy Execution Record

**Project:** psy.market

**Document type:** Versioned migration execution record

**Status:** Completed — object copy and verification only

**Version:** 1.0

**Executed:** 2026-07-18

**Approved source manifest:** `docs/R2_MIGRATION_STEP_8_MANIFEST.md`

**Owner:** Turgay Yildiz

---

## 1. Execution result

R2 migration Step 9 copied exactly the three approved runtime profile-media objects from the Step 8 manifest to the active public R2 bucket.

- Approved objects: 3
- Copied objects: 3
- Verified objects: 3
- Total copied bytes: **463,785**
- Partial failures: 0
- Database rows updated: 0
- Supabase source objects altered or deleted: 0
- Deferred legacy objects copied: 0

The active destination configuration at execution time was:

| Setting | Value |
|---|---|
| Public R2 bucket | `psy-market-images` |
| Canonical public base URL | `https://images.psy.market` |
| Object content type | `image/jpeg` |
| Cache-Control metadata | Not set, matching the current promoted-upload `PutObject` pipeline |

---

## 2. Read-only preflight

All preconditions were checked before the first R2 write.

For each approved object, the preflight confirmed:

1. The database field still contained the exact Supabase URL recorded in Step 8.
2. The Supabase source returned HTTP 200.
3. Source MIME type was exactly `image/jpeg`.
4. Source byte size exactly matched the manifest.
5. Source SHA-256 exactly matched the manifest.
6. The approved R2 destination key was absent.
7. The canonical URL matched the active `NEXT_PUBLIC_R2_PUBLIC_URL` configuration.
8. The destination bucket matched the active public media bucket configuration.

**Preflight result:** PASS — 3 of 3 objects satisfied every precondition.

---

## 3. Copy and independent verification evidence

The original response bytes were written directly to the approved R2 keys. No image was transformed, resized, re-encoded, recompressed, or renamed beyond the approved destination key.

Every write used create-only semantics so an existing destination could not be overwritten.

### 3.1 Turgay avatar

| Field | Result |
|---|---|
| Profile row ID | `a76d80cd-f584-4a6b-bb54-89e77155a576` |
| Database field | `profiles.avatar_url` |
| Source URL | `https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg` |
| Destination key | `avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg` |
| Canonical URL | `https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg` |
| R2 metadata MIME | `image/jpeg` |
| R2 metadata bytes | `117,243` |
| Public HTTP result | `200`, `image/jpeg`, `117,243` bytes |
| Destination SHA-256 | `60b837ffc1b445c11268dfb25735083524fe08fa932f625a6e7c4b5794cc30f9` |
| Source/destination equality | Byte-for-byte identical |
| Fresh database check | Still references the exact original Supabase URL |
| Result | **PASS** |

### 3.2 Turgay profile header

| Field | Result |
|---|---|
| Profile row ID | `a76d80cd-f584-4a6b-bb54-89e77155a576` |
| Database field | `profiles.header_url` |
| Source URL | `https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg` |
| Destination key | `headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg` |
| Canonical URL | `https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg` |
| R2 metadata MIME | `image/jpeg` |
| R2 metadata bytes | `216,455` |
| Public HTTP result | `200`, `image/jpeg`, `216,455` bytes |
| Destination SHA-256 | `7faeadabcb744153b3c50afdcecbb551af0f64cba733e306a07c1c35dc729c82` |
| Source/destination equality | Byte-for-byte identical |
| Fresh database check | Still references the exact original Supabase URL |
| Result | **PASS** |

### 3.3 Otis avatar

| Field | Result |
|---|---|
| Profile row ID | `b87ae4ee-d79a-40a1-a793-9b30251b2ee0` |
| Database field | `profiles.avatar_url` |
| Source URL | `https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif` |
| Destination key | `avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg` |
| Canonical URL | `https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg` |
| R2 metadata MIME | `image/jpeg` |
| R2 metadata bytes | `130,087` |
| Public HTTP result | `200`, `image/jpeg`, `130,087` bytes |
| Destination SHA-256 | `1d8a7d7260229ba24638139aeaeaf5d7d04b734c616b08b09005a39092e5f8ce` |
| Source/destination equality | Byte-for-byte identical |
| Fresh database check | Still references the exact original Supabase URL |
| Result | **PASS** |

---

## 4. Fresh post-copy database check

After all three copy and HTTP-verification operations completed, the database was read again.

All three fields still contained their exact original Supabase Storage URLs. No profile row was updated in Step 9.

| Database field | Post-copy reference state |
|---|---|
| Turgay `profiles.avatar_url` | Exact original Supabase URL retained |
| Turgay `profiles.header_url` | Exact original Supabase URL retained |
| Otis `profiles.avatar_url` | Exact original Supabase URL retained |

---

## 5. Exclusions confirmed

The following were not read as migration inputs, copied, changed, or deleted by Step 9:

- the deferred `featured_sellers.image_url` object for Yacxilan;
- `public/music-hero.jpg`;
- every Supabase Storage object outside the three-object Step 8 approval;
- every R2 object outside the three approved destination keys.

No Supabase source object was altered or deleted.

---

## 6. Remaining authorization boundaries

Step 9 completed object copy and verification only. It does **not** authorize or perform:

- changing `profiles.avatar_url` or `profiles.header_url` to the R2 URLs;
- any other database-row update;
- migration SQL generation or execution;
- deletion or alteration of a Supabase source object;
- deletion of an R2 destination;
- migration of the deferred Yacxilan object;
- removal of `featured_sellers` or execution of database Chunk 9;
- Supabase Storage bucket or policy retirement;
- application deployment.

The database URL switch requires a separate explicit instruction and fresh preflight. Supabase source deletion requires a later exact deletion manifest, observation period, and separate destructive approval.
