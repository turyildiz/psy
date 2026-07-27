# Chunk 10 — SECURITY DEFINER hardening review

> **Status: LIVE — OWNER-APPLIED AND VERIFIED 2026-07-27**
>
> Prepared against the accepted 2026-07-26 live reconciliation baseline and a fresh read-only catalog/data preflight. Turgay applied the reviewed SQL in Supabase SQL Editor; the agent then verified the live definitions, ACLs, RLS/owner state, data invariants, and authenticated trigger behavior.

## Purpose and scope

Harden exactly these two existing functions without changing their signatures:

- `public.increment_view_count(listing_id uuid) returns void`
- `public.update_conversation_last_message() returns trigger`

The chunk:

- fixes each `SECURITY DEFINER` function to the empty `search_path = ''`;
- schema-qualifies all application tables and the `listing_status` enum;
- explicitly revokes PostgreSQL `PUBLIC`, `anon`, and `authenticated` execution;
- grants only `service_role` in addition to the function owner, `postgres`;
- retains the current `on_message_insert` trigger;
- adds trigger-context and exact-parent guards to the trigger function;
- performs no intentional table-data rewrite;
- makes no application-code change.

Chunk 10 depends only on live Chunks 0–7. Deferred/unapplied Chunks 8–9 are not dependencies and are not included.

## Review artifacts

| Artifact | Purpose |
|---|---|
| `supabase/chunks/chunk-10-security-definer-hardening-preflight.sql` | Read-only, one-row go/no-go preflight |
| `supabase/chunks/chunk-10-security-definer-hardening-apply.sql` | Owner-applied transactional DDL/ACL change |
| `supabase/chunks/chunk-10-security-definer-hardening-rollback.sql` | Owner-applied exact captured-state rollback |
| `supabase/chunks/chunk-10-security-definer-hardening-verify.sql` | Independent read-only post-apply verification |

## Fresh read-only live preflight

The discovery connection was explicitly read-only:

- `current_user = audit_readonly`
- `transaction_read_only = on`
- `row_security = on`
- not superuser;
- no `BYPASSRLS`;
- no database or `public` schema `CREATE` privilege.

Completeness-sensitive aggregates were separately checked through the service-role API without writing data or persisting row-level exports.

### Captured pre-apply function state

| Function | Language | Owner | SECURITY DEFINER | Fixed search path | Definition MD5 |
|---|---|---|---:|---:|---|
| `increment_view_count(uuid)` | SQL | `postgres` | Yes | No | `d81d823b78ccd0d43568fd1e953c9e33` |
| `update_conversation_last_message()` | PL/pgSQL | `postgres` | Yes | No | `7c039aa69192e88960c5a1b9e7518b62` |

Before Chunk 10, both functions granted `EXECUTE` to:

- PostgreSQL `PUBLIC`;
- `anon`;
- `authenticated`;
- `service_role`;
- owner `postgres`.

### Live trigger and data state

- Exactly one trigger calls `update_conversation_last_message()`:
  - `public.messages.on_message_insert`;
  - enabled;
  - `AFTER INSERT`;
  - `FOR EACH ROW`.
- The validated `messages_conversation_id_fkey` points to `conversations(id) ON DELETE CASCADE`.
- Exact service-visible counts:
  - 28 listings;
  - 19 messages;
  - 7 conversations.
- All 28 listing `view_count` values are exactly zero.
- No null or negative listing view counts.
- Five conversations contain messages; all five stored `last_message_at` and `last_message_body` values exactly match their latest message.
- Two conversations contain no messages.
- No orphan message references were found.

### FORCE RLS / definer-owner preflight

Fresh read-only catalog checks on 2026-07-27 confirmed:

| Check | Live result |
|---|---|
| `public.conversations` owner | `postgres` |
| RLS enabled | Yes |
| FORCE ROW LEVEL SECURITY | **No** (`relforcerowsecurity = false`) |
| Function owner | `postgres` |
| Function owner is superuser | No |
| Function owner has `BYPASSRLS` | **Yes** |
| Function owner has table `UPDATE` | Yes |
| Message-to-conversation FK | Validated, `ON DELETE CASCADE` |
| Trigger | Enabled `AFTER INSERT FOR EACH ROW` |

