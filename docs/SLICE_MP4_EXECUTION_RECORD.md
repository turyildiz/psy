# Slice MP-4 execution record

**Status:** ROLLING EXECUTION RECORD
**Started:** 2026-08-14
**Scope:** Slice MP-4 — database active-authorization and deletion foundation
**Authoring plan:** [`SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md`](SLICE_MP4_ACTIVE_AUTHORIZATION_PLAN.md)

## Purpose

This file is the single running execution source of truth for the eight guarded Slice MP-4 packages, MP4-A through MP4-H. It records what was actually applied and verified live; the authoring plan remains the source for intended package scope and ordering.

Each package receives one dated section after its live sitting. Future package results must be appended here rather than recorded as separate implementation-status entries elsewhere.

| Package | Live status |
|---|---|
| MP4-A | Live and verified — 2026-08-15 |
| MP4-B | Live and verified — 2026-08-15 |
| MP4-C | Not yet authored/applied |
| MP4-D | Not yet authored/applied |
| MP4-E | Not yet authored/applied |
| MP4-F | Not yet authored/applied |
| MP4-G | Not yet authored/applied |
| MP4-H | Not yet authored/applied |

---

## 2026-08-15 — MP4-A: active-profile authorization primitives

### Scope

MP4-A installs the read-only active-profile authorization primitives required by later Slice MP-4 packages:

- a private active-profile resolver that client roles cannot execute;
- authenticated-only public accessors for active-profile identity, active-profile equality, and active-plus-unsuspended equality;
- guarded compatibility with the still-enforced one-profile model.

MP4-A does not convert any policy or existing authorization consumer to use these primitives.

### Review and evidence process

- The MP4-A package review was performed by the **MOBILE wingman**, including independent pin reproduction.
- The **desk wingman** re-verified every pin against the live catalog immediately before the sitting.

### Live sitting results

The owner-run live sequence completed successfully:

1. **PREFLIGHT: GO** — 17 checks, no findings. The missing owner/direct-ACL evidence for the two existing profile guard functions was disclosed as an `UNPROVEN` boundary; no pin was invented.
2. **APPLY: clean first run** — the package committed successfully.
3. **APPLY rerun: proven no-op live** — the exact-after state was accepted without further mutation.
4. **VERIFY: GO 13/13** — with the standing boundary note preserved.

Wingman post-checks confirmed:

- all four new functions are live;
- the private resolver is unreachable by every client role;
- the three public accessors are authenticated-only;
- all seven MP-3/compatibility helpers remain byte-identical;
- the one-profile lock remains untouched.

### Declared boundaries

- Session rotation, refresh, recovery and logout lifecycle proof remains deferred to MP4-B.
- Disposable lifecycle evidence was produced on PostgreSQL 16; owner-hosted PREFLIGHT and VERIFY remain mandatory for the live PostgreSQL environment.
- Owner/direct-ACL evidence for `enforce_profile_cap()` and `enforce_profile_owner_immutable()` was not present in the supplied evidence bundle and remains honestly unpinned.

### What remains impossible after MP4-A

Authorization behavior is unchanged. No live policy or existing authorization function consults the new primitives yet, so they are installed but unused. No profile can gain identity-bearing authority through MP4-A alone, and the one-profile cardinality lock remains in force.

The next package, MP4-B, must not be authored until Gate 4 supplies the required session-lifecycle proof and a fresh wingman evidence bundle.

---

## 2026-08-15 — MP4-B: profile/listing active authorization

### Scope

MP4-B converts the existing profile and listing policies from account-wide ownership to the MP4-A active-profile authority while preserving public listing reads, account-wide ban enforcement, suspension semantics, moderation protection and the one-profile fallback path. It also closes direct authenticated profile creation at both the table and column privilege layers while retaining signup-trigger creation.

### Authoring and review history

- Authoring restarted three times when stronger evidence or independent review invalidated an assumption; no uncertain pin was broadened to force acceptance.
- Canonical serializers were made environment-neutral with locale-invariant `COLLATE "C"` ordering.
- Policy fingerprints were corrected to use plain `pg_get_expr()` rendering, matching the `pg_policies` evidence format. The policy version branches were collapsed only after the PostgreSQL 16 plain before-state hash exactly matched the live PostgreSQL 17 plain before-state hash.
- The lifecycle harness was hardened to require semantic `GO` verdicts, not merely successful `psql` exit status, and to complete a second apply → verify → rollback → restored-preflight cycle.
- The wingman pre-sitting recompute found the pretty/plain policy-formula defect: 13 of 14 manifest families matched live exactly and had no detected drift. The sole mismatch was the policy family, where direct live recomputation proved a rendering-formula difference rather than catalog drift. Commit `4089f59` corrected the formula and pins without changing policy behavior.
- Independent review confirmed that the committed artifact bytes matched the frozen review hashes:

  | Artifact | SHA-256 |
  |---|---|
  | Preflight | `f8cfac45ae4b88277b94e6c5a60dd7f1cce448ce08206e5220a7951e4663aba5` |
  | Apply | `d9e7d9b52454b58ae24f558cf93da56d70a280c4a37ed14d90f53be229ab1083` |
  | Verify | `a57eb81aef7dc5b45f80e6e4cede5ec9363b1b21541bb1d0be30920c67670bb1` |
  | Rollback | `0af7843038cdf061d037b624ef821ac9ffc808d5d357dbfb9dce6d049469e455` |

### Live sitting results

The owner-run live sequence completed successfully:

1. **PREFLIGHT: GO 3/3** — the exact live before-state and all mandatory owner-hosted gates passed.
2. **APPLY: clean first run** — the guarded policy and privilege transition committed successfully.
3. **APPLY rerun: proven no-op live** — the exact after-state was accepted without further mutation.
4. **VERIFY: GO 5/5** — the final catalog, policy, privilege and dependency state passed.

Wingman catalog post-check outputs confirmed:

- all five converted policies are live, with exactly seven policies total in the after-state, and the after-state policy fingerprint matches exactly;
- authenticated profile `INSERT` is revoked at both table and column levels;
- public listing reads remain intact;

Owner-reported hosted compatibility validation additionally recorded:

- a real profile-edit write and revert succeeded through the converted policy on a fresh session, exercising the one-profile fallback path;
- the sitting's reviewed public-surface health checks remained healthy after application; a route-by-route inventory was not supplied for this record.

### Declared boundaries and process update

- Disposable lifecycle proof was performed on PostgreSQL 16; the mandatory owner-hosted PREFLIGHT and VERIFY gates for the live PostgreSQL environment were retained and both passed.
- The live PostgreSQL 17 plain-render before-state proof establishes the corrected policy fingerprint direction; the disposable PostgreSQL 16 lifecycle remains supporting evidence rather than a substitute for hosted gates.
- The wingman evidence-bundle standard now labels catalog rendering mode explicitly, including plain policy rendering via `pg_policies`, so future pin derivation is unambiguous.

MP4-B is live and verified. The next guarded package is MP4-C; its sitting must continue to use the rolling record and mandatory owner-hosted gates.
