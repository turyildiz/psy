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
| MP4-A | Live and verified — 2026-08-14 |
| MP4-B | Not yet authored/applied |
| MP4-C | Not yet authored/applied |
| MP4-D | Not yet authored/applied |
| MP4-E | Not yet authored/applied |
| MP4-F | Not yet authored/applied |
| MP4-G | Not yet authored/applied |
| MP4-H | Not yet authored/applied |

---

## 2026-08-14 — MP4-A: active-profile authorization primitives

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
