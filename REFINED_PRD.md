# psy.market — Refined Product Requirements Document

**Version:** 3.0
**Date:** February 9, 2026
**Owner:** Turgay Yildiz (Nettmedia)
**Developer:** Gonzo AI (Nettmedia)
**Status:** Refined — Ready for Implementation

---

## Changelog

### v3.0 (February 9, 2026)

| # | Change | Reason |
|---|--------|--------|
| 16 | Replaced Convex with Supabase PostgreSQL | Consolidated to single backend provider |
| 17 | Replaced Clerk with Supabase Auth | Consolidated to single backend provider |
| 18 | Replaced UploadThing with Supabase Storage | Consolidated to single backend provider |
| 19 | Added Supabase Realtime for messaging | Native real-time with Supabase |
| 20 | Replaced Convex cron with Supabase pg_cron | Runs in database, no external cost |
| 21 | Introduced Umbrella Model (User + Profile) | Future-proof for multi-profile in V2 |
| 22 | All entities now reference `profile_id` not `user_id` | Umbrella model architecture |
| 23 | V1 scoped to one profile per user | Keep MVP simple, easy V2 upgrade |
| 24 | Added multi-profile, profile switcher to V2 scope | Deferred complexity |
| 25 | Updated estimated costs for Supabase free tier | New provider |

### v2.0 (February 6, 2026)

| # | Change | Reason |
|---|--------|--------|
| 1 | Added rejection resubmit flow | Original PRD had no path after rejection |
| 2 | Defined edit-after-approval behavior (no re-review) | Undefined in v1.0 |
| 3 | Added auto-approve after 24h SLA breach | SLA had no enforcement mechanism |
| 4 | Removed "popular" sort from V1 | No meaningful data to rank by at launch |
| 5 | Defined featured listing UI (top carousel) | "Featured" had no visual specification |
| 6 | Added `role` field to users schema | Missing from v1.0 schema despite admin requirements |
| 7 | Added content validation rules throughout | No character limits or file constraints existed |
| 8 | Added placeholder legal pages to V1 scope | EU launch requires Privacy Policy and ToS |
| 9 | Defined account deletion behavior (delete everything) | Undefined in v1.0 |
| 10 | Specified messaging capabilities (text + images + links) | Message content rules were undefined |
| 11 | Clarified guest vs authenticated access | Implicit but never stated |
| 12 | Defined admin setup process (manual DB insert) | No admin bootstrapping process existed |
| 13 | Added `/admin` route specification | Admin UI location was undefined |
| 14 | Deferred reporting, stale listings to V2 | Explicitly scoped out of V1 |
| 15 | Added admin content guidelines | No approval/rejection criteria existed |

---

## 1. Executive Summary

**psy.market** is a global marketplace for psytrance fashion and culture. Think Etsy + Vinted + Grailed, but specifically for the psytrance community.

**V1 Goal:** Launch a functional marketplace where users can list, browse, and contact sellers. No payments — validate demand first, monetize second.

**V2 Goal:** Add Stripe Connect payments, reviews, reporting, multi-profile support, and automated featured listings.

---

## 2. Product Goals

| Goal | Priority | Success Metric |
|------|----------|----------------|
| Launch MVP | P0 | Site live with 50+ listings |
| Validate demand | P0 | 100+ registered users, 20+ active listings |
| Build community trust | P1 | 0 scam reports, positive user feedback |
| Generate revenue | P2 | First featured listing sale |

---

## 3. Target Audience

**Primary:**
- Psytrance festival goers (ages 20–40)
- Independent creators making festival clothing
- Vintage collectors selling rare pieces

**Secondary:**
- Festival organizers looking for vendors
- Boutique owners in the scene
- International buyers (global shipping)

**Geography:** Global launch, EU-focused initially.

---

## 4. Features

### 4.1 V1 Features (MVP)

#### 4.1.1 Authentication & Access

- Email/password and Google social login via Supabase Auth
- **Guest access:** Anyone can browse listings and view listing details without an account
- **Authenticated access required for:** creating listings, messaging sellers, managing profile
- Profile completion flow after first sign-up (handle, display name, optional location)

#### 4.1.2 User Architecture (Umbrella Model)

psy.market uses a two-level architecture separating private accounts from public profiles:

**Level 1 — Master Account (`User`):**
- Private. Handles login, security, and (V2) financial payouts.
- Stored in `auth.users` (Supabase Auth) + `public.users` (app-level data: role, email preferences).
- One per human/company.

