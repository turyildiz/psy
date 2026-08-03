# Wall Migration Package Report

## Verdict

**Scope reduction is complete and the requested static validation passed.**

Chunk 11 now has **zero references** to:

```text
public.admin_ban_user
public.admin_unban_user
```

It does not replace, fingerprint, alter ownership, change ACLs, re-grant, verify, or restore either function.

The Wall-owned trigger remains:

```text
clear_hero_on_author_ban_trigger
```

It watches the authoritative transition:

```text
public.users.banned_at: NULL → non-NULL
```

It therefore does not depend on either RPC. **No Wall behavior broke because of the scope reduction.**

Nothing was applied. No migration was run. Nothing was committed or pushed.

## Current package files

The package remains under `supabase/chunks` because that is the repository's existing numbered preflight/apply/verify/rollback convention. It is Chunk 11 because Chunk 10 is the latest referenced security-hardening package.

- `supabase/chunks/chunk-11-wall-data-model-preflight.sql` — read-only fail-closed baseline and package-object collision checks; no ban/unban fingerprints or ACL assumptions.
- `supabase/chunks/chunk-11a-wall-foundation-apply.sql` — hardens `follows` and creates the shared blocklist, validation, visibility, and rolling-window rate-limit foundations.
- `supabase/chunks/chunk-11b-wall-posts-apply.sql` — creates posts, trusted post/Hero operations, visibility rules, physical deletion, and the ban-state Hero-clear trigger; it does not modify ban/unban RPCs.
- `supabase/chunks/chunk-11c-wall-reactions-moderation-apply.sql` — creates fixed-code reactions, metadata-only moderation audit, reaction operations, and atomic admin physical deletion.
- `supabase/chunks/chunk-11-wall-data-model-verify.sql` — stage-aware read-only catalog and behavioral verification for 11A, 11B, and 11C.
- `supabase/chunks/chunk-11-wall-data-model-rollback.sql` — reverses 11C, 11B, and 11A and restores the reviewed prior `follows` state; it contains no ban/unban restoration.

Supporting project documents currently present:

- `docs/WALL_DATA_MODEL_PROPOSAL.md` — source proposal and resolved Wall decisions.
- `docs/WALL_MIGRATION_PACKAGE_REPORT.md` — this current package report.

## Ban/unban scope reduction

Removed from Chunk 11:

- replacement definitions for `public.admin_ban_user` and `public.admin_unban_user`;
- owner changes for those functions;
- all Chunk 11 revokes and grants for those functions, including removal of `service_role` execution;
- installed-definition fingerprints and exact-state preconditions used to guard their replacement;
- verification calls, function counts, source hashes, and ACL assertions that treated those RPCs as Chunk 11 objects;
- rollback definitions, grants, ACL postconditions, and restore logic for ban and unban.

Retained:

- the Wall-owned `clear_hero_on_author_ban()` trigger helper;
- `clear_hero_on_author_ban_trigger` on the authoritative `public.users.banned_at` transition;
- ordinary Wall visibility behavior derived from current ban state.

### Reported inconsistencies

Both previous inconsistencies are dissolved:

| Previous inconsistency | Current result |
|---|---|
| Apply/verify hardened-function count disagreement | Apply and verify now both expect exactly **7 Wall-owned Chunk 11B functions**. |
| Missing unban restoration | No restoration is needed because Chunk 11 no longer changes unban. Rollback contains no unban restoration or unban-state assumption. |

### Did anything break?

No Wall behavior broke as a result.

The Hero-clear trigger observes `public.users.banned_at` directly and does not call either admin RPC. Any authorized route that changes that field from `NULL` to non-`NULL` triggers the Wall cleanup. Existing Chunk 6 ban/unban objects remain untouched.

Unbanning still does not automatically restore old Hero flags. Ordinary post visibility continues to derive from the author's current ban state.

## Image-identifier contradiction

The SQL enforces the profile owner's **authenticated user ID**, not the profile-row ID.

Exact check:

