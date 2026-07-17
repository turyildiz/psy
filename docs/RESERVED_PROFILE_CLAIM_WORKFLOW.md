# Reserved Profiles and Private Claim Links

**Project:** psy.market  
**Document type:** Product and technical workflow specification  
**Status:** Planned — not implemented  
**Created:** 2026-07-12  
**Owner:** Turgay Yildiz

---

## 1. Purpose

Before psy.market launches, the admin should be able to reserve important public identities for established psytrance labels, artists, shops, designers, festivals, and other organisations.

For example, the admin may reserve:

- Display name: `Samsara Collection`
- Handle: `samsara`
- Future public URL: `https://psy.market/samsara`
- Contact channel: Instagram
- Email address: unknown

The reservation must prevent another user from registering or changing a profile to the handle `samsara`, even when the intended owner’s email address is not yet known.

After contacting Samsara Collection through Instagram, the admin should be able to generate a secure, private registration link. The recipient opens the link, supplies their own email address, verifies that email, creates their account, and receives the reserved `samsara` profile.

The admin must never need to create or know the recipient’s password.

---

## 2. Product principles

1. **A reservation must work without an email address.** Instagram or another social platform may be the only known contact channel.
2. **The handle remains protected until explicitly released.** A reservation should not expire merely because an invitation expires.
3. **The private link grants the right to start a claim.** Knowing the public handle alone must never be sufficient.
4. **Invitation links are temporary and revocable.** A leaked or outdated link can be cancelled without releasing the handle.
5. **Invitation links are one-time use.** A successfully claimed invitation cannot be reused.
6. **The recipient owns their authentication credentials.** They enter their own email and password and complete Supabase email verification.
7. **Claiming must be atomic.** The system must not create an account but fail to attach the reserved handle, or attach one handle to two accounts.
8. **Administrative actions must be auditable.** The system should record who created, sent, revoked, and completed a claim.
9. **The reserved handle takes precedence.** The claim flow must not allow the recipient to substitute a different handle during registration.

---

## 3. Terminology

### Reserved profile

A protected public identity prepared for a prospective member. It may contain a display name, handle, description, avatar, header image, social links, and contact notes before it has an owner.

### Handle

The unique URL identifier, such as `samsara` in `psy.market/samsara`.

### Claim invitation

A private, time-limited, one-time link that permits its holder to register and claim one specific reserved profile.

### Claim token

A long cryptographically random secret contained in the invitation URL. The raw token is sent to the recipient. Only a secure hash of it is stored in the database.

---

## 4. Full administrator workflow

### Stage 1: Reserve the identity

In the future admin section, the admin selects **Create reserved profile** and enters:

- Display name, for example `Samsara Collection`
- Reserved handle, for example `samsara`
- Profile type, for example `shop`, `creator`, `artist`, `label`, or the closest supported Psy profile type
- Known public information, if available
- Contact method, for example Instagram
- Contact username or URL, if known
- Internal notes
- Optional avatar, header image, bio, location, and social links

An email address is not required.

After saving:

- `samsara` becomes unavailable in normal registration and profile editing.
- The reservation has status `reserved`.
- The profile has no owning Psy user yet.
- The reservation itself does not automatically expire.

### Stage 2: Contact the prospective owner

The admin contacts Samsara Collection outside Psy.market, for example through Instagram, and introduces the project.

No database ownership change occurs merely because contact was attempted. The admin may record:

- Date contacted
- Contact channel
- Contact account
- Outcome or notes

### Stage 3: Generate a private invitation

If the organisation is interested, the admin opens the reserved profile and selects **Generate claim link**.

The system:

1. Creates a cryptographically random token.
2. Stores only the token hash in the database.
3. Associates the invitation with the reserved profile.
4. Sets an expiration date, recommended default: 14 days.
5. Marks the invitation as active.
6. Shows the private link to the admin once, for example:

   `https://psy.market/claim/<random-secret-token>`

