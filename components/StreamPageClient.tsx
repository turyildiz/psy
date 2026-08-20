"use client";

import { useCallback, useEffect, useMemo, useRef, useState, useTransition, type CSSProperties } from "react";
import { useRouter } from "next/navigation";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import AuthModal from "@/components/AuthModal";
import PageHero from "@/components/PageHero";
import ScrollToTopButton from "@/components/ScrollToTopButton";
import {
  POST_PAGE_SIZE,
  PostCard,
  PostListSkeleton,
  toPost,
  type Post,
  type PostAuthor,
} from "@/components/ProfileWall";
import { createClient } from "@/lib/supabase/client";
import { getStreamHeroImage } from "@/lib/stream-hero";
import { getStreamLocalDateBounds, streamRangeQueryString, type StreamDateRange } from "@/lib/posts/date-range";
import { useReactionViewerProfileId } from "@/lib/posts/use-reaction-viewer";

type StreamPost = {
  post: Post;
  profile: PostAuthor;
  animationIndex: number;
};

function toStreamPost(row: Record<string, unknown>): StreamPost | null {
  const rawProfile = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
  if (!rawProfile || typeof rawProfile !== "object") return null;
  const profileRow = rawProfile as Record<string, unknown>;
  const id = typeof profileRow.id === "string" ? profileRow.id : "";
  const handle = typeof profileRow.handle === "string" ? profileRow.handle : "";
  if (!id || !handle) return null;

  return {
    post: toPost(row),
    animationIndex: 0,
    profile: {
      id,
      handle,
      displayName: typeof profileRow.display_name === "string" && profileRow.display_name
        ? profileRow.display_name
        : handle,
      avatarUrl: typeof profileRow.avatar_url === "string" ? profileRow.avatar_url : undefined,
    },
  };
}

