# Current Session — 2026-06-11 (Claude, via Telegram)

## Shipped to production (main, commit d35066e)
**The Wall + dark festival pages** — full redesign of /festivals/[slug]:
- Whole festival detail page dark-themed (all three tabs got dark passes)
- Wall: photoreal dark wall texture (public/textures/wall-dark.jpg, Gemini-generated via bereket-pipeline GEMINI_API_KEY), festival cover art bleeds through as faded graffiti (auto per festival), weathered colored paper notes (torn clip-path edges, creases, grain), pin/tape/notebook attachment variants (hash-deterministic)
- Permanent Marker titles + Caveat handwritten bodies (new fonts in app/layout.tsx)
- Intro header (trust chips), green Post button, live search, sort, per-category counts, URGENT auto-flag (regex on title/body), load-more pagination, "N new notes since last visit" (localStorage)
- Realtime subscription on notice_posts → live board refetch
- Design iterated v1→v6 against Turgay's reference images (in Telegram); v6 = "This is it" reference

## On branch redesign/homepage (commit 5a4de1b, pushed)
**Homepage redesign** — staging (psy.heyturgay.com) currently runs THIS branch:
- HomeHero: dark texture hero, "Made by the tribe. Worn on the dancefloor.", working search → /browse?q=, quick links, live stats
- WallTeaser: "Live from the walls" band, 3 latest notes as paper cards → /festivals/[slug]?tab=board
- Section order rule: commerce = light/cream, culture = dark+texture (hero → fashion → jewellery → festivals+walls+tickets dark band → music → community)
- /browse now honors ?q= (all-category search, title/desc/tags, Clear button) — fixes header search too
- /festivals/[slug] honors ?tab= deep links
**Rollback:** main (d35066e) is the stable Wall version. `git checkout main && npm run build && fuser -k 3030/tcp` restores staging.

## Open items (need Turgay's explicit OK)
1. Enable Realtime on notice_posts in Supabase (one publication change) — live Wall updates inactive until then
2. Merge redesign/homepage → main when he approves the homepage
3. Optional Wall upgrades: `urgent` DB column (replace regex heuristic), structured from/to fields for rideshare route chips, doodle/sticker decorations
4. psy.market V1 gap list (from PRD review earlier today) — biggest: no admin queue, no listing status flow/mark-as-sold, no settings/account deletion, no email notifications, legal pages 404, zero SEO, no pagination

## Design direction agreed today
"Festival infrastructure" identity: culture surfaces (festivals, Wall, community) = dark + physical textures (plaster/tape/marker); commerce surfaces = clean cream. Accents: rust = buy/sell, green = community actions.

## Notes
- Turgay's workflow preference: NO screenshots in change reports — text summary + staging URL, he checks himself (exception: when he explicitly asks)
- Earlier today (separate): Bereket redesign explored with 4 HTML mockups (direction D = his reference, files in /home/claude/bereket-redesign/) — he said "forget it" and pivoted to psy.market; nothing in bereket repo touched