The admin copies the link and sends it through the existing trusted conversation with the organisation.

Generating an invitation changes the reservation status to `invited`, but the handle remains reserved independently of the invitation.

### Stage 4: Recipient opens the invitation

The claim page validates the token on the server.

For a valid invitation, it displays:

- The organisation or profile name
- The reserved handle and public URL
- A clear statement such as: `You have been invited to claim psy.market/samsara.`
- Registration or sign-in controls
- The invitation expiration date

The page must not expose the raw token in logs, analytics, error reports, or client-side telemetry.

If the link is invalid, expired, revoked, or already used, the page must not reveal private reservation details. It should show a neutral message and direct the recipient to contact Psy.market.

### Stage 5: Recipient registers or signs in

#### New user

The recipient enters their own email address and password, accepts the required terms, and completes Supabase email verification.

The recipient does not choose a handle in this flow. The reserved handle is already fixed.

#### Existing Psy.market user

If policy allows an existing user to claim a reserved profile, they sign in first. Because V1 currently intends one profile per user, the system must stop the claim if that account already owns a profile. Supporting multiple profiles per user is a separate V2 decision and must not be introduced accidentally through this feature.

### Stage 6: Complete the claim

After successful authentication and verified email, the server completes the claim in one database transaction:

1. Lock and re-check the invitation.
2. Confirm it is active, unused, unrevoked, and unexpired.
3. Lock and re-check the reservation.
4. Confirm the reserved handle is still available and the reservation is not already claimed.
5. Confirm the authenticated user is eligible to own a profile under current V1 rules.
6. Create or attach the profile to the authenticated user.
7. Assign the exact reserved handle.
8. Mark the reservation as `claimed`.
9. Mark the invitation as used.
10. Record the claiming user and completion time.
11. Commit all changes together.

If any check fails, the whole transaction must roll back.

### Stage 7: After claiming

The recipient is redirected to an onboarding or profile-editing page where they can complete approved fields such as:

- Avatar and header image
- Bio
- Location
- Social links
- Shop or creator information

The reserved handle should not become freely editable immediately. Handle-change policy should be defined separately and should preserve protected-name safeguards.

The admin section shows the reservation as `claimed`, including the owner and claim date.

---

## 5. Recommended statuses

### Reservation status

| Status | Meaning |
|---|---|
| `reserved` | Handle protected; no active invitation exists |
| `contacted` | Admin has contacted the intended owner |
| `invited` | At least one active claim invitation exists |
| `claim_started` | Optional status indicating registration/verification has begun |
| `claimed` | Reserved profile is attached to a verified Psy user |
| `released` | Admin intentionally removed protection from the handle |
| `cancelled` | Reservation was administratively cancelled but retained for audit history |

A minimal V1 implementation may use only `reserved`, `invited`, `claimed`, and `released`.

### Invitation status

Invitation state can be derived from timestamps, but the UI should present:

| Status | Meaning |
|---|---|
| Active | Valid, unexpired, unrevoked, and unused |
| Expired | Expiration time has passed |
| Revoked | Admin cancelled the invitation |
| Used | Claim completed successfully |

---

## 6. Current database situation

The captured Psy database currently contains `public.reserved_handles` with approximately these fields:

- `id`
- `handle`
- `email`
- `reserved_at`
- `expires_at`
- `consumed`
- `consumed_at`

Current limitations:

1. `email` is required, so an unknown-email reservation cannot be created.
2. Reservations expire after 90 days by default.
3. The current signup trigger finds a reservation by matching the new Auth user’s email.
4. There is no secure invitation token.
5. There is no separate invitation lifecycle or revocation mechanism.
6. There is no claim route or admin claim-management interface.
7. The existing trigger can prefer signup metadata over the reserved handle, which is unsuitable for a private claim link.
8. The reservation record does not represent a rich pre-created profile or contact history.
9. Handle enforcement must explicitly check active reserved handles; a unique constraint inside `reserved_handles` alone does not prevent the same handle from being inserted into `profiles`.

