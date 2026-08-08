# MP-0 Decision/Document Reconciliation Report

**Date:** 2026-08-08
**Authority:** [`docs/MULTI_PROFILE_PROPOSAL.md`](../MULTI_PROFILE_PROPOSAL.md), 29 resolved decisions
**Scope:** Documentation only. No schema, SQL, application code, tests, services, or live data were changed.

---

## 1. Result

Repository decision, workflow, launch, project-context, and historical-planning documentation now distinguishes three states clearly:

1. **Binding V1 product target:** Multi-Profile is V1 scope under the finalized 29 decisions.
2. **Current implementation baseline:** the database and application still contain the pre-Multi-Profile one-profile assumptions until the reviewed MP slices are implemented.
3. **Historical evidence:** old PRD/specification/audit/handover wording is preserved, but affected documents carry a prominent supersession or historical-capture note.

No historical SQL was rewritten and no implementation work was pulled into MP-0. The package changes **20 Markdown/documentation files**: 19 existing records plus this report.

---

## 2. Files changed and why

### Binding/current decision and planning documents

#### `docs/V1_DECISIONS.md`

- Amended the profile decision without deleting its history.
- Added the hard five-profile cap, unchanged signup creation of one personal profile, duplicate-type allowance, `vendor` / **Shop / Brand**, active-profile model, and public sibling unlinkability.
- Made messaging/inbox hiding profile-scoped and recorded the same-account contact block and neutral deleted identity.
- Added per-profile reactions, follows/Following, follower counts, RSVPs, and Notice Board behavior.
- Added minimal additional-profile onboarding and immediate create/claim activation.
- Added profile-deletion and V1 whole-account-deletion rules, banned-account exception, moderation tombstone, email-reuse rule, final-super-admin guard, and lawyer gate.
- Clarified that the narrow admin-only sibling linkage panel is V1 even though broad admin reporting/analytics remains V2.
- Added `vendor` to Wall posting types and made the Following tab active-profile scoped.

#### `docs/MULTI_PROFILE_PROPOSAL.md`

- Replaced the pre-MP-0 statement that downstream decision documents still awaited reconciliation.
- Recorded that MP-0 updates current decision/checklist documents while historical records retain their original text under explicit notes.

#### `docs/WALL_DATA_MODEL_PROPOSAL.md`

- Added `vendor` / **Shop / Brand** to the finalized posting types.
- Corrected the reaction constraint label from “person” to “profile” and made sibling independence/no account deduplication explicit.

#### `docs/V1_PUNCHLIST.md`

- Added the binding MP-0 through MP-14 package reference.
- Updated database, listing, moderation, messaging, email, festivals, settings/deletion, and launch-gate summaries to active-profile/per-profile semantics.
- Added checklist-level launch coverage without copying the proposal's detailed matrices.

#### `docs/PRE_LAUNCH_TEST_LIST.md`

- Added a dedicated Multi-Profile browser launch gate covering:
  - cap/type/onboarding;
  - switcher and dirty-form safety;
  - identity-bearing actions and state reset;
  - sibling interactions and same-account contact blocking;
  - public unlinkability;
  - profile deletion and whole-account deletion;
  - banned-account and final-super-admin safeguards;
  - moderation tombstone/email reuse and lawyer approval.

#### `.agent-context/DECISIONS.md`

- Replaced the stale V1 one-profile/V2-follow rows with the finalized five-profile, active-profile, `vendor`, per-profile Following, and no-team-access decisions.

#### `.agent-context/NEXT_STEPS.md`

- Marked the old sprint detail as historical context.
- Pointed current work to `V1_PUNCHLIST.md` and the MP-0 through MP-14 plan.
- Removed Multi-Profile and follows/feed from the V2 list while keeping team access post-V1.

#### `.agent-context/CURRENT_STATE.md`

- Added the proposal to the source-of-truth order.
- Recorded Multi-Profile and Following as binding V1 scope.
- Kept the implementation boundary explicit: the live baseline still has the one-profile index, one-row application lookups, and no switcher.
- Corrected conversation hiding to profile-scoped terminology.

#### `AGENTS.md`

- Added the proposal as the binding detailed source for Multi-Profile decisions and ordered implementation/verification slices.

#### `docs/README.md`

- Added `V1_DECISIONS.md` and the proposal to the read-first/source list.
- Marked the historical PRD, specification, roles document, and PDF exports as superseded on Multi-Profile scope.

### Reserved-profile workflow

#### `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md`

