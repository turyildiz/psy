# Wall highlights database foundation — live application and verification

**Date:** 2026-08-16

**Status:** PASS — live

**Package commit:** `cc3ea86` on `kanban/t_7fb0e4f9`

**Merged to main:** `3860e9e`

**Apply method:** Turgay executed the reviewed package against the live database as project owner.

**Verification method:** Owner-run preflight/apply/rerun/verify ritual, followed by wingman read-only live object and privilege probes.

## Purpose and scope

The Wall highlights package installs the database foundation for profile-owned highlighted posts. Its live scope is:

- `is_highlighted` and `highlighted_at` on `public.posts`;
- the `posts_highlight_state_check` state constraint;
- the five-highlight maximum enforced by the `enforce_post_highlight_limit` trigger with a profile-row lock;
- `toggle_post_highlight(uuid, boolean)` under the MP4-A active-profile authority contract;
- the partial `posts_profile_highlighted_id_idx` index for newest-first highlight circles; and
- a symmetric rollback.

This package was the database foundation only. The application toggle, circles row, and post overlay were delivered in the subsequent app slice recorded below.

## Authoring and independent review history

The package was authored on card `t_7fb0e4f9` from a live evidence bundle.

An independent cross-model audit first reviewed all bridge-era work and found two behavioral gaps:

1. highlight toggles bypassed the account write rate limit; and
2. the cap's custom SQLSTATE `P5005` would have surfaced as a generic server error.

Correction round 1 on card `t_856252dd` fixed both gaps, improved lock hygiene, and repaired four harness gaps. That round also introduced a new over-strong lock on the posts row, which the audit's second pass caught.

Correction round 2 changed both locks to `FOR NO KEY UPDATE` and repaired two test assertions: the `ctid` no-op probe and the `count(*) = 0` atomicity invariant.

The audit's third pass returned **PASS**. It included byte-exact proof that nothing outside the commissioned fixes changed and independent recomputation of every after-state manifest against the live PostgreSQL 17.6 target. The final package commit was `cc3ea86` on `kanban/t_7fb0e4f9`.

## Live execution record

The owner sitting took place on 2026-08-16.

| Step | Live result |
|---|---|
| Preflight | GO — 3 of 3 |
| Apply | Committed cleanly; `Success. No rows returned` |
| Apply rerun | Proven no-op |
| Verify | GO — 7 of 7; findings empty |
| Wingman read-only reprobe | All commissioned objects present; `toggle_post_highlight` EXECUTE granted only to `authenticated` and `postgres` |
| Merge | Merged to `main` as `3860e9e` |

`Success. No rows returned` is the expected success shape for this package. Its apply postconditions raise on failure instead of printing a verdict row.

## Bound product decisions

- The five-highlight cap message is exactly `You can highlight up to 5 posts; unhighlight one first.` and is raised with SQLSTATE `P0001`.
- The app slice **must branch on the message text**, because `P0001` is shared with the burst limiter.
- Highlight state changes consume the shared account write budget of 20 writes per 10 minutes, by Turgay's decision on 2026-08-16.
- A highlight circle is visible only to a viewer who may open the underlying post. The existing `current_user_can_read_post` read policy enforces this; no new read policy is needed.

## Lifecycle boundaries

- The rollback is symmetric but destroys highlight state by design.
- The disposable lifecycle ran on PostgreSQL 16.
- The live target is PostgreSQL 17.6, and every after-state pin was independently verified against that live target.

## App slice — feature complete (2026-08-16)

Card `t_2959a6e5` delivered the visible feature:

- an owner-only **Highlight** toggle calling `toggle_post_highlight`;
- a **Highlights** circles row at the top of the profile Wall, fed by its own `is_highlighted` query ordered newest-first and limited to five, matching the partial index;
- first-image circle crops for image posts and styled text circles for text-only posts;
- a row and heading that both hide when the profile has zero highlights;
- desktop hover previews of approximately 80 characters;
- click/tap opening the post in a centered overlay with internal scrolling and a panel-pinned close button; and
- the exact cap message shown verbatim on the sixth attempt, with the burst-limit case mapped to a friendly wait message through an exported pure helper covered by behavioral unit tests.

Three owner-feedback rounds refined the presentation. The heading was added, then moved inside the card and sized to match the composer heading; the overlay was centered; close-button clearance was added for the owner's action row; and universal top headroom was accepted by the owner as consistent chrome.

The wingman staging click-round verified create, highlight, hover, overlay, unhighlight, and the sixth-attempt message. Turgay also tested and accepted the feature personally. The app-slice commits were `c283e38`, `9da25c7`, `aeec2a5`, `84f0574`, and `8e2c82f`; they were pushed within merge `ef2f61f` on 2026-08-16.

The full test suite is now wired to one runner: `npm test`, using `node --test` over `tests/`. This closes the independent audit's MAJ-1 wiring finding. The suite stood at 159 passing tests at highlight completion and 172 after the search slice.

## Conclusion

The Wall highlights foundation and app slice are live, verified, and feature-complete as of 2026-08-16.
