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
| MP4-C | Live and verified — 2026-08-15 |
| MP4-D | Live and verified — 2026-08-15 |
| MP4-E | Live and verified — 2026-08-21 |
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

---

## 2026-08-15 — MP4-C: social/event active authorization

### Scope

MP4-C converts the actor policies for favorites, follows, festival RSVPs (`vendor_events`), Notice Board posts and reactions, and event notifications to the MP4-A active-profile authority. It preserves public reads, exact uniqueness/counting semantics, sibling-profile follows and RSVPs, the exact self-follow block, and the account-level notification preference.

### Bridge authoring and review history

- MP4-C was the first package carried through the kanban bridge, commissioned on task `t_2f4f3438` with its correction on `t_2c08744b`.
- The worker authored and validated the initial package in 16 minutes. Its own independent review lane caught a **MAJOR** environment-specific OID-ordering defect in the ACL serializer before commit.
- The serializer was corrected to order rendered grantor names with locale-invariant `COLLATE "C"`. Corrected commit `2966b0b` received a fresh full validation battery.
- One worker crash was cleanly recovered by dispatcher retry, including complete re-validation rather than reliance on the interrupted run.
- Three independent review lanes passed the exact corrected commit. Wingman deep review also passed, including byte-identity checks and a live pin recompute with one expected owner-context finding.
- The frozen reviewed artifact bytes were:

  | Artifact | SHA-256 |
  |---|---|
  | Preflight | `76fdaa84c6c5c902d45aaf530b8829d18d8cc67dee957506606140a2e1ad9b91` |
  | Apply | `d47f8973f3a138926b6700e4337e3cbf931e79ce18f43b8efd5521c7f6892fcd` |
  | Verify | `36e0a33a4fdf2425d49755d95fef88a78bad3490a3783a9c4592a65c4c02f944` |
  | Rollback | `8fb1c9b5d8cbc56b94e3f85149b3eab3a4e103886bee782229d75a529a0e915f` |

### Live sitting results

The owner-run live sequence completed successfully:

1. **PREFLIGHT: GO 4/4** — the exact live before-state and mandatory owner-hosted gates passed.
2. **APPLY: clean first run** — the guarded policy transition committed successfully.
3. **APPLY rerun: proven no-op live** — the exact after-state was accepted without further mutation.
4. **VERIFY: GO 5/5** — the final catalog, policy and dependency state passed.

Wingman post-checks confirmed:

- exactly 13 policies use the active-profile accessor;
- no account-ownership authorization actors remain in the converted scope;
- the self-follow block remains intact;
- public reads return HTTP 200.

Live compatibility was proven with an RSVP round trip through the converted rules: Turgay inserted the RSVP and the wingman deleted it through the browser.

### Declared boundaries, QA and process update

- Disposable lifecycle proof was performed on PostgreSQL 16; the mandatory owner-hosted live gates were retained and passed.
- QA finding #9 was logged for the polish slice: festival RSVP **Change** and **Remove** buttons are functional but near-invisible because of gray-on-dark contrast.
- Review-lane findings must end future runs as blocked or awaiting review, not done, so task state reflects unresolved findings.

MP4-C is live and verified. The next guarded package is MP4-D; its sitting must continue to use this rolling record and mandatory owner-hosted gates.

---

## 2026-08-15 — MP4-D: Wall active authorization

### Scope

MP4-D converts `create_post`, `update_post`, `delete_own_post`, `set_post_reaction` and `remove_post_reaction` to the MP4-A active-profile authority. It preserves the direct-DML fail-closed design, visibility helpers, the `guard_post_reaction_identity` trigger, moderation and Hero behavior, image/link validation, and the account-level write rate limit.

### Bridge authoring and review history

