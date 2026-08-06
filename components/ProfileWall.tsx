"use client";

import { useCallback, useEffect, useRef, useState, type ChangeEvent } from "react";
import Link from "next/link";
import ProfileAvatar from "@/components/ProfileAvatar";
import ImageLightbox from "@/components/ImageLightbox";
import { createClient } from "@/lib/supabase/client";
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
        <label>
          <input type="checkbox" checked={showInStream} onChange={(event) => setShowInStream(event.target.checked)} disabled={saving} />
          Show in Stream
        </label>
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

export function PostCard({ post, profile, isOwner, onUpdated, onDeleted }: {
  post: Post;
  profile: PostAuthor;
  isOwner: boolean;
  onUpdated: (post: Post) => void;
  onDeleted: (id: string) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [lightbox, setLightbox] = useState<{ index: number } | null>(null);

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
      {!post.showInStream && isOwner && <span className="post-stream-note">Wall only</span>}
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

export default function ProfileWall({ profile, isOwner }: { profile: Profile; isOwner: boolean }) {
  const [posts, setPosts] = useState<Post[]>([]);
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
      .select("id, profile_id, body, images, show_in_stream, created_at, updated_at")
      .eq("profile_id", profile.id)
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(POST_PAGE_SIZE + 1);

    const cursor = reset ? null : posts[posts.length - 1];
    if (cursor) {
      query = query.or(`created_at.lt.${cursor.createdAt},and(created_at.eq.${cursor.createdAt},id.lt.${cursor.id})`);
    }

    try {
      const { data, error } = await query;
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
  }, [posts, profile.id]);

  useEffect(() => {
    void loadPosts(true);
    return () => {
      requestGeneration.current += 1;
      paginationInFlight.current = null;
    };
    // Reload only when the viewed profile changes; pagination updates posts separately.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile.id]);

  return (
    <div className="profile-wall">
      {isOwner && <PostEditor profileId={profile.id} onSaved={() => void loadPosts(true)} />}

      {loading ? (
        <div className="post-list" aria-label="Loading Wall">
          {Array.from({ length: 3 }).map((_, index) => <div key={index} className="skeleton-block post-skeleton" />)}
        </div>
      ) : loadError && posts.length === 0 ? (
        <div className="post-empty"><p>{loadError}</p><button type="button" onClick={() => void loadPosts(true)}>Try again</button></div>
      ) : posts.length === 0 ? (
        <div className="post-empty">
          <h2>No posts yet</h2>
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
              onUpdated={(updated) => setPosts((current) => current.map((item) => item.id === updated.id ? updated : item))}
              onDeleted={(id) => setPosts((current) => current.filter((item) => item.id !== id))}
            />
          ))}
          {loadError && <p className="post-form-error" role="alert">{loadError}</p>}
          {hasMore && <button type="button" className="post-load-more" onClick={() => void loadPosts(false)} disabled={loadingMore}>Load more</button>}
        </div>
      )}

      <style>{`
        .profile-wall { max-width: 680px; margin: 0 auto; padding: 32px 0 80px; }
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
        @media (max-width: 640px) {
          .profile-wall { padding-top: 20px; }
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
