# psy.market — Decisions

Last updated: 2026-06-07 by Claude

---

## Confirmed decisions

| Decision | Choice | Notes |
|---|---|---|
| Framework | Next.js 14 App Router | |
| Auth | Supabase Auth (`@supabase/ssr`) | Email/password + Google |
| Database | Supabase Postgres | |
| Image storage | Cloudflare R2 | `images.psy.market`, NOT Supabase Storage |
| Profile URL | `/{handle}` | Instagram-style, `/seller/[handle]` redirects |
| Messaging schema | `conversations` + `messages` | Realtime enabled, `messages.body` field |
| Listing status on create | `active` (no pending) | No admin review in V1 |
| Ratings | Removed from V1 | No meaningful data at launch |
| Payments | Deferred to V2 | V1 = validate demand first, no Stripe |
| User architecture | Umbrella model | `User` (auth) + `Profile` (public) separate |
| Profile per user (V1) | One profile only | Multi-profile is V2 |
| Follows/feed | V2 | Too early without user base |
| Festival data | Admin-curated | No public festival creation |
| Video posts | ≤2min free tier | Longer = future premium feature |

## Deferred/open

- Admin approval queue — decided against for V1, may revisit post-launch
- Legal pages content — need writing before public launch
- Featured listings monetization — mechanism TBD
