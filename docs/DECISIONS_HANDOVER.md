# psy.market — Decision Handover (from planning chats)

**Date:** 2026-08-10
**Purpose:** This document records the PRODUCT AND BUSINESS DECISIONS Turgay made in planning chats with Claude (claude.ai), so that any assistant or agent working on the project shares the same decision history.

**Epistemic status — read this first:** This document makes NO claims about what is implemented. Implementation reality is defined by the repo, the live database, and `docs/research/PROJECT_STATUS_GROUND_TRUTH.md`. Where this document and reality disagree, **reality wins** — treat unimplemented decided items as backlog, never as regressions. Items marked *(rec.)* were Claude's recommendations that Turgay accepted; items without marker were Turgay's own calls.

---

## 1. Vision & motivation

- Scene-owned platform for the global psytrance scene. Turgay has been part of the scene for 30 years; motivation is giving back, not money.
- Core thesis: many scene people are only on Facebook/Instagram because there is no alternative (e.g. to see where their favorite artist plays). psy.market replaces that.
- Long-term shape: scene infrastructure layer — marketplace + festival calendar + community — not just "Etsy for psytrance".
- End-state ambitions (explicitly future, decided NOT to build now): on-platform payments, music sales/streaming by labels, verified ticket resale via organizer partnerships. Target growth markets in Turgay's view: India, Brazil, Thailand.

## 2. Phase map (decided 09 Aug 2026)

- **Phase 0 — now:** finish V1, soft launch to Turgay's personal contacts. No monetization at launch. NO tip jar, no donations (explicit decision).
- **Phase 1 — V1.1 after launch:** quality-of-life + the items listed in §5. Gate to watch: strangers registering, listings appearing organically.
- **Phase 2 — commerce (signal-gated, not date-gated):** trigger = sellers asking to be paid on-platform. Stripe Connect; payments optional per vendor (contact-only always remains). Requires company founding first.
- **Phase 3 — media (needs Phase 2):** music sales/streaming (label partnerships, invite-only), video already earlier (see §5).
- **Phase 4 — verified tickets:** cancel-and-reissue via ticketing-provider integrations; partnership business, last on purpose.
- Meta-rule: each phase is optional until its signal fires; modest outcome (beloved break-even scene tool) counts as success.

## 3. Company & legal (decided 09 Aug 2026, execution pending)

- Roles: co-founder = CEO (lives in Switzerland), Turgay = CTO (Germany, Frankfurt/Wiesbaden area).
- Entity location undecided; leaning German UG *(rec.)*. To be settled with Steuerberater + notary; founder agreement (Gesellschaftervertrag) mandatory at founding.
- Pre-launch lawyer bundle (one visit): Impressum/operator question, Datenschutzerklärung (incl. 12-month ban-tombstone wording from §6), DSA check of report feature + statement-of-reasons wording + footer report-email sufficiency, Nutzungsbedingungen.
- Commerce-phase legal list (later): seller terms, dispute policy, VAT/OSS, DAC7 reporting (small-seller exemption: <30 sales AND <€2,000/yr), withdrawal-right checkboxes for digital goods.

## 4. V1 launch scope decisions

- **Multi-profile is V1** (decided 08 Aug 2026, "essential for launch"; launch delay of weeks accepted). Full decision set in §6.
- **Report/flag feature is V1** (DSA requirement; supersedes older "reports in V2" decision):
  - Report button for logged-in users on: posts, listings, profiles, conversations, notice-board entries.
  - Short fixed reason list + optional free text → reports table.
  - Dedup: many reports on same content = one case with counter. Burst limit per user.
  - Plain email to admins with link to content; NO admin screen for this in V1.
  - On admin delete, author gets a short email with the (already mandatory) deletion reason = statement of reasons.
  - Public report email address in footer/imprint for non-logged-in people.
  - NO AI at launch. AI triage in V1.1: sorts/summarizes/translates reports, NEVER auto-decides or silently closes.
