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
          <img src={item.images[0]} alt={item.title} style={{ width: "100%", height: "260px", objectFit: "cover", display: "block", transition: "transform 0.55s ease", transform: hov ? "scale(1.04)" : "scale(1)" }} />
          <span style={{ position: "absolute", top: "12px", left: "12px", background: "var(--rust)", color: "white", fontSize: "9px", padding: "4px 10px", borderRadius: "4px", fontWeight: 700, letterSpacing: "0.08em", textTransform: "uppercase" }}>
            Featured
          </span>
        </div>
        <div style={{ padding: "16px 18px 20px" }}>
          <p style={{ fontSize: "14px", fontWeight: 600, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3 }}>{item.title}</p>
          {item.description && (
            <p style={{ fontSize: "12px", color: "var(--text-light)", marginBottom: "12px", lineHeight: 1.5, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2 } as CSSProperties}>
              {item.description}
            </p>
          )}
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

function GearCard({ item }: { item: Listing }) {
  const [hov, setHov] = useState(false);
  return (
    <Link href={`/listing/${item.id}`} style={{ textDecoration: "none", display: "block" }}>
      <div
        style={{ background: "var(--white)", borderRadius: "10px", overflow: "hidden", border: "1px solid var(--sand)", boxShadow: hov ? "0 10px 28px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)", transform: hov ? "translateY(-3px)" : "none", transition: "all 0.25s ease" }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div style={{ overflow: "hidden" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={item.images[0]} alt={item.title} className="gear-card-img" style={{ width: "100%", height: "180px", objectFit: "cover", display: "block", transition: "transform 0.5s ease", transform: hov ? "scale(1.05)" : "scale(1)" }} />
        </div>
        <div style={{ padding: "11px 13px 14px" }}>
          <p style={{ fontSize: "12px", fontWeight: 500, color: "var(--text)", marginBottom: "5px", lineHeight: 1.3, overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>{item.title}</p>
          <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "15px", fontWeight: 700, color: "var(--rust)", margin: 0 }}>
            €{(item.priceCents / 100).toFixed(0)}
          </p>
          {item.sellerHandle && (
            <div style={{ display: "flex", alignItems: "center", gap: "4px", marginTop: "6px", paddingTop: "6px", borderTop: "1px solid var(--sand)" }}>
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

export default function MusicPage() {
  const [allListings, setAllListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTag, setActiveTag] = useState<string | null>(null);

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

  const filtered = activeTag
    ? allListings.filter((l) => l.tags.includes(activeTag))
    : allListings;

  const featuredItems = filtered.filter((l) => l.isFeatured).slice(0, 3);
  const hasFeatured = featuredItems.length >= 2;
  const gridItems = hasFeatured ? filtered.filter((l) => !l.isFeatured) : filtered;

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh", overflowX: "hidden" }}>
      <Header />

      {/* Hero */}
      <div style={{ position: "relative", background: "var(--dark)", overflow: "hidden", minHeight: "300px", display: "flex", alignItems: "center" }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/music-hero.jpg" alt="" aria-hidden style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", objectPosition: "60% center", opacity: 1 }} />
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to right, oklch(10% 0.01 55 / 0.92) 0%, oklch(10% 0.01 55 / 0.6) 45%, oklch(10% 0.01 55 / 0.05) 100%)" }} />
        <div className="stagger-item site-shell music-hero-text" style={{ '--i': 0, position: "relative", zIndex: 1, paddingTop: "52px", paddingBottom: "52px" } as CSSProperties}>
          <p style={{ fontSize: "11px", fontWeight: 600, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--rust)", marginBottom: "10px" }}>
            Marketplace
          </p>
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "clamp(32px, 5vw, 52px)", fontWeight: 800, color: "white", margin: "0 0 10px", letterSpacing: "-0.03em", lineHeight: 1.1 }}>
            Music Gear
          </h1>
          <p style={{ fontSize: "15px", color: "oklch(72% 0.01 70)", maxWidth: "420px", lineHeight: 1.6, margin: 0 }}>
            Explore synths, controllers, and everything you need to shape your sound.
          </p>
        </div>
      </div>

      {/* Filter bar */}
      <div className="stagger-item" style={{ '--i': 1, background: "var(--white)", borderBottom: "1px solid var(--sand)" } as CSSProperties}>
        <div className="site-shell" style={{ paddingTop: 0, paddingBottom: 0, display: "flex", alignItems: "center", gap: "8px", overflowX: "auto", scrollbarWidth: "none" }}>
          <span style={{ fontSize: "11px", fontWeight: 600, color: "var(--text-light)", letterSpacing: "0.06em", textTransform: "uppercase", flexShrink: 0, paddingTop: "16px", paddingBottom: "16px", paddingRight: "4px" }}>
            Filter by:
          </span>
          {/* All Gear */}
          <button
            onClick={() => setActiveTag(null)}
            style={{ padding: "6px 16px", borderRadius: "20px", border: activeTag === null ? "none" : "1.5px solid var(--sand)", background: activeTag === null ? "var(--rust)" : "transparent", color: activeTag === null ? "white" : "var(--text-mid)", fontSize: "13px", fontWeight: activeTag === null ? 600 : 400, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", flexShrink: 0, transition: "all 0.15s" }}
          >
            All Gear
          </button>
          {topTags.map((tag) => {
            const active = tag === activeTag;
            const label = tag.charAt(0).toUpperCase() + tag.slice(1).replace(/-/g, " ");
            return (
              <button
                key={tag}
                onClick={() => setActiveTag(tag)}
                style={{ padding: "6px 16px", borderRadius: "20px", border: active ? "none" : "1.5px solid var(--sand)", background: active ? "var(--rust)" : "transparent", color: active ? "white" : "var(--text-mid)", fontSize: "13px", fontWeight: active ? 600 : 400, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", flexShrink: 0, transition: "all 0.15s", whiteSpace: "nowrap" }}
              >
                {label}
              </button>
            );
          })}
        </div>
      </div>

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
                <div className="music-featured-grid">
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
                <SectionHeading count={gridItems.length}>All Music Gear</SectionHeading>
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
        .music-featured-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; }
        .music-gear-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 16px; }
        @media (max-width: 1024px) { .music-gear-grid { grid-template-columns: repeat(4, 1fr); } }
        @media (max-width: 768px) {
          .music-featured-grid { grid-template-columns: repeat(2, 1fr); gap: 12px; }
          .music-gear-grid { grid-template-columns: repeat(2, 1fr); gap: 10px; }
        }
      `}</style>
    </div>
  );
}
