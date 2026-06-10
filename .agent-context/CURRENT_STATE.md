# psy.market — Current State

Last updated: 2026-06-07 14:40 by Claude

---

## Status: Active development — pre-launch MVP

Primary agent: Claude. Turgay and Claude work on this together regularly.

---

## Infrastructure

| Thing | Status | Detail |
|---|---|---|
| Staging | ✅ Live | psy.heyturgay.com → localhost:3030 via `cloudflared-psy.service` |
| Production | ✅ Live | Vercel (auto-deploys on GitHub push) |
| Supabase | ✅ Live | Auth + Postgres + Realtime all wired |
| R2 Images | ✅ Live | Bucket `psy-market-images`, served at `images.psy.market` |
| systemd | ✅ Running | `psy.service`, Restart=always |

---

## Routes

| Route | Status | Notes |
|---|---|---|
| `/` | ✅ | Homepage — category sections, Festival Radar (from DB), Community Spotlight, Tickets |
| `/browse` | ✅ | Browse all listings, filter/sort |
| `/apparel` | ✅ | Clothing category page |
| `/music` | ✅ | Gear/instruments category page |
| `/jewellery` | ✅ | Accessories category page |
| `/listing/[id]` | ✅ | Detail page with lightbox gallery, seller card |
| `/[handle]` | ✅ | Profile/shop page (Instagram-style URL) |
| `/seller/[handle]` | ✅ | Redirects to `/[handle]` |
| `/login` | ✅ | Supabase Auth wired |
| `/signup` | ✅ | 2-step form, Supabase Auth wired |
| `/auth/callback` | ✅ | Auth callback |
| `/listings/new` | ✅ | 3-step create listing form |
| `/messages` | ✅ | Inbox (conversations + messages tables) |
| `/messages/[id]` | ✅ | Conversation thread |
| `/festivals` | ✅ | Calendar widget + hero + list (upcoming + past) |
| `/festivals/[slug]` | ✅ | Info / Who's Going / The Wall tabs |
| `/profile/edit` | ⚠️ | Button exists, page not fully built |
| `/listing/[id]/edit` | ⚠️ | Icon exists, page not built |

---

## Features

- **Auth:** Full Supabase Auth — email/password + Google. Session used throughout.
- **Listings:** Create/browse/detail working. Status defaults to `active` on create.
- **Images:** All on R2. Presign route at `/api/r2/presign`. 25 listings with real AI-generated images.
- **Profile pages:** Avatar, header image, bio, social links, listing grid, owner mode, inbox tab.
- **Messaging:** Conversations + messages with Supabase Realtime. Unread badge in nav.
- **Festival Radar (homepage):** Pulls from DB (upcoming only, sorted by date). Cards link to /festivals/[slug]. "VIEW CALENDAR →" links to /festivals.
- **Festival Calendar:** /festivals — calendar widget (month view, click → festival page), editorial hero (next upcoming), full list with past section.
- **Festival Detail:** /festivals/[slug] — 3 tabs: Info (links), Who's Going (RSVP with role: attending/selling, profile cards), The Wall (corkboard posts, category filter, emoji reactions).
- **The Wall:** Any logged-in user can post. Each post has a required title (80 chars) + body (200 chars) + optional contact handle + category. Posts live forever. Reactions: ❤️ 🙏 🔥 😂 🫂.
- **Category pages:** Apparel/Music/Jewellery — filter bar, multi-select tags, sort, sticky header.
- **Lightbox:** Click image on listing detail → fullscreen overlay, arrows, keyboard, thumbnails.
- **Skeleton loading:** All pages show shimmer skeletons while data loads (never null).

---

## Database (Supabase live tables)

- `profiles` — 9 seed profiles
- `listings` — 25 listings (9 gear, 11 clothing, 5 accessories), all with R2 images
- `conversations` + `messages` — Realtime enabled
- `blocked_handles` — 56 system/route names blocked from registration
- `reserved_handles` — schema exists, empty
- `events` — 9 festivals seeded (Antaris, Ozora, Mo:Dem, Masters of Puppets, DROPS, Boom, Modular, Space Safari, Universo)
- `vendor_events` — RSVP table (profile_id, event_id, role: attending/selling)
- `notice_posts` — The Wall posts (title ≤80, body ≤200, category, contact_handle)
- `notice_reactions` — Emoji reactions on notice posts

---

## Known gaps (not yet built)

- Festival profile integration (attending festivals shown on user profile page)
- Edit profile page (full implementation)
- Edit listing page
- Admin approval queue (listings go live immediately)
- Pagination (all listings load at once — fine for now)
- True unread message count (badge = conversation count)
- Email notifications on new message
- Legal pages (`/privacy-policy`, `/terms-of-service`) — linked but don't exist
- Browse page ignores `?q=` search param