```sql
select p.user_id
  into owner_user_id
from public.profiles as p
where p.id = target_profile_id;

required_pattern :=
  '^https://images[.]psy[.]market/posts/'
  || owner_user_id::text
  || '/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}[.](jpg|png|webp)$';
```

Therefore, the enforced URL namespace is:

```text
https://images.psy.market/posts/{profiles.user_id}/{uuid-v4}.{jpg|png|webp}
```

It is **not**:

```text
https://images.psy.market/posts/{profiles.id}/{uuid-v4}.{ext}
```

### Existing browser upload behavior

The browser upload registry currently has **no post-image purpose**, so it cannot produce a post-image key today.

For existing supported purposes, its key builder is:

```ts
finalKey: `${policy.folder}/${input.userId}/${uploadId}.${extension}`
```

`input.userId` is the authenticated Supabase user ID. If a `posts` purpose were added without changing that builder, it would produce the same authenticated-user-ID namespace that the SQL currently enforces.

No image validation or browser upload implementation was changed during the scope reduction.

## Confirmed owner constants

```text
20 accepted post writes per rolling 10 minutes
love, fire, dance, trippy, shanti, sad
moderation reason: 3–500 characters
```

## Validation results

### 1. SQL delimiter and lexer check

**PASS across all six SQL files.**

Verified:

- valid UTF-8;
- no BOM;
- no NUL bytes;
- no CRLF characters;
- final newline present;
- balanced line and nested block comments;
- balanced quoted strings and quoted identifiers;
- balanced dollar-quoted function bodies;
- balanced parentheses;
- expected transaction shape for apply, preflight, verify, and rollback files.

### 2. Cross-file object coverage and rollback symmetry

**PASS.**

Coverage comprised:

```text
5 new tables
22 new functions
3 new triggers
4 new policies
7 new indexes
```

Results:

- every new object name appears in preflight and verification;
- every new table, function, and trigger has matching rollback removal;
- indexes and policies are removed with their owning package tables;
- the existing `follows` FORCE-RLS and `created_at` hardening have explicit reverse operations;
- no forward stage uses `CREATE OR REPLACE FUNCTION` for an existing function;
- the Hero-clear trigger/helper remain covered by preflight, verification, and rollback.

### 3. Stale assumptions and policy checks

**PASS.**

Found:

```text
admin_ban_user references: 0
admin_unban_user references: 0
CREATE OR REPLACE FUNCTION in forward stages: 0
stale direct-write policy names: 0
obsolete ban/unban fingerprints: 0
```

The current package policy names are consistently represented in apply, preflight, and verification:

```text
Active admins read post link blocklist
Visible posts are publicly readable
Visible reactions are publicly readable
Active admins read post moderation audit
```

Chunk 11B's Wall-owned function count is now:

```text
apply: 7
verify: 7
```

### 4. Git checks and final repository status

`git diff --check` completed successfully with exit code `0`.

All current package/report files are untracked, so ordinary `git diff --check` had no tracked diff to inspect. A separate static whitespace check covered all eight untracked proposal/report/package files and found no BOM, NUL, or trailing-whitespace issues.

Final status at validation time:

```text
## main...origin/main
?? docs/WALL_DATA_MODEL_PROPOSAL.md
?? docs/WALL_MIGRATION_PACKAGE_REPORT.md
?? supabase/chunks/chunk-11-wall-data-model-preflight.sql
?? supabase/chunks/chunk-11-wall-data-model-rollback.sql
?? supabase/chunks/chunk-11-wall-data-model-verify.sql
?? supabase/chunks/chunk-11a-wall-foundation-apply.sql
?? supabase/chunks/chunk-11b-wall-posts-apply.sql
?? supabase/chunks/chunk-11c-wall-reactions-moderation-apply.sql
```

## Skill-file change disclosure

These were earlier self-improvement changes outside the Psy repository. They were made to prevent the exact package-parity, ACL-policy, rollback, and partial-stage mistakes discovered during Chunk 11 review. The skill was not modified again during the scope-reduction task.

