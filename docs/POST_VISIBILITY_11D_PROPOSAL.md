# Post Visibility 11D Proposal

**Status:** Approved and implemented. Chunk 11D was owner-applied and database-verified on 2026-08-07; the coordinated application/docs slice is authored locally and awaiting staging verification before commit.

**Historical framing:** Sections 1–8 retain the approved pre-implementation findings and design, so references there to the “current” system describe the captured pre-11D baseline unless an applied state is stated explicitly.

**Decision to implement:**

- Posts with `show_in_stream = true` are public, including to logged-out visitors.
- Posts with `show_in_stream = false` are visible only to authenticated users.
- Existing author, active-admin, banned-author, banned-reactor, and banned-viewer read behavior remains unchanged.
- The existing composer checkbox becomes the public/members visibility switch.

This proposal treats the owner-applied and verified Chunk 11A–11C database state as the migration baseline. Chunk 11D was therefore delivered as a separately guarded correction rather than rewriting 11A–11C as though the new semantics existed at their initial application. Repository status headers now reflect the owner-confirmed application state.

---

## 1. Captured pre-11D baseline: post read policy

### Pre-11D database shape

Before 11D, `public.posts` had:

- row-level security enabled and forced;
- direct `SELECT` grants for `anon`, `authenticated`, and `service_role`;
- no direct client mutation policies—post writes remain RPC-only;
- exactly one permissive `SELECT` policy.

| Pre-11D policy | Role | Qualifier |
|---|---|---|
| `Visible posts are publicly readable` | `public` | `current_user_can_read_post_author(profile_id)` |

PostgreSQL's `public` pseudo-role includes `anon` and `authenticated`, so the same policy applied to logged-out visitors and members. `show_in_stream` was not part of pre-11D post RLS.

The existing helper is conceptually:

```text
current_user_can_read_post_author(profile_id)
= author is not banned OR viewer is an active admin
```

### Effective post visibility before 11D

| Viewer | Unbanned author | Banned author |
|---|---:|---:|
| Logged out | All posts, regardless of `show_in_stream` | Hidden |
| Authenticated ordinary member | All posts, regardless of `show_in_stream` | Hidden |
| Active authenticated admin | All posts | All posts |
| Banned authenticated viewer | Same read access as an ordinary member | Hidden unless also an active admin |
| Expected Supabase `service_role` | Complete operational access through `BYPASSRLS` | Complete operational access through `BYPASSRLS` |

There is no separate author-read exception. An ordinary author sees their posts because they are authenticated. Under the current helper, a banned author's posts are hidden from that author as well unless the viewer also satisfies the active-admin helper. Chunk 11D should preserve that behavior unless the owner separately decides to introduce an author exception.

`FORCE ROW LEVEL SECURITY` does not constrain a role with `BYPASSRLS`. The preflight must therefore confirm the live `service_role.rolbypassrls` value rather than assuming that direct `SELECT` grants make service-level reads obey RLS.

---

## 2. Proposal: centralized post-visibility decision

Keep the existing author-ban/admin helper unchanged and add one centralized visibility helper:

```text
current_user_can_read_post(
  target_profile_id uuid,
  target_show_in_stream boolean
)
```

Its intended predicate is:

```text
current_user_can_read_post_author(target_profile_id)
AND (
  target_show_in_stream
  OR auth.role() = 'authenticated'
)
```

Recommended properties:

- `STABLE`;
- `SECURITY DEFINER`;
- `SET search_path = ''`;
- owned by `postgres`;
- every referenced application object schema-qualified;
- PostgreSQL `PUBLIC` execution revoked;
- execution granted only to `anon` and `authenticated`;
- no viewer-ban check, preserving the current rule that a banned authenticated viewer can still read posts by an unbanned author;
- existing active-admin access to banned-author posts preserved through `current_user_can_read_post_author(...)`.

### Post policy change

The existing broad post policy must be dropped or replaced, not supplemented. PostgreSQL combines applicable permissive policies with `OR`; retaining the old qualifier would continue exposing every unbanned-author post anonymously.

Recommended resulting policy:

| Proposed policy | Role | Qualifier |
|---|---|---|
| Post visibility policy | `public` | `current_user_can_read_post(profile_id, show_in_stream)` |

Conceptually:

```text
FOR SELECT TO public
USING (
  public.current_user_can_read_post(profile_id, show_in_stream)
)
```

Keeping one policy and one shared visibility helper minimizes policy interaction and gives posts and reactions one authoritative parent-post decision.

### Resulting visibility matrix

| Viewer | Author | `show_in_stream` | Result |
|---|---|---:|---|
| Anonymous | Unbanned | `true` | Visible |
| Anonymous | Unbanned | `false` | Hidden |
| Authenticated non-admin | Unbanned | `true` | Visible |
| Authenticated non-admin | Unbanned | `false` | Visible |
| Authenticated banned viewer | Unbanned | Either | Visible, preserving existing read behavior |
| Anonymous/authenticated non-admin | Banned | Either | Hidden |
| Active authenticated admin | Banned | Either | Visible |
| Expected `BYPASSRLS` service role | Any | Either | Visible |

No post table grant, write policy, mutation RPC, mutation signature, column, or backfill needs to change.

---

## 3. Current-system findings: reaction read policy

`public.post_reactions` currently has:

- row-level security enabled and forced;
- direct `SELECT` grants for `anon`, `authenticated`, and `service_role`;
- no direct client mutation policies—reaction changes remain RPC-only;
- exactly one permissive `SELECT` policy.

| Current policy | Role | Qualifier |
|---|---|---|
| `Visible reactions are publicly readable` | `public` | `current_user_can_read_post_reaction(profile_id, post_id)` |

The current helper requires:

1. the reacting profile's owner is not banned; and
2. the parent post's author passes `current_user_can_read_post_author(...)`.

It does not inspect the parent's `show_in_stream` value. Changing only the `posts` policy would therefore be incomplete: anonymous callers could continue to query reactions attached to a members-only post because the privileged reaction helper can resolve the parent independently of the caller's post RLS.

The helper is also directly executable by `anon` today. Unless its body is corrected, it can act as a boolean oracle for the existence/readability of a members-only parent post even if table RLS filters the reaction row.

---

## 4. Proposal: reaction visibility

### What anonymous visitors should see

For a public post, anonymous visitors should retain the existing reaction-read shape:

- reaction code;
- parent post ID;
- reacting profile ID;
- reaction timestamp;
- only reactions from non-banned reactors;
- only reactions whose parent author remains publicly visible.

Anonymous visitors cannot add or remove reactions. The existing mutation RPCs already require an authenticated, unbanned caller.

For a members-only post, anonymous visitors should see:

- no reaction rows;
- no aggregate derived from those rows;
- no helper result that confirms the members-only post or its reactions exist.

### Required reaction change

Update `current_user_can_read_post_reaction(...)` so the parent-post branch reuses the new centralized helper:

```text
not profile_owner_is_banned(reaction_profile_id)
AND coalesce((
  SELECT current_user_can_read_post(
    post.profile_id,
    post.show_in_stream
  )
  FROM posts AS post
  WHERE post.id = target_post_id
), false)
```

The existing reactor-ban predicate must remain unchanged.

The existing reaction policy can remain a single `public` policy if its helper is replaced with this role-aware parent-post decision. Its exact catalog qualifier may therefore remain the same while the helper body changes.

### Resulting reaction matrix

| Viewer | Parent author | Parent `show_in_stream` | Reactor | Reaction result |
|---|---|---:|---|---|
| Anonymous | Unbanned | `true` | Unbanned | Visible |
| Anonymous | Unbanned | `false` | Unbanned | Hidden |
| Authenticated non-admin | Unbanned | Either | Unbanned | Visible |
| Authenticated banned viewer | Unbanned | Either | Unbanned | Visible, preserving existing read behavior |
| Anonymous/authenticated non-admin | Banned | Either | Unbanned | Hidden |
| Active authenticated admin | Banned | Either | Unbanned | Visible |
| Any RLS-bound viewer | Any | Either | Banned | Hidden |
| Expected `BYPASSRLS` service role | Any | Either | Any | Visible through bypass |