The captured database audit showed zero rows in `reserved_handles` at the time of capture, but live state must be rechecked before designing or applying any migration.

---

## 7. Required database changes

No SQL in this document should be applied directly to production. The final migration needs a fresh live preflight, rollback plan, and staging verification.

### 7.1 Change or replace `reserved_handles`

The reservation must support an unknown email and must not expire by default.

Recommended reservation fields:

| Field | Type | Purpose |
|---|---|---|
| `id` | `uuid` | Primary key |
| `handle` | `text` | Protected handle |
| `display_name` | `text` | Intended public name |
| `profile_type` | Existing enum or `text` | Intended profile category |
| `status` | Enum or constrained `text` | Reservation lifecycle |
| `email` | Nullable `text` | Optional known contact/claim email; not required for reservation |
| `contact_channel` | Nullable `text` | Instagram, email, website, personal contact, etc. |
| `contact_value` | Nullable `text` | Instagram username, URL, or other contact reference |
| `contact_notes` | Nullable `text` | Private admin notes |
| `profile_data` | `jsonb` | Optional prefilled public fields until profile creation |
| `created_by` | `uuid` | Admin who created the reservation |
| `created_at` | `timestamptz` | Creation time |
| `updated_at` | `timestamptz` | Last update time |
| `contacted_at` | Nullable `timestamptz` | When outreach occurred |
| `claimed_by` | Nullable `uuid` | Auth user that completed the claim |
| `claimed_profile_id` | Nullable `uuid` | Resulting profile |
| `claimed_at` | Nullable `timestamptz` | Claim completion time |
| `released_at` | Nullable `timestamptz` | Time handle protection was deliberately released |

Design choice: the current table can be migrated in place, or a clearer `reserved_profiles` table can replace it. `reserved_profiles` is recommended because the feature represents more than a handle-to-email mapping.

### 7.2 Add `profile_claim_invitations`

Recommended fields:

| Field | Type | Purpose |
|---|---|---|
| `id` | `uuid` | Primary key |
| `reserved_profile_id` | `uuid` | Reservation being claimed |
| `token_hash` | `text` | Hash of the secret token; raw token is never stored |
| `created_by` | `uuid` | Admin who generated it |
| `created_at` | `timestamptz` | Generation time |
| `expires_at` | `timestamptz` | Link expiration |
| `revoked_at` | Nullable `timestamptz` | Administrative cancellation |
| `used_at` | Nullable `timestamptz` | Successful completion |
| `claimed_by` | Nullable `uuid` | User who used it |
| `last_opened_at` | Nullable `timestamptz` | Optional operational visibility |
| `open_count` | Integer | Optional abuse/diagnostic signal |

Only one active invitation per reservation is recommended for V1. Generating a replacement should revoke the previous active invitation.

### 7.3 Enforce handle protection in the database

The database must reject a normal profile insert or handle update when the requested handle belongs to an active reservation.

The existing profile-handle enforcement function should check both:

- System route names in `blocked_handles`
- Active business/profile reservations in `reserved_profiles` or `reserved_handles`

The claim transaction requires a tightly scoped exception allowing the specific reserved handle to be assigned to the authenticated claimant associated with a valid invitation. This exception must live in trusted server/database logic; clients must not be able to set a flag such as `bypass_reserved=true`.

Case-insensitive uniqueness must remain enforced across profiles and reservations. Handles should be normalized to lowercase and validated against the current `3–30 lowercase letters, numbers, or underscores` rule.

### 7.4 Add an atomic claim function

Create a security-definer database function or equivalent trusted server transaction, for example conceptually:

`claim_reserved_profile(invitation_token_hash, authenticated_user_id)`

It must:

