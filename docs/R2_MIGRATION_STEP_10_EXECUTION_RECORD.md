# R2 Migration Step 10 — Database-Switch Execution Record

**Project:** psy.market

**Document type:** Versioned migration execution record

**Status:** Completed — owner-applied database switch and acceptance verification

**Version:** 1.0

**Executed:** 2026-07-18

**Approved source manifest:** `docs/R2_MIGRATION_STEP_8_MANIFEST.md`

**Object-copy execution record:** `docs/R2_MIGRATION_STEP_9_EXECUTION_RECORD.md`

**Owner-applied SQL package:** commit `4825980ee3098c01374c347b88b550ba9f25cc7a`

**Owner:** Turgay Yildiz

---

## 1. Execution result

R2 migration Step 10 completed the owner-applied transactional switch for the three approved runtime profile-media URL fields.

- Profile rows switched: **2**
- URL fields switched: **3**
- Turgay avatar fields switched: 1
- Turgay header fields switched: 1
- Otis avatar fields switched: 1
- Rollback required: **No**
- Application or SQL artifacts changed during execution: 0
- Storage objects copied, altered, or deleted during execution: 0

The owner pasted and executed the committed apply artifact from:

- Commit: `4825980ee3098c01374c347b88b550ba9f25cc7a`
- Artifact: `supabase/chunks/step-10-profile-media-switch-apply.sql`
- Artifact SHA-256: `5b26ad5a2fd875a3b8746bde825dfd722fd201a1648137e1511fa5ced70cb25b`

The transaction completed successfully. Its final result showed both target profile rows with the expected canonical R2 media URLs and updated `updated_at` values.

---

## 2. Exact switched scope

| Profile | Profile row ID | Owning user ID | Field | Canonical R2 URL |
|---|---|---|---|---|
| Turgay (`turgay`) | `a76d80cd-f584-4a6b-bb54-89e77155a576` | `b03d0533-1931-47c3-abce-f2d601698bf9` | `profiles.avatar_url` | `https://images.psy.market/avatars/b03d0533-1931-47c3-abce-f2d601698bf9/0c45443d-066e-5dfc-b930-6e73531e56d3.jpg` |
| Turgay (`turgay`) | `a76d80cd-f584-4a6b-bb54-89e77155a576` | `b03d0533-1931-47c3-abce-f2d601698bf9` | `profiles.header_url` | `https://images.psy.market/headers/b03d0533-1931-47c3-abce-f2d601698bf9/faa1dafa-2ea2-5852-a83f-527c2d18a917.jpg` |
| Otis (`otis`) | `b87ae4ee-d79a-40a1-a793-9b30251b2ee0` | `7aba9d97-2572-4f40-9858-27c3892191cb` | `profiles.avatar_url` | `https://images.psy.market/avatars/7aba9d97-2572-4f40-9858-27c3892191cb/cedc6736-78b2-5849-a1a8-6db03ac0d9fd.jpg` |

No unrelated profile field was intentionally changed. The existing `tr_profiles_updated_at` trigger updated `updated_at` on the two switched rows as expected.

Otis's `header_url` remained the bundled `/music-hero.jpg` asset and was not part of the migration.

---

## 3. Owner-run consolidated database verification

The owner ran the compact read-only post-apply verification. It returned one summary row with the following values:

| Check | Result |
|---|---:|
| `switched_profile_rows` | `2` |
| `matching_r2_url_fields` | `3` |
| `turgay_exact_state` | `true` |
| `otis_exact_state` | `true` |
| `old_supabase_runtime_reference_count` | `0` |
| `deferred_yacxilan_reference_unchanged` | `true` |
| `all_database_checks_pass` | `true` |

**Owner verification result:** PASS.

---

## 4. Independent read-only verification

A separate read-only post-apply verification confirmed:

1. Turgay's exact profile ID, owning user ID, handle, R2 avatar URL, and R2 header URL.
2. Otis's exact profile ID, owning user ID, handle, and R2 avatar URL.
3. Exactly two profile rows contained exactly three approved R2 URL fields.
4. The three original Supabase URLs had zero remaining references in runtime profile, listing, and event media fields.
5. The deferred Yacxilan `featured_sellers.image_url` reference remained unchanged.
6. No database mutation was performed by the verification.

**Independent database verification result:** PASS.

---

## 5. Destination and rollback-source verification

All three public R2 destinations and all three original Supabase source objects were fetched again after the database switch.

| Object | HTTP | MIME | Bytes | SHA-256 | Result |
|---|---:|---|---:|---|---|
| Turgay avatar — R2 | 200 | `image/jpeg` | 117,243 | `60b837ffc1b445c11268dfb25735083524fe08fa932f625a6e7c4b5794cc30f9` | PASS |
| Turgay header — R2 | 200 | `image/jpeg` | 216,455 | `7faeadabcb744153b3c50afdcecbb551af0f64cba733e306a07c1c35dc729c82` | PASS |
| Otis avatar — R2 | 200 | `image/jpeg` | 130,087 | `1d8a7d7260229ba24638139aeaeaf5d7d04b734c616b08b09005a39092e5f8ce` | PASS |
| Turgay avatar — original Supabase source | 200 | `image/jpeg` | 117,243 | `60b837ffc1b445c11268dfb25735083524fe08fa932f625a6e7c4b5794cc30f9` | PASS |
| Turgay header — original Supabase source | 200 | `image/jpeg` | 216,455 | `7faeadabcb744153b3c50afdcecbb551af0f64cba733e306a07c1c35dc729c82` | PASS |
| Otis avatar — original Supabase source | 200 | `image/jpeg` | 130,087 | `1d8a7d7260229ba24638139aeaeaf5d7d04b734c616b08b09005a39092e5f8ce` | PASS |

The original Supabase objects remain intact as verified rollback sources. No source or destination object was altered or deleted.

---

## 6. Owner hands-on staging acceptance

The owner completed hands-on acceptance against staging:

- `https://psy.heyturgay.com/turgay` displayed the migrated R2 avatar correctly.
- `https://psy.heyturgay.com/turgay` displayed the migrated R2 header correctly.
- `https://psy.heyturgay.com/otis` displayed the migrated R2 avatar correctly.
- Otis's unchanged bundled `/music-hero.jpg` header displayed correctly.

**Hands-on acceptance result:** PASS.

No staging deployment was required because Step 10 changed database references only and did not change application code.

---

## 7. Demo-data preservation decision

Current demo profiles and listings must remain available throughout development.

Any eventual pre-launch demo-data purge is a separate approval-gated task. It requires an exact reviewed deletion scope and must retain the `@turgay` profile. Step 10 does not authorize deleting demo profiles, listings, or related media.

---

## 8. Remaining authorization boundaries

Step 10 is complete, but it does **not** authorize or perform:

- deletion or alteration of any original Supabase source object;
- retirement of a Supabase Storage bucket or policy;
- deletion of an R2 destination;
- migration or deletion of the deferred Yacxilan object;
- modification or removal of the deferred `featured_sellers` row or table;
- execution of destructive database Chunk 9 work;
- deletion of current demo profiles, listings, or related media;
- application deployment.

Source deletion, Supabase Storage retirement, deferred Yacxilan disposition, database Chunk 9, and any pre-launch demo-data purge each remain separately approval-gated.
