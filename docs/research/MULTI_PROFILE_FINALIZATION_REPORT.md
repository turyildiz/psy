# Multi-Profile Proposal Finalization Report

> **MP-0 completion note (2026-08-08):** The downstream decision/checklist reconciliation listed as follow-up item 1 was completed by the documentation-only MP-0 package recorded in [`MP0_RECONCILIATION_REPORT.md`](./MP0_RECONCILIATION_REPORT.md). This report otherwise preserves the earlier finalization record.

**Date:** 2026-08-08
**Scope:** Documentation-only reconciliation of the 18 decisions that previously appeared as open questions in Part XV of `docs/MULTI_PROFILE_PROPOSAL.md`.
**Compared states:** pre-finalization proposal at `43c9fa9` and finalized proposal at `2e13d7d`.
**Implementation impact:** No schema, SQL, application, test, service, or live-data changes were made.

---

## 1. Executive summary

The Multi-Profile proposal is now product-finalized:

- all 18 former open questions moved into **Part I — Resolved decisions**, continuing the original numbering from 11 through 29;
- the obsolete Part XV question list was removed;
- a final decision-status section now states that no Multi-Profile product question remains open in the proposal;
- dependent database-impact, application-flow, interaction, messaging, deletion, migration, risk, non-goal, slice-plan, and verification sections were reconciled with the decisions;
- the slice plan changed in MP-0 and MP-5 through MP-14;
- MP-1 through MP-4 retained their ordering and core scope;
- the most material simplification is MP-7: verified per-profile reaction uniqueness remains unchanged, and all proposed account-level reaction uniqueness/deduplication work was removed;
- production account deletion now has an explicit lawyer-verification gate for the moderation tombstone and registration-block wording.

---

## 2. What changed in the proposal

### 2.1 Status and decision authority

Before finalization, the proposal described the product direction as decided but said implementation details and open questions still required review.

After finalization:

- document status is **Product decisions finalized; implementation proposal only**;
- detailed SQL, rollback, implementation packages, and verification evidence still require review;
- product decisions may not be silently reopened by later implementation work.

### 2.2 Resolved decisions expanded from 11 to 29

The 18 finalized decisions were added as decisions 12–29:

12. Wall reactions remain per profile.
13. Notice Board reactions remain per profile with current mechanics unchanged.
14. Festival RSVPs remain per profile.
15. Following feeds and counts remain per profile; sibling follows are allowed; exact self-follow remains blocked.
16. Same-account direct messaging and listing contact are blocked with neutral private feedback and no email.
17. Multiple profiles of the same type are allowed; only the total five-profile cap applies.
18. Inactive owned profile pages show a private switch action and never auto-switch.
19. Dirty forms require **Stay** / **Discard and switch** resolution.
20. Profiles that created events cannot be deleted until reviewed admin transfer.
21. Deleted participants render as **Deleted profile** with no handle, avatar, or link.
22. Banned users may delete only their whole account; every other mutation remains blocked.
23. Account deletion retains only a private 12-month moderation tombstone, subject to lawyer verification.
24. Email reuse is immediate except while a matching unexpired ban tombstone exists.
25. New-profile onboarding requires handle, display name, and type and activates the new profile immediately.
26. Sibling profiles are visible to admins only in a dedicated admin-only account panel.
27. New-message email is unread-aware, delayed, and throttled per conversation.
28. Realtime private-delete handling is an empirical messaging-slice verification gate, not a preselected schema change.
29. The final super-admin cannot self-delete before verified role transfer.

### 2.3 Database impact audit reconciled

The impact matrix now records finalized behavior instead of unresolved cardinality questions:

- `vendor_events` keeps per-profile RSVP uniqueness and public profile counts;
- Notice Board reactions keep current per-profile/per-emoji mechanics;
- follows keep profile-level feeds/counts and allow sibling follows while preserving exact self-follow blocking;
- Chunk 11C Wall reactions keep verified `(post_id, profile_id)` uniqueness;
- no account-level owner column, deduplication constraint, reaction-move operation, or owner-linking helper is proposed.

### 2.4 Application-flow sections reconciled

The application inventory now requires:

