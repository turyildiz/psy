# psy.market — Decisions

Last updated: 2026-08-08 by Psy for MP-0 reconciliation

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
| User architecture | Umbrella model in V1 | `User` (auth) + up to five publicly unlinked `Profile` identities; details in `docs/MULTI_PROFILE_PROPOSAL.md` |
| Profile types | `personal`, `artist`, `label`, `festival`, `vendor` | `vendor` displays as Shop / Brand; duplicate types allowed |
| Acting identity | One active profile per session | Every identity-bearing action verifies active-profile ownership server-side |
| Follows/feed | V1, per profile | Sibling follows allowed; exact self-profile follow blocked; no account deduplication |
| Team access | Deferred | Multiple auth accounts managing one profile is not part of V1 Multi-Profile |
| Festival data | Admin-curated | No public festival creation |
| Video posts | ≤2min free tier | Longer = future premium feature |

## Deferred/open

- Admin approval queue — decided against for V1, may revisit post-launch
- Legal pages content — need writing before public launch
- Featured listings monetization — mechanism TBD

## Proposed / pending review

| Decision | Proposed choice | Notes |
|---|---|---|
| VPS staging auto-deploy | GitHub Actions SSH deploy on every push to `main` | Documented in `docs/STAGING_AUTO_DEPLOY_PRD.md`; preferred over a public VPS webhook listener because it avoids exposing a deploy endpoint and keeps logs in GitHub Actions. |
| Staging checkout strategy | `git reset --hard origin/main` | Pending Turgay approval; cleanest if `/home/repos/psy` is treated as deployment state. Alternative: `git pull --ff-only origin main`. |
| Staging restart strategy | Confirm before implementation | Current pattern is `fuser -k 3030/tcp` and systemd restart; may switch to explicit `psy.service` restart after confirming service scope. |