Authenticated users should continue to be able to react to members-only posts. The existing reaction mutation RPC rejects banned callers and banned-author targets and should remain unchanged.

### Why reactions belong in 11D

Reaction visibility must ship in the same transactionally reviewed chunk as post visibility. Otherwise a parent post can become members-only while its reaction rows, reactor identities, reaction codes, timestamps, or existence remain anonymously queryable.

The recommended V1 scope preserves full existing reaction rows on public posts. Moving anonymous access to aggregate-only emoji counts would require a separate view/RPC and application contract and is not required to implement this decision.

---

## 5. Current-system findings: application read surfaces

| Surface | Current query/path | Logged-out behavior after 11D | Error versus filtering |
|---|---|---|---|
| Profile Wall | Browser query on `posts`, filtered by `profile_id`, no `show_in_stream` filter | Shows only public/Stream-enabled posts for that profile | RLS filters rows; the query should not error because the `anon` `SELECT` grant remains |
| Stream | Browser query on `posts` with explicit `show_in_stream = true` | Continues showing public posts in chronological order | No expected error or behavioral regression |
| Stream server page | Validates/canonicalizes date-only URL parameters; does not read posts | No post visibility work occurs server-side | No post-query error path |
| Profile page | Loads profile/listing state and mounts `ProfileWall`; no separate server post query | Public profile remains accessible; its Wall receives the anonymous public subset | No post-query error |
| Post-image upload authorization | Authenticated server-side `.maybeSingle()` lookup by post ID and owner | Not a logged-out surface; authenticated owners continue resolving members-only posts | Compatible; unauthenticated upload requests are rejected earlier |
| Reactions | No current React reaction read/rendering surface was found | Future anonymous reads may show reactions only for public parents | Database helper must change now to protect direct API reads |
| Following | Required by V1 decisions but not currently implemented in the application | No current logged-out surface; future Following is authenticated and may include members-only posts | No present query to change |
| Homepage Hero | No current application post reader is wired | Future flagged posts remain public under the invariant described below | No current query |
| Post moderation audit | Separate authenticated active-admin policy | No logged-out rows | Unchanged |

### Filtering behavior

RLS-denied `SELECT` rows normally produce an empty or reduced result rather than a PostgreSQL authorization error because the table-level `SELECT` grant remains.

Consequences:

- A logged-out Wall receives fewer rows or `[]`.
- RLS filtering occurs before ordering and limit, so keyset pagination operates over the visible subset.
- A Wall containing only members-only posts resolves to the existing terminal empty state rather than a permanent skeleton.
- A direct `.maybeSingle()` lookup of a hidden post ordinarily returns `data = null`; a `.single()` lookup would instead produce PostgREST's no-row error. The current upload ownership path uses `.maybeSingle()` and is authenticated.
- No current server component reads posts in a way that should throw solely because 11D filters anonymous rows.

### Pre-implementation authentication-state freshness finding

Before the coordinated app slice, `ProfileWall` reloaded when `profile.id` changed, not when authentication state changed. A visitor who opened a Wall logged out and then signed in without a route remount could retain the anonymous subset until refresh.

The implemented application slice now subscribes to authentication changes, rejects stale initial auth snapshots, clears stale posts at identity boundaries, and refetches the Wall.

### Implemented empty-state finding

Before the coordinated slice, the non-owner Wall empty state said:

> No posts yet

A logged-out empty result can mean either that no posts exist or that no public posts exist. The implemented logged-out non-owner state now says:

> No public posts yet

This is accurate without revealing whether members-only posts exist.

---

## 6. Current-system finding: Hero posts remain public

The existing database has three protections tying Hero eligibility to Stream/public eligibility:

1. `posts_hero_state_check` requires `show_in_stream = true` whenever `is_hero_featured = true`.
2. `admin_flag_post_for_hero(...)` explicitly rejects a post with `show_in_stream = false`.
3. When a non-admin changes a flagged post from `show_in_stream = true` to `false`, the post invariant trigger clears `is_hero_featured`, `hero_featured_at`, and `hero_featured_by` atomically.

Banning an author also clears that author's Hero state.

