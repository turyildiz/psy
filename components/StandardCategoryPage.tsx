"use client";

import { useEffect, useState, type CSSProperties } from "react";
import Link from "next/link";
import Footer from "@/components/layout/Footer";
import Header from "@/components/layout/Header";
import ProfileAvatar from "@/components/ProfileAvatar";
import { conditionLabels } from "@/lib/constants";
import { toListing } from "@/lib/db";
import { formatPrice } from "@/lib/listings/price";
import { createClient } from "@/lib/supabase/client";
import type { Listing } from "@/types/marketplace";

const CONDITION_COLORS: Record<string, string> = {
  new: "#5a7c4a",
  like_new: "#4a7c6a",
  good: "#8b6914",
  worn: "#7a5a3a",
  vintage: "#7a4a90",
};

const SORT_OPTIONS = ["Newest First", "Price: Low to High", "Price: High to Low"];
const PRICE_RANGES = ["Any Price", "Under €50", "€50–€100", "€100–€200", "€200+"];

type StandardCategoryPageProps = {
  title: string;
  tagline: string;
  heroImage: string;
  heroObjectPosition?: string;
  filterColumn?: "category" | "condition";
  filterValue?: string;
  allLabel: string;
  featuredLabel: string;
  emptyLabel: string;
  infoBanner?: string;
  showFeatured?: boolean;
};