- Derive the user from the authenticated session where possible rather than trusting a submitted user ID
- Lock the invitation and reservation rows
- Validate invitation state and expiry
- Validate email verification
- Enforce one profile per user for V1
- Assign the reserved handle
- Copy approved prefilled profile data
- Mark invitation and reservation as completed
- Return the claimed profile ID/handle
- Roll back on any failure

Function execution must be revoked from anonymous users unless the implementation has a carefully authenticated intermediate step. It must use a fixed `search_path` and explicit table references.

### 7.5 Add audit records

Recommended audit events include:

- Reservation created or edited
- Contact recorded
- Invitation generated
- Invitation revoked or replaced
- Invitation opened, if tracked
- Claim completed
- Reservation released or cancelled

Audit records should identify the admin or authenticated user, event type, reservation, timestamp, and safe metadata. Raw claim tokens and passwords must never be logged.

### 7.6 RLS and permissions

- Normal users and anonymous visitors must not be able to list reservations, emails, contact notes, token hashes, or invitations.
- The admin interface may access reservation management only through confirmed admin authorization.
- Public handle-availability checks should return only availability, not the existence or identity of a private reservation.
- Claim-token validation should return only the minimum safe information required by the claim page.
- Service-role credentials must remain server-side.

---

## 8. Application changes

### Admin section

Add a reserved-profile area with:

- List/search/filter reservations
- Create and edit reservation
- Validate handle format and availability
- Record outreach channel and notes
- Generate claim link
- Copy claim link
- Revoke and regenerate claim link
- See expiration and claim status
- Release a reservation with explicit confirmation
- View audit history

Suggested routes:

- `/admin/reserved-profiles`
- `/admin/reserved-profiles/new`
- `/admin/reserved-profiles/[id]`

### Public claim flow

Suggested route:

- `/claim/[token]`

Required states:

- Valid invitation
- Invalid invitation
- Expired invitation
- Revoked invitation
- Already-used invitation
- Registration awaiting email verification
- Signed-in but ineligible account
- Successful claim

### Authentication integration

The claim context must survive Supabase email verification and the Auth callback without relying only on browser memory. Recommended options are a secure, short-lived, HTTP-only claim session or a server-side pending-claim record tied to the invitation and Auth flow.

Do not put a reusable raw claim token into user metadata, permanent URLs after completion, analytics events, or local storage.

### Normal signup and profile editing

- Reserved handles must appear unavailable.
- The API/database must enforce this even if the client validation is bypassed.
- Normal signup must not consume a token-based reservation by guessing an email or handle.
- The private claim flow must assign the reserved handle regardless of ordinary signup handle input.

---

## 9. Security and abuse safeguards

1. Generate at least 32 random bytes for each claim token.
2. Store only a SHA-256 or stronger keyed/secure hash of the token.
3. Compare token hashes safely on the server.
4. Use HTTPS only.
5. Make invitations short-lived and one-time use.
6. Allow immediate admin revocation and replacement.
7. Rate-limit token validation and registration attempts.
8. Do not reveal whether arbitrary handles or organisations have invitations.
9. Do not include raw tokens in application logs or analytics.
10. Require verified email before final ownership transfer.
11. Re-check all conditions inside the final transaction to prevent race conditions.
12. Prevent the same user from claiming multiple profiles while V1 enforces one profile per user.
13. Require explicit confirmation before releasing a reserved handle.
14. Consider an optional admin-review step for sensitive or high-value identities.

### Forwarded-link risk

A person receiving the Instagram message could forward the private link. Possession of the token therefore proves possession of the invitation, not necessarily legal ownership of the brand.

For V1, this may be acceptable when the link is sent through an already verified official social account. For high-value profiles, the admin may require a final manual approval or additional proof before activating ownership.

---

## 10. Edge cases

### Invitation expires

The invitation stops working, but the handle remains reserved. The admin generates a replacement link.

### Invitation is leaked

The admin revokes it. The handle remains reserved. A new link can be generated.

### Recipient enters the wrong email

