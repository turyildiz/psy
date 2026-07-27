# Chunk 10 — Read-only post-apply verification

**Date:** 2026-07-27

**Status:** PASS — live

**Apply method:** Turgay executed the reviewed apply SQL in Supabase SQL Editor.
**Verification method:** `chunk-10-security-definer-hardening-verify.sql` through the restricted read-only PostgreSQL connection, followed by completeness-sensitive read-only service-API aggregates.

## SQL Editor apply result

The final apply result returned all eight booleans as `true`:

- `increment_function_present`
- `conversation_trigger_function_present`
- `increment_anon_revoked`
- `increment_authenticated_revoked`
- `increment_service_role_granted`
- `conversation_trigger_anon_revoked`
- `conversation_trigger_authenticated_revoked`
- `conversation_trigger_service_role_granted`

## Independent read-only verification

| Check | Result |
|---|---|
| `increment_definition_hardened` | PASS |
| `conversation_trigger_definition_hardened` | PASS |
| `increment_public_revoked` | PASS |
| `increment_anon_revoked` | PASS |
| `increment_authenticated_revoked` | PASS |
| `increment_service_role_granted` | PASS |
| `conversation_trigger_public_revoked` | PASS |
| `conversation_trigger_anon_revoked` | PASS |
| `conversation_trigger_authenticated_revoked` | PASS |
| `conversation_trigger_service_role_granted` | PASS |
| `only_owner_and_service_role_execute` | PASS |
| `conversations_rls_enabled_not_forced_and_postgres_owned` | PASS |
| `trigger_definer_owner_bypasses_rls` | PASS |
| `trigger_definer_owner_has_update` | PASS |
| `matching_message_trigger_count = 1` | PASS |
| `exact_enabled_after_insert_row_trigger` | PASS |
| `null_view_count_rows = 0` | PASS |
| `negative_view_count_rows = 0` | PASS |
| `orphan_message_count = 0` | PASS |
| `last_message_mismatch_count = 0` | PASS |
| `all_checks_pass` | PASS (`true`) |

## Complete aggregate reconciliation at verification time

The restricted auditor is RLS-filtered, so complete aggregates were independently checked through the read-only service API.

| Invariant | Complete result | Result |
|---|---:|---|
| Listings | 28 | PASS |
| Null listing view counts | 0 | PASS |
| Negative listing view counts | 0 | PASS |
| Minimum/maximum view count | 0 / 0 | PASS |
| Messages | 19 | PASS |
| Conversations | 7 | PASS |
| Orphan messages | 0 | PASS |
| Conversations with messages whose latest metadata matched | 5 of 5 | PASS |
| Latest-message mismatches | 0 | PASS |
| Conversations without messages | 2 | PASS |

A later known `@turgay` message increased the live message count from 19 to 20 before the authenticated smoke test. That later row is documented in the smoke execution record and is not a verification discrepancy or test artifact.

## Conclusion

Chunk 10 is live and verified. Both functions use an empty search path, schema-qualified references, and the reviewed minimal ACLs. The existing message trigger remains enabled and correctly attached. Rollback was not executed.