### 1. `supabase-security-migrations/SKILL.md`

**Before:**

```markdown
- Confirm local/remote HEAD and a clean working tree.

### Narrow corrective function replacements
```

**After:**

```markdown
- Confirm local/remote HEAD and a clean working tree.

### Multi-chunk package parity and callable verification

For a staged A → B → C package with one preflight, one verifier, and one rollback, create an object-parity manifest before authoring. Every created, altered, or replaced object must have matching preflight, apply, verify, and rollback coverage. Treat a late addition—especially replacement of an existing RPC—as a package-wide change: update old-state guards, apply function counts and ACL checks, verifier calls/signatures/counts, rollback restoration, and final create/drop symmetry in the same pass.

A single read-only verifier may be stage-aware: detect later objects with `to_regclass`/`to_regprocedure`, use dynamic `EXECUTE` for calls that must not parse before their stage exists, and return separate nullable stage results. It must actually call every legal helper with representative valid and invalid inputs. Calls that intentionally fail at an authorization gate prove only resolution and the gate; they do not prove later DML, constraints, triggers, or the success path. Trigger functions cannot be legally called directly, so verify their bindings structurally and reserve execution proof for a separately authorized rollback-only smoke after application.

Never declare the package owner-ready until the **final** edit has passed package-wide static checks. If work stops after a late scope expansion, label the package `do not apply` and name each incomplete parity item rather than presenting a nearly complete package as finished.

PostgreSQL syntax itself needs static scrutiny: SQL-standard special forms are not always schema-qualifiable ordinary functions (`pg_catalog.position(x in y)` is invalid; use `pg_catalog.strpos(y, x)`), and ordered array fields must reject multidimensional/non-1-based arrays before calling one-dimensional helpers such as `array_position`.

See `references/staged-multi-chunk-package-authoring.md` for the parity matrix, stage-aware verifier pattern, partial-stage failure checks, exact policy/ACL-set verification, observed old-function drift guards, cross-object trigger invariants, proof limits, final static checklist, special-form syntax pitfall, and one-dimensional array checks.

### Narrow corrective function replacements
```

**Why:** This adds an explicit package-wide parity rule for staged migration packages and prevents a late object or RPC change from being updated in only apply SQL while leaving preflight, verification, counts, ACL checks, or rollback inconsistent.

### 2. `supabase-security-migrations/references/staged-multi-chunk-package-authoring.md`

**Before:**

```markdown
- For ordered media arrays, also reject null elements, blanks, duplicates, and counts over the product maximum. Namespace/object-origin validation belongs in a trigger or trusted write boundary when it depends on another row.
```

**After:**