**Level 2 — Profile (`Persona`):**
- Public-facing identity used to interact with the marketplace.
- Stored in `public.profiles` (handle, display name, avatar, bio, location, social links, etc.).
- All marketplace actions (listings, messages) are tied to a **profile**, not the user account.
- **V1:** One profile per user, auto-created on signup. Type defaults to `personal`.
- **V2:** Multiple profiles per user (personal, artist, label, festival) with a profile switcher.

#### 4.1.3 Profile Fields

- **Handle:** Unique, 3–30 characters, alphanumeric + underscores only (used in URLs: `/seller/[handle]`)
- **Display name:** Required, 1–100 characters
- **Bio:** Optional, max 500 characters
- **Avatar:** Optional, uploaded to Supabase Storage (max 2MB, JPEG/PNG/WebP)
- **Location:** Optional, free text (city, country), max 100 characters
- **Social links:** Optional — Instagram URL, Facebook URL, website URL
- **Creator flag:** Self-identified creator (boolean)

#### 4.1.4 Account Settings (on User level)

- **Email notification preferences:** On/off toggle (default: on)
- **Account deletion:** Self-service. Deletes all user data, profile(s), listings, and messages permanently.

#### 4.1.5 Listings

**Creation:**
- **Title:** Required, 5–100 characters
- **Description:** Required, 20–2,000 characters
- **Price:** Required, in EUR cents. Displayed as EUR with 2 decimal places. Minimum: €0.50 (50 cents). Maximum: €50,000 (5,000,000 cents).
- **Condition:** Required, one of: `new`, `like_new`, `good`, `worn`, `vintage`
- **Size:** Required, free text, max 20 characters (e.g., "S", "M/L", "One Size", "42EU")
- **Images:** Required, 1–5 images. Max 5MB each. Accepted formats: JPEG, PNG, WebP. Uploaded to Supabase Storage.
- **Category:** Required, one of: `clothing`, `accessories`, `gear`, `art`, `other`
- **Tags:** Optional, max 10 tags, each tag max 30 characters, alphanumeric + hyphens
- **Shipping location:** Required, select one or more countries from the country list, or "Worldwide"

**Status Flow:**

```
draft → pending → active → sold
                ↘ rejected → (edit) → pending (resubmit)
```

- **draft:** Seller is still editing. Not visible to anyone except the seller.
- **pending:** Submitted for admin review. Not visible to public.
- **active:** Approved by admin (or auto-approved after 24h). Visible to everyone.
- **sold:** Marked as sold by the seller. Visible but clearly marked "Sold".
- **rejected:** Rejected by admin with notes. Seller can edit and resubmit (returns to `pending`).

**Editing:**
- Sellers can edit their own listings at any time.
- Editing an active listing does NOT trigger re-review. Changes go live immediately.
- Editing a rejected listing and resubmitting sends it back to `pending`.

**Constraints:**
- No limit on the number of active listings per profile.
- A profile cannot contact their own listing.

#### 4.1.6 Discovery

- **Browse page** (`/browse`) with infinite scroll (24 listings per page load)
- **Empty state:** "No listings found. Try adjusting your filters." with a link to clear filters.
- **Filters:**
  - Category (multi-select)
  - Condition (multi-select)
  - Price range (min/max EUR input)
  - Size (text input)
  - Shipping location (country picker)
- **Search:** Keyword search across title, description, and tags (PostgreSQL full-text search)
- **Sort options (V1):** Newest first (default), Price low to high, Price high to low
- **Featured carousel:** Top of browse page, horizontal scrollable row of featured listings. Only shown if at least 1 featured listing exists.

#### 4.1.7 Listing Detail Page

- Full image gallery (click to enlarge)
- Title, price, condition badge, size, category
- Full description
- Tags displayed as chips
- Shipping locations
- Seller info card (display name, avatar, handle, location, member since, link to seller profile)
- "Contact Seller" button (requires authentication, opens messaging thread for this listing)
- View count (incremented on each unique page view per session)

#### 4.1.8 Messaging

