"use client";

import { useEffect, useState } from "react";

const BLOCKING_OVERLAY_SELECTOR = [
  '[aria-modal="true"]',
  ".drawer-backdrop",
  ".mobile-drawer.open",
  "[data-scroll-to-top-blocker]",
].join(", ");

function hasBlockingOverlay() {
  return document.body.style.overflow === "hidden" || Boolean(document.querySelector(BLOCKING_OVERLAY_SELECTOR));
}

export default function ScrollToTopButton() {
  const [pastThreshold, setPastThreshold] = useState(false);
  const [overlayOpen, setOverlayOpen] = useState(false);

  useEffect(() => {
    const updateVisibility = () => setPastThreshold(window.scrollY > window.innerHeight * 1.5);
    const updateOverlayState = () => setOverlayOpen(hasBlockingOverlay());

    updateVisibility();
    updateOverlayState();
    window.addEventListener("scroll", updateVisibility, { passive: true });
    window.addEventListener("resize", updateVisibility, { passive: true });

    const observer = new MutationObserver(updateOverlayState);
    observer.observe(document.body, {
      attributes: true,
      attributeFilter: ["class", "style", "aria-modal", "data-scroll-to-top-blocker"],
      childList: true,
      subtree: true,
    });

    return () => {
      window.removeEventListener("scroll", updateVisibility);
      window.removeEventListener("resize", updateVisibility);
      observer.disconnect();
    };
  }, []);

  const visible = pastThreshold && !overlayOpen;

  const handleClick = () => {
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    window.scrollTo({ top: 0, behavior: reducedMotion ? "auto" : "smooth" });

    const target = document.querySelector<HTMLElement>("h1, main, [data-page-top]");
    if (target) {
      target.tabIndex = -1;
      target.focus({ preventScroll: true });
    }
  };

  return (
    <>
      <button
        type="button"
        className="scroll-to-top-button"
        data-visible={visible}
        aria-label="Back to top"
        aria-hidden={!visible}
        tabIndex={visible ? 0 : -1}
        onClick={handleClick}
      >
        <svg aria-hidden="true" viewBox="0 0 24 24">
          <path d="m6 15 6-6 6 6" />
        </svg>
      </button>
      <style>{`
        .scroll-to-top-button {
          position: fixed;
          z-index: 90;
          right: 24px;
          bottom: 24px;
          width: 44px;
          height: 44px;
          display: grid;
          place-items: center;
          border: 1px solid var(--sand);
          border-radius: 50%;
          background: var(--white);
          box-shadow: 0 6px 18px oklch(25% 0.03 50 / .16);
          color: var(--text-mid);
          padding: 0;
          opacity: 0;
          visibility: hidden;
          pointer-events: none;
          transform: translateY(6px);
          transition: opacity 180ms ease, transform 180ms ease, visibility 0s linear 180ms, background 150ms ease, color 150ms ease;
          cursor: pointer;
        }
        .scroll-to-top-button[data-visible="true"] {
          opacity: 1;
          visibility: visible;
          pointer-events: auto;
          transform: translateY(0);
          transition-delay: 0s;
        }
        .scroll-to-top-button svg {
          width: 24px;
          height: 24px;
          fill: none;
          stroke: currentColor;
          stroke-width: 2;
          stroke-linecap: round;
          stroke-linejoin: round;
        }
        .scroll-to-top-button:hover { background: var(--cream); color: var(--rust); }
        .scroll-to-top-button:focus-visible {
          outline: 3px solid var(--rust);
          outline-offset: 2px;
        }
        @media (max-width: 640px) {
          .scroll-to-top-button { right: 18px; bottom: 20px; }
        }
        @media (prefers-reduced-motion: reduce) {
          .scroll-to-top-button { transform: none; transition: none; }
        }
      `}</style>
    </>
  );
}
