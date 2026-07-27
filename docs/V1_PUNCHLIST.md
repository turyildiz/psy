# psy.market V1 Punch List

> Updated 2026-07-27 from the frozen scope in [`V1_DECISIONS.md`](./V1_DECISIONS.md), the accepted read-only reconciliation, and the owner-approved Step 11 architecture decision. Do not implement items from superseded PRD or SPEC sections where they conflict with the frozen decisions.

## Ordered launch punch list

1. **Version and secure the Supabase data layer — L**  
   Capture the live schema as migrations; define constraints, triggers, RPCs, Realtime publication, and RLS for profiles, listings, conversations/messages, events, RSVPs, notice posts/reactions, user roles, bans, and per-user conversation hiding.
   - Database Chunks 0–7 are live and were read-only reconfirmed on 2026-07-26. Chunk 10 was owner-applied, independently verified read-only, and functionally smoke-tested through authenticated RLS on 2026-07-27. Chunks 8–9 remain separately review- and approval-gated.
   - Chunk 10 hardened `increment_view_count` and `update_conversation_last_message` with empty fixed search paths, schema-qualified references, explicit `PUBLIC`/`anon`/`authenticated` revocation, and reviewed `service_role` grants. See `CHUNK_10_SECURITY_DEFINER_HARDENING_VERIFICATION.md` and `CHUNK_10_SECURITY_DEFINER_HARDENING_SMOKE.md`.

2. **Fix authentication and route safety — M**  
   Restrict redirects to same-origin relative paths, remove token/hash logging, add password reset, verify production callback allowlists, and enforce one shared `blocked_handles` list covering every existing and planned handle-compatible top-level route at signup and profile-handle changes.
   - Recovery flow is deployed but remains inactive until Supabase dashboard activation: exact recovery redirects, fragment-based `token_hash` template, and All-Inkl Custom SMTP credentials. Real-mail, SPF/DKIM/DMARC, expired/reused-link, and global-session-revocation tests remain launch gates. See `ITEM_2_AUTH_SMTP_DNS_OWNER_CHECKLIST.md` and `PRE_LAUNCH_TEST_LIST.md`.

3. **Standardize and secure Cloudflare R2 uploads — M**
   Migrate every legacy Supabase Storage avatar/listing path to R2, enforce server-side MIME/type/size/count limits, verify ownership, and define orphan cleanup and object deletion behavior.
   - Profile-media migration Steps 8–10 are complete: three approved objects were copied and verified in R2, and exactly three URL fields across two profile rows were switched and accepted. See `R2_MIGRATION_STEP_10_EXECUTION_RECORD.md`.
   - The prior Step 11 Gate A completion is recorded, but its original execution record was not recovered. Re-run Gate A from the recovered methodology during final pre-launch verification and version the new evidence.
   - The narrow Gate B server-side image-count prototype was rejected and is not present in the application or live database.
   - **Owner decision — 2026-07-27:** the durable direct-publish upload-operation/reservation architecture is the approved target architecture, deliberately deferred until after launch. No Step 11 implementation or SQL preparation is authorized without a separate post-launch approval.
   - **Accepted V1 limitation:** listing images can be promoted before the final listing INSERT/UPDATE commits. V1 retains the existing mitigations—database five-image constraint, process-local presign rate limiting, and report-only public-orphan tracking. This accepted race is not a launch blocker and does not authorize public-object deletion.
   - Original Supabase objects remain verified rollback sources. Source deletion, Supabase Storage retirement, destructive Chunk 9 work, and the deferred Yacxilan object remain separately approval-gated.
   - Current demo profiles and listings must remain available during development. Any pre-launch demo-data purge requires a separate exact reviewed scope and must retain the `@turgay` profile.

4. **Harden the direct-publish listing flow — M**  
   Keep immediate `active` publication, add shared server-side validation and ownership checks, remove dead draft/review controls, add owner unpublish/mark-sold management, and ensure failed uploads cannot create invalid listings.
   - Keep this V1 work within the accepted current upload lifecycle. Do not pull the deferred Step 11 ledger/reservation architecture into pre-launch scope.

5. **Add tickets as a normal listing category — M**  
   Extend schema/types/forms/search to support tickets, display the face-value guideline and ticket-specific safety messaging, and remove the hard-coded homepage ticket section. Do not add verification or affiliate links.

