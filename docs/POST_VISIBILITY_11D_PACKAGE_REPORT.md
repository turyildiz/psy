# Chunk 11D Post Visibility SQL Package Report

## Status

**Owner application status (2026-08-07): APPLIED AND DATABASE VERIFIED.** The owner reported preflight `GO`, successful apply, and `DATABASE PASS`; remaining `UNPROVEN` branches are missing-fixture branches only.

**Package validation verdict: PASSED static validation and independent review.**

This report documents the owner-applied Chunk 11D authorization package for psy.market. The SQL package was authored, independently reviewed, then manually applied and verified by the owner. The coordinated application slice is tracked separately; no database operation was performed by the project agent, and nothing was committed or pushed.

The approved visibility rule is:

```text
show_in_stream = true  -> publicly readable, including anonymous visitors
show_in_stream = false -> readable only by authenticated members
```

The change preserves the existing post-author ban predicate, active-admin exception, banned-viewer behavior, reaction reactor-ban filtering, authenticated access to members-only posts and allowed reactions, `service_role` operational reads through `BYPASSRLS`, and RPC-only browser mutations.

## Package files

| File | Purpose |
|---|---|
| `supabase/chunks/chunk-11d-post-visibility-preflight.sql` | Read-only owner preflight. Returns one clear `GO`/`NO-GO` summary row, checks the captured pre-11D catalog/ACL/data invariants, exposes aggregate counts only, and fails closed on baseline drift. |
| `supabase/chunks/chunk-11d-post-visibility-apply.sql` | One guarded transaction. Creates the centralized post-read helper, replaces the sole post read-policy qualifier, corrects reaction visibility while preserving the reactor-ban predicate, and aborts unless all postconditions match. |
| `supabase/chunks/chunk-11d-post-visibility-verify.sql` | Read-only catalog and runtime verifier. Checks exact policies, helpers, ACLs, mutation boundaries, Hero invariants, and available existing-data viewer branches; missing fixtures are reported as `UNPROVEN`. |
| `supabase/chunks/chunk-11d-post-visibility-rollback.sql` | One guarded transaction. Requires the exact expected 11D state, restores the captured pre-11D post policy and reaction helper/ACL state, drops the 11D helper without `CASCADE`, and verifies the restored baseline before commit. |

The approved design source is:

```text
docs/POST_VISIBILITY_11D_PROPOSAL.md
```

## Required application order

Run the files manually in the Supabase SQL Editor in this order:

1. `supabase/chunks/chunk-11d-post-visibility-preflight.sql`
   - Continue only if the single summary row reports `GO` and every component check is true.
   - Stop on `NO-GO`; do not run apply against a drifted baseline.
2. `supabase/chunks/chunk-11d-post-visibility-apply.sql`
   - Run once, only after preflight passes.
   - The file uses one guarded transaction and commits only after its postconditions pass.
3. `supabase/chunks/chunk-11d-post-visibility-verify.sql`
   - Run after apply succeeds.
   - Review the catalog verdict, every runtime branch, and the explicit external-session requirements.
4. `supabase/chunks/chunk-11d-post-visibility-rollback.sql`
   - **Do not run during the normal forward sequence.** Keep it available only if rollback is deliberately required.
   - It intentionally restores the pre-11D behavior in which `show_in_stream = false` posts and their allowed reactions are anonymously readable again.

Normal forward sequence:

```text
preflight -> apply -> verify
```

Recovery sequence, only if deliberately required after 11D is present:

```text
rollback
```

## Implemented authorization design

The package centralizes the post-read decision in:

```sql
current_user_can_read_post(profile_id, show_in_stream)
```

Conceptually, the helper applies:

```text
current_user_can_read_post_author(profile_id)
AND (
  show_in_stream
  OR auth.role() = 'authenticated'
)
```

The exact post-author helper remains unchanged. This preserves the existing author-ban and active-admin semantics rather than adding a new self-read, viewer-ban, owner, or service-role exception.

The corrected reaction helper preserves the existing reactor-ban predicate and delegates parent visibility to the centralized helper using the parent post's `profile_id` and `show_in_stream` value. This prevents reaction rows or direct helper calls from revealing a members-only parent to anonymous callers.

The package keeps exactly one permissive read policy on `posts` and one on `post_reactions`. This is required because PostgreSQL combines permissive policies with `OR`; retaining the legacy broad post qualifier as another permissive policy would leave members-only posts anonymously readable.

## Choices made where the proposal required interpretation

