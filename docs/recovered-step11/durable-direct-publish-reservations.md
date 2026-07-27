# Durable Direct-Publish Listing Upload Reservations

Use this design when product rules require a resource to appear only as a complete, active row—never as a draft/hidden/incomplete row—but images must be uploaded before that row exists.

## Architecture decision

Use two durable PostgreSQL records independent of the final resource:

1. **Upload session / operation** — owner, mode (`new` or `existing`), target or preallocated future resource UUID, exact existing-media snapshot/version, commit payload/hash, lifecycle, expiry, reconciliation fields.
2. **Per-image reservation** — session, logical slot, operation (`new`/`add`/`replace`), exact old URL for replacement, immutable pending/final keys, MIME/bytes, signed-intent generation, verified private/public metadata, lifecycle and retry evidence.

The final transaction inserts the new resource directly as complete/active, or updates the existing resource atomically. A preallocated UUID is an intended identity, not a draft row.

## Smallest robust flow

1. Create/recover an owner-bound upload session with an idempotency key.
2. Reserve slots transactionally before signing. Lock the session (and existing resource when relevant); enforce unique live `(session, slot)` and the count limit.
3. Presign only the reservation's immutable private key.
4. PUT to private quarantine.
5. **Finalize validates private content only. Do not promote yet.** Persist ETag, bytes, MIME, signature/hash and state.
6. On the user's Publish/Save action, first freeze a canonical payload, ordered reservation set and idempotency hash (`commit_requested`). A browser crash after this point may be reconciled deterministically.
7. Before each public R2 write, commit `promotion_started` with exact owner, source ETag/hash, final key and intended outcome.
8. Promote create-only and verify the exact public destination; then record `promoted` metadata.
9. In one PostgreSQL transaction, recheck authorization/state, insert the complete active resource or apply an optimistic existing-resource media mutation, mark reservations `referenced`, and mark the session `committed`.

PostgreSQL and R2 cannot be one transaction. The write-ahead `promotion_started` row makes the unavoidable gap attributable and recoverable: a crash after R2 success leaves a known final key, never an unknown protocol-created orphan.

## Direct-publish invariants

- No listing/resource row exists before final commit.
- New-resource commit hardcodes the allowed published state; client status is ignored.
- Final metadata uses only ledger-derived promoted URLs, never arbitrary browser URLs.
- At every database snapshot the final resource is absent or complete/published.
- Direct client INSERT and direct media-column UPDATE must be revoked/protected at cutover, or legacy clients can bypass reservations.
- Existing historical media requires no reservation backfill if already referenced; the protocol governs new/changed media.

## Capacity and concurrency

- A signed client index is not a reservation.
- For new resources, row-lock the session and enforce at most N live unique slots.
- For existing additions, lock the resource and enforce `stored_count + live_add_reservations <= max`.
- Replacements are capacity-neutral and bind exact resource ID, slot, current URL, media version/fingerprint, and expected state.
- Prefer one live media operation per existing resource for the smallest robust V1 design.
- Process-local locks/rate limits are abuse controls only; uniqueness, row locking and compare-and-swap state versions define correctness.

Recommended uniqueness includes upload ID, private key, final key, `(session, request_idempotency_key)`, and partial unique live `(session, slot)`.

## Idempotency

- **Session/reservation:** same key + same payload returns the same row; changed payload conflicts.
- **Presign:** repeats target the same private key; no new capacity/key. Stop issuing PUT URLs after private validation or commit request.
- **PUT:** replay can overwrite the private key until expiry; accept only the ETag/hash currently validated, and promote with `If-Match`.
- **Validate:** compare-and-swap to one saved private validation result; retries return durable state.
- **Promote:** immutable final key, create-only destination, exact existing destination can be idempotent success; mismatch stops and alerts.
- **Commit:** frozen payload hash and preallocated resource UUID make response-loss retries return the existing result.

## State model

Session states should cover:

`open -> commit_requested -> promoting -> commit_ready -> committed`

plus `expired`, `failed`, `reconcile_required`, and reconciled evidence. Only open sessions with no commit request or promotion may expire casually.

Reservation states should cover:

`reserved -> uploaded -> validated -> promotion_started -> promoted -> referenced`

plus `expired`, `failed`, `reconcile_required`, and reconciled evidence. Never erase key identity/evidence on failure.

## Replacement behavior

Do not require “remove and save, then upload replacement.” Preserve the old URL until the replacement is verified. The final transaction checks exact old URL and media version, swaps atomically, and increments the media version. The replaced public object remains report-only.

A full resource may replace media because replacement is capacity-neutral. A generic `stored_count >= max` presign guard remains useful only as defense in depth for **additions**; it must exempt valid reservation-backed replacements.

## Expiry, reconciliation and reporting

- HMAC expiry, PUT expiry, reservation expiry, session expiry and ledger retention are distinct.
- Wait until the last PUT capability expires plus margin before private cleanup; a deleted private object can otherwise be recreated.
- Automatic expiry cleanup applies only to exact unpromoted private objects under the approved private-cleanup policy.
- `commit_requested`, `promotion_started`, `promoted`, and `committed` require reconciliation, not casual expiry.
- Promoted-but-unreferenced and replaced public objects remain tracked and report-only; never add public deletion.
- Extend orphan reports to distinguish referenced, known promotion pending, known promoted/commit blocked, known replaced, ledger/object mismatch, and unknown object. Paginate both object storage and every DB read.

A reconciler uses durable row locks/CAS and expiring worker leases. Leases optimize work distribution but do not define correctness. It HEAD-verifies immutable final keys, resumes conditional promotion, retries deterministic commits, or records a blocked/report-only result.

## RLS/RPC boundary

- Enable RLS immediately on session/reservation tables.
- Revoke direct table mutation from `PUBLIC`, `anon`, and `authenticated`; prefer owner-safe status RPCs over direct SELECT.
- Authenticated SECURITY DEFINER RPCs derive `auth.uid()`, recheck ban/suspension/ownership, lock rows, use fixed search paths and schema-qualified names.
- Trusted validation/promotion/reconciliation transitions are service-only RPCs, but the HTTP route must authenticate/authorize the end user before using service credentials.
- Revoke function execution from `PUBLIC` and `anon`; grant only reviewed roles.
- At final cutover, revoke direct final-resource INSERT and protect media columns/revision. Remember that column grants do not narrow an existing table-level grant.

## Rollout and rollback

1. Add schema/RPCs inertly; verify owner-applied migration read-only.
2. Deploy protocol behind a disabled flag.
3. Update every duplicate create/edit UI surface.
4. Run explicit stateful staging and multi-connection concurrency/crash tests.
5. Stop issuing legacy media intents and wait beyond their expiry.
6. Owner applies the separate enforcement grant/trigger cutover.
7. Keep reconciliation/reporting active during observation.

Rollback disables new session creation first, drains/reconciles outstanding sessions, and leaves ledger tables and every object intact. Never drop ledgers that identify promoted objects, and never delete public objects as rollback.

## Mandatory tests

- Many simultaneous same-slot reservations: one durable slot/result.
- Six concurrent slots against max five: exactly five succeed.
- Concurrent existing additions/replacements across separate DB connections.
- Same/different token validation and promotion races.
- Crash injection before/after reservation, private validation, `promotion_started`, R2 success, final DB commit and HTTP response.
- Browser close before commit request: private-only expiry path.
- Browser close after commit request: deterministic reconciliation completion.
- Exact replacement URL/version mismatch and full-capacity replacement.
- Direct arbitrary-URL resource INSERT/media UPDATE blocked after cutover.
- RLS/ACL behavior as anon, owner, other user, banned user and service role.
- Orphan report classifies ledger-known versus unknown objects without deletion.