- **Per-listing threads:** Each conversation is tied to a specific listing between buyer and seller profiles.
- **Thread ID format:** `{listingId}_{buyerProfileId}_{sellerProfileId}`
- **Message content:** Text + images + links. Max 2,000 characters per message. Images uploaded to Supabase Storage (max 5MB, JPEG/PNG/WebP). Links are auto-detected and rendered as clickable.
- **Real-time:** Messages appear instantly via Supabase Realtime subscriptions.
- **Read receipts:** Messages marked as read when the recipient opens the thread.
- **Email notifications:** Opt-in. When enabled, user receives an email via Resend when they get a new message.
- **Message list page:** Shows all conversations grouped by listing, sorted by most recent message.
- **No message editing or deletion in V1.**

#### 4.1.9 Admin

**Access:** Admin dashboard at `/admin` route within the same Next.js app. Protected by role-based middleware — only users with `role: "admin"` or `role: "super_admin"` can access.

**Roles:**

| Capability | Super Admin | Admin |
|------------|:-----------:|:-----:|
| Approve/reject listings | Yes | Yes |
| Ban/suspend users | Yes | Yes |
| View analytics (listing count, user count, pending queue size) | Yes | Yes |
| Toggle featured flag on listings | Yes | Yes |
| Create/remove admin accounts | Yes | No |

**First super admin setup:** Manually run a SQL update in the Supabase dashboard to set `role = 'super_admin'` on your user record in the `public.users` table after signing up.

**Approval Workflow:**
1. User submits listing → status: `pending`
2. Listing appears in admin approval queue, sorted by oldest first
3. Admin reviews and either:
   - **Approves** → status: `active`, listing visible to public
   - **Rejects** → status: `rejected`, admin writes rejection notes (required, min 10 characters), seller sees notes and can edit & resubmit
4. **SLA:** 24 hours. If no admin action within 24 hours of submission, listing is **auto-approved** via a Supabase pg_cron job that runs every hour.

**Admin Content Guidelines (approval criteria):**
- Listing must have at least 1 clear photo of the actual item
- Title and description must be in English (or clearly understandable)
- Item must be relevant to psytrance culture, festival fashion, or related categories
- No counterfeit or stolen goods
- No prohibited items (weapons, drugs, explicit content)
- Price must appear reasonable (not a placeholder like €0.01 or €99,999)

#### 4.1.10 Legal Pages

- **Privacy Policy** (`/privacy`) — Placeholder page covering: data collected (name, email, location, messages), data storage (Supabase), cookies (Supabase Auth), GDPR rights (access, deletion, portability), contact information for data requests.
- **Terms of Service** (`/terms`) — Placeholder page covering: user responsibilities, prohibited items, no liability for off-platform transactions, content ownership, account termination policy.
- Both linked from the site footer.
- To be reviewed by a lawyer before public marketing launch.

#### 4.1.11 SEO & Meta

- Dynamic `<title>` and `<meta description>` for all pages
- Open Graph tags for listing detail pages (image, title, price)
- Sitemap generation for active listings
- Semantic HTML throughout

### 4.2 V2 Features (Post-Launch)

- **Multiple profiles per user** + profile switcher (personal, artist, label, festival)
- Stripe Connect for payments (marketplace model, split payments, KYC on master account)
- Reviews and ratings (buyer reviews seller after transaction)
- Favorites/wishlist
- Report listing / report user
- Automated featured listings (self-service, paid)
- Bump listings to top (paid)
- Profile header images
- Verified badge (blue check for notable artists/festivals)
- Team access (multiple users managing one profile)
- Multi-currency support
- Push notifications
- Stale listing policy (auto-expire after 90 days)
- "Popular" sort (based on real usage data)
- Mobile app

### 4.3 Out of Scope (V1 and V2)

- Shipping label integration
- Escrow service
- Auction functionality
- Live streaming
- NFT integration
- Multi-language support

---

## 5. Tech Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Frontend | Next.js 14+ (App Router) | Performance, SEO, Vercel native |
| Styling | Tailwind CSS + shadcn/ui | Fast development, consistent UI |
| Database | Supabase PostgreSQL | Managed Postgres, RLS, real-time, single provider |
| Auth | Supabase Auth | Email + Google OAuth, integrated with DB |
| File Storage | Supabase Storage | Image uploads, integrated with auth/RLS |
| Real-time | Supabase Realtime | Instant messaging, live updates |
| Cron | Supabase pg_cron | Auto-approve scheduled task, runs in DB |
| Payments (V2) | Stripe Connect | Marketplace model, split payments |
| Email | Resend (via Next.js API routes) | Reliable delivery, good free tier |
| Hosting | Vercel (Hobby plan) | Fast deploys, preview deployments |

