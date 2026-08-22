# Events Rework Vision

> **VISION document — decisions agreed 2026-08-22 between Turgay and the wingman.** This is **NOT scheduled work**. **NO implementation is authorized by this document.** Sequencing is intentionally after **Multi-Profile Gate 1**, except where noted.

## Why events must be central

Events, festivals, and parties are the most important part of the scene and must be central to psy.market. The current `/festivals` section was built ad hoc: the existing entries were created by an admin and an agent. Turgay has declared that it needs a complete rework.

This document captures the agreed target so that future design work can start from a shared vision rather than extending the current ad hoc implementation.

## Core model

An **event** is its own time-bound entity. Profiles are persistent entities. Everything else is represented as a **relation between an event and a profile**:

- **Organizer:** whose event it is. Organizers are linked later and, at first, by admins.
- **Lineup:** who plays at the event.
- **Dancing:** who attends the event. This replaces the site-wide RSVP wording “attending.”

Profile calendars derive entirely from these relations. They are never maintained manually.

## Agreed workflow

### 1. Submission

Any logged-in user can submit an event through a form on `/festivals`, submitting as their **active profile**.

The form contains:

- Event name — required
- Start date and end date — required; the end date may equal the start date
- City and country — required
- Venue — optional, because it is often TBA
- Flyer image — optional but encouraged
- Website link — optional
- Facebook link — optional
- Ticket-sales link — optional
- One free-text field for lineup and description

The three links are separate fields. External ticket providers such as Reservix are the norm. **Tickets is the most important link and renders as the prominent button.** The ticket link may later point to psy.market’s own tickets category.

Submitters do no structured lineup or relation entry. They provide the free text; admins or the agent can complete structured details during review.

After submission, the user receives honest feedback that the event **appears after review**. They can find their submission and see one of these statuses:

- Pending
- Published
- Rejected

### 2. Review queue

The event review queue is the first real admin UI surface and breaks ground for the admin area.

It is a private admin page showing pending submissions newest first. Each queue item includes:

- Full submitted details
- Flyer preview
- Submitting profile
- Submission time

The available actions are:

1. **Approve:** publish as submitted.
2. **Edit then approve:** an admin or agent completes or corrects the details, then publishes.
3. **Reject:** provide a short reason that is visible to the submitter.

The queue flags possible duplicates based on a similar name and overlapping dates.

**Publication rule: published means an admin said yes — no exceptions, including agent drafts.**

### 3. Agent intake through the admin Telegram group

Admins can post a flyer or screenshot in the existing admin Telegram group, where Psy is already a member. The agent extracts:

- Event name
- Dates
- Venue
- City
- Lineup
- Links

The agent creates a draft in the **same review queue**, marked with its source and the admin who handed it in. There are zero shortcuts: the draft requires the same human approval as a user submission.

The group is also the intake channel for general content-change requests. Those requests become normal pipeline cards.

**The group is intake only. Publishing and pushing retain their explicit approval gates.**

### 4. Published event

A published event appears on `/festivals` in the timeline and on its detail page. The published experience includes:

- Flyer
- Dates
- Venue
- Description
- Three link buttons, with **Tickets** prominent
- RSVP using the **Dancing** wording
- The community Notice Board, as today

The page publicly shows **“Submitted by @handle”**, linked to the submitting profile. This follows Turgay’s ruling in support of a credit culture.

The lineup appears under the information tab:

- Artists with psy.market profiles are linked to those profiles.
- Artists without psy.market profiles are shown as plain names.

Organizer and lineup relations begin empty and are linked later.

### 5. Profile events section

Every profile gets an events timeline styled like `/festivals`:

- Upcoming events first
- Past events below

The archive matters because it records: **“I was there.”**

The timeline fills itself from two event-profile relations:

- **Dancing:** the profile RSVP’d. This replaces “attending” site-wide, including the festival-page buttons.
- **Playing:** the profile is on the lineup. This relation comes later.

Visibility differs by relation:

- **Dancing** is visible to logged-in members only.
- **Playing** is fully public.

For shops, Dancing also communicates: **“Find our stand there.”**

## Future chapter: artist profiles and lineup claiming

> **Post–Multi-Profile Gate 1. This is the most differentiating idea in the events vision.**

Lineup extraction creates **placeholder artist entries** for artists who do not yet have psy.market profiles. When an artist joins and claims their name, their existing gig history becomes their **Playing** timeline. Their profile begins with a meaningful history already in place, making this an onboarding magnet.

Turgay’s rationale is specific: many people in the scene created Instagram accounts unwillingly simply to follow where artists play. An artist page that fills itself from event relations removes a real burden.

The existing claiming sketch is documented in [`RESERVED_PROFILE_CLAIM_WORKFLOW.md`](./RESERVED_PROFILE_CLAIM_WORKFLOW.md). Any implementation must reconcile the placeholder-artist concept with that workflow and the Multi-Profile model.

On the organizer side, **proven organizer profiles may earn direct publishing** at a later stage. Submission plus review queue remains the default.

Allowing every profile to create and directly publish events was considered and rejected for launch because of spam and curation risk. The scene values curation.

## Open questions

These decisions remain open and require separate design work:

- **Exact admin-role model for the review queue:** depends on the admin area.
- **Event wall, Notice Board, and organizer-wall relationship:** unresolved here; continue in the separate festival-wall discussion.
- **Lineup extraction quality bar:** the required confidence, correction, and review standard is not yet defined.

## Authority and sequencing reminder

This document records product vision and agreed decisions only. It does not schedule work, authorize implementation, relax the event publication gate, or authorize pushes. Design and implementation sequencing is intentionally after Multi-Profile Gate 1 except where a later chapter is explicitly noted.
