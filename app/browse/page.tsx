"use client";

import { useState } from "react";
import Link from "next/link";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";

/* ── Placeholder data (replaced by Supabase queries later) ── */

const ALL_PRODUCTS = [
  { id: 1,  name: "Fractal Geometry Hoodie", cat: "Hoodies",  price: 99,  seed: "hoodie881",  badge: "Hot",      condition: "Like New" },
  { id: 2,  name: "Sacred Geometry Tee",     cat: "Tees",     price: 45,  seed: "tee7722",    badge: null,       condition: "New" },
  { id: 3,  name: "Psydelic Flow Jacket",    cat: "Jackets",  price: 135, seed: "jacket9933", badge: "New",      condition: "Good" },
  { id: 4,  name: "Cosmic Cargo Pants",      cat: "Pants",    price: 72,  seed: "cargo1244",  badge: null,       condition: "Like New" },
  { id: 5,  name: "Tribal Wrap Dress",       cat: "Dresses",  price: 88,  seed: "dress7755",  badge: null,       condition: "Good" },
  { id: 6,  name: "UV Reactive Hoodie",      cat: "Hoodies",  price: 115, seed: "uvhood6",    badge: "Hot",      condition: "New" },
  { id: 7,  name: "Festival Kimono",         cat: "Dresses",  price: 78,  seed: "kimono7",    badge: null,       condition: "Worn" },
  { id: 8,  name: "Mandala Print Tee",       cat: "Tees",     price: 38,  seed: "mandalatee8",badge: null,       condition: "Good" },
  { id: 9,  name: "Flow Arts Leggings",      cat: "Pants",    price: 65,  seed: "leggings9",  badge: "New",      condition: "Like New" },
  { id: 10, name: "Shaman Cloak",            cat: "Jackets",  price: 185, seed: "cloak10",    badge: "Rare",     condition: "Vintage" },
  { id: 11, name: "Rave Crop Top",           cat: "Tees",     price: 32,  seed: "croptop11",  badge: null,       condition: "Good" },
  { id: 12, name: "Sacred Patchwork Jacket", cat: "Jackets",  price: 148, seed: "patchjack12",badge: "Handmade", condition: "New" },
  { id: 13, name: "Holographic Shorts",      cat: "Pants",    price: 55,  seed: "shorts13",   badge: null,       condition: "Like New" },
  { id: 14, name: "Boho Maxi Dress",         cat: "Dresses",  price: 96,  seed: "maxi14",     badge: null,       condition: "Good" },
  { id: 15, name: "Geometric Bomber",        cat: "Jackets",  price: 160, seed: "bomber15",   badge: "New",      condition: "New" },
  { id: 16, name: "Forest Spirit Hoodie",    cat: "Hoodies",  price: 108, seed: "forest16",   badge: null,       condition: "Like New" },
];

const SUBCATS = ["All", "Hoodies", "Tees", "Jackets", "Pants", "Dresses"];
const SORT_OPTIONS = ["Newest First", "Price: Low to High", "Price: High to Low"];
const PRICE_RANGES = ["Any Price", "Under €50", "€50–€100", "€100–€200", "€200+"];

const BADGE_COLORS: Record<string, string> = {
  Hot: "var(--rust)",
  New: "#5a7c4a",
  Rare: "#7a4a90",
  Handmade: "#8b6914",
};

const CONDITION_COLORS: Record<string, string> = {
  New: "#5a7c4a",
  "Like New": "#4a7c6a",
  Good: "#8b6914",
  Worn: "#7a5a3a",
  Vintage: "#7a4a90",
};

/* ── Product Card ── */

function ProductCard({ item }: { item: (typeof ALL_PRODUCTS)[number] }) {
  const [hov, setHov] = useState(false);

  return (
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
          src={`https://picsum.photos/seed/${item.seed}/480/520`}
          style={{
            width: "100%",
            height: "260px",
            objectFit: "cover",
            display: "block",
            transition: "transform 0.5s",
            transform: hov ? "scale(1.05)" : "scale(1)",
          }}
          alt={item.name}
        />
        {item.badge && (
          <span
            style={{
              position: "absolute",
              top: "10px",
              left: "10px",
              background: BADGE_COLORS[item.badge] || "var(--rust)",
              color: "white",
              fontSize: "9px",
              padding: "3px 8px",
              borderRadius: "3px",
              fontWeight: 700,
              letterSpacing: "0.08em",
              textTransform: "uppercase",
            }}
          >
            {item.badge}
          </span>
        )}
        {hov && (
          <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, padding: "12px", background: "linear-gradient(to top, oklch(0% 0 0 / 0.5), transparent)" }}>
            <Link
              href={`/listing/${item.id}`}
              style={{
                display: "block",
                width: "100%",
                background: "white",
                border: "none",
                padding: "9px",
                borderRadius: "6px",
                fontSize: "12px",
                fontWeight: 700,
                cursor: "pointer",
                fontFamily: "Manrope, var(--font-manrope)",
                letterSpacing: "0.04em",
                color: "var(--dark)",
                textDecoration: "none",
                textAlign: "center",
              }}
            >
              VIEW LISTING
            </Link>
          </div>
        )}
      </div>
      <div style={{ padding: "13px 14px 15px", flex: 1, display: "flex", flexDirection: "column", gap: "4px" }}>
        <p style={{ fontSize: "10px", color: "var(--text-light)", letterSpacing: "0.08em", textTransform: "uppercase" }}>{item.cat}</p>
        <p style={{ fontSize: "14px", fontWeight: 500, color: "var(--text)", lineHeight: 1.3, flex: 1 }}>{item.name}</p>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: "6px" }}>
          <span
            style={{
              fontFamily: "'Bricolage Grotesque', var(--font-bricolage)",
              fontSize: "18px",
              fontWeight: 700,
              color: "var(--rust)",
            }}
          >
            €{item.price}
          </span>
          <span
            style={{
              fontSize: "10px",
              padding: "2px 8px",
              borderRadius: "3px",
              background: `${CONDITION_COLORS[item.condition]}18`,
              color: CONDITION_COLORS[item.condition],
              fontWeight: 600,
              letterSpacing: "0.04em",
            }}
          >
            {item.condition}
          </span>
        </div>
      </div>
    </div>
  );
}

