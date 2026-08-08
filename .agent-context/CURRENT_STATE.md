# psy.market — Current State

**Last updated:** 2026-08-08 by Psy after MP-0 decision/document reconciliation

**Status:** Active development — pre-launch V1
**Primary agent:** Psy. Turgay is the owner and approval authority. Claude has handed over the project and is available for historical reasoning or service actions that still belong to the `claude` account.

---

## Source-of-truth order

1. `docs/V1_DECISIONS.md` — frozen/amended binding V1 scope; overrides conflicting PRD/SPEC text.
2. `docs/MULTI_PROFILE_PROPOSAL.md` — binding detailed Multi-Profile decisions and ordered MP-0 through MP-14 plan.
3. Newest versioned execution/acceptance records, especially `docs/R2_MIGRATION_STEP_*.md`.
4. Current application code and committed Git history.
5. `docs/V1_PUNCHLIST.md` — ordered work list, but completion boundaries must be checked against newer execution records.
6. `.agent-context/*` and older PRD/SPEC documents — context only; several are stale.

There was a substantial committed change set after the previous 2026-06-07 state snapshot. This file replaces that snapshot rather than extending its old assumptions.

---

## Product and launch status

- V1 is a lean, contact-only psytrance marketplace with direct publication: new listings become `active` immediately.
- No V1 approval queue, payments, reviews, favorites, admin analytics, multi-currency, or mobile app.
- Multi-Profile is binding V1 scope: up to five publicly unlinked profiles per account, `vendor` type, one active profile per session, per-profile interactions/feeds/inbox, profile deletion, and whole-account deletion under the finalized safeguards.
- Multi-Profile is not yet implemented: the current database still enforces the pre-MP one-profile index and the application still has one-row actor lookups/no switcher until the guarded MP slices are applied.
- Festival calendar, festival pages, per-profile RSVPs, Notice Board, Wall/Stream/Following, tickets as a normal listing category, minimal reactive moderation, text messaging, one new-message email, account settings/deletion, and legal/safety pages are binding V1 scope.
- `https://psy.heyturgay.com` is the development/staging site.
- `www.psy.market` is the intended launch site, but launch has not happened. The current `psy.market`/`www.psy.market` 404 is expected and must not be diagnosed as an outage.
- Production cutover to Vercel Pro and the public domain happens only after Turgay declares the product ready.

---

## Infrastructure and operations

| Component | Current state |
|---|---|
| Host | `netcup-main` (`152.53.162.231`), Ubuntu 24.04, `Europe/Berlin` |
| Staging | `https://psy.heyturgay.com` → localhost port `3030` |
| App service | `psy.service`, user systemd service owned by the `claude` account |
| Tunnel | `cloudflared-psy.service`, also under `claude` |
| Staging runtime | Production Next.js build: `npm run build` + `npm start`; do not replace with `npm run dev` |
| Database/Auth | Supabase Postgres, Auth, and Realtime |
| Public media | Cloudflare R2, `psy-market-images`, served at `images.psy.market` |
| Private uploads | Separate R2 quarantine bucket used by the hardened upload pipeline |
| Launch hosting | Vercel Pro, activated/cut over only at launch |

Operational boundaries:

- Psy cannot restart or manage the `claude`-owned app/tunnel services. Ask Turgay or Claude.
- No agent has root or NOPASSWD sudo. Never work around a password prompt.
- Manual restarts must retain the production-build runtime. The VPS move showed login improving from about 1.08 seconds to about 0.004 seconds after switching away from the dev server.
- Jobs preserving old UTC firing times must set `CRON_TZ=UTC` because Netcup runs in `Europe/Berlin`.
- The proposed `docs/STAGING_AUTO_DEPLOY_PRD.md` predates the completed VPS move and contains obsolete service ownership, `fuser`, sudo, and mixed-checkout assumptions. It must be rewritten before implementation.

---

## Reconciled repository baseline

The accepted 2026-07-26 read-only reconciliation proved that the application/runtime source, database timestamps, and R2 object timestamps had not advanced beyond checkpoint `f16fceb`. The later repository commits are documentation-only and were explicitly owner-authorized, one file per commit.

- `AGENTS.md` now records the Netcup host, `claude` service ownership, and production Next staging runtime.
- `supabase/migrations-proposal.md` now records Chunks 0–7 live and preserves Chunks 8–9 as approval-gated proposals.
- `docs/V1_PUNCHLIST.md` now records Steps 8–10, Gate A, the rejected Gate B prototype, and deferred database-function hardening.
- Claude's handover is preserved as historical documentation; its known contradictions remain identified below.

---

## Implemented application surfaces

Tracked routes currently include:

- Marketplace: `/`, `/browse`, `/apparel`, `/music`, `/jewellery`, `/listing/[id]`, `/listings/new`, `/listing/[id]/edit`.
- Profiles: `/[handle]`, redirect `/seller/[handle]`, and `/profile/edit`.
- Auth: `/login`, `/signup`, `/auth/callback`, `/forgot-password`, `/auth/recovery`, `/update-password`.
- Messaging: `/messages`, `/messages/[id]`.
- Festivals: `/festivals`, `/festivals/[slug]`.
- APIs: signup, R2 presign, and R2 finalize.

Important corrections to the old snapshot:

- `/profile/edit` and `/listing/[id]/edit` are substantive implemented pages, not absent placeholders. They still require product/security/runtime acceptance and currently violate the loading rule by rendering header-only rather than a layout-matching shimmer skeleton.
- The festival calendar is now a horizontal timeline/Gantt experience with mobile improvements, not the old month-card/calendar description.
- Festival detail and The Wall use the later full dark-page visual design, search/sort/filter controls, pagination, reactions, and Realtime-oriented behavior.

---

## Auth and account safety

Committed application work now includes:

- Central redirect/route safety helpers.
- Same-origin relative redirect enforcement.
- Hardened signup and callback handling.
- Forgot-password, recovery-link, and update-password pages.
- Dedicated recovery page/layout and token-hash email template.
- Removal of auth material from logging paths covered by the hardening work.
- Banned-account error messaging in login and the auth modal.
- Automated auth-safety tests.

Activation boundary:

- The recovery code is committed, but the V1 punch list records it as inactive until Supabase dashboard redirect URLs and the `token_hash` email template are configured and a real-mail end-to-end test passes.

Standing UI requirement from Turgay:

- Loading pages must never render `null`, blank content, or only surrounding chrome. They must render a shimmer skeleton matching the final layout. `.skeleton-block` and the shimmer animation already exist.

---

## Database governance, moderation, and messaging

The repo contains:

- A captured read-only Supabase schema/audit baseline.
- Dependency-ordered SQL packages through Chunk 7 covering critical RLS/RPC fixes, admin/ban foundations, handle/profile constraints, ticket validation, moderation RPCs, conversation hiding, durable ban enforcement, and Realtime publication.
- Application integration for profile-scoped conversation hiding and restoring hidden direct conversations.
- Auth UI behavior for banned-account rejection.

Live status verified read-only on 2026-07-26:

- Database Chunks 0–7 are live, including `hide_conversation`, `find_and_unhide_conversation`, moderation/ban foundations, ticket enum support, constraints, triggers, RLS, and Realtime publication.
- Chunks 8–9 are not authorized or applied.
- No upload-session/reservation table, column, RPC, trigger, policy, or reconciliation state exists in the live database.
- `increment_view_count` and `update_conversation_last_message` are existing `SECURITY DEFINER` functions that are broadly executable and lack a fixed `search_path`. Harden them in the next separately reviewed database chunk; Psy must not prepare or apply SQL without new owner authorization.

V1 moderation remains narrowly scoped: one `super_admin`, appointed admins, listing unpublish, account ban/unban, and Wall-post deletion. No approval queue or analytics dashboard.

---

## Cloudflare R2 and media migration

Committed pipeline capabilities include:

- Private quarantine before public promotion.
- Signed upload intents.
- Server-side purpose, MIME, declared-size, ownership, and key validation.
- Browser preprocessing for supported image uploads.
- Private pending-object validation and exact cleanup boundaries.
- Create-only public promotion behavior.
- Stable, paginated database-reference scans.
- Report-only treatment for public replacement/orphan objects; no public deletion path.
- Automated upload policy, intent, cleanup, and server-config tests.

Migration status:

- Step 8 approved the exact three-object profile-media manifest.
- Step 9 copied and independently verified the three objects byte-for-byte in R2.
- Step 10 completed the owner-applied switch of exactly three profile URL fields across Turgay and Otis; owner and independent verification passed.
- Step 11 Gate A completed the approved state-free baseline, automated upload checks, and static public-deletion-path proof. Its original execution artifact is pending recovery from the pre-migration home archive.
- The narrow Gate B server-side image-count prototype was rejected and is not present in the application or live database.
- Original Supabase objects remain intentional rollback sources.
- Supabase source deletion, Storage retirement, destructive Chunk 9 work, the deferred Yacxilan object, and any demo-data purge remain separately approval-gated.
- Existing demo profiles and listings must remain available during development; any later purge must retain `@turgay`.

Known unresolved listing-upload boundary:

- The current browser flow can promote listing images before the final listing INSERT/UPDATE references the public URL.
- A simple authoritative five-image count check was rejected as insufficient under repeated/concurrent requests and replacement flows.
- A durable upload-session/reservation/commit architecture was designed but not implemented, committed, or deployed. The old-home archive expected to contain the exact package is under `/home/claude/archives-from-old-vps/`, which is not traversable by the Psy account; no permission workaround is authorized. Do not represent the server-side sixth-image/concurrency problem as solved.

