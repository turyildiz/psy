# psy.market — Agent Changelog

---

## 2026-06-11 — The Wall corkboard redesign by Claude

### Iteration v6 — full dark festival page + Wall chrome (third reference, "This is it")
- **Whole festival detail page is now dark** (oklch 14%): title, tabs, breadcrumb, loading/404 states + dark passes on Info tab (light text, dark link buttons) and Who's Going tab (dark profile cards, dark RSVP dropdown)
- **Wall intro header**: ornament glyph, "The Wall" title + subtitle, three trust chips (Real People / Be Respectful / Stay Safe) with stroke icons
- **Controls row**: green "Post a note" button (or "Log in to post" link), live search input (filters title/body/handle), sort dropdown (Newest / Oldest / Most loved)
- **Filter pills**: dark pills with per-category counts; active pill is light
- **Notes**: category badge is now a dark translucent chip with icon; red URGENT chip auto-shows when title/body matches /urgent|dringend/i (no DB column needed)
- **Pagination**: 12 notes visible, "Load more notes" pill inside the board
- **New dark wall texture** generated with Gemini (`public/textures/wall-dark.jpg`, 124KB, bottom stone ledge cropped off); colour splotches + per-festival cover-art bleed layer kept
- Form submit button now green to match

### Iteration v5 — photoreal texture base
- Generated a photoreal weathered-plaster wall texture with Gemini (gemini-2.5-flash-image, one-off API call using the bereket-pipeline GEMINI_API_KEY), compressed to 1024px JPEG (~222KB) at `public/textures/wall-grunge.jpg`
- `.wall-board` now uses the photo texture as base layer (center/cover); procedural linear-gradient plaster removed; kept fine noise + purple/green splotch radials + bottom grime radial on top
- Festival cover art still bleeds through via `.wall-art` multiply layer

### Iteration v4 — "real festival wall" (second reference image)
- Board is no longer cork: plastered/grungy festival wall — warm beige concrete via layered turbulence, paint splotches (purple/green), dirt patches in corners
- **Festival's own cover art bleeds through** the wall as faded graffiti (`.wall-art`: absolutely-positioned cover image, multiply blend, masked ellipse right side) — automatic per festival
- Three attachment variants per note (hash-deterministic): pinned / taped at corners (no pin) / spiral-notebook page (white paper, punched holes via CSS mask, forced near-white)
- Masonry now 2 wide columns on desktop (notes read like posters), 1 on mobile
- `NoticeBoardTab` now takes `coverUrl` prop
- Removed unused paperclip accessory from v3

### Iteration v3 (after Turgay's reference image — "that's perfect")
- Board: realistic tan cork (two-scale SVG turbulence) + 12px dark wood frame, inner bevel/vignette shadows
- Notes: weathered coloured paper per category (sun-bleached blue/yellow/green/cream/white), paper grain, two creases, faint stain, worn-edge vignette, torn edges via per-note clip-path variants, curled bottom-right corner
- Typography: Permanent Marker (new next/font) for uppercase underlined titles, Caveat 19px for handwritten bodies; form inputs match
- Physical variety per note (hash-deterministic): pin colour (5 options), pin x-position (3 options), tear shape (3 options), accessory (none/tape strip/paperclip SVG)
- Category icons: minimal inline stroke SVGs (car/magnifier/eye/package/megaphone) — replaced emojis after feedback; filter tabs are coloured paper chips with icons, slight rotation
- Feedback loop: v1 cartoon cork + pastel papers + emojis → "childish"; v2 dark felt + neutral papers → "too clean"; v3 matches Turgay's AI reference mock


### The Wall (festivals/[slug], "board" tab) — full visual redesign
- **Corkboard aesthetic** (as originally planned in context docs): cork-textured board with wood frame (`.wall-board`), masonry layout via CSS columns (3/2/1 responsive)
- **Paper notes**: pinned sticky notes with deterministic per-post rotation (hash of post id), CSS pin with category-colored head, hover straightens note
- **Category colors**: pastel paper per category (rideshare=blue, lost_found=yellow, looking_for=green, giving_away=pink, shoutout=cream) — `CATEGORY_PAPER` map in page.tsx
- **Caveat font** added via next/font in `app/layout.tsx` (`--font-caveat`) — used for note titles, filter tabs, empty state
- **Filter tabs** restyled as little paper tabs (slight rotations)
- **Post form** restyled as a blank paper note in the selected category color; button is now "Pin it 📌"
- **Realtime**: `postgres_changes` subscription on `notice_posts` filtered by event_id → board refetches when anyone pins/removes a note. NOTE: requires `notice_posts` to be in the `supabase_realtime` publication — NOT yet verified/enabled in Supabase.
- **"N new notes since your last visit"** banner: localStorage key `psy-wall-seen-{festivalId}`; unseen notes get a rotated red NEW sticker (`.is-new`)
- All existing functionality preserved: post/delete/reactions/filter/login-gating
- New CSS: `.wall-*` classes appended to `app/globals.css`
- Built + deployed to staging (localhost:3030). NOT pushed to GitHub/production yet.

---

## 2026-06-07 (afternoon) — Festival + performance fixes by Claude

### Festival Calendar (continued from morning)
- Fixed `--ink` CSS variable (never existed) across entire `festivals/[slug]/page.tsx` → replaced with `--text`
- Renamed "Notice Board" tab to "The Wall"
- Added `title` field to The Wall posts: DB migration (`ALTER TABLE notice_posts ADD COLUMN title TEXT NOT NULL DEFAULT ''`), type, form input (required, 80 chars), card display