Before final claim, allow them to restart with the correct email. After a completed claim, correction becomes an account-support process and must not silently transfer ownership.

### Recipient already has a Psy profile

Under the V1 one-profile-per-user decision, the claim must stop and instruct them to contact the admin or use a different eligible account. Multi-profile support is out of scope.

### Two people open the same link

Both may see the initial claim screen, but only the first eligible, verified completion can succeed. Row locking and one-time consumption must reject the second attempt.

### Handle conflicts with a current profile

Reservation creation must fail. The admin must investigate rather than overwrite or transfer an existing profile automatically.

### Admin releases a handle

Release should require explicit confirmation and an audit entry. It should be prohibited after a completed claim unless a separate ownership/support procedure is followed.

### Organisation declines

The admin may retain the reservation, cancel it, or deliberately release it according to product policy. Cancelling an invitation must not automatically release the handle.

---

## 11. Suggested implementation phases

### Phase 1: Database foundation

- Recheck live schema and reservation data
- Finalize reservation statuses and profile types
- Make email optional or create `reserved_profiles`
- Remove automatic reservation expiry
- Add invitation table
- Add database-level reserved-handle enforcement
- Add atomic claim function
- Add RLS, grants, audit events, rollback SQL, and database tests

### Phase 2: Admin reservation management

- Reservation list and detail screens
- Create/edit reservation
- Outreach notes
- Generate, copy, revoke, and replace invitation links
- Reservation and invitation status display

### Phase 3: Claim and authentication flow

- Secure `/claim/[token]` route
- Registration/sign-in integration
- Email verification continuation
- Atomic claim completion
- Success and failure states

### Phase 4: Hardening and launch verification

- Rate limiting
- Token leakage review
- Race-condition tests
- RLS and privilege tests
- Existing-user and one-profile-per-user tests
- Full staging walkthrough
- Admin audit verification
- Documentation and support procedure

---

## 12. Acceptance criteria

The feature is complete only when all of the following are true:

- [ ] Admin can reserve `samsara` without entering an email address.
- [ ] Normal signup and profile editing cannot take `samsara`.
- [ ] The reservation does not expire automatically.
- [ ] Admin can generate a private, expiring, one-time claim link.
- [ ] Admin can revoke and replace the link without releasing the handle.
- [ ] Recipient can enter their own email and password.
- [ ] Recipient must verify their email before ownership is finalized.
- [ ] Recipient cannot replace `samsara` with another handle during the claim.
- [ ] Successful claim connects exactly one eligible user to the reserved profile.
- [ ] Invitation and reservation updates happen atomically.
- [ ] Reusing, guessing, forwarding after use, or racing the same token cannot produce a second owner.
- [ ] Normal users cannot read reservation contact details, invitation hashes, or admin notes.
- [ ] Admin actions and successful claims are auditable.
- [ ] Existing normal signup continues to work.
- [ ] Staging verification covers valid, expired, revoked, used, and concurrent-link scenarios.

---

## 13. Explicit non-goals for the first version

- Automatic proof that the claimant legally owns a brand
- Multiple profiles per Psy user
- Public self-service requests for arbitrary reserved names
- Buying or selling reserved handles
- Permanent reusable invitation links
- Admin-created passwords
- Automatic transfer of an already claimed profile

---

## 14. Final recommended user experience

1. Turgay reserves `samsara` in the admin section without an email.
2. Psy.market protects `psy.market/samsara` indefinitely.
3. Turgay contacts Samsara Collection through their official Instagram account.
4. If they agree, Turgay generates a private 14-day claim link.
5. Samsara opens the link and sees the exact profile they were invited to claim.
6. They create their own account and verify their email.
7. Psy.market atomically connects their account to `psy.market/samsara`.
8. The link becomes unusable, the reservation becomes claimed, and Samsara completes its profile.

This approach supports pre-launch handle protection without requiring email addresses and provides a controlled onboarding path for organisations contacted through Instagram or other social channels.
