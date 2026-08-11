# MP-4 policy conversion — live application and verification

**Date:** 2026-08-11

**Status:** PASS — live

**Apply method:** Turgay executed the reviewed fixture and MP-4 SQL artifacts one at a time in Supabase SQL Editor as project owner.

**Verification method:** Owner-run MP-4 fixture/preflight/apply/verify/unban ritual against the live database, followed by a corrected verify-only rerun after independent review of the live-data harness findings.

## Purpose and scope

MP-4 converts the approved authorization compatibility layer from direct profile-owner-column checks to the reviewed ownership helpers. The live package covers 22 policies and 10 functions without enabling multiple profiles or changing who may perform each action.

This record documents the live state transition. Package D, which removes anonymous `profiles.user_id` exposure through the separately guarded privacy cutover, remains unapplied.

## Live execution record

| Step | Live result |
|---|---|
| `@darktribo` fixture preflight | GO |
| Temporary database-only ban | Applied |
| Fixture verify | GO |
| MP-4 policy-conversion preflight | Full GO; `banned_profile_owner` proven |
| MP-4 policy-conversion apply | Committed cleanly |
| First MP-4 verify | STOP — 13 of 16 families proven |
| Verify-harness correction | `b85b20f`, independently reviewed |
| Corrected MP-4 verify rerun | GO — 16 of 16 families proven |
| Fixture unban | Restored |
| Fixture unban-verify | GO |

## First verification diagnosis

The initial STOP was caused by three assumptions in the verification harness, not by the applied policies or functions:

1. The Notice-post allow probe used category `other`, while the live constraint permits only `rideshare`, `lost_found`, `looking_for`, `giving_away` and `shoutout`.
2. The Notice-reaction probe used `👍`, while the live constraint permits only `❤️`, `🙏`, `🔥`, `😂` and `🫂`.
3. The RSVP allow probe selected the first event by ID even though the chosen actor profile already had a real RSVP for that event, colliding with the live unique key on `(profile_id, event_id)`.

The verify-only correction changed the test literals to allowed values, selected an event without an existing actor RSVP, preserved an `UNPROVEN — event fixture unavailable` fallback, and made allow-path failures report their SQLSTATE instead of hiding the cause. No preflight, apply, rollback, policy, function or fixture artifact changed.

## Final verification result

The corrected live rerun returned:

- overall status: **GO**;
- proven families: **16 of 16**;
- unproven families: **0**;
- all allow paths: **GO**;
- all deny paths: **GO**, including the banned-account denial path.

## Fixture restoration

The temporary database ban was removed after MP-4 verification. Unban and unban-verify both returned GO. `@darktribo` had zero Hero-featured posts before the fixture, so no Hero state was cleared. The only non-restored differences were the accepted `updated_at` timestamp advances caused by the suspension/unban trigger path.

## Conclusion

MP-4 is live and verified as of 2026-08-11. The compatibility conversion is complete; it does not itself enable Multi-Profile. The next guarded database operation is Package D/database-enforced public-profile privacy.
