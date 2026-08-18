"use client";

import { useEffect, useId, useLayoutEffect, useRef, useState, type CSSProperties } from "react";

type FilterOption = {
  value: string;
  label: string;
};

type CategoryFilterToolbarProps = {
  allLabel: string;
  tags: FilterOption[];
  activeTags: string[];
  onClearTags: () => void;
  onToggleTag: (tag: string) => void;
  sort: string;
  sortOptions: readonly string[];
  onSortChange: (sort: string) => void;
  priceRange: string;
  priceOptions: readonly string[];
  onPriceChange: (priceRange: string) => void;
  style?: CSSProperties;
};

type OpenPopover = "sort" | "price";

function FilterChevron({ open }: { open: boolean }) {
  return (
    <svg aria-hidden="true" width="10" height="6" viewBox="0 0 10 6" style={{ transform: open ? "rotate(180deg)" : "none", transition: "transform 160ms ease" }}>
      <path d="M1 1l4 4 4-4" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" />
    </svg>
  );
}

export default function CategoryFilterToolbar({
  allLabel,
  tags,
  activeTags,
  onClearTags,
  onToggleTag,
  sort,
  sortOptions,
  onSortChange,
  priceRange,
  priceOptions,
  onPriceChange,
  style,
}: CategoryFilterToolbarProps) {
  const toolbarRef = useRef<HTMLDivElement>(null);
  const stickyRef = useRef<HTMLDivElement>(null);
  const railRef = useRef<HTMLDivElement>(null);
  const id = useId().replace(/:/g, "");
  const [openPopover, setOpenPopover] = useState<OpenPopover | null>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);
  const [isStuck, setIsStuck] = useState(false);

  useLayoutEffect(() => {
    const rail = railRef.current;
    if (!rail) return;

    const updateOverflow = () => {
      const maxScrollLeft = rail.scrollWidth - rail.clientWidth;
      setCanScrollLeft(rail.scrollLeft > 1);
      setCanScrollRight(maxScrollLeft - rail.scrollLeft > 1);

      const railRect = rail.getBoundingClientRect();
      for (const child of Array.from(rail.children) as HTMLElement[]) {
        const childRect = child.getBoundingClientRect();
        const fullyVisible = childRect.left >= railRect.left - 1 && childRect.right <= railRect.right + 1;
        child.dataset.railVisible = String(fullyVisible);
      }
    };

    updateOverflow();
    rail.addEventListener("scroll", updateOverflow, { passive: true });
    const resizeObserver = new ResizeObserver(updateOverflow);
    resizeObserver.observe(rail);
    for (let index = 0; index < rail.children.length; index += 1) {
      resizeObserver.observe(rail.children.item(index)!);
    }

    return () => {
      rail.removeEventListener("scroll", updateOverflow);
      resizeObserver.disconnect();
    };
  }, [tags]);

  useEffect(() => {
    const updateStuck = () => {
      const sticky = stickyRef.current;
      if (!sticky) return;
      const stickyTop = Number.parseFloat(window.getComputedStyle(sticky).top) || 0;
      setIsStuck(sticky.getBoundingClientRect().top <= stickyTop + 0.5);
    };

    updateStuck();
    window.addEventListener("scroll", updateStuck, { passive: true });
    window.addEventListener("resize", updateStuck);
    return () => {
      window.removeEventListener("scroll", updateStuck);
      window.removeEventListener("resize", updateStuck);
    };
  }, []);

  useEffect(() => {
    if (!openPopover) return;
    const closeOnOutsideClick = (event: PointerEvent) => {
      if (!toolbarRef.current?.contains(event.target as Node)) setOpenPopover(null);
    };
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpenPopover(null);
    };
    document.addEventListener("pointerdown", closeOnOutsideClick);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("pointerdown", closeOnOutsideClick);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [openPopover]);

  const scrollRail = (direction: -1 | 1) => {
    const rail = railRef.current;
    if (!rail) return;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    rail.scrollBy({ left: direction * rail.clientWidth, behavior: reducedMotion ? "auto" : "smooth" });
  };

  const chooseSort = (value: string) => {
    onSortChange(value);
    setOpenPopover(null);
  };

  const choosePrice = (value: string) => {
    onPriceChange(value);
    setOpenPopover(null);
  };

  return (
    <div ref={stickyRef} className={`category-filter-sticky stagger-item${isStuck ? " is-stuck" : ""}`} style={style} aria-label="Listing filters">
      <div ref={toolbarRef} className="category-filter-toolbar site-shell">
        <div className="category-filter-toolbar-main">
          <div className="category-type-segment">
            {canScrollLeft && <button type="button" className="category-rail-arrow category-rail-arrow-left" aria-label="Scroll types left" onClick={() => scrollRail(-1)}><span aria-hidden="true">‹</span></button>}
            <div ref={railRef} className="category-type-rail">
              <button type="button" className={`category-type-pill${activeTags.length === 0 ? " is-active" : ""}`} aria-pressed={activeTags.length === 0} onClick={onClearTags}>{allLabel}</button>
              {tags.map(({ value, label }) => {
                const active = activeTags.includes(value);
                return <button key={value} type="button" className={`category-type-pill${active ? " is-active" : ""}`} aria-pressed={active} onClick={() => onToggleTag(value)}>{label}</button>;
              })}
            </div>
            <span className="category-rail-fade category-rail-fade-left" data-visible={canScrollLeft} aria-hidden="true" />
            <span className="category-rail-fade category-rail-fade-right" data-visible={canScrollRight} aria-hidden="true" />
            {canScrollRight && <button type="button" className="category-rail-arrow category-rail-arrow-right" aria-label="Scroll types right" onClick={() => scrollRail(1)}><span aria-hidden="true">›</span></button>}
          </div>

          <div className="browse-filter-menu category-filter-menu">
            <button type="button" className={`browse-filter-trigger category-filter-trigger${sort !== sortOptions[0] ? " is-active" : ""}`} aria-haspopup="true" aria-expanded={openPopover === "sort"} aria-controls={`${id}-sort-popover`} onClick={() => setOpenPopover((current) => current === "sort" ? null : "sort")}>
              <span className="browse-filter-key">SORT</span><span className="browse-filter-value">{sort}</span><FilterChevron open={openPopover === "sort"} />
            </button>
            {openPopover === "sort" && <div id={`${id}-sort-popover`} className="browse-filter-popover category-filter-popover" role="group" aria-label="Sort listings">
              {sortOptions.map((option) => <button key={option} type="button" aria-pressed={sort === option} onClick={() => chooseSort(option)}><span className="browse-option-check" aria-hidden="true">{sort === option ? "✓" : ""}</span><span className="browse-option-label">{option}</span></button>)}
            </div>}
          </div>

          <div className="browse-filter-menu category-filter-menu">
            <button type="button" className={`browse-filter-trigger category-filter-trigger${priceRange !== priceOptions[0] ? " is-active" : ""}`} aria-haspopup="true" aria-expanded={openPopover === "price"} aria-controls={`${id}-price-popover`} onClick={() => setOpenPopover((current) => current === "price" ? null : "price")}>
              <span className="browse-filter-key">PRICE</span><span className="browse-filter-value">{priceRange}</span><FilterChevron open={openPopover === "price"} />
            </button>
            {openPopover === "price" && <div id={`${id}-price-popover`} className="browse-filter-popover category-filter-popover" role="group" aria-label="Choose a price range">
              {priceOptions.map((option) => <button key={option} type="button" aria-pressed={priceRange === option} onClick={() => choosePrice(option)}><span className="browse-option-check" aria-hidden="true">{priceRange === option ? "✓" : ""}</span><span className="browse-option-label">{option}</span></button>)}
            </div>}
          </div>
        </div>
      </div>
    </div>
  );
}