- MP4-D was authored on card `t_ca19a741`.
- The first review requested changes with two **MAJOR** findings: function default expressions were not serialized, so the claimed exact source/target manifests were not exact; and the required runtime verification was absent, not merely unexecuted.
- Both findings were corrected. Defaults are serialized through `pg_get_function_arguments`; the column serializers include `attcollation`, `attidentity` and `attgenerated`; and the missing disposable runtime harness was built.
- Final local commit `edd30b5` (`Add MP4-D Wall active-authority package`) changed six files, was hash-frozen, and passed the double-bound lifecycle.
- Independent exact-byte review was completed on card `t_d3ee48bf`.

### Live sitting results

The owner-run Supabase SQL Editor sequence completed successfully on 2026-08-15:

1. **PREFLIGHT: GO 5/5** — the mandatory owner-hosted gates passed.
2. **APPLY: clean first run** — the guarded function transition committed successfully.
3. **APPLY rerun: proven no-op live** — the exact after-state was accepted without further mutation.
4. **VERIFY: GO 6/6** — the final state passed.

The package was pushed on the evening of 2026-08-15 within merge `1471d82`.

Application-layer proof followed on staging on 2026-08-16. The MP4-D surface is `components/ProfileWall.tsx`, used by the profile page (`/[handle]`) and Stream; it is not the festival Notice Board. A round as the logged-in owner covered create, react, un-react with persistence across reload, and delete through the existing two-step confirmation. Live-catalog wiring proved that `posts` and `post_reactions` grant only `SELECT` to `authenticated` and `anon`, and that the sole `post_reactions` policy is read-only. Those writes therefore could only have executed through the `SECURITY DEFINER` RPCs.

### Declared boundaries, QA and process update

- The 2026-08-15 click-round tested the festival Notice Board, which uses direct DML on `notice_posts`, in the mistaken belief that it exercised MP4-D. The root cause was that two UI surfaces were both named “Wall”. The `V1_DECISIONS` rename to **Notice Board** has now been implemented.
- Standing QA rule: every checklist item must name the exact route and the exact function or table it exercises, and the wiring must be verified through the catalog or network rather than inferred from appearance.
- Standing bridge rule from RCA card `t_443bf2e8`: never exit with background subtasks running. Await them or block the card first, and always close the card with `kanban_complete` or `kanban_block` before exiting.
- Standing bridge rule from card `t_2f8aa70e` on 2026-08-16: a delegated reviewer must return its verdict to the author and must never complete, close or block the reviewed card; only the author closes its own card. In that incident, the reviewer closed the card, scratch cleanup removed the uncommitted worktree, and the author recovered the staged index before finishing the work.
- Board serialization is not repository serialization: only one repository-touching card may be eligible at a time.

#### App polish slice 1

Cards `t_59958fdf` and correction `t_7f8ceac4`, commits `82deb4c`, `6f1276b` and `993938c`, merged as `1471d82`, delivered the QA-journey findings; a homepage spotlight filtered to sellers with active listings; contrasting RSVP **Change** and **Remove** pills; app-owned email validation at least as strict as the native validation it replaced; a handle-availability state machine that cannot remain stranded on **Checking…**; the consent line; and the documentation footnote. All checks passed on staging on 2026-08-15, and the slice was pushed.

#### App polish slice 2

Card `t_2f8aa70e`, commit `0aa5bab`, merged as `758ee77`, delivered per-note deletion confirmation on the Notice Board through an isolated `NoticeDeleteControl`; `/reset-password` redirection to `/update-password` with the query string and hash fragment preserved; and the festival tab label change from **The Wall** to **Notice Board**. The redirect is client-side because the hash fragment never reaches the server. The rename is label-only: CSS classes, storage keys and Realtime channel names remain untouched.

Independent review had caught component-global deletion state that allowed a second deletion to overwrite the first. The isolated control corrected that defect. Staging verification passed on 2026-08-16, including the two-notes-at-once isolation case, and the slice was pushed.

#### Launch-critical email deliverability finding

QA finding #10 remains launch-critical. Auth mail from `noreply@psy.market` carries no DKIM signature: recipient headers report `dkim=none`, `spf=pass`, and `dmarc=pass` with policy `p=none`. A spam copy and an inbox copy were identical in authentication terms; the inbox copy arrived only after the recipient had marked earlier mail as not spam.