Therefore every valid future Hero row is Stream-enabled and qualifies for anonymous visibility under 11D, subject to the unchanged author-ban rule. The future Hero does not need a separate anonymous-visibility exception.

Preflight and verification must still assert:

```text
zero rows where is_hero_featured = true and show_in_stream = false
```

No Hero backfill is expected because the validated constraint already prohibits that state.

---

## 7. Approved composer wording — implemented

At design capture, the checkbox said:

> Show in Stream

The implemented replacement is:

**Checkbox label**

> Make this post public

**Checked state**

> **Public** — everyone can see it on your Wall and in Stream.

**Unchecked state**

> **Members only** — signed-in people can see it on your Wall. It won’t appear in Stream.

This avoids inaccurate terms such as "private," "Wall only," or "followers only." An unchecked post is not private to its author and is not restricted to followers; every authenticated member can read it.

The former owner-only card badge:

> Wall only

is now:

> Members only

The coordinated application slice implements the checkbox, state copy, owner badge, authentication-state refetch, stale-auth-snapshot protection, and logged-out empty-state copy.

---

## 8. Proposed Chunk 11D package

Recommended artifacts:

- `chunk-11d-post-visibility-preflight.sql`
- `chunk-11d-post-visibility-apply.sql`
- `chunk-11d-post-visibility-verify.sql`
- `chunk-11d-post-visibility-rollback.sql`

### Dependencies and risk

- **Dependencies:** Chunk 11A, 11B, and 11C owner-applied and independently verified.
- **Risk:** Medium. A stale permissive policy or incorrect helper body could expose members-only content.
- **Data migration:** None.
- **Backfill:** None.
- **New index:** None initially. Existing profile chronology, Stream partial, Hero partial, and reaction parent/code indexes remain appropriate.
- **Table grants:** No intended change.
- **Write RPCs:** No intended change.

### 8.1 Preflight

The preflight should be read-only and return one clearly named owner go/no-go summary row. It should verify:

- execution against the intended project and expected owner context;
- `posts` and `post_reactions` exist;
- both tables have their expected owner, RLS enabled, and FORCE RLS enabled;
- exact current direct table ACLs;
- `service_role` exists and has the expected `BYPASSRLS` attribute;
- the exact current post policy set consists of the one legacy `public` policy with the captured qualifier;
- the exact current reaction policy set consists of the one legacy `public` policy with the captured qualifier;
- `current_user_can_read_post_author(...)` and `current_user_can_read_post_reaction(...)` have the expected signatures, owners, volatility, `SECURITY DEFINER`, empty `search_path`, definitions, and direct ACLs;
- the proposed new helper signature does not already exist;
- `show_in_stream` is non-nullable;
- the Hero constraint exists, is validated, and has zero violations;
- zero reactions have a missing parent;
- aggregate counts of public and members-only posts;
- aggregate counts of reactions attached to public and members-only posts;
- no conflicting 11D policy or helper names exist.

The preflight should not export post bodies, image URLs, handles, reaction identities, or other row-level content.

Because the repository Chunk 11 headers are stale relative to owner-confirmed deployment, live-catalog checks are mandatory. 11D must fail closed if the live definitions differ from the captured baseline.

### 8.2 Apply

The apply artifact should use one guarded transaction and follow the Chunk 11 hardening conventions:

1. Require execution as the reviewed owner role.
2. Set bounded lock and statement timeouts.
3. Reassert the expected old table, policy, helper, ACL, RLS, and role-attribute state inside the transaction.
4. Create `current_user_can_read_post(uuid, boolean)` with:
   - `STABLE`;
   - `SECURITY DEFINER`;
   - `SET search_path = ''`;
   - schema-qualified application references;
   - owner `postgres`;
   - explicit ACL revokes from `PUBLIC` and every unneeded API role;
   - execution granted only to `anon` and `authenticated`.
