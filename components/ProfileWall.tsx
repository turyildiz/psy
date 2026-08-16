"use client";

import { useCallback, useEffect, useRef, useState, type ChangeEvent } from "react";
import { createPortal } from "react-dom";
import Link from "next/link";
import ProfileAvatar from "@/components/ProfileAvatar";
import ImageLightbox from "@/components/ImageLightbox";
import AuthModal from "@/components/AuthModal";
import { createClient } from "@/lib/supabase/client";
import {
  createInitialAuthSnapshotGate,
  createWallAuthRefreshCoordinator,
} from "@/lib/auth/initial-snapshot-gate";
import { registerAuthUiRefreshParticipant } from "@/lib/auth/ui-transition";
import { uploadToR2 } from "@/lib/uploads/client";
import {
  IMAGE_ACCEPT,
  UNSUPPORTED_IMAGE_TYPE_MESSAGE,
  getUploadPolicy,
  selectAllowedImageFiles,
} from "@/lib/uploads/policy";
import {
  POST_BODY_MAX,
  getPostCharacterCount,
  getPostWriteErrorMessage,
  tokenizePostBody,
  validatePostBody,
} from "@/lib/posts/validation";
import type { Profile } from "@/types/marketplace";
import {
  POST_REACTION_ICON_VIEWBOX,
  POST_REACTION_OPTIONS,
  applyOptimisticPostReaction,
  summarizePostReactions,
  toPostReactionRows,
  type PostReactionCode,
  type PostReactionRow,
} from "@/lib/posts/reactions";
import { useReactionViewerProfileId } from "@/lib/posts/use-reaction-viewer";
import { getPostHighlightErrorMessage, getPostHighlightPreview } from "@/lib/posts/highlights";

export const POST_PAGE_SIZE = 10;
const POST_IMAGE_LIMIT = getUploadPolicy("post-image").maxCount;

export type Post = {
  id: string;
  profileId: string;
  body: string;
  images: string[];
  showInStream: boolean;
  createdAt: string;
  updatedAt: string;
  isHighlighted: boolean;
  highlightedAt: string | null;
  reactions: PostReactionRow[];
};

export type PostAuthor = Pick<Profile, "id" | "handle" | "displayName" | "avatarUrl">;

type ImageChoice = {
  id: string;
  previewUrl: string;
  existingUrl?: string;
  file?: File;
};

type PostEditorProps = {
  profileId: string;
  post?: Post;
  onCancel?: () => void;
  onSaved: (post?: Post) => void;
};

export function toPost(row: Record<string, unknown>): Post {
  return {
    id: String(row.id),
    profileId: String(row.profile_id),
    body: String(row.body),
    images: Array.isArray(row.images) ? row.images.filter((value): value is string => typeof value === "string") : [],
    showInStream: row.show_in_stream !== false,
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
    isHighlighted: row.is_highlighted === true,
    highlightedAt: typeof row.highlighted_at === "string" ? row.highlighted_at : null,
    reactions: toPostReactionRows(row.post_reactions),
  };
}

