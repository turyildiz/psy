"use client";

import { useState } from "react";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import { mockListings } from "@/lib/mock-data";
import { conditionLabels } from "@/lib/constants";
import type { Listing } from "@/types/marketplace";

const CLOTHING = mockListings.filter((l) => l.category === "clothing");

const SUBCAT_TAG: Record<string, string> = {
  Hoodies: "hoodie",
  Tees: "tee",
  Jackets: "jacket",
  Pants: "pants",
  Dresses: "dress",
};

const SUBCATS = ["All", "Hoodies", "Tees", "Jackets", "Pants", "Dresses"];
const SORT_OPTIONS = ["Newest First", "Price: Low to High", "Price: High to Low"];
const PRICE_RANGES = ["Any Price", "Under €50", "€50–€100", "€100–€200", "€200+"];

const CONDITION_COLORS: Record<string, string> = {
  new: "#5a7c4a",
  like_new: "#4a7c6a",
  good: "#8b6914",
  worn: "#7a5a3a",
  vintage: "#7a4a90",
};

/* ── Product Card ── */

function ProductCard({ item }: { item: Listing }) {
  const [hov, setHov] = useState(false);
  const badge = item.isFeatured ? "Featured" : item.condition === "vintage" ? "Vintage" : null;
  const condColor = CONDITION_COLORS[item.condition] || "var(--text-light)";

  return (
    <Link
      href={`/listing/${item.id}`}
      style={{ textDecoration: "none", display: "flex", flexDirection: "column" }}
    >
      <div
        style={{
          background: "var(--white)",
          borderRadius: "10px",
          overflow: "hidden",
          border: "1px solid var(--sand)",
          cursor: "pointer",
          display: "flex",
          flexDirection: "column",
          boxShadow: hov ? "0 12px 36px oklch(35% 0.06 55 / 0.14)" : "0 2px 8px oklch(0% 0 0 / 0.06)",
          transform: hov ? "translateY(-4px)" : "none",
          transition: "all 0.3s ease",
        }}
        onMouseEnter={() => setHov(true)}
        onMouseLeave={() => setHov(false)}
      >
        <div style={{ position: "relative", overflow: "hidden" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={item.images[0]}
            style={{
              width: "100%",
              height: "260px",
              objectFit: "cover",
              display: "block",
              transition: "transform 0.5s",
              transform: hov ? "scale(1.05)" : "scale(1)",
            }}
            alt={item.title}
          />
          {badge && (
            <span
              style={{
                position: "absolute",
                top: "10px",
                left: "10px",
                background: badge === "Featured" ? "var(--rust)" : "#7a4a90",
                color: "white",
                fontSize: "9px",
                padding: "3px 8px",
                borderRadius: "3px",
                fontWeight: 700,
                letterSpacing: "0.08em",
                textTransform: "uppercase",
              }}
            >
              {badge}
            </span>
          )}
          {hov && (
            <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, padding: "12px", background: "linear-gradient(to top, oklch(0% 0 0 / 0.5), transparent)" }}>
              <span
                style={{
                  display: "block",
                  width: "100%",
                  background: "white",
                  padding: "9px",
                  borderRadius: "6px",
                  fontSize: "12px",
                  fontWeight: 700,
                  fontFamily: "Manrope, var(--font-manrope)",
                  letterSpacing: "0.04em",
                  color: "var(--dark)",
                  textAlign: "center",
                }}
              >
                VIEW LISTING
              </span>
            </div>
          )}
        </div>
        <div style={{ padding: "13px 14px 15px", flex: 1, display: "flex", flexDirection: "column", gap: "4px" }}>
          <p style={{ fontSize: "10px", color: "var(--text-light)", letterSpacing: "0.08em", textTransform: "uppercase" }}>{item.size}</p>
          <p style={{ fontSize: "14px", fontWeight: 500, color: "var(--text)", lineHeight: 1.3, flex: 1 }}>{item.title}</p>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: "6px" }}>
            <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "18px", fontWeight: 700, color: "var(--rust)" }}>
              €{(item.priceCents / 100).toFixed(0)}
            </span>
            <span
              style={{
                fontSize: "10px",
                padding: "2px 8px",
                borderRadius: "3px",
                background: `${condColor}18`,
                color: condColor,
                fontWeight: 600,
                letterSpacing: "0.04em",
              }}
            >
              {conditionLabels[item.condition]}
            </span>
          </div>
        </div>
      </div>
    </Link>
  );
}

