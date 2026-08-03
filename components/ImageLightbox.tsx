"use client";

import { useEffect, useRef, useState, type CSSProperties, type TouchEvent } from "react";

type ImageLightboxProps = {
  images: string[];
  initialIndex: number;
  alt: string;
  onClose: () => void;
  onIndexChange?: (index: number) => void;
  fallbackSrc?: string;
};

function clampIndex(index: number, length: number) {
  return Math.min(Math.max(index, 0), Math.max(length - 1, 0));
}

export default function ImageLightbox({
  images,
  initialIndex,
  alt,
  onClose,
  onIndexChange,
  fallbackSrc = "/listing-placeholder.webp",
}: ImageLightboxProps) {
  const galleryImages = images.length > 0 ? images : [fallbackSrc];
  const [index, setIndex] = useState(() => clampIndex(initialIndex, galleryImages.length));
  const touchStart = useRef<{ x: number; y: number } | null>(null);
  const thumbnailGap = 6;
  const mobileThumbnailWidth = `calc(${100 / galleryImages.length}% - ${((galleryImages.length - 1) * thumbnailGap) / galleryImages.length}px)`;
  const thumbnailStripStyle = {
    display: "flex",
    gap: "8px",
    marginTop: "20px",
    overflowX: "auto",
    maxWidth: "90vw",
    padding: "4px",
    "--image-lightbox-mobile-thumbnail-width": mobileThumbnailWidth,
  } as CSSProperties;

  const selectIndex = (next: number) => {
    const clamped = clampIndex(next, galleryImages.length);
    setIndex(clamped);
    onIndexChange?.(clamped);
  };

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "ArrowLeft") selectIndex(index - 1);
      if (e.key === "ArrowRight") selectIndex(index + 1);
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [index, galleryImages.length, onClose]);

  const handleTouchStart = (event: TouchEvent) => {
    touchStart.current = {
      x: event.touches[0].clientX,
      y: event.touches[0].clientY,
    };
  };

  const handleTouchEnd = (event: TouchEvent) => {
    if (!touchStart.current) return;
    const dx = touchStart.current.x - event.changedTouches[0].clientX;
    const dy = touchStart.current.y - event.changedTouches[0].clientY;
    touchStart.current = null;
    if (Math.abs(dx) <= Math.abs(dy) || Math.abs(dx) < 40) return;
    selectIndex(index + (dx > 0 ? 1 : -1));
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label="Image gallery"
      onClick={onClose}
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
      style={{ position: "fixed", inset: 0, background: "oklch(0% 0 0 / 0.92)", zIndex: 2000, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}
    >
      <button
        type="button"
        aria-label="Close image gallery"
        onClick={(event) => { event.stopPropagation(); onClose(); }}
        style={{ position: "absolute", top: "20px", right: "20px", background: "oklch(100% 0 0 / 0.12)", border: "1px solid oklch(100% 0 0 / 0.2)", borderRadius: "50%", width: "44px", height: "44px", fontSize: "20px", color: "white", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1 }}
      >
        ✕
      </button>

      {index > 0 && (
        <button
          className="image-lightbox-arrow"
          type="button"
          aria-label="Previous image"
          onClick={(event) => { event.stopPropagation(); selectIndex(index - 1); }}
          style={{ position: "absolute", left: "20px", top: "50%", transform: "translateY(-50%)", background: "oklch(100% 0 0 / 0.12)", border: "1px solid oklch(100% 0 0 / 0.2)", borderRadius: "50%", width: "52px", height: "52px", fontSize: "28px", color: "white", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}
        >
          ‹
        </button>
      )}

      <div onClick={(event) => event.stopPropagation()} style={{ maxWidth: "90vw", maxHeight: "80vh", display: "flex", alignItems: "center", justifyContent: "center" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={galleryImages[index] || fallbackSrc}
          onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = fallbackSrc; }}
          alt={`${alt} — image ${index + 1} of ${galleryImages.length}`}
          draggable={false}
          style={{ maxWidth: "90vw", maxHeight: "80vh", objectFit: "contain", borderRadius: "8px", display: "block", userSelect: "none" }}
        />
      </div>

      {index < galleryImages.length - 1 && (
        <button
          className="image-lightbox-arrow"
          type="button"
          aria-label="Next image"
          onClick={(event) => { event.stopPropagation(); selectIndex(index + 1); }}
          style={{ position: "absolute", right: "20px", top: "50%", transform: "translateY(-50%)", background: "oklch(100% 0 0 / 0.12)", border: "1px solid oklch(100% 0 0 / 0.2)", borderRadius: "50%", width: "52px", height: "52px", fontSize: "28px", color: "white", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}
        >
          ›
        </button>
      )}

      {galleryImages.length > 1 && (
        <div className="image-lightbox-thumbnails" onClick={(event) => event.stopPropagation()} style={thumbnailStripStyle}>
          {galleryImages.map((src, imageIndex) => (
            <button
              className="image-lightbox-thumbnail"
              key={`${src}-${imageIndex}`}
              type="button"
              aria-label={`View image ${imageIndex + 1}`}
              onClick={() => selectIndex(imageIndex)}
              style={{ width: "68px", height: "68px", padding: "2px", background: "transparent", border: imageIndex === index ? "2px solid var(--rust)" : "2px solid oklch(100% 0 0 / 0.2)", borderRadius: "8px", cursor: "pointer", flexShrink: 0 }}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={src} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", borderRadius: "4px", display: "block" }} />
            </button>
          ))}
        </div>
      )}

      <style>{`
        @media (max-width: 640px) {
          .image-lightbox-arrow { display: none !important; }
          .image-lightbox-thumbnails { width: calc(100vw - 24px); max-width: calc(100vw - 24px) !important; gap: 6px !important; overflow-x: visible !important; box-sizing: border-box; justify-content: center; }
          .image-lightbox-thumbnail { width: clamp(44px, var(--image-lightbox-mobile-thumbnail-width), 68px) !important; height: auto !important; aspect-ratio: 1; }
        }
      `}</style>
    </div>
  );
}
