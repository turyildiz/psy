# V1 DECISIONS (frozen 2026-07-12)

1. SCOPE: Lean direct-publish marketplace. Listings publish immediately as active. No approval queue, no 24h auto-approval, no rejection/resubmission workflow.
2. MODERATION: Reactive. Roles: one super_admin (can appoint/remove admins) and admins (identical rights, cannot appoint admins). Powers: unpublish any listing, ban/unban users, delete notice wall posts.
3. STORAGE: Cloudflare R2 only. All legacy Supabase Storage read/write paths will be migrated to R2.
4. PROFILES: Canonical route /[handle]. /seller/[handle] remains a redirect. A reserved-handles list must be enforced at signup (all existing and planned top-level routes).
5. FESTIVAL LAYER: Festival calendar, detail pages, RSVPs and notice wall are officially V1 scope. Calendar will be seeded with the current festival season before launch.
6. PAYMENTS: Contact-only. All payment and delivery off-platform. No payment integration in V1. A safety-tips page is in scope.
7. TICKETS: "Tickets" becomes a normal listing category (contact-only like all others), with a face-value guideline and ticket-specific safety tips. The hard-coded homepage ticket section will be removed. Verified ticket resale = V2 roadmap.
8. MESSAGING: Conversation deletion stays, implemented as per-user soft-delete (hiding). No hard deletion of shared conversation/message rows. Message images, link rendering and full read receipts are deferred to V1.1; V1 requires working thread navigation, unread state, and text messaging.
9. EMAIL: Exactly one notification type in V1 — "new message" email via a transactional provider (Resend), default-on with an opt-out toggle in settings. No other email features.
10. LEGAL: Impressum, Datenschutzerklärung, AGB and safety-tips pages are V1 scope. Operator details (name/address/contact) are implemented as a config placeholder and will be decided and filled in before launch.
11. DEPLOYMENT: Production runs on Vercel (Pro). Domain cutover to psy.market happens at launch. The current VPS dev-server setup will be retired.
12. EXPLICITLY OUT OF V1: payments, reviews, favorites, follows, approval queue, admin analytics dashboard, message images/links, push notifications, multi-currency, mobile apps, verified ticket resale, ticket affiliate links.
