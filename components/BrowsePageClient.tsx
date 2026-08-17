"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useEffect, useMemo, useRef, useState, type CSSProperties } from "react";

import Footer from "@/components/layout/Footer";
import Header from "@/components/layout/Header";
import ProfileAvatar from "@/components/ProfileAvatar";
import {
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
    <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "flex", height: "100%" }}>
      <article
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", display: "flex", flexDirection: "column", width: "100%", boxShadow: hovered ? "0 12px 36px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hovered ? "translateY(-4px)" : "none", transition: "transform 0.25s ease, box-shadow 0.25s ease" }}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        <div style={{ position: "relative", overflow: "hidden" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} style={{ width: "100%", height: "260px", objectFit: "cover", display: "block", transform: hovered ? "scale(1.04)" : "scale(1)", transition: "transform 0.4s ease" }} />
          {item.isFeatured && <span style={{ position: "absolute", top: "10px", left: "10px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "3px 8px", borderRadius: "3px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>Featured</span>}
        </div>
        <div style={{ padding: "13px 14px 15px", flex: 1, display: "flex", flexDirection: "column", gap: "5px" }}>
          <span style={{ fontSize: "10px", color: "var(--text-light)", letterSpacing: "0.08em", textTransform: "uppercase" }}>{formatCategoryLabel(item.category)}</span>
          <h2 style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", lineHeight: 1.35, margin: 0, flex: 1 }}>{item.title}</h2>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "8px", marginTop: "6px" }}>
            <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "18px", fontWeight: 700, color: "var(--rust)" }}>€{(item.priceCents / 100).toFixed(2)}</span>
            <span style={{ fontSize: "10px", padding: "2px 8px", borderRadius: "3px", background: `${conditionColor}18`, color: conditionColor, fontWeight: 600 }}>{conditionLabels[item.condition]}</span>
          </div>
          {item.sellerHandle && <div style={{ display: "flex", alignItems: "center", gap: "5px", marginTop: "8px", paddingTop: "8px", borderTop: "1px solid var(--sand)" }}><ProfileAvatar name={item.sellerName || item.sellerHandle} url={item.sellerAvatar} size={20} /><span style={{ fontSize: "11px", color: "var(--text-light)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>@{item.sellerHandle}</span></div>}
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
  const categories = new Set<string>();
  let afterId: string | undefined;

  while (true) {
    let query = supabase
      .from("listings")
      .select("id, category")
      .eq("status", "active")
      .order("id", { ascending: true })
      .limit(1000);
    if (afterId) query = query.gt("id", afterId);

    const { data, error } = await query;
    if (error) throw error;
    const rows = data ?? [];
    for (const row of rows) {
      if (row.category) categories.add(row.category as string);
    }
    if (rows.length < 1000) break;
    afterId = rows[rows.length - 1].id as string;
  }

  return Array.from(categories).sort();
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
        <section className="browse-content" style={{ paddingBottom: "20px" }}>
          <p style={{ fontSize: "11px", color: "var(--text-light)", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: "8px" }}><Link href="/" style={{ color: "inherit", textDecoration: "none" }}>Home</Link>{" → Browse"}</p>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "clamp(30px, 4vw, 46px)", color: "var(--text)", margin: "0 0 8px" }}>Browse the marketplace</h1>
          <p style={{ color: "var(--text-light)", margin: 0 }}>Search active listings from across Psy.market.</p>
        </section>

        <section className="browse-filter-sticky" aria-label="Listing filters">
          <div className="browse-filter-inner" style={{ height: "auto", paddingTop: "14px", paddingBottom: "14px", flexWrap: "wrap" }}>
            <form onSubmit={submitSearch} style={{ display: "flex", flex: "1 1 320px", gap: "8px" }}>
              <label htmlFor="browse-search" className="sr-only">Search listings</label>
              <input id="browse-search" type="search" value={searchDraft} onChange={(event) => setSearchDraft(event.target.value)} placeholder="Search titles, descriptions and tags" maxLength={120} style={{ minWidth: 0, flex: 1, border: "1px solid var(--sand)", borderRadius: "7px", background: "var(--white)", color: "var(--text)", padding: "9px 12px", font: "inherit" }} />
              <button type="submit" style={{ border: 0, borderRadius: "7px", background: "var(--dark)", color: "white", padding: "9px 18px", fontWeight: 700, cursor: "pointer" }}>Search</button>
            </form>
            <label style={{ display: "flex", alignItems: "center", gap: "7px", fontSize: "12px", color: "var(--text-light)" }}>Price
              <select value={state.price} onChange={(event) => navigate({ price: event.target.value as BrowsePrice })} style={{ border: "1px solid var(--sand)", borderRadius: "6px", background: "var(--white)", padding: "7px 9px", color: "var(--text)" }}>{PRICE_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select>
            </label>
            <label style={{ display: "flex", alignItems: "center", gap: "7px", fontSize: "12px", color: "var(--text-light)" }}>Sort
              <select value={state.sort} onChange={(event) => navigate({ sort: event.target.value as BrowseSort })} style={{ border: "1px solid var(--sand)", borderRadius: "6px", background: "var(--white)", padding: "7px 9px", color: "var(--text)" }}>{SORT_OPTIONS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select>
            </label>
            <div className="browse-pills-group" aria-label="Category">
              <button type="button" onClick={() => navigate({ category: "all" })} aria-pressed={state.category === "all"} style={{ padding: "7px 16px", borderRadius: "20px", border: `1px solid ${state.category === "all" ? "var(--dark)" : "var(--sand)"}`, background: state.category === "all" ? "var(--dark)" : "transparent", color: state.category === "all" ? "white" : "var(--text-mid)", cursor: "pointer" }}>All</button>
              {categories.map((category) => <button key={category} type="button" onClick={() => navigate({ category })} aria-pressed={state.category === category} style={{ padding: "7px 16px", borderRadius: "20px", border: `1px solid ${state.category === category ? "var(--dark)" : "var(--sand)"}`, background: state.category === category ? "var(--dark)" : "transparent", color: state.category === category ? "white" : "var(--text-mid)", cursor: "pointer" }}>{formatCategoryLabel(category)}</button>)}
              {categoriesError && <button type="button" onClick={() => setRetryKey((value) => value + 1)} style={{ border: 0, background: "transparent", color: "var(--rust)", cursor: "pointer", fontWeight: 700 }}>Retry categories</button>}
            </div>
          </div>
        </section>

        <section className="browse-content" aria-live="polite">
          <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", gap: "16px", marginBottom: "24px", flexWrap: "wrap" }}>
            <p style={{ margin: 0, color: "var(--text-mid)", fontSize: "14px" }}>{loading ? "Loading listings…" : `${total} ${total === 1 ? "result" : "results"}`}{state.query ? ` for “${state.query}”` : ""}</p>
            {hasFilters && <Link href="/browse" style={{ color: "var(--rust)", fontSize: "13px", fontWeight: 700 }}>Clear filters</Link>}
          </div>

          {loading ? (
            <div className="browse-grid" style={{ gridTemplateColumns: "repeat(4, 1fr)" }}>{Array.from({ length: 8 }).map((_, index) => <div key={index} className="skeleton-block" style={{ height: "355px" }} />)}</div>
          ) : error && listings.length === 0 ? (
            <div role="alert" style={{ textAlign: "center", padding: "70px 20px", color: "var(--text-mid)" }}><h2 style={{ color: "var(--text)", marginBottom: "8px" }}>Something went wrong</h2><p>{error}</p><button type="button" onClick={() => setRetryKey((value) => value + 1)} style={{ border: 0, borderRadius: "7px", background: "var(--dark)", color: "white", padding: "9px 18px", fontWeight: 700, cursor: "pointer" }}>Retry</button></div>
          ) : listings.length === 0 ? (
            <div style={{ textAlign: "center", padding: "70px 20px", color: "var(--text-light)" }}><h2 style={{ color: "var(--text)", marginBottom: "8px" }}>{state.query ? `Nothing found for '${state.query}'` : "No listings found"}</h2><p>Try adjusting your search or filters.</p><Link href="/browse" style={{ color: "var(--rust)", fontWeight: 700 }}>Clear all filters</Link></div>
          ) : (
            <div className="browse-grid" style={{ gridTemplateColumns: "repeat(4, 1fr)" }}>{listings.map((item, index) => <div key={item.id} className="stagger-item" style={{ "--i": Math.min(index, 9) } as CSSProperties}><ProductCard item={item} /></div>)}</div>
          )}

          {!loading && listings.length > 0 && <div style={{ textAlign: "center", marginTop: "42px" }}>{error && <p role="alert" style={{ color: "#a33" }}>{error}</p>}{hasMore && <button type="button" onClick={() => void loadMore()} disabled={loadingMore} style={{ border: "1px solid var(--dark)", borderRadius: "7px", background: "var(--white)", color: "var(--dark)", padding: "10px 22px", fontWeight: 700, cursor: loadingMore ? "default" : "pointer" }}>{loadingMore ? "Loading…" : "Load more"}</button>}{!hasMore && <p style={{ color: "var(--text-light)", fontSize: "13px" }}>All results loaded</p>}</div>}
        </section>
      </main>
      <Footer />
    </div>
  );
}