/* ── Page ── */

export default function BrowsePage() {
  const [subcat, setSubcat] = useState("All");
  const [sort, setSort] = useState("Newest First");
  const [priceRange, setPriceRange] = useState("Any Price");
  const [gridCols, setGridCols] = useState(4);

  const filtered = ALL_PRODUCTS.filter((p) => {
    if (subcat !== "All" && p.cat !== subcat) return false;
    if (priceRange === "Under €50" && p.price >= 50) return false;
    if (priceRange === "€50–€100" && (p.price < 50 || p.price > 100)) return false;
    if (priceRange === "€100–€200" && (p.price < 100 || p.price > 200)) return false;
    if (priceRange === "€200+" && p.price < 200) return false;
    return true;
  }).sort((a, b) => {
    if (sort === "Price: Low to High") return a.price - b.price;
    if (sort === "Price: High to Low") return b.price - a.price;
    return 0;
  });

  const activeFilters = [
    subcat !== "All" && subcat,
    priceRange !== "Any Price" && priceRange,
  ].filter(Boolean) as string[];

  return (
    <div style={{ background: "var(--cream)", minHeight: "100vh" }}>
      <Header />

      {/* Filter bar */}
      <div style={{ background: "var(--white)", borderBottom: "1px solid var(--sand)", position: "sticky", top: "176px", zIndex: 100 }}>
        <div style={{ maxWidth: "1320px", margin: "0 auto", padding: "0 40px", height: "56px", display: "flex", alignItems: "center", gap: "16px" }}>
          {/* Subcategory pills */}
          <div style={{ display: "flex", gap: "6px", flexShrink: 0 }}>
            {SUBCATS.map((s) => (
              <button
                key={s}
                onClick={() => setSubcat(s)}
                style={{
                  padding: "5px 14px",
                  borderRadius: "20px",
                  fontSize: "12px",
                  cursor: "pointer",
                  fontFamily: "Manrope, var(--font-manrope)",
                  fontWeight: 500,
                  transition: "all 0.2s",
                  background: subcat === s ? "var(--dark)" : "transparent",
                  border: `1px solid ${subcat === s ? "var(--dark)" : "var(--sand)"}`,
                  color: subcat === s ? "white" : "var(--text-mid)",
                }}
              >
                {s}
              </button>
            ))}
          </div>

          <div style={{ width: "1px", height: "20px", background: "var(--sand)", flexShrink: 0 }} />

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

          <div style={{ width: "1px", height: "20px", background: "var(--sand)" }} />

          {/* Price */}
          <div style={{ display: "flex", alignItems: "center", gap: "8px", flexShrink: 0 }}>
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

          <div style={{ flex: 1 }} />

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
                      if (SUBCATS.includes(f)) setSubcat("All");
                      else setPriceRange("Any Price");
                    }}
                    style={{ background: "none", border: "none", cursor: "pointer", color: "var(--rust)", fontSize: "14px", lineHeight: 1, padding: 0 }}
                  >
                    ×
                  </button>
                </span>
              ))}
              <button
                onClick={() => { setSubcat("All"); setPriceRange("Any Price"); }}
                style={{ fontSize: "11px", color: "var(--text-light)", background: "none", border: "none", cursor: "pointer", textDecoration: "underline" }}
              >
                Clear all
              </button>
            </div>
          )}

          {/* Grid toggle */}
          <div style={{ display: "flex", alignItems: "center", gap: "12px", flexShrink: 0 }}>
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
      <div style={{ maxWidth: "1320px", margin: "0 auto", padding: "32px 40px 80px" }}>
        <div style={{ display: "flex", alignItems: "baseline", gap: "12px", marginBottom: "24px" }}>
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
          <div style={{ display: "grid", gridTemplateColumns: `repeat(${gridCols}, 1fr)`, gap: "20px" }}>
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