- Replaced every one-profile claim blocker.
- Existing accounts may claim while below five profiles; four may claim a fifth and five may not claim a sixth.
- The account row/cap must be locked and checked against concurrent create/claim attempts.
- Finalized types replace historical `shop`/`creator` examples.
- Handle, display name, and finalized type are the only required onboarding fields.
- A successful claim consumes one profile slot and immediately activates the claimed profile.
- Cap rejection must not consume the invitation or reservation.
- Acceptance criteria and hardening tests now cover fifth-profile success, sixth-profile rejection, activation, and races.
- Team access replaces Multi-Profile itself as the relevant non-goal.

### Historical/archived documents preserved with top notes

#### `docs/REFINED_PRD.md`

- Added a prominent note that its one-profile-in-V1, V2-switcher, and four-type statements are historical and superseded.
- Left the original PRD body unchanged.

#### `docs/SPEC.md`

- Added a prominent note directing implementation to the proposal instead of the historical one-profile/V2 assumptions.
- Left the original specification body unchanged.

#### `docs/USER_ROLES.md`

- Added the requested status note: the original Umbrella Model is now V1 direction, bounded by five profiles, no team access, public unlinkability, one active profile, and finalized `vendor` naming.
- Left the historical unlimited-cardinality and Buyer/Vendor examples in place as design history.

#### `.agent-context/HANDOVER_CLAUDE_TO_PSY_2026-07-26.md`

- Added a historical note superseding its V2 follows/feed statement without rewriting the handover.

#### `docs/research/MULTI_IDENTITY_RESEARCH.md`

- Added a finalization note explaining that its one-profile/V2 statements are pre-decision evidence, not current V1 scope.
- Preserved all original quotes and schema/application findings.

#### `docs/research/MULTI_PROFILE_FINALIZATION_REPORT.md`

- Added an MP-0 completion note so its earlier “reconcile downstream documents” follow-up is not mistaken for unfinished current work.

#### `supabase/migrations-proposal.md`

- Added a top note distinguishing applied historical Chunk 2/current baseline from the finalized target.
- Withdrew deferred Chunk 9 because its historical SQL would drop V1 `follows` and other identity-sensitive structures before MP redesign/verification; retained the SQL block only as an unauthorized historical proposal.
- Kept applied chunk bodies and the withdrawn Chunk 9 SQL block unchanged; no historical SQL was edited or re-authorized.

#### `supabase/captured/AUDIT_REPORT.md`

- Added a historical-capture note clarifying that its 2026-07-12 one-profile finding is evidence, not current product policy.

### Reconciliation report

#### `docs/research/MP0_RECONCILIATION_REPORT.md`

- Created this requested file to record the documentation changes, whole-repository sweep, deferred code/SQL locations, retained historical evidence, ambiguities, and verification scope.

---

## 3. Parallel whole-repository sweep

### Method and counting

Three read-only sub-agents independently swept:

1. documentation, root/project-context Markdown, and archived planning records;
2. application code, code comments, types, scripts, tests, and READMEs;
3. Supabase SQL/Markdown, migration comments, captured artifacts, skill files, hidden agent files, and remaining paths.

A **location** means one coherent stale assumption at a file/surface, not every repeated word in a quote or every matching SQL line. Historical quotations/current-baseline descriptions count separately from stale current policy. Generic profile lookups by public handle do not count.

### Consolidated counts

| Classification | Locations | Disposition |
|---|---:|---|
| Stale documentation | **7** | Fixed in MP-0 |
| Application/test behavior | **38** | Deferred to the owning MP slices |
| SQL/database behavior | **19** | Deferred to new guarded MP packages; historical SQL unchanged |
| **Code/test/SQL deferred total** | **57** | Expected future implementation work |

The documentation count combines four findings from the final documentation pass and three project-context findings identified by the database/hidden-file pass. The latter were corrected while the parallel sweep was still running. Application and SQL areas are disjoint, so their counts can be summed without double-counting.

### Documentation findings fixed — 7

1. `docs/WALL_DATA_MODEL_PROPOSAL.md:12` — added finalized `vendor` / **Shop / Brand** posting type.
2. `docs/WALL_DATA_MODEL_PROPOSAL.md:496` — changed “one reaction per person” to per profile and made sibling independence/no account deduplication explicit.
3. `supabase/migrations-proposal.md:554-573` — withdrew deferred Chunk 9; its retained historical SQL must not drop V1 `follows` or be applied.
4. `supabase/migrations-proposal.md:605` — replaced the stale “dead/out-of-V1” Chunk 9 summary with the withdrawn/MP-redesign status.
5. `.agent-context/DECISIONS.md:21` — replaced “one profile only / Multi-Profile V2” with finalized V1 decisions.
6. `.agent-context/NEXT_STEPS.md:109` — removed Multi-Profile from the V2 list and pointed work to MP-0 through MP-14.
7. `.agent-context/CURRENT_STATE.md:114-117` — corrected per-user hiding/current scope language and documented the active-profile conversion gap.

