"use client";

import { useState, useEffect, type CSSProperties } from "react";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import { conditionLabels } from "@/lib/constants";
import type { Listing } from "@/types/marketplace";
import { createClient } from "@/lib/supabase/client";
import { toListing } from "@/lib/db";

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
    <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "block" }}>
      <div
        style={{ background: "var(--white)", borderRadius: "12px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hov ? "0 16px 48px oklch(35% 0.06 55 / 0.18)" : "0 4px 14px oklch(0% 0 0 / 0.08)", transform: hov ? "translateY(-5px)" : "none", transition: "all 0.3s ease" }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div style={{ position: "relative", overflow: "hidden" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0]} alt={item.title} style={{ width: "100%", height: "320px", objectFit: "cover", display: "block", transition: "transform 0.55s ease", transform: hov ? "scale(1.04)" : "scale(1)" }} />
          <span style={{ position: "absolute", top: "12px", left: "12px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "4px 10px", borderRadius: "4px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>
            Featured
          </span>
        </div>
        <div style={{ padding: "16px 18px 20px" }}>
          <p style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3 }}>{item.title}</p>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "22px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
              €{(item.priceCents / 100).toFixed(0)}
            </p>
            <span style={{ fontSize: "10px", padding: "2px 8px", borderRadius: "4px", background: `${condColor}18`, color: condColor, fontWeight: 600 }}>
              {conditionLabels[item.condition]}
            </span>
          </div>
          {item.sellerHandle && (
            <div style={{ display: "flex", alignItems: "center", gap: "5px", marginTop: "10px", paddingTop: "10px", borderTop: "1px solid var(--sand)" }}>
              {item.sellerAvatar
                ? <img src={item.sellerAvatar} alt="" style={{ width: "20px", height: "20px", borderRadius: "50%", objectFit: "cover", flexShrink: 0 }} />
                : <div style={{ width: "20px", height: "20px", borderRadius: "50%", background: "var(--rust)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "9px", fontWeight: 700, color: "white", flexShrink: 0 }}>{(item.sellerName || item.sellerHandle).charAt(0).toUpperCase()}</div>
              }
              <span style={{ fontSize: "11px", color: "var(--text-light)" }}>@{item.sellerHandle}</span>
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
    <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "block" }}>
      <div
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hov ? "0 10px 28px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hov ? "translateY(-3px)" : "none", transition: "all 0.25s ease" }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div style={{ overflow: "hidden" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0]} alt={item.title} style={{ width: "100%", height: "220px", objectFit: "cover", display: "block", transition: "transform 0.5s ease", transform: hov ? "scale(1.05)" : "scale(1)" }} />
        </div>
        <div style={{ padding: "11px 13px 14px" }}>
          <p style={{ fontSize: "12px", fontWeight: 500, color: "var(--text)", marginBottom: "4px", lineHeight: 1.3, overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>{item.title}</p>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "6px" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "15px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
              €{(item.priceCents / 100).toFixed(0)}
            </p>
            <span style={{ fontSize: "9px", padding: "2px 6px", borderRadius: "4px", background: `${condColor}18`, color: condColor, fontWeight: 600 }}>
              {conditionLabels[item.condition]}
            </span>
          </div>
          {item.sellerHandle && (
            <div style={{ display: "flex", alignItems: "center", gap: "4px", paddingTop: "6px", borderTop: "1px solid var(--sand)" }}>
              {item.sellerAvatar
                ? <img src={item.sellerAvatar} alt="" style={{ width: "16px", height: "16px", borderRadius: "50%", objectFit: "cover", flexShrink: 0 }} />
                : <div style={{ width: "16px", height: "16px", borderRadius: "50%", background: "var(--rust)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "8px", fontWeight: 700, color: "white", flexShrink: 0 }}>{(item.sellerName || item.sellerHandle).charAt(0).toUpperCase()}</div>
              }
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

  const featuredItems = filtered.filter((l) => l.isFeatured).slice(0, 3);
  const hasFeatured = featuredItems.length >= 2;
  const featuredIds = new Set(featuredItems.map((l) => l.id));
  const gridItems = hasFeatured ? filtered.filter((l) => !featuredIds.has(l.id)) : filtered;

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Hero */}
      <div style={{ position: "relative", background: "var(--dark)", overflow: "hidden", minHeight: "300px", display: "flex", alignItems: "center" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="https://images.psy.market/accessories/ai-generated/1780512099588.jpg" alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: "50% 40%", opacity: 1 }} />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to right, oklch(10% 0.01 55 / 0.92) 0%, oklch(10% 0.01 55 / 0.6) 45%, oklch(10% 0.01 55 / 0.05) 100%)" }} />
        <div className="stagger-item site-shell" style={{ '--i': 0, position: "relative", zIndex: 1, paddingTop: "52px", paddingBottom: "52px" } as CSSProperties}>
          <p style={{ fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--rust)", marginBottom: "10px" }}>
            Marketplace
          </p>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "clamp(32px, 5vw, 52px)", fontWeight: 800, color: "white", margin: "0 0 10px", letterSpacing: "-0.03em", lineHeight: 1.1 }}>
            Jewellery & Accessories
          </h1>
          <p style={{ fontSize: "15px", color: "oklch(72% 0.01 70)", maxWidth: "420px", lineHeight: 1.6, margin: 0 }}>
            Handcrafted pendants, crystals, wire-wraps and sacred adornments for the festival soul.
          </p>
        </div>
      </div>

      {/* Filter bar */}
      <div className="browse-filter-sticky stagger-item" style={{ '--i': 1 } as CSSProperties}>
        <div className="browse-filter-inner">
          <div className="browse-filter-row">
            <div className="browse-pills-group">
              <button onClick={() => setActiveTags([])} style={{ padding: "7px 18px", borderRadius: "20px", fontSize: "13px", cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", fontWeight: 500, transition: "all 0.2s", background: activeTags.length === 0 ? "var(--rust)" : "transparent", border: `1px solid ${activeTags.length === 0 ? "var(--rust)" : "var(--sand)"}`, color: activeTags.length === 0 ? "white" : "var(--text-mid)", whiteSpace: "nowrap" }}>
                All Jewellery
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
                <select value={sort} onChange={(e) => setSort(e.target.value)} style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 28px 5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none" }}>
                  {SORT_OPTIONS.map((o) => <option key={o}>{o}</option>)}
                </select>
                <svg style={{ position: "absolute", right: "8px", top: "50%", transform: "translateY(-50%)", pointerEvents: "none" }} width="10" height="6" viewBox="0 0 10 6"><path d="M1 1l4 4 4-4" stroke="var(--text-light)" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
              </div>
            </div>
            <div style={{ width: "1px", height: "20px", background: "var(--sand)", flexShrink: 0 }} />
            <div style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0 }}>
              <span style={{ fontSize: "13px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Price</span>
              <div style={{ position: "relative" }}>
                <select value={priceRange} onChange={(e) => setPriceRange(e.target.value)} style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 28px 5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none" }}>
                  {PRICE_RANGES.map((r) => <option key={r}>{r}</option>)}
                </select>
                <svg style={{ position: "absolute", right: "8px", top: "50%", transform: "translateY(-50%)", pointerEvents: "none" }} width="10" height="6" viewBox="0 0 10 6"><path d="M1 1l4 4 4-4" stroke="var(--text-light)" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
              </div>
            </div>
          </div>
        </div>
      </div>

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
                <div className="jewellery-featured-grid">
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

      <style>{`
        .jewellery-featured-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
        .jewellery-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 16px; }
        @media (max-width: 1024px) { .jewellery-grid { grid-template-columns: repeat(4, 1fr); } }
        @media (max-width: 768px) {
          .jewellery-featured-grid { grid-template-columns: repeat(2, 1fr); gap: 12px; }
          .jewellery-grid { grid-template-columns: repeat(2, 1fr); gap: 10px; }
        }
      `}</style>
    </div>
  );
}