/* ── Page ── */

export default function BrowsePage() {
  const [subcats, setSubcats] = useState<string[]>([]);
  const [sort, setSort] = useState("Newest First");
  const [priceRange, setPriceRange] = useState("Any Price");
  const [gridCols, setGridCols] = useState(4);

  const toggleSubcat = (s: string) => {
    if (s === "All") { setSubcats([]); return; }
    setSubcats((prev) =>
      prev.includes(s) ? prev.filter((x) => x !== s) : [...prev, s]
    );
  };

  const filtered = CLOTHING.filter((p) => {
    if (subcats.length > 0 && !subcats.some((s) => p.tags.includes(SUBCAT_TAG[s]))) return false;
    const price = p.priceCents / 100;
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

  const activeFilters = [
    ...subcats,
    priceRange !== "Any Price" && priceRange,
  ].filter(Boolean) as string[];

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Filter bar */}
      <div className="browse-filter-sticky">
        <div className="browse-filter-inner">
          {/* Subcategory pills — own row on mobile */}
          <div className="browse-pills-group">
            {SUBCATS.map((s) => {
              const active = s === "All" ? subcats.length === 0 : subcats.includes(s);
              return (
                <button
                  key={s}
                  onClick={() => toggleSubcat(s)}
                  style={{
                    padding: "5px 14px",
                    borderRadius: "20px",
                    fontSize: "12px",
                    cursor: "pointer",
                    fontFamily: "Manrope, var(--font-manrope)",
                    fontWeight: 500,
                    transition: "all 0.2s",
                    background: active ? "var(--dark)" : "transparent",
                    border: `1px solid ${active ? "var(--dark)" : "var(--sand)"}`,
                    color: active ? "white" : "var(--text-mid)",
                    whiteSpace: "nowrap",
                  }}
                >
                  {s}
                </button>
              );
            })}
          </div>

          <div className="browse-divider" style={{ width: "1px", height: "20px", background: "var(--sand)", flexShrink: 0 }} />

          {/* Sort */}
          <div style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0 }}>
            <span style={{ fontSize: "12px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Sort</span>
            <div style={{ position: "relative" }}>
              <select
                value={sort}
                onChange={(e) => setSort(e.target.value)}
                style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 28px 5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none" }}
              >
                {SORT_OPTIONS.map((o) => <option key={o}>{o}</option>)}
              </select>
              <svg style={{ position: "absolute", right: "8px", top: "50%", transform: "translateY(-50%)", pointerEvents: "none" }} width="10" height="6" viewBox="0 0 10 6">
                <path d="M1 1l4 4 4-4" stroke="var(--text-light)" strokeWidth="1.5" fill="none" strokeLinecap="round" />
              </svg>
            </div>
          </div>

          <div className="browse-divider" style={{ width: "1px", height: "20px", background: "var(--sand)" }} />

          {/* Price — pills on desktop, select on mobile */}
          <div className="browse-price-pills-wrap" style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0 }}>
            <span style={{ fontSize: "12px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Price</span>
            <div style={{ display: "flex", gap: "6px" }}>
              {PRICE_RANGES.map((r) => (
                <button
                  key={r}
                  onClick={() => setPriceRange(r)}
                  style={{
                    padding: "4px 12px",
                    borderRadius: "5px",
                    fontSize: "12px",
                    cursor: "pointer",
                    fontFamily: "Manrope, var(--font-manrope)",
                    transition: "all 0.2s",
                    background: priceRange === r ? "var(--dark)" : "transparent",
                    border: `1px solid ${priceRange === r ? "var(--dark)" : "var(--sand)"}`,
                    color: priceRange === r ? "white" : "var(--text-mid)",
                  }}
                >
                  {r}
                </button>
              ))}
            </div>
          </div>

          <div className="browse-price-select-wrap">
            <span style={{ fontSize: "12px", color: "var(--text-light)", letterSpacing: "0.04em", textTransform: "uppercase" }}>Price</span>
            <div style={{ position: "relative" }}>
              <select
                value={priceRange}
                onChange={(e) => setPriceRange(e.target.value)}
                style={{ background: "transparent", border: "1px solid var(--sand)", borderRadius: "6px", padding: "5px 28px 5px 10px", fontSize: "13px", color: "var(--text)", fontFamily: "Manrope, var(--font-manrope)", cursor: "pointer", outline: "none" }}
              >
                {PRICE_RANGES.map((r) => <option key={r}>{r}</option>)}
              </select>
              <svg style={{ position: "absolute", right: "8px", top: "50%", transform: "translateY(-50%)", pointerEvents: "none" }} width="10" height="6" viewBox="0 0 10 6">
                <path d="M1 1l4 4 4-4" stroke="var(--text-light)" strokeWidth="1.5" fill="none" strokeLinecap="round" />
              </svg>
            </div>
          </div>

          <div className="browse-filter-spacer" />

          {/* Active filter chips */}
          {activeFilters.length > 0 && (
            <div style={{ display: "flex", gap: "6px", alignItems: "center" }}>
              {activeFilters.map((f) => (
                <span
                  key={f}
                  style={{ display: "flex", alignItems: "center", gap: "5px", background: "oklch(92% 0.04 55)", border: "1px solid oklch(82% 0.06 55)", borderRadius: "4px", padding: "3px 8px", fontSize: "11px", color: "var(--rust)", fontWeight: 600 }}
                >
                  {f}
                  <button
                    onClick={() => {
                      if (SUBCATS.includes(f)) setSubcats((prev) => prev.filter((x) => x !== f));
                      else setPriceRange("Any Price");
                    }}
                    style={{ background: "none", border: "none", cursor: "pointer", color: "var(--rust)", fontSize: "14px", lineHeight: 1, padding: 0 }}
                  >
                    ×
                  </button>
                </span>
              ))}
              <button
                onClick={() => { setSubcats([]); setPriceRange("Any Price"); }}
                style={{ fontSize: "11px", color: "var(--text-light)", background: "none", border: "none", cursor: "pointer", textDecoration: "underline" }}
              >
                Clear all
              </button>
            </div>
          )}

          {/* Grid toggle — desktop only */}
          <div className="browse-grid-toggle" style={{ display: "flex", alignItems: "center", gap: "12px", flexShrink: 0 }}>
            <div style={{ display: "flex", gap: "4px" }}>
              {[4, 3].map((n) => (
                <button
                  key={n}
                  onClick={() => setGridCols(n)}
                  style={{ width: "28px", height: "28px", borderRadius: "5px", border: `1px solid ${gridCols === n ? "var(--dark)" : "var(--sand)"}`, background: gridCols === n ? "var(--dark)" : "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: "2px" }}
                >
                  {Array.from({ length: n }).map((_, i) => (
                    <div key={i} style={{ width: "3px", height: "12px", background: gridCols === n ? "white" : "var(--sand)", borderRadius: "1px" }} />
                  ))}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Product grid */}
      <div className="browse-content">
        <div style={{ display: "flex", alignItems: "baseline", gap: "12px", marginBottom: "24px", flexWrap: "wrap" }}>
          <p style={{ fontSize: "11px", color: "var(--text-light)", letterSpacing: "0.08em", textTransform: "uppercase" }}>
            <Link href="/" style={{ color: "var(--text-light)", textDecoration: "none" }}>Home</Link>
            {" → Apparel"}
          </p>
          <div style={{ width: "1px", height: "12px", background: "var(--sand)" }} />
          <h1 style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "20px", fontWeight: 700, color: "var(--text)", letterSpacing: "-0.02em", margin: 0 }}>
            Festival Fashion
          </h1>
          <span style={{ fontSize: "12px", color: "var(--text-light)" }}>{filtered.length} results</span>
        </div>
        {filtered.length === 0 ? (
          <div style={{ textAlign: "center", padding: "80px 0", color: "var(--text-light)" }}>
            <p style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "24px", marginBottom: "8px" }}>No listings found</p>
            <p style={{ fontSize: "14px" }}>Try adjusting your filters</p>
          </div>
        ) : (
          <div className="browse-grid" style={{ gridTemplateColumns: `repeat(${gridCols}, 1fr)` }}>
            {filtered.map((item) => <ProductCard key={item.id} item={item} />)}
          </div>
        )}

        {filtered.length > 0 && (
          <div style={{ textAlign: "center", marginTop: "56px" }}>
            <button
              style={{ background: "transparent", border: "1.5px solid var(--dark)", color: "var(--dark)", padding: "13px 40px", borderRadius: "8px", fontSize: "14px", fontWeight: 600, cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)", letterSpacing: "0.02em", transition: "all 0.2s" }}
            >
              Load More
            </button>
          </div>
        )}
      </div>

      <Footer />
    </div>
  );
}