---

## 6. Data Models

### 6.1 Users (Master Account — Private)

Supabase Auth manages `auth.users` (email, password hash, OAuth providers). The `public.users` table extends it with app-specific data:

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK, FK → auth.users) | Same as Supabase Auth user ID |
| `role` | ENUM | `user` (default), `admin`, `super_admin` |
| `email_notifications` | BOOLEAN | Default: true |
| `stripe_account_id` | TEXT | V2 — Stripe Connect ID |
| `created_at` | TIMESTAMPTZ | Account creation time |

### 6.2 Profiles (Public Persona)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Profile ID — referenced by listings, messages |
| `user_id` | UUID (FK → users) | Owner of this profile |
| `type` | ENUM | `personal` (V1 default). V2: `artist`, `label`, `festival` |
| `handle` | TEXT (unique) | 3–30 chars, alphanumeric + underscores. Used in URLs. |
| `display_name` | TEXT | 1–100 chars. Public name. |
| `bio` | TEXT | Optional, max 500 chars |
| `avatar_url` | TEXT | Supabase Storage URL, max 2MB |
| `header_url` | TEXT | V2 — Profile banner image |
| `location` | TEXT | Optional, max 100 chars |
| `social_links` | JSONB | `{ instagram?, facebook?, website? }` — full URLs |
| `is_creator` | BOOLEAN | Self-identified creator, default: false |
| `is_verified` | BOOLEAN | V2 — Manual blue check, default: false |
| `created_at` | TIMESTAMPTZ | Profile creation time |
| `updated_at` | TIMESTAMPTZ | Last update time |

### 6.3 Listings

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Listing ID |
| `profile_id` | UUID (FK → profiles) | Seller's profile |
| `title` | TEXT | 5–100 chars |
| `description` | TEXT | 20–2,000 chars |
| `price` | INTEGER | EUR cents (min 50, max 5,000,000) |
| `condition` | ENUM | `new`, `like_new`, `good`, `worn`, `vintage` |
| `size` | TEXT | 1–20 chars |
| `images` | TEXT[] | Supabase Storage URLs, 1–5 items |
| `category` | ENUM | `clothing`, `accessories`, `gear`, `art`, `other` |
| `tags` | TEXT[] | Max 10 tags, each max 30 chars |
| `ships_to` | TEXT[] | ISO country codes or `["WORLDWIDE"]` |
| `status` | ENUM | `draft`, `pending`, `active`, `sold`, `rejected` |
| `admin_notes` | TEXT | Rejection reason, min 10 chars when rejecting |
| `is_featured` | BOOLEAN | Manual flag, default: false |
| `view_count` | INTEGER | Default: 0 |
| `submitted_at` | TIMESTAMPTZ | When listing entered `pending` (for 24h auto-approve) |
| `created_at` | TIMESTAMPTZ | Creation time |
| `updated_at` | TIMESTAMPTZ | Last update time |

### 6.4 Messages

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Message ID |
| `listing_id` | UUID (FK → listings) | The listing this thread is about |
| `thread_id` | TEXT | Format: `{listingId}_{buyerProfileId}_{sellerProfileId}` |
| `sender_profile_id` | UUID (FK → profiles) | Sender's profile |
| `receiver_profile_id` | UUID (FK → profiles) | Receiver's profile |
| `content` | TEXT | Max 2,000 chars |
| `images` | TEXT[] | Supabase Storage URLs, max 3 per message |
| `read` | BOOLEAN | Default: false |
| `created_at` | TIMESTAMPTZ | Send time |

### 6.5 Favorites (V2 Prep — schema only, no UI in V1)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | Favorite ID |
| `profile_id` | UUID (FK → profiles) | The profile who favorited |
| `listing_id` | UUID (FK → listings) | The favorited listing |
| `created_at` | TIMESTAMPTZ | When favorited |

---

## 7. Page Map & Routing

### 7.1 Public Routes (no auth required)

| Route | Page | Description |
|-------|------|-------------|
| `/` | Landing page | Hero, category highlights, CTAs |
| `/browse` | Browse listings | Infinite scroll, filters, search, featured carousel |
| `/listing/[id]` | Listing detail | Full listing view, seller info, contact button |
| `/seller/[handle]` | Seller profile | Public profile, seller's active listings |
| `/privacy` | Privacy Policy | Placeholder legal page |
| `/terms` | Terms of Service | Placeholder legal page |

