"use client";

import { useState, useEffect } from "react";
import Image from "next/image";
import Link from "next/link";

const CATEGORIES = ["Apparel", "Art & Decor", "Jewellery", "Music", "Tickets", "Vintage", "New Arrivals"];

export default function Header() {
  const [scrolled, setScrolled] = useState(false);
  const [query, setQuery] = useState("");
  const [searchFocused, setSearchFocused] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 150);
    window.addEventListener("scroll", handler, { passive: true });
    return () => window.removeEventListener("scroll", handler);
  }, []);

  return (
    <div style={{ position: "sticky", top: 0, zIndex: 1000 }}>
      <div style={{ background: "#000", borderBottom: "1px solid oklch(100% 0 0 / 0.12)" }}>
        <div className="site-shell header-topbar">
          <div>
            <Link href="/">
              <Image src="/logo.png" alt="psy.market" width={156} height={62} priority style={{ height: "62px", width: "auto", maxWidth: "100%" }} />
            </Link>
          </div>

          <div className="header-search-wrap">
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: "10px",
                background: searchFocused ? "oklch(100% 0 0 / 0.12)" : "oklch(100% 0 0 / 0.07)",
                border: `1px solid ${searchFocused ? "oklch(100% 0 0 / 0.35)" : "oklch(100% 0 0 / 0.14)"}`,
                borderRadius: "8px",
                padding: "11px 16px",
                transition: "all 0.25s",
              }}
            >
              <svg width="15" height="15" viewBox="0 0 15 15" fill="none" style={{ flexShrink: 0 }}>
                <circle cx="6.5" cy="6.5" r="5" stroke="oklch(65% 0.01 70)" strokeWidth="1.4" />
                <line x1="10.5" y1="10.5" x2="13.5" y2="13.5" stroke="oklch(65% 0.01 70)" strokeWidth="1.4" strokeLinecap="round" />
              </svg>
              <input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                onFocus={() => setSearchFocused(true)}
                onBlur={() => setSearchFocused(false)}
                placeholder="Search apparel, art, gear, tickets…"
                style={{ border: "none", outline: "none", background: "transparent", fontSize: "14px", color: "white", width: "100%", fontFamily: "Manrope, var(--font-manrope)" }}
              />
              {query && (
                <button onClick={() => setQuery("")} style={{ background: "transparent", border: "none", color: "oklch(55% 0.01 70)", cursor: "pointer", fontSize: "16px", lineHeight: 1, padding: 0, flexShrink: 0 }}>
                  ×
                </button>
              )}
            </div>
          </div>

          <div className="header-auth-links">
            <Link href="/login" className="header-auth-secondary">Log In</Link>
            <Link href="/signup" className="header-auth-primary">Sign Up</Link>
          </div>
        </div>
      </div>

      <div
        style={{
          minHeight: "56px",
          background: "oklch(15% 0.02 55)",
          borderBottom: "1px solid oklch(100% 0 0 / 0.09)",
          boxShadow: scrolled ? "0 4px 24px oklch(0% 0 0 / 0.45)" : "none",
          transition: "box-shadow 0.35s ease",
        }}
      >
        <div className="site-shell header-categories">
          {CATEGORIES.map((cat) => (
            <Link key={cat} href="/browse" className="header-category-link">
              {cat}
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