- private **Switch to @handle to manage** on inactive owned profiles without automatic switching;
- dirty listing, post, and profile forms to use **Stay** / **Discard and switch**;
- profile onboarding fields limited to handle, display name, and type;
- duplicate profile types to remain valid;
- a successfully created or claimed profile to become active immediately;
- a dedicated admin-only account/profile linkage panel, with no inline sibling information in public-adjacent moderation UI.

### 2.5 Interaction semantics finalized

Part VIII was rewritten from alternatives/questions into binding behavior:

- Wall reactions are independent per profile;
- Notice Board reaction mechanics are unchanged, including separate rows for different emojis;
- sibling follows are allowed and count separately;
- exact self-profile follow remains blocked;
- RSVP rows and public counts remain per profile, including different sibling roles at one event;
- sibling reactions/follows/RSVPs are allowed;
- same-account messaging and listing contact are blocked before a conversation/message exists.

A verification matrix was added for these exact sibling-profile cases.

### 2.6 Messaging, email, and Realtime reconciled

Messaging now explicitly requires:

- private comparison of both participant owners before conversation/contact creation;
- same-account contact rejection with **you can't contact your own profile**;
- no conversation, message, or email side effect for that rejection;
- an idempotent message/outbox boundary;
- sending only after the conversation remains unread for the approved delay;
- throttling per conversation instead of one email per message;
- **Deleted profile** with no historical handle, avatar, or link;
- direct empirical testing of unauthorized and stale subscribers for private `DELETE` identifiers;
- authorized Broadcast only when that testing confirms exposure.

### 2.7 Profile deletion reconciled

Profile deletion now:

- fails when the profile owns events;
- returns an admin-transfer-required result;
- never deletes or automatically reassigns an event;
- remains unavailable as a single-profile operation to banned users;
- keeps existing real deletion rules for listings/posts and report-only media orphans;
- preserves surviving conversations under the neutral **Deleted profile** identity.

The proposal records that direct user event creation is not a V1 flow. The planned direction—festival-page flyer/link submission, admin review, Telegram-agent creation—is context only; its exact workflow remains intentionally undesigned.

### 2.8 Account deletion reconciled

Account deletion now explicitly includes:

- a narrow whole-account deletion exception for banned users;
- final-super-admin transfer/verification guard;
- a single private moderation tombstone containing only hashed email, ban date/reason, and deletion date;
- automatic tombstone expiry after 12 months;
- removal/anonymization of other account-linked moderation/audit identity;
- immediate email re-registration unless an unexpired matching ban tombstone exists;
- no retained content, images, or private account copy of messages;
- continued preservation of counterpart-visible shared conversations under **Deleted profile**;
- lawyer verification before production approval.

### 2.9 Migration, risks, non-goals, and verification reconciled

The proposal now treats profile-level multiplicity as intentional product behavior rather than unresolved count inflation.

It also records:

- accidental account deduplication or cross-sibling rewriting as implementation drift and a privacy risk;
- account-level reaction/follow/RSVP deduplication as a non-goal;
- the exact festival submission workflow as a non-goal for this package;
- explicit interaction tests for sibling reactions, follows, RSVPs, blocked contact, and dirty-form switching;
- deletion tests for banned users, final super-admin, event blockers, tombstone expiry, email reuse, and legal approval.

### 2.10 Structural cleanup

While reconciling the document, the missing **Part XIII — Required verification matrices** heading was restored. Part XV was removed and replaced by a short final decision-status statement.

---

## 3. Every slice-plan change — before and after

MP-1 through MP-4 did not change. Their privacy, cardinality, active-session, authorization, and deletion-foundation ordering remains intact.

### MP-0 — Decision/document reconciliation

**Before**

- Approve the proposal and answer open questions.

**After**

- Record all 29 finalized decisions and remove the obsolete open-question list.

**Reason**

All Part XV questions are now answered; implementation must reconcile downstream decision documents rather than seek product answers.

### MP-5 — Public-profile client cutover and active Header

**Before**

- Header/provider/profile-query conversion only.

**After**

- Add private **Switch to @handle to manage** on inactive owned profile pages, with no automatic switch.
- Add a dedicated admin-only account/profile linkage panel.
- Keep sibling ownership out of inline public-adjacent moderation cards.