### 7.2 Auth Routes

| Route | Page | Description |
|-------|------|-------------|
| `/login` | Login | Custom form with Supabase Auth |
| `/signup` | Sign up | Custom form with Supabase Auth |
| `/auth/callback` | Auth callback | Handles OAuth redirect from Google |

### 7.3 Authenticated Routes (auth required)

| Route | Page | Description |
|-------|------|-------------|
| `/onboarding` | Profile setup | Handle + display name (after first signup) |
| `/sell` | Create listing | Listing creation form |
| `/sell/[id]/edit` | Edit listing | Edit existing listing |
| `/dashboard` | User dashboard | My listings (with status), my messages |
| `/dashboard/listings` | My listings | All user's listings with status filters |
| `/dashboard/messages` | Messages | All conversations, grouped by listing |
| `/dashboard/messages/[threadId]` | Message thread | Single conversation |
| `/dashboard/profile` | Edit profile | Edit handle, display name, bio, avatar, location, socials |
| `/dashboard/settings` | Settings | Email notifications, account deletion |

### 7.4 Admin Routes (admin/super_admin role required)

| Route | Page | Description |
|-------|------|-------------|
| `/admin` | Admin dashboard | Overview stats (pending count, users, listings) |
| `/admin/listings` | Approval queue | Pending listings, approve/reject actions |
| `/admin/users` | User management | User list, ban/suspend actions |
| `/admin/featured` | Featured management | Toggle featured flag on listings |

---

## 8. User Flows

### 8.1 New User Registration

1. Visitor arrives at landing page (`/`)
2. Clicks "Sell" or "Browse"
3. If clicking "Sell" or "Contact Seller" → redirect to `/signup`
4. Completes sign-up (email/password or Google OAuth via Supabase Auth)
5. Database trigger creates `public.users` record (role: `user`) + default `public.profiles` record (type: `personal`)
6. Middleware detects incomplete profile (no handle) → redirects to `/onboarding`
7. User sets handle and display name
8. User can now browse, create listings, and message sellers

### 8.2 Creating a Listing

1. Authenticated user clicks "Sell" button
2. Listing form page loads with all fields
3. User fills in: title, description, price, condition, size
4. User uploads 1–5 images (drag-and-drop or click to upload via Supabase Storage)
5. User selects category and optionally adds tags
6. User selects shipping locations (country picker + Worldwide option)
7. User can "Save as Draft" or "Submit for Review"
8. If submitted → status changes to `pending`, `submitted_at` timestamp recorded
9. User sees confirmation: "Your listing has been submitted for review. You'll be notified when it's approved."
10. Admin reviews (or auto-approved after 24h) → status changes to `active`
11. If rejected → user sees rejection notes, can edit and click "Resubmit"

### 8.3 Buying Flow (V1 — Contact Only)

1. Visitor browses listings at `/browse`
2. Clicks a listing to view detail page
3. Clicks "Contact Seller" (if not authenticated → redirect to `/login` → redirect back)
4. Message composer opens pre-filled with listing reference
5. Buyer sends message (text, optionally images/links)
6. Seller receives notification (in-app via Supabase Realtime + optional email via Resend)
7. Buyer and seller arrange payment and delivery off-platform
8. Seller marks listing as "Sold" from their dashboard

### 8.4 Handling a Rejected Listing

1. Admin rejects listing with notes (e.g., "Photo is too blurry, please upload a clearer image")
2. Seller receives email notification (if opted in)
3. Seller sees listing with status "Rejected" and admin notes in their dashboard
4. Seller clicks "Edit" to update the listing
5. Seller makes changes and clicks "Resubmit"
6. Listing returns to `pending` status with new `submitted_at` timestamp
7. Admin reviews again (same approval workflow)

### 8.5 Account Deletion

1. User navigates to `/dashboard/settings`
2. Clicks "Delete Account"
3. Confirmation dialog: "This will permanently delete your account, your profile, all your listings, and all your messages. This action cannot be undone."
4. User confirms
5. System deletes: profile (cascades to listings, messages, favorites), user record, Supabase Auth account
6. User is logged out and redirected to landing page

### 8.6 Admin Approval Flow

