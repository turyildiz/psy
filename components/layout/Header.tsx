"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
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

export default function Header() {
  const router = useRouter();
  const [scrolled, setScrolled] = useState(false);
  const [query, setQuery] = useState("");
  const [searchFocused, setSearchFocused] = useState(false);
  const [leftOpen, setLeftOpen] = useState(false);
  const [rightOpen, setRightOpen] = useState(false);
  const [userHandle, setUserHandle] = useState<string | null>(null);
  const [userInitial, setUserInitial] = useState<string>("");
  const [userAvatar, setUserAvatar] = useState<string | null>(null);
  const [loggingOut, setLoggingOut] = useState(false);
  const [authModal, setAuthModal] = useState<"login" | "signup" | null>(null);
  const [authLoading, setAuthLoading] = useState(true);

  useEffect(() => {
    // Restore from cache immediately to avoid flash on navigation
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
                <Image src="/logo.png" alt="psy.market" width={156} height={62} priority style={{ height: "62px", width: "auto", maxWidth: "100%", display: "block" }} />
              </Link>
            </div>

            <div className="header-search-wrap">
              <SearchBar />
            </div>

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

            <button className="header-ham header-ham-left" onClick={() => { setLeftOpen(true); setRightOpen(false); }} aria-label="Open categories">
              <HamIcon />
            </button>

            <div className="header-logo-mobile">
              <Link href="/">
                <Image src="/logo.png" alt="psy.market" width={156} height={62} priority style={{ height: "62px", width: "auto", maxWidth: "100%", display: "block" }} />
              </Link>
            </div>

            <button className="header-ham header-ham-right" onClick={() => { setRightOpen(true); setLeftOpen(false); }} aria-label="Open menu">
              <HamIcon />
            </button>
          </div>
        </div>

        <div className="header-catbar" style={{ minHeight: "56px", background: "oklch(15% 0.02 55)", borderBottom: "1px solid oklch(100% 0 0 / 0.09)", boxShadow: scrolled ? "0 4px 24px oklch(0% 0 0 / 0.45)" : "none", transition: "box-shadow 0.35s ease" }}>
          <div className="site-shell header-categories">
            {CATEGORIES.map(({ label, href }) => (
              <Link key={label} href={href} className="header-category-link">{label}</Link>
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
          {CATEGORIES.map(({ label, href }) => (
            <Link key={label} href={href} onClick={closeAll} className="mobile-drawer-link">{label}</Link>
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