### Application and test locations deferred — 38

#### One-profile actor resolution — 10

- `components/layout/Header.tsx:53-59,78-118`
- `app/messages/page.tsx:13-14`
- `app/listing/[id]/page.tsx:134-138`
- `app/listing/[id]/edit/page.tsx:180-184`
- `app/listings/new/page.tsx:249-280`
- `app/[handle]/page.tsx:190-210`
- `app/profile/edit/page.tsx:129-171`
- `app/festivals/[slug]/page.tsx:717-718`
- `lib/posts/use-reaction-viewer.ts:27-39`
- `app/api/auth/signup/route.ts:123-129`

These select one profile by account, choose a newest/first row, or broadly update by `user_id`. MP-5 through MP-10 must replace them with exact signup-profile or session-active-profile behavior.

#### Four-value profile types — 3

- `types/marketplace.ts:10-11`
- `app/profile/edit/page.tsx:13-18`
- `components/EditProfileModal.tsx:10-15`

These omit `vendor` / **Shop / Brand** and belong to the profile-contract/client slices.

#### Public owner exposure / unsafe profile contracts — 6

- `types/marketplace.ts:32-45`
- `lib/db.ts:3-18`
- `app/page.tsx:64`
- `app/[handle]/page.tsx:239`
- `app/listing/[id]/page.tsx:169`
- `app/festivals/[slug]/page.tsx:160-163`

These expose/map `user_id` through general profile contracts or use broad public `select("*")`/`profiles(*)` reads. They belong to MP-2/MP-5.

#### Active-profile isolation and sibling behavior — 5

- `lib/auth/ui-transition.ts:1-24,30-105`
- `components/MessagesInbox.tsx:43-110`
- `app/[handle]/page.tsx:259,341-497`
- `app/[handle]/page.tsx:153-170,420-424`
- `app/listing/[id]/page.tsx:179-205,445-448`

These omit profile-switch generations/state resets, inactive-sibling manage behavior, or same-account contact blocking. They belong to MP-5/MP-8.

#### Auth-user-based upload namespace/authorization — 8

- `lib/uploads/authorization.ts:19-26`
- `lib/uploads/intent-server.ts:31-40`
- `lib/uploads/token.ts:62-69`
- `lib/uploads/cleanup-policy.ts:31-35`
- `scripts/cleanup-promoted-pending.js:34-35,132-135`
- `scripts/lib/validated-r2-upload.js:90-100`
- `scripts/upload-r2.js:43-49`
- `scripts/upload-and-create.js:25-29`

These use the auth-user UUID in browser authorization or public object-key derivation and belong to MP-2/MP-6. Explicit trusted CLI profile-owner checks remain valid; only their public key namespace requires conversion.

#### Tests pinning stale behavior — 6

- `tests/auth-safety.test.ts:97-109`
- `tests/upload-intent.test.ts:8-16,36-38,48-65`
- `tests/trusted-cli-upload.test.ts:24-30,60-77`
- `tests/upload-policy.test.ts:68-89`
- `tests/upload-cleanup.test.ts:22-30`
- `tests/upload-server-pipeline.test.ts:17-33,72-85`

These must change with their owning active-profile/upload slices, not in documentation-only MP-0.

### SQL/database locations deferred — 19

1. `supabase/chunks/chunk-2-handles-profiles-apply.sql:16-22,163-168` — duplicate-account preflight and `profiles_one_per_user_key`; MP-3/MP-10.
2. `supabase/chunks/chunk-5-conversation-hiding-apply.sql:22-34` — participant-state read covers every owned profile; MP-4/MP-8.
3. `supabase/chunks/chunk-5-conversation-hiding-apply.sql:255-284` — conversation SELECT combines all owned profiles/hidden states; MP-4/MP-8.
4. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:127-139` — direct profile INSERT lacks the finalized cap/trusted creation boundary; MP-3/MP-10.
5. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:141-156` — profile editing is account-owned rather than active-profile scoped; MP-4/MP-6.
6. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:158-221` — listing mutations permit any owned profile; MP-4/MP-6.
7. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:223-244` — conversation creation permits any owned buyer and lacks same-account blocking; MP-4/MP-8.
8. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:246-265` — message sender may be any owned participant; MP-4/MP-8.
9. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:267-366` — unread RPCs choose an owned participant with `LIMIT 1`; MP-4/MP-8.
10. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:368-462` — hide/unhide RPCs choose an owned participant with `LIMIT 1`; MP-4/MP-8.
11. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:464-552` — find/unhide selects an arbitrary first account profile; MP-4/MP-8.
12. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:555-584` — RSVP mutations accept any owned profile; MP-4/MP-9.
13. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:586-646` — Notice post/reaction mutations accept any owned profile; MP-4/MP-9.
14. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:648-681` — favorites merges all owned profiles instead of preserving an active-profile private surface; MP-4.
15. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:683-711` — follow/unfollow actor may be any owned profile; MP-4/MP-9.
16. `supabase/chunks/chunk-6-ban-enforcement-durable-moderation-apply.sql:713-741` — event-notification mutations accept any owned profile; MP-4/MP-9.
17. `supabase/chunks/chunk-11a-wall-foundation-apply.sql:315-353` — post-image validator builds public paths from auth-user UUID; MP-6.
18. `supabase/chunks/chunk-11b-wall-posts-apply.sql:294-359,393-409,480-484` — post create/update/delete verifies ownership but not session-active identity; MP-7.
19. `supabase/chunks/chunk-11c-wall-reactions-moderation-apply.sql:182-286` — reaction set/remove verifies ownership but not session-active identity; MP-7.

