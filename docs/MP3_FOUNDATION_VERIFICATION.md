# MP-3 foundation — live application and verification

**Date:** 2026-08-13

**Status:** PASS — live

**Apply method:** Turgay executed the reviewed MP-3 SQL artifacts one at a time in Supabase SQL Editor as project owner.

**Verification method:** Owner-run preflight/apply/verify ritual against the live PostgreSQL 17 database, wingman read-only catalog diagnosis and exact-fingerprint recomputation, followed by a staging QA round using Claude in Chrome and wingman evaluation of its findings.

## Purpose and scope

MP-3 installs the database foundations for future Multi-Profile cardinality and active-session work without enabling a second profile or changing the current application UI. Its live scope is:

- add the dormant `vendor` label to `public.profile_type`;
- prevent ordinary changes to `public.profiles.user_id`;
- enforce a locked maximum of five profiles per account and retain the non-unique owner lookup index;
- add private per-session active-profile state and hardened get/switch helpers;
- install the trusted additional-profile creation RPC without exposing it to client roles;
- preserve signup auto-creation and the existing one-profile barrier;
- preserve Package D profile privacy and all existing profile policies/helper contracts.

`profiles_one_per_user_key` remains in force as a bare unique index. MP-3 therefore does **not** permit a second profile, expose `vendor` in the application, or implement profile creation, switching, or deletion UI.

## Authoring and review history

The initial package in `d704cdb` contained two stale before-state fingerprints derived from a reconstructed disposable schema:

1. it treated `profiles_one_per_user_key` as a constraint row, while the live one-profile guard is a bare unique index; and
2. its reconstructed `public.handle_new_user()` body differed from the live signup function.

The wingman caught both issues during read-only pre-review against the live catalog **before any MP-3 SQL was executed live**. Commit `af0b2dd` corrected the package using wingman-supplied live evidence. No live database state was changed by the stale version.

## Live execution record

| Step | Live result |
|---|---|
| MP-3 preflight | GO; no findings |
| Guarded enum step | Completed cleanly; added the dormant `vendor` label outside the main transaction as required by PostgreSQL enum semantics |
| Transactional apply | Completed cleanly as an all-or-nothing transaction |
| First MP-3 verify | STOP — 17 of 19 checks passed |
| First-verify behavior checks | All passed; only two catalog-fingerprint checks failed |
| Wingman live diagnosis | Applied state confirmed functionally exact; no rollback needed |
| Rendering corrections | `eadd83b` and `01f8382`; every corrected pin recomputed against live and matched before rerun |
| Corrected MP-3 verify | GO — 19 of 19 checks passed |
| Post-verify staging QA | PASS on the tested surfaces |
| Rollback | Available; not needed |

## First VERIFY STOP and correction

The first live verifier returned STOP 17/19. All behavior and authorization checks passed. The two failures were caused by environment- and session-dependent text renderings embedded in otherwise correct fingerprints:

- LF versus CRLF line endings in function bodies;
- caller `search_path` changing whether type and object names were schema-qualified;
- PostgreSQL 17 adding `MAINTAIN` to the owner's raw table ACL rendering; and
- alternate legal renderings of an empty function `search_path`.

The wingman inspected the applied live catalog read-only and confirmed that the functions, constraints, indexes, triggers, schema lock, enum, ACL privilege sets, and Package D contracts were functionally exact. Rollback was neither required nor run.

Commits `eadd83b` and `01f8382` made the catalog checks environment-neutral by:

- canonicalizing the empty function `search_path` forms;
- comparing ACLs as exploded privilege sets rather than raw ACL text;
- stripping session-dependent schema qualification from catalog renderings; and
- hashing function bodies after whitespace-class normalization, making line endings irrelevant.

Before the verifier rerun, the wingman recomputed every corrected fingerprint against the live catalog and confirmed that all pins matched exactly.

## Database verification result

The corrected owner-run live verifier returned:

- overall status: **GO**;
- proven checks: **19 of 19**;
- findings: **none**;
- successful active-session helper behavior for current one-profile accounts had passed the package's disposable PostgreSQL behavior suite; the live verifier re-proved the fail-closed session paths without writing helper state;
- missing, malformed, or unauthorized session paths failed closed;
- client execution of the trusted additional-profile creation RPC remained denied;
- expected authorization denials reported SQLSTATE **`42501`**;
- the owner-immutability and locked five-profile-cap triggers were present and active;
- private session-active-profile state and its constraints/indexes/ACLs matched the exact reviewed manifest;
- `profiles_one_per_user_key` remained valid, unique, and in force;
- signup behavior and Package D profile privacy remained intact.

## Staging QA acceptance

The post-verify staging round was the first mission of the Claude-in-Chrome QA tester under [`DECISIONS_HANDOVER.md` §11](DECISIONS_HANDOVER.md#11-additions--decided-10-aug-2026-recorded-13-aug-2026). Claude operated the staging tab assigned by Turgay; the wingman evaluated the returned findings.

The tested surfaces behaved normally:

- homepage;
- public profile page;
- profile-edit round trip, including one edit and its revert; both writes saved successfully through the new profile triggers;
- Stream.

The `vendor` type was correctly absent from the profile-type UI. This is expected: MP-3 adds a dormant database enum label but does not change application types or expose vendor creation.

## Resulting live state

As of 2026-08-13:

- `vendor` exists as a dormant `public.profile_type` label;
- the five-profile-cap trigger is active;
- the ordinary owner-immutability trigger is active;
- `private.account_session_active_profiles` and the session-active helpers are live and restricted to authenticated use;
- the trusted additional-profile creation RPC is installed but unreachable by every client role;
- `profiles_one_per_user_key` is still in force, so the site remains one-profile-per-account;
- signup still creates exactly one personal profile;
- Package D database-enforced profile privacy remains intact and was re-verified.

These are database foundations only. User-visible Multi-Profile behavior remains disabled.

## Rollback status

The reviewed operational rollback exists and gates on the exact applied state. It removes the reversible MP-3 objects and restores the exact reviewed operational baseline. It was not needed during the live sitting.

The `vendor` enum label is deliberately non-removable by this rollback. PostgreSQL does not provide a safe supported in-place `DROP VALUE`; literal removal would require rebuilding the type and its dependencies and is outside this package. This limitation is documented in the SQL package and does not weaken the one-profile barrier.

## Process lessons

1. **Baseline pins must come from live-verified evidence.** A reconstructed disposable schema is useful for lifecycle testing, but it must never define the current-live fingerprint. Owner- or wingman-read catalog evidence is required.
2. **Hashed catalog text must be environment- and session-neutral.** Normalize line endings and whitespace, caller `search_path`, ACL rendering (including version-added privileges), and schema qualification before hashing. Prefer structural catalog fields and exploded privilege sets over raw rendered text.

## Conclusion and next guarded operation

MP-3 is live and verified as of 2026-08-13. Its foundations are active, Package D privacy remains intact, and current application behavior remains one-profile-per-account.

The next guarded database operation is [`Slice MP-4 — Database active-authorization and deletion foundation`](MULTI_PROFILE_PROPOSAL.md#slice-mp-4--database-active-authorization-and-deletion-foundation). That later slice must keep second-profile creation disabled while preparing active-profile-aware authorization and deletion foundations.
