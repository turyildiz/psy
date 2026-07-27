# Approval-gated database and object-storage migrations

Use this pattern when managed-database references must move from one object store to another without premature source deletion.

## Phase separation

Keep each phase independently reviewed and evidenced:

1. **Manifest:** Read-only inventory of exact database field, row/owner IDs, source URL/key, HTTP status, MIME, byte size, SHA-256, destination key/URL, and destination absence. Version the manifest before writes.
2. **Copy:** Re-run the entire preflight. Copy only approved objects with create-only semantics, preserve exact bytes, and stop on any discrepancy. Verify destination metadata plus public HTTP retrieval and byte equality. Do not update database references.
3. **Database switch:** Prepare four owner-reviewed artifacts: read-only preflight, guarded transactional apply, symmetric rollback, and read-only post-apply verification. The agent never applies SQL when the owner-run gate is required.
4. **Acceptance:** Verify exact database state, source and destination objects, and hands-on rendered pages. Version an execution record.
5. **Retirement:** Source deletion, bucket/policy retirement, dead-schema removal, and orphan cleanup are separate destructive approvals with exact manifests.

Never infer an earlier write succeeded from missing transcript output. Inspect current destination, database, and Git state before retrying; do not recopy an existing verified destination.

## Owner-applied SQL package

Apply/rollback scripts should:

- use exact IDs and complete old/new values, never placeholders;
- begin with deterministic row locks inside one transaction;
- use serializable isolation for the guarded switch;
- keep multi-field changes on one logical row in one guarded `UPDATE`;
- assert exact row and field counts using `ROW_COUNT` plus final-state checks;
- raise unhandled exceptions on every mismatch so the whole transaction aborts;
- include an inspectable final `SELECT` before the single transaction-level `COMMIT`;
- contain no dynamic SQL or schema-object creation;
- document unavoidable `updated_at` trigger effects;
- require external source-object validity before rollback.

A procedural `BEGIN` inside a `DO` block is not an additional transaction boundary.

## Supabase SQL Editor legibility

Supabase SQL Editor may foreground only the final result table from a multi-statement preflight. When the owner needs a clear go/no-go result, provide a separate compact read-only query consisting of CTEs plus one final `SELECT` that returns exactly one summary row. Include clearly named counts/booleans and an `all_checks_pass` expression that is true only when every exact expectation passes.

Execute only read-only preflight/verification queries for validation. Never execute apply or rollback merely to syntax-check them, even inside a transaction that would later roll back. Use static parsing/manual PL/pgSQL review instead.

## Object verification evidence

For every source and destination object record:

- HTTP status;
- normalized MIME type;
- byte count;
- SHA-256;
- source/destination byte equality when copying;
- canonical destination URL and key;
- final database-reference state.

Do not expose credentials, signed URLs, cookies, or upload-intent tokens. Use tool output that reports only sanitized status and hashes.

## Staging upload acceptance under restricted deletion

Before stateful tests, inspect implementation, tests, current accounts/resources, database constraints, and both bucket inventories read-only. Separate:

- state-free automated/static checks;
- authenticated rejection tests;
- transient private-quarantine tests;
- persistent public promotions;
- temporary account-state tests.

If public deletion is disabled, a successful promoted test object cannot be treated as disposable. Prefer a new retained demo resource that references every promoted object; never alter an existing protected demo resource merely to simplify cleanup. Temporary invalid uploads may use only the signed, owner-bound private cleanup path.

Capture a fresh baseline manifest/hash of protected rows and exact private/public inventory. Finish by proving original demo rows are unchanged, account state is restored, every promoted test object is referenced, and private quarantine is empty.

Test server authority, not only honest-client behavior. For count limits, attempt an in-range forged index against a resource already at capacity; UI hiding and a database constraint do not prove presign rejects the extra object. Treat any ability to promote an object that the database later rejects as a blocker because it creates a public orphan.

Run temporary ban/unban tests last, only on an explicitly approved non-owner account, with exact before/after checks. Distinguish database-ban rejection (often 403) from Auth-level ban rejection (often 401 before application authorization).

## State-free Gate A execution pattern

Execute non-stateful acceptance as one fail-closed sequence so later cases never run after an unexpected result:

1. Capture a canonical **before** snapshot:
   - exact protected profile identifiers/ownership;
   - every protected listing ID, owner, status, and ordered image array;
   - the test account's database ban fields, profile suspension flag, and sanitized Auth existence/ban booleans;
   - complete private-quarantine inventory;
   - relevant public-prefix inventory.
2. Sort rows and objects deterministically. Hash canonical JSON. For R2 inventories include at least key, byte size, and ETag; report counts, bytes, and SHA-256 without exposing credentials.
3. Run the automated suite and report exact totals: tests, pass, fail, cancelled, skipped, todo, and duration.
4. Enumerate every `DeleteObjectCommand` constructor and trace bucket aliases to configuration. Distinguish imports from constructors, application routes from opt-in maintenance scripts, and prove there is no public-delete helper or route.
5. Send rejection probes with no cookies:
   - invalid MIME declaration;
   - declared size one byte over the policy limit;
   - an otherwise valid unauthenticated request.
   Require exact status/body and assert that neither an upload token nor presigned URL is returned.
6. Capture the complete **after** snapshot and compare exact rows, account state, object manifests, counts, bytes, and hashes. Gate A passes only when every comparison is identical.

Validation that runs before authentication is useful for state-free policy probes, but add a valid unauthenticated request to prove the authentication boundary itself returns 401. Do not call a rejection probe state-free merely because it is expected to fail: explicitly assert that no signed intent, private object, public object, or database change resulted.

If a cleanup endpoint reports success without exposing whether deletion actually happened, never use the response flag as evidence. Verify private-object absence by a fresh HEAD or complete inventory.

## Documentation closeout

Execution records should state exact scope, artifact commit/checksum, owner verification values, independent verification, hands-on acceptance, rollback-source status, whether rollback was needed, and every remaining destructive boundary. Update the project status document and agent-facing instructions when preservation/deletion rules change.
