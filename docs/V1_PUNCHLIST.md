# psy.market V1 Punch List

> Updated 2026-07-12 from the frozen scope in [`V1_DECISIONS.md`](./V1_DECISIONS.md). Do not implement items from superseded PRD or SPEC sections where they conflict with the frozen decisions.

## Ordered launch punch list

1. **Version and secure the Supabase data layer — L**  
   Capture the live schema as migrations; define constraints, triggers, RPCs, Realtime publication, and RLS for profiles, listings, conversations/messages, events, RSVPs, notice posts/reactions, user roles, bans, and per-user conversation hiding.

2. **Fix authentication and route safety — M**  
   Restrict redirects to same-origin relative paths, remove token/hash logging, add password reset, verify production callback allowlists, and enforce one shared reserved-handles list covering every existing and planned top-level route at signup and profile-handle changes.

3. **Standardize and secure Cloudflare R2 uploads — M**  
   Migrate every legacy Supabase Storage avatar/listing path to R2, enforce server-side MIME/type/size/count limits, verify ownership, and define orphan cleanup and object deletion behavior.

4. **Harden the direct-publish listing flow — M**  
   Keep immediate `active` publication, add shared server-side validation and ownership checks, remove dead draft/review controls, add owner unpublish/mark-sold management, and ensure failed uploads cannot create invalid listings.

5. **Add tickets as a normal listing category — M**  
   Extend schema/types/forms/search to support tickets, display the face-value guideline and ticket-specific safety messaging, and remove the hard-coded homepage ticket section. Do not add verification or affiliate links.

6. **Build minimal reactive moderation — L**  
   Implement exactly one `super_admin` plus appointed admins; both can unpublish listings, ban/unban users, and delete notice-wall posts, while only the super_admin can appoint/remove admins. Enforce bans in auth and write paths. No approval queue or analytics dashboard.

7. **Finish database-backed browse and discovery — M**  
   Implement title search, category and price filters, stable pagination, URL-backed state, and clear empty/error states across normal listings including tickets. Remove or defer controls not supported by the frozen lean scope.

8. **Repair V1 messaging and soft-delete semantics — M**  
   Fix contact-to-thread navigation, unread state, text-message validation, and Realtime behavior. Replace shared-row deletion with per-user hidden state. Defer message images, automatic link rendering, and full read receipts to V1.1.

9. **Implement the single V1 email flow — M**  
   Send only new-message notifications through Resend, default enabled, with an opt-out toggle in settings. Verify sender domain, delivery failure handling, and links to the correct conversation. Do not add approval, marketing, or other notification emails.

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
    Deploy on Vercel Pro, point `psy.market`, verify TLS and Supabase redirects, complete browser/auth/upload/listing/search/messaging/email/moderation/festival/legal/SEO/mobile smoke tests, then retire the VPS dev-server production path.

## Obsolete items from the previous punch list

- **Freeze V1 decisions and reconcile the PRD** — completed by `V1_DECISIONS.md`; no longer an implementation task.
- **Implement draft/pending/rejected/resubmission lifecycle** — obsolete; V1 is direct-publish with immediate `active` status.
- **Build an approval queue and 24-hour auto-approval** — explicitly out of V1.
- **Build an admin analytics dashboard** — explicitly out of V1; moderation is reactive and narrowly scoped.
- **Add message images, automatic link rendering, and full read receipts before launch** — deferred to V1.1.
- **Add payment or checkout integration** — explicitly out of V1; transactions remain off-platform.
- **Harden the VPS as the production deployment** — obsolete; production is Vercel Pro and the VPS dev-server will be retired.
- **Treat the festival layer as optional or outside the marketplace V1** — obsolete; it is now binding V1 scope.
- **Treat hard conversation deletion as acceptable** — obsolete; V1 requires per-user soft-delete/hiding with shared rows retained.
- **Treat tickets as a hard-coded homepage feature** — obsolete; tickets are a standard listing category.
