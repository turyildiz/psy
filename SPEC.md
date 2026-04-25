# psy.market — Engineering Specification

**Version:** 1.1
**Date:** February 9, 2026
**Source:** REFINED_PRD.md v3.0
**Status:** Ready for Implementation

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Environment & Configuration](#2-environment--configuration)
3. [Project Structure](#3-project-structure)
4. [Database Schema](#4-database-schema)
5. [Server-Side Functions & Data Access](#5-server-side-functions--data-access)
6. [Authentication & Authorization](#6-authentication--authorization)
7. [Image Upload](#7-image-upload)
8. [Pages & Routing](#8-pages--routing)
9. [Browse & Discovery](#9-browse--discovery)
10. [Messaging System](#10-messaging-system)
11. [Admin System](#11-admin-system)
12. [Email Notifications](#12-email-notifications)
13. [SEO & Metadata](#13-seo--metadata)
14. [Validation](#14-validation)
15. [UI Patterns](#15-ui-patterns)
16. [Cron Jobs](#16-cron-jobs)
17. [Account Deletion](#17-account-deletion)
18. [Environment Variables Checklist](#18-environment-variables-checklist)
19. [Implementation Phases](#19-implementation-phases)

---

## 1. Architecture Overview

### 1.1 Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Framework | Next.js (App Router) | 14+ |
| Styling | Tailwind CSS + shadcn/ui | Latest |
| Database | Supabase PostgreSQL | Latest |
| Auth | Supabase Auth | Latest |
| File Storage | Supabase Storage | Latest |
| Real-time | Supabase Realtime | Latest |
| Cron | Supabase pg_cron | Latest |
| Email | Resend | Latest |
| Hosting | Vercel | Hobby plan |
| Toast Notifications | sonner | Latest |
| URL State | nuqs | Latest |
| Form Validation | Zod + react-hook-form + @hookform/resolvers | Latest |

### 1.2 Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| User model | Umbrella: User (private) + Profile (public) | Future-proof for V2 multi-profile |
| Foreign keys | `profile_id` (UUID) on all public entities | Profiles are the public-facing identity |
| Search | PostgreSQL full-text search (tsvector/tsquery) | Zero-ops, weighted ranking, sufficient for V1 |
| Pagination | Keyset (cursor) pagination | Efficient for infinite scroll, no offset drift |
| Validation | Shared Zod schemas (client + server) | Single source of truth, no drift |
| Image upload | Supabase Storage with direct client upload | Integrated auth, simple URLs |
| View count | Client-side `sessionStorage` guard | Simple, sufficient for V1 vanity metric |
| Real-time messaging | Supabase Realtime subscriptions | Native Supabase feature, instant delivery |
| Email notifications | 2-minute delayed check via Next.js API route | Avoids emailing users already in conversation |
| Loading states | Skeleton loaders | Polished, modern marketplace feel |
| Error handling | sonner toasts + inline error states | Toasts for mutations, inline for 404s/auth |
| Filter state | URL search params via `nuqs` | Shareable, bookmarkable, back-button-friendly |
| Middleware | Supabase Auth session + role check | Edge-level route protection |
| Account deletion | Database cascade via foreign keys | Simple, reliable with ON DELETE CASCADE |
| SEO | Next.js native `generateMetadata` + `sitemap.ts` | Zero extra dependencies |
| SSR strategy | Supabase server client for public pages, client-side for protected | SEO for public, reactivity for private |
| Country picker | Multi-select combobox with search (`cmdk`) | Handles 40+ countries gracefully |
| Auto-approve | Supabase pg_cron (hourly SQL job) | Free, runs in DB, no external service |

---

## 2. Environment & Configuration

### 2.1 Environment Variables (`.env.local`)

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://uabuhtrtommkfmlhseul.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Resend (uncomment when ready)
# RESEND_API_KEY=re_...
```

### 2.2 Required External Setup

| Service | Action Required |
|---------|----------------|
| Supabase Auth | Enable email/password provider. Enable Google OAuth (requires Google Cloud OAuth credentials). Set site URL and redirect URLs. |
| Supabase Storage | Create buckets: `avatars`, `listings`, `messages`. Set bucket policies (see Section 7). |
| Supabase Realtime | Enable Realtime on the `messages` table. |
| Supabase pg_cron | Enable the `pg_cron` extension. Create the auto-approve scheduled job (see Section 16). |
| Resend | Create account at resend.com. Create API key. Verify sender domain (`psy.market`) or use default sender for development. |
| Google OAuth | Create OAuth 2.0 credentials in Google Cloud Console. Add client ID and secret in Supabase Auth settings. |

---

## 3. Project Structure

```
psy-market/
├── app/
│   ├── (public)/                          # No auth required
│   │   ├── page.tsx                       # Landing page (/)
│   │   ├── browse/
│   │   │   └── page.tsx                   # Browse listings (/browse)
│   │   ├── listing/
│   │   │   └── [id]/
│   │   │       └── page.tsx               # Listing detail (/listing/[id])
│   │   ├── seller/
│   │   │   └── [handle]/
│   │   │       └── page.tsx               # Seller profile (/seller/[handle])
│   │   ├── privacy/
│   │   │   └── page.tsx                   # Privacy policy (/privacy)
│   │   └── terms/
│   │       └── page.tsx                   # Terms of service (/terms)
│   ├── (auth)/                            # Auth pages
│   │   ├── login/
│   │   │   └── page.tsx                   # Login form
│   │   ├── signup/
│   │   │   └── page.tsx                   # Sign up form
│   │   └── auth/
│   │       └── callback/
│   │           └── route.ts               # OAuth callback handler
│   ├── (protected)/                       # Auth required
│   │   ├── onboarding/
│   │   │   └── page.tsx                   # Profile completion (handle + display name)
│   │   ├── sell/
│   │   │   ├── page.tsx                   # Create listing (/sell)
│   │   │   └── [id]/
│   │   │       └── edit/
│   │   │           └── page.tsx           # Edit listing (/sell/[id]/edit)
│   │   └── dashboard/
│   │       ├── page.tsx                   # Dashboard overview (/dashboard)
│   │       ├── listings/
│   │       │   └── page.tsx               # My listings (/dashboard/listings)
│   │       ├── messages/
│   │       │   ├── page.tsx               # All conversations (/dashboard/messages)
│   │       │   └── [threadId]/
│   │       │       └── page.tsx           # Single thread (/dashboard/messages/[threadId])
│   │       ├── profile/
│   │       │   └── page.tsx               # Edit profile (/dashboard/profile)
│   │       └── settings/
│   │           └── page.tsx               # Settings (/dashboard/settings)
│   ├── (admin)/                           # Admin/super_admin role required
│   │   └── admin/
│   │       ├── page.tsx                   # Admin dashboard (/admin)
│   │       ├── listings/
│   │       │   └── page.tsx               # Approval queue (/admin/listings)
│   │       ├── users/
│   │       │   └── page.tsx               # User management (/admin/users)
│   │       └── featured/
│   │           └── page.tsx               # Featured management (/admin/featured)
│   ├── api/
│   │   ├── email/
│   │   │   └── route.ts                   # Email sending via Resend
│   │   └── cron/
│   │       └── auto-approve/
│   │           └── route.ts               # Backup cron endpoint (if pg_cron not available)
│   ├── sitemap.ts                         # Dynamic sitemap generation
│   ├── layout.tsx                         # Root layout (providers, navbar, footer)
│   └── globals.css                        # Tailwind imports, CSS variables
├── components/
│   ├── ui/                                # shadcn/ui primitives (button, input, card, etc.)
│   ├── listings/                          # Listing-specific components
│   │   ├── listing-card.tsx               # Card for browse grid
│   │   ├── listing-form.tsx               # Create/edit form
│   │   ├── listing-gallery.tsx            # Image gallery on detail page
│   │   ├── listing-filters.tsx            # Filter panel for browse
│   │   ├── listing-grid.tsx               # Infinite scroll grid
│   │   ├── featured-carousel.tsx          # Featured listings carousel
│   │   ├── listing-skeleton.tsx           # Skeleton loader for listing card
│   │   └── condition-badge.tsx            # Condition display badge
│   ├── messages/                          # Message-specific components
│   │   ├── thread-list.tsx                # Conversation list
│   │   ├── thread-view.tsx                # Single conversation
│   │   ├── message-bubble.tsx             # Individual message
│   │   └── message-composer.tsx           # Message input + image upload
│   ├── layout/                            # App shell components
│   │   ├── navbar.tsx                     # Top navigation bar
│   │   ├── footer.tsx                     # Site footer with legal links
│   │   ├── mobile-nav.tsx                 # Mobile navigation
│   │   └── sidebar.tsx                    # Dashboard sidebar
│   ├── profile/                           # Profile components
│   │   ├── profile-form.tsx               # Edit profile form
│   │   ├── avatar-upload.tsx              # Avatar upload widget
│   │   └── seller-card.tsx                # Seller info card on listing detail
│   ├── admin/                             # Admin components
│   │   ├── approval-card.tsx              # Listing review card
│   │   ├── user-table.tsx                 # User management table
│   │   └── stats-cards.tsx                # Analytics overview cards
│   ├── auth/                              # Auth components
│   │   ├── login-form.tsx                 # Login form
│   │   ├── signup-form.tsx                # Signup form
│   │   └── oauth-button.tsx               # Google OAuth button
│   └── shared/                            # Shared/generic components
│       ├── country-picker.tsx             # Multi-select country combobox
│       ├── image-upload.tsx               # Reusable image upload widget (Supabase Storage)
│       ├── empty-state.tsx                # Empty state display
│       ├── page-skeleton.tsx              # Full page skeleton
│       └── confirm-dialog.tsx             # Confirmation dialog
├── lib/
│   ├── supabase/
│   │   ├── client.ts                      # Browser Supabase client
│   │   ├── server.ts                      # Server component Supabase client
│   │   ├── middleware.ts                  # Middleware Supabase client
│   │   └── admin.ts                       # Service role client (server-only)
│   ├── utils.ts                           # General utilities (cn, formatPrice, etc.)
│   ├── validators.ts                      # Shared Zod schemas
│   ├── countries.ts                       # Country list with ISO codes and flag emojis
│   └── constants.ts                       # App-wide constants (categories, conditions, etc.)
├── hooks/
│   ├── use-profile.ts                     # Get current user's profile
│   ├── use-user.ts                        # Get current user (auth + role)
│   └── use-debounce.ts                    # Debounce hook for search input
├── types/
│   └── database.ts                        # Supabase generated types (from supabase gen types)
├── middleware.ts                           # Next.js middleware (auth + route protection)
├── tailwind.config.ts
├── next.config.js
├── package.json
├── tsconfig.json
├── REFINED_PRD.md
├── SPEC.md
└── USER_ROLES.md
```

---

## 4. Database Schema

### 4.1 SQL Schema

```sql
-- ============================================
-- psy.market Database Schema
-- Version: 1.1 (Supabase + Umbrella Model)
-- ============================================

-- Enable required extensions
create extension if not exists "pg_cron" with schema "pg_catalog";

-- ============================================
-- ENUMS
-- ============================================

create type user_role as enum ('user', 'admin', 'super_admin');
create type profile_type as enum ('personal', 'artist', 'label', 'festival');
create type listing_status as enum ('draft', 'pending', 'active', 'sold', 'rejected');
create type listing_condition as enum ('new', 'like_new', 'good', 'worn', 'vintage');
create type listing_category as enum ('clothing', 'accessories', 'gear', 'art', 'other');

-- ============================================
-- TABLES
-- ============================================

-- Users table (extends auth.users — private account data)
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'user',
  email_notifications boolean not null default true,
  stripe_account_id text,  -- V2
  created_at timestamptz not null default now()
);

-- Profiles table (public personas)
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type profile_type not null default 'personal',
  handle text not null unique,
  display_name text not null,
  bio text,
  avatar_url text,
  header_url text,  -- V2
  location text,
  social_links jsonb default '{}',
  is_creator boolean not null default false,
  is_verified boolean not null default false,  -- V2
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint handle_length check (char_length(handle) between 3 and 30),
  constraint handle_format check (handle ~ '^[a-zA-Z0-9_]+$'),
  constraint display_name_length check (char_length(display_name) between 1 and 100),
  constraint bio_length check (bio is null or char_length(bio) <= 500),
  constraint location_length check (location is null or char_length(location) <= 100)
);

-- Listings table
create table public.listings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null,
  price integer not null,  -- EUR cents
  condition listing_condition not null,
  size text not null,
  images text[] not null default '{}',
  category listing_category not null,
  tags text[] not null default '{}',
  ships_to text[] not null default '{}',
  status listing_status not null default 'draft',
  admin_notes text,
  is_featured boolean not null default false,
  view_count integer not null default 0,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint title_length check (char_length(title) between 5 and 100),
  constraint description_length check (char_length(description) between 20 and 2000),
  constraint price_range check (price between 50 and 5000000),
  constraint size_length check (char_length(size) between 1 and 20)
);

-- Messages table
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  thread_id text not null,
  sender_profile_id uuid not null references public.profiles(id) on delete cascade,
  receiver_profile_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  images text[] default '{}',
  read boolean not null default false,
  created_at timestamptz not null default now(),

  constraint content_length check (char_length(content) between 1 and 2000)
);

-- Favorites table (V2 prep — schema only, no UI in V1)
create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(profile_id, listing_id)
);

-- ============================================
-- INDEXES
-- ============================================

create index idx_profiles_user_id on public.profiles(user_id);
create index idx_profiles_handle on public.profiles(handle);

create index idx_listings_profile_id on public.listings(profile_id);
create index idx_listings_status on public.listings(status);
create index idx_listings_category on public.listings(category);
create index idx_listings_status_created on public.listings(status, created_at desc);
create index idx_listings_featured on public.listings(is_featured, status);
create index idx_listings_status_submitted on public.listings(status, submitted_at);

create index idx_messages_thread_id on public.messages(thread_id, created_at);
create index idx_messages_receiver_read on public.messages(receiver_profile_id, read);
create index idx_messages_listing_id on public.messages(listing_id);
create index idx_messages_sender on public.messages(sender_profile_id);

create index idx_favorites_profile_id on public.favorites(profile_id);
create index idx_favorites_listing_id on public.favorites(listing_id);

-- ============================================
-- FULL-TEXT SEARCH
-- ============================================

alter table public.listings add column search_vector tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'C')
  ) stored;

create index idx_listings_search on public.listings using gin(search_vector);

-- ============================================
-- AUTO-UPDATED TIMESTAMPS
-- ============================================

create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger tr_profiles_updated_at
  before update on public.profiles
  for each row execute function update_updated_at();

create trigger tr_listings_updated_at
  before update on public.listings
  for each row execute function update_updated_at();

-- ============================================
-- AUTH TRIGGER: Auto-create user + profile on signup
-- ============================================

create or replace function handle_new_user()
returns trigger as $$
declare
  new_user_id uuid;
begin
  -- Create public.users record
  insert into public.users (id, role, email_notifications, created_at)
  values (new.id, 'user', true, now());

  -- Create default profile (handle will be set during onboarding)
  insert into public.profiles (user_id, type, handle, display_name, created_at, updated_at)
  values (
    new.id,
    'personal',
    'user_' || substr(new.id::text, 1, 8),  -- Temporary handle
    coalesce(new.raw_user_meta_data->>'full_name', 'New User'),
    now(),
    now()
  );

  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

alter table public.users enable row level security;
alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.messages enable row level security;
alter table public.favorites enable row level security;

-- USERS policies
create policy "Users can read their own record"
  on public.users for select
  using (auth.uid() = id);

create policy "Service role can manage all users"
  on public.users for all
  using (auth.jwt()->>'role' = 'service_role');

-- PROFILES policies
create policy "Profiles are publicly readable"
  on public.profiles for select
  using (true);

create policy "Users can update their own profiles"
  on public.profiles for update
  using (auth.uid() = user_id);

create policy "Users can insert their own profiles"
  on public.profiles for insert
  with check (auth.uid() = user_id);

-- LISTINGS policies
create policy "Active and sold listings are publicly readable"
  on public.listings for select
  using (
    status in ('active', 'sold')
    or profile_id in (select id from public.profiles where user_id = auth.uid())
  );

create policy "Users can create listings for their own profiles"
  on public.listings for insert
  with check (
    profile_id in (select id from public.profiles where user_id = auth.uid())
  );

create policy "Users can update their own listings"
  on public.listings for update
  using (
    profile_id in (select id from public.profiles where user_id = auth.uid())
  );

create policy "Users can delete their own draft listings"
  on public.listings for delete
  using (
    status = 'draft'
    and profile_id in (select id from public.profiles where user_id = auth.uid())
  );

-- MESSAGES policies
create policy "Users can read messages they sent or received"
  on public.messages for select
  using (
    sender_profile_id in (select id from public.profiles where user_id = auth.uid())
    or receiver_profile_id in (select id from public.profiles where user_id = auth.uid())
  );

create policy "Authenticated users can send messages"
  on public.messages for insert
  with check (
    sender_profile_id in (select id from public.profiles where user_id = auth.uid())
  );

create policy "Users can mark messages as read"
  on public.messages for update
  using (
    receiver_profile_id in (select id from public.profiles where user_id = auth.uid())
  );

-- FAVORITES policies
create policy "Users can manage their own favorites"
  on public.favorites for all
  using (
    profile_id in (select id from public.profiles where user_id = auth.uid())
  );

-- ADMIN override policies (for admin operations via service role or admin check)
-- Admin operations use the service role client (bypasses RLS)
```

### 4.2 Full-Text Search Details

The `search_vector` column is a generated tsvector with weighted fields:
- **Weight A (highest):** `title` — exact title matches rank highest
- **Weight B:** `description` — description matches rank second
- **Weight C (lowest):** `tags` — tag matches rank third

Query example:
```sql
select *, ts_rank(search_vector, query) as rank
from public.listings, plainto_tsquery('english', 'psychedelic jacket') as query
where search_vector @@ query
  and status = 'active'
order by rank desc
limit 24;
```

### 4.3 Index Usage Map

| Index | Used By |
|-------|---------|
| `idx_profiles_user_id` | Resolve current user's profile, account deletion |
| `idx_profiles_handle` | Seller profile page, handle uniqueness |
| `idx_listings_profile_id` | Dashboard "My Listings", account deletion |
| `idx_listings_status` | Admin approval queue |
| `idx_listings_category` | Browse filters |
| `idx_listings_status_created` | Browse page (active listings, newest first) |
| `idx_listings_featured` | Featured carousel (featured + active) |
| `idx_listings_status_submitted` | pg_cron auto-approve job |
| `idx_listings_search` | Browse keyword search (GIN index) |
| `idx_messages_thread_id` | Thread view (all messages in a conversation) |
| `idx_messages_receiver_read` | Unread count badge |
| `idx_messages_listing_id` | Account deletion (cascade) |
| `idx_messages_sender` | Account deletion (cascade) |
| `idx_favorites_profile_id` | V2: user's favorites list |
| `idx_favorites_listing_id` | V2: favorite count per listing |

---

## 5. Server-Side Functions & Data Access

### 5.1 Supabase Client Setup

```typescript
// lib/supabase/client.ts — Browser client
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}

// lib/supabase/server.ts — Server component / route handler client
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createServerSupabaseClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return cookieStore.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        },
      },
    }
  );
}

// lib/supabase/admin.ts — Service role client (server-only, bypasses RLS)
import { createClient } from "@supabase/supabase-js";

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);
```

### 5.2 Data Access Patterns

**Profiles:**
- `getProfileByHandle(handle)` — Public seller profile page
- `getProfileByUserId(userId)` — Get current user's profile
- `isHandleAvailable(handle)` — Onboarding + profile edit
- `updateProfile(profileId, data)` — Profile edit form
- `createProfile(userId, data)` — Auto-created via DB trigger; onboarding updates it

**Listings:**
- `getListingById(id)` — Listing detail page
- `getListingWithSeller(id)` — Listing detail + seller profile join
- `getListingsByProfile(profileId, status?)` — Dashboard, seller profile
- `getActiveListings({ cursor, limit, filters, sort })` — Browse page
- `getFeaturedListings()` — Featured carousel
- `searchListings(query, filters)` — Browse keyword search
- `createListing(data)` — Create listing form
- `updateListing(id, data)` — Edit listing form
- `submitListing(id)` — Change draft → pending
- `markSold(id)` — Change active → sold
- `incrementViewCount(id)` — View tracking

**Messages:**
- `getMessagesByThread(threadId)` — Thread view
- `getThreadsForProfile(profileId)` — Message list
- `getUnreadCount(profileId)` — Navbar badge
- `sendMessage(data)` — Message composer
- `markThreadAsRead(threadId, profileId)` — On thread open

**Admin (via service role client):**
- `getPendingListings()` — Approval queue
- `approveListing(id)` — Set active
- `rejectListing(id, notes)` — Set rejected + notes
- `toggleFeatured(id)` — Toggle is_featured
- `getAllUsers(cursor, limit)` — User management
- `updateUserRole(userId, role)` — Promote/demote
- `getDashboardStats()` — Admin overview

---

## 6. Authentication & Authorization

### 6.1 Supabase Auth Setup

```typescript
// Sign up with email
const { data, error } = await supabase.auth.signUp({
  email,
  password,
  options: { emailRedirectTo: `${origin}/auth/callback` },
});

// Sign in with email
const { data, error } = await supabase.auth.signInWithPassword({
  email,
  password,
});

// Sign in with Google
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: "google",
  options: { redirectTo: `${origin}/auth/callback` },
});
```

### 6.2 OAuth Callback Route (`app/auth/callback/route.ts`)

```typescript
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  if (code) {
    const supabase = await createServerSupabaseClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/login?error=auth`);
}
```

### 6.3 Middleware (`middleware.ts`)

```typescript
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const publicRoutes = ["/", "/browse", "/listing", "/seller", "/privacy", "/terms", "/login", "/signup"];
const adminRoutes = ["/admin"];

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });
  const { pathname } = request.nextUrl;

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll(); },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();

  // Allow public routes
  const isPublic = publicRoutes.some((route) =>
    pathname === route || pathname.startsWith(route + "/")
  );
  if (isPublic || pathname.startsWith("/auth/")) return response;

  // Require auth for all other routes
  if (!user) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", pathname);
    return NextResponse.redirect(url);
  }

  // Check for incomplete profile → redirect to onboarding
  if (!pathname.startsWith("/onboarding")) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("handle")
      .eq("user_id", user.id)
      .single();

    if (profile?.handle?.startsWith("user_")) {
      const url = request.nextUrl.clone();
      url.pathname = "/onboarding";
      return NextResponse.redirect(url);
    }
  }

  // Admin route protection
  if (adminRoutes.some((route) => pathname.startsWith(route))) {
    const { data: userData } = await supabase
      .from("users")
      .select("role")
      .eq("id", user.id)
      .single();

    if (userData?.role !== "admin" && userData?.role !== "super_admin") {
      return NextResponse.redirect(new URL("/", request.url));
    }
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
```

### 6.4 Onboarding Flow

1. Supabase Auth creates `auth.users` record on signup.
2. Database trigger (`handle_new_user`) creates `public.users` + `public.profiles` with temporary handle (`user_XXXXXXXX`).
3. Middleware detects temporary handle → redirects to `/onboarding`.
4. User enters handle (real-time availability check, debounced 300ms) and display name.
5. On submit: update profile with real handle + display name.
6. Middleware sees real handle → allows through to requested page.

### 6.5 First Super Admin Setup

1. Owner signs up (normal flow).
2. Complete onboarding (set handle).
3. In Supabase dashboard SQL editor, run:
   ```sql
   update public.users set role = 'super_admin' where id = '<your-user-uuid>';
   ```
4. Refresh the page → middleware allows access to `/admin`.

---

## 7. Image Upload

### 7.1 Supabase Storage Buckets

| Bucket | Max Size | Max Count | Formats | Public |
|--------|----------|-----------|---------|--------|
| `avatars` | 2MB | 1 per profile | JPEG, PNG, WebP | Yes |
| `listings` | 5MB | 5 per listing | JPEG, PNG, WebP | Yes |
| `messages` | 5MB | 3 per message | JPEG, PNG, WebP | Yes |

### 7.2 Bucket Policies (SQL)

```sql
-- Avatars bucket: authenticated users can upload to their own folder
create policy "Avatar upload" on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Avatar public read" on storage.objects for select
  using (bucket_id = 'avatars');

-- Listings bucket: authenticated users can upload
create policy "Listing image upload" on storage.objects for insert
  with check (bucket_id = 'listings' and auth.role() = 'authenticated');

create policy "Listing image public read" on storage.objects for select
  using (bucket_id = 'listings');

-- Messages bucket: authenticated users can upload
create policy "Message image upload" on storage.objects for insert
  with check (bucket_id = 'messages' and auth.role() = 'authenticated');

create policy "Message image read by participants" on storage.objects for select
  using (bucket_id = 'messages' and auth.role() = 'authenticated');
```

### 7.3 Upload Flow (Listing Images)

1. User selects images in the listing form.
2. Client uploads directly to Supabase Storage via `supabase.storage.from('listings').upload(path, file)`.
3. Path format: `{profileId}/{listingId}/{filename}` (or `{profileId}/temp/{uuid}` before listing is created).
4. UI shows upload progress.
5. On completion, public URL is retrieved via `supabase.storage.from('listings').getPublicUrl(path)`.
6. User can remove an uploaded image (removes from form state; Storage cleanup is a V2 concern).
7. On form submit, image URLs are stored in the listings table `images` array.

---

## 8. Pages & Routing

### 8.1 Public Pages

#### Landing Page (`/`)
- **Server Component** with static content.
- Hero section with gradient background, tagline, and CTA buttons ("Browse" and "Start Selling").
- Category highlights (5 category cards linking to `/browse?category=X`).
- "How it works" section (3 steps: Browse → Contact → Trade).
- Footer with links to `/privacy`, `/terms`.

#### Browse Page (`/browse`)
- **Server Component** for initial data + **Client Component** for interactivity.
- SSR: Supabase server client preloads first 24 active listings + featured listings.
- Client: Supabase client for pagination and filter changes.
- Filter panel (sidebar on desktop, bottom sheet on mobile).
- URL search params via `nuqs`: `?category=clothing,accessories&condition=new,like_new&minPrice=1000&maxPrice=50000&size=M&shipsTo=DE&sort=newest&q=jacket`
- Featured carousel at top (only if featured listings exist).
- Empty state: "No listings found. Try adjusting your filters." with "Clear filters" link.

#### Listing Detail (`/listing/[id]`)
- **Server Component** with Supabase server client for SSR (SEO-critical: title, description, OG image).
- Image gallery: main image + thumbnails. Click to enlarge (lightbox modal).
- Listing info: title, price (formatted as €XX.XX), condition badge, size, category.
- Full description with line breaks preserved.
- Tags as chips.
- Shipping locations as country flags + names.
- Seller card: avatar, display name, handle (links to `/seller/[handle]`), location, member since date.
- "Contact Seller" button: if not authenticated → redirect to `/login` with `next` param. If authenticated → create/open thread.
- "Sold" overlay if status is `sold`.
- View count increment: check `sessionStorage` key `viewed_{listingId}`. If absent, call increment and set key.

#### Seller Profile (`/seller/[handle]`)
- **Server Component** with Supabase server client for SSR.
- Seller info: avatar, display name, handle, bio, location, member since, social links.
- Grid of seller's active listings.

#### Legal Pages (`/privacy`, `/terms`)
- **Server Components** with static content.
- Placeholder text covering required topics (see PRD Section 4.1.10).

### 8.2 Auth Pages

#### Login (`/login`)
- Custom form with email/password fields + Google OAuth button.
- Uses `supabase.auth.signInWithPassword()` and `supabase.auth.signInWithOAuth()`.
- Styled to match site theme.

#### Sign Up (`/signup`)
- Custom form with email/password fields + Google OAuth button.
- Uses `supabase.auth.signUp()`.
- Styled to match site theme.

### 8.3 Protected Pages

#### Onboarding (`/onboarding`)
- Single-page form: handle (required), display name (required), location (optional).
- Handle validation: 3-30 chars, alphanumeric + underscores, real-time availability check (debounced 300ms).
- On submit → update profile → redirect to `/dashboard`.

#### Create Listing (`/sell`)
- Multi-section form using `react-hook-form` + Zod validation.
- Sections: Images (upload first), Details (title, description, price, condition, size), Classification (category, tags), Shipping (country picker).
- Two submit actions: "Save as Draft" and "Submit for Review".

#### Edit Listing (`/sell/[id]/edit`)
- Same form as Create, pre-populated with existing data.
- Only accessible by the listing's seller (profile owner).
- If status is "rejected": show admin rejection notes in an alert banner. Submit button reads "Resubmit for Review".
- If status is "active": submit button reads "Save Changes" (no re-review).

#### Dashboard (`/dashboard`)
- Overview: quick stats (active listings, pending, messages).
- Links to sub-pages.

#### My Listings (`/dashboard/listings`)
- Tabbed view: All / Active / Pending / Draft / Rejected / Sold.
- Each listing shows: thumbnail, title, price, status badge, created date.
- Actions per listing: Edit, Mark as Sold (if active), Delete (if draft).

#### Messages (`/dashboard/messages`)
- Thread list: grouped by listing, sorted by most recent message.
- Each thread shows: listing thumbnail + title, other user's avatar + display name, last message preview (truncated), unread badge.

#### Message Thread (`/dashboard/messages/[threadId]`)
- Chat-style UI: messages displayed chronologically.
- Current user's messages on the right (purple), other user's on the left (slate).
- Message composer at bottom: text input + image upload button + send button.
- On page open: mark thread as read.
- Real-time: Supabase Realtime subscription on messages table filtered by thread_id.

#### Edit Profile (`/dashboard/profile`)
- Form: avatar upload, handle, display name, bio, location, social links, creator toggle.

#### Settings (`/dashboard/settings`)
- Email notifications toggle.
- "Delete Account" button → confirmation dialog → calls delete cascade.

### 8.4 Admin Pages

#### Admin Dashboard (`/admin`)
- Stats cards: pending listings count, total active listings, total users, featured count.
- Quick link to approval queue if pending > 0.

#### Approval Queue (`/admin/listings`)
- List of pending listings sorted by submitted_at ASC (oldest first).
- Each card shows: all listing images, title, description, price, condition, category, seller info.
- Two action buttons: "Approve" (green) and "Reject" (red).
- Reject opens a modal: textarea for rejection notes (min 10 chars), "Confirm Reject" button.

#### User Management (`/admin/users`)
- Table: avatar, display name, handle, email, role, listings count, joined date, actions.
- Actions dropdown: View Profile, Ban User, Change Role (super_admin only).

#### Featured Management (`/admin/featured`)
- Search/browse active listings.
- Toggle featured flag per listing.
- Show currently featured listings at top.

---

## 9. Browse & Discovery

### 9.1 Filter Implementation

All filter state managed via URL search params using `nuqs`.

```typescript
// hooks/use-browse-filters.ts
import { useQueryStates, parseAsArrayOf, parseAsString, parseAsInteger } from "nuqs";

export function useBrowseFilters() {
  return useQueryStates({
    category: parseAsArrayOf(parseAsString).withDefault([]),
    condition: parseAsArrayOf(parseAsString).withDefault([]),
    minPrice: parseAsInteger,
    maxPrice: parseAsInteger,
    size: parseAsString,
    shipsTo: parseAsString,
    sort: parseAsString.withDefault("newest"),
    q: parseAsString,
  });
}
```

### 9.2 Sort Options

| Sort Key | Label | SQL Implementation |
|----------|-------|--------------------|
| `newest` | Newest First | `ORDER BY created_at DESC` |
| `price_asc` | Price: Low to High | `ORDER BY price ASC` |
| `price_desc` | Price: High to Low | `ORDER BY price DESC` |

### 9.3 Infinite Scroll

1. Initial page load: server component fetches first 24 listings.
2. Client stores last item's `created_at` (or `price`) as cursor.
3. `IntersectionObserver` on a sentinel element at bottom of grid.
4. When sentinel enters viewport → fetch next 24 with cursor filter.
5. When fewer than 24 results returned → stop loading.

### 9.4 Featured Carousel

- Horizontal scrollable row using CSS `overflow-x: auto` with `scroll-snap-type: x mandatory`.
- Each card: listing image, title, price, seller name. Subtle purple glow border (`ring-purple-600/30`).
- Only rendered if featured listings query returns 1+ results.
- Max 20 featured listings displayed.

---

## 10. Messaging System

### 10.1 Thread Creation

When a buyer clicks "Contact Seller":
1. Generate `threadId`: `{listingId}_{buyerProfileId}_{sellerProfileId}`.
2. Check if thread already exists (query by `thread_id`).
3. If exists → navigate to existing thread.
4. If not → navigate to thread page with empty state, first message creates the thread.

### 10.2 Real-time Subscriptions

```typescript
// In thread view component
useEffect(() => {
  const channel = supabase
    .channel(`thread:${threadId}`)
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "messages",
        filter: `thread_id=eq.${threadId}`,
      },
      (payload) => {
        setMessages((prev) => [...prev, payload.new as Message]);
      }
    )
    .subscribe();

  return () => { supabase.removeChannel(channel); };
}, [threadId]);
```

### 10.3 Message Display

```
[Listing reference header: thumbnail + title + price]
─────────────────────────────────
                    [Buyer message bubble, right-aligned, purple bg]
                    12:30 PM ✓✓ (read)

[Seller message bubble, left-aligned, slate bg]
12:35 PM

                    [Buyer image message]
                    [Thumbnail, click to enlarge]
                    12:40 PM ✓ (sent)
─────────────────────────────────
[Message composer: text input | 📎 image | Send button]
```

### 10.4 Read Receipts

- When user opens a thread page, update all messages where `receiver_profile_id = currentProfileId` and `read = false` to `read = true`.
- In the message UI: single check (✓) for sent, double check (✓✓) for read.

### 10.5 Link Detection

- Use a regex to detect URLs in message content: `/https?:\/\/[^\s]+/g`
- Render detected URLs as `<a>` tags with `target="_blank"` and `rel="noopener noreferrer"`.
- No rich link previews in V1.

---

## 11. Admin System

### 11.1 Authorization Check

Admin operations use the **service role client** (`supabaseAdmin`) which bypasses RLS. The calling Next.js server action or API route must first verify the user's role:

```typescript
async function requireAdmin() {
  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { data: userData } = await supabase
    .from("users")
    .select("role")
    .eq("id", user.id)
    .single();

  if (userData?.role !== "admin" && userData?.role !== "super_admin") {
    throw new Error("Unauthorized: admin access required");
  }

  return { user, role: userData.role };
}

async function requireSuperAdmin() {
  const { user, role } = await requireAdmin();
  if (role !== "super_admin") {
    throw new Error("Unauthorized: super admin access required");
  }
  return { user, role };
}
```

### 11.2 Approval Queue UI

- Default view: pending listings sorted oldest first.
- Each listing card is expandable to show full details.
- Approve: single click → green success toast "Listing approved".
- Reject: opens modal with textarea (min 10, max 1000 chars) → "Confirm Reject" → red toast.
- After action, listing disappears from the queue (re-fetch or optimistic update).

---

## 12. Email Notifications

### 12.1 Email Templates

All emails sent via Resend API from Next.js API routes. Plain HTML emails (no React Email in V1).

#### New Message Email
```
From: psy.market <noreply@psy.market>
Subject: New message about "{listingTitle}"

Hi {recipientDisplayName},

{senderDisplayName} sent you a message about "{listingTitle}".

View the conversation: {baseUrl}/dashboard/messages/{threadId}

—
psy.market
You're receiving this because you have email notifications enabled.
Manage your preferences: {baseUrl}/dashboard/settings
```

#### Listing Approved Email
```
From: psy.market <noreply@psy.market>
Subject: Your listing "{listingTitle}" has been approved!

Hi {sellerDisplayName},

Your listing "{listingTitle}" has been approved and is now live on psy.market.

View your listing: {baseUrl}/listing/{listingId}

—
psy.market
```

#### Listing Rejected Email
```
From: psy.market <noreply@psy.market>
Subject: Your listing "{listingTitle}" needs changes

Hi {sellerDisplayName},

Your listing "{listingTitle}" was not approved. Here's the feedback:

"{adminNotes}"

You can edit and resubmit your listing: {baseUrl}/sell/{listingId}/edit

—
psy.market
```

### 12.2 Email Sending Logic

```typescript
// app/api/email/route.ts
import { Resend } from "resend";
import { supabaseAdmin } from "@/lib/supabase/admin";

const resend = new Resend(process.env.RESEND_API_KEY);

export async function POST(request: Request) {
  const { type, messageId, listingId } = await request.json();

  if (type === "new_message") {
    // 1. Fetch message
    const { data: message } = await supabaseAdmin
      .from("messages")
      .select("*, listing:listings(title)")
      .eq("id", messageId)
      .single();

    if (!message || message.read) return Response.json({ skipped: true });

    // 2. Fetch receiver's profile + user
    const { data: receiverProfile } = await supabaseAdmin
      .from("profiles")
      .select("display_name, user_id")
      .eq("id", message.receiver_profile_id)
      .single();

    const { data: receiverUser } = await supabaseAdmin
      .from("users")
      .select("email_notifications")
      .eq("id", receiverProfile?.user_id)
      .single();

    if (!receiverUser?.email_notifications) return Response.json({ skipped: true });

    // 3. Get email from auth.users
    const { data: { user: authUser } } = await supabaseAdmin.auth.admin.getUserById(receiverProfile!.user_id);

    // 4. Send email via Resend
    await resend.emails.send({
      from: "psy.market <noreply@psy.market>",
      to: authUser!.email!,
      subject: `New message about "${message.listing.title}"`,
      html: `...`, // Template from Section 12.1
    });
  }

  return Response.json({ sent: true });
}
```

---

## 13. SEO & Metadata

### 13.1 `generateMetadata` per Page

#### Landing Page (`/`)
```typescript
export const metadata: Metadata = {
  title: "psy.market — Psytrance Fashion Marketplace",
  description: "Buy and sell psytrance fashion, festival clothing, and psychedelic art. The global marketplace for the psytrance community.",
};
```

#### Listing Detail (`/listing/[id]`)
```typescript
export async function generateMetadata({ params }): Promise<Metadata> {
  const supabase = await createServerSupabaseClient();
  const { data: listing } = await supabase
    .from("listings")
    .select("title, description, images")
    .eq("id", params.id)
    .single();

  if (!listing) return { title: "Listing Not Found — psy.market" };

  return {
    title: `${listing.title} — psy.market`,
    description: listing.description.slice(0, 160),
    openGraph: {
      title: listing.title,
      description: listing.description.slice(0, 160),
      images: [listing.images[0]],
      type: "website",
    },
  };
}
```

### 13.2 Sitemap (`app/sitemap.ts`)

```typescript
import { supabaseAdmin } from "@/lib/supabase/admin";

export default async function sitemap() {
  const { data: listings } = await supabaseAdmin
    .from("listings")
    .select("id, updated_at")
    .eq("status", "active");

  const listingUrls = (listings ?? []).map((listing) => ({
    url: `https://psy.market/listing/${listing.id}`,
    lastModified: new Date(listing.updated_at),
    changeFrequency: "weekly" as const,
    priority: 0.8,
  }));

  return [
    { url: "https://psy.market", changeFrequency: "daily", priority: 1 },
    { url: "https://psy.market/browse", changeFrequency: "daily", priority: 0.9 },
    { url: "https://psy.market/privacy", changeFrequency: "monthly", priority: 0.3 },
    { url: "https://psy.market/terms", changeFrequency: "monthly", priority: 0.3 },
    ...listingUrls,
  ];
}
```

---

## 14. Validation

### 14.1 Shared Zod Schemas (`lib/validators.ts`)

```typescript
import { z } from "zod";