1. Admin navigates to `/admin/listings`
2. Sees queue of pending listings sorted by oldest first (FIFO)
3. Clicks a listing to review
4. Sees all listing details including images, description, seller info
5. Checks against content guidelines (see Section 4.1.9)
6. Clicks "Approve" → listing goes `active`, visible to public
7. Or clicks "Reject" → must enter rejection notes (min 10 characters) → listing goes `rejected`
8. **Auto-approve:** A Supabase pg_cron job runs every hour. Any listing with status `pending` and `submitted_at` older than 24 hours is automatically set to `active`.

---

## 9. Design System

### 9.1 Color Palette

| Token | Value | Usage |
|-------|-------|-------|
| Background | Slate 950 `#020617` | Page background |
| Surface | Slate 900/50 | Cards, panels |
| Primary | Purple 600 `#9333ea` | Action buttons, links |
| Accent 1 | Teal 400 `#2dd4bf` | Highlights, badges |
| Accent 2 | Pink 500 `#ec4899` | Gradient end, accents |
| Text Primary | Slate 50 `#f8fafc` | Headings |
| Text Secondary | Slate 400 `#94a3b8` | Body text, labels |
| Border | Slate 800 `#1e293b` | Card borders, dividers |
| Error | Red 500 `#ef4444` | Error states, validation |
| Success | Green 500 `#22c55e` | Success states, approved badge |
| Warning | Amber 500 `#f59e0b` | Pending badge |

### 9.2 Typography

- **Headings:** Geist Sans, bold
- **Body:** Geist Sans, regular
- **Mono:** Geist Mono (prices, codes)

### 9.3 Components

- **Cards:** Rounded 2xl, slate-900/50 background, subtle slate-800 border
- **Buttons:** Rounded xl, solid colors with hover states. Primary: purple-600. Secondary: slate-800.
- **Forms:** Rounded lg, slate-800 background, slate-700 border, focus ring purple-600
- **Badges:** Rounded full. Status colors: active=green, pending=amber, rejected=red, sold=slate, draft=slate-600
- **Featured carousel:** Horizontal scroll, cards with subtle purple glow/border to distinguish from regular listings

### 9.4 Logo

- TBD: Will be provided by stakeholder
- Placement: Navbar (left), favicon, Open Graph social sharing image

---

## 10. Business Model

### 10.1 V1 Revenue

- **Free listings** — no cost to list
- **Manual featured listings** — seller contacts admin (via in-app message or email). Admin sets featured flag. Custom pricing negotiated per listing.
- **No transaction fees** — users arrange payment off-platform

### 10.2 V2 Revenue

- **Featured listings** — €5–20/day (automated self-service)
- **Bump to top** — €2–5 per bump
- **Transaction fee** — 5–10% of sale price (via Stripe Connect)

### 10.3 Estimated Costs (V1 — Free Tiers)

| Service | Free Tier Limit | Sufficient for V1? |
|---------|----------------|---------------------|
| Supabase (DB + Auth + Storage + Realtime) | 500MB DB, 1GB storage, 50K MAU | Yes |
| Vercel | Hobby plan (free) | Yes |
| Resend | 3,000 emails/month | Yes |
| Stripe (V2) | 2.9% + €0.30/txn | N/A for V1 |

---

## 11. Timeline

| Phase | Deliverables |
|-------|--------------|
| P0 | Project setup, Supabase schema + RLS, Supabase Auth (email + Google), users + profiles tables, database triggers, Next.js middleware, onboarding |
| P1 | Profile CRUD, create listing form, Supabase Storage image upload, listing detail page, seller profile page |
| P2 | Admin dashboard (`/admin`), approval queue, approve/reject flow, pg_cron auto-approve job |
| P3 | Browse page, filters (category, condition, price, size, location), PostgreSQL full-text search, sort (newest, price), featured carousel |
| P4 | Messaging system (per-listing threads, Supabase Realtime, text + images + links, read receipts), email notifications via Resend |
| P5 | User dashboard (my listings, my messages), settings page (email toggle, account deletion) |
| P6 | Legal pages (privacy, terms), SEO (meta tags, OG, sitemap), mobile responsive polish |
| **Total** | **V1 Live** |

---

## 12. Resolved Decisions

