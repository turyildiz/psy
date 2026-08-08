# Multi-Identity / Multi-Profile Research

> **Status: read-only research note. No product, schema, scope, or implementation decisions have been made by this document.**

**Research date:** 2026-08-08
**Scope:** All 33 files under `docs/` (including both PDFs), relevant project-context records, current application code, captured schema/audit artifacts, and the repository's database migration packages.
**Repository changes made during research:** None other than this requested research note.

## Executive summary

The multiple-identity use case was explicitly discussed early in planning. The original “Umbrella Model” proposed one private master account controlling unlimited public personas, including separate personal, DJ/artist, record-label, and shop identities through a profile switcher.

The later V1 plan deliberately deferred this capability to V2. According to the repository's latest recorded live database verification, the database currently enforces **one profile per auth user** through a unique index on `public.profiles(user_id)`. Current application flows also assume exactly one profile for each user and have no profile switcher or `activeProfileId` implementation.

The underlying model is partly future-ready because listings, messages, posts, reactions, and other public activity generally reference `profile_id` rather than the private user account. Multi-profile support would nevertheless require a coordinated database and application change.

## Research coverage

The review covered:

- all 33 files under `docs/`;
- `docs/REFINED_PRD.md`;
- `docs/V1_DECISIONS.md`;
- `docs/USER_ROLES.md`;
- `docs/SPEC.md`;
- `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md`;
- Wall/post proposals and package reports;
- archived/backed-up planning files in `docs/`;
- `docs/psy-market-v1-status-report-2026-07-12.pdf`;
- the image-only nine-page `docs/psy-market-refined-prd-v3.pdf`, whose pages were extracted and visually/OCR reviewed;
- `supabase/migrations-proposal.md` and Chunk 2 apply/rollback SQL;
- captured schema, enum, index, and duplicate-profile audit artifacts;
- current profile lookup, editing, listing, messaging, auth, and Header code;
- current shared application types.

The image-only refined PRD PDF repeats the relevant V1/V2 decisions found in `REFINED_PRD.md`.

## Findings at a glance

| Question | Finding |
|---|---|
| Was multi-identity support discussed? | Yes, explicitly and in detail in `docs/USER_ROLES.md`. |
| Was the exact DJane + label + jewellery-brand example found? | No, but very similar hybrid-DJ and multi-shop examples were found. |
| Original architecture | One master account managing unlimited public personas. |
| Current V1 decision | One profile per user. |
| Planned V2 direction | Multiple profiles plus a profile switcher. |
| Current database cardinality | One `profiles` row per `user_id`, enforced by a unique index. |
| Current profile types | `personal`, `artist`, `label`, `festival`. |
| Current vendor profile type | None; `vendor` is not in the implemented enum. |
| Current profile switcher | Not implemented. |
| Current `activeProfileId` state | Not implemented outside the old planning document. |
| Current code assumptions | Multiple flows query `profiles.user_id` with `.single()` or otherwise select one row. |

# 1. Documentation findings and exact quotes

## 1.1 Original multi-profile/persona design

### `docs/USER_ROLES.md:1-20`

This is the clearest early treatment of the requirement:

