"use client";

import { useState, useEffect, type CSSProperties } from "react";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import ProfileAvatar from "@/components/ProfileAvatar";
import CategoryFilterToolbar from "@/components/CategoryFilterToolbar";
import FeaturedCategoryRail from "@/components/FeaturedCategoryRail";
import ScrollToTopButton from "@/components/ScrollToTopButton";
import PageHero from "@/components/PageHero";
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

const SORT_OPTIONS = ["Newest First", "Price: Low to High", "Price: High to Low"];
const PRICE_RANGES = ["Any Price", "Under €50", "€50–€100", "€100–€200", "€200+"];

function FeaturedCard({ item }: { item: Listing }) {
  const [hov, setHov] = useState(false);
  const condColor = CONDITION_COLORS[item.condition] || "var(--text-light)";
  return (
    <Link href={`/listing/${item.id}`} className="jewellery-featured-link" style={{ textDecoration: "none" }}>
      <div
        className="jewellery-featured-card"
        style={{ background: "var(--white)", borderRadius: "12px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hov ? "0 16px 48px oklch(35% 0.06 55 / 0.18)" : "0 4px 14px oklch(0% 0 0 / 0.08)", transform: hov ? "translateY(-5px)" : "none", transition: "all 0.3s ease" }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div className="jewellery-featured-image">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="jewellery-featured-image-element" src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} style={{ transition: "transform 0.55s ease", transform: hov ? "scale(1.04)" : "scale(1)" }} />
          <span style={{ position: "absolute", top: "12px", left: "12px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "4px 10px", borderRadius: "4px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>
            Featured
          </span>
        </div>
        <div className="jewellery-featured-content" style={{ padding: "16px 18px 20px" }}>
          <p className="jewellery-featured-title" style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3 }}>{item.title}</p>
          {item.description && (
            <p className="jewellery-featured-description" style={{ fontSize: "12px", color: "var(--text-light)", marginBottom: "12px", lineHeight: 1.5, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2 } as CSSProperties}>
              {item.description}
            </p>
          )}
          <div className="jewellery-featured-price-row">
            <p className="jewellery-featured-price" style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "22px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
              {formatPrice(item.priceCents)}
            </p>
            <span className="jewellery-featured-condition" style={{ fontSize: "10px", padding: "2px 8px", borderRadius: "4px", background: `${condColor}18`, color: condColor, fontWeight: 600 }}>
              {conditionLabels[item.condition]}
            </span>
          </div>
          {item.sellerHandle && (
            <div className="jewellery-featured-seller-row" style={{ marginTop: "10px", paddingTop: "10px", borderTop: "1px solid var(--sand)" }}>
              <ProfileAvatar name={item.sellerName || item.sellerHandle} url={item.sellerAvatar} size={20} />
              <span className="jewellery-featured-seller-handle" style={{ fontSize: "11px", color: "var(--text-light)" }}>@{item.sellerHandle}</span>
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}

function JewelleryCard({ item }: { item: Listing }) {
  const [hov, setHov] = useState(false);
  const condColor = CONDITION_COLORS[item.condition] || "var(--text-light)";
  return (
    <Link href={`/listing/${item.id}`} className="jewellery-card-link" style={{ textDecoration: "none" }}>
      <div
        className="jewellery-card"
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hov ? "0 10px 28px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hov ? "translateY(-3px)" : "none", transition: "all 0.25s ease" }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div className="jewellery-card-image">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="jewellery-card-image-element" src={item.images[0] || "/listing-placeholder.webp"} onError={(event) => { event.currentTarget.onerror = null; event.currentTarget.src = "/listing-placeholder.webp"; }} alt={item.title} style={{ transition: "transform 0.5s ease", transform: hov ? "scale(1.05)" : "scale(1)" }} />
        </div>
        <div className="jewellery-card-content" style={{ padding: "11px 13px 14px" }}>
          <p className="jewellery-card-title" style={{ fontSize: "12px", fontWeight: 500, color: "var(--text)", marginBottom: "4px", lineHeight: 1.3 }}>{item.title}</p>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "6px" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "15px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
              {formatPrice(item.priceCents)}
            </p>
            <span style={{ fontSize: "9px", padding: "2px 6px", borderRadius: "4px", background: `${condColor}18`, color: condColor, fontWeight: 600 }}>
              {conditionLabels[item.condition]}
            </span>
          </div>
          {item.sellerHandle && (
            <div style={{ display: "flex", alignItems: "center", gap: "4px", paddingTop: "6px", borderTop: "1px solid var(--sand)" }}>
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

export default function JewelleryPage() {
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
    supabase.from("listings").select("*, profiles(handle, display_name, avatar_url)").eq("category", "accessories").eq("status", "active")
      .then(({ data }) => { setAllListings((data ?? []).map(toListing)); setLoading(false); });
  }, []);

  const topTags = Object.entries(
    allListings.flatMap((l) => l.tags).reduce<Record<string, number>>((acc, t) => {
      acc[t] = (acc[t] ?? 0) + 1; return acc;
    }, {})
  ).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([tag]) => tag);

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

  const featuredItems = filtered.filter((l) => l.isFeatured);
  const hasFeatured = featuredItems.length >= 2;
  const featuredIds = new Set(featuredItems.map((l) => l.id));
  const gridItems = hasFeatured ? filtered.filter((l) => !featuredIds.has(l.id)) : filtered;

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Hero */}
      <PageHero
        imageSrc="https://images.psy.market/accessories/ai-generated/1780512099588.jpg"
        objectPosition="50% center"
        eyebrow="Marketplace"
        title="Jewellery & Accessories"
        description="Handcrafted pendants, crystals, wire-wraps and sacred adornments for the festival soul."
      />

      {/* Filter bar */}
      <CategoryFilterToolbar
        allLabel="All Jewellery"
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
      <div className="site-shell" style={{ paddingTop: "48px", paddingBottom: "80px" }}>
        {loading ? (
          <>
            <div style={{ marginBottom: "48px" }}>
              <div className="skeleton-block" style={{ width: "160px", height: "22px", marginBottom: "24px" }} />
              <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "20px" }}>
                {[0, 1, 2].map((i) => <div key={i} className="skeleton-block" style={{ height: "380px", borderRadius: "12px" }} />)}
              </div>
            </div>
            <div className="skeleton-block" style={{ width: "140px", height: "20px", marginBottom: "20px" }} />
            <div className="jewellery-grid">
              {Array.from({ length: 8 }).map((_, i) => <div key={i} className="skeleton-block" style={{ height: "270px" }} />)}
            </div>
          </>
        ) : filtered.length === 0 ? (
          <div style={{ textAlign: "center", padding: "80px 0", color: "var(--text-light)" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "24px", marginBottom: "8px" }}>No items found</p>
            <p style={{ fontSize: "14px" }}>Try a different filter</p>
          </div>
        ) : (
          <>
            {hasFeatured && (
              <div style={{ marginBottom: "56px" }}>
                <SectionHeading>Featured Pieces</SectionHeading>
                <FeaturedCategoryRail className="jewellery-featured-grid" itemCount={featuredItems.length} label="Featured Pieces">
                  {featuredItems.map((item, i) => (
                    <div key={item.id} className="stagger-item" style={{ '--i': i } as CSSProperties}>
                      <FeaturedCard item={item} />
                    </div>
                  ))}
                </FeaturedCategoryRail>
              </div>
            )}
            {gridItems.length > 0 && (
              <div>
                <SectionHeading count={filtered.length}>All Jewellery & Accessories</SectionHeading>
                <div className="jewellery-grid">
                  {gridItems.map((item, i) => (
                    <div key={item.id} className="stagger-item" style={{ '--i': Math.min(i, 9) } as CSSProperties}>
                      <JewelleryCard item={item} />
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>

      <Footer />
      <ScrollToTopButton />

      <style>{`
        .jewellery-featured-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; align-items: stretch; }
        .jewellery-featured-grid > .stagger-item { height: 100%; }
        .jewellery-featured-link { display: block; height: 100%; }
        .jewellery-featured-card { display: flex; flex-direction: column; height: 100%; }
        .jewellery-featured-image { position: relative; width: 100%; aspect-ratio: 4 / 3; overflow: hidden; flex-shrink: 0; isolation: isolate; }
        .jewellery-featured-image-element { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; display: block; }
        .jewellery-featured-content { display: flex; flex-direction: column; flex: 1; min-height: 0; }
        .jewellery-featured-price-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: auto; flex-wrap: wrap; }
        .jewellery-featured-price { min-width: 0; overflow-wrap: anywhere; }
        .jewellery-featured-condition { flex-shrink: 0; }
        .jewellery-featured-seller-row { display: flex; align-items: center; gap: 5px; min-width: 0; }
        .jewellery-featured-seller-handle { min-width: 0; overflow-wrap: anywhere; }
        .jewellery-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); column-gap: 24px; row-gap: 26px; align-items: stretch; }
        .jewellery-grid > .stagger-item { min-width: 0; height: 100%; }
        .jewellery-card-link { display: block; height: 100%; }
        .jewellery-card { display: flex; flex-direction: column; height: 100%; }
        .jewellery-card-image { position: relative; width: 100%; aspect-ratio: 1; overflow: hidden; flex-shrink: 0; }
        .jewellery-card-image-element { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; display: block; }
        .jewellery-card-content { display: flex; flex: 1; flex-direction: column; }
        .jewellery-card-title { min-height: 2.6em; overflow: hidden; display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
        @media (max-width: 1180px) { .jewellery-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
        @media (max-width: 860px) { .jewellery-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
        @media (max-width: 768px) {
          .jewellery-featured-grid { display: flex; gap: 12px; overflow-x: auto; overscroll-behavior-inline: contain; scroll-snap-type: x mandatory; scrollbar-width: none; }
          .jewellery-featured-grid::-webkit-scrollbar { display: none; }
          .jewellery-featured-grid > .stagger-item { flex: 0 0 80vw; max-width: 80vw; scroll-snap-align: start; scroll-snap-stop: always; }
        }
        @media (max-width: 640px) { .jewellery-grid { column-gap: 10px; row-gap: 14px; } }
        @media (max-width: 379px) { .jewellery-grid { grid-template-columns: minmax(0, 1fr); } }
      `}</style>
    </div>
  );
}
