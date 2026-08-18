"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useEffect, useMemo, useRef, useState, type CSSProperties } from "react";

import Footer from "@/components/layout/Footer";
import Header from "@/components/layout/Header";
import ProfileAvatar from "@/components/ProfileAvatar";
import {
  BROWSE_CATEGORIES,
  BROWSE_PAGE_SIZE,
  buildBrowseHref,
  createBrowseQueryPlan,
  formatCategoryLabel,
  parseBrowseParams,
  type BrowseCursor,
  type BrowsePrice,
  type BrowseSort,
  type BrowseState,
} from "@/lib/browse-state";
import { conditionLabels } from "@/lib/constants";
import { toListing } from "@/lib/db";
import { formatPrice } from "@/lib/listings/price";
import { createClient } from "@/lib/supabase/client";
import type { Listing } from "@/types/marketplace";

const PRICE_OPTIONS: Array<{ value: BrowsePrice; label: string }> = [
  { value: "any", label: "Any price" },
  { value: "under-50", label: "Under €50" },
  { value: "50-100", label: "€50–€100" },
  { value: "100-200", label: "€100–€200" },
  { value: "200-plus", label: "Over €200" },
];

const SORT_OPTIONS: Array<{ value: BrowseSort; label: string }> = [
  { value: "newest", label: "Newest first" },
  { value: "price-asc", label: "Price: low to high" },
  { value: "price-desc", label: "Price: high to low" },
];

const SORT_MOBILE_LABELS: Record<BrowseSort, string> = {
  newest: "Newest",
  "price-asc": "Low to high",
  "price-desc": "High to low",
};

type BrowsePopover = "category" | "price" | "sort";

function FilterChevron({ open }: { open: boolean }) {
  return <svg aria-hidden="true" width="10" height="6" viewBox="0 0 10 6" style={{ transform: open ? "rotate(180deg)" : "none", transition: "transform 160ms ease" }}><path d="M1 1l4 4 4-4" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>;
}

const CONDITION_COLORS: Record<string, string> = {
  new: "#5a7c4a",
  like_new: "#4a7c6a",
  good: "#8b6914",
  worn: "#7a5a3a",
  vintage: "#7a4a90",
};

