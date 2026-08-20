"use client";

import { useLayoutEffect, useRef, useState, type FocusEvent, type ReactNode } from "react";

type FeaturedCategoryRailProps = {
  className: string;
  itemCount: number;
  label: string;
  children: ReactNode;
};

const OVERFLOW_TOLERANCE_PX = 4;

export default function FeaturedCategoryRail({ className, itemCount, label, children }: FeaturedCategoryRailProps) {
  const railRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);
  const isScrollable = itemCount > 3;

  useLayoutEffect(() => {
    const rail = railRef.current;
    if (!rail || !isScrollable) {
      setCanScrollLeft(false);
      setCanScrollRight(false);
      return;
    }

    const updateOverflow = () => {
      const firstCard = rail.firstElementChild as HTMLElement | null;
      if (firstCard) rail.parentElement?.style.setProperty("--featured-image-center", `${firstCard.getBoundingClientRect().width * 3 / 8}px`);
      setCanScrollLeft(rail.scrollLeft > OVERFLOW_TOLERANCE_PX);
      setCanScrollRight(rail.scrollWidth - rail.clientWidth - rail.scrollLeft > OVERFLOW_TOLERANCE_PX);
    };

    updateOverflow();
    rail.addEventListener("scroll", updateOverflow, { passive: true });
    const resizeObserver = new ResizeObserver(updateOverflow);
    resizeObserver.observe(rail);
    for (const card of Array.from(rail.children)) resizeObserver.observe(card);

    return () => {
      rail.removeEventListener("scroll", updateOverflow);
      resizeObserver.disconnect();
    };
  }, [isScrollable, itemCount]);

  const scrollCardIntoView = (card: HTMLElement) => {
    const rail = railRef.current;
    if (!rail || !isScrollable) return;

    const railRect = rail.getBoundingClientRect();
    const cardRect = card.getBoundingClientRect();
    if (cardRect.left >= railRect.left - 1 && cardRect.right <= railRect.right + 1) return;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    card.scrollIntoView({ behavior: reducedMotion ? "auto" : "smooth", inline: "start", block: "nearest" });
  };

  const scrollRail = (direction: -1 | 1) => {
    const rail = railRef.current;
    if (!rail) return;

    const cards = Array.from(rail.children) as HTMLElement[];
    if (cards.length < 2) return;

    const railRect = rail.getBoundingClientRect();
    const safeEdge = Number.parseFloat(window.getComputedStyle(rail).scrollPaddingInlineStart) || 0;
    const safeLeft = railRect.left + safeEdge;
    const currentIndex = cards.findLastIndex((card) => card.getBoundingClientRect().left <= safeLeft + 1);
    const targetIndex = Math.max(0, Math.min(cards.length - 1, currentIndex + direction));
    const targetCard = cards[targetIndex];
    if (!targetCard) return;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const behavior: ScrollBehavior = reducedMotion ? "auto" : "smooth";
    if (targetIndex === 0) rail.scrollTo({ left: 0, behavior });
    else targetCard.scrollIntoView({ behavior, inline: "start", block: "nearest" });
  };

  const handleFocus = (event: FocusEvent<HTMLDivElement>) => {
    const rail = railRef.current;
    const card = (event.target as HTMLElement).closest<HTMLElement>(".stagger-item");
    if (rail && card?.parentElement === rail) scrollCardIntoView(card);
  };

  return (
    <div className="featured-category-rail-segment" data-scrollable={isScrollable}>
      {isScrollable && canScrollLeft && (
        <button type="button" className="featured-category-rail-arrow featured-category-rail-arrow-left" aria-label="Scroll featured items left" onClick={() => scrollRail(-1)}>
          <svg aria-hidden="true" viewBox="0 0 24 24">
            <path d="m15 18-6-6 6-6" />
          </svg>
        </button>
      )}
      <div ref={railRef} className={`${className} featured-category-rail`} tabIndex={0} aria-label={`${label} — swipe to browse`} onFocusCapture={handleFocus}>
        {children}
      </div>
      {isScrollable && <span className="category-rail-fade category-rail-fade-left" data-visible={canScrollLeft} aria-hidden="true" />}
      {isScrollable && <span className="category-rail-fade category-rail-fade-right" data-visible={canScrollRight} aria-hidden="true" />}
      {isScrollable && canScrollRight && (
        <button type="button" className="featured-category-rail-arrow featured-category-rail-arrow-right" aria-label="Scroll featured items right" onClick={() => scrollRail(1)}>
          <svg aria-hidden="true" viewBox="0 0 24 24">
            <path d="m9 18 6-6-6-6" />
          </svg>
        </button>
      )}
    </div>
  );
}