The `SECURITY DEFINER` body therefore runs as `postgres`, not as the browser
role. `postgres` owns `public.conversations`, the table does not force RLS, and
the role independently has `BYPASSRLS`. The parent update cannot be filtered to
zero rows by conversation RLS.

For a valid message, the validated foreign key requires the parent conversation,
the conversation primary key makes the ID unique, and PostgreSQL's foreign-key
row locking prevents a concurrent parent deletion from completing during the
referencing insert transaction. The exact-one-row guard therefore does not add
a new failure path for an existing valid parent. A zero-row result would indicate
an invalid parent/trigger context or catalog-integrity failure; the insert would
already be invalid at the foreign-key boundary.

The unchecked Supabase results inside `MessagesInbox` remain a separate existing
reliability issue: RLS, validation, network, or trigger errors can be returned in
the `{ error }` result while the UI still clears its sending state. Chunk 10 does
not fix that UI behavior; it remains work for punch item 8.

## What actually calls each function today

### `increment_view_count(uuid)`

**Current caller: none.**

Repository-wide executable-code search found no `supabase.rpc("increment_view_count", ...)` call and no other function invocation.

Current listing-detail behavior is read-only:

1. `app/listing/[id]/page.tsx:123-138` loads the listing with `select("*")`.
2. `lib/db.ts:39` maps `row.view_count` into `listing.viewCount`.
3. `app/listing/[id]/page.tsx:407-412` displays `{listing.viewCount} views`.

`lib/mock-data.ts` contains synthetic nonzero fixture values, but it does not increment the live database.

**Compatibility conclusion:** revoking browser-role execution cannot break an existing app call because no call exists. View counts will continue to display but remain unwired and currently stay at zero. Wiring real view counting later requires a separate reviewed app/API decision; this chunk does not silently activate it.

### `update_conversation_last_message()`

**Current caller: the database trigger only.** No app code calls it as an RPC.

Actual path:

1. `components/MessagesInbox.tsx:125-138` sends a message with one direct `messages` insert.
2. Existing Chunk 6 message INSERT RLS authorizes an unbanned participant-owned sender profile.
3. PostgreSQL fires `public.messages.on_message_insert` after the accepted row insert.
4. The trigger function updates the parent conversation’s `last_message_at` and truncated `last_message_body`.
5. `components/MessagesInbox.tsx:79-95` later reads and orders conversations by `last_message_at` and displays `last_message_body`.

PostgreSQL does not require the inserting browser role to retain direct `EXECUTE` on a trigger function at trigger firing time. The trigger remains attached and executes as the function owner.

**Compatibility conclusion:** revoking `anon` and `authenticated` execution does not break message inserts. The function signature, trigger identity, timing, row level, timestamp assignment, 120-character truncation, and returned `NEW` row remain unchanged.

Current unrelated behavior remains: the message insert and `append_unread_for` RPC run concurrently via `Promise.all`, and the UI does not inspect either result before clearing its sending state. Chunk 10 neither worsens nor repairs that existing messaging reliability issue.

## Authorization design

### View count function

- No end-user grant is justified because there is no current app caller.
- `service_role` is retained as the only named operational caller.
- The function still updates only an existing `active` listing and silently affects zero rows for missing/private listings, preserving current behavior.
- Public/anonymous/authenticated invocation, including trivial count inflation through the exposed RPC, is closed.

### Conversation trigger function

- End users authorize only the originating `messages` insert through existing RLS.
- The trigger derives every value from `NEW`; it accepts no RPC parameters.
- The hardened body verifies it is executing only as an `AFTER INSERT FOR EACH ROW` trigger on `public.messages`.
- The validated FK and exact one-row update guard constrain the parent conversation.
- `service_role` is the only named explicit grant, matching the established trusted-role pattern for internal functions.

An `auth.uid()` check is intentionally not added to the trigger function: it would duplicate the message INSERT policy, interfere with trusted/system inserts, and incorrectly treat an internal derived-state trigger as an end-user RPC.

## Privilege review