// Handle (was username)
export const handleSchema = z
  .string()
  .min(3, "Handle must be at least 3 characters")
  .max(30, "Handle must be at most 30 characters")
  .regex(/^[a-zA-Z0-9_]+$/, "Handle can only contain letters, numbers, and underscores");

// Profile
export const profileSchema = z.object({
  handle: handleSchema,
  display_name: z.string().min(1, "Display name is required").max(100, "Display name must be at most 100 characters"),
  bio: z.string().max(500, "Bio must be at most 500 characters").optional().or(z.literal("")),
  location: z.string().max(100, "Location must be at most 100 characters").optional().or(z.literal("")),
  social_links: z
    .object({
      instagram: z.string().url("Must be a valid URL").optional().or(z.literal("")),
      facebook: z.string().url("Must be a valid URL").optional().or(z.literal("")),
      website: z.string().url("Must be a valid URL").optional().or(z.literal("")),
    })
    .optional(),
  is_creator: z.boolean().default(false),
});

// Listing
export const listingSchema = z.object({
  title: z.string().min(5, "Title must be at least 5 characters").max(100, "Title must be at most 100 characters"),
  description: z.string().min(20, "Description must be at least 20 characters").max(2000, "Description must be at most 2,000 characters"),
  price: z.number().int("Price must be a whole number (cents)").min(50, "Minimum price is €0.50").max(5_000_000, "Maximum price is €50,000"),
  condition: z.enum(["new", "like_new", "good", "worn", "vintage"]),
  size: z.string().min(1, "Size is required").max(20, "Size must be at most 20 characters"),
  images: z.array(z.string().url()).min(1, "At least 1 image is required").max(5, "Maximum 5 images"),
  category: z.enum(["clothing", "accessories", "gear", "art", "other"]),
  tags: z.array(
    z.string().max(30, "Each tag must be at most 30 characters").regex(/^[a-zA-Z0-9-]+$/, "Tags can only contain letters, numbers, and hyphens")
  ).max(10, "Maximum 10 tags").default([]),
  ships_to: z.array(z.string()).min(1, "At least one shipping location is required"),
});