### Performance fixes
- **Middleware**: was calling `supabase.auth.getUser()` on EVERY page request (broad matcher). Now only runs on `/listings/new`, `/messages`, `/profile/edit`. Massive speed improvement.
- **Dev → prod**: switched staging from `npm run dev` to `npm run build && npm run start`. Pages now serve in <300ms vs 1-3s.
- **Login/logout delays**: removed all artificial animation delays (was 700ms + 900ms + 400ms on login, 800ms on logout).

### Server restart pattern (UPDATED)
Always use production build, not dev:
```
cd /home/repos/psy && npm run build && fuser -k 3030/tcp && npm run start -- --port 3030 > /tmp/psy-prod.log 2>&1 &
```

---

## 2026-06-07 (morning) — Festival Calendar + Notice Board built by Claude

- Built `/festivals` page: week-by-week Outlook-style calendar (colored lanes per festival, overlapping support), hero featured card, upcoming/past list
- Built `/festivals/[slug]` page: 3 tabs — Info, Who's Going, The Wall
  - Who's Going: RSVP as Attending/Selling, profile card grid
  - The Wall: category pills, post form, reactions, delete own posts
- Added `events`, `vendor_events`, `notice_posts`, `notice_reactions` tables to Supabase
- Updated FestivalSection (homepage Festival Radar) to fetch from DB, link to event pages
- Added Festival + RSVP + NoticePost + NoticeCategory types to `types/marketplace.ts`

---

## 2026-06-07 — Context rewrite by Claude

Rewrote all .agent-context files and AGENTS.md with current reality.
Previous files were written by Gonzo/hermes on 2026-06-04 and had 0600 permissions (unreadable by other agents). Fixed permissions and replaced with fully current content.

---

## 2026-06-06 — Festival Radar updates by Claude

- Added Space Safari (Sep 4-7, Belgium)
- Sorted all festivals by date
- Fixed scroll-to-top using useRef for touch coords

---

## 2026-06-04 — Auth wiring + category pages + lightbox by Claude

- Wired Supabase Auth throughout — login, signup, session, isOwner checks all use real session
- Built `/apparel`, `/music`, `/jewellery` category pages with filter/sort bar
- Updated nav links to point to real routes
- Added lightbox on listing detail page (fullscreen, arrows, keyboard, thumbnails)
- Fixed blank listing page on load (skeleton instead of null)
- Removed Boom Festival (not happening), added Mo:Dem, Modular, Space Safari, DROPS
- Updated all festival dates to 2026
- Community Spotlight listing counts query DB (were hardcoded 0)
- Footer cleanup: removed Careers/Press, year 2026

---

## 2026-06-03 — R2 migration completed by Claude

- Moved all image uploads from Supabase Storage to Cloudflare R2
- `psy-market-images` bucket, `images.psy.market` custom domain
- `app/api/r2/presign/route.ts` — presigned URL generation
- `lib/r2.ts` — `uploadToR2()` client helper
- NewListingModal, EditListingModal, EditProfileModal all updated to use R2
- All 25 seed listings have proper AI-generated R2 images (no picsum)

---

## 2026-06-01 — Posts feature decision

- Decided: seller posts (V1) = photos + video clips ≤2min + YouTube/Vimeo embeds
- Posts tab on profile page
- Freemium video cap: ≤2min free, longer = future premium
- Not yet built

---

## 2026-05-31 — Messaging + unread badge by Claude

- Added unread message badge to nav
- Edit handle + edit password functionality
- DROPS festival added to Festival Radar

---

## 2026-05-01 — Messaging schema + Supabase wiring by Claude

- Created `conversations` + `messages` tables with RLS, Realtime enabled
- Wired homepage, browse, listing detail, profile to real Supabase data
- Create listing form uploads to Supabase (later migrated to R2)
- `lib/db.ts` with `toProfile()` and `toListing()` transforms

---

## 2026-04-30 — Initial build sprints by Claude

- Cloudflare tunnel setup (psy.heyturgay.com → localhost:3030)
- Homepage responsive overhaul (header, category grids, carousels, footer)
- Browse page: filter bar, multi-select categories, data wiring
- Listing detail: image gallery with swipe + lightbox
- Seller profile page at `/[handle]`
- Signup (2-step) + Login pages built
- Create listing (3-step form) built
- Switched to production build (next start) for stability

---

## 2026-06-04 — Documentation by Gonzo/Hermes (historical)

Context files first created. Verified TypeScript pass, noted permission issues with .next artifacts.

---

## 2026-06-07 — Festival Calendar built by Claude

### DB schema added
- ALTER events: added description, logo_url, city, facebook_url, instagram_url, soundcloud_url
- ALTER vendor_events: added role column ('attending' | 'selling')
- CREATE notice_posts: per-festival notice board posts (200 char, category, contact_handle, no expiry)
- CREATE notice_reactions: emoji reactions on notice posts (❤️ 🙏 🔥 😂 🫂), unique per user/post/emoji
- All tables have RLS policies

### Seed data
- 9 festivals seeded: Antaris, Ozora, Mo:Dem, Masters of Puppets, DROPS, Boom, Modular, Space Safari, Universo Paralello
- All sorted by date, ordered July 2026 → January 2027

### Pages built
- /festivals — calendar widget (month view, event dots, prev/next nav) + editorial hero (next upcoming) + chronological list with past section
- /festivals/[slug] — festival detail with 3 tabs:
  - Info: description, dates, location, website/social links
  - Who's Going: profile cards (seller/attendee badge), 20 + load more, RSVP with role picker
  - Notice Board: corkboard posts, category filter, reactions, post form for logged-in users

### Updated
- FestivalSection.tsx: now fetches from DB instead of hardcoded array; festival cards link to /festivals/[slug]; "View Calendar →" links to /festivals
- types/marketplace.ts: added Festival, FestivalRsvp, NoticePost, NoticeReaction types
