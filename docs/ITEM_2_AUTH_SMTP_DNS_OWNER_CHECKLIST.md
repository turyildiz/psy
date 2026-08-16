# Item 2 — Owner-Apply Auth, All-Inkl SMTP, and Mail-DNS Checklist

> **Status:** owner action required. The application closeout commit does not change Supabase dashboard settings, All-Inkl, Cloudflare DNS, or Vercel DNS.
>
> **Secret handling:** never paste the SMTP password into this repository, Telegram, screenshots, logs, or client-side environment variables.

## A. Supabase Auth URL configuration

Open **Supabase Dashboard → Authentication → URL Configuration**.

- [ ] Set **Site URL** exactly to:

```text
https://psy.market
```

- [ ] Replace or reconcile the **Redirect URLs** list so it contains these exact reviewed application destinations:

```text
https://psy.market/auth/callback
https://psy.market/auth/recovery
https://www.psy.market/auth/callback
https://www.psy.market/auth/recovery
https://psy.heyturgay.com/auth/callback
https://psy.heyturgay.com/auth/recovery
```

The `/auth/callback` entries are for signup confirmation and any reviewed OAuth flow. The `/auth/recovery` entries are only for scanner-resistant password recovery. The `www` entries match the application's already-approved production alias and prevent Supabase from silently falling back to Site URL if an auth flow starts there.

- [ ] Do not use a broad wildcard for recovery.
- [ ] Save and reopen the page to confirm the values persisted.

## B. Supabase recovery email template

Open **Supabase Dashboard → Authentication → Email Templates → Reset password** and replace the complete body with:

```html
<h2>Reset your Psy.market password</h2>

<p>We received a request to reset the password for your Psy.market account.</p>

<p>
  <a href="{{ .RedirectTo }}#token_hash={{ .TokenHash }}&type=recovery">
    Reset password
  </a>
</p>

<p>This link can be used once. If you did not request a password reset, you can ignore this email.</p>
```

Critical exact link:

```html
{{ .RedirectTo }}#token_hash={{ .TokenHash }}&type=recovery
```

- [ ] Confirm there is **no stray `m`** before `{{ .RedirectTo }}`.
- [ ] Confirm `token_hash` is after `#`, not `?`.
- [ ] Confirm `type=recovery` is present.
- [ ] Save and reopen the template to confirm the final stored body.

## C. Create or confirm a dedicated All-Inkl sender mailbox

In **All-Inkl KAS → Email → Email Account**:

- [ ] Create or confirm the dedicated mailbox `no-reply@psy.market`.
- [ ] Save the mailbox’s exact SMTP login/username and password only in an approved owner-only password manager or secret store. The username may differ from the email address.
- [ ] Set a strong unique SMTP password.
- [ ] Confirm the secure outgoing server listed by KAS. All-Inkl documents the secure server pattern as `<your-KAS-login>.kasserver.com`; live DNS currently points psy.market mail to `w0189c69.kasserver.com`.

Only Turgay can supply or confirm:

- the exact KAS SMTP username;
- the SMTP password;
- whether `no-reply@psy.market` already exists or must be created;
- the final server value shown in KAS if it differs from the DNS-observed host.

## D. Supabase Custom SMTP

Open **Supabase Dashboard → Authentication → SMTP Settings / Custom SMTP**.

| Supabase field | Value | Who can supply/confirm |
|---|---|---|
| Enable Custom SMTP | On | Turgay |
| Sender name | `Psy.market` | Pre-approved |
| Sender email / From address | `no-reply@psy.market` | Turgay must create/confirm mailbox |
| Host | Copy the exact outgoing server from KAS → Email → Email Account | **Turgay / All-Inkl only**; `w0189c69.kasserver.com` is only the DNS-observed MX candidate, not verified submission configuration |
| Port | `465` | Recommended secure submission port |
| TLS mode | Implicit SSL/TLS from connection start | Supabase currently has no separate TLS-mode field; port 465 selects this behavior |
| Username | Exact SMTP login shown in KAS | **Turgay / All-Inkl only** |
| Password | Mailbox SMTP password | **Turgay / All-Inkl only; secret** |

Do not substitute port 587 without written All-Inkl confirmation and a controlled transport test. Current All-Inkl guidance specifies port 465 with SSL/TLS. Supabase does not expose a separate TLS-mode field; its mailer selects implicit TLS for port 465. Do not use plaintext SMTP or port 25 for application submission.

After saving:

