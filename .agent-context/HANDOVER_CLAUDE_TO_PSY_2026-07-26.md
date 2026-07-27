# psy.market handover — Claude → Psy

**Date:** 2026-07-26
**Reason:** Turgay moved to one project per agent. Psy owns psy.market from today; Claude moves to phangan.app.
**Scope:** what I know that is *not* already in the repository. Everything else is in `.agent-context/` and `docs/`.

---

## Read this first: the existing context files are stale

`.agent-context/CURRENT_STATE.md` and `NEXT_STEPS.md` say "Last updated 2026-06-07 by Claude".
**There have been 27 commits since then**, including work those files do not mention:

- R2 upload pipeline hardening, Steps 8–10 (profile media manifest, R2 copies, profile media switch) — see `docs/R2_MIGRATION_STEP_*.md`
- Auth hardening: password reset, recovery-link hardening, redirect hardening
- Moderation: ban enforcement (Chunk 6), conversation hiding instead of deletion (Chunk 5), realtime publication (Chunk 7)
- Festival calendar redesigned as a horizontal Gantt timeline, plus mobile UX work
- The Wall redesigned with a dark page theme
- `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md` added
- A staging auto-deploy PRD at `docs/STAGING_AUTO_DEPLOY_PRD.md`

**Trust the git log and `docs/` over `CURRENT_STATE.md` until you have rewritten it.** Rewriting it is
probably your first useful task.

There is also one uncommitted change in the working tree: `AGENTS.md`, updated today for the netcup
cutover. Someone is mid-edit — check with Turgay before committing or reverting it.

---

## Infrastructure, as of today

| Thing | State |
|---|---|
| Staging | `https://psy.heyturgay.com` → `localhost:3030`, **200 OK** |
| Production | Vercel, auto-deploys on push to GitHub `main` |
| Local service | `psy.service`, a **user** systemd service under the **`claude`** account, `Restart=always` |
| Tunnel | `cloudflared-psy.service`, config `/home/claude/.cloudflared/psy-config.yml`, tunnel ID `b6d276a6-982f-4ce6-a242-8f84a8016aac` |
| Images | Cloudflare R2, bucket `psy-market-images`, served at `images.psy.market` |
| Database | Supabase — auth, Postgres, realtime |

**Two things about the service that will confuse you if nobody says them:**

1. It runs under the **`claude`** account, not `psymarketbot`. That is a leftover from the migration,
   when I moved it. You cannot restart it yourself — either ask Turgay, or ask me and I will do it.
   Worth deciding with Turgay whether ownership should move to your account now that the project has.
2. During the VPS move on 2026-07-25 I switched it from a **dev server to a production build**.
   Login went from 1.08s to 0.004s. If you ever restart it manually, use `npm run build && npm start`,
   not `npm run dev`, or you will silently reintroduce that regression.

---

## `psy.market` returns 404 — expected, not a fault

`https://psy.market` → **404**, `https://psy.heyturgay.com` → **200**.

Turgay confirmed on 2026-07-26: **`psy.heyturgay.com` is the development site. `www.psy.market` is
where it moves at launch, and that has not happened yet.** So the 404 is simply an unlaunched domain.

I had this wrong in the first version of this note and flagged it as a top-priority bug — it is not.
Do not spend time diagnosing it. The real task is the launch cutover, whenever Turgay decides the
product is ready.

---

## Things I know that are not written down anywhere in the repo

### Turgay's standing UI rule: never render `null` while loading

Every page must show a shimmer skeleton matching the real layout. Not a spinner, not blank, not
`null`. The `.skeleton-block` class and shimmer animation already exist in `globals.css`.

```tsx
if (loading) return <SkeletonLayout />;
if (!data)   return <NotFound />;
return <RealContent data={data} />;
```

He has corrected this before and cares about it. It applies to anything new you build.

### `reserved_handles` is built but not wired

Two distinct tables handle this and they are easy to confuse:

- **`blocked_handles`** — 56 seeded system/route/brand names that can never be registered (`admin`,
  `login`, `signup`, `browse`, `psymarket`, …). The signup page **already queries this**.
- **`reserved_handles`** — artist/label pre-reservation. Schema exists (`handle`, `email`,
  `reserved_at`, `expires_at` 90 days, `consumed`, `consumed_at`) but the table is **empty and the
  check is not wired into signup**. Intended for letting known artists lock a handle before they
  register. See `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md`.

Error-message distinction that already exists and should be preserved: "Handle not available" for
blocked, "Handle already taken" for an existing profile.

### Posts feature — decided but not built

Confirmed for V1 on 2026-06-01, still unbuilt:

- A "Posts" tab on the profile page alongside "Active Listings"
- Caption + photos (R2) + short video clips ≤2 min (R2) + YouTube/Vimeo embeds
- Native browser player for uploaded clips
- **No Instagram embeds** — decided against, too unreliable; designers download their reel and upload
- Freemium model sketched: free tier caps video at 2 minutes, premium allows longer. Pricing not set.
- **Follows and a feed are explicitly V2**, deliberately — a feed with no user base feels empty

### Admin pattern

Turgay adds festivals and events directly in the Supabase table editor. There is no public creation
flow and none is planned for V1.

---

## What I would do first, in order

1. **Rewrite `CURRENT_STATE.md`** from the git log and `docs/`. It is seven weeks and 27 commits out
   of date, and every future decision made against it inherits that error.
2. **Diagnose the `psy.market` 404.** It is the public front door and nobody owns it.
3. **Decide the service account question** with Turgay — should `psy.service` move from `claude` to
   `psymarketbot` now that you own the project.
4. Then the existing high-priority list: `/profile/edit`, `/listing/[id]/edit`, browse `?q=` search
   being ignored, and the legal pages that are linked from signup but do not exist.

---

## Handover terms

I am not going to keep touching this repository. If something here is wrong, or you need context I
have not written down, ask me directly rather than guessing — I worked on this for months and a lot
of the reasoning only exists in my memory, not in the code.

Two specific offers: I can explain any decision in the git history, and I can restart `psy.service`
while it still runs under the `claude` account.
