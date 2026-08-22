# Browse, category, and Stream design decisions

This record covers the redesign decisions made from 2026-08-17 through 2026-08-21, plus Turgay's 2026-08-22 clarification of the earlier Following decision. It records the reason for each choice so later work does not accidentally reopen a settled trade-off.

## Browse

### 2026-08-17–18 — replace the large photo hero with a compact header

The first Browse redesign removed the large photo hero and used a compact page header instead. The aim was to put search, filtering, and listings closer to the top of a marketplace-results page rather than spending the opening viewport on imagery.

### 2026-08-18 — use one sticky marketplace toolbar and one result summary

Search, category, sort, and price belong in one unified sticky toolbar, replacing the three separate widgets used before the redesign. There is one result count below the toolbar rather than competing counts in several controls. This gives the page one obvious place to refine results and one authoritative summary of what those controls produced.

The Browse category control remains single-select. Whether it should become multi-select to match category-page type pills was deliberately left open on 2026-08-18; see [Open questions](#open-questions).

### 2026-08-18 — make listing columns equal width

The listing grid uses `minmax(0, 1fr)` columns. Plain fractional tracks were still allowing intrinsic content to influence track sizing, so the card with the longest title could make its column wider than its neighbours. A zero minimum lets every track shrink evenly and keeps the cards visually equal.

### 2026-08-18 and 2026-08-20 — align Browse and category grid density

Browse and standard category pages use the same target density: four cards per row on wide desktop and two on mobile. Both retain a three-column responsive midpoint and collapse to one column only on very narrow screens. The decision was about cross-page consistency: moving between the all-listings view and a category should not make the catalogue feel like a different product.

### 2026-08-18 — use a shared, honest end-of-results marker

The end marker is the shared `components/Waveform.tsx` component, not page-specific decoration. It is shown whenever a completed Browse result set has no next page, including zero results, so the terminal count can truthfully read `0 OF 0`. Zero results also receive a distinct empty state with recovery actions; an empty grid is not treated as unexplained blank space.

### 2026-08-20 — reintroduce a slim photo band through the shared hero

After category heroes had been reduced to slim bands, Browse reintroduced photography through the shared `PageHero`. This superseded the compact text-only header from 2026-08-17–18. The reason was cross-page consistency: Browse, category pages, and Stream could share one restrained visual opening without returning to the oversized hero that the first redesign removed.

## Category pages

### 2026-08-18 and 2026-08-20 — keep type choices as multi-select pills

Category type choices stay as pills and remain multi-select; they are not replaced by a dropdown. A normal dropdown communicates one selected value and cannot honestly express the existing multi-select interaction.

The pills live in a horizontally scrollable rail. On desktop, left or right arrows appear only when content is actually hidden in that direction. Mobile keeps the swipeable rail and hides those arrow controls, avoiding unnecessary chrome on a touch interaction.

### 2026-08-20 — keep the photo hero, but give it fixed breakpoint heights

Category photography stays, but only as a slim shared `PageHero` band: 200 px on desktop, matching the profile-header height, and 168 px on mobile. These are fixed pixel heights per breakpoint, not an aspect ratio.

This corrects an earlier same-day aspect-ratio attempt. An aspect ratio made the band taller as the browser widened, while the profile header remains a stable height. Fixed heights preserve the intended slimness and the visual relationship between those surfaces.

### 2026-08-20–21 — make Featured a rail, not a mobile stack

Featured listings use a horizontal swipe row on mobile instead of stacked full-width cards. Desktop keeps three items visible and becomes a rail only when there are more than three items. Its arrows are conditional: a direction is shown only while more content is hidden in that direction.

The arrows are vertically centred on the whole card rather than only on its image. This makes the control read as navigation for the complete listing card and remains correct when card copy changes the card height.

## Stream

### 2026-08-20 — share the slim photo hero and align the toolbar to the feed

Stream uses the same shared `PageHero` as Browse and category pages. Its sticky filter toolbar is constrained to the 680 px post-column width rather than stretching to the page shell. The filter therefore belongs visually to the feed it changes, while the hero still supplies cross-page consistency.

### 2026-08-21 — use presets first, with custom dates on demand

Time range offers these choices:

- All time
- Last 7 days
- Last 30 days
- This year
- Custom range…

`Custom range…` reveals the From and To date fields; the native date inputs are not the default face of the filter.

This explicitly reverses the 2026-08-06 **no presets** decision. Native date inputs cannot be styled consistently across browsers and languages, and the main practical use case—catching up after a festival week—becomes a one-tap action with a preset instead of a two-date task. Custom dates remain available for less common ranges.

## Following: decided placement and open presentation

### Decided — 2026-08-09, clarified 2026-08-22

- Following lives on the **Stream page** as a **Stream / Following** switch, not as a profile tab.
- The switch is visible to logged-out users as well. Logged-out and no-feed situations use a friendly empty state rather than hiding the destination.
- The active view is encoded in the URL so it is shareable and survives reload.
- A shared Following URL shows each recipient **their own** feed; it does not encode or expose the sender's feed identity.
- After Multi-Profile, Following follows the active profile, like the inbox.

The placement is also recorded in `docs/MULTI_PROFILE_GATES.md` under “Resolved product decisions” and in `docs/DECISIONS_HANDOVER.md`. The 2026-08-22 clarification above is newer than their 2026-08-21 “logged-in users” wording and governs visibility: the switch is also shown while logged out.

### Still open — presentation suggestion from 2026-08-22

It is suggested, but not decided, that Stream / Following render as two tabs above the filter toolbar, with a rust underline on the active tab. The reasoning is that changing the feed is a larger navigation move than narrowing the current feed, so tabs would communicate page-level navigation better than another filter control.

Under that suggestion, the toolbar below would reserve scoped post search on the left and Time range on the right. This would keep the toolbar balanced instead of leaving one control in a large empty bar. Scoped post search itself is V1.1, but the layout should reserve its place now if the tab presentation is accepted.

## Open questions

- **Browse category selection (open since 2026-08-18):** should Browse's single-select category control become multi-select to match category pages? The difference was deliberate and has not yet been resolved.
- **Stream / Following presentation (open since 2026-08-22):** accept or reject the tabs-above-toolbar suggestion described above. The placement, URL behaviour, logged-out visibility, shared-link semantics, and active-profile behaviour are already decided regardless of presentation.

## Standing visual constraint

### 2026-08-17–21 — no typography redesign

None of this work authorizes typography changes. Reuse the existing fonts and colour tokens. The redesign changes hierarchy, density, grouping, and responsive behaviour—not the product's type or colour system.

## Implementation references checked on 2026-08-22

The current implementation was checked against the decisions above:

- `components/BrowsePageClient.tsx` — shared hero, unified Browse toolbar, single result summary, equal-width responsive grid, zero-results state, and terminal `Waveform` count.
- `components/StandardCategoryPage.tsx` — shared hero, shared category toolbar, aligned catalogue grid, and Featured mobile swipe row.
- `components/PageHero.tsx` — fixed 200 px desktop and 168 px mobile heights.
- `components/FeaturedCategoryRail.tsx` — more-than-three desktop rail threshold and direction-aware arrows.
- `components/CategoryFilterToolbar.tsx` — multi-select pills, overflow measurement, and direction-aware type-rail controls.
- `components/StreamPageClient.tsx` — shared hero, 680 px toolbar/feed alignment, preset list, and custom-range reveal.
- `components/Waveform.tsx` — shared static waveform component.
- `components/ScrollToTopButton.tsx` — shared page continuation control and reduced-motion-aware behaviour used by these long pages.

Following is still future implementation: this document records the decided product contract and clearly separates it from the open presentation suggestion.
