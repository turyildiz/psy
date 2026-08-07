# V1 DECISIONS (frozen 2026-07-12)

1. SCOPE: Lean direct-publish marketplace. Listings publish immediately as active. No approval queue, no 24h auto-approval, no rejection/resubmission workflow.
2. MODERATION: Reactive. Roles: one super_admin (can appoint/remove admins) and admins (identical rights, cannot appoint admins). Powers: unpublish any listing, ban/unban users, delete posts.
3. STORAGE: Cloudflare R2 only. All legacy Supabase Storage read/write paths will be migrated to R2.
4. PROFILES: Canonical route /[handle]. /seller/[handle] remains a redirect. A reserved-handles list must be enforced at signup (all existing and planned top-level routes).
5. FESTIVAL LAYER: Festival calendar, detail pages, RSVPs and Notice Board are officially V1 scope. Calendar will be seeded with the current festival season before launch.
6. PAYMENTS: Contact-only. All payment and delivery off-platform. No payment integration in V1. A safety-tips page is in scope.
7. TICKETS: "Tickets" becomes a normal listing category (contact-only like all others), with a face-value guideline and ticket-specific safety tips. The hard-coded homepage ticket section will be removed. Verified ticket resale = V2 roadmap.
8. MESSAGING: Conversation deletion stays, implemented as per-user soft-delete (hiding). No hard deletion of shared conversation/message rows. Message images, link rendering and full read receipts are deferred to V1.1; V1 requires working thread navigation, unread state, and text messaging.
9. EMAIL: Exactly one application-notification type in V1 — “new message” email through server-side All-Inkl SMTP, default-on with an opt-out toggle in settings. Supabase signup confirmation and password recovery also use owner-configured All-Inkl Custom SMTP but are authentication necessities, not product notification features. Use `no-reply@psy.market` as the sender identity unless Turgay separately changes it. No marketing or other notification emails.
10. RECOVERY LIMITATIONS: V1 uses one isolated server-only request that verifies the OTP, revokes every other refreshable session, and only then changes the password. V1 accepts the rare case where the response is lost after Supabase consumes the one-time OTP; the user checks the new password and requests a new reset link if needed. Revocation invalidates other refresh tokens immediately, but an already-issued access token remains valid until its encoded expiry and can therefore keep another session authorized for up to the configured JWT lifetime (roughly one hour in the intended V1 configuration). Do not add durable database-backed recovery state before launch without a separate reviewed design and owner-applied migration approval. Do not derive application encryption keys from the Supabase service-role credential.
11. LEGAL: Impressum, Datenschutzerklärung, AGB and safety-tips pages are V1 scope. Operator details (name/address/contact) are implemented as a config placeholder and will be decided and filled in before launch.
12. DEPLOYMENT: Production runs on Vercel (Pro). Domain cutover to psy.market happens at launch. The current VPS dev-server setup will be retired.
13. EXPLICITLY OUT OF V1: payments, reviews, favorites, approval queue, admin analytics dashboard, message images/links, push notifications, multi-currency, mobile apps, verified ticket resale, ticket affiliate links.

## Wall, Stream & Posts (V1)

Following is part of V1.

- **Names:** The profile tab containing the profile's own posts is called **Wall**. The site-wide page containing all posts eligible for site-wide display is called **Stream**. The festival tab currently labelled **The Wall** is renamed to **Notice Board**; this is a label-only change with no data change.
- **Post format:** A post consists of text, up to five images, and links written inline in the text. Inline links are auto-linkified; there is no separate link field. Videos are not supported in V1.
- **Who can post:** All profile types may post: personal, artist, label, and festival. There is no daily post limit.
- **Interactions:** V1 reactions are emoji only. There are no comments.
- **Author controls:** Authors can edit and delete their own posts. Deleting a post does not delete its images from R2; the images remain unreferenced and are cleaned up manually through the orphan report. Deleting a post must remove the post row, or otherwise ensure that the orphan reporter no longer treats its images as referenced. A status-flag soft-delete is not acceptable for posts: the listing Delete button already works that way, and because the orphan reporter scans all listing rows regardless of status, those images never appear in the orphan report and cannot be cleaned up. The agreed manual cleanup path for post images depends on those images actually becoming unreferenced.
- **Post visibility (amended 2026-08-07):** Each post has a **Make this post public** checkbox, enabled by default. Checked posts are publicly readable by everyone, including logged-out visitors, and may appear on the author's Wall and in Stream. Unchecked posts are members-only: all signed-in people may read them on the author's Wall, but logged-out visitors may not, and they do not appear in Stream. Reactions follow the parent post's visibility. A members-only post cannot be flagged for the Homepage Hero. This supersedes the earlier “hidden only from Stream” wording.
- **Following feed:** The **Following** tab on a user's own profile shows posts from profiles they follow. The tab is not rendered at all while the user follows nobody.
- **Profile tabs and URLs:** Profile tabs have their own URLs. Opening a profile defaults to the Wall tab, not Listings.
- **Homepage Hero:** The Hero shows several admin-flagged posts side by side, with no rotation. Listings never appear in the Hero. If fewer posts are flagged than the available slots, only the flagged posts are shown; recent posts do not fill the remaining slots. If no posts are flagged, a fixed introductory section explaining psy.market is shown instead.
- **Moderation:** V1 has no AI pre-check. Posts publish immediately and only a link blocklist is applied before publication. Removal is reactive through admin rights. Banning a user also hides that user's already published posts.
- **Notifications:** There are no email notifications for posts or new followers.
- **Explicitly V2:** Admin-written articles, the profile Calendar tab, and a separate admin area with reporting UI are V2. In V1, admin actions—flag for Hero, delete post, and ban user—are inline buttons on the content and are visible only to admins.

## Upload rule (post Item 3)

All R2 uploads, including event flyers, must use the hardened path: signed intent → quarantine → create-only promotion. No agent or human writes directly to the public bucket.

Trusted CLI usage:

```text
node scripts/upload-r2.js <file> event-flyer <owner-handle> <event-id>
```