// Message
export const messageSchema = z.object({
  content: z.string().min(1, "Message cannot be empty").max(2000, "Message must be at most 2,000 characters"),
  images: z.array(z.string().url()).max(3, "Maximum 3 images per message").optional(),
});

// Admin rejection
export const rejectionSchema = z.object({
  admin_notes: z.string().min(10, "Rejection notes must be at least 10 characters").max(1000, "Rejection notes must be at most 1,000 characters"),
});
```

### 14.2 Price Display Utility

```typescript
// lib/utils.ts
export function formatPrice(cents: number): string {
  return new Intl.NumberFormat("en-EU", {
    style: "currency",
    currency: "EUR",
  }).format(cents / 100);
}
```

---

## 15. UI Patterns

### 15.1 Color Tokens (Tailwind)

| Token | Tailwind Class | Value |
|-------|---------------|-------|
| Background | `bg-slate-950` | `#020617` |
| Surface | `bg-slate-900/50` | — |
| Primary | `bg-purple-600` | `#9333ea` |
| Accent Teal | `text-teal-400` | `#2dd4bf` |
| Accent Pink | `text-pink-500` | `#ec4899` |
| Text Primary | `text-slate-50` | `#f8fafc` |
| Text Secondary | `text-slate-400` | `#94a3b8` |
| Border | `border-slate-800` | `#1e293b` |
| Error | `text-red-500` | `#ef4444` |
| Success | `text-green-500` | `#22c55e` |
| Warning | `text-amber-500` | `#f59e0b` |

