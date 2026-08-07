"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import {
  POST_PAGE_SIZE,
  PostCard,
  toPost,
  type Post,
  type PostAuthor,
} from "@/components/ProfileWall";
import { createClient } from "@/lib/supabase/client";
import { getStreamLocalDateBounds, streamRangeQueryString, type StreamDateRange } from "@/lib/posts/date-range";

type StreamPost = {
  post: Post;
  profile: PostAuthor;
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
  const [posts, setPosts] = useState<StreamPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [rangeOpen, setRangeOpen] = useState(Boolean(range.from || range.to));
  const [draftFrom, setDraftFrom] = useState(range.from ?? "");
  const [draftTo, setDraftTo] = useState(range.to ?? "");
  const rangeBounds = useMemo(() => getStreamLocalDateBounds(range), [range.from, range.to]);
  const requestGeneration = useRef(0);
  const paginationInFlight = useRef<number | null>(null);

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
      .select("id, profile_id, body, images, show_in_stream, created_at, updated_at, profiles(id, handle, display_name, avatar_url)")
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
          .filter((entry): entry is StreamPost => entry !== null);
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
        setLoading(false);
        setLoadingMore(false);
      }
    }
  }, [posts, rangeBounds.fromInclusive, rangeBounds.toExclusive]);

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

  const rangeActive = Boolean(range.from || range.to);

  function applyRange() {
    let from = draftFrom;
    let to = draftTo;
    if (from && to && from > to) [from, to] = [to, from];
    setDraftFrom(from);
    setDraftTo(to);
    setRangeOpen(false);
    const queryString = streamRangeQueryString({ from: from || null, to: to || null });
    if (queryString) router.push(`/stream?${queryString}`);
    else router.push("/stream");
  }

  function clearRange() {
    setDraftFrom("");
    setDraftTo("");
    setRangeOpen(false);
    router.push("/stream");
  }

  return (
    <div className="stream-page">
      <Header />
      <main className="site-shell stream-shell">
        <div className="stream-column">
          <div className="stream-heading">
            <span>Community</span>
            <h1>Stream</h1>
            <p>Latest posts from across psy.market, newest first.</p>
          </div>

          <div className="stream-range-bar">
            <div className="stream-range-summary">
              <button type="button" className={`stream-range-toggle${rangeActive ? " active" : ""}`} onClick={() => setRangeOpen((open) => !open)} aria-expanded={rangeOpen} aria-controls="stream-range-fields">
                <span>Time range</span>
                {rangeActive && <strong>{range.from ?? "Any start"} – {range.to ?? "Any end"}</strong>}
                <svg width="10" height="6" viewBox="0 0 10 6" aria-hidden><path d="M1 1l4 4 4-4" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
              </button>
              {rangeActive && <button type="button" className="stream-range-clear" onClick={clearRange}>Clear</button>}
            </div>
            {rangeOpen && (
              <form id="stream-range-fields" className="stream-range-fields" onSubmit={(event) => { event.preventDefault(); applyRange(); }}>
                <label>
                  <span>From</span>
                  <input type="date" value={draftFrom} max={draftTo || undefined} onChange={(event) => {
                    const next = event.target.value;
                    setDraftFrom(next);
                    if (next && draftTo && next > draftTo) setDraftTo(next);
                  }} />
                </label>
                <label>
                  <span>To</span>
                  <input type="date" value={draftTo} min={draftFrom || undefined} onChange={(event) => {
                    const next = event.target.value;
                    setDraftTo(next);
                    if (next && draftFrom && next < draftFrom) setDraftFrom(next);
                  }} />
                </label>
                <button type="submit" className="stream-range-apply">Apply</button>
                {(draftFrom || draftTo) && <button type="button" className="stream-range-clear" onClick={clearRange}>Clear</button>}
              </form>
            )}
          </div>

          {loading ? (
            <div className="post-list" aria-label="Loading Stream">
              {Array.from({ length: 3 }).map((_, index) => <div key={index} className="skeleton-block post-skeleton" />)}
            </div>
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
              {posts.map(({ post, profile }) => (
                <PostCard
                  key={post.id}
                  post={post}
                  profile={profile}
                  isOwner={false}
                  onUpdated={() => {}}
                  onDeleted={() => {}}
                />
              ))}
              {loadError && <p className="post-form-error" role="alert">{loadError}</p>}
              {hasMore && (
                <button type="button" className="post-load-more" onClick={() => void loadPosts(false)} disabled={loadingMore}>
                  Load more
                </button>
              )}
            </div>
          )}
        </div>
      </main>
      <Footer />

      <style>{`
        .stream-page { min-height: 100vh; background: var(--cream); }
        .stream-shell { padding-top: 42px; padding-bottom: 80px; }
        .stream-column { max-width: 680px; margin: 0 auto; }
        .stream-heading { margin-bottom: 26px; }
        .stream-heading > span { color: var(--rust); font-size: 11px; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; }
        .stream-heading h1 { margin: 5px 0 7px; color: var(--text); font: 700 36px/1.1 'Bricolage Grotesque', var(--font-bricolage); letter-spacing: -.025em; }
        .stream-heading p { margin: 0; color: var(--text-light); font-size: 13px; }
        .stream-range-bar { margin-bottom: 22px; padding: 10px 12px; background: var(--white); border: 1px solid var(--sand); border-radius: 9px; box-shadow: 0 2px 8px oklch(0% 0 0 / .04); }
        .stream-range-summary { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
        .stream-range-toggle { display: flex; align-items: center; gap: 9px; min-width: 0; padding: 6px 8px; border: 0; background: transparent; color: var(--text-mid); font: 600 12px Manrope, var(--font-manrope); cursor: pointer; }
        .stream-range-toggle.active { color: var(--rust); }
        .stream-range-toggle strong { overflow: hidden; color: var(--text); font-size: 11px; font-weight: 500; text-overflow: ellipsis; white-space: nowrap; }
        .stream-range-toggle svg { flex-shrink: 0; }
        .stream-range-fields { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto auto; align-items: end; gap: 10px; margin-top: 10px; padding-top: 12px; border-top: 1px solid var(--sand); }
        .stream-range-fields label { display: flex; flex-direction: column; gap: 5px; color: var(--text-light); font-size: 10px; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; }
        .stream-range-fields input { width: 100%; min-width: 0; padding: 7px 9px; border: 1px solid var(--sand); border-radius: 6px; outline: none; background: transparent; color: var(--text); font: 500 12px Manrope, var(--font-manrope); }
        .stream-range-fields input:focus { border-color: var(--rust); }
        .stream-range-apply, .stream-range-clear { border-radius: 6px; padding: 8px 12px; font: 600 12px Manrope, var(--font-manrope); cursor: pointer; }
        .stream-range-apply { border: 1px solid var(--rust); background: var(--rust); color: white; }
        .stream-range-clear { border: 0; background: transparent; color: var(--rust); }
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
        @media (max-width: 640px) {
          .stream-shell { padding-top: 28px; }
          .stream-heading h1 { font-size: 31px; }
          .stream-range-fields { grid-template-columns: 1fr 1fr; }
          .stream-range-apply, .stream-range-fields .stream-range-clear { width: 100%; }
          .post-card { padding: 15px; border-radius: 10px; }
          .post-images button { height: 190px; }
          .post-images-1 button { height: auto; }
          .post-images-1 img { height: auto; }
          .post-images-5 { grid-template-columns: repeat(2, 1fr); }
          .post-images-3 button:first-child, .post-images-5 button:first-child { height: 385px; }
          .post-card header { align-items: flex-start; }
        }
      `}</style>
    </div>
  );
}