- **Following feed lives on the Stream page**, not as a profile tab (decided 09 Aug 2026): toggle above the timeframe filter (Stream = all posts / Following = followed profiles). Logged-in only; if following nobody, toggle still shows with friendly empty state. View encoded in URL. After multi-profile: follows the active profile (like the inbox).
- **Account deletion flow is V1** (GDPR; also required by multi-profile deletion rules, §6).
- Launch mode: contact-only marketplace (no on-platform payments).

## 5. V1.1 decisions (post-launch, designs fixed now)

- **Video — early V1.1, triggered by post-launch user demand** ("why no videos?"). Very important to Turgay (vendors live on Instagram video). Decided architecture *(rec.)*: R2 quarantine upload → background ffmpeg transcode worker on the VPS (load per upload, not per view) → public R2 / Cloudflare edge delivery. Short clips with format/length cap (~60–90 s, MP4). Cloudflare Stream not needed at this scale.
- **Post search** (design fixed 09 Aug 2026): global top search searches everything; scoped search field next to the timeframe control searches the active view (Stream or Following), combined with timeframe filter, per active profile after multi-profile.
- **Admin translate button** *(rec.)*: admin-only inline button next to delete on posts; server-side AI call; English translation shown inline, not stored. Build together with AI report triage as one API integration.
- Other V1.1 candidates from earlier planning: @-mentions, favorites/bookmarks (originally Turgay's idea — he believes it is in the docs somewhere; verify), listing cover-picker, reservations.

## 6. Multi-profile decision set (complete, decided 08 Aug 2026)

Fixed product decisions (recorded in `docs/MULTI_PROFILE_PROPOSAL.md` as Resolved decisions — the proposal is the authoritative detailed source):

1. Max **5 profiles per account** (want more → new email/account).
2. profile_type gains **vendor** ("Shop / Brand") as the only new type.
3. Signup unchanged: auto-creates one personal profile; type editable; more profiles added voluntarily.
4. Profiles of one account are **publicly unlinked**; only owner (switcher) and admins see the connection.
5. **Bans are account-level**: all sibling profiles go dark together.
6. **Global active-profile switcher** in header (avatar menu); all actions performed as active profile.
7. "Posting as @handle (switch)" hint on listing/post forms.
8. **Inbox is per profile**; switching profiles switches the inbox.
9. New-message email stays ONE account-level switch; email names the contacted profile.
10. Profile deletion allowed except the last profile → routes to account deletion. Real deletion of listings/posts (Wall deletion rules, images to orphan report, no status-only soft-delete); conversations follow existing soft-delete; confirmation with summary + type-the-handle; freed handles return to pool.
11. Account deletion becomes V1 scope.
12. Reactions (Wall AND Notice Board) are **per profile** (rationale: profiles may be run by different people sharing one login; account-level uniqueness would leak co-ownership publicly).
13. RSVPs per profile; siblings may RSVP the same festival differently (attending vs selling).
14. Sibling profiles MAY follow each other (needed for shared-login label/artist feeds); self-follow blocked; no account dedup of follower counts.
15. Sibling profiles can NOT message each other (neutral notice, no email).
16. Multiple profiles of the same type allowed; only the 5-cap counts.
17. Owner visiting own inactive profile sees a private "Switch to manage" action; never auto-switch.
18. Switching with unsaved form work requires confirmation (Stay / Discard).
19. Profiles that created events: deletion blocked pending admin transfer (users never create events directly in V1; planned flow: user submits flyer/link → admin review → agent creates; submit workflow deliberately not designed yet).
20. Deleted profiles appear in surviving conversations as neutral "Deleted profile" (no handle/avatar/link).
21. Banned users may self-service delete their ENTIRE account (GDPR); everything else stays blocked; no single-profile deletion while banned.
22. Account-deletion retention: minimal private moderation tombstone (hashed email, ban date/reason, deletion date), auto-expiring after 12 months; lawyer-verify wording.
23. Email reuse after deletion: immediate re-registration allowed EXCEPT while a ban tombstone exists.
24. New-profile onboarding: handle + display name + type only; new profile becomes active immediately.
25. Admins see sibling profiles ONLY in a dedicated admin panel, never inline on moderation surfaces.
26. Message-email cadence: unread-aware delayed sending, throttled per conversation.
27. Realtime private-delete question: verify empirically during messaging slice; Broadcast only if a real leak is proven.
28. The last super-admin cannot delete their account until the role is transferred.
29. Team access (own logins per person/profile) is explicitly V2; login-sharing is the user's own trust decision in V1.

## 7. MP implementation status AS RECORDED IN CHAT (verify against ground truth before relying on it)

- Package A (read-only baseline preflight): ran to full GO on the live DB (08–09 Aug); approved baseline encoded as expectations; serves as drift tripwire.
- Package B (three private helper functions): applied to the live DB by Turgay, verify returned GO (09 Aug).
- Package C (app conversion to public/private profile contract): built, tests/build green, staging click-round + browser privacy audit passed, committed and pushed (09 Aug). Client-side privacy only — REST exposure of user_id intentionally remains until Package D.
- MP-4 (policy/function conversion package): **LIVE — owner-applied and verified 11 Aug 2026.** History: the authored, validated and published package was initially held because `banned_profile_owner` was unproven. Turgay then ran the reviewed `@darktribo` database-only fixture ritual (preflight GO → temporary ban → fixture verify GO), after which the MP-4 preflight returned full GO and the apply committed cleanly. The first post-apply verify returned STOP 13/16 because its harness used one invalid Notice category, one invalid reaction emoji and an RSVP pair already present in live data; no policy defect was found. Commit `b85b20f` corrected that verify-only harness after independent review, and the live rerun returned GO 16/16 with every allow and deny path proven, including banned-account denial. The fixture unban and unban-verify returned GO; `@darktribo` had no Hero posts to clear, and only the previously accepted `updated_at` timestamp advances remained. Detailed record: [`MP4_POLICY_CONVERSION_VERIFICATION.md`](MP4_POLICY_CONVERSION_VERIFICATION.md).
- Package D (database-enforced public-profile privacy): **LIVE — owner-applied and verified 12 Aug 2026.** Preflight returned GO with no findings and captured the complete pinned 33-entry pre-cutover ACL. Apply committed cleanly on its first live run. Verify returned GO 33/33: both `anon` and `authenticated` received exactly the 12 `PUBLIC_PROFILE_SELECT` columns; direct reads of `user_id`, `is_suspended`, `updated_at` and `select=*` were denied with SQLSTATE `42501`; embeds, private owner/admin helpers and `service_role` access remained intact. An independent VPS REST probe changed from HTTP 200 with owner-ID data before apply to HTTP 401 / SQLSTATE `42501` afterward, while safe-column reads remained HTTP 200. Turgay's staging click-round passed. Rollback exists and was not needed. Detailed record: [`PACKAGE_D_PRIVACY_CUTOVER_VERIFICATION.md`](PACKAGE_D_PRIVACY_CUTOVER_VERIFICATION.md).
- MP-3 foundation (cardinality, type and active-session foundations): **LIVE — owner-applied and verified 13 Aug 2026.** Wingman pre-review caught two stale reconstructed baseline pins before execution; `af0b2dd` replaced them with live-catalog evidence. Live preflight returned GO and apply completed cleanly. The first verify returned STOP 17/19 only because two fingerprints embedded environment/session-dependent catalog renderings; all behavior checks passed and wingman diagnosis confirmed the applied state was functionally exact. `eadd83b` and `01f8382` normalized settings, ACL sets, schema qualification and function-body whitespace; every pin matched live before the rerun, which returned GO 19/19 with expected SQLSTATE `42501` denials. The first Claude-in-Chrome QA mission under §11 passed on the homepage, profile, profile-edit round trip and Stream. `vendor` and the active-session/cap/owner guards are live, but `profiles_one_per_user_key` remains in force, so multiple profiles are still disabled. Detailed record: [`MP3_FOUNDATION_VERIFICATION.md`](MP3_FOUNDATION_VERIFICATION.md).
- Slice MP-4: **in guarded execution, package A of eight live** (see [`SLICE_MP4_EXECUTION_RECORD.md`](SLICE_MP4_EXECUTION_RECORD.md)). This line is updated as packages land; package sitting details belong in the rolling execution record.
- All user-visible multi-profile features (cap raise, switcher, vendor type, profile creation/deletion UI): NOT implemented — later slices per the plan.

## 8. Deliberate NOs (decided, do not re-litigate casually)

- No comments on posts (reactions only) — moderation surface deliberately kept small for a two-admin team.
- No algorithmic feed — chronological is an identity feature for this scene.
- No external ads, ever stated as principle; scene-internal promotion (featured placements) is the ad business.
- No tip jar / donations pre-founding.
- No video hosting on the VPS (serving); VPS is fine as background transcoder only.
- Vendors are never forced into payment onboarding — contact-only remains available per vendor.

## 9. Monetization ladder (decided 09 Aug 2026)

1. Launch: nothing.
2. With traffic (~200+ daily visitors): featured placements (flat weekly fee), festival promo packages (~€50–200/event). Own-service invoicing — no marketplace payment machinery needed. Possibly Kleinunternehmerregelung at start (confirm with Steuerberater).
3. After founding + community: supporter membership (~€3/month, profile badge, Stripe subscription).
4. Phase 2+: marketplace fees (flat transparent single-digit %, seller-side *(rec.)*), later music, later tickets.

## 10. Working preferences (how Turgay works)

- Non-technical; every step explained in simple words (what we do and why) BEFORE the instruction; strictly ONE step per message, wait for result.
- Prompts intended for agents always in code blocks, labeled for which agent.
- Large agent outputs as MD files (mobile copy-paste limits), downloaded and shared.
- Sub-agents/parallelism only for independent read-only work; build slices stay serial (Turgay is the integration point).
- Weekly plain-language update for the co-founder, compiled from git log (not memory) to avoid stale claims.
- Ritual for DB changes: preflight → apply → verify chunk packages run by Turgay in the SQL editor, one result at a time.
- Proposal-first ritual for big features: product decisions in chat → proposal doc → review → build slices.

## 11. Additions — decided 10 Aug 2026 (recorded 13 Aug 2026)

### Staging QA tester — Claude in Chrome

- **Role:** Claude in Chrome (the browser extension in Turgay's Brave browser) is the QA tester for **staging only**. Production remains off-limits under the standing rule.
- **Capabilities:** On the tab Turgay assigns, it can navigate, click, fill forms, and read DOM and network responses. Proven 09 Aug 2026: it ran the Package C browser privacy audit across profile, Stream, and listing pages and found zero owner-ID leaks in response bodies.
- **Dedicated test mailbox:** It gets a dedicated All-Inkl mailbox used only for staging test accounts. This enables complete staging journeys: register → activation link through test webmail → login → forgot-password loop → profile edit → listing create/edit (text flows) → contact flows. Mailbox credentials belong in prompts/configuration, never in repository documentation.
- **Workflow:** The wingman drafts each test script, including goals, staging URL/login, test-mailbox credentials, and the expected report format. Turgay pastes it into the extension. Findings return to the wingman for evaluation. Turgay's own click-round is reduced to spot-checks and judgment calls.
- **Limits:** OS file-picker drivability for image uploads is unverified and will be tested once. Side-effect actions stay deliberate and minimal. Final approval and every judgment call remain with Turgay. This replaces the previously considered Fiverr site testers; it does **not** replace Turgay's final testing.

### Stream Patrol — future V1.1 reports/moderation design input

- **Status:** Design input for the future V1.1 reports/moderation specification; **not an implementation claim and not built now**.
- A scheduled VPS job, not a browser-based tool, scans new posts approximately every six hours. It is multimodal: text **and** images. Its review scope includes spam, pornography, and similar suspicious content.
- **Flag only:** It reports suspicious cases, with a short reason, to Turgay and the co-founder. It never deletes content, bans users, or takes autonomous action. There is no automated "three strikes" rule. Turgay always has the final say on every moderation action.
- It uses the same machinery and governing principle as the already-decided AI report triage: translate, summarize, and rank — never decide and never silently close.