| Ambiguous point | Choice | Reason |
|---|---|---|
| Exact post-policy catalog name | Retain `Visible posts are publicly readable` and replace only its qualifier. | Minimizes catalog and rollback surface while preserving the approved one-policy architecture. The exact qualifier and sole-policy inventory, not the English name alone, enforce 11D. |
| Whether to add a second post policy | Replace the legacy qualifier; do not add another permissive policy. | Permissive policies combine with `OR`. Keeping the old broad policy would bypass members-only visibility. |
| Split role-specific policies versus one shared helper | Use one centralized `current_user_can_read_post(uuid, boolean)` helper and one permissive policy per table. | Gives posts and reactions one authoritative parent-visibility decision and avoids policy interaction/leakage. |
| Existing author helper | Leave `current_user_can_read_post_author(uuid)` unchanged. | Preserves the captured ban/admin behavior exactly and avoids introducing an unapproved author self-read or viewer-ban rule. |
| Reaction-policy replacement | Keep the sole reaction policy structurally unchanged because its exact qualifier already calls the reaction helper; replace and reassert the helper instead. | The corrected helper is the authoritative place to apply parent visibility while preserving the reactor-ban predicate. Recreating an identical policy would add unnecessary migration surface. |
| Anonymous and authenticated runtime proof in SQL Editor | Use the actual PostgreSQL API roles plus owner-supplied JWT claim context and existing fixture identities for database-layer probes; explicitly require separate real PostgREST/Supabase session probes. | `SET LOCAL ROLE` plus synthetic claims proves RLS/helper behavior inside PostgreSQL but cannot prove gateway, token, or real-session transport. No end-user token is requested or embedded. |
| Missing runtime fixtures | Report each unavailable branch as `UNPROVEN`; never create users, profiles, posts, or reactions. | The task prohibited creating test data, and an absent fixture must not be reported as a passing behavioral proof. |
| Read-only verification versus Hero mutation probes | Do not call the two mutating Hero probes in the read-only verifier. Verify exact RPC signatures/direct ACLs, the validated Hero constraint, and zero invalid Hero rows; label the mutation probes as not run. | Calling those RPCs would violate the read-only requirement even if a transaction were later rolled back. |
| `service_role` behavior | Require the expected non-superuser `BYPASSRLS` role shape, verify successful complete table reads through bypass, and verify that direct execution of the read helpers is denied. | Operational table access comes from `BYPASSRLS`; helper `EXECUTE` is intentionally granted only to `anon` and `authenticated`, not mechanically to `service_role`. |
| Mutation-RPC drift proof | Compare the complete overload set for all eight mutation RPC names and the full exploded direct ACL state, including owner/authenticated grantees, `EXECUTE`, grantor, and grant-option bit. | Effective privilege checks alone would miss extra overloads, inherited/public grants, additional grantees, changed grantors, or `WITH GRANT OPTION` drift. |
| Intended project identity without a repository-bound project reference | Require the expected database and owner context plus the exact captured Chunk 11 table, policy, helper, role, RLS, constraint, and ACL fingerprint. | No safe project reference was available to embed. Exact object-state matching makes the owner preflight fail closed rather than guessing. |
| Hero constraint comparison | Require the named validated check constraint, its relevant structural markers, and zero `is_hero_featured AND NOT show_in_stream` rows. | This proves the approved Hero invariant without relying on an unobserved catalog-body hash. |
| Function drift guards | Compare observed semantic definitions and independent function properties/ACLs rather than hardcoded, unobserved body hashes. | Follows the Chunk 10 lesson: repository-derived hashes are not proof of the live catalog representation and can abort a valid owner application. |
| Preflight output privacy | Return aggregate public/members-only post and reaction counts only; emit no IDs, bodies, image URLs, handles, or reaction identities. | Meets the diagnostic requirement without exposing row-level content. |
| Rollback scope | Restore policy/helper/ACL authorization semantics only; perform no row rewrite or backfill. | Chunk 11D changes authorization, not stored data. The rollback is data-lossless but deliberately restores the old anonymous-read behavior. |

## Exact unchanged mutation boundary

The package checks the complete overload and direct-ACL state for these eight existing RPCs:

```text
public.create_post(uuid,text,text[],boolean)
public.update_post(uuid,text,text[],boolean)
public.delete_own_post(uuid)
public.admin_flag_post_for_hero(uuid)
public.admin_unflag_post_for_hero(uuid)
public.set_post_reaction(uuid,uuid,text)
public.remove_post_reaction(uuid,uuid)
public.admin_delete_post(uuid,text)
```

For each RPC, the expected direct ACL state is exactly owner `postgres` plus `authenticated`, with `EXECUTE`, grantor `postgres`, and no grant option. Missing or additional overloads, missing or additional ACL entries, changed grantees, changed grantors, changed privileges, or grant-option drift fail closed.

Direct browser writes to `public.posts` and `public.post_reactions` remain unavailable; browser mutations continue through the reviewed RPCs.

## Static validation results