### 15.2 Component Patterns

#### Card
```html
<div class="rounded-2xl bg-slate-900/50 border border-slate-800 p-4">
  <!-- Content -->
</div>
```

#### Primary Button
```html
<button class="rounded-xl bg-purple-600 hover:bg-purple-700 text-white px-6 py-2.5 font-medium transition-colors">
  Label
</button>
```

#### Status Badge
```typescript
const badgeStyles = {
  active: "bg-green-500/10 text-green-500 border-green-500/20",
  pending: "bg-amber-500/10 text-amber-500 border-amber-500/20",
  rejected: "bg-red-500/10 text-red-500 border-red-500/20",
  sold: "bg-slate-500/10 text-slate-400 border-slate-500/20",
  draft: "bg-slate-600/10 text-slate-500 border-slate-600/20",
};
```

#### Featured Card
```html
<div class="rounded-2xl bg-slate-900/50 border border-purple-600/30 ring-1 ring-purple-600/20 p-4">
  <!-- Purple glow distinguishes from regular cards -->
</div>
```

### 15.3 Skeleton Loaders

```html
<div class="rounded-2xl bg-slate-900/50 border border-slate-800 p-4 animate-pulse">
  <div class="aspect-square rounded-xl bg-slate-800 mb-3" />
  <div class="h-4 bg-slate-800 rounded w-3/4 mb-2" />
  <div class="h-4 bg-slate-800 rounded w-1/4" />
</div>
```