function ProductCard({ item }: { item: Listing }) {
  const [hovered, setHovered] = useState(false);
  const conditionColor = CONDITION_COLORS[item.condition] || "var(--text-light)";

  return (
    <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "block", height: "100%", minWidth: 0 }}>
      <article
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hovered ? "0 10px 28px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hovered ? "translateY(-3px)" : "none", transition: "all 0.25s ease", display: "flex", flexDirection: "column", width: "100%", height: "100%", minWidth: 0 }}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        <div style={{ position: "relative", overflow: "hidden", aspectRatio: "1 / 1" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} style={{ width: "100%", height: "100%", objectFit: "cover", display: "block", transform: hovered ? "scale(1.05)" : "scale(1)", transition: "transform 0.5s ease" }} />
          {item.isFeatured && <span style={{ position: "absolute", top: "10px", left: "10px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "3px 8px", borderRadius: "3px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>Featured</span>}
        </div>
        <div style={{ padding: "11px 13px 14px", flex: 1, minWidth: 0 }}>
          <p style={{ fontSize: "10px", color: "var(--text-light)", letterSpacing: "0.06em", textTransform: "uppercase", margin: "0 0 4px" }}>{formatCategoryLabel(item.category)}</p>
          <h2 style={{ fontSize: "12px", fontWeight: 500, color: "var(--text)", lineHeight: 1.3, margin: "0 0 4px", overflow: "hidden", textOverflow: "ellipsis", display: "-webkit-box", WebkitBoxOrient: "vertical", WebkitLineClamp: 2, minHeight: "2.6em" }}>{item.title}</h2>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "6px" }}>
            <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "15px", fontWeight: 700, color: "var(--rust)" }}>{formatPrice(item.priceCents)}</span>
            <span style={{ fontSize: "9px", padding: "2px 6px", borderRadius: "4px", background: `${conditionColor}18`, color: conditionColor, fontWeight: 600 }}>{conditionLabels[item.condition]}</span>
          </div>
          {item.sellerHandle && <div style={{ display: "flex", alignItems: "center", gap: "4px", paddingTop: "6px", borderTop: "1px solid var(--sand)" }}><ProfileAvatar name={item.sellerName || item.sellerHandle} url={item.sellerAvatar} size={16} /><span style={{ fontSize: "10px", color: "var(--text-light)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>@{item.sellerHandle}</span></div>}
        </div>
      </article>
    </Link>
  );
}

async function fetchListings(state: BrowseState, cursor?: BrowseCursor) {
  const plan = createBrowseQueryPlan(state, cursor);
  const supabase = createClient();
  let query = supabase
    .from("listings")
    .select("*, profiles(handle, display_name, avatar_url)", { count: "exact" })
    .eq("status", "active");

  if (plan.textSearch) query = query.textSearch("search_vector", plan.textSearch, { type: "websearch" });
  if (plan.category) query = query.eq("category", plan.category);
  if (plan.minPrice !== undefined) query = query.gte("price", plan.minPrice);
  if (plan.maxPrice !== undefined) query = query.lte("price", plan.maxPrice);
  if (plan.cursorFilter) query = query.or(plan.cursorFilter);
  for (const order of plan.order) query = query.order(order.column, { ascending: order.ascending });

  return query.limit(BROWSE_PAGE_SIZE + 1);
}

async function fetchCategoryCounts(state: BrowseState): Promise<Record<string, number>> {
  const plan = createBrowseQueryPlan({ ...state, category: "all", sort: "newest" });
  const supabase = createClient();
  const counts = await Promise.all(BROWSE_CATEGORIES.map(async (category) => {
    let query = supabase
      .from("listings")
      .select("id", { count: "exact", head: true })
      .eq("status", "active")
      .eq("category", category);
    if (plan.textSearch) query = query.textSearch("search_vector", plan.textSearch, { type: "websearch" });
    if (plan.minPrice !== undefined) query = query.gte("price", plan.minPrice);
    if (plan.maxPrice !== undefined) query = query.lte("price", plan.maxPrice);
    const { count, error } = await query;
    if (error) throw error;
    return [category, count ?? 0] as const;
  }));

  return Object.fromEntries(counts);
}

export default function BrowsePageClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const paramsKey = searchParams.toString();
  const state = useMemo(() => parseBrowseParams(new URLSearchParams(paramsKey)), [paramsKey]);
  const requestId = useRef(0);
  const paginationInFlight = useRef(false);
  const toolbarRef = useRef<HTMLDivElement>(null);
  const [searchDraft, setSearchDraft] = useState(state.query);
  const [categoryCounts, setCategoryCounts] = useState<Record<string, number>>({});
  const [categoriesError, setCategoriesError] = useState(false);
  const [listings, setListings] = useState<Listing[]>([]);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);
  const [openPopover, setOpenPopover] = useState<BrowsePopover | null>(null);

  useEffect(() => setSearchDraft(state.query), [state.query]);

  useEffect(() => {
    if (!window.matchMedia("(max-width: 640px)").matches) return;
    const query = searchDraft.trim().slice(0, 120);
    if (query === state.query) return;
    const timeout = window.setTimeout(() => {
      router.replace(buildBrowseHref(state, { query }), { scroll: false });
    }, 160);
    return () => window.clearTimeout(timeout);
  }, [router, searchDraft, state]);

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

  useEffect(() => {
    let cancelled = false;
    setCategoriesError(false);
    void fetchCategoryCounts(state)
      .then((values) => {
        if (!cancelled) setCategoryCounts(values);
      })
      .catch(() => {
        if (!cancelled) {
          setCategoriesError(true);
        }
      });
    return () => { cancelled = true; };
  }, [state.query, state.price, retryKey]);

  useEffect(() => {
    const currentRequest = ++requestId.current;
    setLoading(true);
    setLoadingMore(false);
    paginationInFlight.current = false;
    setError(null);
    setListings([]);

    void fetchListings(state).then(({ data, error: queryError, count }) => {
      if (currentRequest !== requestId.current) return;
      if (queryError) {
        setTotal(0);
        setHasMore(false);
        setError("We couldn’t load listings. Please try again.");
      } else {
        const rows = data ?? [];
        setListings(rows.slice(0, BROWSE_PAGE_SIZE).map(toListing));
        setTotal(count ?? 0);
        setHasMore(rows.length > BROWSE_PAGE_SIZE);
      }
      setLoading(false);
    });
  }, [state, retryKey]);

  const navigate = (patch: Partial<BrowseState>) => router.replace(buildBrowseHref(state, patch), { scroll: false });
  const submitSearch = (event: FormEvent) => {
    event.preventDefault();
    navigate({ query: searchDraft.trim().slice(0, 120) });
  };
  const loadMore = async () => {
    const last = listings[listings.length - 1];
    if (!last || paginationInFlight.current) return;
    const currentRequest = requestId.current;
    paginationInFlight.current = true;
    setLoadingMore(true);
    setError(null);
    const { data, error: queryError } = await fetchListings(state, { id: last.id, createdAt: last.createdAt, price: last.priceCents });
    if (currentRequest !== requestId.current) return;
    if (queryError) {
      setError("We couldn’t load more listings. Please try again.");
    } else {
      const rows = data ?? [];
      setListings((current) => [...current, ...rows.slice(0, BROWSE_PAGE_SIZE).map(toListing)]);
      setHasMore(rows.length > BROWSE_PAGE_SIZE);
    }
    paginationInFlight.current = false;
    setLoadingMore(false);
  };
  const hasActiveFilters = Boolean(state.query || state.category !== "all" || state.price !== "any" || state.sort !== "newest");
  const allCategoryCount = BROWSE_CATEGORIES.reduce((sum, category) => sum + (categoryCounts[category] ?? 0), 0);
  const selectedPriceLabel = PRICE_OPTIONS.find((option) => option.value === state.price)?.label ?? "Any price";
  const selectedSortLabel = SORT_OPTIONS.find((option) => option.value === state.sort)?.label ?? "Newest first";
  const selectedSortMobileLabel = SORT_MOBILE_LABELS[state.sort];
  const chooseFilter = (patch: Partial<BrowseState>) => {
    navigate(patch);
    setOpenPopover(null);
  };

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />
      <main>
        <section className="stagger-item site-shell" style={{ "--i": 0, boxSizing: "border-box", minHeight: "120px", paddingTop: "14px", paddingBottom: "14px", display: "flex", flexDirection: "column", justifyContent: "center" } as CSSProperties}>
          <p style={{ fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--rust)", margin: "0 0 4px" }}>Marketplace</p>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "40px", fontWeight: 800, color: "var(--text)", margin: "0 0 4px", letterSpacing: "-0.03em", lineHeight: 1.05 }}>Browse</h1>
          <p style={{ fontSize: "14px", color: "var(--text-mid)", lineHeight: 1.5, margin: 0 }}>Every active listing from the tribe — apparel, art, sound and tickets.</p>
        </section>

        <section className="browse-filter-sticky stagger-item" style={{ "--i": 1 } as CSSProperties} aria-label="Listing filters">
          <div ref={toolbarRef} className="browse-marketplace-toolbar site-shell">
            <div className="browse-marketplace-toolbar-main">
              <form onSubmit={submitSearch} className="browse-toolbar-search">
                <label htmlFor="browse-search" className="sr-only">Search listings</label>
                <input id="browse-search" type="search" value={searchDraft} onChange={(event) => setSearchDraft(event.target.value)} placeholder="Search listings, sellers, festivals…" maxLength={120} />
                {searchDraft && <button type="button" className="browse-search-clear" aria-label="Clear search" onClick={() => { setSearchDraft(""); navigate({ query: "" }); }}>×</button>}
              </form>

              <div className="browse-filter-menu">
                <button type="button" className={`browse-filter-trigger${state.category !== "all" ? " is-active" : ""}`} aria-haspopup="true" aria-expanded={openPopover === "category"} aria-controls="browse-category-popover" onClick={() => setOpenPopover((current) => current === "category" ? null : "category")}>
                  <span className="browse-filter-key">CATEGORY</span><span className="browse-filter-value">{state.category === "all" ? "All" : formatCategoryLabel(state.category)}</span><FilterChevron open={openPopover === "category"} />
                </button>
                {openPopover === "category" && <div id="browse-category-popover" className="browse-filter-popover browse-category-popover" role="group" aria-label="Choose a category">
                  <button type="button" aria-pressed={state.category === "all"} onClick={() => chooseFilter({ category: "all" })}><span className="browse-option-check" aria-hidden="true">{state.category === "all" ? "✓" : ""}</span><span className="browse-option-label">All</span><span className="browse-category-count">{allCategoryCount}</span></button>
                  {BROWSE_CATEGORIES.map((category) => {
                    const count = categoryCounts[category] ?? 0;
                    return <button key={category} type="button" aria-pressed={state.category === category} disabled={count === 0} onClick={() => chooseFilter({ category })}><span className="browse-option-check" aria-hidden="true">{state.category === category ? "✓" : ""}</span><span className="browse-option-label">{formatCategoryLabel(category)}</span><span className="browse-category-count">{count}</span></button>;
                  })}
                  {categoriesError && <button type="button" className="browse-filter-retry" onClick={() => setRetryKey((value) => value + 1)}>Retry categories</button>}
                </div>}
              </div>

              <div className="browse-filter-menu">
                <button type="button" className={`browse-filter-trigger${state.sort !== "newest" ? " is-active" : ""}`} aria-haspopup="true" aria-expanded={openPopover === "sort"} aria-controls="browse-sort-popover" onClick={() => setOpenPopover((current) => current === "sort" ? null : "sort")}>
                  <span className="browse-filter-key">SORT</span><span className="browse-filter-value browse-filter-value-desktop">{selectedSortLabel}</span><span className="browse-filter-value browse-filter-value-mobile">{selectedSortMobileLabel}</span><FilterChevron open={openPopover === "sort"} />
                </button>
                {openPopover === "sort" && <div id="browse-sort-popover" className="browse-filter-popover browse-sort-popover" role="group" aria-label="Sort listings">
                  {SORT_OPTIONS.map((option) => <button key={option.value} type="button" aria-pressed={state.sort === option.value} onClick={() => chooseFilter({ sort: option.value })}><span className="browse-option-check" aria-hidden="true">{state.sort === option.value ? "✓" : ""}</span><span className="browse-option-label">{option.label}</span></button>)}
                </div>}
              </div>

              <div className="browse-filter-menu">
                <button type="button" className={`browse-filter-trigger${state.price !== "any" ? " is-active" : ""}`} aria-haspopup="true" aria-expanded={openPopover === "price"} aria-controls="browse-price-popover" onClick={() => setOpenPopover((current) => current === "price" ? null : "price")}>
                  <span className="browse-filter-key">PRICE</span><span className="browse-filter-value">{selectedPriceLabel}</span><FilterChevron open={openPopover === "price"} />
                </button>
                {openPopover === "price" && <div id="browse-price-popover" className="browse-filter-popover" role="group" aria-label="Choose a price range">
                  {PRICE_OPTIONS.map((option) => <button key={option.value} type="button" aria-pressed={state.price === option.value} onClick={() => chooseFilter({ price: option.value })}><span className="browse-option-check" aria-hidden="true">{state.price === option.value ? "✓" : ""}</span><span className="browse-option-label">{option.label}</span></button>)}
                </div>}
              </div>
            </div>

          </div>
        </section>

        <section className="site-shell" style={{ paddingTop: "48px", paddingBottom: "80px" }} aria-live="polite">
          <div className="browse-results-meta">
            {loading ? (
              <p style={{ margin: 0, color: "var(--text-light)", fontSize: "13px" }}>Loading listings…</p>
            ) : state.query ? (
              <p style={{ margin: 0, color: "var(--text-mid)", fontSize: "13px" }}><strong style={{ color: "var(--text)", fontWeight: 700 }}>{total}</strong> {total === 1 ? "result" : "results"} for &quot;<strong style={{ color: "var(--rust)", fontWeight: 700 }}>{state.query}</strong>&quot;</p>
            ) : (
              <p style={{ margin: 0, color: "var(--text-light)", fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase" }}>{total} listings</p>
            )}
            {(state.category !== "all" || state.price !== "any") && <div className="browse-active-filters" aria-label="Active filters">
              {state.category !== "all" && <button type="button" onClick={() => navigate({ category: "all" })}><span className="browse-active-chip-key">CAT</span><span>{formatCategoryLabel(state.category)}</span><span aria-hidden="true">×</span><span className="sr-only">Remove category filter</span></button>}
              {state.price !== "any" && <button type="button" onClick={() => navigate({ price: "any" })}><span className="browse-active-chip-key">PRICE</span><span>{selectedPriceLabel}</span><span aria-hidden="true">×</span><span className="sr-only">Remove price filter</span></button>}
            </div>}
            <div className="browse-results-meta-spacer" />
            {hasActiveFilters && <Link href="/browse" className="browse-clear-filters">Clear filters</Link>}
          </div>

          {loading ? (
            <div className="browse-results-grid">{Array.from({ length: 10 }).map((_, index) => <div key={index} className="skeleton-block" style={{ height: "270px" }} />)}</div>
          ) : error && listings.length === 0 ? (
            <div role="alert" style={{ textAlign: "center", padding: "70px 20px", color: "var(--text-mid)" }}><h2 style={{ color: "var(--text)", marginBottom: "8px" }}>Something went wrong</h2><p>{error}</p><button type="button" onClick={() => setRetryKey((value) => value + 1)} style={{ border: 0, borderRadius: "7px", background: "var(--dark)", color: "white", padding: "9px 18px", fontWeight: 700, cursor: "pointer" }}>Retry</button></div>
          ) : listings.length === 0 ? (
            <div style={{ textAlign: "center", padding: "70px 20px", color: "var(--text-light)" }}><h2 style={{ color: "var(--text)", marginBottom: "8px" }}>{state.query ? `Nothing found for '${state.query}'` : "No listings found"}</h2><p>Try adjusting your search or filters.</p><Link href="/browse" style={{ color: "var(--rust)", fontWeight: 700 }}>Clear all filters</Link></div>
          ) : (
            <div className="browse-results-grid">{listings.map((item, index) => <div key={item.id} className="stagger-item" style={{ "--i": Math.min(index, 9), minWidth: 0, height: "100%" } as CSSProperties}><ProductCard item={item} /></div>)}</div>
          )}

          {!loading && listings.length > 0 && <div style={{ textAlign: "center", marginTop: "42px" }}>{error && <p role="alert" style={{ color: "#a33" }}>{error}</p>}{hasMore && <button type="button" onClick={() => void loadMore()} disabled={loadingMore} style={{ border: "1px solid var(--dark)", borderRadius: "7px", background: "var(--white)", color: "var(--dark)", padding: "10px 22px", fontWeight: 700, cursor: loadingMore ? "default" : "pointer" }}>{loadingMore ? "Loading…" : "Load more"}</button>}{!hasMore && <p style={{ color: "var(--text-light)", fontSize: "13px" }}>All results loaded</p>}</div>}
        </section>
      </main>
      <Footer />
      <style>{`
        .browse-results-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); column-gap: 24px; row-gap: 26px; align-items: stretch; }
        @media (max-width: 1180px) { .browse-results-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
        @media (max-width: 860px) { .browse-results-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
        @media (max-width: 640px) { .browse-results-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 10px; row-gap: 14px; } }
        @media (max-width: 379px) { .browse-results-grid { grid-template-columns: minmax(0, 1fr); } }
      `}</style>
    </div>
  );
}