**Decisions applied:** 18 and 26.

### MP-6 — Profile media namespace, listings, editing, and uploads

**Before**

- Generic switch-with-unsaved-work behavior.

**After**

- Require the exact **Stay** / **Discard and switch** confirmation for dirty listing/profile forms.
- Prohibit publishing under either identity before explicit resolution.

**Decision applied:** 19.

### MP-7 — Wall posts and reactions

**Before**

- Implement a still-undecided account-versus-profile reaction model in the RPC package.

**After**

- Preserve verified per-profile Wall reaction uniqueness and existing trusted set/remove mechanics.
- Preserve current Notice Board reaction mechanics unchanged.
- Add no account-level uniqueness, owner column, deduplication, cross-sibling lookup, or reaction-moving work.
- Apply **Stay** / **Discard and switch** to dirty post forms.

**Decisions applied:** 12, 13, and 19.

**Material effect:** This removes proposed account-level reaction work; the existing uniqueness machinery does not need redesign for cardinality.

### MP-8 — Messaging and notification email

**Before**

- Active-profile inbox/read/send/hide/unhide.
- Generic account-level email preference with contacted-profile handle.
- Generic deleted-participant verification.

**After**

- Block same-account direct messages and listing contact before side effects.
- Return neutral owner-only feedback and send no email.
- Add unread-aware delayed sending, idempotent outbox, and per-conversation throttling.
- Render **Deleted profile** with no handle, avatar, or link.
- Empirically test private Realtime `DELETE` identifier visibility.
- Use authorized Broadcast only if exposure is confirmed.

**Decisions applied:** 16, 21, 27, and 28.

### MP-9 — Follows, Following, festivals, RSVPs, and notices

**Before**

- Implement unspecified resolved actor/count semantics.

**After**

- Keep Following feeds, follower counts, RSVPs, and Notice reactions per profile.
- Allow sibling follows and multiple sibling RSVPs.
- Preserve exact self-profile follow blocking.
- Add no account deduplication.

**Decisions applied:** 13, 14, and 15.

### MP-10 — Multi-Profile enablement and reserved-profile claims

**Before**

- Enable profile creation and claims under the five-profile cap without finalized onboarding/activation details.

**After**

- Require only handle, display name, and type.
- Allow multiple profiles of the same type.
- Make a newly created or claimed profile active immediately.

**Decisions applied:** 17 and 25.

### MP-11 — Conversation retention under profile deletion

**Before**

- Generic nullable/tombstone participant model and null rendering.

**After**

- Enforce the exact neutral **Deleted profile** presentation with no handle, avatar, or link.

**Decision applied:** 21.

### MP-12 — Profile deletion

**Before**

- Generic profile deletion with created-event blockers left unresolved.

**After**

- Block deletion while the profile owns events and require reviewed admin transfer.
- Keep single-profile deletion unavailable to banned users.

**Decisions applied:** 20 and 22.

### MP-13 — Account deletion

**Before**

- Generic separately specified account deletion with Auth/database retries and counterpart conversation preservation.

**After**

- Permit banned users to delete the whole account while all other mutations remain blocked.
- Create only the private 12-month moderation tombstone.
- Allow immediate email reuse except during an unexpired matching ban tombstone.
- Block final-super-admin deletion until verified role transfer.
- Preserve counterpart conversations under the neutral deleted identity while removing other account-linked retained data.

**Decisions applied:** 21, 22, 23, 24, and 29.

### MP-14 — Full launch gate

**Before**

- Standard static, RLS/privacy, browser, network, email, R2, and manual launch verification.

**After**

- Add mandatory lawyer verification of tombstone fields, hashing, retention period, registration block, and user-facing wording before production approval.

**Decision applied:** 23.

---

## 4. Conflicts and ambiguities found during integration

### 4.1 Earlier recommendations conflicted with final decisions

The pre-final proposal recommended account-level Wall reactions and recommended blocking sibling follows. The finalized decisions choose the opposite:

- reactions remain independently per profile;
- sibling follows are allowed and count separately.

Those recommendations were removed everywhere, including the impact matrix, Part VIII, slice plan, risks, non-goals, and verification matrix.