6. **Build minimal reactive moderation — L**  
   Implement exactly one `super_admin` plus appointed admins; both can unpublish listings, ban/unban users, and delete notice-wall posts, while only the super_admin can appoint/remove admins. Enforce bans in auth and write paths. The moderation UI must synchronize account bans with Supabase Auth: Ban sets Auth `banned_until`, Unban clears it, and rejected login attempts display a clear banned-account message. No approval queue or analytics dashboard.

7. **Finish database-backed browse and discovery — M**  
   Implement title search, category and price filters, stable pagination, URL-backed state, and clear empty/error states across normal listings including tickets. Remove or defer controls not supported by the frozen lean scope.

8. **Repair V1 messaging and soft-delete semantics — M**  
   Fix contact-to-thread navigation, unread state, text-message validation, and Realtime behavior. Replace shared-row deletion with per-user hidden state. Defer message images, automatic link rendering, and full read receipts to V1.1.

9. **Implement the single V1 application-email flow — M**
   Send only new-message notifications through server-side All-Inkl SMTP, default enabled, with an opt-out toggle in settings. Use `no-reply@psy.market` as the binding sender identity unless Turgay separately changes it; keep credentials in environment-scoped Vercel server secrets. Verify sender-domain authentication, delivery failure handling, and links to the correct conversation. Do not add approval, marketing, or other notification emails.

10. **Complete and seed the festival layer — M**  
    Verify calendar, detail pages, RSVPs, notice posting/reactions, permissions, and moderation end-to-end; seed the current festival season before launch.

11. **Add account settings and safe deletion — M**  
    Provide the new-message email opt-out, password management links, and self-service account deletion with defined treatment of marketplace and festival/community records.

12. **Add legal and safety pages — M**  
    Implement Impressum, Datenschutzerklärung, AGB, and safety-tips routes; include marketplace and ticket-specific safety guidance; centralize operator name/address/contact as a config placeholder and block launch until real details are supplied.

13. **Complete launch SEO, navigation, and dead-UI repair — M**
    Repair dead links, add production `metadataBase`, canonical URLs, dynamic listing/profile/festival metadata, Open Graph data, robots policy, and sitemap; ensure `psy.market` is used consistently. Remove or wire up dead UI controls before launch; specifically, the **Save Draft** buttons in `components/NewListingModal.tsx` and `app/listings/new/page.tsx` are currently `type="button"` with no `onClick` handler and do nothing.

14. **Prepare Vercel Pro production operations — M**  
    Configure environment variables and secret separation, Vercel build/deploy settings, error monitoring, health checks, runtime pinning, lint/tests, R2 CORS/public domain, Supabase production URLs, and operational logging. The VPS remains staging only until retired.

15. **Production-domain cutover and launch verification — M**  
    Deploy on Vercel Pro, point `psy.market`, verify TLS and Supabase redirects, complete browser/auth/upload/listing/search/messaging/email/moderation/festival/legal/SEO/mobile smoke tests, then retire the VPS staging-service path.
    - Before cutover, re-run state-free Step 11 Gate A exactly from `recovered-step11/approval-gated-database-object-storage-migrations.md`; capture and version canonical before/after hashes, test totals, rejection-probe results, static public-deletion-path proof, and final private/public inventories.

## Obsolete items from the previous punch list

- **Freeze V1 decisions and reconcile the PRD** — completed by `V1_DECISIONS.md`; no longer an implementation task.
- **Implement draft/pending/rejected/resubmission lifecycle** — obsolete; V1 is direct-publish with immediate `active` status.
- **Build an approval queue and 24-hour auto-approval** — explicitly out of V1.
- **Build an admin analytics dashboard** — explicitly out of V1; moderation is reactive and narrowly scoped.
- **Add message images, automatic link rendering, and full read receipts before launch** — deferred to V1.1.
- **Add payment or checkout integration** — explicitly out of V1; transactions remain off-platform.
- **Harden the VPS as the production deployment** — obsolete; production is Vercel Pro and the VPS staging service will be retired.
- **Treat the festival layer as optional or outside the marketplace V1** — obsolete; it is now binding V1 scope.
- **Treat hard conversation deletion as acceptable** — obsolete; V1 requires per-user soft-delete/hiding with shared rows retained.
- **Treat tickets as a hard-coded homepage feature** — obsolete; tickets are a standard listing category.
