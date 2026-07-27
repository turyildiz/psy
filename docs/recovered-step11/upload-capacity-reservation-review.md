# Upload Capacity, Reservation, and Commit Review

Use this checklist when a change claims to enforce upload counts, logical slots, replacements, or lifecycle safety.

## Trace the full state machine

Review the complete flow, not only the presign route:

1. authorize intent;
2. reserve durable capacity or a logical slot;
3. upload to private quarantine;
4. validate and promote the object;
5. commit the durable database reference;
6. consume/release the reservation;
7. reconcile abandoned and partial states.

A database array-cardinality constraint protects only the final row. It does not limit presigns, quarantine PUTs, public promotions, or unreferenced public objects.

## Mandatory adversarial scenarios

Analyze these explicitly:

- repeated presigns for the same index;
- simultaneous presigns reading the same current count;
- simultaneous finalizations for distinct tokens;
- simultaneous replay/finalization of one token;
- new resources uploaded before an authoritative row exists;
- abandonment after promotion but before database save;
- full-resource replacement where removals exist only in client state;
- malformed/null stored arrays and invalid array members;
- direct metadata writes or alternate APIs bypassing the upload route;
- distributed deployments using a process-local limiter.

Signing `index` into a token does not reserve that slot. If each token receives a unique object ID/key, repeated same-index intents can still produce many objects unless durable state enforces uniqueness and lifecycle transitions.

## Concurrency proof questions

For every check-then-act sequence, ask:

- What durable state changes between check and action?
- Can two requests observe the same state and both succeed?
- Is capacity reserved transactionally?
- Does finalization consume the reservation exactly once?
- Does object-store idempotency protect only one destination key while distinct tokens still use distinct keys?

A read such as `current_count < max` is defense in depth, not a safe capacity protocol. Robust designs commonly require a durable draft/resource ID, reservation records or slots with uniqueness constraints and expiry, and an idempotent commit/reconciliation state machine.

## Replacement UX

A server check against the persisted array can reject a legitimate replacement when the client removed an old item locally but uploads before saving the new array. Inspect actual UI ordering. Do not recommend saving removals first without addressing temporary data loss, rollback, failed replacement, and abandonment.

## Test authenticity

Verify that rejection tests instrument and assert zero calls to the relevant side effects:

- token/signature creation;
- presigned URL creation;
- object-store HEAD/GET/PUT/COPY/DELETE;
- promotion/finalization operations.

Determine whether tests call the framework's exported route or an extracted handler. Extracted-handler tests prove handler logic, but not module wiring or full integration. Require concurrency/replay tests or a convincing durable-state proof for atomicity claims.

## Live staging worktree isolation

Before prototyping a security fix, determine whether the repository working tree is itself served by a development process. Next.js/Vite-style dev servers can hot-reload uncommitted edits, so “not deployed” is false if the live service reads that tree on demand.

When a review may block release:

1. implement and test in an isolated Git worktree or disposable clone that is not watched by staging;
2. capture the exact diff and independent-review input from that settled isolated tree;
3. merge/apply into the live deployment tree only after the review gate passes;
4. if edits were accidentally made in a live-served tree and the gate blocks, restore the tracked tree immediately and verify its commit/status rather than leaving the prototype reachable by lazy route compilation.

Do not use an in-repo ignored directory as an executable worktree if the framework watches nested files. Keep review artifacts non-executable and outside application source roots.

## Verdict guidance

Block deployment when a change claims lifecycle/cardinality safety but only adds a local count guard and leaves races or irreversible orphan paths. Report separately on:

- final database-row integrity;
- object-store lifecycle integrity;
- replacement/new-resource UX;
- auth/authz and validation ordering;
- malformed persisted state;
- test realism and side-effect assertions.
