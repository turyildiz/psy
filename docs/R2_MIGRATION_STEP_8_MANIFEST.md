# R2 Migration Step 8 — Approved Profile-Media Manifest

**Project:** psy.market

**Document type:** Versioned migration-scope manifest

**Status:** Approved scope — execution requires a separate instruction

**Version:** 1.0

**Created:** 2026-07-18

**Owner:** Turgay Yildiz

---

## 1. Decision

Step 8 approves exactly three runtime profile-media objects for a later Supabase Storage to Cloudflare R2 migration:

1. Turgay profile avatar.
2. Turgay profile header.
3. Otis profile avatar.

The approved source total is **463,785 bytes**. All three source objects were retrievable when the manifest was prepared, and all three proposed R2 destinations were absent.

The dormant `featured_sellers.image_url` reference for Yacxilan is explicitly excluded. It must not be copied to R2 because the table has no runtime consumer and is scheduled for removal under database Chunk 9. Its row and source object are recorded separately in Section 5 so they cannot be forgotten during later dead-schema and Supabase Storage retirement approval.

---

## 2. Namespace decision

Production upload keys use the authenticated Supabase Auth user ID, not the public profile row ID:

```text
{purpose-folder}/{authenticated user.id}/{upload UUID}.{safe extension}
```

The production presign route creates final keys from `user.id`. Upload authorization separately confirms that the requested owner profile satisfies `profiles.user_id = user.id`. The signed upload intent then binds the authenticated user ID, profile owner ID, purpose folder, upload UUID, MIME type, and extension.

The approved migration keys therefore use each profile's owning `profiles.user_id`. Their folders, UUID filenames, and JPEG extensions match the production namespace and remain structurally compatible with ownership validation and future replacement/orphan reporting.

The UUID filenames below are deterministic UUIDv5 values derived from each exact source URL and SHA-256 checksum. This makes the proposal repeatable and collision-resistant without reusing legacy filenames.

---

## 3. Approved migration manifest

### 3.1 Turgay avatar

| Field | Value |
|---|---|
| Table | `profiles` |
| Profile row ID | `a76d80cd-f584-4a6b-bb54-89e77155a576` |
| Owning user ID | `b03d0533-1931-47c3-abce-f2d601698bf9` |
| Profile handle | `turgay` |
| Column | `avatar_url` |
| Array position | Not applicable |
| Exact source URL | `https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg` |
| Supabase bucket | `avatars` |
| Supabase object key | `a76d80cd-f584-4a6b-bb54-89e77155a576/1780503451588.jpg` |
| Source MIME type | `image/jpeg` |
| Source byte size | `117,243` |
| Source SHA-256 | `60b837ffc1b445c11268dfb25735083524fe08fa932f625a6e7c4b5794cc30f9` |
| Approved R2 key | `avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg` |
| Approved canonical URL | `https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg` |
| Destination status at review | Absent |

### 3.2 Turgay profile header

| Field | Value |
|---|---|
| Table | `profiles` |
| Profile row ID | `a76d80cd-f584-4a6b-bb54-89e77155a576` |
| Owning user ID | `b03d0533-1931-47c3-abce-f2d601698bf9` |
| Profile handle | `turgay` |
| Column | `header_url` |
| Array position | Not applicable |
| Exact source URL | `https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg` |
| Supabase bucket | `avatars` |
| Supabase object key | `b03d0533-1931-47c3-abce-f2d601698bf9/header.jpg` |
| Source MIME type | `image/jpeg` |
| Source byte size | `216,455` |
| Source SHA-256 | `7faeadabcb744153b3c50afdcecbb551af0f64cba733e306a07c1c35dc729c82` |
| Approved R2 key | `headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg` |
| Approved canonical URL | `https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg` |
| Destination status at review | Absent |

### 3.3 Otis avatar