### 15.4 Toast Patterns

```typescript
import { toast } from "sonner";

toast.success("Listing submitted for review");
toast.error("Failed to send message. Please try again.");
```

### 15.5 Responsive Breakpoints

| Breakpoint | Layout |
|------------|--------|
| Mobile (< 640px) | Single column, bottom sheet filters, stacked cards |
| Tablet (640px–1024px) | 2-column grid, collapsible sidebar |
| Desktop (> 1024px) | 3-4 column grid, persistent sidebar filters |

### 15.6 Empty States

| Page | Empty State Message | Action |
|------|-------------------|--------|
| Browse (no results) | "No listings found. Try adjusting your filters." | "Clear filters" link |
| Browse (no listings) | "No listings yet. Be the first to sell!" | "Start Selling" CTA |
| My Listings | "You haven't created any listings yet." | "Create Listing" CTA |
| Messages | "No messages yet. Contact a seller to start a conversation." | "Browse Listings" CTA |
| Admin Queue (empty) | "No listings pending review." | — |

---

## 16. Cron Jobs

### 16.1 Auto-Approve Pending Listings (pg_cron)

**Schedule:** Every 1 hour.

```sql
select cron.schedule(
  'auto-approve-pending-listings',
  '0 * * * *',
  $$
  update public.listings
  set status = 'active', updated_at = now()
  where status = 'pending'
  and submitted_at < now() - interval '24 hours'
  $$
);
```