| Decision | Answer | Rationale |
|----------|--------|-----------|
| Backend provider | Supabase for everything | Single provider, simpler ops, lower cost |
| User/Profile model | Umbrella (User + Profile) | Future-proof for V2 multi-profile |
| V1 profile limit | One per user | Keep MVP simple |
| Image storage | Supabase Storage | Single provider, integrated with auth/RLS |
| Real-time messaging | Supabase Realtime | Native integration, no extra service |
| Auto-approve mechanism | Supabase pg_cron | Free, runs in database |
| Email sending | Resend via Next.js API routes | Simple, all logic in one codebase |
| Rejected listing flow | Edit & resubmit | Less friction for sellers |
| Edit active listing | No re-review | Trust sellers, reduce admin load |
| 24h SLA breach | Auto-approve | Prevent seller frustration |
| Popular sort in V1 | Removed | No meaningful data at launch |
| Report mechanism | Deferred to V2 | Reduces V1 scope |
| Featured listing UI | Top carousel on browse page | Clear visibility without complexity |
| Listing limit per user | No limit | Don't restrict early adopters |
| Legal pages | Placeholder in V1 | Required for EU, lawyer review later |
| Account deletion | Delete everything (cascade) | Simplest, GDPR-friendly |
| Stale listing policy | Deferred to V2 | Need real data first |
| Message content | Text + images + links | Rich enough for transaction negotiation |
| Guest access | Browse without account | Reduce friction for discovery |
| Admin setup | Manual SQL in Supabase dashboard | Simplest for V1, no admin invite flow needed |
| Admin UI | Same app, `/admin` route | Single deployment, simpler to maintain |

---

## 13. Open Questions (Remaining)

1. **Logo:** To be provided by stakeholder
2. **Sample listings:** 5–10 demo listings needed for launch (who creates them?)
3. **Super admin email(s):** Which user(s) get `super_admin` role?
4. **Domain DNS:** `psy.market` is not yet pointed to Vercel
5. **Email sender domain:** Which domain for Resend? (e.g., `noreply@psy.market`)
6. **Google OAuth:** Needs to be enabled in Supabase dashboard with Google Cloud credentials

---

## 14. Appendix

### 14.1 Country List

All EU countries + Switzerland, Norway, UK, US, Canada, Australia, New Zealand, Israel, Japan, Brazil, Mexico, South Africa, India, Thailand, Indonesia, Argentina, Colombia, Chile + "Worldwide" option.

Full list with ISO codes and flag emojis defined in `lib/countries.ts`.

### 14.2 Condition Definitions

| Condition | Label | Description |
|-----------|-------|-------------|
| `new` | New | Never worn, tags attached |
| `like_new` | Like New | Worn once or twice, no signs of wear |
| `good` | Good | Gently used, minor signs of wear |
| `worn` | Worn | Visible wear but fully functional |
| `vintage` | Vintage | Older piece, may have character/aging |

### 14.3 Validation Rules Summary

| Field | Min | Max | Format |
|-------|-----|-----|--------|
| Handle | 3 chars | 30 chars | Alphanumeric + underscores |
| Display name | 1 char | 100 chars | Free text |
| Bio | — | 500 chars | Free text |
| Avatar | — | 2MB | JPEG, PNG, WebP |
| Location | — | 100 chars | Free text |
| Listing title | 5 chars | 100 chars | Free text |
| Listing description | 20 chars | 2,000 chars | Free text |
| Listing price | €0.50 | €50,000 | EUR cents integer |
| Listing size | 1 char | 20 chars | Free text |
| Listing images | 1 | 5 | Max 5MB each, JPEG/PNG/WebP |
| Tags | 0 | 10 | Max 30 chars each, alphanumeric + hyphens |
| Message content | 1 char | 2,000 chars | Text, auto-linked URLs |
| Message images | 0 | 3 | Max 5MB each, JPEG/PNG/WebP |
| Admin rejection notes | 10 chars | 1,000 chars | Free text |

### 14.4 Admin Content Guidelines

Listings should be **approved** if:
- At least 1 clear photo of the actual item (not a stock photo)
- Title and description are understandable (English preferred)
- Item is relevant to psytrance culture, festival fashion, or related categories
- Price appears reasonable

Listings should be **rejected** if:
- No photos or only stock/placeholder images
- Counterfeit, stolen, or prohibited items (weapons, drugs, explicit content)
- Spam, duplicate, or off-topic content
- Placeholder or clearly fake pricing
- Misleading title or description

---

**Document Owner:** Turgay Yildiz
**Refined By:** Gonzo AI (Nettmedia)
**Last Updated:** February 9, 2026
**Status:** Refined — Ready for Implementation