- [ ] Reopen the dashboard and confirm Custom SMTP remains enabled.
- [ ] Review **Authentication → Rate Limits**. Supabase documents an initial custom-SMTP limit of 30 messages/hour; set an intentional launch limit rather than assuming the default is sufficient.
- [ ] Do not disable email confirmation to work around delivery problems.
- [ ] Send controlled signup and recovery messages to external inboxes only during the approved manual test.
- [ ] Inspect delivered-message headers for SPF, DKIM, and DMARC results.

Supabase Custom SMTP covers Supabase Auth mail such as signup confirmations and password recovery. The future V1 “new message” notification is application mail, not an Auth template; its server-side sender must separately use All-Inkl SMTP from server-only, environment-scoped Vercel secrets. Whether it reuses the Auth mailbox credential or uses a separately rotatable mailbox must be an explicit blast-radius decision. Those credentials must never be exposed to browser code.

## E. Current read-only DNS snapshot — updated 2026-08-16

Authoritative DNS is currently Cloudflare:

```text
NS  miguel.ns.cloudflare.com
NS  oaklyn.ns.cloudflare.com
```

Observed mail records:

```text
@  MX  10 w0189c69.kasserver.com.
@  TXT "v=spf1 a mx include:spf.kasserver.com ~all"
_dmarc  TXT "v=DMARC1; p=none;"
```

All-Inkl support confirmed on 2026-08-16 that its servers sign outgoing mail and that the domain key is published in the KAS DNS zone view. The current selector is `kas202604191039`, issued 2026-04-19 with 180-day validity. The matching `kas202604191039._domainkey` TXT record was published in Cloudflare on 2026-08-16 from a byte-verified copy and confirmed resolving through both `1.1.1.1` and `8.8.8.8`.

`mail.psy.market` currently resolves to Cloudflare anycast web addresses. Do **not** enter `mail.psy.market` as the SMTP host or proxy SMTP through Cloudflare; use the KAS-provided `*.kasserver.com` host.

## F. Mail-authentication records required for deliverability

### SPF

Current SPF already authorizes the observed All-Inkl mail path:

```text
v=spf1 a mx include:spf.kasserver.com ~all
```

- [ ] Keep exactly one SPF record at the zone apex.
- [ ] Confirm a real All-Inkl-sent message returns `spf=pass` and aligns with the visible `From: ...@psy.market` domain.
- [ ] Do not add a second SPF TXT record during the Vercel cutover.
- [ ] Inventory whether the current `a` mechanism is actually needed. A Vercel apex cutover changes which IP addresses `a` authorizes; preserve the record during cutover to avoid an outage, then remove unnecessary authorization only after real All-Inkl header testing.
- [ ] Tightening `~all` to `-all` should happen only after every legitimate sender is inventoried and verified.

### DKIM

**DKIM state recorded 2026-08-16:** All-Inkl support confirmed that its servers sign outgoing mail and that the domain key is available in KAS. Selector `kas202604191039` was issued on 2026-04-19 with 180-day validity. Its `kas202604191039._domainkey` TXT record is published at Cloudflare from a byte-verified KAS copy and resolves through `1.1.1.1` and `8.8.8.8`.

The key rotates approximately 2026-10-16 and every 180 days after that. This is a manual maintenance duty: each replacement selector/key must be copied from KAS to Cloudflare and byte-verified, or DKIM verification will begin failing.

**OPEN:** The Supabase-to-KAS authenticated SMTP submission path is not yet proven to receive an All-Inkl DKIM signature. Keep this item open until a live delivered-message header shows a `DKIM-Signature` and `dkim=pass` for the path actually used by signup and recovery mail.

- [x] Confirm All-Inkl outgoing signing and obtain the current selector/key from KAS.
- [x] Publish the exact supplied `kas202604191039._domainkey` TXT record in Cloudflare and verify it through `1.1.1.1` and `8.8.8.8`.
- [ ] Run a live Supabase-to-KAS header test and require `DKIM-Signature` with `dkim=pass`.
- [ ] Around 2026-10-16, and every 180 days thereafter, copy the rotated selector/key from KAS to Cloudflare and byte-verify it.

DMARC remains at `p=none` until the signed Supabase-to-KAS flow is proven; hardening follows only after that proof. If the live submission path does not sign, the fallback is **Cloudflare Email Service**, its sending product currently in public beta with auto-managed keys. This is distinct from Cloudflare's inbound-only Email Routing product.

### DMARC

The current monitoring policy is syntactically valid but minimal:

```text
v=DMARC1; p=none;
```

Before changing it, create/confirm a mailbox or alias for aggregate reports, for example `dmarc@psy.market`. A recommended monitoring record is:

```text
v=DMARC1; p=none; rua=mailto:dmarc@psy.market; adkim=s; aspf=s; pct=100
```