| Field | Value |
|---|---|
| Table | `profiles` |
| Profile row ID | `b87ae4ee-d79a-40a1-a793-9b30251b2ee0` |
| Owning user ID | `7aba9d97-2572-4f40-9858-27c3892191cb` |
| Profile handle | `otis` |
| Column | `avatar_url` |
| Array position | Not applicable |
| Exact source URL | `https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif` |
| Supabase bucket | `avatars` |
| Supabase object key | `7aba9d97-2572-4f40-9858-27c3892191cb/avatar.jfif` |
| Source MIME type | `image/jpeg` |
| Source byte size | `130,087` |
| Source SHA-256 | `1d8a7d7260229ba24638139aeaeaf5d7d04b734c616b08b09005a39092e5f8ce` |
| Approved R2 key | `avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg` |
| Approved canonical URL | `https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg` |
| Destination status at review | Absent |

### 3.4 Approved totals

| Metric | Value |
|---|---:|
| Approved objects | 3 |
| Approved profile rows | 2 |
| Approved bytes | **463,785** |
| Existing proposed destinations | **0** |

---

## 4. Storage-inventory reconciliation

The earlier approximately 6 MiB estimate describes the complete contents of the relevant legacy Supabase Storage buckets, not the runtime-referenced migration scope.

| Supabase bucket | Object count | Total bytes |
|---|---:|---:|
| `avatars` | 7 | 5,463,443 |
| `headers` | 1 | 912,673 |
| **Complete relevant bucket inventory** | **8** | **6,376,116** |

`6,376,116` bytes is approximately 6.081 MiB. Most of that inventory is not part of the approved runtime profile-media migration.

The wider schema review found four database-held Supabase Storage URLs totaling 1,376,458 bytes. Three runtime profile references totaling 463,785 bytes are approved here. The remaining 912,673-byte `featured_sellers` reference is excluded and deferred as dead-schema data.

---

## 5. Excluded and deferred legacy reference

### Yacxilan featured-seller image

| Field | Value |
|---|---|
| Decision | **Excluded — do not migrate to R2** |
| Reason | `featured_sellers` is dormant, has no runtime consumer, and is scheduled for removal in database Chunk 9. Copying this object would create an unnecessary R2 orphan. |
| Table | `featured_sellers` |
| Row ID | `af51e0fe-0f73-4636-bdc1-62e26e8fe74a` |
| Owning profile row ID | `26e48650-0fef-45a5-b6eb-3da895450ccf` |
| Owning user ID | `2c14f3e8-b173-406f-ba9b-c017b18bb87f` |
| Profile handle | `yacxilan` |
| Column | `image_url` |
| Exact source URL | `https://uabuhtrtommkfmlhseul.supabase.co/storage/v1/object/public/headers/yacxilan/header.jpg` |
| Supabase bucket | `headers` |
| Supabase object key | `yacxilan/header.jpg` |
| Source MIME type | `image/jpeg` |
| Source byte size | `912,673` |
| Source SHA-256 | `2d27965f5f42e7be9ab255e61fece7d17a2e8dd03df872cbbba1c7d826815ecc` |
| Required later handling | Include this row and source object explicitly in the reviewed dead-schema export/removal and Supabase Storage retirement manifest before Chunk 9 or Storage deletion is executed. |

Chunk 9 is destructive and remains separately approval-gated. This document does not authorize removal of the row, table, bucket, or source object.

---

## 6. Bundled music hero decision

`public/music-hero.jpg` remains a bundled, Git-tracked repository asset.

- Runtime reference: `app/music/page.tsx`
- It is fixed application presentation media, not user-owned content.
- It should not be migrated to R2.
- Its large JPEG dimensions and byte size should be addressed later as a separate performance task, preferably by replacing it with an optimized bundled WebP or AVIF asset.

---

## 7. Execution boundaries

This document records the approved Step 8 scope. It does **not** itself authorize or perform any of the following:

- database-row updates;
- migration SQL generation or execution;
- deletion of any Supabase Storage object;
- deletion of any R2 object;
- bucket or Storage-policy retirement;
- migration of the deferred Yacxilan object;
- removal of `featured_sellers` or any other database schema;
- deployment or application-code changes.

Copying the three approved objects, verifying their R2 copies, and rewriting profile URLs require an explicit subsequent execution instruction. Source-object deletion and Supabase Storage retirement require a later exact deletion manifest and separate destructive approval.
