"use client";

import { useCallback, useEffect, useRef, useState } from "react";
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

export default function StreamPage() {
  const [posts, setPosts] = useState<StreamPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
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
  }, [posts]);

  useEffect(() => {
    void loadPosts(true);
    return () => {
      requestGeneration.current += 1;
      paginationInFlight.current = null;
    };
    // The first page loads once; subsequent pages use the latest button handler.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
              <h2>No posts in the Stream yet</h2>
              <p>Check back soon for something new.</p>
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