To verify the job is scheduled:
```sql
select * from cron.job;
```

---

## 17. Account Deletion

### 17.1 Deletion Flow

Thanks to `ON DELETE CASCADE` on all foreign keys, deletion is straightforward:

1. Delete from `public.profiles` where `user_id = X` → cascades to listings, messages, favorites.
2. Delete from `public.users` where `id = X`.
3. Delete Supabase Auth account via admin API: `supabaseAdmin.auth.admin.deleteUser(userId)`.

```typescript
// Server action for account deletion
async function deleteAccount() {
  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  // Cascade: profiles → listings, messages, favorites
  await supabaseAdmin.from("profiles").delete().eq("user_id", user.id);
  await supabaseAdmin.from("users").delete().eq("id", user.id);
  await supabaseAdmin.auth.admin.deleteUser(user.id);
}
```

### 17.2 Confirmation UI

```
┌─────────────────────────────────────┐
│  ⚠ Delete Account                   │
│                                     │
│  This will permanently delete:      │
│  • Your profile                     │
│  • All your listings                │
│  • All your messages                │
│                                     │
│  This action cannot be undone.      │
│                                     │
│  [Cancel]  [Delete My Account]      │
│            (red, destructive)       │
└─────────────────────────────────────┘
```

---

## 18. Environment Variables Checklist

