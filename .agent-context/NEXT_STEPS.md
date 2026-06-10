# psy.market — Next Steps

Last updated: 2026-06-07 by Claude

---

## This weekend (2026-06-07/08) — Festival Calendar + Notice Board

### 1. Festival Calendar

**DB schema — run in Supabase SQL editor:**
```sql
CREATE TABLE festivals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  location text NOT NULL,
  date_start date NOT NULL,
  date_end date,
  image_url text,
  description text,
  website_url text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE festival_rsvps (
  festival_id uuid REFERENCES festivals(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (festival_id, profile_id)
);

ALTER TABLE festival_rsvps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own rsvps" ON festival_rsvps
  USING (profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()))
  WITH CHECK (profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()));
```

**Seed data (migrate from homepage hardcoded):**
- Boom Festival | Aug 12–18 | Idanha-a-Nova, Portugal
- Ozora Festival | Jul 28–Aug 3 | Ozora, Hungary
- Universo Paralello | Dec 27–Jan 3 | Bahia, Brazil
- Antaris Project | Jul 3–7 | Brandenburg, Germany
- Masters of Puppets | Aug 6–10 | Leeuwarden, Netherlands
- DROPS Festival | Aug 11–16 | Slovenia | header image sent by Turgay via Telegram

**Pages:**
- `/festivals` — card grid sorted by date, filter by month, search
- `/festivals/[slug]` — hero image, date/location, description, website link, RSVP button, "Who's going" (profile cards), related listings
- Homepage "VIEW CALENDAR →" → `/festivals`

**RSVP flow:** Logged-in seller clicks "I'll be there" → inserts into `festival_rsvps` → profile card appears in "Who's going" → can un-RSVP

**Admin:** Turgay adds festivals directly in Supabase table editor (no public creation)

---

### 2. Festival Notice Board

Digital version of the physical festival corkboard — one of the most loved community rituals.

**DB schema:**
```sql
CREATE TABLE notice_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  festival_id uuid REFERENCES festivals(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  category text NOT NULL, -- rideshare, lost_found, looking_for, giving_away, shoutout
  body text NOT NULL CHECK (length(body) <= 200),
  contact_handle text,
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);
```

**Categories:** Rideshare / Lost & Found / Looking For / Giving Away Free / Shoutout

**Rules:** Login required to post. Posts auto-expire when festival ends (or 2 weeks). Reactions only (no comment threads).

**Design:** Corkboard aesthetic with pinned paper cards.

**Placement:** Tab on each `/festivals/[slug]` page. Possibly standalone `/board` later.

---

## After festival sprint

### High priority
- Edit profile page (`/profile/edit`) — button exists, page not built
- Edit listing page (`/listing/[id]/edit`) — icon exists, page not built
- Fix browse page search (`?q=` param currently ignored)
- Legal pages (`/privacy-policy`, `/terms-of-service`) — linked from signup but don't exist

### Medium priority
- True unread message count (badge currently = conversation count, not unread)
- Email notification when user receives a message (Resend/SMTP)
- Posts feature on profile (V1: photos + video clips ≤2min + YouTube/Vimeo embeds)

### Deferred / future
- Pagination across all listing pages
- Admin approval queue (listings currently go live immediately)
- Music download sales (V1.5) — signed R2 download URLs, Bandcamp-style pricing
- Ticket sales system (V2) — Stripe + QR codes for festival door staff
- Multi-profile per user (V2)
- Follows + feed (V2)
