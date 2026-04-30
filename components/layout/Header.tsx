"use client";

import { useState, useEffect } from "react";
import Image from "next/image";
import Link from "next/link";

const CATEGORIES = ["Apparel", "Art & Decor", "Jewellery", "Music", "Tickets", "Vintage", "New Arrivals"];

export default function Header() {
  const [scrolled, setScrolled] = useState(false);
  const [query, setQuery] = useState("");
  const [searchFocused, setSearchFocused] = useState(false);
  const [leftOpen, setLeftOpen] = useState(false);
  const [rightOpen, setRightOpen] = useState(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 150);
    window.addEventListener("scroll", handler, { passive: true });
    return () => window.removeEventListener("scroll", handler);
  }, []);

  useEffect(() => {
    document.body.style.overflow = leftOpen || rightOpen ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [leftOpen, rightOpen]);

  const closeAll = () => { setLeftOpen(false); setRightOpen(false); };

  const SearchBar = ({ autoFocus }: { autoFocus?: boolean }) => (
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
        autoFocus={autoFocus}
        style={{ border: "none", outline: "none", background: "transparent", fontSize: "14px", color: "white", width: "100%", fontFamily: "Manrope, var(--font-manrope)" }}
      />
      {query && (
        <button onClick={() => setQuery("")} style={{ background: "transparent", border: "none", color: "oklch(55% 0.01 70)", cursor: "pointer", fontSize: "16px", lineHeight: 1, padding: 0, flexShrink: 0 }}>
          ×
        </button>
      )}
    </div>
  );

  return (
    <>
      <div style={{ position: "sticky", top: 0, zIndex: 1000 }}>
        <div style={{ background: "#000", borderBottom: "1px solid oklch(100% 0 0 / 0.12)" }}>
          <div className="site-shell header-topbar">
            <div className="header-logo">
              <Link href="/">
                <Image src="/logo.png" alt="psy.market" width={130} height={52} priority style={{ height: "52px", width: "auto", maxWidth: "100%", display: "block" }} />
              </Link>
            </div>

            <div className="header-search-wrap">
              <SearchBar />
            </div>

            <div className="header-auth-links">
              <Link href="/login" className="header-auth-secondary">Log In</Link>
              <Link href="/signup" className="header-auth-primary">Sign Up</Link>
            </div>

            <button className="header-ham header-ham-left" onClick={() => { setLeftOpen(true); setRightOpen(false); }} aria-label="Open categories">
              <HamIcon />
            </button>

            <div className="header-logo-mobile">
              <Link href="/">
                <Image src="/logo.png" alt="psy.market" width={130} height={52} priority style={{ height: "52px", width: "auto", maxWidth: "100%", display: "block" }} />
              </Link>
            </div>

            <button className="header-ham header-ham-right" onClick={() => { setRightOpen(true); setLeftOpen(false); }} aria-label="Open menu">
              <HamIcon />
            </button>
          </div>
        </div>

        <div className="header-catbar" style={{ minHeight: "56px", background: "oklch(15% 0.02 55)", borderBottom: "1px solid oklch(100% 0 0 / 0.09)", boxShadow: scrolled ? "0 4px 24px oklch(0% 0 0 / 0.45)" : "none", transition: "box-shadow 0.35s ease" }}>
          <div className="site-shell header-categories">
            {CATEGORIES.map((cat) => (
              <Link key={cat} href="/browse" className="header-category-link">{cat}</Link>
            ))}
          </div>
        </div>
      </div>

      {(leftOpen || rightOpen) && (
        <div onClick={closeAll} style={{ position: "fixed", inset: 0, background: "oklch(0% 0 0 / 0.6)", zIndex: 1100 }} />
      )}

      <div className={`mobile-drawer mobile-drawer-left${leftOpen ? " open" : ""}`}>
        <div className="mobile-drawer-header">
          <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "17px", fontWeight: 700, color: "white" }}>Categories</span>
          <button onClick={closeAll} className="mobile-drawer-close">✕</button>
        </div>
        <nav style={{ padding: "8px 0" }}>
          {CATEGORIES.map((cat) => (
            <Link key={cat} href="/browse" onClick={closeAll} className="mobile-drawer-link">{cat}</Link>
          ))}
        </nav>
      </div>

      <div className={`mobile-drawer mobile-drawer-right${rightOpen ? " open" : ""}`}>
        <div className="mobile-drawer-header">
          <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "17px", fontWeight: 700, color: "white" }}>Search</span>
          <button onClick={closeAll} className="mobile-drawer-close">✕</button>
        </div>
        <div style={{ padding: "0 20px 24px" }}>
          <SearchBar autoFocus={rightOpen} />
        </div>
        <div style={{ padding: "0 20px", display: "flex", flexDirection: "column", gap: "10px" }}>
          <Link href="/login" onClick={closeAll} className="mobile-auth-btn mobile-auth-secondary">Log In</Link>
          <Link href="/signup" onClick={closeAll} className="mobile-auth-btn mobile-auth-primary">Sign Up</Link>
        </div>
      </div>
    </>
  );
}

function HamIcon() {
  return (
    <svg width="22" height="16" viewBox="0 0 22 16" fill="none">
      <rect y="0" width="22" height="2" rx="1" fill="white" />
      <rect y="7" width="22" height="2" rx="1" fill="white" />
      <rect y="14" width="22" height="2" rx="1" fill="white" />
    </svg>
  );
}
