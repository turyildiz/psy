"use client";

import { useState, useEffect, type CSSProperties } from "react";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import ProfileAvatar from "@/components/ProfileAvatar";
import CategoryFilterToolbar from "@/components/CategoryFilterToolbar";
import { conditionLabels } from "@/lib/constants";
import type { Listing } from "@/types/marketplace";
import { createClient } from "@/lib/supabase/client";
import { toListing } from "@/lib/db";
import { formatPrice } from "@/lib/listings/price";

const CONDITION_COLORS: Record<string, string> = {
  new: "#5a7c4a",
  like_new: "#4a7c6a",
  good: "#8b6914",
  worn: "#7a5a3a",
  vintage: "#7a4a90",
};

function FeaturedCard({ item }: { item: Listing }) {
  const [hov, setHov] = useState(false);
  const condColor = CONDITION_COLORS[item.condition] || "var(--text-light)";
  return (
    <Link href={`/listing/${item.id}`} className="music-featured-link" style={{ textDecoration: "none" }}>
      <div
        className="music-featured-card"
        style={{ background: "var(--white)", borderRadius: "12px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hov ? "0 16px 48px oklch(35% 0.06 55 / 0.18)" : "0 4px 14px oklch(0% 0 0 / 0.08)", transform: hov ? "translateY(-5px)" : "none", transition: "all 0.3s ease" }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div className="music-featured-image">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="music-featured-image-element" src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} style={{ transition: "transform 0.55s ease", transform: hov ? "scale(1.04)" : "scale(1)" }} />
          <span style={{ position: "absolute", top: "12px", left: "12px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "4px 10px", borderRadius: "4px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>
            Featured
          </span>
        </div>
        <div className="music-featured-content" style={{ padding: "16px 18px 20px" }}>
          <p className="music-featured-title" style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3 }}>{item.title}</p>
          {item.description && (
            <p className="music-featured-description" style={{ fontSize: "12px", color: "var(--text-light)", marginBottom: "12px", lineHeight: 1.5, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2 } as CSSProperties}>
              {item.description}
            </p>
          )}
          <div className="music-featured-price-row">
            <p className="music-featured-price" style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "22px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
              {formatPrice(item.priceCents)}
            </p>
            <span className="music-featured-condition" style={{ fontSize: "10px", padding: "2px 8px", borderRadius: "4px", background: `${condColor}18`, color: condColor, fontWeight: 600 }}>
              {conditionLabels[item.condition]}
            </span>
          </div>
          {item.sellerHandle && (
            <div className="music-featured-seller-row" style={{ marginTop: "10px", paddingTop: "10px", borderTop: "1px solid var(--sand)" }}>
              <ProfileAvatar name={item.sellerName || item.sellerHandle} url={item.sellerAvatar} size={20} />
              <span className="music-featured-seller-handle" style={{ fontSize: "11px", color: "var(--text-light)" }}>@{item.sellerHandle}</span>
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}

function GearCard({ item }: { item: Listing }) {
  const [hov, setHov] = useState(false);
  return (
    <Link href={`/listing/${item.id}`} className="music-gear-card-link" style={{ textDecoration: "none" }}>
      <div
        className="music-gear-card"
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hov ? "0 10px 28px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hov ? "translateY(-3px)" : "none", transition: "all 0.25s ease" }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div className="music-gear-card-image">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} className="music-gear-card-image-element" style={{ transition: "transform 0.5s ease", transform: hov ? "scale(1.05)" : "scale(1)" }} />
        </div>
        <div className="music-gear-card-content" style={{ padding: "11px 13px 14px" }}>
          <p className="music-gear-card-title" style={{ fontSize: "12px", fontWeight: 500, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3 }}>{item.title}</p>
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
      {count !== undefined && (
        <span style={{ fontSize: "13px", color: "var(--text-light)" }}>{count} items</span>
      )}
    </div>
  );
}

const SORT_OPTIONS = ["Newest First", "Price: Low to High", "Price: High to Low"];
const PRICE_RANGES = ["Any Price", "Under €50", "€50–€100", "€100–€200", "€200+"];

export default function MusicPage() {
  const [allListings, setAllListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTags, setActiveTags] = useState<string[]>([]);
  const [sort, setSort] = useState("Newest First");
  const [priceRange, setPriceRange] = useState("Any Price");

  const toggleTag = (tag: string) => {
    setActiveTags((prev) => prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag]);
  };

  useEffect(() => {
    const supabase = createClient();
    supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "gear").eq("status", "active")
      .then(({ data }) => { setAllListings((data ?? []).map(toListing)); setLoading(false); });
  }, []);

  // Compute top 8 tags by frequency across all listings
  const topTags = Object.entries(
    allListings.flatMap((l) => l.tags).reduce<Record<string, number>>((acc, t) => {
      acc[t] = (acc[t] ?? 0) + 1;
      return acc;
    }, {})
  )
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([tag]) => tag);

  const filtered = allListings.filter((l) => {
    if (activeTags.length > 0 && !activeTags.some((t) => l.tags.includes(t))) return false;
    const price = l.priceCents / 100;
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

  const featuredItems = filtered.filter((l) => l.isFeatured).slice(0, 3);
  const hasFeatured = featuredItems.length >= 2;
  const featuredIds = new Set(featuredItems.map((l) => l.id));
  const gridItems = hasFeatured ? filtered.filter((l) => !featuredIds.has(l.id)) : filtered;

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Hero */}
      <div className="category-photo-hero" style={{ position: "relative", background: "var(--dark)", overflow: "hidden", display: "flex", alignItems: "center" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/music-hero.jpg" alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: "50% center", opacity: 1 }} />
        <div className="category-photo-hero-overlay" style={{ position: "absolute", inset: 0, background: "linear-gradient(to right, oklch(10% 0.01 55 / 0.96) 0%, oklch(10% 0.01 55 / 0.82) 55%, oklch(10% 0.01 55 / 0.64) 100%)" }} />
        <div className="stagger-item site-shell category-photo-hero-text" style={{ '--i': 0, position: "relative", zIndex: 1 } as CSSProperties}>
          <p className="category-photo-hero-eyebrow" style={{ fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--rust)" }}>
            Marketplace
          </p>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "clamp(32px, 5vw, 52px)", fontWeight: 800, color: "white", margin: 0, letterSpacing: "-0.03em", lineHeight: 1.1 }}>
            Music Gear
          </h1>
          <p className="category-photo-hero-description" style={{ fontSize: "15px", color: "white", maxWidth: "420px", lineHeight: 1.6 }}>
            Explore synths, controllers, and everything you need to shape your sound.
          </p>
        </div>
      </div>

      {/* Filter bar */}
      <CategoryFilterToolbar
        allLabel="All Gear"
        tags={topTags.map((tag) => ({ value: tag, label: tag.charAt(0).toUpperCase() + tag.slice(1).replace(/-/g, " ") }))}
        activeTags={activeTags}
        onClearTags={() => setActiveTags([])}
        onToggleTag={toggleTag}
        sort={sort}
        sortOptions={SORT_OPTIONS}
        onSortChange={setSort}
        priceRange={priceRange}
        priceOptions={PRICE_RANGES}
        onPriceChange={setPriceRange}
        style={{ '--i': 1 } as CSSProperties}
      />
      {/* Content */}
      <div className="site-shell music-content" style={{ paddingTop: "48px", paddingBottom: "80px" }}>
        {loading ? (
          <>
            <div style={{ marginBottom: "48px" }}>
              <div className="skeleton-block" style={{ width: "160px", height: "22px", marginBottom: "24px" }} />
              <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "20px" }}>
                {[0, 1, 2].map((i) => <div key={i} className="skeleton-block" style={{ height: "330px", borderRadius: "12px" }} />)}
              </div>
            </div>
            <div className="skeleton-block" style={{ width: "140px", height: "20px", marginBottom: "20px" }} />
            <div className="music-gear-grid">
              {Array.from({ length: 10 }).map((_, i) => <div key={i} className="skeleton-block" style={{ height: "230px" }} />)}
            </div>
          </>
        ) : filtered.length === 0 ? (
          <div style={{ textAlign: "center", padding: "80px 0", color: "var(--text-light)" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "24px", marginBottom: "8px" }}>No gear found</p>
            <p style={{ fontSize: "14px" }}>Try a different filter</p>
          </div>
        ) : (
          <>
            {hasFeatured && (
              <div style={{ marginBottom: "56px" }}>
                <SectionHeading>Featured Gear</SectionHeading>
                <div className="music-featured-grid" tabIndex={0} aria-label="Featured Gear — swipe to browse">
                  {featuredItems.map((item, i) => (
                    <div key={item.id} className="stagger-item" style={{ '--i': i } as CSSProperties}>
                      <FeaturedCard item={item} />
                    </div>
                  ))}
                </div>
              </div>
            )}

            {gridItems.length > 0 && (
              <div>
                <SectionHeading count={filtered.length}>All Music Gear</SectionHeading>
                <div className="music-gear-grid">
                  {gridItems.map((item, i) => (
                    <div key={item.id} className="stagger-item" style={{ '--i': Math.min(i, 9) } as CSSProperties}>
                      <GearCard item={item} />
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
        .category-photo-hero { width: 100%; height: 200px; }
        .category-photo-hero-text { width: 100%; padding-top: 20px; padding-bottom: 20px; }
        .category-photo-hero-eyebrow { margin: 0 0 10px; }
        .category-photo-hero-description { margin: 10px 0 0; text-shadow: 0 1px 3px oklch(0% 0 0 / 0.72); }
        .music-featured-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; align-items: stretch; }
        .music-featured-grid > .stagger-item { height: 100%; }
        .music-featured-link { display: block; height: 100%; }
        .music-featured-card { display: flex; flex-direction: column; height: 100%; }
        .music-featured-image { position: relative; width: 100%; aspect-ratio: 4 / 3; overflow: hidden; flex-shrink: 0; isolation: isolate; }
        .music-featured-image-element { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; display: block; }
        .music-featured-content { display: flex; flex-direction: column; flex: 1; min-height: 0; }
        .music-featured-price-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: auto; flex-wrap: wrap; }
        .music-featured-price { min-width: 0; overflow-wrap: anywhere; }
        .music-featured-condition { flex-shrink: 0; }
        .music-featured-seller-row { display: flex; align-items: center; gap: 5px; min-width: 0; }
        .music-featured-seller-handle { min-width: 0; overflow-wrap: anywhere; }
        .music-gear-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); column-gap: 24px; row-gap: 26px; align-items: stretch; }
        .music-gear-grid > .stagger-item { min-width: 0; height: 100%; }
        .music-gear-card-link { display: block; height: 100%; }
        .music-gear-card { display: flex; flex-direction: column; height: 100%; }
        .music-gear-card-image { position: relative; width: 100%; aspect-ratio: 1; overflow: hidden; flex-shrink: 0; }
        .music-gear-card-image-element { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; display: block; }
        .music-gear-card-content { display: flex; flex: 1; flex-direction: column; }
        .music-gear-card-title { min-height: 2.6em; overflow: hidden; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
        @media (max-width: 1180px) { .music-gear-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
        @media (max-width: 860px) { .music-gear-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
        @media (max-width: 768px) {
          .music-featured-grid { display: flex; gap: 12px; overflow-x: auto; overscroll-behavior-inline: contain; scroll-snap-type: x mandatory; scrollbar-width: none; }
          .music-featured-grid::-webkit-scrollbar { display: none; }
          .music-featured-grid > .stagger-item { flex: 0 0 80vw; max-width: 80vw; scroll-snap-align: start; scroll-snap-stop: always; }
        }
        @media (max-width: 640px) { .category-photo-hero { height: 130px; } .category-photo-hero-text { padding-top: 0; padding-bottom: 0; } .category-photo-hero-eyebrow { margin-bottom: 0; } .category-photo-hero-description { margin-top: 0; } .music-gear-grid { column-gap: 10px; row-gap: 14px; } }
        @media (max-width: 379px) { .music-gear-grid { grid-template-columns: minmax(0, 1fr); } }
      `}</style>
    </div>
  );
}