### Negative findings

- No stale inline code comment, JSDoc, application README, or engineering comment outside documentation was found.
- No tracked repository `SKILL.md`, `.claude`, `.cursor`, `.hermes`, or `.agents` skill/config tree exists; there was no skill-file hit to fix.
- Generic profile lookup by globally unique handle/ID was not counted.
- Account-level bans and account-level abuse rate limits remain correct and were not flagged.
- Signup's creation of exactly one personal profile remains correct.
- Existing Wall and Notice Board per-profile reaction uniqueness remains correct; only active actor selection still needs its future slice.

---

## 4. Historical/current-baseline references intentionally retained

The following are not stale product decisions and were not rewritten:

- `docs/REFINED_PRD.md` and `docs/SPEC.md` bodies: historical product/specification decisions, now covered by top supersession notes.
- `docs/USER_ROLES.md` body: original Umbrella design history, now bounded by a top status note.
- `docs/research/MULTI_IDENTITY_RESEARCH.md`: quotations and read-only evidence from before the 29 decisions were finalized.
- `docs/psy-market-refined-prd-v3.pdf` and `docs/psy-market-v1-status-report-2026-07-12.pdf`: binary historical exports; their status is recorded in `docs/README.md` and the Markdown source notes rather than altering the PDFs.
- `supabase/captured/**`: timestamped schema/audit evidence.
- Applied and rollback SQL under `supabase/chunks/**`: exact implementation history and current pre-MP baseline.
- Current one-profile code paths and the `profiles_one_per_user_key` constraint: expected implementation work explicitly scheduled by the proposal, not documentation to disguise or remove in MP-0.

---

## 5. Ambiguities and choices

### Historical truth versus current policy

Old documents genuinely recorded a one-profile V1 decision. Rewriting those bodies would falsify history, so MP-0 adds top notes and changes only current/binding planning documents.

### Product scope versus implementation state

Multi-Profile is now V1 scope but is not implemented. Current-state documentation says both. It does not claim that the five-profile cap, `vendor`, switcher, active-profile authorization, or deletion flows are live.

### PDF exports

The two PDFs cannot receive a Markdown top note without modifying binary historical artifacts. They remain unchanged and are explicitly classified as historical/superseded in `docs/README.md` and the source/research notes.

### Reserved claims for a new signup

Signup still creates one personal profile. A successful reserved claim creates/attaches another profile within the same five-profile cap and activates the claimed profile. MP-0 does not design a different signup trigger.

### Active-profile authorization

Existing SQL often authorizes any profile owned by `auth.uid()`. That remains an ownership boundary but is insufficient for identity-bearing actions. MP-0 records those locations as deferred slice work and does not alter SQL.

### Account deletion and surviving conversations

The private moderation tombstone retains no messages. Counterpart-visible shared conversation history remains under the prior fixed deletion rule and renders the deleted side only as **Deleted profile**. Detailed orchestration remains implementation-package work.

### Realtime private deletes

No Broadcast migration was documented as predetermined. Direct private-delete leakage testing remains an MP-8 verification gate; Broadcast is conditional on confirmed exposure.

### Legal language

The 12-month moderation tombstone and registration block remain product decisions but cannot pass the production gate until lawyer verification is recorded.

### Team access

One account may own multiple profiles, but multiple auth accounts managing one profile remains out of V1. No historical shared-credential example was converted into a team-permissions design.

---

## 6. Verification requirements for this package

The final package must show:

- only Markdown/documentation files changed;
- no `.sql`, `.ts`, `.tsx`, schema, migration, application, test, service, or live-data change;
- no unresolved stale current-policy statement found by the three sweeps;
- all historical occurrences either clearly marked or classified in this report;
- every new relative Markdown link resolves;
- `git diff --check` passes;
- the report and all reconciliation edits are committed together and the pushed remote hash matches local `HEAD`.
