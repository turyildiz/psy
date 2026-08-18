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
    <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "block" }}>
      <article
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hovered ? "0 10px 28px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hovered ? "translateY(-3px)" : "none", transition: "all 0.25s ease" }}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        <div style={{ position: "relative", overflow: "hidden" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} style={{ width: "100%", height: "220px", objectFit: "cover", display: "block", transform: hovered ? "scale(1.05)" : "scale(1)", transition: "transform 0.5s ease" }} />
          {item.isFeatured && <span style={{ position: "absolute", top: "10px", left: "10px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "3px 8px", borderRadius: "3px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>Featured</span>}
        </div>
        <div style={{ padding: "11px 13px 14px" }}>
          <p style={{ fontSize: "10px", color: "var(--text-light)", letterSpacing: "0.06em", textTransform: "uppercase", margin: "0 0 4px" }}>{formatCategoryLabel(item.category)}</p>
          <h2 style={{ fontSize: "12px", fontWeight: 500, color: "var(--text)", lineHeight: 1.3, margin: "0 0 4px", overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>{item.title}</h2>
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

async function fetchActiveCategories(): Promise<string[]> {
  const supabase = createClient();
  const counts = await Promise.all(BROWSE_CATEGORIES.map(async (category) => {
    const { count, error } = await supabase
      .from("listings")
      .select("id", { count: "exact", head: true })
      .eq("status", "active")
      .eq("category", category);
    if (error) throw error;
    return count && count > 0 ? category : null;
  }));

  return counts.filter((category): category is (typeof BROWSE_CATEGORIES)[number] => category !== null);
}

export default function BrowsePageClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const paramsKey = searchParams.toString();
  const state = useMemo(() => parseBrowseParams(new URLSearchParams(paramsKey)), [paramsKey]);
  const requestId = useRef(0);
  const paginationInFlight = useRef(false);
  const [searchDraft, setSearchDraft] = useState(state.query);
  const [categories, setCategories] = useState<string[]>([]);
  const [categoriesError, setCategoriesError] = useState(false);
  const [listings, setListings] = useState<Listing[]>([]);
  const [total, setTotal] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => setSearchDraft(state.query), [state.query]);

  useEffect(() => {
    let cancelled = false;
    setCategoriesError(false);
    void fetchActiveCategories()
      .then((values) => {
        if (!cancelled) setCategories(values);
      })
      .catch(() => {
        if (!cancelled) {
          setCategoriesError(true);
        }
      });
    return () => { cancelled = true; };
  }, [retryKey]);

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
  const hasFilters = Boolean(state.query || state.category !== "all" || state.price !== "any" || state.sort !== "newest");

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />
      <main>
        <section style={{ position: "relative", background: "var(--dark)", overflow: "hidden", minHeight: "300px", display: "flex", alignItems: "center" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="https://images.psy.market/listings/ai-generated/1780562083573.jpg" alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: "50% 30%" }} />
          <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to right, oklch(10% 0.01 55 / 0.92) 0%, oklch(10% 0.01 55 / 0.6) 45%, oklch(10% 0.01 55 / 0.05) 100%)" }} />
          <div className="stagger-item site-shell" style={{ "--i": 0, position: "relative", zIndex: 1, paddingTop: "52px", paddingBottom: "52px" } as CSSProperties}>
            <p style={{ fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--rust)", marginBottom: "10px" }}>Marketplace</p>
            <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "clamp(32px, 5vw, 52px)", fontWeight: 800, color: "white", margin: "0 0 10px", letterSpacing: "-0.03em", lineHeight: 1.1 }}>Browse the marketplace</h1>
            <p style={{ fontSize: "15px", color: "oklch(72% 0.01 70)", maxWidth: "460px", lineHeight: 1.6, margin: 0 }}>Search active listings from across Psy.market.</p>
          </div>
        </section>

        <section className="browse-filter-sticky stagger-item" style={{ "--i": 1 } as CSSProperties} aria-label="Listing filters">
          <div className="browse-filter-inner browse-marketplace-filter-inner">
            <div className="browse-filter-row browse-marketplace-search-row">
            <form onSubmit={submitSearch} style={{ display: "flex", flex: 1, gap: "8px", minWidth: 0 }}>
              <label htmlFor="browse-search" className="sr-only">Search listings</label>
              <input id="browse-search" type="search" value={searchDraft} onChange={(event) => setSearchDraft(event.target.value)} placeholder="Search titles, descriptions and tags" maxLength={120} style={{ minWidth: 0, flex: 1, border: "1px solid var(--sand)", borderRadius: "6px", background: "transparent", color: "var(--text)", padding: "7px 10px", font: "inherit", fontSize: "13px", outline: "none" }} />
              <button type="submit" style={{ border: 0, borderRadius: "6px", background: "var(--rust)", color: "white", padding: "7px 18px", fontSize: "13px", fontWeight: 700, cursor: "pointer" }}>Search</button>
            </form>
            </div>
            <div className="browse-filter-row browse-marketplace-options-row">
            <div className="browse-pills-group" aria-label="Category">
              <button type="button" onClick={() => navigate({ category: "all" })} aria-pressed={state.category === "all"} style={{ padding: "7px 18px", borderRadius: "20px", fontSize: "13px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", fontWeight: 500, transition: "all 0.2s", border: `1px solid ${state.category === "all" ? "var(--rust)" : "var(--sand)"}`, background: state.category === "all" ? "var(--rust)" : "transparent", color: state.category === "all" ? "white" : "var(--text-mid)", whiteSpace: "nowrap" }}>All</button>
              {categories.map((category) => <button key={category} type="button" onClick={() => navigate({ category })} aria-pressed={state.category === category} style={{ padding: "7px 18px", borderRadius: "20px", fontSize: "13px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", fontWeight: 500, transition: "all 0.2s", border: `1px solid ${state.category === category ? "var(--rust)" : "var(--sand)"}`, background: state.category === category ? "var(--rust)" : "transparent", color: state.category === category ? "white" : "var(--text-mid)", whiteSpace: "nowrap" }}>{formatCategoryLabel(category)}</button>)}
              {categoriesError && <button type="button" onClick={() => setRetryKey((value) => value + 1)} style={{ border: 0, background: "transparent", color: "var(--rust)", cursor: "pointer", fontWeight: 700 }}>Retry categories</button>}
            </div>
            <div className="browse-filter-spacer" />
            <label style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0, fontSize: "13px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Sort
              <select value={state.sort} onChange={(event) => navigate({ sort: event.target.value as BrowseSort })} style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none", textTransform: "none", letterSpacing: 0 }}>{SORT_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select>
            </label>
            <div style={{ width: "1px", height: "20px", background: "var(--sand)", flexShrink: 0 }} />
            <label style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0, fontSize: "13px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Price
              <select value={state.price} onChange={(event) => navigate({ price: event.target.value as BrowsePrice })} style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none", textTransform: "none", letterSpacing: 0 }}>{PRICE_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select>
            </label>
            </div>
          </div>
        </section>

        <section className="site-shell" style={{ paddingTop: "48px", paddingBottom: "80px" }} aria-live="polite">
          <div style={{ display: "flex", alignItems: "center", gap: "14px", marginBottom: "24px", flexWrap: "wrap" }}>
            <div style={{ width: "26px", height: "2px", background: "var(--rust)", flexShrink: 0 }} />
            <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 700, color: "var(--text)", margin: 0, letterSpacing: "-0.02em" }}>All Listings</h2>
            <p style={{ margin: 0, color: "var(--text-light)", fontSize: "13px" }}>{loading ? "Loading listings…" : `${total} ${total === 1 ? "result" : "results"}`}{state.query ? ` for “${state.query}”` : ""}</p>
            <div style={{ flex: 1 }} />
            {hasFilters && <Link href="/browse" style={{ color: "var(--rust)", fontSize: "13px", fontWeight: 700 }}>Clear filters</Link>}
          </div>

          {loading ? (
            <div className="apparel-grid">{Array.from({ length: 10 }).map((_, index) => <div key={index} className="skeleton-block" style={{ height: "270px" }} />)}</div>
          ) : error && listings.length === 0 ? (
            <div role="alert" style={{ textAlign: "center", padding: "70px 20px", color: "var(--text-mid)" }}><h2 style={{ color: "var(--text)", marginBottom: "8px" }}>Something went wrong</h2><p>{error}</p><button type="button" onClick={() => setRetryKey((value) => value + 1)} style={{ border: 0, borderRadius: "7px", background: "var(--dark)", color: "white", padding: "9px 18px", fontWeight: 700, cursor: "pointer" }}>Retry</button></div>
          ) : listings.length === 0 ? (
            <div style={{ textAlign: "center", padding: "70px 20px", color: "var(--text-light)" }}><h2 style={{ color: "var(--text)", marginBottom: "8px" }}>{state.query ? `Nothing found for '${state.query}'` : "No listings found"}</h2><p>Try adjusting your search or filters.</p><Link href="/browse" style={{ color: "var(--rust)", fontWeight: 700 }}>Clear all filters</Link></div>
          ) : (
            <div className="apparel-grid">{listings.map((item, index) => <div key={item.id} className="stagger-item" style={{ "--i": Math.min(index, 9) } as CSSProperties}><ProductCard item={item} /></div>)}</div>
          )}

          {!loading && listings.length > 0 && <div style={{ textAlign: "center", marginTop: "42px" }}>{error && <p role="alert" style={{ color: "#a33" }}>{error}</p>}{hasMore && <button type="button" onClick={() => void loadMore()} disabled={loadingMore} style={{ border: "1px solid var(--dark)", borderRadius: "7px", background: "var(--white)", color: "var(--dark)", padding: "10px 22px", fontWeight: 700, cursor: loadingMore ? "default" : "pointer" }}>{loadingMore ? "Loading…" : "Load more"}</button>}{!hasMore && <p style={{ color: "var(--text-light)", fontSize: "13px" }}>All results loaded</p>}</div>}
        </section>
      </main>
      <Footer />
      <style>{`
        .apparel-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 16px; }
        @media (max-width: 1024px) { .apparel-grid { grid-template-columns: repeat(4, 1fr); } }
        @media (max-width: 768px) { .apparel-grid { grid-template-columns: repeat(2, 1fr); gap: 10px; } }
      `}</style>
    </div>
  );
}
