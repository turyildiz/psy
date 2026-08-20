"use client";

import { useLayoutEffect, useRef, useState, type FocusEvent, type ReactNode } from "react";

type FeaturedCategoryRailProps = {
  className: string;
  itemCount: number;
  label: string;
  children: ReactNode;
};

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
      const railRect = rail.getBoundingClientRect();
      const cards = Array.from(rail.children) as HTMLElement[];
      const firstCardRect = cards[0]?.getBoundingClientRect();
      const lastCardRect = cards.at(-1)?.getBoundingClientRect();

      setCanScrollLeft(Boolean(firstCardRect && firstCardRect.left < railRect.left - 1));
      setCanScrollRight(Boolean(lastCardRect && lastCardRect.right > railRect.right + 1));
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
    const maxScrollLeft = rail.scrollWidth - rail.clientWidth;
    const targetLeft = Math.max(0, Math.min(maxScrollLeft, rail.scrollLeft + cardRect.left - railRect.left));
    rail.scrollTo({ left: targetLeft, behavior: reducedMotion ? "auto" : "smooth" });
  };

  const scrollRail = (direction: -1 | 1) => {
    const rail = railRef.current;
    if (!rail) return;

    const cards = Array.from(rail.children) as HTMLElement[];
    if (cards.length < 2) return;

    const cardStep = cards[1].offsetLeft - cards[0].offsetLeft;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    rail.scrollBy({ left: direction * cardStep, behavior: reducedMotion ? "auto" : "smooth" });
  };

  const handleFocus = (event: FocusEvent<HTMLDivElement>) => {
    const rail = railRef.current;
    const card = (event.target as HTMLElement).closest<HTMLElement>(".stagger-item");
    if (rail && card?.parentElement === rail) scrollCardIntoView(card);
  };

  return (
    <div className="featured-category-rail-segment" data-scrollable={isScrollable}>
      {isScrollable && canScrollLeft && (
        <button type="button" className="category-rail-arrow category-rail-arrow-left" aria-label="Scroll featured items left" onClick={() => scrollRail(-1)}>
          <span aria-hidden="true">‹</span>
        </button>
      )}
      <div ref={railRef} className={`${className} featured-category-rail`} tabIndex={0} aria-label={`${label} — swipe to browse`} onFocusCapture={handleFocus}>
        {children}
      </div>
      {isScrollable && <span className="category-rail-fade category-rail-fade-left" data-visible={canScrollLeft} aria-hidden="true" />}
      {isScrollable && <span className="category-rail-fade category-rail-fade-right" data-visible={canScrollRight} aria-hidden="true" />}
      {isScrollable && canScrollRight && (
        <button type="button" className="category-rail-arrow category-rail-arrow-right" aria-label="Scroll featured items right" onClick={() => scrollRail(1)}>
          <span aria-hidden="true">›</span>
        </button>
      )}
    </div>
  );
}
