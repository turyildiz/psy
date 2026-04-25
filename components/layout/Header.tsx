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
      {/* Top bar: Logo + Search + Auth */}
      <div style={{ background: "#000", borderBottom: "1px solid oklch(100% 0 0 / 0.12)" }}>
        <div
          style={{
            maxWidth: "1320px",
            margin: "0 auto",
            padding: "0 40px",
            height: "120px",
            display: "grid",
            gridTemplateColumns: "1fr auto 1fr",
            alignItems: "center",
            gap: "24px",
          }}
        >
          <div>
            <Link href="/">
              <Image
                src="/logo.png"
                alt="psy.market"
                width={156}
                height={62}
                priority
                style={{ height: "62px", width: "auto" }}
              />
            </Link>
          </div>

          <div style={{ width: "480px" }}>
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
                style={{
                  border: "none",
                  outline: "none",
                  background: "transparent",
                  fontSize: "14px",
                  color: "white",
                  width: "100%",
                  fontFamily: "Manrope, var(--font-manrope)",
                }}
              />
              {query && (
                <button
                  onClick={() => setQuery("")}
                  style={{ background: "transparent", border: "none", color: "oklch(55% 0.01 70)", cursor: "pointer", fontSize: "16px", lineHeight: 1, padding: 0, flexShrink: 0 }}
                >
                  ×
                </button>
              )}
            </div>
          </div>

          <div style={{ display: "flex", gap: "10px", justifyContent: "flex-end" }}>
            <Link
              href="/login"
              style={{
                background: "transparent",
                border: "1px solid oklch(100% 0 0 / 0.22)",
                color: "white",
                padding: "9px 20px",
                borderRadius: "7px",
                fontSize: "13px",
                fontFamily: "Manrope, var(--font-manrope)",
                fontWeight: 500,
                textDecoration: "none",
                transition: "all 0.2s",
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = "oklch(100% 0 0 / 0.08)";
                e.currentTarget.style.borderColor = "oklch(100% 0 0 / 0.4)";
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = "transparent";
                e.currentTarget.style.borderColor = "oklch(100% 0 0 / 0.22)";
              }}
            >
              Log In
            </Link>
            <Link
              href="/signup"
              style={{
                background: "var(--rust)",
                border: "none",
                color: "white",
                padding: "9px 22px",
                borderRadius: "7px",
                fontSize: "13px",
                fontFamily: "Manrope, var(--font-manrope)",
                fontWeight: 600,
                textDecoration: "none",
                transition: "background 0.2s",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.background = "var(--rust-dim)")}
              onMouseLeave={(e) => (e.currentTarget.style.background = "var(--rust)")}
            >
              Sign Up
            </Link>
          </div>
        </div>
      </div>

      {/* Category nav bar */}
      <div
        style={{
          height: "56px",
          background: "oklch(15% 0.02 55)",
          borderBottom: "1px solid oklch(100% 0 0 / 0.09)",
          boxShadow: scrolled ? "0 4px 24px oklch(0% 0 0 / 0.45)" : "none",
          transition: "box-shadow 0.35s ease",
        }}
      >
        <div
          style={{
            maxWidth: "1320px",
            margin: "0 auto",
            padding: "0 40px",
            height: "100%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: "28px",
          }}
        >
          {CATEGORIES.map((cat) => (
            <Link
              key={cat}
              href="/browse"
              style={{
                color: "oklch(68% 0.01 70)",
                fontSize: "13px",
                textDecoration: "none",
                fontWeight: 400,
                letterSpacing: "0.005em",
                whiteSpace: "nowrap",
                transition: "color 0.2s",
              }}
              onMouseEnter={(e) => (e.currentTarget.style.color = "white")}
              onMouseLeave={(e) => (e.currentTarget.style.color = "oklch(68% 0.01 70)")}
            >
              {cat}
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