5. Drop and recreate or replace the post read policy so its sole qualifier uses `current_user_can_read_post(profile_id, show_in_stream)`.
6. Replace `current_user_can_read_post_reaction(uuid, uuid)` so it calls `current_user_can_read_post(post.profile_id, post.show_in_stream)` while preserving the existing reactor-ban predicate.
7. Preserve the existing reaction policy only if its exact qualifier still calls the corrected helper; otherwise recreate it with that qualifier.
8. Do not retain the old broad post qualifier as an additional permissive policy.
9. Do not change table grants, mutation RPC signatures, mutation RPC ACLs, post/reaction constraints, or stored rows.
10. Assert the exact final policy set, helper properties, helper ACLs, table grants, and unchanged Hero invariant before commit.

The function replacement must use meaningful old-definition drift guards. It should not rely on an unobserved catalog-body hash.

### 8.3 Verify

The verify artifact should be read-only and should distinguish catalog proof from role-specific runtime proof.

#### Catalog and invariant checks

Verify:

- exact post and reaction policy count, names, roles, commands, permissive mode, qualifiers, and null `WITH CHECK` expressions;
- absence of the old broad post qualifier;
- new helper signature, owner, volatility, `SECURITY DEFINER`, empty `search_path`, body, and exact direct ACLs;
- corrected reaction-helper body and unchanged reactor-ban predicate;
- exact direct ACLs for the reaction helper;
- unchanged post and reaction table grants;
- RLS and FORCE RLS remain enabled;
- `service_role` retains its expected bypass attribute;
- direct post/reaction client mutations remain unavailable;
- mutation RPC signatures and grants remain unchanged;
- Hero constraint remains validated with zero violations;
- Stream query behavior remains application-filtered by `show_in_stream = true`;
- no invalid reaction parent exists.

#### Runtime viewer matrix

Where representative existing data permits, verify:

| Viewer | Author | `show_in_stream` | Post | Unbanned reaction |
|---|---|---:|---:|---:|
| Anonymous | Unbanned | `true` | Visible | Visible |
| Anonymous | Unbanned | `false` | Hidden | Hidden |
| Authenticated non-admin | Unbanned | `true` | Visible | Visible |
| Authenticated non-admin | Unbanned | `false` | Visible | Visible |
| Authenticated banned viewer | Unbanned | `false` | Visible | Visible if reactor is unbanned |
| Anonymous/authenticated non-admin | Banned | Either | Hidden | Hidden |
| Active authenticated admin | Banned | Either | Visible | Visible only if reactor is unbanned |
| Expected `BYPASSRLS` service role | Any | Either | Visible | Visible |

Also verify:

- anonymous direct lookup of a known members-only post ID returns zero rows;
- anonymous direct reaction lookup or aggregate for that post returns zero rows;
- authenticated lookup returns the same members-only post and its allowed reactions;
- anonymous invocation of the corrected reaction helper cannot confirm a members-only parent;
- non-admin switching a Hero post to members-only still clears Hero state atomically;
- admin flagging a members-only post remains rejected.

Role-specific probes should use the real `anon` path and an existing approved authenticated session. A SQL Editor owner/no-JWT call alone cannot prove anonymous versus authenticated behavior.

If preflight finds no suitable members-only post or reaction fixture, report that runtime branch as unproven rather than creating a test user, creating persistent profile data, or silently weakening verification.

### 8.4 Rollback

The rollback artifact should use one guarded transaction and:

1. Confirm the exact expected 11D state before changing anything.
2. Restore the captured pre-11D reaction-helper body and direct ACLs.
3. Restore the captured pre-11D post policy qualifier and exact policy set.
4. Drop `current_user_can_read_post(uuid, boolean)` only after all dependent policies/functions have been restored.
5. Reassert the exact pre-11D policy, helper, table-grant, RLS, and ACL state.
6. Commit only if every rollback postcondition passes.

Rollback is lossless at the data level because 11D changes authorization only. Its intentional consequence is that `show_in_stream = false` posts and their reactions become anonymously readable again.

---

## 9. Coordinated non-SQL implementation work — completed locally

After owner application and database verification, the coordinated application/docs slice:

- replaced the composer checkbox copy and added checked/unchecked explanatory state;
- replaced the owner badge `Wall only` with `Members only`;
- made Wall data refresh when authentication state changes or authentication completes;
- added `No public posts yet` for logged-out non-owner empty Walls;
- updated `docs/V1_DECISIONS.md` to supersede the former “hidden only from Stream” wording;
- updated `docs/WALL_DATA_MODEL_PROPOSAL.md` to record centralized public/members-only RLS;
- added application regressions for copy, Stream-filter retention, stale-row clearing, and delayed initial-auth snapshots; and
- left staging refresh and browser verification pending under the approved service-owner workflow.