- [ ] Turgay creates/confirms `dmarc@psy.market` before adding `rua`.
- [ ] Start with `p=none` while signup/recovery delivery is tested.
- [ ] Confirm SPF and preferably DKIM pass with strict alignment.
- [ ] Move later to `p=quarantine`, then `p=reject`, only after reports show all legitimate senders aligned.

No DNS policy can guarantee inbox placement. Mailbox reputation, complaint rates, content, volume, reverse DNS of All-Inkl infrastructure, and recipient filtering also matter.

## G. Planned Vercel DNS cutover — conflict rules

There is no inherent conflict between Vercel web hosting and All-Inkl mail if the mail records are preserved.

### If Cloudflare remains authoritative

- Change only the web-facing apex/`www` records required by Vercel.
- Preserve the MX, SPF, DKIM, and DMARC records exactly.
- Keep mail-related records DNS-only; never proxy SMTP through Cloudflare.

### If nameservers move to Vercel DNS

Before changing nameservers:

- [ ] Attach and verify the production domain in Vercel before changing delegation.
- [ ] Copy and compare the entire Cloudflare DNS zone, not only mail records.
- [ ] Pre-create the All-Inkl MX record in Vercel DNS.
- [ ] Copy the one apex SPF TXT record exactly.
- [ ] If All-Inkl provides DKIM signing, copy the verified DKIM selector TXT record exactly; otherwise record the explicitly accepted SPF-only decision.
- [ ] Copy the DMARC TXT record exactly.
- [ ] Copy any mail-autoconfiguration or verification records still required.
- [ ] Recheck the registrar for DS/DNSSEC immediately before changing nameservers; a stale DS record can cause `SERVFAIL`.
- [ ] Lower TTLs in advance where practical.
- [ ] Query the future authoritative nameservers directly and compare every mail record before delegation changes.
- [ ] Preserve the Cloudflare zone until delegation and resolver caches have fully propagated. Lower TTLs help record changes but do not eliminate parent NS/delegation caching.
- [ ] After cutover, verify apex, `www`, TLS, MX/TXT, and send/receive behavior from multiple resolvers before declaring DNS complete.

Changing the apex A/CNAME for Vercel does not replace MX records. Changing authoritative nameservers without copying the mail records will break or degrade All-Inkl delivery.

## H. Final acceptance gate

- [ ] Site URL and all six exact callback/recovery allowlist entries saved.
- [ ] Correct fragment-based template saved without the stray `m`.
- [ ] Custom SMTP enabled with All-Inkl credentials.
- [ ] Signup confirmation arrives at an external inbox.
- [ ] Recovery email arrives at an external inbox.
- [ ] SPF passes and aligns.
- [ ] The Supabase-to-KAS live header test shows `DKIM-Signature` and `dkim=pass` for selector `kas202604191039` (or its current 180-day replacement); otherwise use the approved fallback decision.
- [ ] DMARC passes in delivered headers.
- [ ] Same-browser and cross-browser recovery work.
- [ ] Expired and reused recovery links fail safely.
- [ ] The accepted V1 response-loss case does not claim success; the user can check the new password, and a newly requested reset link restores the flow if needed.
- [ ] Successful recovery revokes every other Supabase session before changing the password and prevents every pre-existing browser/device from refreshing its session.
- [ ] Record the configured JWT lifetime and confirm pre-existing access tokens stop working no later than their `exp` time.

Supabase documents an important platform limit: revoking sessions destroys the affected refresh tokens, but already-issued access JWTs remain valid until their encoded expiry. If “immediate” means zero remaining JWT-validity window, that requires a separate server-side revocation/session-version design or a deliberately shorter JWT lifetime; Custom SMTP and refresh-token revocation cannot provide that by themselves.

- [ ] Evidence is added to `docs/PRE_LAUNCH_TEST_LIST.md`.

## References

- Supabase Custom SMTP: <https://supabase.com/docs/guides/auth/auth-smtp>
- Supabase session sign-out scopes and access-token expiry behavior: <https://supabase.com/docs/guides/auth/signout>
- All-Inkl secure mail-server naming: <https://all-inkl.com/en/support/tutorials/software/email/updating-an-ssl-certificate-email-settings/email-settings-for-a-secure-connection-via-ssltlsstarttls_384.html>
- All-Inkl mailbox setup and port 465 with SSL/TLS: <https://all-inkl.com/en/support/tutorials/kas/email/email-address-autoresponder-forwarding/how-to-create-an-email-account_98.html>
- All-Inkl DKIM DNS format: <https://all-inkl.com/en/support/tutorials/kas/tools/dns-tools/how-to-add-a-dkim-record-in-case-of-using-an-external-email-server_444.html>