function formatPostDate(value: string) {
  return new Date(value).toLocaleDateString("en-IE", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function PostBody({ post }: { post: Post }) {
  return (
    <p style={{ margin: 0, whiteSpace: "pre-wrap", overflowWrap: "anywhere", color: "var(--text)", fontSize: "15px", lineHeight: 1.7 }}>
      {tokenizePostBody(post.body).map((token, index) => token.type === "link" ? (
        <a
          key={`${token.value}-${index}`}
          href={token.value}
          target="_blank"
          rel="noopener noreferrer"
          style={{ color: "var(--rust)", textDecoration: "underline", textUnderlineOffset: "2px" }}
        >
          {token.value}
        </a>
      ) : <span key={index}>{token.value}</span>)}
    </p>
  );
}

function PostImages({ images, onOpen }: { images: string[]; onOpen: (index: number) => void }) {
  if (images.length === 0) return null;
  return (
    <div className={`post-images post-images-${images.length}`}>
      {images.map((url, index) => (
        <button key={url} type="button" onClick={() => onOpen(index)} aria-label={`Open post image ${index + 1} of ${images.length}`}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={url} alt={`Post image ${index + 1} of ${images.length}`} />
        </button>
      ))}
    </div>
  );
}

function PostEditor({ profileId, post, onCancel, onSaved }: PostEditorProps) {
  const [body, setBody] = useState(post?.body ?? "");
  const [showInStream, setShowInStream] = useState(post?.showInStream ?? true);
  const [images, setImages] = useState<ImageChoice[]>(() => (post?.images ?? []).map((url) => ({
    id: url,
    previewUrl: url,
    existingUrl: url,
  })));
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const objectUrls = useRef(new Set<string>());

  useEffect(() => () => {
    objectUrls.current.forEach((url) => URL.revokeObjectURL(url));
    objectUrls.current.clear();
  }, []);

  const resetNewComposer = () => {
    objectUrls.current.forEach((url) => URL.revokeObjectURL(url));
    objectUrls.current.clear();
    setBody("");
    setShowInStream(true);
    setImages([]);
    setError(null);
  };

  const chooseImages = (event: ChangeEvent<HTMLInputElement>) => {
    if (saving) return;
    const remaining = POST_IMAGE_LIMIT - images.length;
    const selected = selectAllowedImageFiles(event.target.files ?? [], remaining);
    if (selected.unsupportedTypeFound) setError(UNSUPPORTED_IMAGE_TYPE_MESSAGE);
    else if ((event.target.files?.length ?? 0) > remaining) setError("Posts can contain up to five images.");
    else setError(null);

    const additions = selected.accepted.map((file) => {
      const previewUrl = URL.createObjectURL(file);
      objectUrls.current.add(previewUrl);
      return { id: crypto.randomUUID(), previewUrl, file };
    });
    setImages((current) => [...current, ...additions]);
    event.target.value = "";
  };

  const removeImage = (id: string) => {
    setImages((current) => {
      const removed = current.find((item) => item.id === id);
      if (removed?.file) {
        URL.revokeObjectURL(removed.previewUrl);
        objectUrls.current.delete(removed.previewUrl);
      }
      return current.filter((item) => item.id !== id);
    });
    setError(null);
  };

  const save = async () => {
    const validationError = validatePostBody(body);
    if (validationError) {
      setError(validationError);
      return;
    }

    setSaving(true);
    setError(null);
    const uploadedImages: string[] = [];
    try {
      for (let index = 0; index < images.length; index += 1) {
        const image = images[index];
        if (image.existingUrl) uploadedImages.push(image.existingUrl);
        else if (image.file) {
          uploadedImages.push(await uploadToR2(image.file, {
            purpose: "post-image",
            ownerId: profileId,
            resourceId: post?.id,
            index,
          }));
        }
      }
    } catch {
      setError("Could not upload one of your images. Please try again.");
      setSaving(false);
      return;
    }

    const supabase = createClient();
    if (post) {
      const { error: updateError } = await supabase.rpc("update_post", {
        target_post_id: post.id,
        post_body: body,
        post_images: uploadedImages,
        include_in_stream: showInStream,
      });
      if (updateError) {
        setError(getPostWriteErrorMessage(updateError, "save"));
        setSaving(false);
        return;
      }
      onSaved({ ...post, body, images: uploadedImages, showInStream, updatedAt: new Date().toISOString() });
      return;
    }

    const { error: createError } = await supabase.rpc("create_post", {
      target_profile_id: profileId,
      post_body: body,
      post_images: uploadedImages,
      include_in_stream: showInStream,
    });
    if (createError) {
      setError(getPostWriteErrorMessage(createError, "publish"));
      setSaving(false);
      return;
    }
    resetNewComposer();
    setSaving(false);
    onSaved();
  };

  return (
    <div className={post ? "post-editor post-editor-inline" : "post-editor"}>
      {!post && <h2>Share something</h2>}
      <textarea
        value={body}
        onChange={(event) => {
          if (getPostCharacterCount(event.target.value) <= POST_BODY_MAX) setBody(event.target.value);
          setError(null);
        }}
        disabled={saving}
        rows={post ? 4 : 5}
        placeholder="What’s happening in your world? Add http:// or https:// links directly in your text."
        aria-label={post ? "Edit post text" : "Post text"}
      />
      <div className="post-editor-count" aria-live="polite">{getPostCharacterCount(body)}/{POST_BODY_MAX}</div>

      {images.length > 0 && (
        <div className="post-editor-previews">
          {images.map((image, index) => (
            <div key={image.id} className="post-editor-preview">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={image.previewUrl} alt={`Selected image ${index + 1}`} />
              <button type="button" onClick={() => removeImage(image.id)} aria-label={`Remove image ${index + 1}`} disabled={saving}>×</button>
            </div>
          ))}
        </div>
      )}

      <div className="post-editor-options">
        <div>
          <button
            type="button"
            className="post-image-button"
            onClick={() => inputRef.current?.click()}
            disabled={saving || images.length >= POST_IMAGE_LIMIT}
          >
            + Add images
          </button>
          <span>{images.length}/{POST_IMAGE_LIMIT}</span>
          <input ref={inputRef} type="file" accept={IMAGE_ACCEPT} multiple hidden onChange={chooseImages} disabled={saving} />
        </div>
        <div className="post-visibility-option">
          <label>
            <input type="checkbox" checked={showInStream} onChange={(event) => setShowInStream(event.target.checked)} disabled={saving} />
            Make this post public
          </label>
          <p>
            {showInStream ? (
              <><strong>Public</strong> — everyone can see it on your Wall and in Stream.</>
            ) : (
              <><strong>Members only</strong> — signed-in people can see it on your Wall. It won’t appear in Stream.</>
            )}
          </p>
        </div>
      </div>

      {error && <p className="post-form-error" role="alert">{error}</p>}
      <div className="post-editor-actions">
        {onCancel && <button type="button" className="post-secondary-button" onClick={onCancel} disabled={saving}>Cancel</button>}
        <button type="button" className="post-primary-button" onClick={save} disabled={saving || Boolean(validatePostBody(body))}>
          {saving ? (post ? "Saving…" : "Publishing…") : (post ? "Save changes" : "Publish")}
        </button>
      </div>
    </div>
  );
}

export function PostListSkeleton({ label }: { label: string }) {
  return (
    <div className="post-list" style={{ display: "flex", flexDirection: "column", gap: "16px" }} role="status" aria-label={label} aria-live="polite">
      {Array.from({ length: 3 }).map((_, index) => (
        <div
          key={index}
          className="skeleton-block post-skeleton"
          style={{ height: "210px", borderRadius: "12px" }}
          aria-hidden="true"
        />
      ))}
    </div>
  );
}

function PostReactionBar({
  post,
  viewerProfileId,
  onLoginRequested,
}: {
  post: Post;
  viewerProfileId: string | null | undefined;
  onLoginRequested: () => void;
}) {
  const [reactionRows, setReactionRows] = useState<PostReactionRow[]>(post.reactions);
  const [mutating, setMutating] = useState(false);
  const [reactionError, setReactionError] = useState<string | null>(null);
  const mutationGeneration = useRef(0);

  useEffect(() => {
    mutationGeneration.current += 1;
    setReactionRows(post.reactions);
    setMutating(false);
    setReactionError(null);
    return () => {
      mutationGeneration.current += 1;
    };
  }, [post.id, post.reactions]);

  const { counts, activeCode } = summarizePostReactions(
    reactionRows,
    typeof viewerProfileId === "string" ? viewerProfileId : null,
  );

  const react = async (code: PostReactionCode) => {
    if (viewerProfileId === undefined || mutating) return;
    if (viewerProfileId === null) {
      onLoginRequested();
      return;
    }

    const requestGeneration = ++mutationGeneration.current;
    const previousRows = reactionRows;
    const nextCode = activeCode === code ? null : code;
    setReactionRows(applyOptimisticPostReaction(previousRows, viewerProfileId, nextCode));
    setReactionError(null);
    setMutating(true);

    const supabase = createClient();
    let mutation: { error: unknown };
    try {
      mutation = nextCode
        ? await supabase.rpc("set_post_reaction", {
            target_post_id: post.id,
            target_profile_id: viewerProfileId,
            target_reaction_code: nextCode,
          })
        : await supabase.rpc("remove_post_reaction", {
            target_post_id: post.id,
            target_profile_id: viewerProfileId,
          });
    } catch {
      if (requestGeneration !== mutationGeneration.current) return;
      setReactionRows(previousRows);
      setReactionError("Could not update your reaction. Please try again.");
      setMutating(false);
      return;
    }

    if (requestGeneration !== mutationGeneration.current) return;
    if (mutation.error) {
      setReactionRows(previousRows);
      setReactionError("Could not update your reaction. Please try again.");
      setMutating(false);
      return;
    }

    let data: unknown = null;
    let error: unknown = null;
    try {
      const result = await supabase
        .from("post_reactions")
        .select("profile_id, reaction_code")
        .eq("post_id", post.id);
      data = result.data;
      error = result.error;
    } catch {
      error = true;
    }
    if (requestGeneration !== mutationGeneration.current) return;
    if (error) {
      setReactionError("Your reaction was saved, but the counts could not be refreshed.");
    } else {
      setReactionRows(toPostReactionRows(data));
    }
    setMutating(false);
  };

  return (
    <div className="post-reaction-area">
      <div className="post-reactions" aria-label="Post reactions">
        {POST_REACTION_OPTIONS.map(({ code, visual, label }) => {
          const count = counts[code];
          const active = activeCode === code;
          return (
            <button
              key={code}
              type="button"
              className={`post-reaction-button${active ? " active" : ""}${count === 0 ? " zero" : ""}`}
              data-tooltip={label}
              aria-label={`${label}: ${count}${active ? ", your reaction" : ""}`}
              aria-pressed={active}
              disabled={mutating || viewerProfileId === undefined}
              onClick={() => void react(code)}
            >
              <svg
                aria-hidden="true"
                viewBox={POST_REACTION_ICON_VIEWBOX}
                width="20" height="20"
                fill="currentColor"
              >
                {visual.paths.map((path, index) => (
                  <path key={index} d={path.d} fillRule={path.fillRule} clipRule={path.fillRule} />
                ))}
              </svg>
              <small>{count}</small>
            </button>
          );
        })}
      </div>
      {reactionError && <p className="post-reaction-error" role="alert">{reactionError}</p>}
    </div>
  );
}

export function PostCard({ post, profile, isOwner, viewerProfileId, onLoginRequested, onUpdated, onDeleted, onHighlightChanged }: {
  post: Post;
  profile: PostAuthor;
  isOwner: boolean;
  viewerProfileId: string | null | undefined;
  onLoginRequested: () => void;
  onUpdated: (post: Post) => void;
  onDeleted: (id: string) => void;
  onHighlightChanged?: (post: Post) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [lightbox, setLightbox] = useState<{ index: number } | null>(null);
  const [highlightMutating, setHighlightMutating] = useState(false);
  const [highlightError, setHighlightError] = useState<string | null>(null);

  useEffect(() => {
    setHighlightMutating(false);
    setHighlightError(null);
  }, [post.id, post.isHighlighted]);

  const toggleHighlight = async () => {
    if (highlightMutating) return;
    const nextHighlighted = !post.isHighlighted;
    setHighlightMutating(true);
    setHighlightError(null);
    try {
      const { error } = await createClient().rpc("toggle_post_highlight", {
        target_post_id: post.id,
        should_highlight: nextHighlighted,
      });
      if (error) {
        setHighlightError(getPostHighlightErrorMessage(error));
        setHighlightMutating(false);
        return;
      }
      onHighlightChanged?.({
        ...post,
        isHighlighted: nextHighlighted,
        highlightedAt: nextHighlighted ? new Date().toISOString() : null,
      });
    } catch (error) {
      setHighlightError(getPostHighlightErrorMessage(error));
      setHighlightMutating(false);
    }
  };

  const deletePost = async () => {
    setDeleting(true);
    setDeleteError(null);
    const { error } = await createClient().rpc("delete_own_post", { target_post_id: post.id });
    if (error) {
      setDeleteError(getPostWriteErrorMessage(error, "delete"));
      setDeleting(false);
      return;
    }
    onDeleted(post.id);
  };

  if (editing) {
    return (
      <PostEditor
        profileId={profile.id}
        post={post}
        onCancel={() => setEditing(false)}
        onSaved={(updated) => {
          if (updated) onUpdated(updated);
          setEditing(false);
        }}
      />
    );
  }

  return (
    <article className="post-card">
      <header>
        <Link href={`/${profile.handle}`} className="post-author-link">
          <ProfileAvatar name={profile.displayName || profile.handle} url={profile.avatarUrl} size={42} />
          <div className="post-author-copy">
            <strong>{profile.displayName}</strong>
            <span>@{profile.handle} · {formatPostDate(post.createdAt)}</span>
          </div>
        </Link>
        {isOwner && (
          <div className="post-author-actions">
            <label className="post-highlight-toggle">
              <input
                type="checkbox"
                checked={post.isHighlighted}
                onChange={() => void toggleHighlight()}
                disabled={highlightMutating}
              />
              {highlightMutating ? "Updating…" : "Highlight"}
            </label>
            <button type="button" onClick={() => setEditing(true)}>Edit</button>
            {!confirmDelete ? (
              <button type="button" onClick={() => setConfirmDelete(true)}>Delete</button>
            ) : (
              <div className="post-delete-confirm">
                <span>Delete permanently?</span>
                <button type="button" onClick={deletePost} disabled={deleting}>{deleting ? "Deleting…" : "Yes, delete"}</button>
                <button type="button" onClick={() => setConfirmDelete(false)} disabled={deleting}>Keep</button>
              </div>
            )}
          </div>
        )}
      </header>
      <PostBody post={post} />
      <PostImages images={post.images} onOpen={(index) => setLightbox({ index })} />
      <PostReactionBar post={post} viewerProfileId={viewerProfileId} onLoginRequested={onLoginRequested} />
      {!post.showInStream && isOwner && <span className="post-stream-note">Members only</span>}
      {highlightError && <p className="post-form-error" role="alert">{highlightError}</p>}
      {deleteError && <p className="post-form-error" role="alert">{deleteError}</p>}
      {lightbox && (
        <ImageLightbox
          images={post.images}
          initialIndex={lightbox.index}
          alt={`Post by ${profile.displayName || profile.handle}`}
          onClose={() => setLightbox(null)}
        />
      )}
    </article>
  );
}

function HighlightedPostsRow({ posts, onOpen }: { posts: Post[]; onOpen: (post: Post) => void }) {
  if (posts.length === 0) return null;
  return (
    <section className="post-highlights" aria-label="Highlighted posts">
      <div className="post-highlights-row">
        <h2>Highlights</h2>
        {posts.map((post) => {
          const preview = getPostHighlightPreview(post.body);
          return (
            <button
              key={post.id}
              type="button"
              className="post-highlight-circle"
              data-highlight-preview={preview}
              aria-label={`Open highlighted post: ${preview}`}
              onClick={() => onOpen(post)}
            >
              <span className="post-highlight-circle-frame">
                {post.images[0] ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={post.images[0]} alt="" />
                ) : (
                  <span className="post-highlight-text" aria-hidden="true">{preview}</span>
                )}
              </span>
            </button>
          );
        })}
      </div>
    </section>
  );
}

function HighlightedPostOverlay({
  post,
  profile,
  isOwner,
  viewerProfileId,
  onClose,
  onLoginRequested,
  onUpdated,
  onDeleted,
  onHighlightChanged,
}: {
  post: Post;
  profile: PostAuthor;
  isOwner: boolean;
  viewerProfileId: string | null | undefined;
  onClose: () => void;
  onLoginRequested: () => void;
  onUpdated: (post: Post) => void;
  onDeleted: (id: string) => void;
  onHighlightChanged: (post: Post) => void;
}) {
  const [portalTarget, setPortalTarget] = useState<HTMLElement | null>(null);

  useEffect(() => {
    setPortalTarget(document.body);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [onClose]);

  if (!portalTarget) return null;
  return createPortal(
    <div className="post-highlight-overlay" role="dialog" aria-modal="true" aria-label="Highlighted post" onClick={onClose}>
      <div className="post-highlight-overlay-panel" onClick={(event) => event.stopPropagation()}>
        <button type="button" className="post-highlight-overlay-close" aria-label="Close highlighted post" onClick={onClose}>✕</button>
        <div className="post-highlight-overlay-content">
          <PostCard
            post={post}
            profile={profile}
            isOwner={isOwner}
            viewerProfileId={viewerProfileId}
            onLoginRequested={onLoginRequested}
            onUpdated={onUpdated}
            onDeleted={onDeleted}
            onHighlightChanged={onHighlightChanged}
          />
        </div>
      </div>
    </div>,
    portalTarget,
  );
}

export default function ProfileWall({ profile, isOwner }: { profile: Profile; isOwner: boolean }) {
  const viewerProfileId = useReactionViewerProfileId();
  const [posts, setPosts] = useState<Post[]>([]);
  const [highlightedPosts, setHighlightedPosts] = useState<Post[]>([]);
  const [highlightLoadError, setHighlightLoadError] = useState<string | null>(null);
  const [openHighlight, setOpenHighlight] = useState<Post | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);
  const [reactionLoginOpen, setReactionLoginOpen] = useState(false);
  const requestGeneration = useRef(0);
  const paginationInFlight = useRef<number | null>(null);
  const loadPostsRef = useRef<(
    reset: boolean,
    options?: { silent?: boolean }
  ) => Promise<void>>(async () => undefined);

  const loadHighlights = useCallback(async (requestId: number) => {
    setHighlightLoadError(null);
    try {
      const { data, error } = await createClient()
        .from("posts")
        .select("id, profile_id, body, images, show_in_stream, created_at, updated_at, is_highlighted, highlighted_at, post_reactions(profile_id, reaction_code)")
        .eq("profile_id", profile.id)
        .eq("is_highlighted", true)
        .order("highlighted_at", { ascending: false })
        .order("id", { ascending: false })
        .limit(5);
      if (requestId !== requestGeneration.current) return;
      if (error) {
        setHighlightLoadError("Could not load highlighted posts. Please try again.");
        return;
      }
      setHighlightedPosts((data ?? []).map((row) => toPost(row as Record<string, unknown>)));
    } catch {
      if (requestId === requestGeneration.current) {
        setHighlightLoadError("Could not load highlighted posts. Please try again.");
      }
    }
  }, [profile.id]);

  const loadPosts = useCallback(async (
    reset: boolean,
    options?: { silent?: boolean }
  ) => {
    if (!reset && paginationInFlight.current !== null) return;
    const requestId = reset ? requestGeneration.current + 1 : requestGeneration.current;
    if (reset) {
      requestGeneration.current += 1;
      paginationInFlight.current = null;
      if (!options?.silent) setLoading(true);
      setLoadingMore(false);
    } else {
      paginationInFlight.current = requestId;
      setLoadingMore(true);
    }
    setLoadError(null);

    let query = createClient()
      .from("posts")
      .select("id, profile_id, body, images, show_in_stream, created_at, updated_at, is_highlighted, highlighted_at, post_reactions(profile_id, reaction_code)")
      .eq("profile_id", profile.id)
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(POST_PAGE_SIZE + 1);

    const cursor = reset ? null : posts[posts.length - 1];
    if (cursor) {
      query = query.or(`created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id.lt.${cursor.id})`);
    }

    try {
      const highlightsRequest = reset ? loadHighlights(requestId) : Promise.resolve();
      const { data, error } = await query;
      await highlightsRequest;
      if (requestId !== requestGeneration.current) return;
      if (error) {
        setLoadError("Could not load this Wall. Please try again.");
      } else {
        const next = (data ?? []).slice(0, POST_PAGE_SIZE).map((row) => toPost(row as Record<string, unknown>));
        setHasMore((data ?? []).length > POST_PAGE_SIZE);
        setPosts((current) => reset ? next : [...current, ...next]);
      }
    } catch {
      if (requestId === requestGeneration.current) {
        setLoadError("Could not load this Wall. Please try again.");
      }
    } finally {
      if (paginationInFlight.current === requestId) paginationInFlight.current = null;
      if (requestId === requestGeneration.current) {
        setLoading(false);
        setLoadingMore(false);
      }
    }
  }, [loadHighlights, posts, profile.id]);

  useEffect(() => {
    loadPostsRef.current = (reset, options) => loadPosts(reset, options);
  }, [loadPosts]);

  useEffect(() => {
    const supabase = createClient();
    const authUiParticipant = registerAuthUiRefreshParticipant();
    let cancelled = false;

    const refreshCoordinator = createWallAuthRefreshCoordinator({
      clearSensitiveRows: () => {
        setPosts([]);
        setHighlightedPosts([]);
        setOpenHighlight(null);
        setHasMore(false);
      },
      refresh: ({ silent }) => loadPostsRef.current(true, { silent }),
    });

    const syncAuthState = (nextUserId: string | null) => {
      if (cancelled) return;
      setIsAuthenticated(nextUserId !== null);
      authUiParticipant.track(nextUserId, refreshCoordinator.observe(nextUserId));
    };

    const authGate = createInitialAuthSnapshotGate<string | null>(syncAuthState);

    void supabase.auth.getSession().then(({ data }) => {
      authGate.applyInitial(data.session?.user.id ?? null);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      authGate.applyEvent(session?.user.id ?? null);
    });

    return () => {
      cancelled = true;
      requestGeneration.current += 1;
      paginationInFlight.current = null;
      authUiParticipant.unregister();
      subscription.unsubscribe();
    };
  }, [profile.id]);

  const updatePost = (updated: Post) => {
    setPosts((current) => current.map((item) => item.id === updated.id ? updated : item));
    setHighlightedPosts((current) => {
      const withoutUpdated = current.filter((item) => item.id !== updated.id);
      if (!updated.isHighlighted) return withoutUpdated;
      return [updated, ...withoutUpdated]
        .sort((left, right) => (right.highlightedAt ?? "").localeCompare(left.highlightedAt ?? ""))
        .slice(0, 5);
    });
    setOpenHighlight((current) => current?.id === updated.id ? updated : current);
  };

  const removePost = (id: string) => {
    setPosts((current) => current.filter((item) => item.id !== id));
    setHighlightedPosts((current) => current.filter((item) => item.id !== id));
    setOpenHighlight((current) => current?.id === id ? null : current);
  };

  return (
    <div className="profile-wall">
      <HighlightedPostsRow posts={highlightedPosts} onOpen={setOpenHighlight} />
      {highlightLoadError && <p className="post-form-error post-highlight-load-error" role="alert">{highlightLoadError}</p>}
      {isOwner && <PostEditor profileId={profile.id} onSaved={() => void loadPosts(true)} />}

      {loading ? (
        <PostListSkeleton label="Loading Wall" />
      ) : loadError && posts.length === 0 ? (
        <div className="post-empty"><p>{loadError}</p><button type="button" onClick={() => void loadPosts(true)}>Try again</button></div>
      ) : posts.length === 0 ? (
        <div className="post-empty">
          <h2>{!isOwner && isAuthenticated === false ? "No public posts yet" : "No posts yet"}</h2>
          <p>{isOwner ? "Share the first post on your Wall." : "Check back soon."}</p>
        </div>
      ) : (
        <div className="post-list">
          {posts.map((post) => (
            <PostCard
              key={post.id}
              post={post}
              profile={profile}
              isOwner={isOwner}
              viewerProfileId={viewerProfileId}
              onLoginRequested={() => setReactionLoginOpen(true)}
              onUpdated={updatePost}
              onDeleted={removePost}
              onHighlightChanged={updatePost}
            />
          ))}
          {loadError && <p className="post-form-error" role="alert">{loadError}</p>}
          {hasMore && <button type="button" className="post-load-more" onClick={() => void loadPosts(false)} disabled={loadingMore}>Load more</button>}
        </div>
      )}

      {reactionLoginOpen && <AuthModal initial="login" onClose={() => setReactionLoginOpen(false)} />}
      {openHighlight && (
        <HighlightedPostOverlay
          post={openHighlight}
          profile={profile}
          isOwner={isOwner}
          viewerProfileId={viewerProfileId}
          onClose={() => setOpenHighlight(null)}
          onLoginRequested={() => setReactionLoginOpen(true)}
          onUpdated={updatePost}
          onDeleted={removePost}
          onHighlightChanged={updatePost}
        />
      )}

      <style>{`
        .profile-wall { max-width: 680px; margin: 0 auto; padding: 32px 0 80px; }
        .post-highlights { width: 100%; margin: 0 0 24px; }
        .post-highlights-row { width: 100%; box-sizing: border-box; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; padding: 14px 16px; background: var(--white); border: 1px solid var(--sand); border-radius: 12px; }
        .post-highlights-row h2 { grid-column: 1 / -1; margin: 0 0 2px; color: var(--text); font: 700 14px 'Bricolage Grotesque', var(--font-bricolage); letter-spacing: -.01em; }
        .post-highlight-circle { position: relative; min-width: 0; padding: 0; border: 0; background: transparent; cursor: pointer; }
        .post-highlight-circle-frame { display: flex; width: clamp(52px, 9vw, 82px); max-width: 100%; aspect-ratio: 1; margin: 0 auto; align-items: center; justify-content: center; overflow: hidden; border: 3px solid var(--white); border-radius: 50%; outline: 2px solid var(--rust); background: linear-gradient(145deg, var(--rust), #7c4250); box-shadow: 0 3px 12px oklch(0% 0 0 / .12); }
        .post-highlight-circle img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .post-highlight-text { display: -webkit-box; padding: 8px; overflow: hidden; color: white; font: 700 9px/1.2 Manrope, var(--font-manrope); text-align: center; overflow-wrap: anywhere; -webkit-box-orient: vertical; -webkit-line-clamp: 4; }
        .post-highlight-circle:focus-visible { outline: 2px solid var(--rust); outline-offset: 5px; border-radius: 50%; }
        .post-highlight-load-error { margin: -12px 0 20px; }
        .post-highlight-toggle { display: inline-flex; align-items: center; gap: 5px; color: var(--text-mid); font-size: 11px; font-weight: 650; cursor: pointer; }
        .post-highlight-toggle input { accent-color: var(--rust); }
        .post-highlight-overlay { position: fixed; inset: 0; z-index: 1800; display: flex; align-items: center; justify-content: center; overflow: hidden; padding: 20px; box-sizing: border-box; background: oklch(0% 0 0 / .72); }
        .post-highlight-overlay-panel { position: relative; width: min(680px, 100%); max-height: calc(100dvh - 40px); border-radius: 12px; }
        .post-highlight-overlay-content { max-height: inherit; overflow-y: auto; border-radius: inherit; }
        .post-highlight-overlay-close { position: absolute; z-index: 2; top: 12px; right: 12px; width: 44px; height: 44px; border: 1px solid var(--sand); border-radius: 50%; background: var(--white); color: var(--text); font-size: 16px; cursor: pointer; box-shadow: 0 2px 10px oklch(0% 0 0 / .14); }
        .post-editor, .post-card { background: var(--white); border: 1px solid var(--sand); border-radius: 12px; padding: 20px; }
        .post-editor { margin-bottom: 24px; }
        .post-editor-inline { margin-bottom: 0; }
        .post-editor h2 { margin: 0 0 14px; font: 700 20px 'Bricolage Grotesque', var(--font-bricolage); color: var(--text); }
        .post-editor textarea { width: 100%; box-sizing: border-box; resize: vertical; border: 1px solid var(--sand); border-radius: 9px; padding: 13px 14px; background: var(--cream); color: var(--text); font: 14px/1.55 Manrope, var(--font-manrope); }
        .post-editor textarea:focus { outline: 2px solid oklch(64% 0.13 42 / 0.22); border-color: var(--rust); }
        .post-editor-count { margin-top: 5px; color: var(--text-light); font-size: 11px; text-align: right; }
        .post-editor-previews { display: grid; grid-template-columns: repeat(5, 1fr); gap: 8px; margin-top: 14px; }
        .post-editor-preview { position: relative; aspect-ratio: 1; border-radius: 8px; overflow: hidden; border: 1px solid var(--sand); }
        .post-editor-preview img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .post-editor-preview button { position: absolute; top: 5px; right: 5px; width: 24px; height: 24px; border: 0; border-radius: 50%; background: oklch(0% 0 0 / .65); color: white; cursor: pointer; font-size: 16px; }
        .post-editor-options, .post-editor-options > div, .post-editor-actions { display: flex; align-items: center; gap: 10px; }
        .post-editor-options { justify-content: space-between; flex-wrap: wrap; margin-top: 14px; }
        .post-editor-options span, .post-editor-options label { color: var(--text-mid); font-size: 12px; }
        .post-editor-options label { display: flex; align-items: center; gap: 7px; cursor: pointer; }
        .post-editor-options > .post-visibility-option { max-width: 390px; flex-direction: column; align-items: flex-start; gap: 3px; }
        .post-visibility-option p { margin: 0; color: var(--text-light); font-size: 11px; line-height: 1.45; }
        .post-visibility-option strong { color: var(--text-mid); }
        .post-editor-options input[type='checkbox'] { accent-color: var(--rust); }
        .post-image-button, .post-secondary-button, .post-author-actions button, .post-load-more, .post-empty button { border: 1px solid var(--sand); background: var(--white); color: var(--text-mid); border-radius: 7px; padding: 8px 12px; font: 600 12px Manrope, var(--font-manrope); cursor: pointer; }
        .post-editor-actions { justify-content: flex-end; margin-top: 14px; }
        .post-primary-button { border: 0; background: var(--rust); color: white; border-radius: 8px; padding: 10px 18px; font: 700 13px Manrope, var(--font-manrope); cursor: pointer; }
        button:disabled { opacity: .55; cursor: not-allowed; }
        .post-form-error { margin: 12px 0 0; color: #a52e24; font-size: 12px; line-height: 1.5; }
        .post-list { display: flex; flex-direction: column; gap: 16px; }
        .post-card header { display: flex; align-items: center; gap: 11px; margin-bottom: 16px; }
        .post-author-link { display: flex; align-items: center; gap: 11px; min-width: 0; color: inherit; text-decoration: none; }
        .post-author-copy { display: flex; flex-direction: column; min-width: 0; }
        .post-card header strong { color: var(--text); font-size: 13px; }
        .post-card header span { color: var(--text-light); font-size: 11px; }
        .post-author-actions { margin-left: auto; display: flex; align-items: center; gap: 6px; flex-wrap: wrap; justify-content: flex-end; }
        .post-delete-confirm { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
        .post-delete-confirm > span { color: #a52e24; }
        .post-delete-confirm button:first-of-type { color: white; background: #a52e24; border-color: #a52e24; }
        .post-images { display: grid; gap: 5px; margin-top: 16px; overflow: hidden; border-radius: 10px; }
        .post-images-1 { grid-template-columns: 1fr; }
        .post-images-2, .post-images-3, .post-images-4 { grid-template-columns: repeat(2, 1fr); }
        .post-images-5 { grid-template-columns: repeat(3, 1fr); }
        .post-images button { width: 100%; height: 280px; padding: 0; border: 0; background: var(--sand); cursor: zoom-in; overflow: hidden; }
        .post-images img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .post-images-1 button { height: auto; max-height: 620px; }
        .post-images-1 img { height: auto; max-height: 620px; }
        .post-images-3 button:first-child, .post-images-5 button:first-child { grid-row: span 2; height: 565px; }
        .post-stream-note { display: inline-block; margin-top: 12px; border-radius: 999px; background: var(--cream); color: var(--text-light); padding: 4px 9px; font-size: 10px; }
        .post-load-more { align-self: center; margin-top: 8px; padding: 10px 24px; }
        .post-empty { text-align: center; padding: 72px 20px; color: var(--text-light); }
        .post-empty h2 { margin: 0 0 7px; color: var(--text); font: 700 20px 'Bricolage Grotesque', var(--font-bricolage); }
        .post-empty p { margin: 0 0 16px; font-size: 13px; }
        .post-skeleton { height: 210px; border-radius: 12px; }
        @media (hover: hover) and (pointer: fine) {
          .post-highlight-circle::after { content: attr(data-highlight-preview); position: absolute; z-index: 3; left: 50%; bottom: calc(100% + 10px); width: min(240px, 36vw); padding: 8px 10px; border-radius: 7px; background: var(--text); color: var(--white); font-size: 11px; line-height: 1.4; text-align: left; opacity: 0; pointer-events: none; transform: translate(-50%, 4px); transition: opacity .14s ease, transform .14s ease; }
          .post-highlight-circle:hover::after, .post-highlight-circle:focus-visible::after { opacity: 1; transform: translate(-50%, 0); }
        }
        @media (max-width: 640px) {
          .profile-wall { padding-top: 20px; }
          .post-highlights-row { gap: 8px; padding: 12px 10px; border-radius: 10px; }
          .post-highlight-circle-frame { width: clamp(48px, 15vw, 68px); }
          .post-highlight-text { padding: 6px; font-size: 8px; }
          .post-highlight-overlay { padding: 10px; }
          .post-highlight-overlay-panel { max-height: calc(100dvh - 20px); }
          .post-highlight-overlay-close { top: 8px; right: 8px; }
          .post-editor, .post-card { padding: 15px; border-radius: 10px; }
          .post-editor-previews { grid-template-columns: repeat(3, 1fr); }
          .post-images button { height: 190px; }
          .post-images-1 button { height: auto; }
          .post-images-1 img { height: auto; }
          .post-images-5 { grid-template-columns: repeat(2, 1fr); }
          .post-images-3 button:first-child, .post-images-5 button:first-child { height: 385px; }
          .post-card header { align-items: flex-start; }
          .post-author-actions { max-width: 52%; }
        }
      `}</style>
    </div>
  );
}
