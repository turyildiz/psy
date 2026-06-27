# psy.market

psy.market is a psytrance culture marketplace for festival fashion, jewellery/accessories, music gear/instruments, creator profiles, seller shops, and community messaging.

This repository is the Next.js app for the marketplace.

## Current status

Last documented: 2026-06-04

The project is an active marketplace prototype, not just a parked PRD. It has live Supabase-backed profiles/listings, public listing/profile pages, auth screens, profile/shop owner surfaces, messaging UI, and Cloudflare R2 upload infrastructure.

It is not yet fully aligned with the original PRD/SPEC and should not be treated as launch-ready without resolving the known gaps below.

## Tech stack

- Next.js 14 App Router
- React 18
- TypeScript
- Tailwind/custom CSS and inline component styling
- Supabase Auth/Postgres via `@supabase/ssr` and `@supabase/supabase-js`
- Cloudflare R2 presigned upload API exists in the app
- npm with `package-lock.json`

## Important docs for agents

Before working on this repo, read:

1. `/home/repos/AGENTS.md`
2. `AGENTS.md`
3. `.agent-context/CURRENT_STATE.md`
4. `.agent-context/NEXT_STEPS.md`
5. `.agent-context/DECISIONS.md`
6. `.agent-context/CHANGELOG.md`

The older product docs remain useful but are partly stale:

- `REFINED_PRD.md`
- `SPEC.md`
- `USER_ROLES.md`

Focused docs live in `docs/`:

- `docs/STAGING_AUTO_DEPLOY_PRD.md` — proposed GitHub Actions → VPS staging auto-deploy plan for `psy.heyturgay.com`.

## Main implemented routes

Public/mostly public:

- `/`
- `/browse`
- `/apparel`
- `/jewellery`
- `/music`
- `/listing/[id]`
- `/seller/[handle]` redirects to `/{handle}`
- `/{handle}` profile/shop page
- `/login`
- `/signup`
- `/auth/callback`

Protected/auth-dependent:

- `/listings/new`
- `/messages`
- `/messages/[id]`
- `/profile/edit`
- `/listing/[id]/edit`

API routes:

- `/api/auth/signup`
- `/api/r2/presign`

## Environment variables

Do not commit secrets. Current code expects variables in `.env.local` or the deployment environment. Known variable names include:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
NEXT_PUBLIC_SITE_URL=
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=
NEXT_PUBLIC_R2_PUBLIC_URL=
```

## Local development

```bash
cd /home/repos/psy
npm run dev
```

The public tunnel memory for this project is `psy.heyturgay.com`, expected to target local port `3030`.

`psy.heyturgay.com` is VPS staging, separate from Vercel production. See `docs/STAGING_AUTO_DEPLOY_PRD.md` for the proposed plan to auto-rebuild/restart VPS staging whenever GitHub `main` changes.

## Safe verification

TypeScript check:

```bash
cd /home/repos/psy
./node_modules/.bin/tsc --noEmit --incremental false
```

Production build caveat: direct `npm run build` in this shared VPS repo may fail if `.next/` artifacts are owned by another agent. Use a temp copy for build verification unless Turgay approves permission/artifact cleanup.

Example temp-copy build pattern:

```bash
rm -rf /tmp/psy-build-check && mkdir -p /tmp/psy-build-check
rsync -a --exclude .git --exclude .next --exclude node_modules /home/repos/psy/ /tmp/psy-build-check/
cp -a /home/repos/psy/node_modules /tmp/psy-build-check/node_modules
cd /tmp/psy-build-check
npm run build -- --no-lint
```

## Known launch blockers / alignment gaps

1. **Listing moderation mismatch**
   - Original PRD expects `draft → pending → active` admin review.
   - Current create listing flow inserts new listings as `active`.

2. **Admin system missing**
   - Original PRD expects `/admin` route tree.
   - Current tracked app has no admin routes.

3. **Storage strategy split**
   - Original docs say Supabase Storage.
   - Current app includes R2 presign/upload infrastructure and some Supabase Storage usage.

4. **Search incomplete**
   - Header routes to `/browse?q=...`.
   - `/browse` currently does not apply the query.

5. **Legal routes inconsistent**
   - Original PRD expects `/privacy` and `/terms`.
   - Signup links currently point to `/privacy-policy` and `/terms-of-service`.
   - Legal pages are not present in tracked files as of this doc update.

6. **Messaging schema docs stale**
   - Original SPEC describes `messages.thread_id`/`content`.
   - Current app uses `conversations`, `messages.conversation_id`, `messages.body`, `unread_for`, and RPC helpers.

7. **Middleware protection narrower than SPEC**
   - Current middleware protects `/listings/new` and `/messages`.
   - Review owner/admin protection before launch.

## Current guidance

Before adding features, first reconcile the documentation and product decisions around moderation, storage, admin, legal pages, search, and database schema. Otherwise agents may build against stale assumptions from the original PRD/SPEC.
