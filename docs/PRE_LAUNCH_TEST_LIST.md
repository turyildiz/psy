# psy.market Pre-Launch Manual Browser Test List

> Standing launch-gate checklist. Add manual browser-verification work as it is discovered.
> Do not remove an item without Turgay's explicit approval. Mark an item complete only with dated evidence and the tested environment/account recorded.

## Status legend

- [ ] Pending
- [x] Completed with evidence recorded in this file

## 1. Real password-reset email flow end to end

**Dependencies:** Supabase recovery redirect allowlist and recovery email template activated for the launch environment.

- [ ] Confirm the Supabase recovery email template sends the reviewed `token_hash` callback URL and does not expose or log tokens in application output.
- [ ] Confirm the exact staging and production callback origins are present in the Supabase redirect allowlist; confirm an unapproved external redirect is rejected or normalized safely.
- [ ] Request a password reset through the real login UI using a real test inbox.
- [ ] Confirm the recovery email arrives with correct sender identity, subject, branding, and one working recovery link.
- [ ] Open the link in a clean browser session and confirm it reaches the intended reset-password screen without redirect loops or token leakage.
- [ ] Set a new password and confirm the UI reports success.
- [ ] Confirm the old password no longer signs in and the new password does.
- [ ] Reuse the consumed recovery link and confirm it fails safely with a useful user-facing message.
- [ ] Test an expired recovery link and confirm it fails safely with a useful user-facing message.
- [ ] Confirm callback, reset, and login behavior on mobile and desktop widths.

**Evidence required:** date, environment, test account/inbox identifier without credentials, screenshots of user-visible states, callback/network status, and final old-password/new-password sign-in results.

## 2. Hands-on R2 listing upload: quarantine to promotion

**Dependencies:** staging uses the private R2 quarantine bucket and public media bucket with current upload secrets/configuration.

- [ ] Sign in as an unbanned non-owner test account and open the real listing-create UI.
- [ ] Upload a supported JPEG, PNG, or WebP through the browser.
- [ ] Confirm browser preprocessing/re-encoding occurs and the outgoing file respects the current dimensions, quality, MIME, and 10 MB listing-image rules.
- [ ] Confirm the browser obtains a private-quarantine upload intent rather than a direct public-bucket write.
- [ ] Confirm the object is uploaded to the private quarantine bucket.
- [ ] Confirm finalization validates the uploaded private object before promotion.
- [ ] Confirm successful promotion creates the intended immutable public R2 object and returns the expected `images.psy.market` URL.
- [ ] Complete direct publication and confirm the listing row stores the promoted URL and the listing renders the image on staging.
- [ ] Confirm the promoted private quarantine object is deleted only after successful promotion/reference handling.
- [ ] Exercise listing edit/replacement and confirm the final database image array and rendered order are correct.
- [ ] Confirm the five-image UI/database limit is enforced.
- [ ] Confirm unsupported MIME, oversize declaration/object, failed PUT, failed validation, and unauthorized/banned attempts show useful errors and do not create an invalid listing.
- [ ] Inspect browser network responses for accidental credentials, internal bucket details, raw server errors, or reusable write capability leakage.
- [ ] Record any promoted-but-unreferenced object through the report-only orphan process; do not delete public objects.

**Accepted V1 limitation:** promotion can succeed before the listing metadata commit. The durable reservation architecture is approved but deferred post-launch. This test verifies the current V1 mitigations and observable behavior; it does not require Step 11.

**Evidence required:** date, environment, test account, source-file MIME/bytes/dimensions, quarantine key/presence, promotion result, public object metadata/HTTP result, database reference, rendered staging URL/screenshot, private cleanup result, and failure-case results.

## 3. Banned-user login experience after moderation sets Auth `banned_until`

**Dependencies:** moderation UI action synchronizes the public ban state and Supabase Auth `banned_until`. Use an approved existing demo account; never use `@turgay`.

- [ ] Sign in successfully as the selected demo account before banning and record the baseline.
- [ ] Ban the account through the moderation UI, not by direct database manipulation.
- [ ] Confirm the public ban record and Auth `banned_until` represent the same account and intended duration.
- [ ] Observe the already-open browser session and record whether it remains readable, becomes read-only, or is signed out; confirm this matches the approved behavior.
- [ ] Attempt a prohibited write from any still-open session and confirm RLS/RPC enforcement rejects it with a useful UI message.
- [ ] Sign out, then attempt to sign in again and confirm Auth rejects the banned account.
- [ ] Confirm the login UI presents a clear, nontechnical banned-account message rather than a raw Supabase error, generic false success, or endless spinner.
- [ ] Confirm password reset or OAuth cannot be used to bypass the ban.
- [ ] Confirm a banned account cannot create listing-upload intents or leave private/public upload artifacts.
- [ ] Unban the same account through the moderation UI.
- [ ] Confirm Auth `banned_until` and public ban state are both cleared consistently.
- [ ] Confirm normal sign-in and authorized writes work again after unbanning.
- [ ] Confirm another unbanned account remains unaffected throughout the test.

**Evidence required:** date, environment, demo handle/Auth user ID, before/ban/unban state summaries without secrets, screenshots of login and write-error experiences, relevant network status/error codes, and final restored-login result.

## Execution records

Add dated execution records below. Do not replace the checklist above.

<!--
### YYYY-MM-DD — Test name

- Environment:
- Test account:
- Result: PASS / FAIL / BLOCKED
- Evidence:
- Follow-up:
-->
