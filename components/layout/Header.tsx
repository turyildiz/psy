"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter, usePathname } from "next/navigation";
import Image from "next/image";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import AuthModal from "@/components/AuthModal";

const CATEGORIES = [
  { label: "Apparel", href: "/browse" },
  { label: "Art & Decor", href: "/browse" },
  { label: "Jewellery", href: "/browse" },
  { label: "Music", href: "/music" },
  { label: "Tickets", href: "/browse" },
  { label: "Vintage", href: "/browse" },
  { label: "New Arrivals", href: "/browse" },
];

const QUICK_LINKS = [
  { label: "Apparel", href: "/browse", icon: "👕" },
  { label: "Music Gear", href: "/music", icon: "🎹" },
  { label: "Jewellery", href: "/browse", icon: "💎" },
  { label: "Tickets", href: "/browse", icon: "🎪" },
  { label: "Vintage", href: "/browse", icon: "✨" },
  { label: "New Arrivals", href: "/browse", icon: "🆕" },
];

export default function Header() {
  const router = useRouter();
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [leftOpen, setLeftOpen] = useState(false);
  const [rightOpen, setRightOpen] = useState(false);
  const [userHandle, setUserHandle] = useState<string | null>(null);
  const [userInitial, setUserInitial] = useState<string>("");
  const [userAvatar, setUserAvatar] = useState<string | null>(null);
  const [loggingOut, setLoggingOut] = useState(false);
  const [authModal, setAuthModal] = useState<"login" | "signup" | null>(null);
  const [authLoading, setAuthLoading] = useState(true);
  const searchInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    try {
      const cached = sessionStorage.getItem("psy_auth");
      if (cached) {
        const { handle, initial, avatar } = JSON.parse(cached);
        setUserHandle(handle);
        setUserInitial(initial);
        setUserAvatar(avatar ?? null);
        setAuthLoading(false);
      }
    } catch {}

    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) {
        sessionStorage.removeItem("psy_auth");
        setUserHandle(null);
        setUserInitial("");
        setUserAvatar(null);
        setAuthLoading(false);
        return;
      }
      const { data: profile } = await supabase
        .from("profiles")
        .select("handle, display_name, avatar_url")
        .eq("user_id", data.user.id)
        .single();
      if (profile) {
        const handle = profile.handle;
        const initial = (profile.display_name || profile.handle).charAt(0).toUpperCase();
        const avatar = profile.avatar_url ?? null;
        try { sessionStorage.setItem("psy_auth", JSON.stringify({ handle, initial, avatar })); } catch {}
        setUserHandle(handle);
        setUserInitial(initial);
        setUserAvatar(avatar);
      }
      setAuthLoading(false);
    });
  }, []);

  // Autofocus when overlay opens
  useEffect(() => {
    if (searchOpen) {
      setTimeout(() => searchInputRef.current?.focus(), 50);
      document.body.style.overflow = "hidden";
    } else {
      if (!leftOpen && !rightOpen) document.body.style.overflow = "";
    }
    return () => { document.body.style.overflow = ""; };
  }, [searchOpen, leftOpen, rightOpen]);

  // Close on ESC
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") { setSearchOpen(false); setQuery(""); }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  // Close on route change
  useEffect(() => {
    setSearchOpen(false);
    setQuery("");
    setLeftOpen(false);
    setRightOpen(false);
  }, [pathname]);

  const handleSearch = () => {
    if (!query.trim()) return;
    setSearchOpen(false);
    setQuery("");
    router.push(`/browse?q=${encodeURIComponent(query.trim())}`);
  };

  const handleLogout = async () => {
    setLoggingOut(true);
    try { sessionStorage.removeItem("psy_auth"); } catch {}
    const supabase = createClient();
    await Promise.all([
      supabase.auth.signOut(),
      new Promise<void>((r) => setTimeout(r, 800)),
    ]);
    window.location.href = "/";
  };

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 150);
    window.addEventListener("scroll", handler, { passive: true });
    return () => window.removeEventListener("scroll", handler);
  }, []);

  useEffect(() => {
    if (!searchOpen) document.body.style.overflow = leftOpen || rightOpen ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [leftOpen, rightOpen, searchOpen]);

  const closeAll = () => { setLeftOpen(false); setRightOpen(false); };

  return (
    <>
      <div style={{ position: "sticky", top: 0, zIndex: 1000 }}>
        {/* Top bar */}
        <div style={{ background: "#000", borderBottom: "1px solid oklch(100% 0 0 / 0.12)" }}>
          <div className="site-shell header-topbar">
            <div className="header-logo">
              <Link href="/">
                <Image src="/logo.png" alt="psy.market" width={156} height={62} priority style={{ height: "62px", width: "auto", maxWidth: "100%", display: "block" }} />
              </Link>
            </div>

            {/* Desktop nav + search icon */}
            <div className="header-nav-center">
              {CATEGORIES.map(({ label, href }) => (
                <Link key={label} href={href} className="header-category-link">{label}</Link>
              ))}
              <button
                onClick={() => { setSearchOpen(!searchOpen); closeAll(); }}
                aria-label="Search"
                style={{ background: "none", border: "none", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", width: "32px", height: "32px", color: searchOpen ? "white" : "oklch(65% 0.01 70)", transition: "color 0.15s", flexShrink: 0, padding: 0 }}
              >
                {searchOpen ? (
                  <svg width="17" height="17" viewBox="0 0 17 17" fill="none">
                    <path d="M2 2l13 13M15 2L2 15" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
                  </svg>
                ) : (
                  <svg width="17" height="17" viewBox="0 0 17 17" fill="none">
                    <circle cx="7.5" cy="7.5" r="5.5" stroke="currentColor" strokeWidth="1.7" />
                    <line x1="11.5" y1="11.5" x2="15" y2="15" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
                  </svg>
                )}
              </button>
            </div>

            {/* Desktop auth */}
            <div className="header-auth-links">
              {authLoading ? (
                <div style={{ width: "120px" }} />
              ) : userHandle ? (
                <>
                  <Link href={`/${userHandle}`} style={{ display: "flex", alignItems: "center", gap: "8px", textDecoration: "none", color: "white" }}>
                    {userAvatar
                      ? <img src={userAvatar} alt={userInitial} style={{ width: "32px", height: "32px", borderRadius: "50%", objectFit: "cover", flexShrink: 0, border: "2px solid oklch(100% 0 0 / 0.15)" }} />
                      : <div style={{ width: "32px", height: "32px", borderRadius: "50%", background: "var(--rust)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "13px", fontWeight: 700, color: "white", flexShrink: 0 }}>{userInitial}</div>
                    }
                    <span style={{ fontSize: "13px", fontWeight: 600, color: "oklch(85% 0.01 70)" }}>@{userHandle}</span>
                  </Link>
                  <button onClick={handleLogout} disabled={loggingOut} className="header-auth-secondary" style={{ cursor: loggingOut ? "default" : "pointer", background: "oklch(100% 0 0 / 0.08)", border: "1px solid oklch(100% 0 0 / 0.3)", borderRadius: "6px", padding: "7px 14px", fontSize: "13px", color: "oklch(88% 0.01 70)", fontFamily: "Manrope, var(--font-manrope)", transition: "all 0.2s", opacity: loggingOut ? 0.5 : 1, fontWeight: 500 }}>
                    {loggingOut ? "Logging out…" : "Log Out"}
                  </button>
                </>
              ) : (
                <>
                  <button onClick={() => setAuthModal("login")} className="header-auth-secondary" style={{ cursor: "pointer", background: "transparent", fontFamily: "Manrope, var(--font-manrope)" }}>Log In</button>
                  <button onClick={() => setAuthModal("signup")} className="header-auth-primary" style={{ cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>Sign Up</button>
                </>
              )}
            </div>

            <button className="header-ham header-ham-left" onClick={() => { setLeftOpen(true); setRightOpen(false); setSearchOpen(false); }} aria-label="Open categories">
              <HamIcon />
            </button>

            <div className="header-logo-mobile">
              <Link href="/">
                <Image src="/logo.png" alt="psy.market" width={156} height={62} priority style={{ height: "62px", width: "auto", maxWidth: "100%", display: "block" }} />
              </Link>
            </div>

            <button className="header-ham header-ham-right" onClick={() => { setRightOpen(true); setLeftOpen(false); setSearchOpen(false); }} aria-label="Open menu">
              <HamIcon />
            </button>
          </div>
        </div>

        {/* Search overlay */}
        <div style={{
          position: "absolute",
          top: "100%",
          left: 0,
          width: "100%",
          zIndex: 999,
          transform: searchOpen ? "translateY(0)" : "translateY(-8px)",
          opacity: searchOpen ? 1 : 0,
          pointerEvents: searchOpen ? "auto" : "none",
          transition: "transform 0.25s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.2s ease",
        }}>
          <div style={{ background: "oklch(12% 0.015 55 / 0.98)", backdropFilter: "blur(20px)", WebkitBackdropFilter: "blur(20px)", borderBottom: "1px solid oklch(100% 0 0 / 0.1)", boxShadow: "0 24px 48px oklch(0% 0 0 / 0.5)" }}>
            <div className="site-shell" style={{ paddingTop: "28px", paddingBottom: "28px" }}>
              {/* Search input */}
              <div style={{ display: "flex", gap: "12px", marginBottom: "24px" }}>
                <div style={{ flex: 1, display: "flex", alignItems: "center", gap: "12px", background: "oklch(100% 0 0 / 0.07)", border: "1px solid oklch(100% 0 0 / 0.15)", borderRadius: "10px", padding: "14px 18px" }}>
                  <svg width="18" height="18" viewBox="0 0 18 18" fill="none" style={{ flexShrink: 0 }}>
                    <circle cx="8" cy="8" r="5.5" stroke="oklch(60% 0.01 70)" strokeWidth="1.6" />
                    <line x1="12.5" y1="12.5" x2="16" y2="16" stroke="oklch(60% 0.01 70)" strokeWidth="1.6" strokeLinecap="round" />
                  </svg>
                  <input
                    ref={searchInputRef}
                    type="text"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                    placeholder="Search apparel, art, gear, tickets…"
                    style={{ flex: 1, background: "transparent", border: "none", outline: "none", fontSize: "16px", color: "white", fontFamily: "Manrope, var(--font-manrope)", fontWeight: 500 }}
                  />
                  {query && (
                    <button onClick={() => setQuery("")} style={{ background: "none", border: "none", cursor: "pointer", color: "oklch(55% 0.01 70)", fontSize: "20px", lineHeight: 1, padding: 0, flexShrink: 0 }}>×</button>
                  )}
                </div>
                <button
                  onClick={handleSearch}
                  disabled={!query.trim()}
                  style={{ background: "var(--rust)", color: "white", border: "none", borderRadius: "10px", padding: "14px 28px", fontSize: "14px", fontWeight: 700, cursor: query.trim() ? "pointer" : "default", fontFamily: "Manrope, var(--font-manrope)", opacity: query.trim() ? 1 : 0.4, transition: "opacity 0.2s", flexShrink: 0, letterSpacing: "0.02em" }}
                >
                  Search
                </button>
              </div>

              {/* Quick links */}
              <div>
                <p style={{ fontSize: "10px", fontWeight: 700, letterSpacing: "0.1em", textTransform: "uppercase", color: "oklch(50% 0.01 70)", marginBottom: "12px" }}>
                  Browse categories
                </p>
                <div style={{ display: "flex", flexWrap: "wrap", gap: "8px" }}>
                  {QUICK_LINKS.map(({ label, href, icon }) => (
                    <Link
                      key={label}
                      href={href}
                      style={{ display: "flex", alignItems: "center", gap: "7px", background: "oklch(100% 0 0 / 0.06)", border: "1px solid oklch(100% 0 0 / 0.12)", borderRadius: "8px", padding: "8px 14px", fontSize: "13px", color: "oklch(80% 0.01 70)", textDecoration: "none", fontWeight: 500, transition: "all 0.15s", fontFamily: "Manrope, var(--font-manrope)" }}
                    >
                      <span>{icon}</span>
                      {label}
                    </Link>
                  ))}
                </div>
              </div>
            </div>
          </div>
          {/* Backdrop */}
          <div
            onClick={() => { setSearchOpen(false); setQuery(""); }}
            style={{ height: "100vh", background: "oklch(0% 0 0 / 0.5)" }}
          />
        </div>
      </div>

      {(leftOpen || rightOpen) && (
        <div onClick={closeAll} style={{ position: "fixed", inset: 0, background: "oklch(0% 0 0 / 0.6)", zIndex: 1100 }} />
      )}

      {/* Mobile category drawer */}
      <div className={`mobile-drawer mobile-drawer-left${leftOpen ? " open" : ""}`}>
        <div className="mobile-drawer-header">
          <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "17px", fontWeight: 700, color: "white" }}>Categories</span>
          <button onClick={closeAll} className="mobile-drawer-close">✕</button>
        </div>
        <nav style={{ padding: "8px 0" }}>
          {CATEGORIES.map(({ label, href }) => (
            <Link key={label} href={href} onClick={closeAll} className="mobile-drawer-link">{label}</Link>
          ))}
        </nav>
      </div>

      {/* Mobile menu drawer */}
      <div className={`mobile-drawer mobile-drawer-right${rightOpen ? " open" : ""}`}>
        <div className="mobile-drawer-header">
          <span style={{ fontFamily: "'Bricolage Grotesque', var(--font-bricolage)", fontSize: "17px", fontWeight: 700, color: "white" }}>Menu</span>
          <button onClick={closeAll} className="mobile-drawer-close">✕</button>
        </div>
        {/* Search in mobile drawer */}
        <div style={{ padding: "16px 20px 8px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "10px", background: "oklch(100% 0 0 / 0.07)", border: "1px solid oklch(100% 0 0 / 0.14)", borderRadius: "8px", padding: "11px 16px" }}>
            <svg width="15" height="15" viewBox="0 0 15 15" fill="none" style={{ flexShrink: 0 }}>
              <circle cx="6.5" cy="6.5" r="5" stroke="oklch(65% 0.01 70)" strokeWidth="1.4" />
              <line x1="10.5" y1="10.5" x2="13.5" y2="13.5" stroke="oklch(65% 0.01 70)" strokeWidth="1.4" strokeLinecap="round" />
            </svg>
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter" && query.trim()) { closeAll(); router.push(`/browse?q=${encodeURIComponent(query.trim())}`); setQuery(""); } }}
              placeholder="Search…"
              autoFocus={rightOpen}
              style={{ border: "none", outline: "none", background: "transparent", fontSize: "14px", color: "white", width: "100%", fontFamily: "Manrope, var(--font-manrope)" }}
            />
          </div>
        </div>
        <div style={{ padding: "8px 20px 24px", display: "flex", flexDirection: "column", gap: "10px" }}>
          {!authLoading && (userHandle ? (
            <>
              <Link href={`/${userHandle}`} onClick={closeAll} style={{ display: "flex", alignItems: "center", gap: "10px", padding: "12px 0", textDecoration: "none" }}>
                {userAvatar
                  ? <img src={userAvatar} alt={userInitial} style={{ width: "36px", height: "36px", borderRadius: "50%", objectFit: "cover", flexShrink: 0, border: "2px solid oklch(100% 0 0 / 0.15)" }} />
                  : <div style={{ width: "36px", height: "36px", borderRadius: "50%", background: "var(--rust)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "14px", fontWeight: 700, color: "white", flexShrink: 0 }}>{userInitial}</div>
                }
                <span style={{ fontSize: "14px", fontWeight: 600, color: "white" }}>@{userHandle}</span>
              </Link>
              <button onClick={handleLogout} disabled={loggingOut} className="mobile-auth-btn mobile-auth-secondary" style={{ cursor: loggingOut ? "default" : "pointer", fontFamily: "Manrope, var(--font-manrope)", opacity: loggingOut ? 0.6 : 1, transition: "opacity 0.2s" }}>
                {loggingOut ? "Logging out…" : "Log Out"}
              </button>
            </>
          ) : (
            <>
              <button onClick={() => { closeAll(); setAuthModal("login"); }} className="mobile-auth-btn mobile-auth-secondary" style={{ cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>Log In</button>
              <button onClick={() => { closeAll(); setAuthModal("signup"); }} className="mobile-auth-btn mobile-auth-primary" style={{ cursor: "pointer", fontFamily: "Manrope, var(--font-manrope)" }}>Sign Up</button>
            </>
          ))}
        </div>
      </div>

      {authModal && <AuthModal initial={authModal} onClose={() => setAuthModal(null)} />}
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
