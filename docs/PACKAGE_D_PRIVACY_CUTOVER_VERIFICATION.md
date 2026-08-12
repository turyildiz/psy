# Package D privacy cutover — live application and verification

**Date:** 2026-08-12

**Status:** PASS — live

**Apply method:** Turgay executed the reviewed Package D SQL artifacts one at a time in Supabase SQL Editor as project owner.

**Verification method:** Owner-run preflight/apply/verify ritual against the live database, an independent REST probe from the VPS before and after apply, and Turgay's authenticated staging click-round.

## Purpose and scope

Package D closes direct public access to private profile-account linkage at the database privilege layer. It removes table-wide `SELECT` from `anon` and `authenticated`, then grants both roles column-level `SELECT` on exactly the 12 columns in `PUBLIC_PROFILE_SELECT`:

- `id`
- `type`
- `handle`
- `display_name`
- `bio`
- `avatar_url`
- `header_url`
- `location`
- `social_links`
- `is_creator`
- `is_verified`
- `created_at`

Direct access to `user_id`, `is_suspended` and `updated_at` is denied to both public API roles. The cutover changes column privileges only: it does not change profile row visibility, RLS enablement, RLS policies, helper definitions, table schema or unrelated privileges.

## Live execution record

| Step | Live result |
|---|---|
| Package D preflight | GO; no findings |
| Complete pre-cutover ACL capture | 33 entries; exact match to the package's pinned expectation |
| Package D apply | Committed cleanly on the first live run; no refusal |
| Package D verify | GO — 33 of 33 checks passed |
| Independent REST probe before apply | `profiles?select=id,user_id` returned HTTP 200 with data; reconfirmed on 2026-08-12 |
| Independent REST probe after apply | The same owner-ID request returned HTTP 401 / SQLSTATE `42501`, `permission denied for table profiles` |
| Safe-column REST probe after apply | HTTP 200 |
| Authenticated staging click-round | PASS |
| Rollback | Available; not needed |

## Database verification result

The owner-run live verifier returned:

- overall status: **GO**;
- proven checks: **33 of 33**;
- findings: **none**;
- all 12 approved public columns readable as `anon` and `authenticated`;
- `user_id`, `is_suspended`, `updated_at` and wildcard `select=*` denied as each public role;
- every expected denial reported SQLSTATE **`42501`**;
- approved embedded profile relationships remained readable;
- row-level visibility remained unchanged;
- `get_my_profiles`, `current_user_owns_profile` and `admin_get_profile_account` remained intact through their reviewed `SECURITY DEFINER` boundary;
- full `service_role` and owner access remained intact.

## Independent REST evidence

The wingman ran an independent PostgREST probe from the VPS. Before the ritual—and reconfirmed immediately before apply on 2026-08-12—an anonymous request for `profiles?select=id,user_id` returned HTTP 200 with data.

After apply, the same request returned HTTP 401 with SQLSTATE `42501` and `permission denied for table profiles`. Requests restricted to the approved safe columns continued to return HTTP 200. This independently proves that the former anonymous owner-ID exposure is closed at the database/API privilege boundary rather than merely hidden by application query discipline.

## Staging acceptance

Turgay completed an authenticated staging click-round after the live cutover. The following surfaces behaved normally:

- homepage;
- listing detail;
- public profile;
- Stream;
- festival pages;
- inbox;
- profile editing.

No application regression was observed in that round.

## Rollback status

The reviewed rollback artifact remains available and restores the exact pinned pre-cutover ACL. It was not needed because preflight, apply, database verification, independent REST verification and staging acceptance all passed.

## Conclusion

Package D is live and verified as of 2026-08-12. Anonymous and authenticated owner-ID exposure is closed at the database level. The public read surface of `public.profiles` is now exactly the 12 `PUBLIC_PROFILE_SELECT` columns.

This satisfies the privacy precondition that blocked Multi-Profile cardinality enablement. It does not itself enable multiple profiles: the MP-3 cardinality, profile-type and active-profile/session foundations remain open. The next guarded database operation is the MP-3 foundation slice.