| Variable | Required | Source | Status |
|----------|----------|--------|--------|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Supabase Dashboard → Settings → API | Configured |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Yes | Supabase Dashboard → Settings → API | Configured |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Supabase Dashboard → Settings → API | Configured |
| `RESEND_API_KEY` | Yes | Resend Dashboard | TODO |

---

## 19. Implementation Phases

### Phase P0: Foundation
**Files:** `lib/supabase/*`, `middleware.ts`, `app/layout.tsx`, `app/(auth)/**`, `app/(protected)/onboarding/**`, `types/database.ts`
- Supabase schema deployment (tables, enums, indexes, RLS, triggers)
- Supabase Auth setup (email + Google OAuth)
- Supabase client utilities (browser, server, middleware, admin)
- Next.js middleware (auth + route protection + onboarding redirect)
- Root layout with Supabase auth provider
- Login / Sign up pages (custom forms)
- OAuth callback route
- Onboarding page (handle + display name setup)
- **Depends on:** Supabase project configured, Google OAuth credentials

### Phase P1: Listings & Profiles
**Files:** `lib/validators.ts`, `lib/countries.ts`, `lib/constants.ts`, `lib/utils.ts`, `components/listings/**`, `components/profile/**`, `components/shared/image-upload.tsx`, `app/(protected)/sell/**`, `app/(public)/listing/**`, `app/(public)/seller/**`
- Supabase Storage buckets (avatars, listings, messages) + policies
- Shared Zod validation schemas
- Country list with ISO codes and flags
- Constants (categories, conditions)
- Utility functions (formatPrice, cn)
- Image upload component (Supabase Storage)
- Create listing form
- Edit listing form
- Listing detail page (SSR)
- Seller public profile page (SSR)
- **Depends on:** P0