| Validation | Result |
|---|---|
| Exact four-file manifest | **PASS** |
| UTF-8/control/final-newline checks | **PASS** |
| Delimiter/lexer balance | **PASS** — four files and 21 dollar-quoted bodies checked |
| Parentheses, strings, quoted identifiers, comments, and dollar-quote balance | **PASS** |
| Apply/rollback transaction shape | **PASS** |
| Read-only preflight/verify envelope | **PASS** |
| No `CASCADE` | **PASS** |
| Invalid qualified `pg_catalog.position(...)` scan | **PASS** — corrected implementation uses `pg_catalog.strpos(...)` |
| Cross-file policy/helper/ACL/rollback symmetry | **PASS** |
| Runtime status writer/required/final-output symmetry | **PASS** — 23 branches |
| Exact mutation-RPC comparator parity | **PASS** — five copies: apply pre/post, verify, rollback pre/post |
| Per-file untracked whitespace checks using `git diff --no-index --check` | **PASS** for all four SQL files |
| Repository `git diff --check` | **PASS** |
| Focused post tests | **PASS — 16/16** |
| Full existing test suite | **PASS — 135/135** |
| Independent final package review | **PASSED — no remaining blocker** |
| PostgreSQL parsing in the independent review environment | **PASS** for all four files and each extracted mutation-RPC comparator |

The independent final review specifically confirmed that all five mutation-RPC comparisons reject:

- missing or additional overload signatures across all eight RPC names;
- missing or additional direct ACL grantees;
- an incorrect privilege type;
- grant-option drift;
- a changed grantor;
- a missing owner (`postgres`) or `authenticated` ACL entry.

## Owner-applied state and remaining checks

### Database application result

- Owner-run preflight returned `GO` on 2026-08-07.
- Owner-run apply succeeded.
- Owner-run verify returned `DATABASE PASS`.
- Remaining `UNPROVEN` runtime branches are missing-fixture branches only; verify intentionally creates no test data.

### Runtime branches may be `UNPROVEN`

The verifier uses existing data only. A branch is intentionally reported as `UNPROVEN` when the database lacks a suitable existing fixture, including potentially:

- public or members-only posts;
- public or members-only parent reactions;
- banned-author posts or reactions;
- banned-reactor reactions;
- a banned authenticated viewer;
- an active admin viewer.

An `UNPROVEN` branch is not a failure of the catalog migration, but it is also not behavioral proof. Review every branch in the verifier's final row before treating runtime coverage as complete.

### External session probes remain required

The SQL verifier's role/JWT matrix proves the PostgreSQL layer only. Following owner apply and SQL verification, repeat the essential lookups through:

- the real anonymous PostgREST/Supabase path; and
- an existing approved authenticated session.

At minimum, confirm through those real paths that:

| Probe | Expected result |
|---|---|
| Anonymous lookup of a known `show_in_stream = true` post | Visible |
| Anonymous lookup of a known `show_in_stream = false` post by ID | Zero rows |
| Anonymous reaction lookup/aggregate for that members-only post | Zero rows |
| Approved authenticated lookup of the same members-only post | Visible |
| Approved authenticated lookup of its allowed reactions | Visible |

Do not paste or store end-user access tokens in this report or the SQL files.

### Mutating Hero probes are deferred

The read-only verifier does not execute:

- non-admin switching a Hero post to members-only and confirming Hero state clears atomically;
- admin attempting to flag a members-only post and receiving rejection.

Before relying on those runtime paths, perform them only in a separately approved, controlled test using suitable existing data and a clear rollback/recovery plan. The package does statically/catalog-verify the unchanged RPC boundaries, validated Hero constraint, and zero current invariant violations.

### Coordinated application work

The approved application/docs slice is now authored locally and awaiting staging verification. It implements:

- the exact approved composer checked/unchecked wording;
- the owner-only `Members only` badge;
- the logged-out empty state:

```text
No public posts yet
```

- Wall refresh when authentication state changes or authentication completes;
- correction of superseded V1/Wall documentation; and
- regression coverage for stale initial-auth snapshots arriving after newer auth events.

The existing Stream client retains its explicit:

```text
show_in_stream = true
```

filter. End-to-end rendered behavior remains pending the approved staging refresh and anonymous/authenticated browser checks.

## Applied sequence and remaining checks

- [x] Confirmed the four SQL files were the reviewed copies.
- [x] Owner-run preflight returned a single `GO` result.
- [x] Owner-run apply succeeded.
- [x] Owner-run verify returned `DATABASE PASS`; missing fixtures remained honestly `UNPROVEN`.
- [ ] Complete the required real anonymous and approved authenticated session probes.
- [x] Kept rollback available without running it.
- [x] Recorded that rollback intentionally restores anonymous access to non-Stream posts and allowed reactions.
- [ ] Refresh and verify staging before any commit or push.

## Repository and execution state on 2026-08-07

```text
Database application: owner-applied
Database verification: DATABASE PASS; missing-fixture branches UNPROVEN only
Application code changes: coordinated slice authored locally, staging pending
Commit: none
Push: none
```