```markdown
- For ordered media arrays, also reject null elements, blanks, duplicates, and counts over the product maximum. Namespace/object-origin validation belongs in a trigger or trusted write boundary when it depends on another row.

## 7. Verify exact RLS policy sets, not policy names

Permissive policies combine with OR, so a verifier that checks only expected names or counts can pass while an extra policy exposes rows.

For every package relation, verify all of the following:

1. total policy count;
2. policy name;
3. command;
4. role array;
5. permissive/restrictive mode;
6. complete `USING` expression;
7. complete `WITH CHECK` expression, including expected `NULL`.

Move complicated visibility logic into one narrowly scoped helper when that makes the policy expression simple and auditable. Verify the helper's full definition and behavior as well as the policy. Do not keep client write policies on an RPC-only table merely for appearance: with direct mutation grants revoked they are unnecessary, and granting internal validators so those policies can execute can create boolean oracles over admin-only state.

## 8. Compare direct ACL sets, including grantor and grant options

`has_table_privilege()` and `has_function_privilege()` answer effective-access questions; they do not prove the direct ACL is exactly the reviewed one. For apply postconditions, verification, and rollback guards:

- expand `relacl`/`proacl` with `aclexplode`;
- compare actual and expected rows in both directions with `EXCEPT`;
- include object, grantee, privilege, `is_grantable`, and grantor;
- include durable operational roles such as read-only auditors, not only Supabase API roles;
- reject unexpected `PUBLIC`, inherited-role, or grant-option paths.

Text comparison of ACL arrays is order-sensitive. Prefer set comparison unless byte-identical catalog text is itself a requirement.

## 9. Existing-function replacement requires an observed old-state contract

Before replacing an existing privileged RPC, capture the complete installed state:

- `pg_get_functiondef`;
- owner, language, volatility, strictness, leakproofness, parallel mode, and `prosecdef`;
- exact `proconfig`;
- exact direct ACL.

A normalized digest of the **observed live definition** can be a compact old-state drift guard. Normalize only known representation noise such as CRLF versus LF and preserve the full definition semantics. Do not derive the old-state hash from a repository file and assume it equals the catalog. Do not hardcode a post-apply hash derived only from local source as runtime truth; PostgreSQL's stored representation must be observed after owner application before such a digest becomes authoritative.

If a companion function is hardened at the same time—for example both ban and unban—add both to preflight, apply counts, verifier calls, rollback restoration, and postconditions. Restoring only one function is not a reversible package.

## 10. Enforce cross-object invariants at every authoritative write path

If a state transition must cause a dependent cleanup, enforcing it only in one admin RPC is insufficient when the underlying state can change through another RPC, direct owner operation, dashboard action, or trusted service path. Put the invariant at the authoritative table boundary, normally with a trigger on the source-state transition.

When the cleanup updates a second table that has its own invariant trigger:

- design the two triggers together;
- permit only the exact internal cleanup transition, never a general bypass;
- scope any transaction-local context flag to one operation and validate the resulting `NEW` row independently;
- keep the internal trigger helper owner-only;
- add both trigger bindings and helper definitions to rollback symmetry and verification.

A read-only verifier can prove trigger bindings, definitions, ACLs, and existing-row invariants, but not a successful mutating trigger path. Keep that proof boundary explicit and require separately authorized rollback-only runtime smoke if successful execution must be demonstrated.

## 11. Stage detection must fail on partial presence

A stage-aware verifier must distinguish absent, complete, and partial states. Do not compute `stage_present` as `object_a_exists AND object_b_exists` and silently treat a one-object partial migration as absent. Count or XOR-check every required stage marker and raise on partial presence or impossible dependency order before returning nullable stage results.
```

**Why:** These additions record the specific lessons from the independent review: exact RLS-policy sets instead of name-only checks, exact direct ACL sets, complete reversible treatment of existing-function replacements, trigger enforcement at the authoritative state boundary, and fail-closed detection of partially applied stages.

## Remaining owner-review blockers and limitations

The files-only static work is complete, but owner review should still account for:

- PostgreSQL has not parsed or executed these files.
- Successful mutation and trigger paths remain untested because the verifier is read-only.
- No second independent review was run after the final scope reduction.
- Browser post-image upload is still unimplemented and remains outside this package.
- The verifier's normalized `pg_policies` expression assumptions should be reviewed against the installed PostgreSQL/Supabase representation.
- Exact direct-ACL assumptions should be reviewed against the installed roles and grantors.
- The `users.banned_at` trigger interaction with post Hero invariants has only static, not runtime, evidence.
- The fail-closed Unicode-domain treatment remains a deliberate product/security choice.

## Point where work stopped

The requested scope reduction and all four requested static-validation steps were completed. Work did **not** stop halfway through an edit, and the six SQL files were left in a consistent state.

Work stopped before any PostgreSQL parse/application or successful runtime mutation test because those actions were outside the files-only instruction and would require separate owner authorization.

## Final execution record

- Package SQL applied: **No**
- Migration run: **No**
- Database mutation performed: **No**
- Read-only catalog checks performed during earlier authoring: **Yes**
- Application code changed: **No**
- Upload implementation changed: **No**
- Commit created: **No**
- Push performed: **No**
- Requested files-only static validation completed: **Yes**
- Safe to apply without owner review: **No**