### Phase P2: Admin System
**Files:** `components/admin/**`, `app/(admin)/**`, `app/api/email/**`
- Admin authorization helpers (requireAdmin, requireSuperAdmin)
- Approval queue (pending listings FIFO)
- Approve / Reject mutations + UI
- pg_cron auto-approve job
- Admin dashboard stats
- User management table
- Featured listing toggle
- Email notifications for approval/rejection (Resend)
- **Depends on:** P1

### Phase P3: Browse & Discovery
**Files:** `components/listings/listing-filters.tsx`, `components/listings/listing-grid.tsx`, `components/listings/featured-carousel.tsx`, `components/shared/country-picker.tsx`, `hooks/use-browse-filters.ts`, `app/(public)/browse/**`
- Browse page with SSR preload
- Infinite scroll (keyset pagination)
- Filter panel (category, condition, price, size, shipping)
- URL search params via `nuqs`
- PostgreSQL full-text search
- Sort (newest, price asc/desc)
- Featured carousel
- Empty states
- **Depends on:** P1, P2 (for featured listings)

### Phase P4: Messaging
**Files:** `components/messages/**`, `app/(protected)/dashboard/messages/**`
- Message insert + queries
- Thread list query (grouped by listing, sorted by recency)
- Unread count query (for navbar badge)
- Thread view with Supabase Realtime subscriptions
- Message composer (text + image upload)
- Read receipts (single/double check)
- Link auto-detection
- Delayed email notifications (2-min check via Resend)
- **Depends on:** P1, P2 (for email)

### Phase P5: User Dashboard
**Files:** `components/layout/sidebar.tsx`, `app/(protected)/dashboard/**`
- Dashboard overview page
- My Listings page (tabbed by status)
- My Messages integration (links to P4 pages)
- Edit Profile page
- Settings page (email toggle, account deletion)
- Account deletion cascade
- **Depends on:** P1, P4

### Phase P6: Polish & SEO
**Files:** `app/(public)/privacy/**`, `app/(public)/terms/**`, `app/sitemap.ts`, `components/layout/**`
- Privacy Policy page
- Terms of Service page
- Dynamic metadata (`generateMetadata`) on all pages
- Open Graph tags for listing detail pages
- Sitemap generation
- Responsive polish (mobile nav, breakpoints)
- Footer with legal links
- **Depends on:** All previous phases

---

**Document Owner:** Turgay Yildiz
**Engineer:** Gonzo AI (Nettmedia)
**Last Updated:** February 9, 2026
**Status:** Ready for Implementation