---

## Handles and reserved profiles

Two different concepts must remain separate:

- `blocked_handles`: seeded system, route, and brand names that normal signup must never claim. Signup already reads this list, with database-side enforcement represented in the migration package.
- `reserved_handles`: intended pre-reservation for selected artists, labels, shops, and organisations. The current table was empty at capture time and the private claim workflow is planned, not implemented.

`docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md` proposes non-expiring reservations plus expiring one-time claim invitations. It requires a fresh live preflight, owner-reviewed SQL, rollback, and staging acceptance before implementation.

Preserve existing user-facing distinctions:

- Blocked/system name: `Handle not available`.
- Existing profile collision: `Handle already taken`.

---

## Posts scope remains unconfirmed in the binding document

Claude's handover says Posts are intended for V1, but `docs/V1_DECISIONS.md` does not currently make Posts binding. Do not begin implementation until Turgay resolves that documentation gap. The historical concept was:

- Profile `Posts` tab beside active listings.
- Captions plus photos, native short clips up to two minutes, and YouTube/Vimeo embeds.
- Native browser playback for uploaded clips.
- Instagram embeds were deliberately rejected as unreliable; users may upload downloaded reel video instead.
- Longer video may become a premium feature; pricing is undecided.
- Follows and the Following feed are V1 and profile-scoped under the Multi-Profile proposal; the current implementation still requires active-profile conversion and verification.

---

## Current high-priority gaps

These are evidence-backed gaps, not a final implementation plan:

1. **Context reconciliation:** `NEXT_STEPS.md`, `DECISIONS.md`, `CHANGELOG.md`, and `docs/README.md` remain stale or internally contradictory after the 27-commit period and VPS move.
2. **Loading UX:** substantive edit pages render header-only while loading, violating the required shimmer-skeleton rule.
3. **Browse/discovery:** `/browse` ignores `?q=`, is currently clothing-oriented, lacks stable pagination/URL-backed full filter state, and does not yet cover the frozen ticket-category requirement.
4. **Legal/safety:** login/signup link to legal routes that do not exist; V1 requires Impressum, Datenschutzerklärung, AGB, and safety tips.
5. **Email:** the single V1 new-message Resend flow and opt-out setting are not implemented/accepted.
6. **Tickets:** ticket listings, face-value guidance, and ticket-specific safety behavior are not fully implemented end-to-end.
7. **Moderation:** SQL/application foundations are live and read-only verified, but the minimal moderation UI and full browser acceptance remain incomplete.
8. **Account settings/deletion:** email preference, password-management integration, and safe self-service account deletion remain incomplete.
9. **Reserved profile claims:** specified but not implemented or wired into normal handle enforcement.
10. **Posts:** described as V1 in the handover but absent from the binding decision document; owner clarification is required before implementation.
11. **Upload concurrency:** durable listing-image reservation/commit remains unresolved.
12. **Launch readiness:** SEO/canonical/metadata, monitoring, Vercel Pro configuration, Supabase launch redirects, legal operator data, domain cutover, and complete browser acceptance remain future gated work.

---

## Documentation known to be stale or contradictory

- `.agent-context/NEXT_STEPS.md`: still plans the June festival schema/build that already exists and includes obsolete staging restart options.
- `.agent-context/DECISIONS.md`: omits frozen July V1 decisions and retains obsolete service-restart uncertainty.
- `.agent-context/CHANGELOG.md`: stops at June 27 and contains historical service commands that are not valid current operations.
- `docs/README.md`: says last documented June 4, still frames frozen decisions as unresolved PRD mismatches, and contains stale environment/build guidance.
- `docs/STAGING_AUTO_DEPLOY_PRD.md`: predates Netcup completion and conflicts with no-root policy, `claude` service ownership, production-build staging, and the dirty shared checkout.
- `.agent-context/HANDOVER_CLAUDE_TO_PSY_2026-07-26.md`: its main facts are authoritative, but section “What I would do first” item 2 incorrectly says to diagnose the `psy.market` 404; that directly contradicts the corrected domain section above it. Do not follow that item.

---

## Immediate documentation sequence

1. Keep architecture implementation paused until Turgay reviews the exact recovered Step 11 package against the accepted reconciliation baseline.
2. Ask Claude to extract the approved `psymarketbot-home-20260725.tar.gz` archive because Psy lacks traversal/read permission; do not work around that boundary.
3. Reconcile `NEXT_STEPS.md` against `docs/V1_DECISIONS.md`, `docs/V1_PUNCHLIST.md`, committed code, and verified completion records before selecting implementation work.
4. Ask Claude directly whenever a product or implementation decision depends on historical reasoning not preserved in the repo.
5. Do not diagnose or cut over `psy.market`/`www.psy.market` until Turgay declares launch readiness.