> “Psy.market utilizes a **One-to-Many (Parent-Child)** relationship between Accounts and Public Profiles. This architecture separates the *Legal Entity* (User) from the *Public Persona* (Profile), allowing a single user to manage multiple distinct identities (e.g., a \"Personal Buyer\" profile, a \"DJ Artist\" profile, and a \"Record Label\" profile) without multiple logins.”

It defines profiles as personas:

> “#### Level 2: The Personas (`Profile`)”

> “**Definition:** The public-facing identity used to interact with the marketplace.”

> “**Cardinality:** N (Unlimited) per Master Account.”

### `docs/USER_ROLES.md:24-32`

It includes a concrete hybrid-identity example:

> “**Case A: The \"Hybrid\" User (John Doe)**”

> “*As John, I want to buy a second-hand jacket without my fans knowing, but I also want to sell my DJ mixes under my artist name.*”

> “**Solution:** John creates a default \"Personal\" profile for buying. He creates a second \"Artist\" profile (`@dj-jd`) for selling. His purchase history is linked to his Personal profile; his sales history is linked to his Artist profile.”

It also contains a one-login/multiple-brands example:

> “*As a merchandise printer, I manage shops for 3 different festivals. I need to switch between them easily to fulfill orders.*”

> “**Solution:** The user logs in once. They use a \"Profile Switcher\" in the dashboard to toggle between `@psy-fi-shop`, `@ozora-merch`, and `@my-print-shop`. All notifications are centralized but tagged by profile.”

These examples are conceptually close to one person acting as a DJane, label head, and jewellery-brand vendor under different names.

### `docs/USER_ROLES.md:38-54`

The proposed workflow was explicit:

> “System automatically generates **one default profile** (Type: `Personal`) using the user's name.”

> “User can select \"Create New Profile\" from the settings menu.”

> “**Type:** `Buyer` (Default), `Artist` (DJ/Producer), or `Vendor` (Shop/Label).”

> “The frontend must maintain an `activeProfileId` in the application state.”

> “All actions (Listing an item, Sending a message, Liking a product) must tag the `activeProfileId`, **not** just the `userId`.”

> “**UI:** A dropdown menu in the navbar displaying the avatar of the currently active profile.”

### `docs/USER_ROLES.md:63-76`

Its proposed profile schema says:

> “`user_id` | UUID | Foreign Key to `auth.users`. (The Owner).”

> “`type` | ENUM | `personal`, `artist`, `label`, `festival`.”

This early document does not place a uniqueness rule on `user_id`, consistent with its intended one-to-many relationship.

## 1.2 Later PRD decision: one profile in V1, multiple profiles in V2

### `docs/REFINED_PRD.md:26-29`

The change log records the scope decision:

> “Introduced Umbrella Model (User + Profile) | Future-proof for multi-profile in V2”

> “All entities now reference `profile_id` not `user_id` | Umbrella model architecture”

> “V1 scoped to one profile per user | Keep MVP simple, easy V2 upgrade”

> “Added multi-profile, profile switcher to V2 scope | Deferred complexity”

### `docs/REFINED_PRD.md:102-116`

The architecture section says:

> “**Level 2 — Profile (`Persona`):**”

> “Public-facing identity used to interact with the marketplace.”

> “All marketplace actions (listings, messages) are tied to a **profile**, not the user account.”

> “**V1:** One profile per user, auto-created on signup. Type defaults to `personal`.”

> “**V2:** Multiple profiles per user (personal, artist, label, festival) with a profile switcher.”

### `docs/REFINED_PRD.md:250-253`

Under post-launch features:

> “**Multiple profiles per user** + profile switcher (personal, artist, label, festival)”

### `docs/REFINED_PRD.md:574-580`

The resolved-decision table confirms:

> “User/Profile model | Umbrella (User + Profile) | Future-proof for V2 multi-profile”

> “V1 profile limit | One per user | Keep MVP simple”

### `docs/psy-market-refined-prd-v3.pdf`

The nine-page PDF duplicates those decisions. Relevant visible text includes:

> “V1: One profile per user, auto-created on signup. Type defaults to personal.”

> “V2: Multiple profiles per user (personal, artist, label, festival) with a profile switcher.”

> “Multiple profiles per user + profile switcher (personal, artist, label, festival)”

> “V1 profile limit | One per user | Keep MVP simple”

## 1.3 Reserved-profile planning protects the V1 limit

### `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md:143-145`

> “Because V1 currently intends one profile per user, the system must stop the claim if that account already owns a profile. Supporting multiple profiles per user is a separate V2 decision and must not be introduced accidentally through this feature.”

### `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md:311-317`

Its transaction checklist requires:

> “Enforce one profile per user for V1”

### `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md:417`

> “Prevent the same user from claiming multiple profiles while V1 enforces one profile per user.”

### `docs/RESERVED_PROFILE_CLAIM_WORKFLOW.md:443-445`

> “Under the V1 one-profile-per-user decision, the claim must stop and instruct them to contact the admin or use a different eligible account. Multi-profile support is out of scope.”

## 1.4 Historical specification and profile enum

### `docs/SPEC.md:258-260`

The historical specification defines:

```sql
create type profile_type as enum ('personal', 'artist', 'label', 'festival');
```

### `docs/SPEC.md:277-299`

Its profile table begins:

```sql
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type profile_type not null default 'personal',
  handle text not null unique,
  display_name text not null,
  ...
);
```

This historical schema had no `UNIQUE(user_id)` declaration, so in isolation it would permit multiple profiles per user. The later applied Chunk 2 migration deliberately changed that for V1.

### `docs/REFINED_PRD.md:314-320`

The profile field table similarly says:

> “`user_id` | UUID (FK → users) | Owner of this profile”

> “`type` | ENUM | `personal` (V1 default). V2: `artist`, `label`, `festival`”

## 1.5 V1 status and frozen decisions

### `docs/psy-market-v1-status-report-2026-07-12.pdf`

The status report lists:

> “Out of V1: integrated payments, reviews, favorites, follows, reports, multi-profile support…”

It also identifies this functionality as incomplete at that time:

> “Profile-type editing for artist/label/festival identities.”

### `docs/V1_DECISIONS.md:23`

The frozen decisions acknowledge all four profile types:

> “All profile types may post: personal, artist, label, and festival.”

`V1_DECISIONS.md` does not itself contain an explicit one-profile-per-user or multi-profile paragraph. The explicit V1/V2 split appears in `REFINED_PRD.md`, the reserved-profile workflow, the migration package, and the reconciled project state.

## 1.6 Terms and examples not found

No documentation was found using these exact terms in the requested identity sense:

- “alter ego”;
- “stage name”;
- “real name versus artist name”;
- “sub-profile”;
- “linked profile.”

No document describes the exact DJane + label + jewellery-brand woman. However, `USER_ROLES.md` documents the same underlying requirement through the personal buyer + DJ artist + record-label example and the multi-shop profile-switcher example.

# 2. Current database enforcement

## 2.1 Current result: one profile per user

The applied migration contains this unique index.

### `supabase/chunks/chunk-2-handles-profiles-apply.sql:163-168`

> “These indexes enforce the V1 invariants.”

```sql
create unique index profiles_handle_lower_key
  on public.profiles (lower(handle));

create unique index profiles_one_per_user_key
  on public.profiles (user_id);
```

`profiles_one_per_user_key` causes the database to reject a second profile row with the same `user_id`, regardless of its handle, display name, or profile type.

The handle index also makes public handles globally unique without regard to letter case.

## 2.2 Evidence that Chunk 2 is live

### `docs/V1_PUNCHLIST.md:9`

> “Database Chunks 0–7 are live and were read-only reconfirmed on 2026-07-26.”

Chunk 2 is the reserved-handle/profile-uniqueness chunk. The repository's latest recorded live verification therefore says the one-profile index is active.

### `supabase/migrations-proposal.md:245-249`

> “## CHUNK 2 — Reserved handles and profile uniqueness”

> “**Purpose:** Reserve all current and frozen/planned V1 top-level routes, make the list readable by the existing signup client, enforce it in a database trigger for every write path, add case-insensitive handle uniqueness, and enforce one profile per user.”

The only repository SQL found that removes `profiles_one_per_user_key` is the dedicated Chunk 2 rollback:

```sql
drop index if exists public.profiles_one_per_user_key;
```

No evidence was found that this rollback was applied.

This research did not execute a fresh live database catalog query. The conclusion is based on the repository's explicit record that Chunks 0–7 were live and read-only reconfirmed, plus the current migration set and absence of a reported rollback.

## 2.3 Signup creates one personal profile

### `supabase/chunks/chunk-2-handles-profiles-apply.sql:214-229`

The auth trigger inserts one profile:

```sql
insert into public.profiles (
  user_id,
  type,
  handle,
  display_name,
  created_at,
  updated_at
)
values (
  new.id,
  'personal',
  assigned_handle,
  coalesce(new.raw_user_meta_data->>'full_name', 'New User'),
  now(),
  now()
);
```

Therefore:

1. signup creates one profile;
2. it starts as `personal`;
3. the unique index prevents another profile for that user.

## 2.4 `profile_type` permits four row types, not four profiles per user

The current enum values are:

| Enum value | Intended identity |
|---|---|
| `personal` | Individual/personal profile |
| `artist` | DJ, producer, or other artist identity |
| `label` | Music-label identity |
| `festival` | Festival identity |

A profile row may have one of those values. The enum does not control how many profiles a user owns; the unique `profiles(user_id)` index controls that.

There is no `vendor`, `shop`, or `brand` enum value. The early `USER_ROLES.md` loosely described “Vendor (Shop/Label),” but the implemented enum remains the four values above.

## 2.5 Historical state before Chunk 2

Before Chunk 2, the captured audit found the opposite.

### `supabase/captured/AUDIT_REPORT.md:18`

> “Current code assumes one profile per user, but the database does not enforce it. Three user IDs currently have multiple profile rows. Calls using `.eq(\"user_id\", ...).single()` can fail or behave inconsistently.”

`supabase/captured/duplicate-profiles-review.md` records three duplicate groups, each with two profiles under one `user_id`. The review recommended selecting a survivor, reassigning dependent rows, merging non-conflicting fields, and deleting duplicates only after verification.

That audit is a historical pre-Chunk-2 capture, not the recorded current post-Chunk-2 state. Chunk 2's preflight and cleanup process existed specifically to resolve those rows before creating `profiles_one_per_user_key`.

# 3. Current application-code behavior

The current application is built around exactly one profile for each auth user.

## 3.1 New listing creation

### `app/listings/new/page.tsx:247-250`

```ts
const { data: { user } } = await supabase.auth.getUser();
if (!user) { router.push("/login"); return; }
const { data: profile } = await supabase
  .from("profiles")
  .select("id")
  .eq("user_id", user.id)
  .single();
```

There is no selection of an active profile before creating a listing.

## 3.2 Profile editing

### `app/profile/edit/page.tsx:125-136`

```ts
supabase.auth.getUser().then(async ({ data }) => {
  if (!data.user) { router.replace("/login?next=/profile/edit"); return; }
  const { data: p } = await supabase
    .from("profiles")
    .select("*")
    .eq("user_id", data.user.id)
    .single();
  if (!p) { router.replace("/"); return; }
  setProfileId(p.id);
  ...
  setType(p.type);
});
```

The user edits the one row returned for their account.

## 3.3 Messages redirect

### `app/messages/page.tsx:9-15`

```ts
supabase.auth.getUser().then(async ({ data }) => {
  if (!data.user) { router.replace("/login?next=/messages"); return; }
  const { data: profile } = await supabase
    .from("profiles")
    .select("handle")
    .eq("user_id", data.user.id)
    .single();
  if (profile) router.replace(`/${profile.handle}?tab=inbox`);
  else router.replace("/");
});
```

There is no profile choice before entering messaging.

## 3.4 Header identity

### `components/layout/Header.tsx:88-103`

```ts
const { data: profiles } = await supabase
  .from("profiles")
  .select("id, handle, display_name, avatar_url")
  .eq("user_id", userId)
  .order("created_at", { ascending: false })
  .limit(1);

const profile = profiles?.[0] ?? null;
```

The Header selects at most one profile and contains no profile-switching state.

## 3.5 Other one-profile assumptions

The same pattern exists in:

- `app/listing/[id]/edit/page.tsx`;
- `app/festivals/[slug]/page.tsx`;
- `lib/posts/use-reaction-viewer.ts`;
- authentication/profile synchronization paths;
- current-user ownership checks.

Searches found:

- no implemented `activeProfileId` application state;
- no Profile Switcher component;
- no “Create additional profile” flow;
- no current mechanism for choosing which profile owns a new listing, message, post, reaction, or upload.

## 3.6 Profile type can change, but identity does not multiply

### `types/marketplace.ts:10-11`

```ts
export const PROFILE_TYPES = ["personal", "artist", "label", "festival"] as const;
export type ProfileType = (typeof PROFILE_TYPES)[number];
```

Both profile-editing interfaces offer those four types. Changing the type updates the single existing profile row; it does not create separately named simultaneous identities.

# 4. Practical result for the real example

Under current behavior, one auth account cannot simultaneously own:

1. a DJane profile under an artist name;
2. a separate label profile under the label name;
3. a separate jewellery/vendor profile under its brand name.

The database's unique `profiles(user_id)` index blocks that, and the application has no profile-switching concept.

The current workaround would require separate auth accounts, or collapsing all roles into one public profile and one handle. Neither reproduces the originally planned one-login/multiple-persona experience.

# 5. Architecture implications for later discussion

This section records implications only; it makes no decision.

The system is partly prepared for future multi-profile support because public activity is generally tied to `profile_id`, not directly to `user_id`. Implementing the original Umbrella Model would still require at least:

1. an approved migration to remove or replace `profiles_one_per_user_key`;
2. a defined number/eligibility rule for additional profiles;
3. profile creation and deletion flows;
4. an `activeProfileId` state and profile switcher;
5. changes to every current `.eq("user_id", ...).single()` or one-row lookup;
6. explicit profile selection for listings, messages, posts, reactions, follows, RSVPs, and uploads;
7. rules for notifications, moderation, bans, reputation, and account deletion across profiles;
8. a decision on whether vendors/shops/brands need a new profile type or use an existing one;
9. rules for whether identities are publicly linked or intentionally isolated;
10. separate design work for team access, where multiple users manage one profile—the inverse relationship mentioned as a V2+ idea in `USER_ROLES.md`.

# 6. Bottom line

The multi-identity concept is documented clearly and was an intentional early architecture goal. The later product plan deferred it from V1 to V2, while preserving profile-based foreign keys to make a future transition easier.

According to the repository's recorded live database state and current code, psy.market presently supports **one public profile per auth user**, with that one profile having one of four types: personal, artist, label, or festival.