### 4.2 Notice Board “per profile” includes current per-emoji multiplicity

The decision says current mechanics stay. The current unique key is `(post_id, profile_id, emoji)`, so one profile may retain different emojis on one Notice post. The proposal now states this explicitly to avoid a later implementation incorrectly imposing one total emoji per profile.

### 4.3 Shared-login rationale is not a team-permissions feature

The reaction/follow rationale allows profiles under one login to be maintained by different people. This does not add delegated access, separate credentials, audit attribution per maintainer, or multi-account ownership of one profile. Team/shared profile management remains a non-goal. If formal multi-user profile management is wanted later, it requires a separate security model.

### 4.4 “Only tombstone survives” versus counterpart message history

The original fixed deletion decisions require surviving conversation history to remain available to the other participant. The finalized retention decision says no messages survive as retained private moderation/account data.

The proposal reconciles these as follows:

- no private account copy or moderation retention of messages survives;
- the other participant's shared conversation history remains product data under the prior fixed decision;
- the deleted side is shown only as **Deleted profile**.

The detailed account-deletion/messaging specification must preserve this distinction explicitly.

### 4.5 Realtime decision is conditional, not a predetermined migration

No Broadcast schema/architecture switch is authorized in advance. MP-8 must first reproduce the suspected private identifier exposure with unauthorized and stale subscribers. Broadcast becomes required only if that test confirms exposure.

### 4.6 Event submission remains intentionally undesigned

The deletion rule is final: event ownership blocks profile deletion until reviewed admin transfer. The festival-page flyer/link submission, admin review, and Telegram-agent creation direction is context, not an implementation specification. It should not be silently designed inside the Multi-Profile database slice.

### 4.7 Email delay/throttle values are not specified

The cadence model is decided—unread-aware, delayed, throttled per conversation—but exact delay and throttle windows are not. These are implementation parameters that need explicit values in the messaging package and staging acceptance criteria; they do not reopen the product model.

### 4.8 Tombstone matching needs security/legal precision

The product fields and 12-month expiry are fixed, but implementation still must define:

- email canonicalization before hashing;
- whether the “hash” is a keyed/HMAC construction to resist offline guessing;
- key rotation and access controls;
- automatic expiry enforcement and verification;
- how a matching unexpired ban tombstone blocks signup without becoming a public account-existence oracle.

The proposal flags all tombstone wording and behavior for lawyer verification before production.

### 4.9 Final-super-admin transfer needs an exact verifier

The rule is final, but the account-deletion package must define a race-safe check that another verified super-admin exists after transfer and before deletion proceeds. The current “at most one super-admin” invariant does not itself guarantee that one remains.

### 4.10 Structural issue corrected

The proposal's required-verification section had lost its Part XIII heading during earlier editing. The heading was restored while finalizing the document; no product content changed as a result.

---

## 5. Follow-up items

These are implementation/documentation tasks, not open Multi-Profile product questions:

1. Amend the binding decision documents, reserved-claim workflow, punch list, and launch checklist in MP-0.
2. Specify exact unread-email delay and per-conversation throttle windows in MP-8.
3. Build direct unauthorized/stale-subscriber Realtime tests before deciding whether Broadcast is required.
4. Write the detailed profile/account deletion and conversation-retention specification.
5. Define the reviewed admin event-transfer operation before profile deletion is enabled.
6. Define tombstone hashing/canonicalization, expiry enforcement, signup blocking, and access controls.
7. Obtain lawyer verification before production launch.
8. Define and verify the final-super-admin transfer guard.
9. Keep the festival submission workflow out of Multi-Profile implementation until separately designed.

---

## 6. Verification performed

The finalized proposal was checked for:

- exactly 29 sequential resolved decisions;
- representation of all 18 supplied decisions;
- removal of Part XV and all “open question” wording;
- preservation of per-profile Wall and Notice reaction mechanics;
- explicit sibling follow/RSVP/count behavior;
- exact same-account contact, switch-confirmation, deletion, retention, email, Realtime, and super-admin rules;
- updated slice-plan and verification matrices;
- balanced Markdown fences and no trailing whitespace;
- documentation-only repository changes.
