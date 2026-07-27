# Chunk 10 — Authenticated functional smoke execution record

**Date:** 2026-07-27

**Status:** PASS — live
**Database path under test:** Supabase client authenticated as an existing demo user via the anon key; ordinary authenticated RLS applied. The insert did not use `service_role`.

## Test identity and scope

- Demo profile: `@otis`
- Conversation: `58d7b595-2e48-4973-8a22-ba310224a36f`
- Operation: insert one message as a real conversation participant, read the parent conversation back through the authenticated client, verify the trigger-derived fields, then remove only the test message and restore the exact pre-test conversation preview.

No Auth user or profile was created.

## Before state

| Field | Value |
|---|---|
| Live message count | 20 |
| `last_message_at` | `2026-07-27T09:09:52.715577+00:00` |
| `last_message_body` | `Hi` |

The count was already 20 before the smoke insert. The earlier 19-row baseline had changed because of a known real message from `@turgay`; no unknown row was removed.

## Test insert and trigger result

| Field | Value |
|---|---|
| Test message ID | `d167ef24-e155-4fdd-9fd7-9f3c6eae3de5` |
| Test message `created_at` | `2026-07-27T09:16:27.721358+00:00` |
| Original body length | 232 characters |
| Expected preview length | 120 characters |
| Triggered `last_message_at` | `2026-07-27T09:16:27.721358+00:00` |
| Triggered `last_message_body` | `Chunk 10 authenticated trigger smoke 2026-07-27T09:16:27.626Z-8637ce533d :: abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqr` |

| Check | Result |
|---|---|
| Authenticated/RLS message insert succeeded | PASS |
| Insert error object | None |
| `last_message_at = inserted.created_at` | PASS |
| `last_message_body = left(inserted.body, 120)` | PASS |

## Cleanup

Cleanup used the trusted service client only after the authenticated behavior had been proven.

| Check | Result |
|---|---|
| Exact test message deleted | PASS |
| Test message confirmed absent | PASS |
| Conversation preview restored to exact before values | PASS |
| Final `last_message_at` restored | `2026-07-27T09:09:52.715577+00:00` |
| Final `last_message_body` restored | `Hi` |
| Final message count | 20 — exact pre-smoke baseline |

No non-test message was deleted.

## Identification of the 20th message

A separate read-only query identified the row that changed the earlier 19-row baseline:

| Field | Value |
|---|---|
| Message ID | `a29b8f9d-b023-44d8-bec1-81a5574abcad` |
| Created at | `2026-07-27T09:09:52.715577+00:00` |
| Sender profile | `@turgay` |
| Conversation | `58d7b595-2e48-4973-8a22-ba310224a36f` |
| First 50 body characters | `Hi` |

It was the only message created during the reviewed 48-hour window. It came from the known owner profile, not an unexpected account, bot, or smoke-test artifact.

## Conclusion

The live Chunk 10 trigger works through the same authenticated RLS path used by the application. The trigger updates both conversation summary fields exactly as designed, and the test left no message or conversation-state residue.