All-Inkl KAS inspection on 2026-08-16 found no DKIM signing option in mailbox settings. Its guide covers only external mail servers, and its DNS settings are tariff-locked and irrelevant because `psy.market` DNS is at Cloudflare. A support question was sent to All-Inkl on 2026-08-15. The identified fallback is Cloudflare Email Service, public beta since April 2026: it requires DNS at Cloudflare, creates SPF/DKIM/DMARC records automatically, and offers SMTP submission. Cloudflare Email Routing is inbound-only and cannot serve this need.

#### Weekly co-founder update automation

The Sunday co-founder auto-update timer, `psy-weekly-cofounder.timer`, was verified armed on 2026-08-16 with its first run due that afternoon. It runs Sundays at 15:00 `Europe/Berlin`, has `Persistent=true`, and linger is enabled.

MP4-D is live and verified. The next guarded package is MP4-E; its sitting must continue to use this rolling record and mandatory owner-hosted gates.

---

## 2026-08-21 — MP4-E: dormant conversation nullability foundation

### Scope

MP4-E makes `conversations.buyer_profile_id`, `conversations.seller_profile_id` and `messages.sender_profile_id` nullable while retaining the existing foreign-key delete actions. It replaces the participant-difference check with a null-aware form and installs four null-safe structural guards for conversation participants, message senders, unread state and participant state.

The package does not install a deletion callable path or rewrite a live participant value. The future profile-FK `SET NULL` transition, unread cleanup, retained-conversation uniqueness and both-deleted cleanup remain held for later guarded packages.

### Authoring and review history

- MP4-E was authored on card `t_eb13e65e` in commit `64eab48`.
- An independent live-catalog audit returned **CHANGES-REQUIRED**, with three blockers and seven majors. The correction commit `39b4393` fixed every blocker and major, and the exact corrected artifacts were re-verified by recomputation.
- The independent re-audit verdict was **PASS-WITH-MINORS**. The accepted non-blocking minors are recorded on the authoring card. They include a binding follow-up for MP4-F: its commission must require harness fixture fidelity and evidence the no-first-branch-wins rule.

### Live sitting results

The owner-run live sequence completed successfully on 2026-08-21:

1. **PREFLIGHT first run: STOP 10/11** — the owner-context row-invariant check exposed four nonparticipant-sender messages. They were May 2026 QA relics in which Turgay had sent messages into an Otis/Solarbeing conversation before sender-identity guards existed.
2. **Guarded cleanup: exact four-row correction** — the wingman-prepared cleanup deleted exactly those four rows and refreshed the conversation last-message summary.
3. **PREFLIGHT rerun: GO 11/11** — all owner-hosted gates passed, with 16 messages remaining.
4. **APPLY: clean first run** — the guarded nullability, constraint, function and trigger transition committed successfully.
5. **APPLY rerun: proven no-op live** — the exact after-state was accepted without further mutation.
6. **VERIFY: GO 11/11** — the final catalog, guard and compatibility state passed.

Wingman live post-checks confirmed:

- all three actor columns are nullable;
- all four guard triggers are installed;
- the null-aware participant-difference constraint is live;
- the guard functions grant no client role direct `EXECUTE` access.

Application-layer proof followed on staging in the owner session. A real message sent through `MessagesInbox` passed the new active-participant guard, and both the send and rendered result were verified.

### Declared boundaries

- Conversation creation remains authorized by the current policy and structural rules. Conversion to active-profile authority for conversation creation belongs to MP4-F.
- JWT-less trusted message writes now require the documented owner `DISABLE TRIGGER` break-glass path. No current trusted messaging writer exists.
- Deletion and the retained-row cutover are not live. MP4-E only installs their dormant nullability and guard foundation.
- The accepted harness/evidence minors remain recorded on card `t_eb13e65e`; MP4-F must inherit the fixture-fidelity requirement and prove the no-first-branch-wins rule.

MP4-E is live and verified. The next guarded package is MP4-F; its sitting must continue to use this rolling record and mandatory owner-hosted gates.