export default function StreamPageClient({ range }: { range: StreamDateRange }) {
  const router = useRouter();
  const viewerProfileId = useReactionViewerProfileId();
  const rangeKey = `${range.from ?? ""}:${range.to ?? ""}`;
  const [posts, setPosts] = useState<StreamPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [resolvedRangeKey, setResolvedRangeKey] = useState<string | null>(null);
  const [rangeNavigationPending, startRangeTransition] = useTransition();
  const [reactionLoginOpen, setReactionLoginOpen] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [rangeOpen, setRangeOpen] = useState(false);
  const [draftFrom, setDraftFrom] = useState(range.from ?? "");
  const [draftTo, setDraftTo] = useState(range.to ?? "");
  const rangeBounds = useMemo(() => getStreamLocalDateBounds(range), [range.from, range.to]);
  const requestGeneration = useRef(0);
  const paginationInFlight = useRef<number | null>(null);
  const rangeToolbarRef = useRef<HTMLDivElement>(null);

  const loadPosts = useCallback(async (reset: boolean) => {
    if (!reset && paginationInFlight.current !== null) return;
    const requestId = reset ? requestGeneration.current + 1 : requestGeneration.current;
    if (reset) {
      requestGeneration.current += 1;
      paginationInFlight.current = null;
      setLoading(true);
      setLoadingMore(false);
      setPosts([]);
      setHasMore(false);
    } else {
      paginationInFlight.current = requestId;
      setLoadingMore(true);
    }
    setLoadError(null);

    let query = createClient()
      .from("posts")
      .select("id, profile_id, body, images, show_in_stream, created_at, updated_at, profiles(id, handle, display_name, avatar_url), post_reactions(profile_id, reaction_code)")
      .eq("show_in_stream", true)
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(POST_PAGE_SIZE + 1);

    if (rangeBounds.fromInclusive) query = query.gte("created_at", rangeBounds.fromInclusive);
    if (rangeBounds.toExclusive) query = query.lt("created_at", rangeBounds.toExclusive);

    const cursor = reset ? null : posts[posts.length - 1]?.post;
    if (cursor) {
      query = query.or(`created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id.lt.${cursor.id})`);
    }

    try {
      const { data, error } = await query;
      if (requestId !== requestGeneration.current) return;
      if (error) {
        setLoadError("Could not load the Stream. Please try again.");
      } else {
        const next = (data ?? [])
          .slice(0, POST_PAGE_SIZE)
          .map((row) => toStreamPost(row as Record<string, unknown>))
          .filter((entry): entry is StreamPost => entry !== null)
          .map((entry, index) => ({ ...entry, animationIndex: Math.min(index, 9) }));
        setHasMore((data ?? []).length > POST_PAGE_SIZE);
        setPosts((current) => reset ? next : [...current, ...next]);
      }
    } catch {
      if (requestId === requestGeneration.current) {
        setLoadError("Could not load the Stream. Please try again.");
      }
    } finally {
      if (paginationInFlight.current === requestId) paginationInFlight.current = null;
      if (requestId === requestGeneration.current) {
        if (reset) setResolvedRangeKey(rangeKey);
        setLoading(false);
        setLoadingMore(false);
      }
    }
  }, [posts, rangeBounds.fromInclusive, rangeBounds.toExclusive, rangeKey]);

  useEffect(() => {
    setDraftFrom(range.from ?? "");
    setDraftTo(range.to ?? "");
    void loadPosts(true);
    return () => {
      requestGeneration.current += 1;
      paginationInFlight.current = null;
    };
    // The first page reloads when the server-validated range changes; subsequent pages use the latest button handler.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [range.from, range.to]);

  useEffect(() => {
    if (!rangeOpen) return;
    const closeOnOutsideClick = (event: PointerEvent) => {
      if (!rangeToolbarRef.current?.contains(event.target as Node)) setRangeOpen(false);
    };
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setRangeOpen(false);
    };
    document.addEventListener("pointerdown", closeOnOutsideClick);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("pointerdown", closeOnOutsideClick);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [rangeOpen]);

  const rangeActive = Boolean(range.from || range.to);
  const rangeLabel = rangeActive
    ? `${range.from ?? "Any start"} – ${range.to ?? "Any end"}`
    : "All time";
  const requestInFlight = loading || rangeNavigationPending || resolvedRangeKey !== rangeKey;

  function applyRange() {
    let from = draftFrom;
    let to = draftTo;
    if (from && to && from > to) [from, to] = [to, from];
    setDraftFrom(from);
    setDraftTo(to);
    setRangeOpen(false);
    const queryString = streamRangeQueryString({ from: from || null, to: to || null });
    startRangeTransition(() => {
      if (queryString) router.push(`/stream?${queryString}`);
      else router.push("/stream");
    });
  }

  function clearRange() {
    setDraftFrom("");
    setDraftTo("");
    setRangeOpen(false);
    startRangeTransition(() => router.push("/stream"));
  }

  return (
    <div className="stream-page">
      <Header />
      <PageHero
        imageSrc={getStreamHeroImage()}
        objectPosition="50% center"
        eyebrow="Community"
        title="Stream"
        description="Latest posts from across psy.market, newest first."
        contentClassName="stream-page-hero-text"
      />
      <section className="stream-range-sticky" aria-label="Time range filter">
        <div ref={rangeToolbarRef} className="stream-range-control">
          <div className="stream-range-toolbar">
            <div className="stream-range-menu">
              <button
                type="button"
                className={`stream-range-toggle${rangeActive ? " is-active" : ""}`}
                onClick={() => setRangeOpen((open) => !open)}
                aria-haspopup="true"
                aria-expanded={rangeOpen}
                aria-controls="stream-range-popover"
              >
                <span className="stream-range-key">Time range</span>
                <span className="stream-range-value">{rangeLabel}</span>
                <svg width="10" height="6" viewBox="0 0 10 6" aria-hidden style={{ transform: rangeOpen ? "rotate(180deg)" : "none" }}><path d="M1 1l4 4 4-4" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
              </button>
              {rangeOpen && (
                <form id="stream-range-popover" className="stream-range-popover" onSubmit={(event) => { event.preventDefault(); applyRange(); }}>
                  <label>
                    <span>From</span>
                    <span className="stream-range-date-field">
                      <input type="date" value={draftFrom} max={draftTo || undefined} onChange={(event) => {
                        const next = event.target.value;
                        setDraftFrom(next);
                        if (next && draftTo && next > draftTo) setDraftTo(next);
                      }} />
                      <svg className="stream-range-date-icon" width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
                        <rect x="1.5" y="2.5" width="11" height="10" rx="2" stroke="currentColor" />
                        <path d="M4 1v3M10 1v3M2 5.5h10" stroke="currentColor" strokeLinecap="round" />
                      </svg>
                    </span>
                  </label>
                  <label>
                    <span>To</span>
                    <span className="stream-range-date-field">
                      <input type="date" value={draftTo} min={draftFrom || undefined} onChange={(event) => {
                        const next = event.target.value;
                        setDraftTo(next);
                        if (next && draftFrom && next < draftFrom) setDraftFrom(next);
                      }} />
                      <svg className="stream-range-date-icon" width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
                        <rect x="1.5" y="2.5" width="11" height="10" rx="2" stroke="currentColor" />
                        <path d="M4 1v3M10 1v3M2 5.5h10" stroke="currentColor" strokeLinecap="round" />
                      </svg>
                    </span>
                  </label>
                  <div className="stream-range-actions">
                    <button type="button" className="stream-range-popover-clear" onClick={clearRange} disabled={rangeNavigationPending}>Clear</button>
                    <button type="submit" className="stream-range-apply" disabled={rangeNavigationPending}>{rangeNavigationPending ? "Applying…" : "Apply"}</button>
                  </div>
                </form>
              )}
            </div>
          </div>
          {rangeActive && (
            <div className="stream-range-active-filters" aria-label="Active filters">
              <button type="button" className="stream-range-chip" onClick={clearRange} disabled={rangeNavigationPending}>
                <span className="stream-range-chip-key">RANGE</span>
                <span>{rangeLabel}</span>
                <span aria-hidden="true">×</span>
                <span className="sr-only">Remove time range filter</span>
              </button>
              <button type="button" className="stream-range-clear-link" onClick={clearRange} disabled={rangeNavigationPending}>Clear</button>
            </div>
          )}
        </div>
      </section>
      <main className="site-shell stream-shell">
        <div className="stream-column">
          {requestInFlight ? (
            <PostListSkeleton label="Loading Stream" />
          ) : loadError && posts.length === 0 ? (
            <div className="post-empty">
              <p>{loadError}</p>
              <button type="button" onClick={() => void loadPosts(true)}>Try again</button>
            </div>
          ) : posts.length === 0 ? (
            <div className="post-empty">
              <h2>{rangeActive ? "No posts in this period" : "No posts in the Stream yet"}</h2>
              <p>{rangeActive ? "Try another date range or clear the filter." : "Check back soon for something new."}</p>
            </div>
          ) : (
            <div className="post-list">
              {posts.map(({ post, profile, animationIndex }) => (
                <div
                  key={post.id}
                  className="stagger-item"
                  style={{ "--i": animationIndex } as CSSProperties}
                >
                  <PostCard
                    post={post}
                    profile={profile}
                    isOwner={false}
                    viewerProfileId={viewerProfileId}
                    onLoginRequested={() => setReactionLoginOpen(true)}
                    onUpdated={() => {}}
                    onDeleted={() => {}}
                  />
                </div>
              ))}
              {loadError && <p className="post-form-error" role="alert">{loadError}</p>}
              {hasMore && (
                <button type="button" className="post-load-more" onClick={() => void loadPosts(false)} disabled={loadingMore}>
                  {loadingMore ? "Loading…" : "Load more"}
                </button>
              )}
            </div>
          )}
        </div>
      </main>
      <Footer />
      <ScrollToTopButton />
      {reactionLoginOpen && <AuthModal initial="login" onClose={() => setReactionLoginOpen(false)} />}

      <style>{`
        .stream-page { min-height: 100vh; background: var(--cream); }
        .stream-page-hero-text { max-width: 760px; }
        .stream-shell { padding-top: 28px; padding-bottom: 80px; }
        .stream-column { max-width: 680px; margin: 0 auto; }
        .stream-range-sticky { position: sticky; top: 72px; z-index: 100; width: calc(100% - 32px); max-width: 680px; margin: 0 auto; background: var(--cream); }
        .stream-range-control { padding: 12px 0; }
        .stream-range-toolbar { box-sizing: border-box; width: 100%; height: 56px; display: flex; align-items: center; border: 1px solid var(--sand); border-radius: 16px; background: var(--white); }
        .stream-range-menu { position: relative; width: 270px; max-width: 100%; height: 100%; }
        .stream-range-toggle { width: 100%; height: 100%; display: grid; grid-template-columns: auto minmax(0, 1fr) auto; align-items: center; gap: 10px; padding: 0 14px; border: 0; border-radius: 15px; background: transparent; color: var(--text-mid); font: 600 13px Manrope, var(--font-manrope); text-align: left; cursor: pointer; }
        .stream-range-toggle:hover, .stream-range-toggle[aria-expanded="true"] { background: var(--cream); color: var(--rust); }
        .stream-range-toggle.is-active { background: oklch(96% 0.025 55); color: var(--rust); }
        .stream-range-key { color: var(--text-light); font-size: 11px; font-weight: 600; letter-spacing: .12em; text-transform: uppercase; }
        .stream-range-value { overflow: hidden; color: var(--text); text-overflow: ellipsis; white-space: nowrap; }
        .stream-range-toggle.is-active .stream-range-value { color: var(--rust); }
        .stream-range-toggle svg { flex-shrink: 0; transition: transform 160ms ease; }
        .stream-range-popover { box-sizing: border-box; position: absolute; z-index: 5; top: calc(100% + 9px); left: 0; width: min(356px, calc(100vw - 32px)); display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px 10px; margin: 0; padding: 14px; border: 1px solid var(--sand); border-radius: 12px; background: var(--white); box-shadow: 0 14px 36px oklch(25% 0.03 50 / .17); }
        .stream-range-popover label { display: flex; flex-direction: column; gap: 6px; color: var(--text-light); font-size: 10px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }
        .stream-range-date-field { position: relative; display: block; }
        .stream-range-popover input { box-sizing: border-box; position: relative; width: 100%; min-width: 0; height: 40px; padding: 0 34px 0 10px; border: 1px solid var(--sand); border-radius: 8px; outline: none; appearance: none; -webkit-appearance: none; background: var(--cream); color: var(--text); color-scheme: light; font: 500 12px Manrope, var(--font-manrope); }
        .stream-range-date-icon { position: absolute; top: 50%; right: 10px; transform: translateY(-50%); color: var(--text-light); pointer-events: none; }
        .stream-range-popover input::-webkit-datetime-edit { padding: 0; color: var(--text); }
        .stream-range-popover input::-webkit-datetime-edit-fields-wrapper { padding: 0; }
        .stream-range-popover input::-webkit-datetime-edit-text { padding: 0 1px; color: var(--text-light); }
        .stream-range-popover input::-webkit-datetime-edit-day-field,
        .stream-range-popover input::-webkit-datetime-edit-month-field,
        .stream-range-popover input::-webkit-datetime-edit-year-field { color: var(--text); font: inherit; }
        .stream-range-popover input::-webkit-inner-spin-button { display: none; }
        .stream-range-popover input::-webkit-calendar-picker-indicator { position: absolute; inset: 0; width: auto; height: auto; margin: 0; padding: 0; opacity: 0; cursor: pointer; }
        .stream-range-popover input:focus { border-color: var(--rust); box-shadow: 0 0 0 2px oklch(58% 0.12 45 / .12); }
        .stream-range-actions { grid-column: 1 / -1; display: flex; align-items: center; justify-content: space-between; gap: 16px; }
        .stream-range-popover-clear { border: 0; background: transparent; color: var(--text-light); padding: 5px 0; font: 500 12px Manrope, var(--font-manrope); cursor: pointer; }
        .stream-range-popover-clear:hover { color: var(--text-mid); text-decoration: underline; }
        .stream-range-apply { min-height: 34px; border: 1px solid var(--rust); border-radius: 8px; background: var(--rust); color: white; padding: 6px 14px; font: 600 12px Manrope, var(--font-manrope); cursor: pointer; }
        .stream-range-active-filters { display: flex; align-items: center; gap: 9px; padding-top: 10px; }
        .stream-range-chip { display: flex; align-items: center; gap: 5px; min-width: 0; border: 0; border-radius: 999px; background: oklch(96% 0.025 55); color: var(--rust); padding: 5px 9px; font: 600 11px Manrope, var(--font-manrope); cursor: pointer; }
        .stream-range-chip > span:nth-child(2) { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .stream-range-chip-key { flex-shrink: 0; font-size: 9px; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; }
        .stream-range-clear-link { border: 0; background: transparent; color: var(--text-light); padding: 0; font: 500 12px Manrope, var(--font-manrope); cursor: pointer; }
        .stream-range-clear-link:hover { color: var(--text-mid); text-decoration: underline; }
        .stream-range-apply:disabled, .stream-range-popover-clear:disabled, .stream-range-chip:disabled, .stream-range-clear-link:disabled { opacity: .55; cursor: not-allowed; }
        .post-list { display: flex; flex-direction: column; gap: 16px; }
        .post-card { background: var(--white); border: 1px solid var(--sand); border-radius: 12px; padding: 20px; }
        .post-card header { display: flex; align-items: center; gap: 11px; margin-bottom: 16px; }
        .post-author-link { display: flex; align-items: center; gap: 11px; min-width: 0; color: inherit; text-decoration: none; }
        .post-author-copy { display: flex; flex-direction: column; min-width: 0; }
        .post-card header strong { color: var(--text); font-size: 13px; }
        .post-card header span { color: var(--text-light); font-size: 11px; }
        .post-images { display: grid; gap: 5px; margin-top: 16px; overflow: hidden; border-radius: 10px; }
        .post-images-1 { grid-template-columns: 1fr; }
        .post-images-2, .post-images-3, .post-images-4 { grid-template-columns: repeat(2, 1fr); }
        .post-images-5 { grid-template-columns: repeat(3, 1fr); }
        .post-images button { width: 100%; height: 280px; padding: 0; border: 0; background: var(--sand); cursor: zoom-in; overflow: hidden; }
        .post-images img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .post-images-1 button { height: auto; max-height: 620px; }
        .post-images-1 img { height: auto; max-height: 620px; }
        .post-images-3 button:first-child, .post-images-5 button:first-child { grid-row: span 2; height: 565px; }
        .post-form-error { margin: 12px 0 0; color: #a52e24; font-size: 12px; line-height: 1.5; }
        .post-load-more, .post-empty button { border: 1px solid var(--sand); background: var(--white); color: var(--text-mid); border-radius: 7px; padding: 8px 12px; font: 600 12px Manrope, var(--font-manrope); cursor: pointer; }
        .post-load-more { align-self: center; margin-top: 8px; padding: 10px 24px; }
        .post-load-more:disabled { opacity: .55; cursor: not-allowed; }
        .post-empty { text-align: center; padding: 72px 20px; color: var(--text-light); }
        .post-empty h2 { margin: 0 0 7px; color: var(--text); font: 700 20px 'Bricolage Grotesque', var(--font-bricolage); }
        .post-empty p { margin: 0 0 16px; font-size: 13px; }
        .post-skeleton { height: 210px; border-radius: 12px; }
        @media (min-width: 769px) and (max-width: 1024px) { .stream-page-hero-text { max-width: 728px; } }
        @media (max-width: 768px) { .stream-page-hero-text { max-width: 712px; } }
        @media (max-width: 640px) {
          .stream-page-hero-text { padding-left: 16px; }
          .stream-range-sticky { top: 76px; }
          .stream-range-control { padding: 8px 0; }
          .stream-range-menu { width: 250px; }
          .stream-shell { padding-top: 20px; }
          .post-card { padding: 15px; border-radius: 10px; }
          .post-images button { height: 190px; }
          .post-images-1 button { height: auto; }
          .post-images-1 img { height: auto; }
          .post-images-5 { grid-template-columns: repeat(2, 1fr); }
          .post-images-3 button:first-child, .post-images-5 button:first-child { height: 385px; }
          .post-card header { align-items: flex-start; }
        }
        @media (max-width: 420px) {
          .stream-range-popover { grid-template-columns: 1fr; }
          .stream-range-actions { grid-column: 1; }
        }
        @media (prefers-reduced-motion: reduce) {
          .stream-range-toggle svg { transition: none; }
        }
      `}</style>
    </div>
  );
}