function FeaturedCard({ item }: { item: Listing }) {
  const [hovered, setHovered] = useState(false);
  const conditionColor = CONDITION_COLORS[item.condition] || "var(--text-light)";

  return (
    <Link href={`/listing/${item.id}`} className="standard-category-featured-link" style={{ textDecoration: "none" }}>
      <div
        className="standard-category-featured-card"
        style={{ background: "var(--white)", borderRadius: "12px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hovered ? "0 16px 48px oklch(35% 0.06 55 / 0.18)" : "0 4px 14px oklch(0% 0 0 / 0.08)", transform: hovered ? "translateY(-5px)" : "none", transition: "all 0.3s ease" }}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        <div className="standard-category-featured-image">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            className="standard-category-featured-image-element"
            src={item.images[0] || "/listing-placeholder.webp"}
            onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }}
            alt={item.title}
            style={{ transition: "transform 0.55s ease", transform: hovered ? "scale(1.04)" : "scale(1)" }}
          />
          <span style={{ position: "absolute", top: "12px", left: "12px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "4px 10px", borderRadius: "4px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>
            Featured
          </span>
        </div>
        <div className="standard-category-featured-content" style={{ padding: "16px 18px 20px" }}>
          <p className="standard-category-featured-title" style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3 }}>{item.title}</p>
          {item.description && (
            <p className="standard-category-featured-description" style={{ fontSize: "12px", color: "var(--text-light)", marginBottom: "12px", lineHeight: 1.5, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2 } as CSSProperties}>
              {item.description}
            </p>
          )}
          <div className="standard-category-featured-price-row">
            <p className="standard-category-featured-price" style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "22px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
              {formatPrice(item.priceCents)}
            </p>
            <span className="standard-category-featured-condition" style={{ fontSize: "10px", padding: "2px 8px", borderRadius: "4px", background: `${conditionColor}18`, color: conditionColor, fontWeight: 600 }}>
              {conditionLabels[item.condition]}
            </span>
          </div>
          {item.sellerHandle && (
            <div className="standard-category-featured-seller-row" style={{ marginTop: "10px", paddingTop: "10px", borderTop: "1px solid var(--sand)" }}>
              <ProfileAvatar name={item.sellerName || item.sellerHandle} url={item.sellerAvatar} size={20} />
              <span className="standard-category-featured-seller-handle" style={{ fontSize: "11px", color: "var(--text-light)" }}>@{item.sellerHandle}</span>
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}

function ListingCard({ item }: { item: Listing }) {
  const [hovered, setHovered] = useState(false);

  return (
    <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "block" }}>
      <div
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hovered ? "0 10px 28px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hovered ? "translateY(-3px)" : "none", transition: "all 0.25s ease" }}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
      >
        <div style={{ overflow: "hidden" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} style={{ width: "100%", height: "180px", objectFit: "cover", display: "block", transition: "transform 0.5s ease", transform: hovered ? "scale(1.05)" : "scale(1)" }} />
        </div>
        <div style={{ padding: "11px 13px 14px" }}>
          <p style={{ fontSize: "12px", fontWeight: 500, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3, overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>{item.title}</p>
          <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "15px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
            {formatPrice(item.priceCents)}
          </p>
          {item.sellerHandle && (
            <div style={{ display: "flex", alignItems: "center", gap: "4px", marginTop: "6px", paddingTop: "6px", borderTop: "1px solid var(--sand)" }}>
              <ProfileAvatar name={item.sellerName || item.sellerHandle} url={item.sellerAvatar} size={16} />
              <span style={{ fontSize: "10px", color: "var(--text-light)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>@{item.sellerHandle}</span>
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}

function SectionHeading({ children, count }: { children: React.ReactNode; count?: number }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: "14px", marginBottom: "24px" }}>
      <div style={{ width: "26px", height: "2px", background: "var(--rust)", flexShrink: 0 }} />
      <h2 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 700, color: "var(--text)", margin: 0, letterSpacing: "-0.02em" }}>
        {children}
      </h2>
      {count !== undefined && <span style={{ fontSize: "13px", color: "var(--text-light)" }}>{count} items</span>}
    </div>
  );
}

export default function StandardCategoryPage({
  title,
  tagline,
  heroImage,
  heroObjectPosition = "50% center",
  filterColumn,
  filterValue,
  allLabel,
  featuredLabel,
  emptyLabel,
  infoBanner,
  showFeatured = true,
}: StandardCategoryPageProps) {
  const [allListings, setAllListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTags, setActiveTags] = useState<string[]>([]);
  const [sort, setSort] = useState("Newest First");
  const [priceRange, setPriceRange] = useState("Any Price");

  useEffect(() => {
    let cancelled = false;
    const supabase = createClient();
    let query = supabase
      .from("listings")
      .select("*, profiles(handle, display_name, avatar_url)")
      .eq("status", "active");
    if (filterColumn && filterValue) query = query.eq(filterColumn, filterValue);

    void (async () => {
      try {
        const { data } = await query;
        if (cancelled) return;
        setAllListings((data ?? []).map(toListing));
        setLoading(false);
      } catch {
        if (cancelled) return;
        setAllListings([]);
        setLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, [filterColumn, filterValue]);

  const toggleTag = (tag: string) => {
    setActiveTags((current) => current.includes(tag) ? current.filter((item) => item !== tag) : [...current, tag]);
  };

  const topTags = Object.entries(
    allListings.flatMap((listing) => listing.tags).reduce<Record<string, number>>((counts, tag) => {
      counts[tag] = (counts[tag] ?? 0) + 1;
      return counts;
    }, {})
  )
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([tag]) => tag);

  const filtered = allListings.filter((listing) => {
    if (activeTags.length > 0 && !activeTags.some((tag) => listing.tags.includes(tag))) return false;
    const price = listing.priceCents / 100;
    if (priceRange === "Under €50" && price >= 50) return false;
    if (priceRange === "€50–€100" && (price < 50 || price > 100)) return false;
    if (priceRange === "€100–€200" && (price < 100 || price > 200)) return false;
    if (priceRange === "€200+" && price < 200) return false;
    return true;
  }).sort((a, b) => {
    if (sort === "Price: Low to High") return a.priceCents - b.priceCents;
    if (sort === "Price: High to Low") return b.priceCents - a.priceCents;
    return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
  });

  const featuredItems = showFeatured ? filtered.filter((listing) => listing.isFeatured).slice(0, 3) : [];
  const hasFeatured = showFeatured && featuredItems.length >= 2;
  const featuredIds = new Set(featuredItems.map((listing) => listing.id));
  const gridItems = hasFeatured ? filtered.filter((listing) => !featuredIds.has(listing.id)) : filtered;

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      <div style={{ position: "relative", background: "var(--dark)", overflow: "hidden", minHeight: "300px", display: "flex", alignItems: "center" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={heroImage} alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: heroObjectPosition, opacity: 1 }} />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to right, oklch(10% 0.01 55 / 0.92) 0%, oklch(10% 0.01 55 / 0.6) 45%, oklch(10% 0.01 55 / 0.05) 100%)" }} />
        <div className="stagger-item site-shell" style={{ "--i": 0, position: "relative", zIndex: 1, paddingTop: "52px", paddingBottom: "52px" } as CSSProperties}>
          <p style={{ fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--rust)", marginBottom: "10px" }}>Marketplace</p>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "clamp(32px, 5vw, 52px)", fontWeight: 800, color: "white", margin: "0 0 10px", letterSpacing: "-0.03em", lineHeight: 1.1 }}>{title}</h1>
          <p style={{ fontSize: "15px", color: "oklch(72% 0.01 70)", maxWidth: "460px", lineHeight: 1.6, margin: 0 }}>{tagline}</p>
        </div>
      </div>

      {infoBanner && (
        <div style={{ background: "var(--cream-mid)", borderBottom: "1px solid var(--sand)" }}>
          <div className="site-shell" style={{ paddingTop: "11px", paddingBottom: "11px" }}>
            <p style={{ margin: 0, color: "var(--text-mid)", fontSize: "12px", lineHeight: 1.5 }}>{infoBanner}</p>
          </div>
        </div>
      )}

      <div className="browse-filter-sticky stagger-item" style={{ "--i": 1 } as CSSProperties}>
        <div className="browse-filter-inner">
          <div className="browse-filter-row">
            <div className="browse-pills-group">
              <button onClick={() => setActiveTags([])} style={{ padding: "7px 18px", borderRadius: "20px", fontSize: "13px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", fontWeight: 500, transition: "all 0.2s", background: activeTags.length === 0 ? "var(--rust)" : "transparent", border: `1px solid ${activeTags.length === 0 ? "var(--rust)" : "var(--sand)"}`, color: activeTags.length === 0 ? "white" : "var(--text-mid)", whiteSpace: "nowrap" }}>
                {allLabel}
              </button>
              {topTags.map((tag) => {
                const active = activeTags.includes(tag);
                const label = tag.charAt(0).toUpperCase() + tag.slice(1).replace(/-/g, " ");
                return (
                  <button key={tag} onClick={() => toggleTag(tag)} style={{ padding: "7px 18px", borderRadius: "20px", fontSize: "13px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", fontWeight: 500, transition: "all 0.2s", background: active ? "var(--rust)" : "transparent", border: `1px solid ${active ? "var(--rust)" : "var(--sand)"}`, color: active ? "white" : "var(--text-mid)", whiteSpace: "nowrap" }}>
                    {label}
                  </button>
                );
              })}
            </div>
          </div>
          <div className="browse-filter-row">
            <div className="browse-filter-spacer" />
            <div style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0 }}>
              <span style={{ fontSize: "13px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Sort</span>
              <div style={{ position: "relative" }}>
                <select value={sort} onChange={(event) => setSort(event.target.value)} style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 28px 5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none" }}>
                  {SORT_OPTIONS.map((option) => <option key={option}>{option}</option>)}
                </select>
                <svg style={{ position: "absolute", right: "8px", top: "50%", transform: "translateY(-50%)", pointerEvents: "none" }} width="10" height="6" viewBox="0 0 10 6"><path d="M1 1l4 4 4-4" stroke="var(--text-light)" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
              </div>
            </div>
            <div style={{ width: "1px", height: "20px", background: "var(--sand)", flexShrink: 0 }} />
            <div style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0 }}>
              <span style={{ fontSize: "13px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Price</span>
              <div style={{ position: "relative" }}>
                <select value={priceRange} onChange={(event) => setPriceRange(event.target.value)} style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 28px 5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none" }}>
                  {PRICE_RANGES.map((range) => <option key={range}>{range}</option>)}
                </select>
                <svg style={{ position: "absolute", right: "8px", top: "50%", transform: "translateY(-50%)", pointerEvents: "none" }} width="10" height="6" viewBox="0 0 10 6"><path d="M1 1l4 4 4-4" stroke="var(--text-light)" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="site-shell" style={{ paddingTop: "48px", paddingBottom: "80px" }}>
        {loading ? (
          <>
            <div style={{ marginBottom: "48px" }}>
              <div className="skeleton-block" style={{ width: "160px", height: "22px", marginBottom: "24px" }} />
              <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "20px" }}>
                {[0, 1, 2].map((index) => <div key={index} className="skeleton-block" style={{ height: "330px", borderRadius: "12px" }} />)}
              </div>
            </div>
            <div className="skeleton-block" style={{ width: "140px", height: "20px", marginBottom: "20px" }} />
            <div className="standard-category-grid">
              {Array.from({ length: 10 }).map((_, index) => <div key={index} className="skeleton-block" style={{ height: "230px" }} />)}
            </div>
          </>
        ) : filtered.length === 0 ? (
          <div style={{ textAlign: "center", padding: "80px 0", color: "var(--text-light)" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "24px", marginBottom: "8px" }}>{emptyLabel}</p>
            <p style={{ fontSize: "14px" }}>Try a different filter</p>
          </div>
        ) : (
          <>
            {hasFeatured && (
              <div style={{ marginBottom: "56px" }}>
                <SectionHeading>{featuredLabel}</SectionHeading>
                <div className="standard-category-featured-grid">
                  {featuredItems.map((item, index) => (
                    <div key={item.id} className="stagger-item" style={{ "--i": index } as CSSProperties}>
                      <FeaturedCard item={item} />
                    </div>
                  ))}
                </div>
              </div>
            )}
            {gridItems.length > 0 && (
              <div>
                <SectionHeading count={filtered.length}>{allLabel}</SectionHeading>
                <div className="standard-category-grid">
                  {gridItems.map((item, index) => (
                    <div key={item.id} className="stagger-item" style={{ "--i": Math.min(index, 9) } as CSSProperties}>
                      <ListingCard item={item} />
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>

      <Footer />

      <style>{`
        .standard-category-featured-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; align-items: stretch; }
        .standard-category-featured-grid > .stagger-item { height: 100%; }
        .standard-category-featured-link { display: block; height: 100%; }
        .standard-category-featured-card { display: flex; flex-direction: column; height: 100%; }
        .standard-category-featured-image { position: relative; width: 100%; aspect-ratio: 4 / 3; overflow: hidden; flex-shrink: 0; isolation: isolate; }
        .standard-category-featured-image-element { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; display: block; }
        .standard-category-featured-content { display: flex; flex-direction: column; flex: 1; min-height: 0; }
        .standard-category-featured-price-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: auto; flex-wrap: wrap; }
        .standard-category-featured-price { min-width: 0; overflow-wrap: anywhere; }
        .standard-category-featured-condition { flex-shrink: 0; }
        .standard-category-featured-seller-row { display: flex; align-items: center; gap: 5px; min-width: 0; }
        .standard-category-featured-seller-handle { min-width: 0; overflow-wrap: anywhere; }
        .standard-category-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 16px; }
        @media (max-width: 1024px) { .standard-category-grid { grid-template-columns: repeat(4, 1fr); } }
        @media (max-width: 768px) {
          .standard-category-featured-grid { grid-template-columns: repeat(2, 1fr); gap: 12px; }
          .standard-category-grid { grid-template-columns: repeat(2, 1fr); gap: 10px; }
        }
      `}</style>
    </div>
  );
}