| Function | PUBLIC before → after | anon before → after | authenticated before → after | service_role before → after | Internal authorization |
|---|---|---|---|---|---|
| `increment_view_count(uuid)` | Execute → revoked | Execute → revoked | Execute → revoked | Execute → Execute | Active-listing target restriction; trusted caller boundary |
| `update_conversation_last_message()` | Execute → revoked | Execute → revoked | Execute → revoked | Execute → Execute | Existing message RLS + trigger-context guard + validated FK + exact parent update |

The apply file explicitly revokes both PostgreSQL `PUBLIC` and Supabase named client roles after `CREATE OR REPLACE`, because replacement preserves prior ACLs and Supabase may hold role-specific grants.

## Definition compatibility

| Property | Before | After | Compatibility result |
|---|---|---|---|
| `increment_view_count` signature | `(listing_id uuid) returns void` | Same | Preserved |
| Increment behavior | Add 1 only for `active` listing | Same | Preserved |
| Missing/inactive target | Zero rows; void | Same | Preserved |
| Trigger function signature | `() returns trigger` | Same | Preserved |
| Trigger | `on_message_insert`, after insert, row | Same existing trigger | Preserved |
| Conversation timestamp | `NEW.created_at` | Same | Preserved |
| Conversation preview | `left(NEW.body, 120)` | Same | Preserved |
| Trigger return | `NEW` | Same | Preserved |
| Search path | Caller-controlled/default | Empty (`''`) | Hardened |
| Table/type references | Unqualified | Schema-qualified | Hardened |
| Client EXECUTE grants | Broad | None | Intentional security closure |

## Risk and what could break

**Risk level: low-to-medium.** The surface is narrow, but message sending is launch-critical.

Potential failure modes:

1. Unexpected live definition/ACL/trigger drift before application. The apply transaction aborts before replacement.
2. A hidden client not present in this repository calls `increment_view_count` directly. It will lose access; no repository call exists today.
3. A hidden client directly invokes the trigger function as RPC. That was never a valid trigger-function use and will lose access.
4. The message trigger is attached in an unexpected context. The new internal guard fails the insert rather than silently updating the wrong table/context.
5. The parent conversation unexpectedly cannot be updated. The exact-row guard aborts the message insert rather than accepting inconsistent preview metadata.

The validated FK, primary key, current trigger state, and current exact last-message reconciliation make items 4–5 unlikely under the reviewed schema.

## Rollback review

Rollback restores the exact captured function bodies and broad ACLs. It does not restore table rows because the apply chunk intentionally rewrites none.

Rollback is security-regressive by design. It reopens:

- missing fixed `search_path`;
- PostgreSQL `PUBLIC` execution;
- `anon` execution;
- `authenticated` execution.

It should be used only after a verified compatibility failure and explicit owner approval. The rollback fails closed if the hardened definitions or ACLs drift after application.

## Owner-apply workflow

1. Review this document and all four SQL files.
2. Run `chunk-10-security-definer-hardening-preflight.sql` in Supabase SQL Editor.
3. Confirm the single summary row has `all_checks_pass = true`.
4. Stop and report any false result; do not run apply.
5. After explicit approval, run `chunk-10-security-definer-hardening-apply.sql` once.
6. Report the SQL Editor result.
7. The agent runs `chunk-10-security-definer-hardening-verify.sql` independently through the read-only connection and reports each check as PASS/FAIL.
8. Do not commit/push the package as live until read-only verification passes.

## Current status

- Live preflight discovery: completed read-only.
- Apply SQL: owner-applied successfully in Supabase SQL Editor on 2026-07-27; all eight apply-result booleans were true.
- Post-apply verification: passed independently through the read-only connection; every catalog, definition, ACL, trigger, RLS/owner, and data-invariant check passed.
- Authenticated functional smoke: passed as `@otis` through the ordinary anon-key/authenticated-user RLS path; trigger timestamp and `left(body, 120)` behavior matched exactly.
- Smoke cleanup: test message deleted, conversation preview restored, and live message count returned to the actual 20-row pre-smoke baseline.
- The prior 19-to-20 message-count change was identified read-only as a known `@turgay` message (`Hi`), not an unknown or smoke-test artifact.
- Rollback SQL: retained for emergency use only; not executed.