---

## 10. Open questions and trade-offs

### 10.1 Anonymous reaction representation

| Option | Trade-off |
|---|---|
| Preserve full existing reaction rows on public posts | Minimal change; retains reactor profile IDs and timestamps already exposed today |
| Expose aggregate emoji counts only | Better identity minimization, but requires a new view/RPC and application contract |
| Hide all reactions from anonymous visitors | Strongest privacy, but public posts appear less interactive and differs from current visibility |

**Recommendation:** Preserve full existing reaction rows on public posts for 11D. Treat aggregate-only reactions as a separate privacy/API decision.

### 10.2 Policy architecture

| Option | Trade-off |
|---|---|
| One centralized `current_user_can_read_post(...)` helper used by posts and reactions | One authoritative decision, one policy per table, minimal policy-OR risk; depends on reviewed `auth.role()` semantics |
| Separate `anon` and `authenticated` policies plus a dedicated anonymous reaction helper | Role behavior is explicit in catalog policies; creates more policies/helpers and more rollback/verification surface |

**Recommendation:** Use the centralized helper and keep exactly one permissive read policy per table.

### 10.3 Logged-out empty-Wall copy

| Option | Trade-off |
|---|---|
| Keep `No posts yet` | Reveals nothing about visibility state but can imply that no posts exist |
| Use `No public posts yet` | Accurately describes the visible subset without confirming members-only rows exist |

**Recommendation:** Use `No public posts yet` for logged-out non-owner Walls.

### 10.4 Members-only owner badge

| Option | Trade-off |
|---|---|
| Remove the former `Wall only` badge | Less UI clutter but no visibility reminder for the author |
| Replace it with `Members only` | Accurately reminds the author who can see the post |

**Recommendation:** Replace it with `Members only`.

### 10.5 Banned author's access to their own posts

| Option | Trade-off |
|---|---|
| Preserve the exact existing helper behavior | A banned author cannot read their own banned-author posts unless also an active admin; no scope expansion |
| Add an explicit author exception | Changes ban semantics and requires a separate security decision and verification matrix |

**Recommendation:** Preserve the exact existing behavior in 11D.

### 10.6 Reactions on members-only posts

| Option | Trade-off |
|---|---|
| Authenticated members may react | Matches their read access and preserves current reaction RPC behavior |
| Members-only posts are readable but cannot be reacted to | Requires new mutation restrictions and potentially confusing UI behavior |

**Recommendation:** Allow authenticated members to react to members-only posts.

### 10.7 Logged-out direct-link behavior

| Option | Trade-off |
|---|---|
| Silent filtering/not-found | Avoids confirming that a members-only post exists |
| Sign-in prompt that confirms the post exists | Better conversion UX but leaks existence and requires a direct-post surface/contract |

**Recommendation:** Use silent filtering/not-found. Do not reveal members-only post existence to anonymous visitors.

### 10.8 Authentication-state refresh

| Option | Trade-off |
|---|---|
| Make `ProfileWall` subscribe/react to authentication-state changes | Wall refreshes correctly wherever auth changes; adds component auth coupling |
| Trigger a targeted router refresh/remount after successful sign-in | Smaller Wall change; depends on every auth completion path doing it correctly |
| Require manual reload | No implementation work but stale anonymous subsets remain visible after sign-in |

**Recommendation:** Make Wall loading explicitly react to authentication-state changes, with a post-sign-in refresh as defense in depth.

### 10.9 Documentation timing

| Option | Trade-off |
|---|---|
| Update decision/data-model docs with the coordinated implementation | Keeps binding scope and database documentation truthful before launch |
| Leave the old wording as historical context | Creates a direct contradiction with live RLS and future maintenance risk |

**Recommendation:** Update both `V1_DECISIONS.md` and `WALL_DATA_MODEL_PROPOSAL.md` in the coordinated implementation slice after 11D is applied and verified.
