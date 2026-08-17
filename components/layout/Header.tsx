"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter, usePathname } from "next/navigation";
import Image from "next/image";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { createInitialAuthSnapshotGate } from "@/lib/auth/initial-snapshot-gate";
import { registerAuthUiRefreshParticipant } from "@/lib/auth/ui-transition";
import { assignAtTop } from "@/lib/navigation/scroll-reset";
import { getMyProfiles, getOnlyProfileForCurrentAccount } from "@/lib/db";
import AuthModal from "@/components/AuthModal";
import ProfileAvatar from "@/components/ProfileAvatar";

const CATEGORIES = [
  { label: "Apparel", href: "/apparel" },
  { label: "Art & Decor", href: "/art" },
  { label: "Jewellery", href: "/jewellery" },
  { label: "Music", href: "/music" },
  { label: "Tickets", href: "/tickets" },
  { label: "Vintage", href: "/vintage" },
  { label: "New Arrivals", href: "/new-arrivals" },
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
  const [msgCount, setMsgCount] = useState(0);
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
    const authUiParticipant = registerAuthUiRefreshParticipant();
    let cancelled = false;
    let authGeneration = 0;
    let observedUserId: string | null | undefined;

    const clearAuthenticatedUser = () => {
      try { sessionStorage.removeItem("psy_auth"); } catch {}
      setUserHandle(null);
      setUserInitial("");
      setUserAvatar(null);
      setMsgCount(0);
      setAuthLoading(false);
    };

    const syncAuthenticatedUser = async (userId: string | null) => {
      if (cancelled || observedUserId === userId) return;
      observedUserId = userId;
      const generation = ++authGeneration;

      if (!userId) {
        clearAuthenticatedUser();
        return;
      }

      const { data: profiles } = await getMyProfiles(supabase);
      if (cancelled || generation !== authGeneration) return;

      const profile = getOnlyProfileForCurrentAccount(profiles);
      if (!profile) {
        clearAuthenticatedUser();
        return;
      }

      const handle = profile.handle;
      const initial = (profile.displayName || profile.handle).charAt(0).toUpperCase();
      const avatar = profile.avatarUrl ?? null;
      try { sessionStorage.setItem("psy_auth", JSON.stringify({ handle, initial, avatar })); } catch {}
      setUserHandle(handle);
      setUserInitial(initial);
      setUserAvatar(avatar);

      const { data: unreadConvs } = await supabase.from("conversations")
        .select("id, unread_for")
        .or(`buyer_profile_id.eq.${profile.id},seller_profile_id.eq.${profile.id}`);
      if (cancelled || generation !== authGeneration) return;
      const unreadCount = (unreadConvs ?? []).filter((conversation: { unread_for?: string[] | null }) =>
        (conversation.unread_for ?? []).includes(profile.id)
      ).length;
      setMsgCount(unreadCount);
      setAuthLoading(false);
    };

    const authGate = createInitialAuthSnapshotGate<string | null>((userId) => {
      authUiParticipant.track(userId, syncAuthenticatedUser(userId));
    });

    void supabase.auth.getUser().then(({ data }) => {
      authGate.applyInitial(data.user?.id ?? null);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      authGate.applyEvent(session?.user.id ?? null);
    });

    return () => {
      cancelled = true;
      authUiParticipant.unregister();
      subscription.unsubscribe();
    };
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
    setAuthModal(null);
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
    await supabase.auth.signOut();
    assignAtTop("/");
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
  const isActivePath = (href: string) => pathname === href;

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
              <Link href="/stream" className={`header-category-link${isActivePath("/stream") ? " active" : ""}`} aria-current={isActivePath("/stream") ? "page" : undefined}>Stream</Link>
              {CATEGORIES.map(({ label, href }) => (
                href
                  ? <Link key={label} href={href} className={`header-category-link${isActivePath(href) ? " active" : ""}`} aria-current={isActivePath(href) ? "page" : undefined}>{label}</Link>
                  : <span key={label} className="header-category-link" style={{ cursor: "default" }}>{label}</span>
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
                    <ProfileAvatar name={userInitial || userHandle} url={userAvatar} size={32} style={{ border: "2px solid oklch(100% 0 0 / 0.15)" }} />
                    <span style={{ fontSize: "13px", fontWeight: 600, color: "oklch(85% 0.01 70)" }}>@{userHandle}</span>
                  </Link>
                  <Link href={`/${userHandle}?tab=inbox`} style={{ position: "relative", display: "flex", alignItems: "center", justifyContent: "center", width: "34px", height: "34px", borderRadius: "50%", background: "oklch(100% 0 0 / 0.08)", border: "1px solid oklch(100% 0 0 / 0.15)", textDecoration: "none", flexShrink: 0 }} title="Messages">
                    <svg width="16" height="14" viewBox="0 0 16 14" fill="none">
                      <path d="M1 1h14v9a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V1z" stroke="oklch(75% 0.01 70)" strokeWidth="1.4" />
                      <path d="M1 1l7 5 7-5" stroke="oklch(75% 0.01 70)" strokeWidth="1.4" strokeLinecap="round" />
                    </svg>
                    {msgCount > 0 && (
                      <span style={{ position: "absolute", top: "-4px", right: "-4px", background: "var(--rust)", color: "white", fontSize: "9px", fontWeight: 700, borderRadius: "10px", padding: "1px 5px", minWidth: "16px", textAlign: "center", lineHeight: "14px" }}>
                        {msgCount > 99 ? "99+" : msgCount}
                      </span>
                    )}
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
              <div style={{ display: "flex", gap: "12px" }}>
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
          <Link href="/stream" onClick={closeAll} className={`mobile-drawer-link${isActivePath("/stream") ? " active" : ""}`} aria-current={isActivePath("/stream") ? "page" : undefined}>Stream</Link>
          <div className="mobile-stream-divider" aria-hidden style={{ height: "1px", margin: "8px 20px", background: "oklch(100% 0 0 / 0.12)" }} />
          {CATEGORIES.map(({ label, href }) => (
            href
              ? <Link key={label} href={href} onClick={closeAll} className={`mobile-drawer-link${isActivePath(href) ? " active" : ""}`} aria-current={isActivePath(href) ? "page" : undefined}>{label}</Link>
              : <span key={label} className="mobile-drawer-link" style={{ cursor: "default" }}>{label}</span>
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
                <ProfileAvatar name={userInitial || userHandle} url={userAvatar} size={36} style={{ border: "2px solid oklch(100% 0 0 / 0.15)" }} />
                <span style={{ fontSize: "14px", fontWeight: 600, color: "white" }}>@{userHandle}</span>
              </Link>
              <Link href={`/${userHandle}?tab=inbox`} onClick={closeAll} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px 16px", borderRadius: "8px", background: "oklch(100% 0 0 / 0.06)", border: "1px solid oklch(100% 0 0 / 0.1)", textDecoration: "none" }}>
                <span style={{ fontSize: "14px", fontWeight: 600, color: "white" }}>Messages</span>
                {msgCount > 0 && <span style={{ background: "var(--rust)", color: "white", fontSize: "11px", fontWeight: 700, borderRadius: "10px", padding: "2px 8px" }}>{msgCount > 99 ? "99+" : msgCount}</span>}
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
