# AGENTS.md — psy.market

Last updated: 2026-06-07 by Claude

## ⚠️ CRITICAL — CONFIRM BEFORE ANY ACTION

Before writing a single line of code, running a script, editing a file, or pushing anything:
1. Explain what you plan to do and why
2. Explain the implications (what changes, what's irreversible)
3. Wait for Turgay's explicit "yes"
4. Only then act

**Session resumption:** Approvals from a previous session do NOT carry over. Always list pending work and wait for fresh confirmation.

---

## Project overview

**psy.market** — global marketplace for psytrance fashion and culture. Think Vinted/Etsy for the psytrance scene: festival clothing, jewellery/accessories, music gear, creator profiles, community messaging.

- **Repo:** `/home/repos/psy`
- **Staging:** https://psy.heyturgay.com (Cloudflare tunnel → localhost:3030, `cloudflared-psy.service`)
- **Production:** Vercel (auto-deploys on GitHub push)
- **Supabase project:** https://uabuhtrtommkfmlhseul.supabase.co

## Stack

- Next.js 14 App Router + TypeScript
- Supabase (Postgres, Auth via `@supabase/ssr`, Realtime)
- Cloudflare R2 for images — bucket `psy-market-images`, served at `images.psy.market`
- Tailwind CSS + custom globals.css
- Vercel hosting

## Dev workflow

1. Edit files in `/home/repos/psy`
2. `npm run build`
3. `fuser -k 3030/tcp; sleep 6` — systemd (`psy.service`) auto-restarts
4. Test at https://psy.heyturgay.com
5. `git push` → Vercel auto-deploys

## Required reading before any work

1. `/home/repos/AGENTS.md`
2. This file
3. `.agent-context/CURRENT_STATE.md`
4. `.agent-context/NEXT_STEPS.md`

## After meaningful work, update

- `.agent-context/CHANGELOG.md`
- `.agent-context/CURRENT_STATE.md` if reality changed
- `.agent-context/NEXT_STEPS.md` if priorities changed
- `.agent-context/DECISIONS.md` if a key decision was locked in

**File permissions rule:** Always write context files so all agents can read them.
After writing any file in `.agent-context/`: `chmod 664 /home/repos/psy/.agent-context/<filename>`

## Working rules

- Do not install packages without Turgay's explicit confirmation.
- Do not deploy, restart services, run migrations, or write to Supabase/R2 unless explicitly asked.
- Keep credentials out of all docs. Mention env var names only. Secrets live in `.env.local`.
- If `npm run build` fails due to `.next/` ownership issues, use `sudo chown -R $(whoami) /home/repos/psy/.next` and retry.

## Key docs

- `REFINED_PRD.md` — product requirements (v3.0). Useful for product intent but **stale in several areas** — trust CURRENT_STATE.md over this for implementation reality.
- `SPEC.md` — technical spec (partially stale — trust git log over spec).
- `USER_ROLES.md` — role definitions.
- `docs/STAGING_AUTO_DEPLOY_PRD.md` — proposed VPS staging auto-deploy plan; not implemented yet.
